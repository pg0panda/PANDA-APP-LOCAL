-- Codes are inserted by the owner. Never put this data in the public GitHub repo.
CREATE TABLE IF NOT EXISTS codes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  code TEXT NOT NULL UNIQUE,
  plan TEXT NOT NULL CHECK (plan IN ('day', 'week', 'month', '3months', '6months', 'year')),
  claimed_at TEXT,
  claimed_purchase_id INTEGER UNIQUE,
  customer_name TEXT,
  customer_email TEXT,
  license_synced_at TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_codes_available ON codes(plan, claimed_at, id);

-- A payment creates exactly one redemption token. Its hash validates claims;
-- the opaque token itself is retained only for the post-payment redirect.
CREATE TABLE IF NOT EXISTS purchases (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  provider_payment_id TEXT NOT NULL UNIQUE,
  plan TEXT NOT NULL CHECK (plan IN ('day', 'week', 'month', '3months', '6months', 'year')),
  redemption_token_hash TEXT NOT NULL UNIQUE,
  -- Kept only in D1 (never exposed through the public claim API) so the
  -- post-payment return endpoint can send the buyer to their one-time link.
  redemption_token TEXT NOT NULL,
  code_id INTEGER UNIQUE REFERENCES codes(id),
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  claimed_at TEXT
);
