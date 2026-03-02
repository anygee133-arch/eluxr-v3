# Supabase REST API Pattern Validation

**Tested:** 2026-03-02
**Plan:** 03-01 Task 2
**Purpose:** Validate all 5 CRUD operations against the live Supabase REST API from curl/Python, confirming the patterns every n8n sub-workflow will use.

## Test Environment

- **Supabase URL:** `https://llpnwaoxisfwptxvdfed.supabase.co`
- **API Gateway Key (apikey header):** `sb_publishable_9gnLO_J9HBxVta1f8Ecvxw_KO8huPYQ`
- **Authorization:** User JWT via `Authorization: Bearer <JWT>` (authenticated user pattern)
- **Test User:** testuser-a@eluxr.test (ID: `2488af7b-69ea-4bad-9876-ef28617b031c`)
- **Test Tables:** `icps`, `content_items`

## Dual-Header Authentication Pattern

All Supabase REST API calls require TWO headers:

```
Authorization: Bearer <JWT_TOKEN>
apikey: <GATEWAY_KEY>
```

**For n8n sub-workflows (service_role pattern):**

```
Authorization: Bearer <SERVICE_ROLE_JWT>
apikey: sb_publishable_9gnLO_J9HBxVta1f8Ecvxw_KO8huPYQ
```

The `apikey` header MUST use the `sb_publishable_*` (or `sb_secret_*`) format key. Legacy JWT keys are rejected by the API gateway for this header. The `Authorization` header accepts either a user JWT (RLS-enforced) or the service_role JWT (RLS-bypassed).

**For frontend (user JWT pattern):**

```
Authorization: Bearer <USER_JWT_FROM_SUPABASE_AUTH>
apikey: sb_publishable_9gnLO_J9HBxVta1f8Ecvxw_KO8huPYQ
```

## Test Results

### Test 1: SELECT (GET)

| Property | Value |
|----------|-------|
| Method | `GET` |
| URL | `{BASE}/rest/v1/{table}?{filters}&select={columns}` |
| Prefer Header | Not required |
| Status | **200 OK** |
| Result | **PASS** |

**Request:**
```
GET /rest/v1/icps?user_id=eq.2488af7b-69ea-4bad-9876-ef28617b031c&select=id,user_id,industry,icp_summary
Authorization: Bearer <USER_JWT>
apikey: sb_publishable_9gnLO_J9HBxVta1f8Ecvxw_KO8huPYQ
```

**Response (200):**
```json
[
  {
    "id": "a98b0bf4-f111-40b8-9b71-10dfca62b620",
    "user_id": "2488af7b-69ea-4bad-9876-ef28617b031c",
    "industry": "Technology",
    "icp_summary": "API pattern test ICP - upserted"
  }
]
```

**Key Patterns:**
- PostgREST filter syntax: `?column=operator.value` (e.g., `?user_id=eq.UUID`)
- Column selection: `?select=col1,col2,col3`
- Ordering: `?order=created_at.desc`
- Pagination: `?limit=10&offset=0`
- Response is always a JSON array (even for single row)

### Test 2: INSERT (POST)

| Property | Value |
|----------|-------|
| Method | `POST` |
| URL | `{BASE}/rest/v1/{table}` |
| Prefer Header | `return=representation` |
| Content-Type | `application/json` |
| Status | **201 Created** |
| Result | **PASS** |

**Request:**
```
POST /rest/v1/content_items
Authorization: Bearer <USER_JWT>
apikey: sb_publishable_9gnLO_J9HBxVta1f8Ecvxw_KO8huPYQ
Content-Type: application/json
Prefer: return=representation

{
  "user_id": "2488af7b-...",
  "title": "API Pattern Test - INSERT",
  "content": "Validating INSERT pattern for n8n HTTP Request nodes",
  "content_type": "text",
  "platform": "linkedin",
  "status": "draft"
}
```

**Response (201):**
```json
[
  {
    "id": "92cbdf53-0dca-4c1b-8ce5-f81586bb6101",
    "user_id": "2488af7b-69ea-4bad-9876-ef28617b031c",
    "campaign_id": null,
    "theme_id": null,
    "title": "API Pattern Test - INSERT",
    "content": "Validating INSERT pattern for n8n HTTP Request nodes",
    "content_type": "text",
    "platform": "linkedin",
    "status": "draft",
    "created_at": "2026-03-02T07:02:10.090637+00:00",
    "updated_at": "2026-03-02T07:02:10.090637+00:00"
  }
]
```

**Key Patterns:**
- `Prefer: return=representation` returns the created row (otherwise returns empty)
- Response includes server-generated fields: `id`, `created_at`, `updated_at`
- For batch INSERT: send a JSON array `[{...}, {...}]`

### Test 3: UPSERT (POST with merge-duplicates)

| Property | Value |
|----------|-------|
| Method | `POST` |
| URL | `{BASE}/rest/v1/{table}?on_conflict={column}` |
| Prefer Header | `resolution=merge-duplicates,return=representation` |
| Content-Type | `application/json` |
| Status | **200 OK** |
| Result | **PASS** |

**CRITICAL FINDING: `on_conflict` query parameter is REQUIRED.**

Without `?on_conflict=user_id`, PostgREST returns **409 Conflict** with error:
```json
{"code":"23505","message":"duplicate key value violates unique constraint \"icps_user_id_key\""}
```

**Request (working):**
```
POST /rest/v1/icps?on_conflict=user_id
Authorization: Bearer <USER_JWT>
apikey: sb_publishable_9gnLO_J9HBxVta1f8Ecvxw_KO8huPYQ
Content-Type: application/json
Prefer: resolution=merge-duplicates,return=representation

{
  "user_id": "2488af7b-...",
  "business_url": "https://upsert-test.com",
  "industry": "Tech Upserted",
  "icp_summary": "Upserted via API pattern test"
}
```

**Response (200):**
```json
[
  {
    "id": "a98b0bf4-f111-40b8-9b71-10dfca62b620",
    "user_id": "2488af7b-69ea-4bad-9876-ef28617b031c",
    "business_url": "https://upsert-test.com",
    "industry": "Tech Upserted",
    "icp_summary": "Upserted via API pattern test"
  }
]
```

**Key Patterns:**
- `?on_conflict=user_id` specifies which UNIQUE constraint column to use
- `Prefer: resolution=merge-duplicates` tells PostgREST to UPDATE on conflict instead of error
- Combined with `return=representation` to get the row back
- For tables without a UNIQUE constraint, UPSERT is not possible via REST API (use INSERT + PATCH instead)

**UPSERT pattern per table:**
| Table | on_conflict column | Constraint |
|-------|-------------------|------------|
| icps | `user_id` | `icps_user_id_key` (UNIQUE) |
| campaigns | `user_id,month` | `campaigns_user_id_month_key` (composite UNIQUE) |
| profiles | `id` | Primary key |

### Test 4: PATCH (update)

| Property | Value |
|----------|-------|
| Method | `PATCH` |
| URL | `{BASE}/rest/v1/{table}?{filter}` |
| Prefer Header | `return=representation` |
| Content-Type | `application/json` |
| Status | **200 OK** |
| Result | **PASS** |

**Request:**
```
PATCH /rest/v1/content_items?id=eq.92cbdf53-0dca-4c1b-8ce5-f81586bb6101
Authorization: Bearer <USER_JWT>
apikey: sb_publishable_9gnLO_J9HBxVta1f8Ecvxw_KO8huPYQ
Content-Type: application/json
Prefer: return=representation

{"status": "approved"}
```

**Response (200):**
```json
[
  {
    "id": "92cbdf53-0dca-4c1b-8ce5-f81586bb6101",
    "status": "approved",
    "title": "API Pattern Test - INSERT",
    ...
  }
]
```

**Key Patterns:**
- Filter in URL determines which row(s) to update
- Only include fields being updated in the body
- Without filter, ALL rows are updated (dangerous!)
- `Prefer: return=representation` returns the updated row

### Test 5: DELETE

| Property | Value |
|----------|-------|
| Method | `DELETE` |
| URL | `{BASE}/rest/v1/{table}?{filter}` |
| Prefer Header | Not required |
| Status | **204 No Content** |
| Result | **PASS** |

**Request:**
```
DELETE /rest/v1/content_items?id=eq.92cbdf53-0dca-4c1b-8ce5-f81586bb6101
Authorization: Bearer <USER_JWT>
apikey: sb_publishable_9gnLO_J9HBxVta1f8Ecvxw_KO8huPYQ
```

**Response (204):** Empty body

**Verification:** Follow-up SELECT for the deleted ID returned 0 rows.

**Key Patterns:**
- Filter in URL determines which row(s) to delete
- Without filter, ALL rows are deleted (dangerous!)
- Returns 204 No Content on success (empty body)
- Add `Prefer: return=representation` if you need the deleted row back

## n8n HTTP Request Node Template

For each Supabase CRUD operation in an n8n sub-workflow, use this HTTP Request node pattern:

### Common Headers (all operations)

```json
{
  "headerParameters": {
    "parameters": [
      {
        "name": "Authorization",
        "value": "=Bearer {{ SERVICE_ROLE_KEY }}"
      },
      {
        "name": "apikey",
        "value": "sb_publishable_9gnLO_J9HBxVta1f8Ecvxw_KO8huPYQ"
      }
    ]
  }
}
```

**Note:** In n8n, the service_role key will come from the n8n credential store (Supabase Service Role credential). The `apikey` header is always the publishable gateway key.

### SELECT Template

```
Method: GET
URL: https://llpnwaoxisfwptxvdfed.supabase.co/rest/v1/{table}?user_id=eq.{{ $json.user_id }}&select={columns}
Headers: Authorization + apikey
```

### INSERT Template

```
Method: POST
URL: https://llpnwaoxisfwptxvdfed.supabase.co/rest/v1/{table}
Headers: Authorization + apikey + Content-Type + Prefer: return=representation
Body: JSON with user_id and data fields
```

### UPSERT Template

```
Method: POST
URL: https://llpnwaoxisfwptxvdfed.supabase.co/rest/v1/{table}?on_conflict={unique_column}
Headers: Authorization + apikey + Content-Type + Prefer: resolution=merge-duplicates,return=representation
Body: JSON with user_id and data fields
```

### PATCH Template

```
Method: PATCH
URL: https://llpnwaoxisfwptxvdfed.supabase.co/rest/v1/{table}?{filter}
Headers: Authorization + apikey + Content-Type + Prefer: return=representation
Body: JSON with only the fields to update
```

### DELETE Template

```
Method: DELETE
URL: https://llpnwaoxisfwptxvdfed.supabase.co/rest/v1/{table}?{filter}
Headers: Authorization + apikey
```

## Summary

| # | Operation | Method | Status | Key Header | Result |
|---|-----------|--------|--------|-----------|--------|
| 1 | SELECT | GET | 200 | Authorization + apikey | PASS |
| 2 | INSERT | POST | 201 | + Content-Type + Prefer: return=representation | PASS |
| 3 | UPSERT | POST | 200 | + Content-Type + Prefer: resolution=merge-duplicates,return=representation | PASS |
| 4 | PATCH | PATCH | 200 | + Content-Type + Prefer: return=representation | PASS |
| 5 | DELETE | DELETE | 204 | Authorization + apikey only | PASS |

**Critical Finding:** UPSERT requires `?on_conflict={column}` query parameter. Without it, PostgREST returns 409 on duplicate keys. This must be included in every n8n HTTP Request node that performs UPSERT operations.

**Service Role Pattern (confirmed from Phase 1 testing):** The dual-header pattern works with the service_role JWT in the Authorization header. The service_role key bypasses RLS, which is correct for n8n backend operations where the workflow has already validated the user's JWT via Auth Validator and uses user_id in query filters manually.

---
*Tested: 2026-03-02*
*All patterns validated for use in Phase 3 sub-workflow construction*
