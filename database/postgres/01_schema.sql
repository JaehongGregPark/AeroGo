-- database/mysql/01_schema.sql 를 PostgreSQL로 변환한 버전.
-- 변환 규칙: AUTO_INCREMENT -> GENERATED ALWAYS AS IDENTITY, UNSIGNED 제거,
-- ENUM -> VARCHAR+CHECK, DATETIME -> TIMESTAMP, JSON -> JSONB,
-- "ON UPDATE CURRENT_TIMESTAMP" -> set_updated_at() 트리거, FULLTEXT -> tsvector+GIN.

CREATE OR REPLACE FUNCTION set_updated_at() RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TABLE IF NOT EXISTS users (
  id BIGINT GENERATED ALWAYS AS IDENTITY,
  username VARCHAR(255) NOT NULL,
  email VARCHAR(255) NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  role VARCHAR(20) NOT NULL DEFAULT 'user'
    CHECK (role IN ('admin', 'user')),
  status VARCHAR(20) NOT NULL DEFAULT 'pending_email'
    CHECK (status IN ('pending_email', 'active', 'disabled', 'locked')),
  email_verified BOOLEAN NOT NULL DEFAULT FALSE,
  email_verification_sent_at TIMESTAMP NULL,
  email_confirmed_at TIMESTAMP NULL,
  terms_accepted_at TIMESTAMP NULL,
  display_name VARCHAR(100) NULL,
  last_login_at TIMESTAMP NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  CONSTRAINT uq_users_username UNIQUE (username),
  CONSTRAINT uq_users_email UNIQUE (email)
);
CREATE INDEX IF NOT EXISTS idx_users_role_status ON users (role, status);
DROP TRIGGER IF EXISTS trg_users_updated_at ON users;
CREATE TRIGGER trg_users_updated_at BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE IF NOT EXISTS email_verification_tokens (
  id BIGINT GENERATED ALWAYS AS IDENTITY,
  user_id BIGINT NOT NULL,
  token_hash CHAR(64) NOT NULL,
  purpose VARCHAR(20) NOT NULL DEFAULT 'signup_confirm'
    CHECK (purpose IN ('signup_confirm', 'email_change')),
  expires_at TIMESTAMP NOT NULL,
  used_at TIMESTAMP NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  CONSTRAINT uq_email_verification_tokens_hash UNIQUE (token_hash),
  CONSTRAINT fk_email_verification_tokens_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_email_verification_tokens_user
  ON email_verification_tokens (user_id, purpose, used_at, expires_at);

CREATE TABLE IF NOT EXISTS system_settings (
  setting_key VARCHAR(100) NOT NULL,
  setting_value JSONB NOT NULL,
  description VARCHAR(500) NULL,
  updated_by BIGINT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (setting_key),
  CONSTRAINT fk_system_settings_updated_by
    FOREIGN KEY (updated_by) REFERENCES users(id)
    ON DELETE SET NULL
);
DROP TRIGGER IF EXISTS trg_system_settings_updated_at ON system_settings;
CREATE TRIGGER trg_system_settings_updated_at BEFORE UPDATE ON system_settings
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE IF NOT EXISTS user_preferences (
  user_id BIGINT NOT NULL,
  preference_key VARCHAR(100) NOT NULL,
  preference_value JSONB NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id, preference_key),
  CONSTRAINT fk_user_preferences_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE
);
DROP TRIGGER IF EXISTS trg_user_preferences_updated_at ON user_preferences;
CREATE TRIGGER trg_user_preferences_updated_at BEFORE UPDATE ON user_preferences
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE IF NOT EXISTS game_records (
  id BIGINT GENERATED ALWAYS AS IDENTITY,
  owner_user_id BIGINT NULL,
  black_player_id BIGINT NULL,
  white_player_id BIGINT NULL,
  black_player_name VARCHAR(150) NULL,
  white_player_name VARCHAR(150) NULL,
  title VARCHAR(255) NOT NULL,
  board_size SMALLINT NOT NULL,
  komi DECIMAL(4,1) NOT NULL DEFAULT 6.5,
  game_mode VARCHAR(20) NOT NULL
    CHECK (game_mode IN ('human_vs_human', 'human_vs_ai', 'ai_vs_ai')),
  status VARCHAR(20) NOT NULL DEFAULT 'ongoing'
    CHECK (status IN ('ongoing', 'completed', 'imported', 'archived')),
  winner VARCHAR(10) NOT NULL DEFAULT 'unknown'
    CHECK (winner IN ('black', 'white', 'draw', 'unknown')),
  result_text VARCHAR(50) NULL,
  black_captures INTEGER NOT NULL DEFAULT 0,
  white_captures INTEGER NOT NULL DEFAULT 0,
  sgf_text TEXT NULL,
  source_name VARCHAR(150) NULL,
  source_url VARCHAR(1000) NULL,
  source_record_id VARCHAR(100) NULL,
  source_license_note VARCHAR(500) NULL,
  imported_at TIMESTAMP NULL,
  started_at TIMESTAMP NULL,
  ended_at TIMESTAMP NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  search_vector tsvector GENERATED ALWAYS AS (
    to_tsvector('simple', coalesce(title, '') || ' ' || coalesce(sgf_text, ''))
  ) STORED,
  PRIMARY KEY (id),
  CONSTRAINT fk_game_records_owner
    FOREIGN KEY (owner_user_id) REFERENCES users(id)
    ON DELETE SET NULL,
  CONSTRAINT fk_game_records_black_player
    FOREIGN KEY (black_player_id) REFERENCES users(id)
    ON DELETE SET NULL,
  CONSTRAINT fk_game_records_white_player
    FOREIGN KEY (white_player_id) REFERENCES users(id)
    ON DELETE SET NULL,
  CONSTRAINT chk_game_records_board_size
    CHECK (board_size IN (9, 13, 19))
);
CREATE INDEX IF NOT EXISTS idx_game_records_owner ON game_records (owner_user_id, created_at);
CREATE INDEX IF NOT EXISTS idx_game_records_status ON game_records (status, created_at);
CREATE INDEX IF NOT EXISTS ft_game_records_title_sgf ON game_records USING GIN (search_vector);
DROP TRIGGER IF EXISTS trg_game_records_updated_at ON game_records;
CREATE TRIGGER trg_game_records_updated_at BEFORE UPDATE ON game_records
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE IF NOT EXISTS game_moves (
  id BIGINT GENERATED ALWAYS AS IDENTITY,
  game_record_id BIGINT NOT NULL,
  move_number INTEGER NOT NULL,
  color VARCHAR(10) NOT NULL CHECK (color IN ('black', 'white')),
  row_index SMALLINT NULL,
  col_index SMALLINT NULL,
  is_pass BOOLEAN NOT NULL DEFAULT FALSE,
  captured_count INTEGER NOT NULL DEFAULT 0,
  board_snapshot JSONB NULL,
  played_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  CONSTRAINT uq_game_moves_number UNIQUE (game_record_id, move_number),
  CONSTRAINT fk_game_moves_game
    FOREIGN KEY (game_record_id) REFERENCES game_records(id)
    ON DELETE CASCADE,
  CONSTRAINT chk_game_moves_point_or_pass
    CHECK (
      (is_pass = TRUE AND row_index IS NULL AND col_index IS NULL)
      OR
      (is_pass = FALSE AND row_index IS NOT NULL AND col_index IS NOT NULL)
    )
);
CREATE INDEX IF NOT EXISTS idx_game_moves_game ON game_moves (game_record_id, played_at);

CREATE TABLE IF NOT EXISTS ai_analysis (
  id BIGINT GENERATED ALWAYS AS IDENTITY,
  game_record_id BIGINT NOT NULL,
  move_number INTEGER NULL,
  model_name VARCHAR(100) NOT NULL,
  difficulty VARCHAR(20) NOT NULL
    CHECK (difficulty IN ('beginner', 'intermediate', 'advanced')),
  mcts_visits INTEGER NOT NULL DEFAULT 0,
  black_winrate DECIMAL(5,2) NULL,
  score_lead DECIMAL(6,2) NULL,
  analysis_json JSONB NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  CONSTRAINT fk_ai_analysis_game
    FOREIGN KEY (game_record_id) REFERENCES game_records(id)
    ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_ai_analysis_game_move ON ai_analysis (game_record_id, move_number);

CREATE TABLE IF NOT EXISTS training_datasets (
  id BIGINT GENERATED ALWAYS AS IDENTITY,
  name VARCHAR(150) NOT NULL,
  file_path VARCHAR(1000) NOT NULL,
  file_type VARCHAR(20) NOT NULL DEFAULT 'sgf'
    CHECK (file_type IN ('sgf', 'text', 'archive', 'other')),
  status VARCHAR(20) NOT NULL DEFAULT 'registered'
    CHECK (status IN ('registered', 'training', 'completed', 'failed')),
  games_count INTEGER NOT NULL DEFAULT 0,
  created_by BIGINT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  CONSTRAINT fk_training_datasets_created_by
    FOREIGN KEY (created_by) REFERENCES users(id)
    ON DELETE SET NULL
);
CREATE INDEX IF NOT EXISTS idx_training_datasets_status ON training_datasets (status, created_at);
DROP TRIGGER IF EXISTS trg_training_datasets_updated_at ON training_datasets;
CREATE TRIGGER trg_training_datasets_updated_at BEFORE UPDATE ON training_datasets
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE IF NOT EXISTS admin_audit_logs (
  id BIGINT GENERATED ALWAYS AS IDENTITY,
  admin_user_id BIGINT NULL,
  action VARCHAR(100) NOT NULL,
  target_type VARCHAR(100) NOT NULL,
  target_id VARCHAR(100) NULL,
  details JSONB NULL,
  ip_address VARCHAR(45) NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  CONSTRAINT fk_admin_audit_logs_admin
    FOREIGN KEY (admin_user_id) REFERENCES users(id)
    ON DELETE SET NULL
);
CREATE INDEX IF NOT EXISTS idx_admin_audit_logs_admin ON admin_audit_logs (admin_user_id, created_at);
CREATE INDEX IF NOT EXISTS idx_admin_audit_logs_target ON admin_audit_logs (target_type, target_id);
