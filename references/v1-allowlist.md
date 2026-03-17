# Scarf Data Assistant v1 Allowlist Policy

## Default policy

- v1 is analytics-first with bounded insights-filter management.
- v1 executes `GET` operations by default.
- Only the approved insights-filter mutations are allowed outside `GET`.
- All other non-`GET` operations are blocked by default.

## Routing policy

- The assistant may reference the full endpoint inventory for understanding.
- The assistant may execute only endpoints present in the v1 allowlist.
- Approved non-`GET` operations:
  - `setInsightsFilters`
  - `setInsightsFiltersName`
  - `deleteInsightsFiltersName`
- If a user asks for create/update/delete actions outside these endpoints, respond that v1 supports analytics plus limited insights-filter management only.

## Why this policy

- Increases reliability and predictability.
- Reduces accidental side effects.
- Preserves the new public filter-management workflow without reopening the broader write surface.
- Speeds up validation and launch.
