import 'package:flutter/material.dart';

import '../models/enums.dart';
import '../models/user_environment_settings.dart';

/// "환경 설정" screen: edits a working copy of [UserEnvironmentSettings]
/// and calls [onSave] (debounced per-change) to persist it.
class UserEnvironmentSettingsPanel extends StatefulWidget {
  const UserEnvironmentSettingsPanel({
    required this.role,
    required this.settings,
    required this.onSave,
    super.key,
  });

  final UserRole role;
  final UserEnvironmentSettings settings;
  final Future<void> Function(UserEnvironmentSettings settings) onSave;

  @override
  State<UserEnvironmentSettingsPanel> createState() =>
      _UserEnvironmentSettingsPanelState();
}

class _UserEnvironmentSettingsPanelState
    extends State<UserEnvironmentSettingsPanel> {
  late UserEnvironmentSettings settings;
  late TextEditingController autoReplayIntervalController;
  String? intervalError;
  bool saved = false;

  @override
  void initState() {
    super.initState();
    settings = widget.settings.copy();
    autoReplayIntervalController = TextEditingController(
      text: settings.autoReplayIntervalSeconds.toString(),
    );
  }

  @override
  void didUpdateWidget(UserEnvironmentSettingsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.role != widget.role ||
        oldWidget.settings != widget.settings) {
      settings = widget.settings.copy();
      autoReplayIntervalController.text =
          settings.autoReplayIntervalSeconds.toString();
      intervalError = null;
      saved = false;
    }
  }

  @override
  void dispose() {
    autoReplayIntervalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 840),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: DefaultTabController(
              length: 2,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.settings),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '환경 설정',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            Text('${widget.role.label}별 개인 설정'),
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _save,
                        icon: const Icon(Icons.save),
                        label: const Text('저장'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const TabBar(
                    tabs: [
                      Tab(icon: Icon(Icons.description), text: '기보/해설'),
                      Tab(icon: Icon(Icons.volume_up), text: '소리'),
                    ],
                  ),
                  SizedBox(
                    height: 440,
                    child: TabBarView(
                      children: [
                        _buildRecordCommentaryTab(),
                        _buildSoundTab(),
                      ],
                    ),
                  ),
                  if (saved)
                    const Text(
                      '현재 사용자 설정으로 저장되었습니다.',
                      style: TextStyle(color: Color(0xff1b6b35)),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecordCommentaryTab() {
    return ListView(
      padding: const EdgeInsets.only(top: 16),
      children: [
        SwitchListTile(
          title: const Text('참고도 표시'),
          value: settings.showReferenceDiagram,
          onChanged: (value) =>
              _updateSettings(() => settings.showReferenceDiagram = value),
        ),
        SwitchListTile(
          title: const Text('본인기보 자동저장'),
          value: settings.autoSaveOwnRecords,
          onChanged: (value) =>
              _updateSettings(() => settings.autoSaveOwnRecords = value),
        ),
        SwitchListTile(
          title: const Text('관전기보 자동저장'),
          value: settings.autoSaveObservedRecords,
          onChanged: (value) =>
              _updateSettings(() => settings.autoSaveObservedRecords = value),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            controller: autoReplayIntervalController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: '수순자동진행 시간간격(초)',
              helperText: '가능범위 1-360초',
              errorText: intervalError,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) {
              if (intervalError != null) {
                setState(() => intervalError = null);
              }
            },
          ),
        ),
        SwitchListTile(
          title: const Text('수순표시'),
          subtitle: const Text('선택 시 흑돌 또는 백돌 위에 수순을 표시합니다.'),
          value: settings.showMoveNumbers,
          onChanged: (value) =>
              _updateSettings(() => settings.showMoveNumbers = value),
        ),
      ],
    );
  }

  Widget _buildSoundTab() {
    return ListView(
      padding: const EdgeInsets.only(top: 16),
      children: [
        SwitchListTile(
          title: const Text('대국/관전시 착점소리'),
          value: settings.playStoneSoundInGame,
          onChanged: (value) =>
              _updateSettings(() => settings.playStoneSoundInGame = value),
        ),
        SwitchListTile(
          title: const Text('기보보기시 착점소리'),
          value: settings.playStoneSoundInRecordReview,
          onChanged: (value) => _updateSettings(
              () => settings.playStoneSoundInRecordReview = value),
        ),
        SwitchListTile(
          title: const Text('초읽기 소리'),
          value: settings.playCountdownSound,
          onChanged: (value) =>
              _updateSettings(() => settings.playCountdownSound = value),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Text('착점소리', style: Theme.of(context).textTheme.titleSmall),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<StoneSoundVolume>(
            segments: const [
              ButtonSegment(value: StoneSoundVolume.loud, label: Text('크게')),
              ButtonSegment(value: StoneSoundVolume.normal, label: Text('보통')),
              ButtonSegment(value: StoneSoundVolume.small, label: Text('작게')),
            ],
            selected: {settings.stoneSoundVolume},
            onSelectionChanged: (selected) {
              _updateSettings(() => settings.stoneSoundVolume = selected.first);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 6),
          child: Text('초읽기소리음성', style: Theme.of(context).textTheme.titleSmall),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<CountdownVoice>(
            segments: const [
              ButtonSegment(value: CountdownVoice.male, label: Text('남성')),
              ButtonSegment(value: CountdownVoice.female, label: Text('여성')),
            ],
            selected: {settings.countdownVoice},
            onSelectionChanged: (selected) {
              _updateSettings(() => settings.countdownVoice = selected.first);
            },
          ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final seconds = int.tryParse(autoReplayIntervalController.text.trim());
    if (seconds == null || seconds < 1 || seconds > 360) {
      setState(() {
        intervalError = '1초에서 360초 사이로 입력해 주세요.';
        saved = false;
      });
      return;
    }

    settings.autoReplayIntervalSeconds = seconds;
    await widget.onSave(settings.copy());
    if (!mounted) {
      return;
    }
    setState(() {
      saved = true;
      intervalError = null;
    });
  }

  Future<void> _updateSettings(VoidCallback update) async {
    update();
    await widget.onSave(settings.copy());
    if (!mounted) {
      return;
    }
    setState(() {
      saved = false;
    });
  }
}
