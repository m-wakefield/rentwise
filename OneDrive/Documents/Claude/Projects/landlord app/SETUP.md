# RentWise — Deployment Setup Guide

Follow these steps in order. Each section is a ~5-minute task.

---

## Step 1 — Supabase: Run the database schema

1. Go to your Supabase project → **SQL Editor**
2. Open `supabase/schema.sql` from this folder
3. Paste the entire contents and click **Run**
4. Verify success: you should see tables listed under **Table Editor**

**Also in Supabase:**
- Go to **Authentication → Providers**
- Enable **Email** (already on by default)
- Enable **Google** — follow the Google OAuth setup wizard (requires a Google Cloud project with OAuth credentials)
- Under **Authentication → URL Configuration**, set:
  - Site URL: `https://your-netlify-domain.netlify.app`
  - Redirect URLs: add `https://your-netlify-domain.netlify.app/**`

---

## Step 2 — Supabase: Get your API keys

1. Go to **Settings → API**
2. Copy:
   - **Project URL** → `SUPABASE_URL`
   - **anon (public) key** → `SUPABASE_ANON_KEY`
   - **service_role (secret) key** → `SUPABASE_SERVICE_ROLE_KEY` *(used only in Netlify functions)*

---

## Step 3 — Stripe: Create your products

1. Go to your Stripe Dashboard → **Products**
2. Create a product called **RentWise Pro**
3. Add a recurring price (e.g., $29/month or whatever you've decided)
4. Copy the **Price ID** (starts with `price_...`) → `STRIPE_PRO_PRICE_ID`
5. Copy your **Publishable key** → `STRIPE_PUBLISHABLE_KEY`
6. Copy your **Secret key** → `STRIPE_SECRET_KEY`

**Stripe Webhook:**
1. Go to **Developers → Webhooks → Add endpoint**
2. URL: `https://your-netlify-domain.netlify.app/api/stripe-webhook`
3. Select these events:
   - `customer.subscription.created`
   - `customer.subscription.updated`
   - `customer.subscription.deleted`
   - `checkout.session.completed`
   - `invoice.payment_failed`
4. Copy the **Signing secret** → `STRIPE_WEBHOOK_SECRET`

**Stripe Customer Portal (required for users to manage their subscription):**
1. Go to **Settings → Billing → Customer portal**
2. Enable it and configure what actions customers can take
3. Save

---

## Step 4 — Update the HTML config constants

In **three places**, replace the placeholder values with your real keys:

### `index.html` (around line 1814)
```js
const SUPABASE_URL   = 'https://XXXX.supabase.co';
const SUPABASE_ANON  = 'eyJhbGc...';
const STRIPE_PUB_KEY = 'pk_live_...';
```

### `public/tenant.html` (near the top `<script>`)
```js
const SUPABASE_URL  = 'https://XXXX.supabase.co';
const SUPABASE_ANON = 'eyJhbGc...';
```

### `public/investor.html` and `public/pm.html` — same pattern

> **Security note:** The `anon` key and publishable Stripe key are safe to put in frontend code — they're designed for that. Never put `service_role` or `STRIPE_SECRET_KEY` in frontend HTML.

---

## Step 5 — Set Netlify environment variables

In your Netlify project → **Site configuration → Environment variables**, add:

| Variable | Value |
|---|---|
| `ANTHROPIC_API_KEY` | Your Anthropic API key |
| `SUPABASE_URL` | Your Supabase project URL |
| `SUPABASE_SERVICE_ROLE_KEY` | Supabase service role key (server-side only) |
| `STRIPE_SECRET_KEY` | Stripe secret key |
| `STRIPE_PRO_PRICE_ID` | Stripe price ID for Pro plan |
| `STRIPE_WEBHOOK_SECRET` | Stripe webhook signing secret |
| `SITE_URL` | Your full Netlify URL, e.g. `https://rentwise.netlify.app` |

---

## Step 6 — Deploy to Netlify

**Option A — Drag and drop (simplest):**
1. Go to [app.netlify.com](https://app.netlify.com)
2. Drag your project folder onto the Netlify dashboard
3. Done — Netlify auto-detects `netlify.toml`

**Option B — GitHub (recommended for ongoing development):**
1. Push this folder to a GitHub repo
2. Connect the repo in Netlify → **Add new site → Import from Git**
3. Every push to `main` auto-deploys

---

## Step 7 — Install function dependencies

Netlify will automatically run `npm install` inside `netlify/functions/` because of the `package.json` there. No extra steps needed.

If you're testing locally with `netlify dev`, run:
```bash
cd netlify/functions && npm install
```

---

## Step 8 — Test end-to-end

Work through this checklist before announcing launch:

- [ ] Sign up with email → lands on landlord dashboard
- [ ] Sign up, choose Pro → redirects to Stripe Checkout → subscription created → returns to app with Pro badge
- [ ] Add a property → refresh page → property still there (Supabase persistence confirmed)
- [ ] Add an expense, add a mileage log → same check
- [ ] AI chat responds correctly
- [ ] Sign out → redirected to login
- [ ] Sign up as Tenant → redirected to `/tenant.html`
- [ ] Sign up as Investor → redirected to `/investor.html`
- [ ] Sign up as PM → redirected to `/pm.html`
- [ ] Stripe webhook: go to Stripe Dashboard → test a `customer.subscription.created` event → user's plan in Supabase updates to `pro`
- [ ] Billing portal: user with active subscription can open Stripe customer portal

---

## File Structure Reference

```
rentwise/
├── public/
│   ├── index.html          ← Landlord dashboard (main app)
│   ├── tenant.html         ← Tenant portal
│   ├── investor.html       ← Investor dashboard
│   └── pm.html             ← Property Manager portal
├── netlify/
│   └── functions/
│       ├── claude-proxy.js     ← AI chat proxy (Anthropic API)
│       ├── create-checkout.js  ← Stripe subscription checkout
│       ├── stripe-webhook.js   ← Stripe event handler
│       ├── stripe-portal.js    ← Stripe customer portal
│       └── package.json        ← stripe + @supabase/supabase-js
├── supabase/
│   └── schema.sql          ← Full DB schema + RLS policies
├── netlify.toml            ← Build config + redirects + security headers
└── SETUP.md                ← This file
```

---

## What's still on your Phase 2 list

These were intentionally deferred to keep launch scope tight:

1. **Rent collection payments** — Stripe Payment Element for tenants to pay rent in `tenant.html`
2. **Lease e-signatures** — DocuSign or HelloSign API integration
3. **Listing syndication** — Zillow, Zumper, Apartments.com APIs (requires their partnership programs)
4. **Email notifications** — Supabase Edge Functions + Resend.com for rent reminders, late notices, maintenance updates
5. **CreditBoost reporting** — requires partnership with Experian RentBureau or similar
6. **PM ↔ Owner linking** — mechanism for a landlord to add a PM to their account and grant access
