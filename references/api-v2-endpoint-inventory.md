# Scarf API Endpoint Inventory (Public Spec Source)

Published spec: `https://api.scarf.sh/static/api-v2.yaml`

Aggregation export exception: use public v3 `GET /v3/insights/{owner}/aggregations/export` for aggregate analytics. Do not use the legacy v2 `GET /v2/packages/{owner}/aggregates` route in new skill flows.

Notes:
- Inventory generated from the published v2 OpenAPI spec.
- The document contains published v2 and v3 paths despite its filename.
- Snapshot checked on 2026-08-30.
- Ignore internal-only fields unless they are documented for external users.

## Pagination (applies to all list endpoints)

List endpoints (`GET` operations that return a collection — packages, routes, tracking pixels, filters, exports, members, imports, etc.) silently truncate to **10 results per page** by default and return **no pagination metadata**:

- No `Link` header.
- No `total`, `count`, `next`, or `has_more` field in the response body.
- Some endpoints wrap results in `{"results": [...]}`; others (notably `/routes`) return a bare JSON array. Neither shape carries pagination state.

**Implication:** a 10-row response is indistinguishable from a complete result set. Treating it as complete is a real footgun — for example, `GET /v2/packages/{owner}/{package_id}/routes` on a package with 23 configured routes returns only the first 10, hiding routes that genuinely exist.

**Required behavior:**
- Always pass an explicit `?per_page=N` on list calls. Default to a value large enough to cover realistic result sets (e.g. `per_page=200`).
- If exactly `per_page` rows come back, do not assume that's the full list — page forward with `?page=2`, `?page=3`, … until a short page is returned.
- When summarizing results to the user, never imply completeness from a single page; if you didn't paginate to exhaustion, say so.

Total operations: 85

## Collections (5)

| operationId | Method | Path | Summary |
|---|---|---|---|
| `getCollections` | `GET` | `/v2/collections/{owner}` | List collections |
| `createCollection` | `POST` | `/v2/collections/{owner}` | Create collection |
| `deleteCollection` | `DELETE` | `/v2/collections/{owner}/{collection_id}` | Delete collection |
| `getCollection` | `GET` | `/v2/collections/{owner}/{collection_id}` | Get collection |
| `updateCollection` | `PUT` | `/v2/collections/{owner}/{collection_id}` | Update collection |

## Company (5)

| operationId | Method | Path | Summary |
|---|---|---|---|
| `exportCompanyPackageRollup` | `GET` | `/v2/companies/{owner}/package-rollup` | Export the company event rollups for each package |
| `exportCompanyPixelRollup` | `GET` | `/v2/companies/{owner}/pixel-rollup` | Export the company event rollups for each pixel |
| `exportEntityScarfScores` | `GET` | `/v2/companies/{owner}/scoring` | Export company Scarf scores |
| `exportEntityCompanyEvents` | `GET` | `/v2/companies/{owner}/{domain}/events` | Export company events |
| `exportCompanyRollup` | `GET` | `/v2/packages/{owner}/company-rollup` | Export Company Data |

## Domains (2)

| operationId | Method | Path | Summary |
|---|---|---|---|
| `requestDomainVerification` | `POST` | `/v2/domains/{owner}/{domain_ref}/request-verification` | Explicitly requests domain verification |
| `getDomainStatus` | `GET` | `/v2/domains/{owner}/{domain_ref}/status` | Returns the status of a domain |

## External event import (7)

| operationId | Method | Path | Summary |
|---|---|---|---|
| `getEventImports` | `GET` | `/v2/imports/{owner}` | Retrieve a list of event imports
 |
| `getEventImport` | `GET` | `/v2/imports/{owner}/{event_import_id}` | Retrieve a specific event import
 |
| `abortEventImport` | `POST` | `/v2/imports/{owner}/{event_import_id}/abort` | Abort event import
 |
| `getImportLogs` | `GET` | `/v2/imports/{owner}/{event_import_id}/log` | Retrieve the import log for an event import |
| `importPackageEvents` | `POST` | `/v2/packages/{owner}/{package_id}/import` | Import external package events in bulk
 |
| `importTrackingPixelEvents` | `POST` | `/v2/tracking-pixels/{owner}/{tracking_pixel_id}/import` | Import external tracking-pixel events in bulk
 |
| `importEvents` | `POST` | `/v2/{owner}/import` | Import events in bulk
 |

## Insights Filters (7)

| operationId | Method | Path | Summary |
|---|---|---|---|
| `listInsightsFilters` | `GET` | `/v2/insights/{owner}/filters` | List filters |
| `createInsightsFilter` | `POST` | `/v2/insights/{owner}/filters` | Create filter |
| `getInsightsFilter` | `GET` | `/v2/insights/{owner}/filters/{filter_id}` | Get filter |
| `updateInsightsFilter` | `PUT` | `/v2/insights/{owner}/filters/{filter_id}` | Update filter |
| `deleteInsightsFilter` | `DELETE` | `/v2/insights/{owner}/filters/{filter_id}` | Delete filter |
| `getUserDefinedVariables` | `GET` | `/v2/insights/{owner}/user-defined-variables` | Gets persisted user-defined variables |
| `setUserDefinedVariables` | `POST` | `/v2/insights/{owner}/user-defined-variables` | Sets persisted user-defined variables |

## Organization (3)

| operationId | Method | Path | Summary |
|---|---|---|---|
| `deletePendingOrganizationInvite` | `DELETE` | `/v2/organizations/{organization_name}/members/invites` | Delete pending organization invite |
| `getOrganizationPendingInvites` | `GET` | `/v2/organizations/{organization_name}/members/invites` | Get all pending invites for the organization |
| `inviteMember` | `POST` | `/v2/organizations/{organization_name}/members/invites` | Invite a member who is not yet a scarf user by email |

## Organizations (8)

| operationId | Method | Path | Summary |
|---|---|---|---|
| `getOrganization` | `GET` | `/v2/organizations/{organization_name}` | Get organization |
| `updateOrganization` | `PUT` | `/v2/organizations/{organization_name}` | Update organization |
| `getOrganizationDownloadFeed` | `GET` | `/v2/organizations/{organization_name}/download-feed` | Get organization-wide download feed |
| `getOrganizationMembers` | `GET` | `/v2/organizations/{organization_name}/members` | Get organization members |
| `addOrganizationMember` | `POST` | `/v2/organizations/{organization_name}/members` | Add organization member |
| `deleteOrganizationMember` | `DELETE` | `/v2/organizations/{organization_name}/members/{organization_member}` | Delete organization member |
| `getOrganizationMember` | `GET` | `/v2/organizations/{organization_name}/members/{organization_member}` | Get organization member |
| `updateOrganizationMemberRole` | `PUT` | `/v2/organizations/{organization_name}/members/{organization_member}` | Update member role |

Note:
- `GET /v2/organizations/{organization_name}/download-feed` is the endpoint to use when the user asks for Dependency Radar, the supply chain security feed, `download-feed`, or the org-wide download feed.
- Required query params are `domain` and `date` (`YYYY-MM-DD`, UTC).
- Do not substitute `/v2/companies/{owner}/{domain}/events` or `/v2/packages/{owner}/company-rollup` when the user asks for Dependency Radar, the supply chain security feed, or `download-feed`.

## Packages (27)

| operationId | Method | Path | Summary |
|---|---|---|---|
| `deleteScheduledExport` | `DELETE` | `/v2/exports/{owner}/schedule-export` | Delete a scheduled export |
| `getScheduledExports` | `GET` | `/v2/exports/{owner}/schedule-export` | Retrieve currently scheduled daily exports |
| `scheduleExport` | `POST` | `/v2/exports/{owner}/schedule-export` | Schedule Daily Export |
| `getScheduledExportsHistory` | `GET` | `/v2/exports/{owner}/schedule-export-history` | Retrieve recent scheduled exports history |
| `getPackages` | `GET` | `/v2/packages/{owner}` | List packages |
| `createPackage` | `POST` | `/v2/packages/{owner}` | Creates a new package |
| `exportEntityAggregates` | `GET` | `/v2/packages/{owner}/aggregates` | Deprecated legacy aggregate export; do not use for skill flows |
| `exportEntityPackageEvents` | `GET` | `/v2/packages/{owner}/events` | Export all package events |
| `getPackagesOverview` | `GET` | `/v2/packages/{owner}/overview` | List packages overview |
| `deletePackage` | `DELETE` | `/v2/packages/{owner}/{package_id}` | Deletes a package |
| `getPackageById` | `GET` | `/v2/packages/{owner}/{package_id}` | Get package (by id) |
| `updatePackage` | `PUT` | `/v2/packages/{owner}/{package_id}` | Updates an existing package |
| `getPackageDomains` | `GET` | `/v2/packages/{owner}/{package_id}/domains` | Get package domains |
| `createPackageDomain` | `POST` | `/v2/packages/{owner}/{package_id}/domains` | Create package domain. |
| `deletePackageDomain` | `DELETE` | `/v2/packages/{owner}/{package_id}/domains/{domain_id}` | Delete package domain |
| `getPackageDomain` | `GET` | `/v2/packages/{owner}/{package_id}/domains/{domain_id}` | Get package domain |
| `exportPackageEvents` | `GET` | `/v2/packages/{owner}/{package_id}/events` | Export package events |
| `getPackagePermissions` | `GET` | `/v2/packages/{owner}/{package_id}/permissions` | Get package permissions |
| `setPackagePermission` | `POST` | `/v2/packages/{owner}/{package_id}/permissions` | Set package permission (only when owner is a user) |
| `deletePackagePermission` | `DELETE` | `/v2/packages/{owner}/{package_id}/permissions/{username}` | Delete package permission |
| `getPackageRoutes` | `GET` | `/v2/packages/{owner}/{package_id}/routes` | Get package routes (only for File Packages) |
| `createPackageRoute` | `POST` | `/v2/packages/{owner}/{package_id}/routes` | Create package route (only for File Packages) |
| `deletePackageRoute` | `DELETE` | `/v2/packages/{owner}/{package_id}/routes/{route_id}` | Delete package route |
| `getPackageRoute` | `GET` | `/v2/packages/{owner}/{package_id}/routes/{route_id}` | Get package route (only for File Packages) |
| `updatePackageRoute` | `PUT` | `/v2/packages/{owner}/{package_id}/routes/{route_id}` | Update package route (only for File Packages) |
| `getPackageTrackingPixels` | `GET` | `/v2/packages/{owner}/{package_id}/tracking-pixels` | Get tracking pixels |
| `getPackageByName` | `GET` | `/v2/packages/{owner}/{package_type}/{package_name}` | Get package (by name) |

## Search (1)

| operationId | Method | Path | Summary |
|---|---|---|---|
| `search` | `POST` | `/v2/search` | Searches an entities Packages, Tracking Pixels |

## Tracking Pixels (12)

| operationId | Method | Path | Summary |
|---|---|---|---|
| `getPixelsOverview` | `GET` | `/v2/pixels/{owner}/overview` | List pixels overview |
| `getTrackingPixels` | `GET` | `/v2/tracking-pixels/{owner}` | Get tracking pixels |
| `createTrackingPixel` | `POST` | `/v2/tracking-pixels/{owner}` | Create tracking pixel |
| `exportEntityTrackingPixelEvents` | `GET` | `/v2/tracking-pixels/{owner}/events` | Export all tracking pixel events |
| `deleteTrackingPixel` | `DELETE` | `/v2/tracking-pixels/{owner}/{tracking_pixel_id}` | Delete tracking pixel |
| `getTrackingPixel` | `GET` | `/v2/tracking-pixels/{owner}/{tracking_pixel_id}` | Get tracking pixel |
| `updateTrackingPixel` | `PUT` | `/v2/tracking-pixels/{owner}/{tracking_pixel_id}` | Update tracking pixel |
| `getTrackingPixelDomains` | `GET` | `/v2/tracking-pixels/{owner}/{tracking_pixel_id}/domains` | Get Tracking Pixel Domains |
| `createTrackingPixelDomain` | `POST` | `/v2/tracking-pixels/{owner}/{tracking_pixel_id}/domains` | Create tracking pixel domain |
| `deleteTrackingPixelDomain` | `DELETE` | `/v2/tracking-pixels/{owner}/{tracking_pixel_id}/domains/{domain_id}` | Delete Tracking Pixel Domain |
| `getTrackingPixelDomain` | `GET` | `/v2/tracking-pixels/{owner}/{tracking_pixel_id}/domains/{domain_id}` | Get Tracking Pixel Domain |
| `exportTrackingPixelEvents` | `GET` | `/v2/tracking-pixels/{owner}/{tracking_pixel_id}/events` | Export tracking pixel events |

## Users (2)

| operationId | Method | Path | Summary |
|---|---|---|---|
| `getUserInformation` | `GET` | `/v2/users/{username}` | Get user |
| `getUserOrganizations` | `GET` | `/v2/users/{username}/organizations` | List user organizatons |

## v3 Insights and AI (6)

| operationId | Method | Path | Summary |
|---|---|---|---|
| `export_entity_aggregations` | `GET` | `/v3/insights/{owner}/aggregations/export` | Export Entity Aggregations |
| `get_provider_adoption_leaderboard` | `GET` | `/v3/public/ai-provider-adoption` | Get Provider Adoption Leaderboard |
| `chat_with_scarf_ai` | `POST` | `/v3/organizations/{owner}/ai/chat` | Chat with Scarf AI |
| `create_positive_endpoint_feedback` | `POST` | `/v3/organizations/{owner}/endpoint-feedback/matches` | Create Positive Endpoint Feedback |
| `create_negative_endpoint_feedback` | `POST` | `/v3/organizations/{owner}/endpoint-feedback/unmatches` | Create Negative Endpoint Feedback |
| `request_provider_adoption_access` | `POST` | `/v3/public/ai-provider-adoption/access` | Capture a lead and email the unlisted leaderboard URL (protected) |
