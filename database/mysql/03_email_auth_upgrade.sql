ALTER TABLE users
  MODIFY COLUMN username VARCHAR(255) NOT NULL;

ALTER TABLE users
  MODIFY COLUMN status ENUM('pending_email', 'active', 'disabled', 'locked')
  NOT NULL DEFAULT 'pending_email';

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS email_verified BOOLEAN NOT NULL DEFAULT FALSE AFTER status,
  ADD COLUMN IF NOT EXISTS email_verification_sent_at DATETIME NULL AFTER email_verified,
  ADD COLUMN IF NOT EXISTS email_confirmed_at DATETIME NULL AFTER email_verification_sent_at,
  ADD COLUMN IF NOT EXISTS terms_accepted_at DATETIME NULL AFTER email_confirmed_at;

UPDATE users
SET email_verified = TRUE,
    email_confirmed_at = COALESCE(email_confirmed_at, CURRENT_TIMESTAMP),
    terms_accepted_at = COALESCE(terms_accepted_at, CURRENT_TIMESTAMP)
WHERE status = 'active'
  AND email_verified = FALSE;

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

ALTER TABLE game_records
  ADD COLUMN IF NOT EXISTS black_player_name VARCHAR(150) NULL AFTER white_player_id,
  ADD COLUMN IF NOT EXISTS white_player_name VARCHAR(150) NULL AFTER black_player_name,
  ADD COLUMN IF NOT EXISTS result_text VARCHAR(50) NULL AFTER winner,
  ADD COLUMN IF NOT EXISTS source_name VARCHAR(150) NULL AFTER sgf_text,
  ADD COLUMN IF NOT EXISTS source_url VARCHAR(1000) NULL AFTER source_name,
  ADD COLUMN IF NOT EXISTS source_record_id VARCHAR(100) NULL AFTER source_url,
  ADD COLUMN IF NOT EXISTS source_license_note VARCHAR(500) NULL AFTER source_record_id,
  ADD COLUMN IF NOT EXISTS imported_at DATETIME NULL AFTER source_license_note;
