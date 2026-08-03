# scarf-skill

Standalone Scarf skill for analytics, Dependency Radar, and administration across the published Scarf API.

## Access model

The skill separates work into two request-scoped profiles:

- **Read:** public `GET` routes plus the read-like search and Scarf AI chat `POST` routes.
- **Admin:** public state-changing routes for packages, Scarf Gateway domains and routes, tracking pixels, collections, scheduled exports, filters, organization members and permissions, and event imports.

The skill calls `https://api.scarf.sh` directly over authenticated HTTPS with a user-provided `SCARF_API_TOKEN`; it does not require a Scarf-specific tool or server. The read execution profile is the default, and admin behavior is activated only for the current explicit task. Guardrails include exact target resolution, pre-change reads, fresh confirmation for protected operations, serialized mutations, and post-change verification. A skill is not a security boundary, so use least-privileged and separate read/admin credentials where the API and deployment support them.

The current capability map covers all 83 operations in the published v2/v3 OpenAPI document as of 2026-08-02. The release checker independently pins every operation ID to its approved HTTP method and path so policy assignments cannot silently move to another route.

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
- `references/api-map.json`: full public operation-ID manifest plus separate read/admin execution profiles
- `references/api-v2-endpoint-inventory.md`: published endpoint catalog
- `references/filter-catalog.md`: insights-filter schema and examples
- `references/prompt-examples.md`: behavioral acceptance cases
- `references/launch-checklist.md`: release checks
- `LICENSE`: Apache-2.0

## Validation

- `ruby scripts/check_skill_structure.rb`: validate the repository-required skill frontmatter.
- `ruby scripts/check_api_coverage.rb`: compare the live OpenAPI document, canonical manifest, inventory, profiles, policy, and capability groups.
- `ruby scripts/test_api_coverage.rb`: run the live baseline plus executable fail-closed mutations for route, profile, policy, capability, reference, schema, inventory, and transport-contract drift.

GitHub Actions runs these checks, Ruby syntax validation, JSON parsing, and changed-file whitespace checks on every pull request and push to `main`.
