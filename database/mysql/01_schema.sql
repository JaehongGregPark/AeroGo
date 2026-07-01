CREATE TABLE IF NOT EXISTS users (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  username VARCHAR(255) NOT NULL,
  email VARCHAR(255) NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  role ENUM('admin', 'user') NOT NULL DEFAULT 'user',
  status ENUM('pending_email', 'active', 'disabled', 'locked') NOT NULL DEFAULT 'pending_email',
  email_verified BOOLEAN NOT NULL DEFAULT FALSE,
  email_verification_sent_at DATETIME NULL,
  email_confirmed_at DATETIME NULL,
  terms_accepted_at DATETIME NULL,
  display_name VARCHAR(100) NULL,
  last_login_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_users_username (username),
  UNIQUE KEY uq_users_email (email),
  KEY idx_users_role_status (role, status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS email_verification_tokens (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NOT NULL,
  token_hash CHAR(64) NOT NULL,
  purpose ENUM('signup_confirm', 'email_change') NOT NULL DEFAULT 'signup_confirm',
  expires_at DATETIME NOT NULL,
  used_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_email_verification_tokens_hash (token_hash),
  KEY idx_email_verification_tokens_user (user_id, purpose, used_at, expires_at),
  CONSTRAINT fk_email_verification_tokens_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS system_settings (
  setting_key VARCHAR(100) NOT NULL,
  setting_value JSON NOT NULL,
  description VARCHAR(500) NULL,
  updated_by BIGINT UNSIGNED NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (setting_key),
  CONSTRAINT fk_system_settings_updated_by
    FOREIGN KEY (updated_by) REFERENCES users(id)
    ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS game_records (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  owner_user_id BIGINT UNSIGNED NULL,
  black_player_id BIGINT UNSIGNED NULL,
  white_player_id BIGINT UNSIGNED NULL,
  black_player_name VARCHAR(150) NULL,
  white_player_name VARCHAR(150) NULL,
  title VARCHAR(255) NOT NULL,
  board_size TINYINT UNSIGNED NOT NULL,
  komi DECIMAL(4,1) NOT NULL DEFAULT 6.5,
  game_mode ENUM('human_vs_human', 'human_vs_ai', 'ai_vs_ai') NOT NULL,
  status ENUM('ongoing', 'completed', 'imported', 'archived') NOT NULL DEFAULT 'ongoing',
  winner ENUM('black', 'white', 'draw', 'unknown') NOT NULL DEFAULT 'unknown',
  result_text VARCHAR(50) NULL,
  black_captures INT UNSIGNED NOT NULL DEFAULT 0,
  white_captures INT UNSIGNED NOT NULL DEFAULT 0,
  sgf_text LONGTEXT NULL,
  source_name VARCHAR(150) NULL,
  source_url VARCHAR(1000) NULL,
  source_record_id VARCHAR(100) NULL,
  source_license_note VARCHAR(500) NULL,
  imported_at DATETIME NULL,
  started_at DATETIME NULL,
  ended_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_game_records_owner (owner_user_id, created_at),
  KEY idx_game_records_status (status, created_at),
  FULLTEXT KEY ft_game_records_title_sgf (title, sgf_text),
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS game_moves (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  game_record_id BIGINT UNSIGNED NOT NULL,
  move_number INT UNSIGNED NOT NULL,
  color ENUM('black', 'white') NOT NULL,
  row_index TINYINT UNSIGNED NULL,
  col_index TINYINT UNSIGNED NULL,
  is_pass BOOLEAN NOT NULL DEFAULT FALSE,
  captured_count INT UNSIGNED NOT NULL DEFAULT 0,
  board_snapshot JSON NULL,
  played_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_game_moves_number (game_record_id, move_number),
  KEY idx_game_moves_game (game_record_id, played_at),
  CONSTRAINT fk_game_moves_game
    FOREIGN KEY (game_record_id) REFERENCES game_records(id)
    ON DELETE CASCADE,
  CONSTRAINT chk_game_moves_point_or_pass
    CHECK (
      (is_pass = TRUE AND row_index IS NULL AND col_index IS NULL)
      OR
      (is_pass = FALSE AND row_index IS NOT NULL AND col_index IS NOT NULL)
    )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS ai_analysis (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  game_record_id BIGINT UNSIGNED NOT NULL,
  move_number INT UNSIGNED NULL,
  model_name VARCHAR(100) NOT NULL,
  difficulty ENUM('beginner', 'intermediate', 'advanced') NOT NULL,
  mcts_visits INT UNSIGNED NOT NULL DEFAULT 0,
  black_winrate DECIMAL(5,2) NULL,
  score_lead DECIMAL(6,2) NULL,
  analysis_json JSON NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_ai_analysis_game_move (game_record_id, move_number),
  CONSTRAINT fk_ai_analysis_game
    FOREIGN KEY (game_record_id) REFERENCES game_records(id)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS training_datasets (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  name VARCHAR(150) NOT NULL,
  file_path VARCHAR(1000) NOT NULL,
  file_type ENUM('sgf', 'text', 'archive', 'other') NOT NULL DEFAULT 'sgf',
  status ENUM('registered', 'training', 'completed', 'failed') NOT NULL DEFAULT 'registered',
  games_count INT UNSIGNED NOT NULL DEFAULT 0,
  created_by BIGINT UNSIGNED NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_training_datasets_status (status, created_at),
  CONSTRAINT fk_training_datasets_created_by
    FOREIGN KEY (created_by) REFERENCES users(id)
    ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS admin_audit_logs (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  admin_user_id BIGINT UNSIGNED NULL,
  action VARCHAR(100) NOT NULL,
  target_type VARCHAR(100) NOT NULL,
  target_id VARCHAR(100) NULL,
  details JSON NULL,
  ip_address VARCHAR(45) NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_admin_audit_logs_admin (admin_user_id, created_at),
  KEY idx_admin_audit_logs_target (target_type, target_id),
  CONSTRAINT fk_admin_audit_logs_admin
    FOREIGN KEY (admin_user_id) REFERENCES users(id)
    ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
