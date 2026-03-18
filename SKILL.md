---
name: scarf
user-invocable: true
description: Scarf Data Assistant skill for AI agents to answer Scarf analytics questions, manage insights filters, and read or set persisted user-defined variables with a user-provided SCARF_API_TOKEN using Scarf public v2 API endpoints. Use when users ask for Scarf package/org metrics, funnel/lead summaries, export status, or bounded insights-filter workflows.
---

# Scarf Data Assistant

Use this skill to translate user intent into safe, reliable Scarf API calls and concise, actionable outputs.

## Operating contract

- Require `SCARF_API_TOKEN` before any API call.
- Never log, print, or persist raw tokens.
- Require organization scope (`owner`) before query execution.
- Default to read-oriented analytics flows.
- Allow bounded insights-filter workflows as the only v1 write surface.
- v1 policy: execute `GET` operations plus the explicit insights-filter and persisted-variable exceptions below.
- Allowed non-`GET` operations:
  - `POST /v2/insights/{owner}/filters`
  - `PUT /v2/insights/{owner}/filters/{filter_id}`
  - `DELETE /v2/insights/{owner}/filters/{filter_id}`
  - `POST /v2/insights/{owner}/user-defined-variables`
- Block all other create/update/delete operations in v1.
- Use UTC for all date logic and output labels.
- If no time range is provided, default to last 30 days: `[now-30d, now)` in UTC.
- Use `filter_id` when available to narrow scope and reduce noisy output.
- When listing or creating filters, use `scope=adhoc|global` as documented.
- Prefer `global` scope for reusable saved filters and `adhoc` scope for temporary filters.
- Prefer small, composable calls and summarize results in user language.

## Startup flow

1. Validate auth (`401/403` handling with clear next-step guidance).
2. Resolve organization scope (`owner`) and optional package/entity target.
3. Resolve date range (default 30-day UTC window if omitted).
4. If the user is managing filters, choose the minimal operation (`list`, `create`, `get`, `update`, `delete`) plus `scope` and optional `saved_only` as needed.
5. If the user asks to persist or read custom variables, use `getUserDefinedVariables` / `setUserDefinedVariables`.
6. Apply `filter_id` when an analytics endpoint supports it and a filter context is available.
7. Run minimal API calls needed to answer the request.
8. Return:
   - direct answer,
   - key numbers,
   - assumptions,
   - optional next action.

## Output style

- Be concise and decision-oriented.
- Include caveats if data is partial, delayed, sampled, or filtered.
- If a filter mutation succeeds, state exactly what changed and which `filter_id` or scope was affected.
- If persisted user-defined variables are written, summarize the keys changed.
- If the API fails, provide exact reason plus one concrete recovery step.

## References

- Read `references/v1-spec.md` for architecture, scope, defaults, and API strategy.
- Read `references/v1-allowlist.md` for the execution allowlist and insights-filter CRUD exceptions.
- Read `references/api-v2-endpoint-inventory.md` for the public v2 endpoint catalog derived from the published OpenAPI spec.
- Read `references/api-map.v1.json` for v1 capability-to-endpoint mapping.
- Read `references/filter-catalog.md` for supported filter keys, scope usage, and payload examples.
- Read `references/launch-checklist.md` before release.
- Read `references/prompt-examples.md` for canonical user intents and expected behavior.
