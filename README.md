# scarf-skill

Scarf Data Assistant skill for Scarf analytics and insights-filter workflows.

## v1 contract (analytics-first with bounded filter CRUD)

- Auth env var: `SCARF_API_TOKEN` (required)
- Organization scope: required (`owner` / org slug)
- Timezone handling: **UTC only** for all defaults and reporting
- Default date window when missing: last **30 days** (`[now-30d, now)` in UTC)
- API scope: `GET` by default, plus limited insights-filter CRUD
- Allowed filter mutations: `createInsightsFilter`, `updateInsightsFilter`, `deleteInsightsFilter`
- Optional narrowing: use `filter_id` when endpoint supports it, or manage filters through the public `/v2/insights/{owner}/filters` endpoints
- Filter listing/creation params: `scope=adhoc|global`, plus `saved_only=true` when the user wants saved filters only
- Scope guidance: prefer `global` for reusable saved filters and `adhoc` for temporary filters

## Included files

- `SKILL.md`
- `references/filter-catalog.md`
- `references/v1-spec.md`
- `references/v1-allowlist.md`
- `references/api-v2-endpoint-inventory.md`
- `references/api-map.v1.json`
- `references/prompt-examples.md`
- `references/launch-checklist.md`
- `RELEASE_CHECKLIST.md`
- `LICENSE` (Apache-2.0)

## Release status

- Current release target: `0.2.0`
