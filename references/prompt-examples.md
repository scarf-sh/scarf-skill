# Canonical Prompt Examples

Use these as acceptance examples for v1 behavior.

## 1) Package performance

Prompt:
- "How did package `acme/widget` perform in the last 30 days?"

Expected behavior:
- Resolve org/package + date range
- Return trend summary + key metrics + one suggestion

## 2) Weekly change detection

Prompt:
- "What changed this week compared to last week for our top package?"

Expected behavior:
- Compare bounded windows
- Return directional deltas and confidence caveats

## 3) Lead follow-up shortlist

Prompt:
- "Who are the top orgs we should follow up with this week?"

Expected behavior:
- Use lead/funnel data where available
- Return concise ranked shortlist with reason field

## 4) Referrer insight

Prompt:
- "Where is most adoption traffic coming from right now?"

Expected behavior:
- Return top referrers/channels
- Include date range and any known attribution limits

## 5) Export status

Prompt:
- "Did my latest export finish, and where do I get it?"

Expected behavior:
- Check export status endpoint(s)
- Return status + retrieval path + next action

## 6) Ambiguous request

Prompt:
- "How are we doing?"

Expected behavior:
- Ask one clarifying question (org/package + date range), then proceed

## 7) Build a saved insights filter (examples)

Prompt:
- "Create a saved filter for Fortune 500 companies in the United States on version 5.x and then use it for company rollup for last 7 days"

Expected behavior:
- Create/choose a filter scope (default `global` unless user asks for `adhoc`)
- Construct a `SetInsightsFilters` JSON payload
- `PUT /v2/insights/{owner}/filters?filter_scope=global`
- Use returned `id` as `filter_id` on supported analytics calls

Example payload:
```json
{
  "name": "Fortune 500 / US / version 5.x",
  "company_is_fortune_500": { "value": true },
  "company_country": { "op": "equals", "values": ["United States"] },
  "request_version": { "op": "starts-with", "values": ["5."] }
}
```
