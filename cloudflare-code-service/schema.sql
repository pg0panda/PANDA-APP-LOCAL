-- Codes are inserted by the owner. Never put this data in the public GitHub repo.
CREATE TABLE IF NOT EXISTS codes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  code TEXT NOT NULL UNIQUE,
  plan TEXT NOT NULL CHECK (plan IN ('day', 'week', 'month', '3months', '6months', 'year')),
  claimed_at TEXT,
  claimed_purchase_id INTEGER UNIQUE,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_codes_available ON codes(plan, claimed_at, id);

-- A payment creates exactly one redemption token. Only its SHA-256 hash is stored.
CREATE TABLE IF NOT EXISTS purchases (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  provider_payment_id TEXT NOT NULL UNIQUE,
  plan TEXT NOT NULL CHECK (plan IN ('day', 'week', 'month', '3months', '6months', 'year')),
  redemption_token_hash TEXT NOT NULL UNIQUE,
  code_id INTEGER UNIQUE REFERENCES codes(id),
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  claimed_at TEXT
);
