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

## 12) Dependency Radar threat check

Prompt:
- "Check Dependency Radar for `example.com` on 2026-03-17 and flag anything suspicious"
- "Check the supply chain security feed for `example.com` on 2026-03-17"
- "Check the org download feed for `example.com` on 2026-03-17"

Expected behavior:
- Treat Dependency Radar, supply chain security feed, and org download feed as aliases
- Call `GET /v2/organizations/{organization_name}/download-feed?domain=example.com&date=2026-03-17`
- Summarize key signals for security teams: unusual user agents, geo anomalies, bursty package pulls, and unknown/automated clients
- Keep the output concise and action-oriented for human responders or downstream AI agents

## 13) Open beta handling for Dependency Radar

Prompt:
- "Use Dependency Radar for our org"
- "Use the supply chain security feed for our org"

Expected behavior:
- If feed access appears unavailable, clearly state this endpoint is currently open beta
- Tell the user to reach out to Scarf for help (e.g., Slack or `help@scarf.sh`)
- Offer to continue with adjacent analytics endpoints while access is being enabled

## 14) Explicit `download-feed` endpoint routing

Prompt:
- "check the `download-feed` endpoint in the scarf org for netflix.com, jan 9 2026"
- "check dependency radar in the scarf org for netflix.com, jan 9 2026"

Expected behavior:
- Recognize that Dependency Radar maps to the `download-feed` endpoint and must not be rerouted to company events or company rollup
- Call `GET /v2/organizations/scarf/download-feed?domain=netflix.com&date=2026-01-09`
- Return the direct result and explicitly state which endpoint was used
- If the endpoint errors, surface the exact missing/invalid query parameter instead of guessing another endpoint


## 15) Aggregate export routing

Prompt:
- "Export aggregate downloads for our packages last month"
- "Use aggregations export for the scarf org from 2026-04-01 to 2026-05-01"

Expected behavior:
- Route aggregate analytics to `GET /v3/insights/{owner}/aggregations/export`
- Do not call the legacy `GET /v2/packages/{owner}/aggregates` endpoint
- Include the date window and any selected dimensions/filters in the answer
- State that the v3 aggregation export endpoint was used
