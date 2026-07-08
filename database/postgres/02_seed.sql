-- database/mysql/02_seed.sql 의 PostgreSQL 변환.
-- ON DUPLICATE KEY UPDATE -> ON CONFLICT ... DO UPDATE, JSON_OBJECT() -> jsonb_build_object().
INSERT INTO users (
  username,
  email,
  password_hash,
  role,
  status,
  email_verified,
  email_confirmed_at,
  terms_accepted_at,
  display_name
) VALUES
  (
    'admin',
    'admin@aerogo.local',
    '$2b$12$replace_with_real_admin_password_hash',
    'admin',
    'active',
    TRUE,
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP,
    'AeroGo Admin'
  ),
  (
    'guest',
    'guest@aerogo.local',
    '$2b$12$replace_with_real_guest_password_hash',
    'user',
    'active',
    TRUE,
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP,
    'Guest User'
  )
ON CONFLICT (username) DO UPDATE SET
  role = EXCLUDED.role,
  status = EXCLUDED.status,
  email_verified = EXCLUDED.email_verified,
  display_name = EXCLUDED.display_name;

INSERT INTO system_settings (
  setting_key,
  setting_value,
  description,
  updated_by
) VALUES
  (
    'game.defaults',
    jsonb_build_object(
      'boardSize', 19,
      'komi', 6.5,
      'gameMode', 'human_vs_human'
    ),
    'Default game settings',
    (SELECT id FROM users WHERE username = 'admin')
  ),
  (
    'ai.defaults',
    jsonb_build_object(
      'difficulty', 'beginner',
      'mctsVisits', 100,
      'modelName', NULL,
      'acceleration', 'cpu'
    ),
    'Default AI settings',
    (SELECT id FROM users WHERE username = 'admin')
  ),
  (
    'visual.defaults',
    jsonb_build_object(
      'boardSkin', 'classic',
      'stoneStyle', 'flat',
      'showCoordinates', true
    ),
    'Default visual settings',
    (SELECT id FROM users WHERE username = 'admin')
  )
ON CONFLICT (setting_key) DO UPDATE SET
  setting_value = EXCLUDED.setting_value,
  description = EXCLUDED.description,
  updated_by = EXCLUDED.updated_by;

INSERT INTO admin_audit_logs (
  admin_user_id,
  action,
  target_type,
  target_id,
  details
) VALUES (
  (SELECT id FROM users WHERE username = 'admin'),
  'database.seed',
  'database',
  'aerogo',
  jsonb_build_object('message', 'Initial AeroGo PostgreSQL seed data applied')
);
