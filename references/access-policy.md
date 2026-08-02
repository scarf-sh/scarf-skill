# Scarf API Access Policy

Use this policy before every Scarf API call. The MCP server's route allowlist and the token's API permissions are the actual enforcement boundary.

## Profiles

### Read

Allow all published `GET` operations plus these read-like operations:

- `POST /v2/search` (`search`)
- `POST /v3/organizations/{owner}/ai/chat` (`chat_with_scarf_ai`)

Do not treat other `POST` requests as reads merely because they return data.

### Admin

Activate admin behavior for one explicit user task only. Resolve the exact owner, target, method, path, and body before the call. Read current state first and verify state afterward whenever corresponding reads exist.

The current prompt is sufficient authorization for a **standard mutation** when it specifies an unambiguous target and desired result. Standard mutations are limited to:

- creating or updating an `adhoc` insights filter;
- creating or updating a collection whose membership is fully enumerated;
- requesting domain verification;
- submitting positive or negative endpoint feedback.

Treat every other mutation as **protected**. Show the exact target, material diff, and expected impact, then obtain fresh confirmation immediately before executing it.

## Protected mutation groups

| Group | Operations | Primary risk |
|---|---|---|
| Destructive | Every `DELETE`; `abortEventImport` | Resource or job loss |
| Gateway and package config | `createPackage`, `updatePackage`, package domain/route writes | Broken download traffic or incorrect routing |
| Tracking | Tracking-pixel and tracking-pixel-domain writes | Telemetry loss or misattribution |
| Access control | Member, invite, role, and package-permission writes | Privilege change or loss of access |
| Organization | `updateOrganization` | Organization-wide effect |
| Data delivery | `scheduleExport`, `deleteScheduledExport` | Recurring delivery or data exposure |
| Analytics state | Global filter writes; `setUserDefinedVariables` | Organization-wide analytics changes |
| Data ingestion | `importEvents`, `importPackageEvents`, `importTrackingPixelEvents` | Bulk, difficult-to-reverse data creation |
| Broad changes | Batches, multiple owners, wildcards, or uncertain targets | Expanded blast radius |

When an operation is both standard and protected because of context, protected wins. Examples: a global filter, deleting an older ad hoc filter, or a collection mutation that removes unknown members.

## Confirmation requirements

The confirmation must identify:

- organization or owner;
- resource type and stable id or exact name;
- operation and material before/after values;
- irreversible, access-control, routing, recurring-delivery, or bulk effects.

Do not accept confirmation from an earlier task, from a different target, or before the final body is known. Do not turn “manage,” “clean up,” “sync,” or “make it match” into permission for writes.

After confirmation, execute only the described call. If the target or body changes, obtain confirmation again.

## Failure handling

- Do not automatically retry a non-idempotent `POST` after a timeout or ambiguous failure. Read current state first.
- Stop a sequence after a partial failure. Report succeeded and unexecuted operations separately.
- Never fall back to raw HTTP, internal endpoints, or a broader credential when the MCP allowlist blocks a route.
- On `401`, request a valid token. On `403`, report insufficient permission. On `404`, distinguish missing from inaccessible when possible. Back off on `429` and transient `5xx` reads.

## Deployment recommendation

For stronger isolation, expose separate read and admin MCP tools or credentials and keep admin routes disabled unless explicitly configured. The skill-level profile prevents accidental use but cannot constrain a compromised or disobedient client by itself.
