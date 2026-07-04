import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'enums.dart';

/// Per-user, per-role display/sound preferences. Persisted locally via
/// [SharedPreferences] under a per-role key (see [_environmentSettingsKey]).
///
/// Note: the backend also exposes
/// `GET/PUT /users/{user_id}/preferences/environment` with the same JSON
/// shape (see backend/app/main.py), but the Flutter app does not call it yet
/// -- settings only round-trip through local storage today.
class UserEnvironmentSettings {
  UserEnvironmentSettings({
    required this.showReferenceDiagram,
    required this.autoSaveOwnRecords,
    required this.autoSaveObservedRecords,
    required this.autoReplayIntervalSeconds,
    required this.showMoveNumbers,
    required this.playStoneSoundInGame,
    required this.playStoneSoundInRecordReview,
    required this.playCountdownSound,
    required this.stoneSoundVolume,
    required this.countdownVoice,
  });

  factory UserEnvironmentSettings.defaults() {
    return UserEnvironmentSettings(
      showReferenceDiagram: true,
      autoSaveOwnRecords: true,
      autoSaveObservedRecords: false,
      autoReplayIntervalSeconds: 3,
      showMoveNumbers: false,
      playStoneSoundInGame: true,
      playStoneSoundInRecordReview: true,
      playCountdownSound: true,
      stoneSoundVolume: StoneSoundVolume.normal,
      countdownVoice: CountdownVoice.female,
    );
  }

  factory UserEnvironmentSettings.fromJson(Map<String, dynamic> json) {
    final defaults = UserEnvironmentSettings.defaults();
    return UserEnvironmentSettings(
      showReferenceDiagram: json['showReferenceDiagram'] as bool? ??
          defaults.showReferenceDiagram,
      autoSaveOwnRecords:
          json['autoSaveOwnRecords'] as bool? ?? defaults.autoSaveOwnRecords,
      autoSaveObservedRecords: json['autoSaveObservedRecords'] as bool? ??
          defaults.autoSaveObservedRecords,
      autoReplayIntervalSeconds: json['autoReplayIntervalSeconds'] as int? ??
          defaults.autoReplayIntervalSeconds,
      showMoveNumbers:
          json['showMoveNumbers'] as bool? ?? defaults.showMoveNumbers,
      playStoneSoundInGame: json['playStoneSoundInGame'] as bool? ??
          defaults.playStoneSoundInGame,
      playStoneSoundInRecordReview:
          json['playStoneSoundInRecordReview'] as bool? ??
              defaults.playStoneSoundInRecordReview,
      playCountdownSound:
          json['playCountdownSound'] as bool? ?? defaults.playCountdownSound,
      stoneSoundVolume: StoneSoundVolume.values.firstWhere(
        (value) => value.name == json['stoneSoundVolume'],
        orElse: () => defaults.stoneSoundVolume,
      ),
      countdownVoice: CountdownVoice.values.firstWhere(
        (value) => value.name == json['countdownVoice'],
        orElse: () => defaults.countdownVoice,
      ),
    );
  }

  bool showReferenceDiagram;
  bool autoSaveOwnRecords;
  bool autoSaveObservedRecords;
  int autoReplayIntervalSeconds;
  bool showMoveNumbers;
  bool playStoneSoundInGame;
  bool playStoneSoundInRecordReview;
  bool playCountdownSound;
  StoneSoundVolume stoneSoundVolume;
  CountdownVoice countdownVoice;

  UserEnvironmentSettings copy() {
    return UserEnvironmentSettings(
      showReferenceDiagram: showReferenceDiagram,
      autoSaveOwnRecords: autoSaveOwnRecords,
      autoSaveObservedRecords: autoSaveObservedRecords,
      autoReplayIntervalSeconds: autoReplayIntervalSeconds,
      showMoveNumbers: showMoveNumbers,
      playStoneSoundInGame: playStoneSoundInGame,
      playStoneSoundInRecordReview: playStoneSoundInRecordReview,
      playCountdownSound: playCountdownSound,
      stoneSoundVolume: stoneSoundVolume,
      countdownVoice: countdownVoice,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'showReferenceDiagram': showReferenceDiagram,
      'autoSaveOwnRecords': autoSaveOwnRecords,
      'autoSaveObservedRecords': autoSaveObservedRecords,
      'autoReplayIntervalSeconds': autoReplayIntervalSeconds,
      'showMoveNumbers': showMoveNumbers,
      'playStoneSoundInGame': playStoneSoundInGame,
      'playStoneSoundInRecordReview': playStoneSoundInRecordReview,
      'playCountdownSound': playCountdownSound,
      'stoneSoundVolume': stoneSoundVolume.name,
      'countdownVoice': countdownVoice.name,
    };
  }
}

Map<UserRole, UserEnvironmentSettings> _defaultEnvironmentSettingsByRole() {
  return {
    UserRole.user: UserEnvironmentSettings.defaults(),
    UserRole.admin: UserEnvironmentSettings.defaults(),
  };
}

/// Loads saved settings for every role, falling back to defaults when a
/// role has nothing saved yet or its saved value fails to parse.
Future<Map<UserRole, UserEnvironmentSettings>>
    loadInitialEnvironmentSettings() async {
  final settingsByRole = _defaultEnvironmentSettingsByRole();
  final preferences = await SharedPreferences.getInstance();
  for (final userRole in UserRole.values) {
    final value = preferences.getString(_environmentSettingsKey(userRole));
    if (value == null) {
      continue;
    }
    try {
      settingsByRole[userRole] = UserEnvironmentSettings.fromJson(
        jsonDecode(value) as Map<String, dynamic>,
      );
    } catch (_) {
      settingsByRole[userRole] = UserEnvironmentSettings.defaults();
    }
  }
  return settingsByRole;
}

/// Persists [settings] for [userRole] to local storage.
Future<void> persistEnvironmentSettings(
  UserRole userRole,
  UserEnvironmentSettings settings,
) async {
  final preferences = await SharedPreferences.getInstance();
  await preferences.setString(
    _environmentSettingsKey(userRole),
    jsonEncode(settings.toJson()),
  );
  await preferences.reload();
}

String _environmentSettingsKey(UserRole userRole) {
  return 'aerogo.environmentSettings.${userRole.name}';
}
