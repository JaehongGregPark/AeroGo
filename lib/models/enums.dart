// Shared enums used across the AeroGo app (menus, game setup, settings)
// and their small `label`/value extensions.
//
// Extracted from lib/main.dart, which used to define every enum, model,
// widget, and the Go engine in a single ~2100-line file.

enum UserRole { user, admin }

enum GameMode { humanVsHuman, humanVsAi, aiVsAi }

enum AiDifficulty { beginner, intermediate, advanced }

enum StoneSoundVolume { loud, normal, small }

enum CountdownVoice { male, female }

extension UserRoleLabel on UserRole {
  String get label => switch (this) {
        UserRole.user => '일반사용자',
        UserRole.admin => '관리자',
      };
}

extension GameModeLabel on GameMode {
  String get label => switch (this) {
        GameMode.humanVsHuman => '사람 vs 사람',
        GameMode.humanVsAi => '사람 vs AI',
        GameMode.aiVsAi => 'AI vs AI',
      };
}

extension AiDifficultyLabel on AiDifficulty {
  String get label => switch (this) {
        AiDifficulty.beginner => '초급',
        AiDifficulty.intermediate => '중급',
        AiDifficulty.advanced => '고급',
      };

  int get visits => switch (this) {
        AiDifficulty.beginner => 100,
        AiDifficulty.intermediate => 800,
        AiDifficulty.advanced => 3000,
      };
}

extension StoneSoundVolumeLevel on StoneSoundVolume {
  double get volume => switch (this) {
        StoneSoundVolume.loud => 1.0,
        StoneSoundVolume.normal => 0.62,
        StoneSoundVolume.small => 0.32,
      };
}
