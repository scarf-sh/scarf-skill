# Launch Checklist (Scarf Data Assistant)

## Product

- [ ] v1 scope frozen (no new capabilities during hardening)
- [ ] non-goals documented and accepted
- [ ] sample prompts reviewed by Scarf team
- [ ] positioning aligned to `scarf-skill` naming

## API + Data

- [ ] endpoint inventory complete (`references/api-v2-endpoint-inventory.md`)
- [ ] capability mapping complete (`references/api-map.v1.json`)
- [ ] UTC date handling validated end-to-end
- [ ] default 30-day window validated (`[now-30d, now)` UTC)
- [ ] org-required behavior validated (missing owner blocks execution)
- [ ] `filter_id` behavior validated for supported endpoints
- [ ] no-data behavior tested for all capabilities

## Security

- [ ] `SCARF_API_TOKEN` required
- [ ] token redaction verified in logs/errors
- [ ] read-only default behavior enforced
- [ ] GET-only v1 policy enforced

## Reliability

- [ ] retry/backoff on 429 and 5xx
- [ ] timeout policy defined
- [ ] user-friendly error messages shipped

## Docs + Distribution

- [ ] Apache-2.0 `LICENSE` present
- [ ] `README.md` + `SKILL.md` + references align on auth/defaults/UTC/filter behavior
- [ ] no deprecated/removed file references remain
- [ ] lightweight release tag plan documented (`v0.1.0`)
- [ ] repo remains private until first tag

## GTM / Feedback

- [ ] dogfood with internal team + 2-3 design partners
- [ ] telemetry for success/failure (non-sensitive)
- [ ] issue template for API mismatch reports
