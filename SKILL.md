---
name: scarf-skill
user-invocable: true
description: Scarf Data Assistant skill for AI agents to answer Scarf analytics questions with a user-provided SCARF_API_TOKEN using Scarf public v2 API endpoints. Use when users ask for Scarf package/org metrics, funnel/lead summaries, export status, or bounded read-only data retrieval workflows.
---

# Scarf Data Assistant

Use this skill to translate user intent into safe, reliable Scarf API calls and concise, actionable outputs.

## Operating contract

- Require `SCARF_API_TOKEN` before any API call.
- Never log, print, or persist raw tokens.
- Require organization scope (`owner`) before query execution.
- Default to read-only flows.
- v1 policy: execute `GET` operations only.
- Block create/update/delete operations in v1.
- Use UTC for all date logic and output labels.
- If no time range is provided, default to last 30 days: `[now-30d, now)` in UTC.
- Use `filter_id` when available to narrow scope and reduce noisy output.
- Prefer small, composable calls and summarize results in user language.

## Startup flow

1. Validate auth (`401/403` handling with clear next-step guidance).
2. Resolve organization scope (`owner`) and optional package/entity target.
3. Resolve date range (default 30-day UTC window if omitted).
4. Apply `filter_id` when endpoint supports it and a filter context is available.
5. Run minimal API calls needed to answer the request.
6. Return:
   - direct answer,
   - key numbers,
   - assumptions,
   - optional next action.

## Output style

- Be concise and decision-oriented.
- Include caveats if data is partial, delayed, sampled, or filtered.
- If the API fails, provide exact reason plus one concrete recovery step.

## References

- Read `references/v1-spec.md` for architecture, scope, defaults, and API strategy.
- Read `references/v1-allowlist.md` for strict read-only/GET-only execution policy.
- Read `references/api-v2-endpoint-inventory.md` for the public v2 endpoint catalog derived from `scarf-repo/api-server/api-v2-final.yaml`.
- Read `references/api-map.v1.json` for v1 capability-to-endpoint mapping.
- Read `references/launch-checklist.md` before release.
- Read `references/prompt-examples.md` for canonical user intents and expected behavior.
