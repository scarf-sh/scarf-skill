# 0.2.0 Release Checklist (lightweight SemVer tag)

- [ ] Confirm docs align on:
  - `SCARF_API_TOKEN` required
  - UTC handling
  - default 30-day window
  - org-required behavior
  - v1 default-`GET` plus bounded filter CRUD policy
  - `filter_id` usage guidance
- [ ] Confirm release docs no longer describe the repo as pre-release/private-only
- [ ] Confirm Apache-2.0 `LICENSE` exists
- [ ] Confirm no stale/deprecated file references remain
- [ ] Final sanity read of `SKILL.md` + references
- [ ] Create lightweight tag: `git tag 0.2.0`
- [ ] Push commit + tag: `git push origin main --follow-tags`
- [ ] Verify repo is named `scarf-skill`
- [ ] Verify `SKILL.md` frontmatter is `name: scarf-skill`
- [ ] Re-run quick doc link/reference check
