# Scarf Skill Capability Spec

## Goal

Let a Scarf user analyze data and manage resources across the published API through ordinary authenticated HTTPS, without requiring a separate Scarf-specific tool or server.

## Architecture

- Call `https://api.scarf.sh` directly with `SCARF_API_TOKEN` as a Bearer token using any available HTTPS client.
- Do not require a plugin, proxy, companion server, or other Scarf-specific transport.
- Use `references/api-map.json` as the reviewable public-operation manifest and execution-profile source. The release checker independently binds every operation ID to its approved method and path; never make the full manifest the default execution profile.
- Treat `references/access-policy.md` as behavioral defense in depth, not authorization enforcement; the API token's server-side permissions are the hard boundary.
- Prefer separate least-privileged read and admin credentials when the API and deployment support them.
- Normalize the published v3 `ScarfBearer` security-requirement label to the declared `ApiToken` Bearer scheme. Reject every other undefined security-requirement name.

## Coverage

Cover all operations in the published OpenAPI document at `https://api.scarf.sh/static/api-v2.yaml`, including its v2 and v3 paths. The 2026-08-02 snapshot contains 83 operations.

Capability families include analytics, packages, Scarf Gateway domains and routes, tracking pixels, collections, scheduled exports, filters and persisted variables, organizations and access control, external event imports, Dependency Radar, search, Scarf AI chat, and endpoint feedback.

Do not call undocumented internal endpoints. When the published spec changes, update the inventory and map together and re-run the coverage check.

## Auth and scope

- Require `SCARF_API_TOKEN` and never expose it.
- Resolve every identifier declared by the selected route. Require an exact `owner` or `organization_name` only for routes that declare one; username discovery routes require `username` instead.
- Use UTC for analytics windows and default to `[now-30d, now)` when omitted.
- Require explicit dates and domains for Dependency Radar.
- Paginate list operations and prefer bounded requests.

## Mutation safety

- Keep reads as the default profile.
- Scope admin authorization to one explicit task.
- Pre-read and classify, re-evaluate conditionally standard mutations against the complete request immediately before writing, confirm protected operations, revalidate existing resources or creation context immediately after confirmation, serialize every admin mutation, and post-read.
- Treat all deletes, routing changes, access-control changes, imports, recurring exports, org-wide state, and ambiguous or broad changes as protected.
- Never retry an ambiguous non-idempotent call without checking whether it succeeded.

## Quality bar

Validate:

- local skill structure and frontmatter;
- duplicate-free JSON/YAML, unique operation ids and tuples, unambiguous referenced path items, canonical operation ID/method/path bindings, request parameters and transitive request-body schemas for every operation, and exact OpenAPI coverage;
- the canonical API server with no path- or operation-level overrides, plus the documented Bearer scheme and exact global/path/operation security state;
- read/admin classification for every non-`GET` operation;
- prompt behavior for safe reads, standard mutations, protected mutations, stale confirmation, partial failure, schema drift, and standalone API execution;
- auth redaction, pagination, UTC defaults, `401`/`403`/`404`/`429`/`5xx`, and schema drift.

Run `scripts/check_api_coverage.rb` and `scripts/test_api_coverage.rb` against the live spec before release. The executable mutation suite must reject synchronized route swaps, new referenced operations, policy escalation, classification drift, capability reassignment, malformed map shapes, undeclared execution profiles, legacy transport configuration, policy-relevant request-schema drift, and stale inventory counts.

## Response contract

Return the direct result, evidence or material diff, affected scope, endpoint family, assumptions, verification status, and one useful next action. Distinguish planned, confirmed, executed, failed, and unexecuted mutations.
