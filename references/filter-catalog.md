# Insights Filters Catalog (v1)

Canonical source: `scarf-repo/api-lib/insights-filters/*` (generated API types).

## Payload shape

Filter sets are sent as JSON objects to:

- `PUT /v2/insights/{owner}/filters?filter_scope=global|adhoc`

You can optionally include:

- `name` (saved filter name)
- `crm_connections` (list of CRM integration ids)

Then apply the returned `id` via `filter_id` on supported analytics endpoints.

## Operators / enums

### Text filter (`NewTextFilter`)

```json
{ "op": "equals|not-equals|contains|does-not-contain|starts-with|does-not-start-with|is-empty|is-not-empty", "values": ["..."] }
```

### Boolean filter (`NewBooleanFilter`)

```json
{ "value": true }
```

### Date range filter (`NewFirstSeenFilter`, `NewLastSeenFilter`)

```json
{ "op": "yesterday|last-week|last-month|last-3-month|last-year|not-last-week|not-last-2-weeks" }
```

### Trend filter (`NewTimeTrendFilter`)

```json
{ "op": ["up"|"stable"|"down"] }
```

### Confidence filter (`NewConfidenceFilter`)

```json
{ "op": ["low"|"medium"|"high"] }
```

### Funnel stage filter (`NewFunnelStageFilter`)

```json
{ "op": ["interest"|"investigation"|"experimentation"|"ongoing-usage"|"inactive"] }
```

### Company size filter (`NewCompanySizeFilter`)

```json
{ "op": ["size-1-10"|"size-11-50"|"size-51-250"|"size-251-1K"|"size-1K-5K"|"size-5K-10K"|"size-10K-50K"|"size-50K-100K"|"size-100K-plus"] }
```

### CRM sync filter (`NewCrmSyncFilter`)

```json
{ "op": "any|none|these", "connection_ids": ["..."] }
```

### Industry filter (`NewIndustryFilter`)

```json
{ "op": [{ "sic_codes": [1234, 5678] }] }
```

### Variable filter (`NewVariableFilter`)

```json
{ "variable": "$key", "values_text_filter": { "op": "equals", "values": ["foo"] } }
```

## Full filter key catalog

All supported keys in `SetInsightsFilters` / `NewInsightsFilters`:

- `artifact_name` (text)
- `company_city` (text)
- `company_cloud_provider` (text)
- `company_confidence` (confidence)
- `company_country` (text)
- `company_crm` (crm)
- `company_domain` (text)
- `company_first_seen` (date-range)
- `company_funnelstage` (funnel-stage)
- `company_industry` (industry)
- `company_industry_label` (text)
- `company_is_forbes_2000` (boolean)
- `company_is_fortune_500` (boolean)
- `company_last_seen` (date-range)
- `company_mom_trend` (trend)
- `company_name` (text)
- `company_size` (company-size)
- `company_state` (text)
- `company_techstack` (text)
- `company_wow_trend` (trend)
- `endpoint_id` (text)
- `origin_id` (text)
- `request_do_not_track` (boolean)
- `request_domain` (text)
- `request_is_bot` (boolean)
- `request_origin_city` (text)
- `request_origin_country` (text)
- `request_origin_state` (text)
- `request_origin_zipcode` (text)
- `request_platform` (text)
- `request_referrer` (text)
- `request_user_agent` (text)
- `request_variable` (variable)
- `request_variable_2` (variable)
- `request_variable_3` (variable)
- `request_version` (text)

## Example: Fortune 500 + US + version 5.x

```json
{
  "name": "Fortune 500 / US / version 5.x",
  "company_is_fortune_500": { "value": true },
  "company_country": { "op": "equals", "values": ["United States"] },
  "request_version": { "op": "starts-with", "values": ["5."] }
}
```

Apply flow:

1. `PUT /v2/insights/{owner}/filters?filter_scope=global`
2. Read returned `id`
3. Call analytics endpoint with `?filter_id=<id>`
