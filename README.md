# scarf-skill

Scarf skill for analytics, Dependency Radar, and administration across the published Scarf API.

## Access model

The skill separates work into two request-scoped profiles:

- **Read:** public `GET` routes plus the read-like search and Scarf AI chat `POST` routes.
- **Admin:** public state-changing routes for packages, Scarf Gateway domains and routes, tracking pixels, collections, scheduled exports, filters, organization members and permissions, and event imports.

Admin access is default-deny at the MCP layer. Deploy the read allowlist by default and expose the separate admin allowlist only through explicit configuration. The skill adds behavioral guardrails: exact target resolution, pre-change reads, fresh confirmation for protected operations, serialized mutations, and post-change verification. A skill is not a security boundary; production deployments should also use least-privileged, separate read/admin credentials where possible.

The current capability map covers all 83 operations in the published v2/v3 OpenAPI document as of 2026-08-02.

## Defaults

- Auth: `SCARF_API_TOKEN` (required and never echoed)
- Route scope: resolve every identifier declared by the selected route; require `owner` or `organization_name` only when that route declares it
- Analytics timezone: UTC
- Missing analytics window: `[now-30d, now)`
- Aggregations: `GET /v3/insights/{owner}/aggregations/export`, never the legacy v2 aggregate route
- List pagination: explicit `per_page` and `page` until a short page; the API defaults to 10 with no pagination metadata
- Insights-filter scope: `adhoc` unless the user explicitly requests and confirms `global`
- Dependency Radar: `GET /v2/organizations/{organization_name}/download-feed`

## References

- `references/access-policy.md`: read/admin isolation and confirmation policy
- `references/api-map.json`: full public operation manifest plus separate read/admin deployment profiles
- `references/api-v2-endpoint-inventory.md`: published endpoint catalog
- `references/filter-catalog.md`: insights-filter schema and examples
- `references/prompt-examples.md`: behavioral acceptance cases
- `references/launch-checklist.md`: release checks
- `LICENSE`: Apache-2.0
