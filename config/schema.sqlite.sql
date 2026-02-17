-- ============================================================
-- KPTV SQLite Schema
-- Converted from ./config/schema.sql
-- ============================================================

PRAGMA foreign_keys = OFF;

DROP TABLE IF EXISTS kptv_users;
CREATE TABLE kptv_users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  u_role INTEGER NOT NULL DEFAULT 0,
  u_active INTEGER NOT NULL DEFAULT 0,
  u_name TEXT NOT NULL,
  u_pass TEXT NOT NULL,
  u_hash TEXT NOT NULL,
  u_email TEXT NOT NULL,
  u_lname TEXT DEFAULT NULL,
  u_fname TEXT DEFAULT NULL,
  u_created TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  u_updated TEXT DEFAULT NULL,
  last_login TEXT DEFAULT NULL,
  login_attempts INTEGER DEFAULT 0,
  locked_until TEXT DEFAULT NULL
);
CREATE UNIQUE INDEX idx_uname ON kptv_users (u_name);
CREATE UNIQUE INDEX idx_uemail ON kptv_users (u_email);
CREATE INDEX idx_uactive ON kptv_users (u_active);

DROP TABLE IF EXISTS kptv_stream_providers;
CREATE TABLE kptv_stream_providers (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  u_id INTEGER NOT NULL,
  sp_should_filter INTEGER NOT NULL DEFAULT 1,
  sp_priority INTEGER NOT NULL DEFAULT 99,
  sp_name TEXT NOT NULL,
  sp_cnx_limit INTEGER NOT NULL DEFAULT 1,
  sp_type INTEGER NOT NULL DEFAULT 0,
  sp_domain TEXT NOT NULL,
  sp_username TEXT DEFAULT NULL,
  sp_password TEXT DEFAULT NULL,
  sp_stream_type INTEGER NOT NULL DEFAULT 0,
  sp_refresh_period INTEGER NOT NULL DEFAULT 3,
  sp_last_synced TEXT DEFAULT NULL,
  sp_added TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  sp_updated TEXT DEFAULT NULL
);
CREATE INDEX idx_stream_providers_uid ON kptv_stream_providers (u_id);
CREATE INDEX idx_spname ON kptv_stream_providers (sp_name);

DROP TABLE IF EXISTS kptv_streams;
CREATE TABLE kptv_streams (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  u_id INTEGER NOT NULL,
  p_id INTEGER NOT NULL DEFAULT 0,
  s_type_id INTEGER NOT NULL DEFAULT 0,
  s_active INTEGER NOT NULL DEFAULT 0,
  s_channel TEXT NOT NULL DEFAULT '0',
  s_name TEXT NOT NULL,
  s_orig_name TEXT NOT NULL,
  s_stream_uri TEXT NOT NULL DEFAULT '',
  s_tvg_id TEXT DEFAULT NULL,
  s_tvg_group TEXT DEFAULT NULL,
  s_tvg_logo TEXT DEFAULT NULL,
  s_extras TEXT DEFAULT NULL,
  s_created TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  s_updated TEXT DEFAULT NULL
);
CREATE INDEX idx_streams_uid ON kptv_streams (u_id);
CREATE INDEX idx_streams_pid ON kptv_streams (p_id);
CREATE INDEX idx_stypeid ON kptv_streams (s_type_id);
CREATE INDEX idx_sactive ON kptv_streams (s_active);
CREATE INDEX idx_schannel ON kptv_streams (s_channel);
CREATE INDEX idx_sactive_stvgid ON kptv_streams (s_active, s_tvg_id);
CREATE INDEX idx_sname_supdated ON kptv_streams (s_name, s_updated);

-- Full-text search replacement for MySQL FULLTEXT indexes
DROP TABLE IF EXISTS kptv_streams_fts;
CREATE VIRTUAL TABLE kptv_streams_fts USING fts5(
  s_name,
  s_orig_name,
  content='kptv_streams',
  content_rowid='id'
);

DROP TABLE IF EXISTS kptv_stream_filters;
CREATE TABLE kptv_stream_filters (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  u_id INTEGER NOT NULL,
  sf_active INTEGER NOT NULL DEFAULT 1,
  sf_type_id INTEGER NOT NULL DEFAULT 0,
  sf_filter TEXT NOT NULL,
  sf_created TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  sf_updated TEXT DEFAULT NULL
);
CREATE INDEX idx_uid_sfactive_sftypeid ON kptv_stream_filters (u_id, sf_active, sf_type_id);

DROP TABLE IF EXISTS kptv_stream_missing;
CREATE TABLE kptv_stream_missing (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  u_id INTEGER NOT NULL,
  p_id INTEGER NOT NULL,
  stream_id INTEGER NOT NULL DEFAULT 0,
  other_id INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_stream_missing_uid ON kptv_stream_missing (u_id);
CREATE INDEX idx_stream_missing_pid ON kptv_stream_missing (p_id);
CREATE INDEX idx_streamid ON kptv_stream_missing (stream_id);
CREATE INDEX idx_otherid ON kptv_stream_missing (other_id);

DROP TABLE IF EXISTS kptv_stream_temp;
CREATE TABLE kptv_stream_temp (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  u_id INTEGER NOT NULL,
  p_id INTEGER NOT NULL,
  s_type_id INTEGER NOT NULL DEFAULT 0,
  s_orig_name TEXT NOT NULL,
  s_stream_uri TEXT NOT NULL DEFAULT '',
  s_tvg_id TEXT DEFAULT NULL,
  s_tvg_logo TEXT DEFAULT NULL,
  s_extras TEXT DEFAULT NULL,
  s_group TEXT DEFAULT NULL,
  s_orig_name_lower TEXT GENERATED ALWAYS AS (lower(s_orig_name)) VIRTUAL
);

-- -----------------------------------------------------------------
-- Triggers to emulate MySQL "ON UPDATE CURRENT_TIMESTAMP"
-- -----------------------------------------------------------------
CREATE TRIGGER kptv_users_set_updated
AFTER UPDATE ON kptv_users
FOR EACH ROW
WHEN NEW.u_updated IS OLD.u_updated
BEGIN
  UPDATE kptv_users SET u_updated = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

CREATE TRIGGER kptv_stream_providers_set_updated
AFTER UPDATE ON kptv_stream_providers
FOR EACH ROW
WHEN NEW.sp_updated IS OLD.sp_updated
BEGIN
  UPDATE kptv_stream_providers SET sp_updated = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

CREATE TRIGGER kptv_streams_set_updated
AFTER UPDATE ON kptv_streams
FOR EACH ROW
WHEN NEW.s_updated IS OLD.s_updated
BEGIN
  UPDATE kptv_streams SET s_updated = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

CREATE TRIGGER kptv_stream_filters_set_updated
AFTER UPDATE ON kptv_stream_filters
FOR EACH ROW
WHEN NEW.sf_updated IS OLD.sf_updated
BEGIN
  UPDATE kptv_stream_filters SET sf_updated = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

-- -----------------------------------------------------------------
-- FTS sync triggers
-- -----------------------------------------------------------------
CREATE TRIGGER kptv_streams_ai AFTER INSERT ON kptv_streams BEGIN
  INSERT INTO kptv_streams_fts(rowid, s_name, s_orig_name) VALUES (new.id, new.s_name, new.s_orig_name);
END;

CREATE TRIGGER kptv_streams_ad AFTER DELETE ON kptv_streams BEGIN
  INSERT INTO kptv_streams_fts(kptv_streams_fts, rowid, s_name, s_orig_name) VALUES('delete', old.id, old.s_name, old.s_orig_name);
END;

CREATE TRIGGER kptv_streams_au AFTER UPDATE ON kptv_streams BEGIN
  INSERT INTO kptv_streams_fts(kptv_streams_fts, rowid, s_name, s_orig_name) VALUES('delete', old.id, old.s_name, old.s_orig_name);
  INSERT INTO kptv_streams_fts(rowid, s_name, s_orig_name) VALUES (new.id, new.s_name, new.s_orig_name);
END;

-- -----------------------------------------------------------------
-- Stored procedure equivalents (execute from app/CLI):
-- CleanupStreams:
--   DELETE FROM kptv_streams
--   WHERE NOT EXISTS (
--       SELECT 1 FROM kptv_stream_providers
--       WHERE kptv_stream_providers.id = kptv_streams.p_id
--   );
--
--   DELETE FROM kptv_streams
--   WHERE id NOT IN (
--       SELECT MAX(id)
--       FROM kptv_streams
--       GROUP BY s_stream_uri
--   );
--
--   DELETE FROM kptv_stream_temp;
--
-- ResetStreamIDs is not generally needed in SQLite and should be avoided.
-- If necessary, rebuild the table using a CREATE TABLE AS / INSERT flow.
