# Insights Filters Catalog (v1)

Canonical source for endpoints: published public OpenAPI specs. Filter management remains on the public v2 API (`https://api.scarf.sh/static/api-v2.yaml`); aggregate analytics use v3 `GET /v3/insights/{owner}/aggregations/export` rather than legacy v2 aggregates.

Canonical source for filter fields and operator guidance: Scarf-provided `InsightsFilterInput` description shared on 2026-03-18, to be preferred until the public docs are updated.

## Management endpoints

- `GET /v2/insights/{owner}/filters`
- `POST /v2/insights/{owner}/filters`
- `GET /v2/insights/{owner}/filters/{filter_id}`
- `PUT /v2/insights/{owner}/filters/{filter_id}`
- `DELETE /v2/insights/{owner}/filters/{filter_id}`

Common query params:

- `scope=adhoc|global` on list/create
- `saved_only=true|false` on list

Skill guidance:

- Default new filters to `adhoc` scope.
- Use `global` scope only when the user explicitly asks for it.
- Before creating a `global` filter, ask for one confirmation because it affects org-wide analytics until removed.
- User-defined variable writes are documented by the API, but remain out of v1 skill scope.

## Payload shape

Filter payloads are sent as JSON objects to:

- `POST /v2/insights/{owner}/filters?scope=global|adhoc`
- `PUT /v2/insights/{owner}/filters/{filter_id}`

You can optionally include:

- `name` (saved filter name)
- `crm_connections` (list of CRM integration ids)

Then apply the returned `id` via `filter_id` on supported analytics endpoints.

## Authoritative filter input description

Payload used to create or update insights filters.

Supported filter keys include:
`artifact_name`, `company_city`, `company_cloud_provider`, `company_confidence`,
`company_country`, `company_crm`, `company_domain`, `company_first_seen`,
`company_funnelstage`, `company_industry`, `company_industry_label`,
`company_is_forbes_2000`, `company_is_fortune_500`, `company_last_seen`,
`company_mom_trend`, `company_name`, `company_size`, `company_state`,
`company_techstack`, `company_wow_trend`, `endpoint_id`, `origin_id`,
`request_do_not_track`, `request_domain`, `request_is_bot`,
`request_origin_city`, `request_origin_country`, `request_origin_state`,
`request_origin_zipcode`, `request_platform`, `request_referrer`,
`request_user_agent`, `request_variable`, `request_variable_2`,
`request_variable_3`, `request_version`.

Common operators:
- text filters: `equals`, `not-equals`, `contains`, `does-not-contain`, `starts-with`, `does-not-start-with`, `is-empty`, `is-not-empty`
- date-range filters: `yesterday`, `last-week`, `last-month`, `last-3-month`, `last-year`, `not-last-week`, `not-last-2-weeks`
- trend filters: `up`, `stable`, `down`
- CRM filter op: `any`, `none`, `these`
- funnel stages: `interest`, `investigation`, `experimentation`, `ongoing-usage`, `inactive`
- confidence: `low`, `medium`, `high`
- company size: `size-1-10`, `size-11-50`, `size-51-250`, `size-251-1K`, `size-1K-5K`, `size-5K-10K`, `size-10K-50K`, `size-50K-100K`, `size-100K-plus`

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
{ "op": "up|stable|down" }
```

### Confidence filter (`NewConfidenceFilter`)

```json
{ "op": "low|medium|high" }
```

### Funnel stage filter (`NewFunnelStageFilter`)

```json
{ "op": "interest|investigation|experimentation|ongoing-usage|inactive" }
```

### Company size filter (`NewCompanySizeFilter`)

```json
{ "op": "size-1-10|size-11-50|size-51-250|size-251-1K|size-1K-5K|size-5K-10K|size-10K-50K|size-50K-100K|size-100K-plus" }
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

All supported keys in `InsightsFilterInput`:

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

1. `POST /v2/insights/{owner}/filters?scope=adhoc`
2. Read returned `id`
3. Call analytics endpoint with `?filter_id=<id>`
