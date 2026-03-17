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
- Create/choose a filter scope (`global` for saved/reusable filters, `adhoc` for one-off analysis)
- Construct a `SetInsightsFilters` JSON payload
- `PUT /v2/insights/{owner}/filters?filter_scope=global`
- Optionally attach a stable name with `POST /v2/insights/{owner}/filters/{filter_id}/name`
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

## 8) Inspect existing saved filters

Prompt:
- "List our named insights filters and show me the one for enterprise accounts"

Expected behavior:
- Call `GET /v2/insights/{owner}/filters/named`
- Return matching names plus the associated filter definition or `filter_id`
- If there is no exact match, say so and suggest creating or renaming one

## 9) Temporary ad hoc filter

Prompt:
- "Use an ad hoc filter for traffic from Germany on 6.x just for this analysis"

Expected behavior:
- Choose `filter_scope=adhoc`
- Construct the minimal `SetInsightsFilters` payload
- `PUT /v2/insights/{owner}/filters?filter_scope=adhoc`
- Use the returned `id` as `filter_id` on the follow-up analytics call
