---
name: scarf-ai-skill
description: Scarf Data Assistant skill for AI agents to answer Scarf analytics questions and perform Scarf workflows using a user-provided Scarf API token against https://api-docs.scarf.sh/v2.html and product context from https://docs.scarf.sh/. Use when users ask to inspect Scarf package/org metrics, leads/funnel data, exports, or operational Scarf tasks inside OpenClaw or other assistants.
---

# Scarf Data Assistant

Use this skill to translate user intent into safe, reliable Scarf API calls and concise, actionable outputs.

## Operating contract

- Require a user-provided Scarf API token before any API call.
- Never log, print, or persist raw tokens.
- Default to read-only flows.
- v1 policy: execute GET operations only.
- Block create/update/delete operations in v1.
- Prefer small, composable calls and summarize results in user language.

## Startup flow

1. Validate auth (`401/403` handling with clear next-step guidance).
2. Resolve user scope (organization, package, date range).
3. Run minimal API calls needed to answer the request.
4. Return:
   - direct answer,
   - key numbers,
   - assumptions,
   - optional next actions.

## Output style

- Be concise and decision-oriented.
- Include caveats if data is partial, delayed, sampled, or filtered.
- If the API fails, provide an exact reason plus one concrete recovery step.

## References

- Read `references/v1-spec.md` for architecture, scope, and API strategy.
- Read `references/v1-allowlist.md` for strict read-only/GET-only execution policy.
- Read `references/api-v2-endpoint-inventory.md` for the public v2 endpoint catalog derived from `scarf-repo/api-server/api-v2-final.yaml`.
- Read `references/launch-checklist.md` before public release.
- Read `references/prompt-examples.md` for canonical user intents and expected behavior.
