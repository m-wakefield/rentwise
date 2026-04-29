# RentWise — Launch Readiness Audit
**Date:** April 28, 2026  
**File reviewed:** `rentwise-site-clean.zip`  
**Verdict: ⛔ NOT READY for paid launch — significant backend work required**

---

## What the App Currently Is

RentWise is a beautifully designed single-page application (one `index.html` file, ~6,255 lines) with a Netlify serverless function for AI chat. The UI is polished and covers a lot of ground — landlord dashboard, tenant tools, AI co-pilot, calculator, listings wizard, accounting, and more.

**The only functional backend component is the AI chat.** Everything else — authentication, user accounts, data storage, subscription payments, role-based portals — is either fake or missing entirely.

---

## Critical Issues (Blockers for Launch)

### 1. ❌ Authentication is completely fake
The login and signup screens look real but do nothing. The "Sign in with Google / Apple / Microsoft" buttons all call `nextAuthStep('account-type')` — they just advance a visual step. The email/password fields are never read. `enterApp()` simply unhides a div. There is no session, no JWT, no user identity of any kind.

**Anyone who opens the URL is immediately "logged in" as a demo user.**

**Fix needed:** Integrate a real auth provider. Supabase Auth, Firebase Auth, or Clerk are the most practical options for a project of this size.

---

### 2. ❌ Zero data persistence
All data — properties, expenses, mileage logs, added tenants — lives in JavaScript arrays (`let properties = []`, `let expenses = []`, etc.). Refreshing the page wipes everything. There is no database, no localStorage, no API calls to save anything.

The five tenants shown (Sarah Rodriguez, Tyler Washington, etc.) are hardcoded demo data.

**Fix needed:** A real database (Supabase/PostgreSQL recommended). Every form that says "Save" needs an actual API call behind it.

---

### 3. ❌ No subscription or payment processing
The plan selection screen (Free / Pro) is purely cosmetic — `selectPlan()` just toggles a CSS class. Choosing "Pro" never triggers a payment flow. There is no Stripe integration anywhere in the codebase.

**Fix needed:** Stripe Checkout or Stripe Billing. You need:
- Products and prices set up in Stripe
- A checkout session endpoint
- A webhook to update the user's plan status in your database after payment
- Plan-gated features in the UI (currently `selectedPlan` is set but never checked)

---

### 4. ❌ Account types do nothing
The onboarding asks "I am a… Landlord / Tenant / Property Manager / Investor" but `enterApp()` ignores `selectedAcct` entirely. Every account type gets the same landlord dashboard with the same hardcoded data. There is no tenant portal, no investor view, no PM workspace — just the one UI.

**Fix needed:** After auth, route users to role-appropriate dashboards. The tenant portal screens (Renter Profile, CreditBoost, Find My Next Place) exist as placeholders but need real data and separate login flows.

---

### 5. ❌ Claude model name is incorrect
In `index.html` line 5134, the model is hardcoded as `'claude-sonnet-4-20250514'`. The correct model string is `claude-sonnet-4-5`. This will cause the AI chat to fail in production.

Also in `claude-proxy.js` line 29, the fallback is `'claude-sonnet-4-20250514'` — same issue.

**Fix needed:** Change both to `'claude-sonnet-4-5'`.

---

## Secondary Issues (Important but not instant blockers)

### 6. ⚠️ No multi-tenancy
The app assumes one landlord with one fixed portfolio. There's no concept of "which user is logged in, which properties belong to them." You can't build a real SaaS without this.

### 7. ⚠️ AI system prompt contains hardcoded tenant data
The AI's system prompt on line ~5100 hardcodes "His tenants include: Sarah Rodriguez (Unit 4B)…" This demo data will appear in every user's AI session. The system prompt needs to be dynamically built from the logged-in user's actual data.

### 8. ⚠️ No CORS protection on the AI proxy
`claude-proxy.js` returns `'Access-Control-Allow-Origin': '*'` — wide open. Anyone who finds your Netlify function URL can call it and run up your Anthropic bill. Should be locked to your own domain.

### 9. ⚠️ Export P&L does nothing
`exportPL()` is defined but the function body is empty — it doesn't generate or download any file.

### 10. ⚠️ Listing wizard doesn't publish anywhere
`publishListing()` shows a success toast but doesn't connect to Zillow, Zumper, or any listing platform.

### 11. ⚠️ Rent collection has no payment processor
The payments screen shows statuses (Paid / Late / Due) but there's no way for tenants to actually pay rent. No Stripe, Plaid, or ACH integration.

### 12. ⚠️ Lease signing is wired to AI only
"Add & Generate Lease with AI" calls the AI, but there's no e-signature integration (DocuSign, HelloSign, etc.) to actually execute a lease.

### 13. ⚠️ No HTTPS enforcement or security headers beyond basics
The `netlify.toml` has `X-Frame-Options` and `X-Content-Type-Options`, but is missing `Content-Security-Policy`, `Strict-Transport-Security`, and `Referrer-Policy`.

---

## What IS Working

| Feature | Status |
|---|---|
| AI chat (Ask AI screen) | ✅ Functional — routes to Anthropic via Netlify function |
| Property investment calculator | ✅ Functional — pure JS math |
| UI navigation (all screens) | ✅ Works |
| Add Property / Add Expense / Log Mileage forms | ✅ Work in-session (data lost on refresh) |
| Listing creation wizard | ✅ UI works, doesn't publish anywhere |
| Netlify deployment config | ✅ Correct setup |

---

## Recommended Build Order

To get to a real paid launch, here's the sequence that makes the most sense:

**Phase 1 — Foundation (must have)**
1. Set up Supabase (auth + database in one)
2. Replace fake login with Supabase Auth (supports Google/Apple/email)
3. Create database tables: `users`, `properties`, `tenants`, `payments`, `expenses`
4. Wire all "Save" buttons to real API calls

**Phase 2 — Monetization**
5. Add Stripe — products for Free/Pro, checkout session, webhook
6. Gate Pro features behind plan check
7. Add user-specific AI system prompt (pull their real property/tenant data)

**Phase 3 — Role portals**
8. Build actual tenant login → tenant dashboard (pay rent, view lease, submit maintenance)
9. Build investor view (portfolio analytics, ROI tracking)

**Phase 4 — Integrations**
10. Rent collection via Stripe or Plaid ACH
11. Listing syndication API (Zillow/Zumper)
12. E-signature for leases (DocuSign or HelloSign)
13. Fix CORS on AI proxy, fix model name

---

## Summary

The app is an excellent prototype — the design, UX, and feature scope are genuinely impressive. But right now it is a static demo with a working chatbot attached. No user can create a real account, no data persists between sessions, and no payment can be collected. These are not minor gaps — they are the entire backend of a SaaS product.

The good news: the UI is done and the Netlify infrastructure is in place. The path to launch is clear, and Supabase in particular can handle auth + database + storage in a way that slots neatly into this existing single-file architecture.
