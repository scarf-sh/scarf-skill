# v0.1.0 Release Checklist (lightweight SemVer tag)

- [ ] Confirm repo is still private
- [ ] Confirm docs align on:
  - `SCARF_API_TOKEN` required
  - UTC handling
  - default 30-day window
  - org-required behavior
  - v1 GET-only policy
  - `filter_id` usage guidance
- [ ] Confirm Apache-2.0 `LICENSE` exists
- [ ] Confirm no stale/deprecated file references remain
- [ ] Final sanity read of `SKILL.md` + references
- [ ] Commit release-prep docs
- [ ] Create lightweight tag: `git tag v0.1.0`
- [ ] Push commit + tag: `git push origin main --follow-tags`
- [ ] Rename repo to `scarf-skill` (if not already)
- [ ] Update `SKILL.md` frontmatter `name: scarf-skill`
- [ ] Re-run quick doc link/reference check after rename
