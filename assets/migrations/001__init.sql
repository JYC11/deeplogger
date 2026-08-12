-- 001__init.sql — initial schema for DeepLogger.
-- All DDL is idempotent (IF NOT EXISTS) so re-running is safe.
-- Future migrations append as 002__*.sql, 003__*.sql, etc.

CREATE TABLE IF NOT EXISTS dive_logs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  start_time INTEGER NOT NULL,
  end_time INTEGER,
  location TEXT,
  altitude TEXT,
  max_depth_m REAL,
  avg_depth_m REAL,
  duration_min REAL,
  gas_type TEXT,
  gas_other TEXT,
  tank_size TEXT,
  tank_volume_value REAL,
  tank_volume_unit TEXT,
  start_pressure_bar REAL,
  end_pressure_bar REAL,
  water_temp_c REAL,
  salinity TEXT,
  visibility_m REAL,
  weight_kg REAL,
  notes TEXT,
  is_draft INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS dive_photos (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  dive_log_id INTEGER NOT NULL,
  local_path TEXT NOT NULL,
  taken_at INTEGER,
  FOREIGN KEY (dive_log_id) REFERENCES dive_logs(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS sightings (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  dive_log_id INTEGER NOT NULL,
  dive_photo_id INTEGER,
  common_name TEXT NOT NULL,
  FOREIGN KEY (dive_log_id) REFERENCES dive_logs(id) ON DELETE CASCADE,
  FOREIGN KEY (dive_photo_id) REFERENCES dive_photos(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS certifications (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  org TEXT NOT NULL,
  level TEXT NOT NULL,
  cert_id TEXT,
  issue_date INTEGER,
  photo_path TEXT
);

CREATE TABLE IF NOT EXISTS gear_items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  type_notes TEXT,
  category TEXT
);

CREATE TABLE IF NOT EXISTS dive_log_gear (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  dive_log_id INTEGER NOT NULL,
  gear_item_id INTEGER,
  gear_text TEXT,
  FOREIGN KEY (dive_log_id) REFERENCES dive_logs(id) ON DELETE CASCADE,
  FOREIGN KEY (gear_item_id) REFERENCES gear_items(id) ON DELETE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_log_gear_pair
  ON dive_log_gear(dive_log_id, gear_item_id) WHERE gear_item_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_photos_log ON dive_photos(dive_log_id);
CREATE INDEX IF NOT EXISTS idx_sightings_log ON sightings(dive_log_id);
CREATE INDEX IF NOT EXISTS idx_sightings_photo ON sightings(dive_photo_id);
CREATE INDEX IF NOT EXISTS idx_logs_start ON dive_logs(start_time);
CREATE INDEX IF NOT EXISTS idx_certs_org ON certifications(org, issue_date);
