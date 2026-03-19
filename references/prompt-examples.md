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

## 7) Build an insights filter (default scope behavior)

Prompt:
- "Create a filter for Fortune 500 companies in the United States on version 5.x and then use it for company rollup for last 7 days"

Expected behavior:
- Choose `scope=adhoc` by default because the user did not explicitly ask for `global`
- Construct an `InsightsFilterInput` JSON payload
- `POST /v2/insights/{owner}/filters?scope=adhoc`
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

## 8) Explicit global scope requires confirmation

Prompt:
- "Create this filter as a global filter for the whole org"

Expected behavior:
- Ask one confirmation before creating the filter
- Only after confirmation, call `POST /v2/insights/{owner}/filters?scope=global`
- State clearly that the global filter will affect org-wide analytics until removed

## 9) List saved insights filters

Prompt:
- "Show me our saved filters"

Expected behavior:
- Call `GET /v2/insights/{owner}/filters?saved_only=true&scope=global`
- Return concise filter names/ids and ask one follow-up question only if needed

## 10) Update an existing filter

Prompt:
- "Update filter `f_123` to only include Germany and France"

Expected behavior:
- Resolve the target `filter_id`
- Construct the updated `InsightsFilterInput` payload
- `PUT /v2/insights/{owner}/filters/{filter_id}`
- Confirm the updated filter and its resulting scope or name if present

## 11) Delete a temporary filter

Prompt:
- "Delete the temporary filter we just created"

Expected behavior:
- Resolve the target `filter_id`
- `DELETE /v2/insights/{owner}/filters/{filter_id}`
- Confirm deletion and note that analytics calls must no longer reference that `filter_id`
