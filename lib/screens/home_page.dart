import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../game/go_engine.dart';
import '../models/enums.dart';
import '../models/menu.dart';
import '../models/user_environment_settings.dart';
import '../widgets/admin_panels.dart';
import '../widgets/analysis_bar.dart';
import '../widgets/app_menu.dart';
import '../widgets/broadcast_service_panel.dart';
import '../widgets/dialog_choice.dart';
import '../widgets/game_board_panel.dart';
import '../widgets/header.dart';
import '../widgets/info_panel.dart';
import '../widgets/signup_verification_panel.dart';
import '../widgets/user_environment_settings_panel.dart';

/// AeroGo's single screen: a persistent side nav + menu, with the main
/// content area switching between the board, settings, and the various
/// placeholder/admin panels based on [_AeroGoHomePageState.selectedMenu].
class AeroGoHomePage extends StatefulWidget {
  const AeroGoHomePage({
    required this.initialEnvironmentSettings,
    super.key,
  });

  final Map<UserRole, UserEnvironmentSettings> initialEnvironmentSettings;

  @override
  State<AeroGoHomePage> createState() => _AeroGoHomePageState();
}

class _AeroGoHomePageState extends State<AeroGoHomePage> {
  UserRole role = UserRole.user;
  int boardSize = 19;
  GameMode gameMode = GameMode.humanVsHuman;
  AiDifficulty difficulty = AiDifficulty.beginner;
  String selectedMenu = '대국';
  final GoGame game = GoGame(size: 19);
  final GoAiPlayer aiPlayer = GoAiPlayer();
  final AudioPlayer stoneSoundPlayer = AudioPlayer();
  late final Map<UserRole, UserEnvironmentSettings> environmentSettingsByRole;
  bool aiThinking = false;

  @override
  void initState() {
    super.initState();
    environmentSettingsByRole = Map<UserRole, UserEnvironmentSettings>.from(
      widget.initialEnvironmentSettings,
    );
  }

  @override
  void dispose() {
    stoneSoundPlayer.dispose();
    super.dispose();
  }

  List<MenuSection> get menuSections {
    final sections = <MenuSection>[
      MenuSection(
        title: '새 게임 시작',
        items: [
          MenuItem('대국 환경 설정', Icons.grid_on, () => _showBoardSizeDialog()),
          MenuItem('대국 모드', Icons.groups, () => _showGameModeDialog()),
          MenuItem('AI 난이도 설정', Icons.memory, () => _showDifficultyDialog()),
          MenuItem('새 게임', Icons.add_circle_outline, () => _newGame()),
        ],
      ),
      MenuSection(
        title: '계정',
        items: [
          MenuItem(
            '회원가입/이메일 인증',
            Icons.mark_email_read,
            () => _selectMenu('회원가입/이메일 인증'),
          ),
        ],
      ),
      MenuSection(
        title: '대국 관리',
        items: [
          MenuItem('Undo', Icons.undo, () => setState(game.undo)),
          MenuItem('Redo', Icons.redo, () => setState(game.redo)),
          MenuItem('형세 분석', Icons.bar_chart, () => _selectMenu('형세 분석')),
          MenuItem('기보 저장/불러오기', Icons.description, () => _selectMenu('기보')),
        ],
      ),
      MenuSection(
        title: '중계/관전',
        items: [
          MenuItem(
            '무료 중계 서비스',
            Icons.live_tv,
            () => _selectMenu('무료 중계 서비스'),
          ),
          MenuItem(
            'AeroGo 중계방',
            Icons.sensors,
            () => _selectMenu('AeroGo 중계방'),
          ),
          MenuItem(
            'SGF 가져오기',
            Icons.upload_file,
            () => _selectMenu('SGF 가져오기'),
          ),
        ],
      ),
      MenuSection(
        title: '학습 및 분석',
        items: [
          MenuItem('기보 학습 모드', Icons.school, () => _selectMenu('기보 학습')),
          MenuItem('AI 모델 상태 확인', Icons.psychology, () => _selectMenu('AI 모델')),
        ],
      ),
      MenuSection(
        title: '설정',
        items: [
          MenuItem('시각화 옵션', Icons.palette, () => _selectMenu('시각화 옵션')),
          MenuItem('환경 설정', Icons.settings, () => _selectMenu('환경 설정')),
        ],
      ),
    ];

    if (role == UserRole.admin) {
      sections.add(
        MenuSection(
          title: '관리자 메뉴',
          items: [
            MenuItem(
              '시스템 전체 환경관리',
              Icons.admin_panel_settings,
              () => _selectMenu('시스템 전체 환경관리'),
            ),
            MenuItem(
              '사용자 관리',
              Icons.manage_accounts,
              () => _selectMenu('사용자 관리'),
            ),
            MenuItem('기보관리', Icons.folder_copy, () => _selectMenu('기보관리')),
          ],
        ),
      );
    }

    sections.add(
      MenuSection(
        title: '종료',
        items: [
          MenuItem('앱 종료 안내', Icons.exit_to_app, () => _selectMenu('종료')),
        ],
      ),
    );
    return sections;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: MediaQuery.sizeOf(context).width >= 980,
            selectedIndex: role == UserRole.admin ? 1 : 0,
            onDestinationSelected: (index) {
              setState(() {
                role = index == 0 ? UserRole.user : UserRole.admin;
              });
            },
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: Text('일반사용자'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.shield_outlined),
                selectedIcon: Icon(Icons.shield),
                label: Text('관리자'),
              ),
            ],
          ),
          const VerticalDivider(width: 1),
          SizedBox(
            width: 292,
            child: AppMenu(
              role: role,
              sections: menuSections,
              selectedMenu: selectedMenu,
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              children: [
                AeroGoHeader(
                  role: role,
                  boardSize: boardSize,
                  gameMode: gameMode,
                  difficulty: difficulty,
                  selectedMenu: selectedMenu,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: _buildContent(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (selectedMenu == '대국') {
      return GameBoardPanel(
        game: game,
        aiThinking: aiThinking,
        gameMode: gameMode,
        settings: environmentSettingsByRole[role]!,
        onPointTap: (row, col) {
          if (aiThinking || _isHumanInputBlocked) {
            return;
          }
          final played = game.play(row, col);
          if (played) {
            _playStoneSoundIfEnabled();
          }
          setState(() {});
          if (played) {
            _playAiIfNeeded();
          }
        },
        onPass: () {
          if (aiThinking || _isHumanInputBlocked) {
            return;
          }
          setState(game.passTurn);
          _playAiIfNeeded();
        },
        onAiMove: _playAiIfNeeded,
      );
    }

    if (selectedMenu == '회원가입/이메일 인증') {
      return const SignupVerificationPanel();
    }

    if (selectedMenu == '형세 분석') {
      return InfoPanel(
        title: '형세 분석',
        icon: Icons.bar_chart,
        children: [
          AnalysisBar(game: game),
          const SizedBox(height: 16),
          Text('흑 포획: ${game.blackCaptures}'),
          Text('백 포획: ${game.whiteCaptures}'),
          const Text('현재는 돌 수와 포획 수 기반의 간단 분석입니다.'),
        ],
      );
    }

    if (selectedMenu == '기보') {
      return const InfoPanel(
        title: '기보 저장/불러오기',
        icon: Icons.description,
        children: [
          Text('Flutter 버전에서는 SGF 저장/불러오기 화면을 준비 중입니다.'),
          Text('Python 버전의 SGF 엔진을 Dart로 이전하면 이 메뉴에 연결됩니다.'),
        ],
      );
    }

    if (selectedMenu == '무료 중계 서비스') {
      return const BroadcastServicePanel();
    }

    if (selectedMenu == 'AeroGo 중계방') {
      return const InfoPanel(
        title: 'AeroGo 중계방',
        icon: Icons.sensors,
        children: [
          Text('외부 서비스와 독립적으로 AeroGo 안에서 대국을 중계하고 관전하는 화면입니다.'),
          Text('권장 흐름: 관리자가 대국을 만들고 착수를 입력하면 사용자는 실시간 보드로 관전합니다.'),
          Text(
              '백엔드에 /games/live, /admin/live-games, /admin/live-games/{id}/moves API를 붙이면 이 메뉴에서 바로 목록과 보드를 표시할 수 있습니다.'),
          Text(
              '타이젬, KGS, Pandanet, OGS는 약관과 공개 API 여부를 확인한 뒤 허가된 데이터만 연결하는 방식이 안전합니다.'),
        ],
      );
    }

    if (selectedMenu == 'SGF 가져오기') {
      return const InfoPanel(
        title: 'SGF 가져오기',
        icon: Icons.upload_file,
        children: [
          Text('공개 기보나 허가받은 SGF 파일을 AeroGo 표준 기보로 가져오는 화면입니다.'),
          Text('현재 DB에는 game_records.sgf_text와 game_moves 저장 구조가 준비되어 있습니다.'),
          Text(
              '다음 단계에서는 SGF 업로드, 선수명/결과/날짜 파싱, 착수 재생, 출처 URL 기록 기능을 연결하면 됩니다.'),
          Text(
              '저작권 확인이 어려운 중계 데이터는 SGF 전문 저장 대신 출처 링크와 메타데이터만 저장하는 방식을 권장합니다.'),
        ],
      );
    }

    if (selectedMenu == '기보 학습') {
      return const InfoPanel(
        title: '기보 학습 모드',
        icon: Icons.school,
        children: [Text('데이터셋 파일 경로 지정, 학습 시작, 진행률 표시 UI가 들어갈 영역입니다.')],
      );
    }

    if (selectedMenu == 'AI 모델') {
      return const InfoPanel(
        title: 'AI 모델 상태 확인',
        icon: Icons.psychology,
        children: [
          Text('현재 로드된 신경망 가중치가 없습니다.'),
          Text('MCTS 및 모델 로더를 추가하면 상태와 버전을 표시합니다.'),
        ],
      );
    }

    if (selectedMenu == '시각화 옵션') {
      return const InfoPanel(
        title: '시각화 옵션',
        icon: Icons.palette,
        children: [Text('바둑판 스킨, 돌 디자인, 좌표 표시 옵션을 관리하는 화면입니다.')],
      );
    }

    if (selectedMenu == '환경 설정') {
      return UserEnvironmentSettingsPanel(
        role: role,
        settings: environmentSettingsByRole[role]!,
        onSave: (settings) {
          setState(() {
            environmentSettingsByRole[role] = settings;
          });
          return persistEnvironmentSettings(role, settings);
        },
      );
    }

    if (selectedMenu == '시스템 전체 환경관리') {
      return const InfoPanel(
        title: '시스템 전체 환경관리',
        icon: Icons.admin_panel_settings,
        children: [
          Text('관리자 전용 메뉴입니다.'),
          Text('전역 AI 설정, 서버 연결, 저장소 경로, 로그 정책을 관리합니다.'),
        ],
      );
    }

    if (selectedMenu == '사용자 관리') {
      return const UserManagementPanel();
    }

    if (selectedMenu == '기보관리') {
      return const RecordManagementPanel();
    }

    return const InfoPanel(
      title: '종료',
      icon: Icons.exit_to_app,
      children: [Text('데스크톱/모바일 환경에서는 운영체제의 뒤로가기 또는 창 닫기를 사용합니다.')],
    );
  }

  void _selectMenu(String menu) {
    setState(() {
      selectedMenu = menu;
    });
  }

  void _newGame() {
    setState(() {
      game.reset(boardSize);
      selectedMenu = '대국';
    });
    _playAiIfNeeded();
  }

  Future<void> _showBoardSizeDialog() async {
    final selected = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('대국 환경 설정'),
        children: [
          for (final size in [19, 13, 9])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, size),
              child: DialogChoice(
                label: '$size x $size',
                selected: size == boardSize,
              ),
            ),
        ],
      ),
    );
    if (selected != null) {
      setState(() {
        boardSize = selected;
        game.reset(selected);
        selectedMenu = '대국';
      });
    }
  }

  Future<void> _showGameModeDialog() async {
    final selected = await showDialog<GameMode>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('대국 모드'),
        children: [
          for (final mode in GameMode.values)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, mode),
              child: DialogChoice(
                label: mode.label,
                selected: mode == gameMode,
              ),
            ),
        ],
      ),
    );
    if (selected != null) {
      setState(() {
        gameMode = selected;
      });
      _playAiIfNeeded();
    }
  }

  Future<void> _showDifficultyDialog() async {
    final selected = await showDialog<AiDifficulty>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('AI 난이도 설정'),
        children: [
          for (final item in AiDifficulty.values)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, item),
              child: DialogChoice(
                label: '${item.label} - MCTS ${item.visits}회',
                selected: item == difficulty,
              ),
            ),
        ],
      ),
    );
    if (selected != null) {
      setState(() {
        difficulty = selected;
      });
    }
  }

  bool get _isHumanInputBlocked {
    return gameMode == GameMode.aiVsAi ||
        (gameMode == GameMode.humanVsAi && game.turn == Stone.white);
  }

  Future<void> _playAiIfNeeded() async {
    if (!mounted || selectedMenu != '대국' || aiThinking) {
      return;
    }

    final shouldPlay = gameMode == GameMode.aiVsAi ||
        (gameMode == GameMode.humanVsAi && game.turn == Stone.white);
    if (!shouldPlay) {
      return;
    }

    setState(() {
      aiThinking = true;
      game.message = '${game.turn.label} AI가 수를 읽는 중입니다.';
    });
    await Future<void>.delayed(const Duration(milliseconds: 260));
    if (!mounted) {
      return;
    }

    setState(() {
      final played = aiPlayer.play(game, difficulty);
      if (played) {
        _playStoneSoundIfEnabled();
      }
      aiThinking = false;
    });

    if (gameMode == GameMode.aiVsAi) {
      Future<void>.delayed(const Duration(milliseconds: 260), _playAiIfNeeded);
    }
  }

  Future<void> _playStoneSoundIfEnabled() async {
    final settings = environmentSettingsByRole[role]!;
    if (!settings.playStoneSoundInGame) {
      return;
    }
    try {
      await stoneSoundPlayer.stop();
      await stoneSoundPlayer.setVolume(settings.stoneSoundVolume.volume);
      await stoneSoundPlayer.play(AssetSource('sounds/stone_click.wav'));
    } catch (_) {
      // Audio output can fail on devices without an initialized audio backend.
    }
  }
}
