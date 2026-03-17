# Scarf Data Assistant v1 Spec

## 1) Goal

Enable a Scarf user to connect their own API token and complete common Scarf workflows from an AI assistant without custom scripts.

## 2) Naming and packaging

- Repo name: `scarf-skill`
- Keep repo private until first public release process is complete.
- First distribution targets:
  1. GitHub OSS repo
  2. ClawHub listing
  3. Docs page on `docs.scarf.sh`

## 3) Reuse strategy for private MCP server

Use MCP internals as inspiration, but avoid coupling v1 release to private MCP runtime.

Recommended architecture:

- `ScarfTransport` interface
  - `request(method, path, query, body)`
- `RestTransport` implementation (v1)
- `McpTransport` implementation (future)
- `ScarfClient` (shared domain calls, pagination, retries, normalization)

Result: public skill ships now; MCP can become a drop-in backend later.

## 4) v1 scope (tight, useful)

Ship 6 core capabilities:

1. **Org snapshot**
   - answer: high-level usage trend, top packages, top geos/orgs (as available)
2. **Package snapshot**
   - answer: package health over date range (downloads/events trend)
3. **Top referrers / acquisition context**
   - answer: where traffic/adoption is coming from
4. **Lead/funnel summary**
   - answer: recent OQL/adoption stage changes
5. **Export helper**
   - answer: locate export jobs and summarize status
6. **Natural-language Q&A with guardrails**
   - convert prompts into bounded API queries with explicit date ranges

Out of scope for v1:
- all write automation
- multi-org orchestration
- background jobs and scheduling inside the skill itself

## 5) Auth and security model

- Input secret: `SCARF_API_TOKEN` (required)
- Organization scope (`owner`) is required before execution
- Optional package/entity defaults via env vars or explicit params
- Never print token in outputs, logs, traces, or errors
- Sanitize headers before debug output
- Add `--debug` mode that redacts secret fields

Error mapping (minimum):
- `401`: invalid/expired token -> re-auth with a valid Scarf API token
- `403`: insufficient permission -> token lacks access to this org/package
- `404`: resource missing or inaccessible
- `429`: rate-limited; retry with backoff and narrowed query window
- `5xx`: transient server issue; retry + fallback messaging

## 6) API strategy

Use `scarf-repo/api-server/api-v2-final.yaml` as source of truth for public API coverage.

Implementation approach:
- maintain internal endpoint map: `references/api-map.v1.json`
- record for each operation:
  - method
  - path
  - required params
  - pagination model
  - primary response fields

Current status:
- endpoint inventory: `references/api-v2-endpoint-inventory.md`
- capability mapping + default-deny allowlist: `references/api-map.v1.json`

## 7) Query defaults and filters

- Timezone: **UTC** for all normalization and output labels
- Default date window (if omitted): last **30 days** `[now-30d, now)` in UTC
- Use `filter_id` when endpoint supports it and filter context is provided
- Require explicit override for unusually broad windows (> 365 days)

### Filter catalog + examples

See `references/filter-catalog.md` for:
- full list of filter keys
- operator enums
- copy/paste examples (e.g. Fortune 500 + US + version prefix)

## 8) Assistant behavior contract

For each user request, always return:

1. **Answer first** (one short paragraph or bullets)
2. **Evidence** (key metrics and date range)
3. **Assumptions/filters** (org, package, timezone, filter_id if used)
4. **Next useful action** (one suggestion)

If request is ambiguous, ask one clarifying question only.

## 9) Testing and quality

Minimum test matrix:

- auth: valid / invalid / forbidden
- org required behavior: missing owner should block with clear prompt
- query: default 30-day UTC window and custom windows
- pagination: single-page and multi-page responses
- filter usage: with and without `filter_id`
- no-data response behavior
- retry on 429/5xx
- schema drift tolerance for non-critical fields

Golden prompt tests (text fixtures):
- How did package X do last 30 days?
- Which companies started showing up this week?
- What changed vs previous period?
- Give me top opportunities to follow up on today.

## 10) Initial repo structure

```text
scarf-skill/
  SKILL.md
  references/
    v1-spec.md
    launch-checklist.md
    prompt-examples.md
```

Target structure:

```text
scarf-skill/
  SKILL.md
  references/
```

## 11) Release plan

Phase 1 (now): finalize capability spec + endpoint map + release docs
Phase 2: private dogfood with 2-3 Scarf users
Phase 3: lightweight SemVer tag `v0.1.0` (private)
Phase 4: public OSS + ClawHub + docs launch page
