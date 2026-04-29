-- ============================================================
-- RentWise — Supabase Database Schema
-- Run this in the Supabase SQL editor (Dashboard → SQL Editor)
-- ============================================================

-- ── PROFILES ──────────────────────────────────────────────
-- Extends Supabase's built-in auth.users table
CREATE TABLE IF NOT EXISTS profiles (
  id            UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  email         TEXT,
  full_name     TEXT,
  role          TEXT DEFAULT 'landlord' CHECK (role IN ('landlord','tenant','investor','pm')),
  plan          TEXT DEFAULT 'free'     CHECK (plan IN ('free','pro')),
  stripe_customer_id       TEXT UNIQUE,
  stripe_subscription_id   TEXT,
  subscription_status      TEXT DEFAULT 'inactive',
  avatar_url    TEXT,
  phone         TEXT,
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);

-- Automatically create a profile when a new user signs up
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO profiles (id, email, full_name, role)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    COALESCE(NEW.raw_user_meta_data->>'role', 'landlord')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();


-- ── PROPERTIES ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS properties (
  id             UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  owner_id       UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  name           TEXT,                      -- display name, e.g. "240 Maple Ave"
  address        TEXT NOT NULL,
  city           TEXT,
  state          TEXT DEFAULT 'TX',
  zip            TEXT,
  units          INTEGER DEFAULT 1,
  purchase_price NUMERIC,
  rent_estimate  NUMERIC,
  emoji          TEXT DEFAULT '🏠',
  gradient       TEXT DEFAULT '#e8f0e6,#c0d8c0',
  created_at     TIMESTAMPTZ DEFAULT NOW()
);


-- ── TENANTS ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS tenants (
  id               UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  landlord_id      UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  tenant_user_id   UUID REFERENCES profiles(id) ON DELETE SET NULL,  -- their RentWise account (optional)
  property_id      UUID REFERENCES properties(id) ON DELETE SET NULL,
  first_name       TEXT NOT NULL,
  last_name        TEXT NOT NULL,
  email            TEXT,
  phone            TEXT,
  unit             TEXT,
  rent_amount      NUMERIC DEFAULT 0,
  lease_start      DATE,
  lease_end        DATE,
  health_score     INTEGER DEFAULT 75 CHECK (health_score BETWEEN 0 AND 100),
  status           TEXT DEFAULT 'active' CHECK (status IN ('active','inactive','eviction')),
  payment_status   TEXT DEFAULT 'current' CHECK (payment_status IN ('current','late','paid','due')),
  creditboost      BOOLEAN DEFAULT FALSE,
  notes            TEXT,
  created_at       TIMESTAMPTZ DEFAULT NOW(),
  updated_at       TIMESTAMPTZ DEFAULT NOW()
);


-- ── PAYMENTS ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS payments (
  id                       UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  tenant_id                UUID REFERENCES tenants(id) ON DELETE CASCADE NOT NULL,
  landlord_id              UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  property_id              UUID REFERENCES properties(id) ON DELETE SET NULL,
  amount                   NUMERIC NOT NULL,
  due_date                 DATE,
  paid_date                DATE,
  status                   TEXT DEFAULT 'pending' CHECK (status IN ('pending','paid','late','partial','waived')),
  stripe_payment_intent_id TEXT,
  notes                    TEXT,
  created_at               TIMESTAMPTZ DEFAULT NOW()
);


-- ── EXPENSES ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS expenses (
  id          UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  owner_id    UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  property_id UUID REFERENCES properties(id) ON DELETE SET NULL,
  date        DATE DEFAULT CURRENT_DATE,
  description TEXT NOT NULL,
  category    TEXT DEFAULT 'Other',
  vendor      TEXT,
  amount      NUMERIC NOT NULL,
  notes       TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);


-- ── MILEAGE ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS mileage (
  id          UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  owner_id    UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  property_id UUID REFERENCES properties(id) ON DELETE SET NULL,
  date        DATE DEFAULT CURRENT_DATE,
  destination TEXT,
  purpose     TEXT,
  miles       NUMERIC NOT NULL,
  irs_rate    NUMERIC DEFAULT 0.67,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);


-- ── MAINTENANCE ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS maintenance (
  id            UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  landlord_id   UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  tenant_id     UUID REFERENCES tenants(id) ON DELETE SET NULL,
  property_id   UUID REFERENCES properties(id) ON DELETE SET NULL,
  title         TEXT NOT NULL,
  description   TEXT,
  priority      TEXT DEFAULT 'medium' CHECK (priority IN ('low','medium','high','urgent')),
  status        TEXT DEFAULT 'open' CHECK (status IN ('open','in_progress','resolved','closed')),
  estimated_cost NUMERIC,
  actual_cost   NUMERIC,
  vendor        TEXT,
  photos        TEXT[],
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);


-- ── MESSAGES ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS messages (
  id           UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  sender_id    UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  recipient_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  tenant_id    UUID REFERENCES tenants(id) ON DELETE SET NULL,
  body         TEXT NOT NULL,
  read         BOOLEAN DEFAULT FALSE,
  created_at   TIMESTAMPTZ DEFAULT NOW()
);


-- ── LISTINGS ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS listings (
  id          UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  owner_id    UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  property_id UUID REFERENCES properties(id) ON DELETE SET NULL,
  unit        TEXT,
  title       TEXT,
  description TEXT,
  rent        NUMERIC,
  bedrooms    INTEGER,
  bathrooms   NUMERIC,
  sqft        INTEGER,
  available   DATE,
  pets        TEXT DEFAULT 'no',
  status      TEXT DEFAULT 'draft' CHECK (status IN ('draft','active','paused','rented')),
  photos      TEXT[],
  created_at  TIMESTAMPTZ DEFAULT NOW()
);


-- ── APPLICATIONS ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS applications (
  id           UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  listing_id   UUID REFERENCES listings(id) ON DELETE SET NULL,
  landlord_id  UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  first_name   TEXT,
  last_name    TEXT,
  email        TEXT,
  phone        TEXT,
  status       TEXT DEFAULT 'pending' CHECK (status IN ('pending','approved','denied','withdrawn')),
  income       NUMERIC,
  credit_score INTEGER,
  notes        TEXT,
  created_at   TIMESTAMPTZ DEFAULT NOW()
);


-- ============================================================
-- ROW-LEVEL SECURITY (RLS)
-- Users can only read/write their own data
-- ============================================================

ALTER TABLE profiles     ENABLE ROW LEVEL SECURITY;
ALTER TABLE properties   ENABLE ROW LEVEL SECURITY;
ALTER TABLE tenants       ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments     ENABLE ROW LEVEL SECURITY;
ALTER TABLE expenses     ENABLE ROW LEVEL SECURITY;
ALTER TABLE mileage      ENABLE ROW LEVEL SECURITY;
ALTER TABLE maintenance  ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages     ENABLE ROW LEVEL SECURITY;
ALTER TABLE listings     ENABLE ROW LEVEL SECURITY;
ALTER TABLE applications ENABLE ROW LEVEL SECURITY;


-- profiles: read/update own row
CREATE POLICY "Users can view own profile"   ON profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update own profile" ON profiles FOR UPDATE USING (auth.uid() = id);

-- properties: landlord owns their properties
CREATE POLICY "Landlords can view own properties"   ON properties FOR SELECT USING (auth.uid() = owner_id);
CREATE POLICY "Landlords can insert properties"     ON properties FOR INSERT WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "Landlords can update own properties" ON properties FOR UPDATE USING (auth.uid() = owner_id);
CREATE POLICY "Landlords can delete own properties" ON properties FOR DELETE USING (auth.uid() = owner_id);

-- tenants: landlord manages their tenants; tenants can view their own record
CREATE POLICY "Landlords can manage own tenants" ON tenants FOR ALL USING (auth.uid() = landlord_id);
CREATE POLICY "Tenants can view own record"      ON tenants FOR SELECT USING (auth.uid() = tenant_user_id);

-- payments
CREATE POLICY "Landlords can manage own payments" ON payments FOR ALL USING (auth.uid() = landlord_id);
CREATE POLICY "Tenants can view own payments"     ON payments FOR SELECT
  USING (tenant_id IN (SELECT id FROM tenants WHERE tenant_user_id = auth.uid()));

-- expenses
CREATE POLICY "Owners can manage own expenses" ON expenses FOR ALL USING (auth.uid() = owner_id);

-- mileage
CREATE POLICY "Owners can manage own mileage" ON mileage FOR ALL USING (auth.uid() = owner_id);

-- maintenance
CREATE POLICY "Landlords can manage maintenance"    ON maintenance FOR ALL USING (auth.uid() = landlord_id);
CREATE POLICY "Tenants can view and insert tickets" ON maintenance FOR SELECT
  USING (tenant_id IN (SELECT id FROM tenants WHERE tenant_user_id = auth.uid()));
CREATE POLICY "Tenants can submit tickets" ON maintenance FOR INSERT
  WITH CHECK (tenant_id IN (SELECT id FROM tenants WHERE tenant_user_id = auth.uid()));

-- messages: sender or recipient can see
CREATE POLICY "Participants can view messages" ON messages FOR SELECT
  USING (auth.uid() = sender_id OR auth.uid() = recipient_id);
CREATE POLICY "Authenticated users can send messages" ON messages FOR INSERT
  WITH CHECK (auth.uid() = sender_id);
CREATE POLICY "Recipients can mark as read" ON messages FOR UPDATE
  USING (auth.uid() = recipient_id);

-- listings: owner manages, everyone can view active listings
CREATE POLICY "Owners can manage own listings" ON listings FOR ALL USING (auth.uid() = owner_id);
CREATE POLICY "Anyone can view active listings" ON listings FOR SELECT USING (status = 'active');

-- applications: landlord sees all for their listings; applicant sees own
CREATE POLICY "Landlords can manage applications" ON applications FOR ALL USING (auth.uid() = landlord_id);


-- ============================================================
-- USEFUL VIEWS
-- ============================================================

-- Portfolio summary per landlord
CREATE OR REPLACE VIEW landlord_portfolio AS
SELECT
  p.owner_id,
  COUNT(DISTINCT p.id)                                     AS total_properties,
  SUM(p.units)                                             AS total_units,
  COUNT(DISTINCT t.id) FILTER (WHERE t.status = 'active') AS occupied_units,
  SUM(t.rent_amount) FILTER (WHERE t.status = 'active')   AS monthly_revenue,
  COUNT(DISTINCT t.id) FILTER (WHERE t.payment_status = 'late') AS late_tenants,
  AVG(t.health_score) FILTER (WHERE t.status = 'active')  AS avg_health_score
FROM properties p
LEFT JOIN tenants t ON t.property_id = p.id
GROUP BY p.owner_id;
