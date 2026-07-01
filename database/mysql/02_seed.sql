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
ON DUPLICATE KEY UPDATE
  role = VALUES(role),
  status = VALUES(status),
  email_verified = VALUES(email_verified),
  display_name = VALUES(display_name);

INSERT INTO system_settings (
  setting_key,
  setting_value,
  description,
  updated_by
) VALUES
  (
    'game.defaults',
    JSON_OBJECT(
      'boardSize', 19,
      'komi', 6.5,
      'gameMode', 'human_vs_human'
    ),
    'Default game settings',
    (SELECT id FROM users WHERE username = 'admin')
  ),
  (
    'ai.defaults',
    JSON_OBJECT(
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
    JSON_OBJECT(
      'boardSkin', 'classic',
      'stoneStyle', 'flat',
      'showCoordinates', true
    ),
    'Default visual settings',
    (SELECT id FROM users WHERE username = 'admin')
  )
ON DUPLICATE KEY UPDATE
  setting_value = VALUES(setting_value),
  description = VALUES(description),
  updated_by = VALUES(updated_by);

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
  JSON_OBJECT('message', 'Initial AeroGo MySQL seed data applied')
);
