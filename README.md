# scarf-skill

Scarf Data Assistant skill for Scarf analytics and insights-filter workflows.

Slash command: `/scarf`

## v1 contract (analytics-first with bounded insights workflows)

- Auth env var: `SCARF_API_TOKEN` (required)
- Organization scope: required (`owner` / org slug)
- Timezone handling: **UTC only** for all defaults and reporting
- Default date window when missing: last **30 days** (`[now-30d, now)` in UTC)
- API scope: `GET` by default, plus bounded insights workflow writes
- Allowed write operations: `createInsightsFilter`, `updateInsightsFilter`, `deleteInsightsFilter`, `setUserDefinedVariables`
- Optional narrowing: use `filter_id` when endpoint supports it, or manage filters through the public `/v2/insights/{owner}/filters` endpoints
- Filter listing/creation params: `scope=adhoc|global`, plus `saved_only=true` when the user wants saved filters only
- Scope guidance: prefer `global` for reusable saved filters and `adhoc` for temporary filters
- Persisted variables endpoints are in scope:
  - `GET /v2/insights/{owner}/user-defined-variables`
  - `POST /v2/insights/{owner}/user-defined-variables`

## Slash command examples

- `/scarf list filters for scarf org`
- `/scarf create a global saved filter for US Fortune 500 companies on version 5.x`
- `/scarf show persisted user-defined variables for scarf`
- `/scarf set persisted user-defined variable campaign=launch-q2 for scarf`

## Included files

- `SKILL.md`
- `references/filter-catalog.md`
- `references/v1-spec.md`
- `references/v1-allowlist.md`
- `references/api-v2-endpoint-inventory.md`
- `references/api-map.v1.json`
- `references/prompt-examples.md`
- `references/launch-checklist.md`
- `LICENSE` (Apache-2.0)
