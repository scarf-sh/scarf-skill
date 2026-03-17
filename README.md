# scarf-skill (private pre-release)

Private prep repo for the first public release of the Scarf skill.

## v1 contract (read-only)

- Auth env var: `SCARF_API_TOKEN` (required)
- Organization scope: required (`owner` / org slug)
- Timezone handling: **UTC only** for all defaults and reporting
- Default date window when missing: last **30 days** (`[now-30d, now)` in UTC)
- API scope: **GET-only** (no create/update/delete in v1)
- Optional narrowing: use `filter_id` when endpoint supports it

## Included files

- `SKILL.md`
- `references/v1-spec.md`
- `references/v1-allowlist.md`
- `references/api-v2-endpoint-inventory.md`
- `references/api-map.v1.json`
- `references/prompt-examples.md`
- `references/launch-checklist.md`
- `RELEASE_CHECKLIST.md`
- `LICENSE` (Apache-2.0)

## Privacy/release posture

- Keep repo private until first tag (`v0.1.0`) is cut.
- Public release happens immediately after tag + repo rename validation.
