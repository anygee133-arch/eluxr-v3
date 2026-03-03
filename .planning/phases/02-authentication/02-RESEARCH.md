# Phase 2 Research: Authentication

**Researched:** 2026-03-01
**Phase Goal:** Users can sign up, log in, reset passwords, and access a protected dashboard -- with every n8n webhook validating their identity before processing requests.
**Research Flag:** MEDIUM (confirmed -- CORS behavior with auth headers is the primary unknown requiring early testing)

---

## Table of Contents

1. [Research Question](#research-question)
2. [Work Area A: Supabase Auth -- Signup, Login, Session Management](#work-area-a-supabase-auth----signup-login-session-management)
3. [Work Area B: Password Reset Flow](#work-area-b-password-reset-flow)
4. [Work Area C: Frontend Auth UI + Protected Routes](#work-area-c-frontend-auth-ui--protected-routes)
5. [Work Area D: n8n Webhook JWT Validation (INFRA-04)](#work-area-d-n8n-webhook-jwt-validation-infra-04)
6. [Work Area E: CORS -- The Critical Unknown](#work-area-e-cors----the-critical-unknown)
7. [Work Area F: Token Refresh in Vanilla JS (MOD-1)](#work-area-f-token-refresh-in-vanilla-js-mod-1)
8. [Work Area G: Tenant Isolation via Auth (AUTH-05)](#work-area-g-tenant-isolation-via-auth-auth-05)
9. [Pitfall Mitigations](#pitfall-mitigations)
10. [Open Questions Resolved](#open-questions-resolved)
11. [Open Questions Requiring Live Testing](#open-questions-requiring-live-testing)
12. [Dependencies and Ordering Constraints](#dependencies-and-ordering-constraints)
13. [Architecture Decision: JWT Delivery to n8n](#architecture-decision-jwt-delivery-to-n8n)
14. [Sources](#sources)

---

## Research Question

**"What do I need to know to PLAN this phase well?"**

Phase 2 has six interrelated work areas:

1. **Auth UI (AUTH-01, AUTH-02):** Build login/signup pages in vanilla HTML/JS using supabase-js@2 from CDN
2. **Password reset (AUTH-03):** Implement the email-based reset flow with redirect URL handling
3. **Protected routes (AUTH-04):** Gate the dashboard behind auth state, redirect unauthenticated users
4. **Webhook security (INFRA-04):** Validate Supabase JWTs in every n8n webhook -- the most architecturally significant piece
5. **Tenant isolation (AUTH-05):** Ensure auth.uid() flows through to RLS on every query
6. **CORS with auth headers (HIGH-3):** Verify that n8n Cloud webhooks accept browser requests with Authorization headers -- the primary technical risk

The research flag is MEDIUM because items 1-4 are well-documented patterns, but item 5 (CORS behavior) has known issues in n8n Cloud that could force an architectural workaround (API proxy or token-in-body pattern).

---

## Work Area A: Supabase Auth -- Signup, Login, Session Management

### How Supabase Auth Works with supabase-js@2

The supabase-js v2 SDK handles auth entirely client-side. The SDK is loaded via CDN (esm.sh) with no build step required:

```html
<script type="module">
  import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

  const supabase = createClient(
    'https://llpnwaoxisfwptxvdfed.supabase.co',
    'sb_publishable_9gnLO_J9HBxVta1f8Ecvxw_KO8huPYQ'
  )
  window.supabase = supabase
</script>
```

### Signup (AUTH-01)

```javascript
const { data, error } = await supabase.auth.signUp({
  email: 'user@example.com',
  password: 'securepassword'
})
// data.user contains the new user object
// data.session is null until email is confirmed (if email confirmation is enabled)
```

**Important behaviors:**
- On signup, Supabase creates a row in `auth.users`
- The `handle_new_user()` trigger (from Phase 1) auto-creates a row in `public.profiles`
- If email confirmation is enabled in Supabase Dashboard (Authentication > Providers > Email), the user must click a confirmation link before they can log in
- The confirmation email uses a template configurable in Dashboard > Authentication > Email Templates
- **Decision needed:** Enable or disable email confirmation for v2. Recommendation: **enable it** for production, but allow a way to bypass during testing (Supabase auto-confirms users created via the Admin API)

### Login (AUTH-02)

```javascript
const { data, error } = await supabase.auth.signInWithPassword({
  email: 'user@example.com',
  password: 'securepassword'
})
// data.session.access_token contains the JWT
// data.session.refresh_token for obtaining new access tokens
// data.user contains user metadata
```

**Session behavior:**
- On successful login, supabase-js stores the session in `localStorage` by default
- The session includes an `access_token` (JWT, default 1-hour expiry) and a `refresh_token`
- supabase-js automatically refreshes the access token before it expires (auto-refresh is on by default)
- Session persists across page refreshes via localStorage
- Session syncs across browser tabs via localStorage events (BroadcastChannel where available)

### Retrieving the Session (for n8n webhook calls)

```javascript
const { data: { session } } = await supabase.auth.getSession()
if (session) {
  const jwt = session.access_token  // This is the JWT to send to n8n
  const userId = session.user.id     // User UUID
}
```

**Note on getSession():** This reads from local storage and does NOT make a network request unless the token is expired. It is fast and safe to call before every n8n webhook request.

### JWT Structure (Supabase Access Token)

The access token JWT contains these claims:

| Claim | Value | Purpose |
|-------|-------|---------|
| `sub` | UUID (e.g., `2488af7b-69ea-4bad-9876-ef28617b031c`) | User ID -- this is `auth.uid()` in RLS policies |
| `aud` | `"authenticated"` | Audience -- used for verification |
| `role` | `"authenticated"` | PostgreSQL role |
| `exp` | Unix timestamp (1 hour from issue) | Token expiry |
| `iat` | Unix timestamp | Token issued at |
| `iss` | `https://llpnwaoxisfwptxvdfed.supabase.co/auth/v1` | Issuer |
| `session_id` | UUID | Session identifier |
| `email` | User's email address | Convenience claim |

**Critical for n8n:** The `sub` claim is the user_id. After JWT validation in n8n, extract `sub` and use it for all Supabase writes to enforce tenant isolation.

### Supabase JWT Signing

Supabase supports three JWT signing algorithms:
- **HS256** (HMAC with shared secret) -- legacy default, uses the JWT secret from Dashboard
- **ES256** (ECDSA P-256) -- recommended for new projects
- **RS256** (RSA 2048) -- widely supported but slower

**Current project status:** Need to check which algorithm the Supabase project uses. If it's HS256 (legacy), the JWT secret from Dashboard > Settings > API > JWT Secret can be used directly in n8n's JWT node. If ES256/RS256, use the JWKS endpoint for verification.

**JWKS endpoint (for asymmetric algorithms):**
```
GET https://llpnwaoxisfwptxvdfed.supabase.co/auth/v1/.well-known/jwks.json
```

This endpoint is cached by Supabase Edge for 10 minutes and can be used for fast local JWT verification without hitting the Auth server.

### Logout

```javascript
const { error } = await supabase.auth.signOut()
// Clears the session from localStorage
// Fires the SIGNED_OUT event on onAuthStateChange
```

---

## Work Area B: Password Reset Flow

### Two-Step Process (AUTH-03)

**Step 1: Request password reset**
```javascript
const { data, error } = await supabase.auth.resetPasswordForEmail(email, {
  redirectTo: 'https://your-domain.com/reset-password'
})
```

This sends an email with a magic link. When the user clicks the link, they are redirected to the `redirectTo` URL with a token hash in the URL parameters.

**Step 2: Update the password (on the reset page)**
```javascript
// Listen for the PASSWORD_RECOVERY event
supabase.auth.onAuthStateChange((event, session) => {
  if (event === 'PASSWORD_RECOVERY') {
    // Show the new password form
    // The user is now authenticated via the magic link
  }
})

// After user enters new password:
const { data, error } = await supabase.auth.updateUser({
  password: 'new-secure-password'
})
```

### Configuration Required

1. **Site URL:** Set in Dashboard > Authentication > URL Configuration > Site URL
   - This is the default redirect when no `redirectTo` is specified
   - Set to the production frontend URL (e.g., `https://eluxr.vercel.app`)

2. **Redirect URLs allowlist:** Add all valid redirect URLs
   - Production: `https://eluxr.vercel.app/**`
   - Development: `http://localhost:8080/**`
   - Vercel previews: `https://*-eluxr.vercel.app/**` (if applicable)

3. **Email templates:** Customize in Dashboard > Authentication > Email Templates
   - Confirmation template (for signup)
   - Recovery template (for password reset)
   - May need to replace `{{ .SiteURL }}` with `{{ .RedirectTo }}` in templates if using `redirectTo`

4. **Custom SMTP (recommended for production):**
   - Supabase's built-in email sending has rate limits (2 emails per hour on free tier, 30 on Pro)
   - For production, configure a custom SMTP server (Resend, SendGrid, AWS SES, etc.)
   - Configured in Dashboard > Authentication > SMTP Settings

### Frontend Pages Required

The password reset flow requires a dedicated page/view:
- A "Forgot password?" link on the login page
- A reset request form (email input + submit)
- A reset confirmation page (new password input + submit) at the `redirectTo` URL

Since the app is a single `index.html` file, these can be implemented as:
- Additional sections in the same file (shown/hidden based on URL hash or state)
- OR separate HTML files (e.g., `reset-password.html`)

**Recommendation:** Use URL hash routing (`#login`, `#signup`, `#reset-password`, `#dashboard`) within `index.html` to keep the single-file architecture while supporting the redirect flow.

---

## Work Area C: Frontend Auth UI + Protected Routes

### Auth State Management (AUTH-04)

The `onAuthStateChange` listener is the core of auth state management:

```javascript
supabase.auth.onAuthStateChange((event, session) => {
  switch (event) {
    case 'SIGNED_IN':
      showDashboard()
      break
    case 'SIGNED_OUT':
      showLoginPage()
      break
    case 'TOKEN_REFRESHED':
      // Automatic -- no action needed
      // supabase-js handles this internally
      break
    case 'PASSWORD_RECOVERY':
      showResetPasswordForm()
      break
    case 'USER_UPDATED':
      // Password was changed, or user metadata updated
      break
  }
})
```

### Protected Route Pattern

On page load:
1. Check if a session exists: `const { data: { session } } = await supabase.auth.getSession()`
2. If session exists, show the dashboard
3. If no session, show the login page
4. Register `onAuthStateChange` to handle subsequent state changes

```javascript
async function initAuth() {
  const { data: { session } } = await supabase.auth.getSession()

  if (session) {
    showDashboard()
  } else {
    showLoginPage()
  }

  // Listen for future auth changes
  supabase.auth.onAuthStateChange((event, session) => {
    if (event === 'SIGNED_OUT' || !session) {
      showLoginPage()
    } else if (event === 'SIGNED_IN') {
      showDashboard()
    }
  })
}
```

### UI Structure

The existing `index.html` has:
- Header with ELUXR branding
- Phase navigation (3 tabs: Setup, Generate, Calendar)
- Page sections for each tab
- Toast notifications

**New UI needed:**
- Login form (email + password + submit + "forgot password" link + "sign up" link)
- Signup form (email + password + confirm password + submit + "login" link)
- Password reset request form (email + submit)
- Password reset confirmation form (new password + confirm + submit)
- User menu in header (email display + logout button) -- replaces or augments existing header

**Integration approach:**
- Add auth sections as new `<div>` elements in `index.html`
- Use CSS to show/hide auth vs. dashboard sections
- The existing phase-nav and page-sections become the "dashboard" that is hidden when not authenticated
- Auth pages use the same design system (colors, fonts, spacing)

### Success Criteria Mapping

| Requirement | Implementation |
|------------|----------------|
| AUTH-01: Signup | `supabase.auth.signUp()` + signup form |
| AUTH-02: Login + dashboard | `supabase.auth.signInWithPassword()` + session check + show/hide |
| AUTH-03: Password reset | `resetPasswordForEmail()` + `updateUser()` + dedicated forms |
| AUTH-04: Protected routes | `getSession()` on load + `onAuthStateChange` listener |

---

## Work Area D: n8n Webhook JWT Validation (INFRA-04)

### The Critical Architecture Piece

Every n8n webhook must validate the Supabase JWT before processing any request. This prevents:
- Unauthenticated API abuse (CRIT-3)
- Cross-tenant data access
- AI API cost exploitation

### Three Validation Approaches

#### Approach 1: n8n Webhook Node Built-in JWT Auth (RECOMMENDED if CORS works)

n8n's Webhook node supports JWT authentication natively:

1. **Create a JWT Auth credential in n8n:**
   - Go to Credentials > Add Credential > JWT Auth
   - Key Type: "Passphrase" (for HS256) or "PEM Key" (for RS256/ES256)
   - Algorithm: Match the Supabase signing algorithm
   - Secret: The Supabase JWT secret (from Dashboard > Settings > API > JWT Secret)

2. **Configure the Webhook node:**
   - Authentication: "JWT Auth"
   - Select the JWT Auth credential
   - n8n automatically validates the signature on incoming `Authorization: Bearer <token>` headers
   - The decoded payload is accessible as `jwtPayload` in subsequent nodes

3. **Extract user_id in a Code node:**
   ```javascript
   const userId = $input.first().json.headers?.jwtPayload?.sub
   // OR depending on where n8n exposes it:
   const userId = $('Webhook').first().json.jwtPayload?.sub
   ```

**Advantages:**
- Built-in, no custom code for validation
- n8n handles signature verification
- Decoded payload available as `jwtPayload`

**Limitations:**
- Claims (exp, aud) are NOT automatically enforced -- must add a Code node to check
- HS256 requires sharing the Supabase JWT secret with n8n (security consideration)
- Does not verify the token against Supabase's auth server (no session revocation check)
- CORS preflight handling with Authorization header is uncertain (see Work Area E)

#### Approach 2: n8n JWT Node (Verify Operation)

Use n8n's dedicated JWT node after the Webhook node:

1. **Webhook node:** Set authentication to "None" (token comes in request body or header)
2. **Code node:** Extract the Bearer token from headers
3. **JWT node:** Operation = "Verify", credential = JWT Auth with Supabase secret
4. **Code node:** Check exp, aud claims and extract user_id

**Advantages:**
- More control over the validation process
- Can be used as a reusable sub-workflow
- Webhook node does not need JWT auth (simpler CORS)

**Limitations:**
- More nodes in the flow
- Same HS256 secret-sharing consideration
- Still no session revocation check

#### Approach 3: Supabase HTTP API Validation (Most Secure)

Validate the JWT by calling Supabase's `auth/v1/user` endpoint:

```
HTTP Request node:
  Method: GET
  URL: https://llpnwaoxisfwptxvdfed.supabase.co/auth/v1/user
  Headers:
    Authorization: Bearer {the_user_jwt}
    apikey: sb_publishable_9gnLO_J9HBxVta1f8Ecvxw_KO8huPYQ
```

If the response is HTTP 200, the JWT is valid and the response contains the full user object. If 401, the JWT is invalid or expired.

**Advantages:**
- Cryptographically secure -- Supabase verifies the token
- Checks session validity (catches revoked sessions)
- No secret sharing needed (uses the publishable anon key)
- Works regardless of signing algorithm (HS256, ES256, RS256)

**Limitations:**
- Adds one HTTP request per webhook call (~50-200ms latency)
- Depends on Supabase Auth service availability
- Higher load on Supabase Auth server

### Recommended Approach: Hybrid (Approach 1 + 3)

**Primary path:** Use n8n's built-in webhook JWT auth for fast signature validation (Approach 1).

**Fallback/secondary validation:** For sensitive operations (content generation, approval actions), add an HTTP Request node calling Supabase's auth endpoint to verify session validity (Approach 3).

**Practical recommendation for Phase 2:** Start with Approach 2 or 3 because they decouple JWT validation from the webhook CORS configuration, which is the primary risk area. Move to Approach 1 only after confirming CORS behavior.

### Auth Validator Sub-Workflow Pattern

The success criteria require "An Auth Validator sub-workflow exists in n8n that all webhook workflows call as their first step."

**Design:**

```
Auth Validator Sub-Workflow:
  Input: Raw webhook request (headers + body)

  Step 1: Extract Bearer token from Authorization header
    Code node:
      const authHeader = $input.first().json.headers?.authorization
      if (!authHeader?.startsWith('Bearer ')) {
        return [{ json: { error: 'Missing authorization', statusCode: 401 } }]
      }
      const token = authHeader.replace('Bearer ', '')
      return [{ json: { token, ...($input.first().json) } }]

  Step 2: Validate JWT
    Option A: JWT node (Verify operation) with Supabase JWT secret
    Option B: HTTP Request to Supabase auth/v1/user

  Step 3: Extract user_id and return
    Code node:
      return [{ json: {
        user_id: validatedPayload.sub,
        email: validatedPayload.email,
        original_body: $input.first().json.body
      }}]

  Output: { user_id, email, original_body } OR { error, statusCode: 401 }
```

**Usage in webhook workflows:**
```
Webhook node → Execute Sub-Workflow (Auth Validator) → IF(error) → Respond 401
                                                     → IF(success) → Continue with user_id
```

---

## Work Area E: CORS -- The Critical Unknown

### The Problem

Adding an `Authorization: Bearer <token>` header to browser fetch requests converts them from "simple requests" to "preflighted requests." The browser sends an OPTIONS request first to check if the server allows the `Authorization` header. If the server does not respond correctly to OPTIONS, the actual request is blocked.

### Current State (Working)

The v1 frontend sends POST requests with `Content-Type: application/json` header to n8n Cloud webhooks with `allowedOrigins: "*"`. These work correctly, which means:

1. n8n Cloud IS handling OPTIONS preflight for `Content-Type: application/json` (since `application/json` is NOT a CORS-safelisted content type and DOES trigger preflight)
2. The `allowedOrigins` setting in the webhook node IS being respected by n8n Cloud's underlying server

### The Unknown

Will n8n Cloud's preflight response include `Authorization` in the `Access-Control-Allow-Headers` response? This has NOT been tested and community reports are mixed:

**Evidence that it might NOT work:**
- GitHub issue #18143: CORS preflight fails for Wait node webhooks despite correct env vars (open, unresolved as of Jan 2026)
- Multiple community threads showing CORS failures when adding custom headers
- n8n Cloud does not expose environment variable configuration for `WEBHOOK_CORS_ALLOWED_HEADERS`

**Evidence that it might work:**
- The v1 frontend already sends `Content-Type: application/json` which triggers preflight, and it works
- The webhook node has an `allowedOrigins` configuration that is functional
- n8n's blog and documentation describe JWT auth on webhooks as a supported feature

### Testing Plan (Must Execute Before Planning)

**Test 1:** From a browser (not curl/Postman), send a fetch request with `Authorization: Bearer <token>` header to an n8n Cloud webhook with `allowedOrigins: "*"`. Observe whether the OPTIONS preflight succeeds.

```javascript
// Run this from browser console on any domain
fetch('https://flowbound.app.n8n.cloud/webhook/eluxr-approval-list', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer test-token-here'
  },
  body: JSON.stringify({ test: true })
})
.then(r => r.json())
.then(console.log)
.catch(console.error)
```

If the OPTIONS response includes `Access-Control-Allow-Headers: Authorization` (or `*`), we can use the Authorization header directly. If not, we need a workaround.

### Workaround Options (If CORS Fails)

#### Option A: Token in Request Body (Simplest)

Instead of `Authorization: Bearer <token>`, send the JWT in the request body:

```javascript
fetch(webhookUrl, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    _auth_token: session.access_token,
    ...originalPayload
  })
})
```

In n8n, the Auth Validator extracts the token from `body._auth_token` instead of headers.

**Advantages:**
- No CORS preflight issues (Content-Type: application/json is already working)
- Simple to implement
- No infrastructure changes needed

**Disadvantages:**
- Non-standard pattern (Authorization header is the convention)
- The JWT is in the request body instead of the header
- GET requests cannot have a body (affects `eluxr-approval-list` and `eluxr-themes-list` which currently use GET)

#### Option B: Vercel/Netlify Serverless Proxy

Create a serverless function that:
1. Receives the request from the browser (same origin = no CORS)
2. Forwards it to n8n with the Authorization header
3. Returns the n8n response to the browser

**Example Vercel serverless function (`api/webhook/[...path].js`):**
```javascript
export default async function handler(req, res) {
  const path = req.query.path.join('/')
  const n8nUrl = `https://flowbound.app.n8n.cloud/webhook/${path}`

  const response = await fetch(n8nUrl, {
    method: req.method,
    headers: {
      'Content-Type': 'application/json',
      'Authorization': req.headers.authorization
    },
    body: req.method !== 'GET' ? JSON.stringify(req.body) : undefined
  })

  const data = await response.json()
  res.status(response.status).json(data)
}
```

**Advantages:**
- Standard Authorization header pattern
- Hides n8n webhook URLs from the browser (security improvement)
- Handles CORS properly (same-origin requests)
- Can add rate limiting, logging, etc.

**Disadvantages:**
- Adds infrastructure complexity (Vercel/Netlify dependency)
- Adds latency (~100ms per request)
- Requires maintaining serverless functions
- Not yet needed if the app is a static HTML file

#### Option C: Convert GET Webhooks to POST (Partial Fix)

For the two GET endpoints (`eluxr-approval-list`, `eluxr-themes-list`), convert them to POST and send the token in the body. This avoids the GET-with-body issue.

This can be combined with Option A for a complete body-based token solution.

### Recommendation

**Priority order:**
1. **Test CORS with Authorization header first** (Test 1 above)
2. **If CORS works:** Use standard Authorization header + n8n JWT auth
3. **If CORS fails:** Use Option A (token in body) as the primary approach
   - It is the simplest, requires no infrastructure changes
   - Convert GET webhooks to POST to support body-based tokens
   - The non-standard pattern is acceptable for an internal API

**Do NOT use Option B (proxy) unless Option A is also unacceptable**, because it adds infrastructure complexity that conflicts with the "no build step, no frameworks" constraint.

---

## Work Area F: Token Refresh in Vanilla JS (MOD-1)

### How supabase-js Handles Token Refresh

The supabase-js v2 client handles token refresh automatically:

1. **Auto-refresh is ON by default** when the client is created
2. The client monitors the access token's `exp` claim
3. Before the token expires, the client uses the refresh token to obtain a new access token
4. This happens in the background without any user action
5. The `TOKEN_REFRESHED` event fires on `onAuthStateChange` when this occurs

### What Could Go Wrong

1. **Token expires while the tab is backgrounded:** Browsers may throttle timers in background tabs. If the auto-refresh timer does not fire, the token expires. When the tab is foregrounded, the client detects the expired token and refreshes it -- but any requests made during the brief gap may fail.

2. **Refresh token is revoked or expired:** If the refresh token itself expires or is revoked (e.g., user logged out from another device), the auto-refresh fails. The user should be redirected to login.

3. **Network interruption during refresh:** If the refresh request fails due to a network error, the client retries. But if the user makes a request before the retry succeeds, it fails with an expired token.

### Mitigation Strategy

```javascript
// Wrapper function for all n8n webhook calls
async function authenticatedFetch(url, options = {}) {
  // Get current session (fast -- reads from localStorage)
  const { data: { session } } = await supabase.auth.getSession()

  if (!session) {
    // No session -- redirect to login
    showLoginPage()
    throw new Error('Not authenticated')
  }

  // Add Authorization header (or token in body, depending on CORS approach)
  const headers = {
    'Content-Type': 'application/json',
    ...options.headers
  }

  // CORS-safe approach (if Authorization header does not work):
  const body = options.body ? JSON.parse(options.body) : {}
  body._auth_token = session.access_token

  try {
    const response = await fetch(url, {
      ...options,
      headers,
      body: JSON.stringify(body)
    })

    if (response.status === 401) {
      // Token was rejected by n8n -- try refreshing
      const { data: { session: newSession } } = await supabase.auth.refreshSession()
      if (!newSession) {
        showLoginPage()
        throw new Error('Session expired')
      }

      // Retry with new token
      body._auth_token = newSession.access_token
      return fetch(url, {
        ...options,
        headers,
        body: JSON.stringify(body)
      })
    }

    return response
  } catch (error) {
    if (error.message === 'Not authenticated' || error.message === 'Session expired') {
      throw error
    }
    throw error  // Network or other error
  }
}
```

### Session Persistence Configuration

The success criteria state: "JWT in memory, not localStorage." However, supabase-js v2 uses localStorage by default and this is the recommended approach for vanilla JS. The alternative is custom storage:

```javascript
const supabase = createClient(url, key, {
  auth: {
    storage: {
      getItem: (key) => window.sessionStorage.getItem(key),
      setItem: (key, value) => window.sessionStorage.setItem(key, value),
      removeItem: (key) => window.sessionStorage.removeItem(key),
    }
  }
})
```

**Recommendation:** Use localStorage (the default). It is the standard pattern for SPAs and survives page refreshes. The success criteria mention "JWT in memory, not localStorage" but this is impractical for a vanilla JS app without a framework -- page refreshes would log the user out. Using localStorage is the standard secure pattern for Supabase Auth. The anon key in localStorage is not a security risk because RLS enforces authorization.

**Alternative interpretation:** The criteria may mean "do not store raw JWTs in localStorage manually" -- supabase-js handles this internally and securely. This is already the case with the default configuration.

---

## Work Area G: Tenant Isolation via Auth (AUTH-05)

### How Auth Flows to RLS

Phase 1 established RLS policies on all 10 tables using `(select auth.uid()) = user_id`. Here is how the authentication chain works:

1. **Frontend → Supabase:** When the frontend uses supabase-js with the user's session, the SDK automatically includes the access token in every request. Supabase's PostgREST gateway extracts the JWT, sets `auth.uid()` to the `sub` claim, and RLS policies filter results to the user's rows. **No additional code needed** -- this works automatically.

2. **Frontend → n8n → Supabase:** When the frontend calls an n8n webhook, n8n operates with the `service_role` key (which bypasses RLS). Therefore, n8n MUST:
   - Extract the `user_id` from the validated JWT
   - Include `user_id` in every Supabase INSERT/UPDATE
   - Filter by `user_id` in every Supabase SELECT/DELETE

This is the critical security chain. If n8n fails to include `user_id` in a query, the service_role key will return/affect ALL users' data.

### Enforcement Pattern in n8n

After the Auth Validator sub-workflow returns `{ user_id }`:

**For reads:**
```
HTTP Request: GET https://llpnwaoxisfwptxvdfed.supabase.co/rest/v1/content_items?user_id=eq.{user_id}
Headers:
  Authorization: Bearer {service_role_jwt}
  apikey: sb_publishable_9gnLO_J9HBxVta1f8Ecvxw_KO8huPYQ
```

**For writes:**
```
HTTP Request: POST https://llpnwaoxisfwptxvdfed.supabase.co/rest/v1/content_items
Headers:
  Authorization: Bearer {service_role_jwt}
  apikey: sb_publishable_9gnLO_J9HBxVta1f8Ecvxw_KO8huPYQ
  Content-Type: application/json
  Prefer: return=minimal
Body: { "user_id": "{user_id}", "content": "...", ... }
```

**For updates:**
```
HTTP Request: PATCH https://llpnwaoxisfwptxvdfed.supabase.co/rest/v1/content_items?id=eq.{item_id}&user_id=eq.{user_id}
```

Always include `user_id=eq.{user_id}` as a filter on updates and deletes, even though the service_role bypasses RLS. This is defense-in-depth.

### Verification

Phase 1's test accounts (testuser-a@eluxr.test / TestPass123A, testuser-b@eluxr.test / TestPass123B) can be used to verify:
1. Log in as User A, make a webhook call, verify the response contains only User A's data
2. Log in as User B, verify they see only User B's data
3. Attempt to include User B's user_id in a request while authenticated as User A -- should be rejected by the Auth Validator

---

## Pitfall Mitigations

### CRIT-3: Unauthenticated Webhooks

| Aspect | Mitigation |
|--------|-----------|
| **What could go wrong** | Webhooks remain open and anyone can trigger AI pipeline operations |
| **Prevention** | Auth Validator sub-workflow as first step in every webhook flow. Requests without valid JWT return 401 immediately. |
| **Verification** | Curl a webhook URL without Authorization header -- should get 401. Curl with a valid JWT -- should succeed. Curl with an expired/invalid JWT -- should get 401. |
| **Rollback risk** | Do NOT remove `allowedOrigins: "*"` until CORS with auth headers is tested. Changing origins prematurely could break the working v1 frontend during development. |

### HIGH-3: CORS with Auth Headers

| Aspect | Mitigation |
|--------|-----------|
| **What could go wrong** | Adding Authorization header triggers CORS preflight that n8n Cloud does not handle, breaking all frontend-to-n8n communication |
| **Prevention** | Test CORS behavior FIRST, before building any auth UI. Have token-in-body fallback ready. |
| **Verification** | Browser-based test (not Postman) with Authorization header against live n8n Cloud webhook. |
| **Decision tree** | CORS works → use Authorization header. CORS fails → use token-in-body + convert GETs to POSTs. |

### MOD-1: Token Refresh in Vanilla JS

| Aspect | Mitigation |
|--------|-----------|
| **What could go wrong** | Token expires, n8n returns 401, user sees errors with no recovery |
| **Prevention** | `authenticatedFetch()` wrapper that checks session, handles 401 with automatic refresh, redirects to login on refresh failure |
| **Verification** | Set short JWT expiry (5 min) in Supabase during testing. Wait for expiry, trigger a webhook call, verify auto-refresh fires and the call succeeds. |

---

## Open Questions Resolved

| Question | Answer | Confidence | Source |
|----------|--------|-----------|--------|
| How does Supabase Auth work with vanilla JS? | supabase-js@2 via CDN handles signup, login, session refresh, and token management. No framework needed. | HIGH | Supabase docs, community examples |
| What JWT claims does Supabase include? | `sub` (user UUID), `aud` ("authenticated"), `role`, `exp`, `iss`, `email`, `session_id` | HIGH | Supabase JWT docs |
| Can n8n validate JWTs natively? | Yes. Webhook node supports JWT Auth credential. Also has a standalone JWT node with Verify operation. Both support HS256. | HIGH | n8n docs, community |
| Does n8n JWT auth expose the decoded payload? | Yes, as `jwtPayload` on the webhook output. | HIGH | n8n community (confirmed pattern) |
| What algorithm does Supabase use for JWT signing? | Legacy projects use HS256 (HMAC). Newer projects may use ES256 (ECDSA). Need to check which one this project uses. | MEDIUM | Supabase signing keys docs |
| How does password reset work in vanilla JS? | `resetPasswordForEmail()` sends email link, `onAuthStateChange` catches PASSWORD_RECOVERY event, `updateUser({ password })` sets new password. | HIGH | Supabase docs |
| Does supabase-js auto-refresh tokens? | Yes, by default. The client refreshes the access token before expiry. `TOKEN_REFRESHED` event fires. | HIGH | Supabase session docs |
| Can n8n Cloud Code nodes install npm packages? | No. n8n Cloud Code nodes cannot install external npm packages. Built-in modules only (crypto, Buffer, etc.). | HIGH | Community reports, Auth0 integration discussion |
| What is the Supabase JWKS endpoint? | `https://{project}.supabase.co/auth/v1/.well-known/jwks.json` -- cached for 10 minutes. | HIGH | Supabase signing keys docs |
| How should n8n enforce tenant isolation? | Extract user_id from validated JWT, include in every Supabase query as filter parameter. Defense-in-depth alongside RLS. | HIGH | Architecture docs, standard pattern |

---

## Open Questions Requiring Live Testing

These cannot be resolved through documentation alone. They require live testing during the first planning iteration.

| Question | Test Procedure | Impact if Negative | Fallback |
|----------|---------------|-------------------|----------|
| **Does n8n Cloud handle CORS preflight for Authorization header?** | Send fetch with Authorization header from browser to n8n Cloud webhook. Check OPTIONS response for `Access-Control-Allow-Headers`. | Cannot use standard Authorization header pattern. | Token-in-body approach (Option A). |
| **What JWT signing algorithm does this Supabase project use?** | Check Dashboard > Settings > API > JWT Secret, or decode a test JWT and inspect the `alg` header claim. | If ES256/RS256, cannot use HS256 passphrase in n8n JWT auth -- must use JWKS or Supabase API validation. | Use Approach 3 (Supabase HTTP API validation) which is algorithm-agnostic. |
| **Does n8n webhook JWT auth work with Supabase-issued JWTs?** | Configure JWT Auth credential in n8n with Supabase JWT secret, set webhook auth to JWT, send a Supabase access token. | If the format is incompatible, cannot use built-in JWT auth. | Use JWT node (Verify) or Supabase API validation. |
| **Do the existing test account passwords work for login?** | Call `supabase.auth.signInWithPassword()` with testuser-a@eluxr.test / TestPass123A. | If auto-confirm was not enabled, test accounts may need email confirmation first. | Enable user manually in Supabase Dashboard. |

---

## Dependencies and Ordering Constraints

### Internal Ordering (Within Phase 2)

```
Step 0: CORS Test (MUST be first -- determines architecture)
    |-- Test Authorization header CORS on n8n Cloud webhook from browser
    |-- Test Supabase JWT signing algorithm
    |-- Results determine which JWT delivery and validation approach to use
    |
Step 1: Supabase Auth Configuration
    |-- Configure Site URL, redirect URLs, email templates
    |-- Verify test account login works
    |-- Determine email confirmation setting
    |
Step 2: Auth Validator Sub-Workflow in n8n
    |-- Create JWT Auth credential in n8n (using Supabase JWT secret)
    |-- Build the Auth Validator sub-workflow
    |-- Test with valid/invalid/expired tokens
    |
Step 3: Frontend Auth UI
    |-- Add login/signup/reset forms to index.html
    |-- Implement auth state management (onAuthStateChange)
    |-- Implement protected route pattern (show/hide dashboard)
    |-- Build authenticatedFetch() wrapper
    |
Step 4: Integrate Auth with Existing Webhooks
    |-- Modify each webhook flow to call Auth Validator as first step
    |-- Update frontend fetch calls to use authenticatedFetch()
    |-- Lock down allowedOrigins (change from "*" to production domain)
    |
Step 5: End-to-End Verification
    |-- Test full signup → confirm → login → webhook call → data isolation flow
    |-- Test with both test accounts for cross-tenant isolation
    |-- Test password reset flow
    |-- Test unauthenticated access rejection
```

### Dependencies on Phase 1 (All Met)

| Phase 1 Deliverable | How Phase 2 Uses It | Status |
|---------------------|---------------------|--------|
| `profiles` table with `handle_new_user` trigger | Auto-creates profile on signup | COMPLETE |
| RLS policies on all 10 tables | `auth.uid()` from JWT enforces isolation | COMPLETE |
| Supabase service_role credential in n8n | n8n writes to Supabase with tenant isolation | COMPLETE |
| Test accounts (testuser-a, testuser-b) | Used for auth testing and cross-tenant verification | COMPLETE |
| `pipeline_runs` with Realtime enabled | Not used in Phase 2 (Phase 4), but schema is ready | COMPLETE |

### What Phase 2 Unblocks

| Phase 2 Deliverable | Phases It Unblocks |
|---------------------|-------------------|
| Auth Validator sub-workflow | Phase 3 (all webhook flows will use it) |
| Frontend auth state management | Phase 5 (frontend migration builds on auth) |
| Protected route pattern | Phase 5 (all frontend features behind auth) |
| JWT-to-user_id extraction pattern | Phase 3+ (every backend operation needs user_id) |
| authenticatedFetch() wrapper | Phase 5+ (every frontend API call uses it) |

---

## Architecture Decision: JWT Delivery to n8n

### Decision Matrix

| Factor | Authorization Header | Token in Body | Vercel Proxy |
|--------|---------------------|--------------|-------------|
| CORS risk | HIGH (may fail preflight) | NONE (already working) | NONE (same-origin) |
| Implementation effort | LOW (if CORS works) | LOW | MEDIUM (new infra) |
| Standards compliance | Standard pattern | Non-standard | Standard |
| GET request support | Yes | No (must convert to POST) | Yes |
| n8n JWT auth built-in | Yes (automatic validation) | No (manual extraction) | Yes (proxy passes header) |
| Infrastructure change | None | None | Vercel serverless functions |
| Latency overhead | None | None | ~100ms per request |

### Decision Process

This decision CANNOT be made during research -- it requires the CORS test from Step 0.

**If CORS works:** Use Authorization header (standard, enables n8n's built-in JWT auth).
**If CORS fails:** Use token-in-body (simplest workaround, no infrastructure changes, convert GETs to POSTs).

Both approaches produce the same security outcome. The difference is ergonomics and conventions, not security.

---

## Success Criteria Checklist (For Plan Validation)

The plan must produce deliverables that satisfy ALL of the following:

- [ ] A new user can sign up with email/password, receive confirmation (if enabled), and land on their dashboard
- [ ] A returning user can log in and their session persists across browser tabs
- [ ] A user who forgot their password receives a reset email and can set a new password
- [ ] Visiting any dashboard URL while logged out redirects to the login page
- [ ] An Auth Validator sub-workflow exists in n8n that all webhook workflows call as their first step
- [ ] Requests to any webhook without a valid JWT return 401
- [ ] Each user's data is isolated -- logged-in User A cannot see User B's data through any webhook
- [ ] The `authenticatedFetch()` wrapper handles token refresh and 401 retry automatically
- [ ] All 13 webhook endpoints are protected by the Auth Validator
- [ ] allowedOrigins is set to the production frontend domain (not "*") after verification

---

## Sources

### Verified Documentation

- [Supabase Auth -- Password-based Auth](https://supabase.com/docs/guides/auth/passwords) -- signup, login, password reset flow
- [Supabase Auth -- Sessions](https://supabase.com/docs/guides/auth/sessions) -- session duration, refresh tokens, auto-refresh
- [Supabase Auth -- Redirect URLs](https://supabase.com/docs/guides/auth/redirect-urls) -- redirect URL configuration, wildcard patterns
- [Supabase Auth -- Email Templates](https://supabase.com/docs/guides/auth/auth-email-templates) -- customizing confirmation and recovery emails
- [Supabase Auth -- Custom SMTP](https://supabase.com/docs/guides/auth/auth-smtp) -- configuring custom email delivery
- [Supabase Auth -- JWT Signing Keys](https://supabase.com/docs/guides/auth/signing-keys) -- HS256 vs ES256 vs RS256, JWKS endpoint
- [Supabase Auth -- JWT Claims Reference](https://supabase.com/docs/guides/auth/jwt-fields) -- sub, aud, role, exp, session_id claims
- [Supabase JS -- onAuthStateChange](https://supabase.com/docs/reference/javascript/auth-onauthstatechange) -- event listener for auth state
- [Supabase JS -- resetPasswordForEmail](https://supabase.com/docs/reference/javascript/auth-resetpasswordforemail) -- password reset initiation
- [Supabase Discussion -- Verifying JWT](https://github.com/orgs/supabase/discussions/20763) -- local vs API-based JWT verification
- [n8n JWT Node Docs](https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.jwt/) -- sign, verify, decode operations
- [n8n JWT Credentials](https://docs.n8n.io/integrations/builtin/credentials/jwt/) -- passphrase vs PEM key, algorithm options
- [n8n Webhook Credentials](https://docs.n8n.io/integrations/builtin/credentials/webhook/) -- Basic Auth, Header Auth, JWT Auth options
- [n8n Webhook Node Docs](https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.webhook/) -- webhook configuration, CORS settings
- [n8n Community -- JWT for Authenticated Webhooks](https://community.n8n.io/t/using-jwts-json-web-tokens-for-authenticated-webhooks/107397) -- jwtPayload extraction pattern
- [n8n Community -- CORS Errors](https://community.n8n.io/t/how-to-call-webhook-triggered-flow-from-frontend-avoid-cors-errors/6975) -- CORS workaround discussion
- [n8n Community -- Auth0 JWT Verification](https://community.n8n.io/t/verify-credentials-from-auth0-users-jwt-in-a-wekhook/118661) -- limitations of n8n Cloud for external JWT validation
- [n8n Workflow Template -- Secure Webhook with Supabase](https://n8n.io/workflows/8258-learn-secure-webhook-apis-with-authentication-and-supabase-integration/) -- reference workflow pattern
- [n8n Blog -- Webhook Security Guide](https://blog.nocodecreative.io/n8n-webhooks-a-beginners-guide-with-security-built-in/) -- JWT auth, CORS configuration, claims validation
- [GitHub Issue #18143 -- CORS Preflight Bug](https://github.com/n8n-io/n8n/issues/18143) -- open bug, OPTIONS preflight fails for Wait node webhooks
- [n8n Community -- CORS Cloud Persistent Error](https://community.n8n.io/t/persistent-cors-error-with-n8n-cloud-webhook-despite-environment-variables/97556) -- unresolved CORS issues on n8n Cloud
- [MDN -- CORS](https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/CORS) -- simple vs preflighted requests specification
- [Medium -- Supabase Auth with Plain HTML & CDN](https://medium.com/@wahengchang2023/6-steps-building-auth-to-do-web-app-with-supabase-plain-html-cdn-javascript-cdaad65348c8) -- vanilla JS implementation example
- [Vercel -- Enabling CORS](https://vercel.com/kb/guide/how-to-enable-cors) -- serverless proxy option

### Primary Codebase Sources

- `index.html` (154KB, ~4100 lines) -- current frontend, no auth code, 13+ fetch calls with no Authorization header
- `ELUXR social media Action v2 (3).json` (117KB) -- n8n workflow with 13 webhook endpoints, all `allowedOrigins: "*"`, no auth
- `supabase/migrations/20260228044505_create_initial_schema.sql` -- Phase 1 schema with profiles table, handle_new_user trigger, RLS policies
- `.planning/phases/01-security-hardening-database-foundation/01-03-SUMMARY.md` -- test accounts and verified tenant isolation

### Confidence Levels

| Finding | Confidence | Why |
|---------|-----------|-----|
| Supabase Auth API (signup, login, reset) | HIGH | Official docs, stable API, widely used |
| supabase-js@2 auto-refresh behavior | HIGH | Official docs, default behavior |
| n8n Webhook JWT Auth credential | HIGH | Official docs, community confirmed |
| n8n JWT node operations | HIGH | Official docs |
| CORS behavior with Authorization header on n8n Cloud | LOW | Known open bugs, conflicting reports, requires live testing |
| n8n Cloud Code node module availability | MEDIUM | Community reports, no npm install on Cloud |
| Supabase JWT signing algorithm for this project | UNKNOWN | Requires checking Dashboard |
| Token-in-body approach working with existing CORS setup | HIGH | `Content-Type: application/json` POST already works |

---

*Research completed: 2026-03-01*
*Ready for: CORS test (Step 0), then planning phase*
