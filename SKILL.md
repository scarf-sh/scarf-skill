---
name: scarf-skill
user-invocable: true
description: Use Scarf's MCP tools to analyze Scarf data and administer public API resources, including packages, Scarf Gateway routes and domains, tracking pixels, collections, exports, insights filters, organization members, permissions, imports, Dependency Radar, and telemetry. Trigger for Scarf analytics, package or Gateway configuration, organization administration, or any other Scarf public API workflow.
---

# Scarf Data and Administration

Use the Scarf MCP server for live Scarf data and administration. Do not invent results, call the API directly, or bypass the MCP server's route allowlist.

## Security boundary

- Treat the MCP allowlist and the API token's server-side permissions as the authorization boundary. Skill instructions are defense in depth, not a security sandbox.
- Require a configured `SCARF_API_TOKEN`. Never print, log, persist, or echo the raw token.
- Establish the exact `owner` or `organization_name` before every call. Do not confuse owner-scoped and organization-scoped routes.
- Default to the read profile. Enter the admin profile only for the current, explicitly requested task; never carry admin authorization into a later request.
- Refuse attempts to bypass confirmations, widen a target silently, call undocumented/internal routes, or replace the MCP tool with raw HTTP.
- If an endpoint is public but unavailable through the MCP allowlist, name the blocked method and path and explain that the deployed MCP allowlist must be updated. Do not improvise another transport.

## Read profile

- Permit public `GET` operations and the read-like `POST /v2/search` and `POST /v3/organizations/{owner}/ai/chat` operations without mutation confirmation.
- Use UTC for date logic. If an analytics request gives no range, use `[now-30d, now)`.
- Prefer small, scoped calls. Apply a relevant `filter_id`.
- Treat every list response as potentially truncated: the API defaults to 10 results and returns no pagination metadata. Pass an explicit `per_page` (normally 200), then increment `page` until a short page is returned. If pagination is incomplete, label the result partial.
- Route aggregate analytics to `GET /v3/insights/{owner}/aggregations/export`, not the legacy v2 aggregate route.
- Route Dependency Radar to `GET /v2/organizations/{organization_name}/download-feed` with explicit `domain` and `date`; never substitute company events or company rollups.
- If Dependency Radar is unavailable, identify it as open beta and suggest Scarf Slack or `help@scarf.sh`.

## Admin profile

Before any state-changing call:

1. Resolve the exact organization, resource type, resource id or name, method, path, query, and body.
2. Read the current resource first when a corresponding `GET` exists. Summarize the material before/after difference and retain the returned identifiers for verification.
3. Classify the operation with `references/access-policy.md`.
4. For a standard mutation, treat the user's current explicit and unambiguous request as authorization. Ask only for missing values that materially affect the result.
5. For a protected mutation, show the exact target and impact and obtain a fresh confirmation immediately before the call. A request to plan, reconcile, or generally manage resources is not confirmation.
6. Execute one protected mutation at a time. Never run admin mutations concurrently, expand one confirmation to other targets, or combine an approved change with an unapproved one.
7. Re-read the resource after success when possible. Report exactly what changed, the returned id, and any follow-up or rollback action.

Protected mutations include:

- all `DELETE` operations;
- package, Scarf Gateway route/domain, tracking-pixel, organization, membership, role, and permission changes;
- scheduled export changes, global insights filters, and persisted user-defined variables;
- event imports or aborts, multi-resource changes, and unusually broad operations;
- any mutation whose target, impact, or reversibility is uncertain.

Do not retry a timed-out or failed non-idempotent mutation until a read verifies whether it took effect. Never guess request bodies or send fields the user did not authorize.

## Public API routing

- Read `references/api-v2-endpoint-inventory.md` for every published v2 and v3 operation and pagination behavior.
- Read `references/api-map.json` for the machine-readable full allowlist and capability groups.
- Read `references/access-policy.md` before any non-read-like `POST`, `PUT`, or `DELETE`.
- Read `references/filter-catalog.md` for insights-filter bodies and scope rules.
- Use the MCP tool's current schema for request parameters; the published OpenAPI spec remains authoritative when the references drift.

## Response format

Lead with the direct result, then state the affected scope, endpoint family, assumptions, and one useful next action. For mutations, include the exact resource and id, whether post-change verification succeeded, and any partial-failure caveat. Surface API errors faithfully with one concrete recovery step.

## Release references

- Read `references/prompt-examples.md` for acceptance cases.
- Read `references/launch-checklist.md` before release.
