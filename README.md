# scarf-skill

Scarf Data Assistant skill for Scarf analytics, Dependency Radar monitoring, and insights-filter workflows.

## v1 contract (analytics-first with bounded filter CRUD)

- Auth env var: `SCARF_API_TOKEN` (required)
- Organization scope: required (`owner` / org slug)
- Timezone handling: **UTC only** for all defaults and reporting
- Default date window when missing: last **30 days** (`[now-30d, now)` in UTC)
- API scope: `GET` by default, plus limited insights-filter CRUD
- Aggregations: use `GET /v3/insights/{owner}/aggregations/export`; do not use legacy `/v2/packages/{owner}/aggregates`
- Allowed filter mutations: `createInsightsFilter`, `updateInsightsFilter`, `deleteInsightsFilter`
- Optional narrowing: use `filter_id` when endpoint supports it, or manage filters through the public `/v2/insights/{owner}/filters` endpoints
- Dependency Radar: route Dependency Radar, supply chain security feed, and org-wide download-feed requests to `getOrganizationDownloadFeed`
- Filter listing/creation params: `scope=adhoc|global`, plus `saved_only=true` when the user wants saved filters only
- Scope guidance: default new filters to `adhoc`; use `global` only when the user explicitly asks for it and confirms once

## Included files

- `SKILL.md`
- `references/filter-catalog.md`
- `references/v1-spec.md`
- `references/v1-allowlist.md`
- `references/api-v2-endpoint-inventory.md` (public v2 catalog plus v3 aggregation-export replacement note)
- `references/api-map.v1.json`
- `references/prompt-examples.md`
- `references/launch-checklist.md`
- `LICENSE` (Apache-2.0)
