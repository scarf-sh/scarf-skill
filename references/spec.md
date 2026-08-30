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

Cover all operations in the published OpenAPI document at `https://api.scarf.sh/static/api-v2.yaml`, including its v2 and v3 paths. The 2026-08-30 snapshot contains 85 operations.

Capability families include analytics, packages, Scarf Gateway domains and routes, tracking pixels, collections, scheduled exports, filters and persisted variables, organizations and access control, external event imports, Dependency Radar, search, Scarf AI chat, and endpoint feedback.

Do not call undocumented internal endpoints. When the published spec changes, update the inventory and map together and re-run the coverage check.

## Auth and scope

- Require `SCARF_API_TOKEN` and never expose it.
- Resolve every identifier declared by the selected route. Require an exact `owner` or `organization_name` only for routes that declare one; username discovery routes require `username` instead.
- Use UTC for analytics windows and default to `[now-30d, now)` when omitted.
- Require explicit dates and domains for Dependency Radar.
- Paginate list operations and prefer bounded requests.

## Aggregation queries

Use `export_entity_aggregations` (`GET /v3/insights/{owner}/aggregations/export`).
Read the published contract before using a parameter. The helper deliberately
runs one explicit rollup and one breakdown set per call, keeping results bounded
and avoiding double-counting overlapping rollups or independent breakdowns.

- Dates are UTC calendar dates: `start_date` inclusive, `end_date` exclusive.
  Convert an inclusive user end date to the following day. Omitted helper dates
  select the latest 30 date buckets, ending tomorrow UTC. Never add a day to an
  end date that is already exclusive. The response reports the window the server
  actually queried in `X-Scarf-Effective-Start-Date` and
  `X-Scarf-Effective-End-Date`; the helper echoes them as `effective_window`.
  Report that window, not the client-side prediction, which drifts if the route's
  default changes.
- Use `rollup=total` for one whole-window result or distinct count; use `daily`,
  `weekly` (Monday start), `monthly`, or `yearly` for timelines. A timeline uses
  `by-total` plus the requested rollup; it does not need a separate by-date route.
- Repeat `package_id` or `tracking_pixel_id` for a union of UUIDs. Each selector
  also accepts `all` or `none`, alone. With neither selector, all active artifacts
  are included; specifying only packages excludes pixels and vice versa. Use
  `tracking_pixels_for_package_id` for pixels attached to a package. The `query`
  name DSL is an alternative to explicit selectors, not an additional filter.
- V3 accepts a saved/adhoc filter reference through `filter`, including v3 slugs
  and v2 hashids. `company_reference` scopes an accessible company;
  `include_low_confidence=false` excludes low-confidence company matches.
- JSON (`format=json`) returns `{data: [...]}`; the default NDJSON returns one
  object per line. Parse the requested format, not a guessed array shape.
- New dimensions include `by-user-agent`, `by-importance`,
  `by-company-funnel-stage`, `by-company-size`, and `by-company-sic-code`.
  The last three require `format=json`, `rollup=total`, and exactly one breakdown.
  Use `company_count` for company-segment counts, not event totals.
- `query` cannot be combined with `package_id` or `tracking_pixel_id`, and
  `tracking_pixels_for_package_id` cannot be combined with `query` or
  `package_id`. The helper rejects both before spending a request.
- Rows distinguish `artifact`, `artifact_name`, and `artifact_type` and carry
  `total`, `unique_origins`, and `unique_endpoints`. Default grouping is per
  artifact. `group_by_artifact=false` combines artifacts within each type;
  packages and pixels remain separate. Sum event totals only across disjoint
  groups. `by-variable` can repeat an event across variables, so its row totals
  are not an organization-wide event total.
- Distinct counts are approximate and non-additive. Never deduplicate identical
  aggregate rows or add their unique counts to infer shared visitors. For a
  whole-window package distinct count, request `package_id=all`, `rollup=total`,
  `by-total`, and `group_by_artifact=false` and read the single result row.
- Packages and tracking pixels cannot be combined into one distinct count. No
  published parameter groups across artifact types, so report the package and
  pixel counts separately and say they cannot be added. Never present a summed
  figure as a combined unique count.

For example, whole-window package totals for August 2026:

```sh
ruby scripts/aggregation_export.rb --owner OWNER \
  --start-date 2026-08-01 --end-date 2026-09-01 \
  --package-id all --rollup total --breakdown by-total \
  --no-group-by-artifact --format json
```

Keep normal public API entitlements and usage metering. Never send `_ui=1` or
use internal routes to bypass an export restriction. A `403` is a failure to
report, not a reason to change the access path.

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
