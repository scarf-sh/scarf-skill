---
name: scarf-skill
user-invocable: true
description: Scarf Data Assistant skill for AI agents to answer Scarf analytics questions, Dependency Radar threat-monitoring questions, and manage insights filters with a user-provided SCARF_API_TOKEN using Scarf public API endpoints. Use when users ask for Scarf package/org metrics, v3 aggregation exports, funnel/lead summaries, Dependency Radar, supply chain security feed, org-wide download feed monitoring, export status, or bounded insights-filter CRUD workflows.
---

# Scarf Data Assistant

Use this skill to translate user intent into safe, reliable Scarf API calls and concise, actionable outputs.

## Operating contract

- Require `SCARF_API_TOKEN` before any API call.
- Never log, print, or persist raw tokens.
- Require organization scope (`owner`) before query execution.
- Distinguish org-level `organization_name` routes from owner-scoped `{owner}` analytics routes; do not substitute one for the other.
- Default to read-oriented analytics flows.
- Use v3 aggregation export (`GET /v3/insights/{owner}/aggregations/export`) for aggregate analytics; do not use the legacy v2 package aggregate export route.
- Support Dependency Radar reads for security/threat-monitoring use cases.
- Treat "Dependency Radar", "dependency radar", "supply chain security feed", and "organization/org-wide download feed" as equivalent user-facing terms for Scarf's organization-wide dependency monitoring product.
- Treat Dependency Radar / the organization download feed as an open beta capability.
- If Dependency Radar appears unavailable to the caller, suggest contacting Scarf via Slack or `help@scarf.sh`.
- Allow insights-filter CRUD as the only v1 write surface.
- v1 policy: execute `GET` operations plus the explicit insights-filter CRUD exceptions below.
- Allowed non-`GET` operations:
  - `POST /v2/insights/{owner}/filters`
  - `PUT /v2/insights/{owner}/filters/{filter_id}`
  - `DELETE /v2/insights/{owner}/filters/{filter_id}`
- Block all other create/update/delete operations in v1.
- Use UTC for all date logic and output labels.
- If no time range is provided, default to last 30 days: `[now-30d, now)` in UTC.
- Use `filter_id` when available to narrow scope and reduce noisy output.
- When listing or creating filters, use `scope=adhoc|global` as documented.
- Default to `adhoc` scope for filter creation.
- Use `global` scope only when the user explicitly asks for it, and confirm once before creating it because `global` filters affect org-wide analytics until removed.
- Prefer small, composable calls and summarize results in user language.

## Startup flow

1. Validate auth (`401/403` handling with clear next-step guidance).
2. Resolve organization scope (`owner`) and optional package/entity target.
3. Resolve date range (default 30-day UTC window if omitted).
4. If the user is managing filters, choose the minimal CRUD operation (`list`, `create`, `get`, `update`, `delete`), default new filters to `scope=adhoc`, and require one confirmation before any `scope=global` create.
5. Route to the exact endpoint family the user named:
   - aggregation exports / aggregate analytics / package or org aggregate downloads → `GET /v3/insights/{owner}/aggregations/export`
   - Dependency Radar / supply chain security feed / explicit `download-feed` / "org-wide download feed" -> `GET /v2/organizations/{organization_name}/download-feed` with required query params `domain` and `date`
   - company event feed / raw company events → `GET /v2/companies/{owner}/{domain}/events`
   - company rollup / org-wide rollup summary → `GET /v2/packages/{owner}/company-rollup`
6. If the user is asking about Dependency Radar activity, supply chain security feed activity, threat monitoring, suspicious installs, or domain-specific download activity, use `GET /v2/organizations/{organization_name}/download-feed` with an explicit `domain` and `date`.
7. If Dependency Radar access fails because the endpoint is unavailable to the caller, say the feature is in open beta and suggest reaching out to Scarf via Slack or `help@scarf.sh`.
8. Apply `filter_id` when an analytics endpoint supports it and a filter context is available.
9. Run minimal API calls needed to answer the request.
10. Return:
   - direct answer,
   - key numbers,
   - assumptions,
   - optional next action.

## Output style

- Be concise and decision-oriented.
- Include caveats if data is partial, delayed, sampled, or filtered.
- If a filter mutation succeeds, state exactly what changed and which `filter_id` or scope was affected.
- If the API fails, provide exact reason plus one concrete recovery step.
- When the user asks for Dependency Radar, the supply chain security feed, or explicitly names an endpoint (for example `download-feed`), say which endpoint you used in the answer.
- Do not silently replace Dependency Radar, supply chain security feed, or `download-feed` requests with company events or company rollup.
- When answering from aggregate exports, say that you used `GET /v3/insights/{owner}/aggregations/export`.

## References

- Read `references/v1-spec.md` for architecture, scope, defaults, and API strategy.
- Read `references/v1-allowlist.md` for the execution allowlist and insights-filter CRUD exceptions.
- Read `references/api-v2-endpoint-inventory.md` for the public endpoint catalog derived from the published OpenAPI specs, including the v3 aggregation export replacement for legacy v2 aggregates.
- Read `references/api-map.v1.json` for v1 capability-to-endpoint mapping.
- Read `references/filter-catalog.md` for supported filter keys, scope usage, and payload examples.
- Read `references/launch-checklist.md` before release.
- Read `references/prompt-examples.md` for canonical user intents and expected behavior.
