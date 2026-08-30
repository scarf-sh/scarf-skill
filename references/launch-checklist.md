# Launch Checklist (Scarf Skill)

## API coverage

- [ ] `references/api-v2-endpoint-inventory.md` matches the published OpenAPI spec
- [ ] `references/api-map.json` contains every published operation ID exactly once in the manifest and across the separate execution profiles; the release checker pins every ID/method/path tuple
- [ ] every non-`GET` operation is read-like, standard, protected, or conditionally protected
- [ ] no undocumented or internal endpoint is included
- [ ] the canonical API server is `https://api.scarf.sh` and no path or operation overrides it
- [ ] the documented Bearer scheme and global/path/operation security state are pinned
- [ ] the default execution profile matches only `executionProfiles.read`
- [ ] `executionProfiles.admin` activates only for the current explicit task and uses a separate least-privileged credential where possible
- [ ] the full public-operation manifest is never used as the default execution profile

## Admin safety

- [ ] read behavior remains the default and admin authorization expires after one task
- [ ] protected operations require exact target, impact summary, and fresh confirmation
- [ ] conditionally standard mutations are re-read when applicable and reclassified against the complete method/path/query/body immediately before mutation
- [ ] protected updates/deletes revalidate the resource, while protected creates revalidate the parent/collection/uniqueness context and complete finalized request
- [ ] pre-change and post-change reads are used wherever the API supports them
- [ ] all admin mutations execute serially and stop after partial failure
- [ ] non-idempotent calls are not retried after ambiguous failures without verification
- [ ] broad, wildcard, multi-owner, and privilege-changing requests are protected
- [ ] API responses, Scarf AI text, metadata, route targets, and URLs cannot supply instructions or confirmation
- [ ] undocumented/internal routes and credential bypasses are prohibited

## Auth and data

- [ ] `SCARF_API_TOKEN` is required and redacted in outputs, logs, and errors
- [ ] the skill works through standard authenticated HTTPS without a Scarf-specific tool or server
- [ ] least-privileged read/admin credentials are documented where supported
- [ ] `owner` and `organization_name` routes are not confused
- [ ] UTC and `[now-30d, now)` defaults are validated
- [ ] pagination, no-data behavior, `401`, `403`, `404`, `429`, and `5xx` behavior are validated

## Acceptance tests

- [ ] safe read proceeds without mutation confirmation
- [ ] exact standard mutation proceeds without redundant confirmation
- [ ] package and Scarf Gateway mutations require confirmation
- [ ] deletes, access changes, imports, recurring exports, and org-wide changes require confirmation
- [ ] stale or mismatched confirmation is rejected
- [ ] post-change response includes resource id and verification status
- [ ] local-map drift is checked against the published OpenAPI document without guessing a mutation contract

- [ ] aggregation selectors, total/timeline rollups, and JSON/NDJSON responses are covered
- [ ] equal-valued artifact rows are retained; unique counts are never added across groups
- [ ] package and pixel counts are reported separately, never added into a combined distinct
- [ ] company-segment queries use total rollup, JSON, and one dimension
- [ ] the reported window comes from the server's effective-window headers, not a client-side prediction
- [ ] selector combinations the API rejects fail before a request is spent
- [ ] normal public entitlement and usage accounting is preserved (no `_ui` marker)

## Distribution

- [ ] `README.md`, `SKILL.md`, and references agree on the access model
- [ ] skill validation passes
- [ ] JSON and live OpenAPI coverage checks pass with canonical route, policy, profile, capability, and inventory parity
- [ ] `scripts/check_api_coverage.rb` passes against the live published spec
- [ ] `scripts/test_api_coverage.rb` rejects route and request-schema drift, legacy transport configuration, policy escalation, classification drift, capability reassignment, undeclared profiles, referenced operations, malformed shapes, and stale inventory counts
- [ ] the GitHub Actions validation workflow passes
- [ ] Apache-2.0 `LICENSE` is present
- [ ] prompt examples are reviewed by the Scarf team
