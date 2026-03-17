# scarf-skill (private pre-release)

Private prep repo for the first public release of the Scarf skill.

## Positioning / rename status

- Canonical repo name: **`scarf-skill`** (remote updated).
- Local working directory may still be `scarf-ai-skill` depending on clone path.
- Rename/release prep steps have been applied.

### Rename/release prep status

1. GitHub remote points to `scarf-sh/scarf-skill`.
2. Skill frontmatter `name:` is `scarf-skill`.
3. Internal references checked/updated for renamed repo intent.
4. Lightweight SemVer tag target: `v0.1.0`.

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
