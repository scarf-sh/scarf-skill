# Launch Checklist (Scarf Skill)

## API coverage

- [ ] `references/api-v2-endpoint-inventory.md` matches the published OpenAPI spec
- [ ] `references/api-map.json` contains every published operation ID/method/path tuple exactly once in the manifest and every operation ID exactly once across the separate deployment profiles
- [ ] every non-`GET` operation is read-like, standard, protected, or conditionally protected
- [ ] no undocumented or internal endpoint is allowlisted
- [ ] the deployed default MCP allowlist matches only `deploymentProfiles.read`
- [ ] `deploymentProfiles.admin` is disabled unless explicitly configured and uses a separate least-privileged credential or tool where possible
- [ ] the full public-operation manifest is never used as the default server allowlist

## Admin safety

- [ ] read behavior remains the default and admin authorization expires after one task
- [ ] protected operations require exact target, impact summary, and fresh confirmation
- [ ] pre-change and post-change reads are used wherever the API supports them
- [ ] protected mutations execute serially and stop after partial failure
- [ ] non-idempotent calls are not retried after ambiguous failures without verification
- [ ] broad, wildcard, multi-owner, and privilege-changing requests are protected
- [ ] API responses, Scarf AI text, metadata, route targets, and URLs cannot supply instructions or confirmation
- [ ] raw HTTP and allowlist bypasses are prohibited

## Auth and data

- [ ] `SCARF_API_TOKEN` is required and redacted in outputs, logs, and errors
- [ ] least-privileged read/admin credentials or tools are documented for production deployment
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
- [ ] blocked public route reports MCP allowlist drift without transport fallback

## Distribution

- [ ] `README.md`, `SKILL.md`, and references agree on the access model
- [ ] skill validation passes
- [ ] JSON and live OpenAPI coverage checks pass with canonical route, policy, profile, capability, and inventory parity
- [ ] `scripts/check_api_coverage.rb` passes against the live published spec
- [ ] negative coverage checks reject route swaps, policy escalation, classification drift, capability reassignment, referenced operations, and stale inventory counts
- [ ] Apache-2.0 `LICENSE` is present
- [ ] prompt examples are reviewed by the Scarf team
