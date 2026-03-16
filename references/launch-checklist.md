# Launch Checklist (Scarf Data Assistant)

## Product

- [ ] v1 scope frozen (no new capabilities during hardening)
- [ ] clear non-goals documented
- [ ] sample prompts reviewed by Scarf team

## API + Data

- [ ] endpoint inventory complete (`api-map.json` planned)
- [ ] per-capability endpoint mapping complete
- [ ] pagination and date-window behavior validated
- [ ] no-data behavior tested for all capabilities

## Security

- [ ] token handling reviewed
- [ ] token redaction verified in logs/errors
- [ ] read-only default behavior enforced
- [ ] explicit confirmation required for mutating operations

## Reliability

- [ ] retry/backoff on 429 and 5xx
- [ ] timeout policy defined
- [ ] structured, user-friendly error messages shipped

## Docs + Distribution

- [ ] GitHub repo public with clear examples
- [ ] ClawHub listing published
- [ ] docs.scarf.sh page added (quickstart + examples)
- [ ] versioning + compatibility policy published

## GTM / Feedback

- [ ] dogfood with internal team + 2-3 design partners
- [ ] telemetry for success/failure (non-sensitive)
- [ ] issue template for user-reported API mismatches
