import 'dart:math' as math;
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const AeroGoApp());
}

enum UserRole { user, admin }

enum GameMode { humanVsHuman, humanVsAi, aiVsAi }

enum AiDifficulty { beginner, intermediate, advanced }

class AeroGoApp extends StatelessWidget {
  const AeroGoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AeroGo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff355c3a)),
        useMaterial3: true,
      ),
      home: const AeroGoHomePage(),
    );
  }
}

class AeroGoHomePage extends StatefulWidget {
  const AeroGoHomePage({super.key});

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
  bool aiThinking = false;

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
                _Header(
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
        onPointTap: (row, col) {
          if (aiThinking || _isHumanInputBlocked) {
            return;
          }
          final played = game.play(row, col);
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
          _AnalysisBar(game: game),
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
      return const InfoPanel(
        title: '환경 설정',
        icon: Icons.settings,
        children: [Text('CPU/GPU 가속, 캐시 위치, 분석 기본값을 관리하는 화면입니다.')],
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
              child: _DialogChoice(
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
              child: _DialogChoice(
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
              child: _DialogChoice(
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
      aiPlayer.play(game, difficulty);
      aiThinking = false;
    });

    if (gameMode == GameMode.aiVsAi) {
      Future<void>.delayed(const Duration(milliseconds: 260), _playAiIfNeeded);
    }
  }
}

class AppMenu extends StatelessWidget {
  const AppMenu({
    required this.role,
    required this.sections,
    required this.selectedMenu,
    super.key,
  });

  final UserRole role;
  final List<MenuSection> sections;
  final String selectedMenu;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 18),
            child: Text(
              role == UserRole.admin ? '관리자 메뉴' : '사용자 메뉴',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          for (final section in sections)
            ExpansionTile(
              initiallyExpanded: section.title != '종료',
              title: Text(section.title),
              children: [
                for (final item in section.items)
                  ListTile(
                    selected: selectedMenu == item.label,
                    leading: Icon(item.icon),
                    title: Text(item.label),
                    onTap: item.onTap,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _DialogChoice extends StatelessWidget {
  const _DialogChoice({
    required this.label,
    required this.selected,
  });

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(label)),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.role,
    required this.boardSize,
    required this.gameMode,
    required this.difficulty,
    required this.selectedMenu,
  });

  final UserRole role;
  final int boardSize;
  final GameMode gameMode;
  final AiDifficulty difficulty;
  final String selectedMenu;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          Icon(role == UserRole.admin ? Icons.shield : Icons.person),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selectedMenu,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(
                  '${role.label} | ${boardSize}x$boardSize | ${gameMode.label} | AI ${difficulty.label}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class GameBoardPanel extends StatelessWidget {
  const GameBoardPanel({
    required this.game,
    required this.aiThinking,
    required this.gameMode,
    required this.onPointTap,
    required this.onPass,
    required this.onAiMove,
    super.key,
  });

  final GoGame game;
  final bool aiThinking;
  final GameMode gameMode;
  final void Function(int row, int col) onPointTap;
  final VoidCallback onPass;
  final VoidCallback onAiMove;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            FilledButton.icon(
              onPressed: aiThinking ? null : onPass,
              icon: const Icon(Icons.skip_next),
              label: const Text('Pass'),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: aiThinking ? null : onAiMove,
              icon: const Icon(Icons.smart_toy),
              label: Text(gameMode == GameMode.aiVsAi ? 'AI 계속' : 'AI 한 수'),
            ),
            const SizedBox(width: 12),
            Text(game.message),
            const Spacer(),
            Text('흑 포획 ${game.blackCaptures} | 백 포획 ${game.whiteCaptures}'),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xffd8a84f),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return GestureDetector(
                        onTapUp: (details) {
                          final cell = constraints.maxWidth / (game.size - 1);
                          final row = (details.localPosition.dy / cell).round();
                          final col = (details.localPosition.dx / cell).round();
                          if (row >= 0 &&
                              row < game.size &&
                              col >= 0 &&
                              col < game.size) {
                            onPointTap(row, col);
                          }
                        },
                        child: SizedBox.expand(
                          child: CustomPaint(painter: GoBoardPainter(game)),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class GoBoardPainter extends CustomPainter {
  GoBoardPainter(this.game);

  final GoGame game;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xff2f2416)
      ..strokeWidth = 1;
    final cell = size.width / (game.size - 1);

    for (var i = 0; i < game.size; i++) {
      final offset = i * cell;
      canvas.drawLine(Offset(0, offset), Offset(size.width, offset), linePaint);
      canvas.drawLine(
        Offset(offset, 0),
        Offset(offset, size.height),
        linePaint,
      );
    }

    for (final point in _starPoints(game.size)) {
      canvas.drawCircle(
        Offset(point.$2 * cell, point.$1 * cell),
        4,
        Paint()..color = const Color(0xff261b10),
      );
    }

    for (var row = 0; row < game.size; row++) {
      for (var col = 0; col < game.size; col++) {
        final stone = game.board[row][col];
        if (stone == Stone.empty) {
          continue;
        }
        final center = Offset(col * cell, row * cell);
        final radius = math.max(6.0, cell * 0.42);
        canvas.drawCircle(
          center,
          radius,
          Paint()
            ..color = stone == Stone.black
                ? const Color(0xff111111)
                : const Color(0xfff2eee7),
        );
        canvas.drawCircle(
          center,
          radius,
          Paint()
            ..color =
                stone == Stone.black ? Colors.black : const Color(0xffb7aea0)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant GoBoardPainter oldDelegate) => true;

  List<(int, int)> _starPoints(int size) {
    final points = switch (size) {
      9 => [2, 4, 6],
      13 => [3, 6, 9],
      _ => [3, 9, 15],
    };
    return [
      for (final row in points)
        for (final col in points) (row, col),
    ];
  }
}

class InfoPanel extends StatelessWidget {
  const InfoPanel({
    required this.title,
    required this.icon,
    required this.children,
    super.key,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon),
                    const SizedBox(width: 12),
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                  ],
                ),
                const SizedBox(height: 18),
                ...children.map(
                  (child) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnalysisBar extends StatelessWidget {
  const _AnalysisBar({required this.game});

  final GoGame game;

  @override
  Widget build(BuildContext context) {
    final black = game.blackStones + game.blackCaptures;
    final white = game.whiteStones + game.whiteCaptures + 6.5;
    final total = math.max(1.0, black + white);
    final blackRatio = black / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            minHeight: 28,
            value: blackRatio,
            backgroundColor: const Color(0xfff2eee7),
            color: const Color(0xff111111),
          ),
        ),
        const SizedBox(height: 8),
        Text('흑 ${black.toStringAsFixed(1)} : 백 ${white.toStringAsFixed(1)}'),
      ],
    );
  }
}

class SignupVerificationPanel extends StatefulWidget {
  const SignupVerificationPanel({super.key});

  @override
  State<SignupVerificationPanel> createState() =>
      _SignupVerificationPanelState();
}

class _SignupVerificationPanelState extends State<SignupVerificationPanel> {
  final apiBaseUrlController = TextEditingController(
    text: 'http://localhost:8000',
  );
  final emailController = TextEditingController();
  final displayNameController = TextEditingController();
  final passwordController = TextEditingController();
  bool termsAccepted = false;
  bool loading = false;
  String message = '메일 아이디로 가입하면 인증 메일이 발송됩니다.';

  @override
  void dispose() {
    apiBaseUrlController.dispose();
    emailController.dispose();
    displayNameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.mark_email_read),
                    const SizedBox(width: 12),
                    Text(
                      '회원가입/이메일 인증',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: apiBaseUrlController,
                  decoration: const InputDecoration(
                    labelText: 'API 서버 주소',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: '메일 아이디',
                    hintText: 'user@example.com',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: displayNameController,
                  decoration: const InputDecoration(
                    labelText: '표시 이름',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '비밀번호',
                    helperText: '8자 이상',
                    border: OutlineInputBorder(),
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: termsAccepted,
                  onChanged: loading
                      ? null
                      : (value) {
                          setState(() {
                            termsAccepted = value ?? false;
                          });
                        },
                  title: const Text('서비스 이용 약관에 동의합니다.'),
                ),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: loading ? null : _register,
                      icon: loading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.person_add),
                      label: const Text('회원가입'),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: loading ? null : _resendVerification,
                      icon: const Icon(Icons.refresh),
                      label: const Text('인증메일 재발송'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SelectableText(message),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _register() async {
    if (!termsAccepted) {
      setState(() {
        message = '약관 동의가 필요합니다.';
      });
      return;
    }
    await _post(
      '/auth/register',
      {
        'email': emailController.text.trim(),
        'password': passwordController.text,
        'display_name': displayNameController.text.trim(),
        'terms_accepted': termsAccepted,
      },
    );
  }

  Future<void> _resendVerification() async {
    await _post(
      '/auth/resend-verification',
      {'email': emailController.text.trim()},
    );
  }

  Future<void> _post(String path, Map<String, Object?> body) async {
    setState(() {
      loading = true;
      message = '요청을 처리하는 중입니다.';
    });

    try {
      final baseUrl = apiBaseUrlController.text.trim().replaceAll(
            RegExp(r'/$'),
            '',
          );
      final response = await http.post(
        Uri.parse('$baseUrl$path'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      setState(() {
        if (response.statusCode >= 200 && response.statusCode < 300) {
          final verifyUrl = data['development_verify_url'];
          message = [
            data['message'] ?? '요청이 완료되었습니다.',
            if (verifyUrl != null) '개발용 인증 링크: $verifyUrl',
          ].join('\n');
        } else {
          message = data['detail']?.toString() ?? '요청에 실패했습니다.';
        }
      });
    } catch (error) {
      setState(() {
        message = 'API 서버에 연결할 수 없습니다. 서버 주소와 실행 상태를 확인해 주세요.\n$error';
      });
    } finally {
      setState(() {
        loading = false;
      });
    }
  }
}

class UserManagementPanel extends StatelessWidget {
  const UserManagementPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return InfoPanel(
      title: '사용자 관리',
      icon: Icons.manage_accounts,
      children: [
        DataTable(
          columns: const [
            DataColumn(label: Text('사용자')),
            DataColumn(label: Text('역할')),
            DataColumn(label: Text('상태')),
          ],
          rows: const [
            DataRow(
              cells: [
                DataCell(Text('admin')),
                DataCell(Text('관리자')),
                DataCell(Text('활성')),
              ],
            ),
            DataRow(
              cells: [
                DataCell(Text('guest')),
                DataCell(Text('일반사용자')),
                DataCell(Text('활성')),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class RecordManagementPanel extends StatelessWidget {
  const RecordManagementPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return const InfoPanel(
      title: '기보관리',
      icon: Icons.folder_copy,
      children: [
        Text('저장된 SGF 기보 목록, 검색, 삭제, 내보내기 기능이 들어갈 관리자 화면입니다.'),
        Text('일반 사용자 기보 메뉴보다 시스템 전체 기보를 대상으로 관리합니다.'),
      ],
    );
  }
}

class MenuSection {
  MenuSection({required this.title, required this.items});

  final String title;
  final List<MenuItem> items;
}

class MenuItem {
  MenuItem(this.label, this.icon, this.onTap);

  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

enum Stone { empty, black, white }

class BoardPoint {
  const BoardPoint(this.row, this.col);

  final int row;
  final int col;
}

class GoAiPlayer {
  GoAiPlayer({math.Random? random}) : _random = random ?? math.Random();

  final math.Random _random;

  bool play(GoGame game, AiDifficulty difficulty) {
    final move = chooseMove(game, difficulty);
    if (move == null) {
      game.passTurn();
      game.message = '${game.turn.opponent.label} AI가 패스했습니다.';
      return false;
    }
    final color = game.turn;
    final played = game.play(move.row, move.col, actor: '${color.label} AI');
    if (played) {
      game.message =
          '${color.label} AI 착수: ${game.formatCoord(move.row, move.col)}';
    }
    return played;
  }

  BoardPoint? chooseMove(GoGame game, AiDifficulty difficulty) {
    final moves = game.legalMoves();
    if (moves.isEmpty) {
      return null;
    }
    if (difficulty == AiDifficulty.beginner) {
      return moves[_random.nextInt(moves.length)];
    }

    final scored = [
      for (final move in moves)
        (
          move: move,
          score:
              _scoreMove(game, move, difficulty) + _random.nextDouble() * 0.1,
        ),
    ]..sort((a, b) => b.score.compareTo(a.score));

    if (difficulty == AiDifficulty.intermediate && scored.length > 4) {
      return scored[_random.nextInt(4)].move;
    }
    return scored.first.move;
  }

  double _scoreMove(GoGame game, BoardPoint move, AiDifficulty difficulty) {
    final color = game.turn;
    final beforeCaptures =
        color == Stone.black ? game.blackCaptures : game.whiteCaptures;
    final trial = game.copy();
    trial.play(move.row, move.col);
    final afterCaptures =
        color == Stone.black ? trial.blackCaptures : trial.whiteCaptures;
    final captured = afterCaptures - beforeCaptures;
    final ownGroup = trial._group(move.row, move.col);
    final liberties = trial._liberties(ownGroup).length;
    final center = (game.size - 1) / 2;
    final centerBias =
        game.size - (move.row - center).abs() - (move.col - center).abs();
    final adjacentFriendlies = game
        ._neighbors(move.row, move.col)
        .where((p) => game.board[p.$1][p.$2] == color)
        .length;
    final adjacentEnemies = game
        ._neighbors(move.row, move.col)
        .where((p) => game.board[p.$1][p.$2] == color.opponent)
        .length;

    var score = captured * 120.0 +
        liberties * 4.0 +
        centerBias * 0.4 +
        adjacentFriendlies * 3.0 +
        adjacentEnemies * 1.5;

    if (difficulty == AiDifficulty.advanced) {
      score += _atariPressure(trial, color) * 18.0;
      score += (color == Stone.black
              ? trial.blackStones - trial.whiteStones
              : trial.whiteStones - trial.blackStones)
          .toDouble();
    }
    return score;
  }

  int _atariPressure(GoGame game, Stone color) {
    final seen = <(int, int)>{};
    var pressure = 0;
    for (var row = 0; row < game.size; row++) {
      for (var col = 0; col < game.size; col++) {
        if (game.board[row][col] != color.opponent ||
            seen.contains((row, col))) {
          continue;
        }
        final group = game._group(row, col);
        seen.addAll(group);
        if (game._liberties(group).length == 1) {
          pressure += group.length;
        }
      }
    }
    return pressure;
  }
}

class GoGame {
  GoGame({required this.size}) {
    reset(size);
  }

  GoGame._copy({
    required this.size,
    required this.board,
    required this.turn,
    required this.blackCaptures,
    required this.whiteCaptures,
    required this.message,
  });

  int size;
  late List<List<Stone>> board;
  Stone turn = Stone.black;
  int blackCaptures = 0;
  int whiteCaptures = 0;
  String message = '흑 차례입니다.';
  final List<GameSnapshot> undoStack = [];
  final List<GameSnapshot> redoStack = [];

  int get blackStones =>
      board.expand((row) => row).where((stone) => stone == Stone.black).length;

  int get whiteStones =>
      board.expand((row) => row).where((stone) => stone == Stone.white).length;

  void reset(int newSize) {
    size = newSize;
    board = List.generate(size, (_) => List.generate(size, (_) => Stone.empty));
    turn = Stone.black;
    blackCaptures = 0;
    whiteCaptures = 0;
    message = '흑 차례입니다.';
    undoStack.clear();
    redoStack.clear();
  }

  GoGame copy() {
    return GoGame._copy(
      size: size,
      board: board.map((row) => List<Stone>.from(row)).toList(),
      turn: turn,
      blackCaptures: blackCaptures,
      whiteCaptures: whiteCaptures,
      message: message,
    );
  }

  bool play(int row, int col, {String? actor}) {
    if (!isLegalMove(row, col)) {
      message = board[row][col] == Stone.empty ? '자살수입니다.' : '이미 돌이 있습니다.';
      return false;
    }
    undoStack.add(_snapshot());
    redoStack.clear();
    final playedColor = turn;
    board[row][col] = turn;
    final captured = _captureAround(row, col);
    if (turn == Stone.black) {
      blackCaptures += captured;
      turn = Stone.white;
    } else {
      whiteCaptures += captured;
      turn = Stone.black;
    }
    final who = actor ?? playedColor.label;
    message = '$who 착수: ${formatCoord(row, col)}, ${turn.label} 차례입니다.';
    return true;
  }

  void passTurn() {
    undoStack.add(_snapshot());
    redoStack.clear();
    turn = turn == Stone.black ? Stone.white : Stone.black;
    message = turn == Stone.black ? '백 패스, 흑 차례입니다.' : '흑 패스, 백 차례입니다.';
  }

  void undo() {
    if (undoStack.isEmpty) {
      message = '되돌릴 수가 없습니다.';
      return;
    }
    redoStack.add(_snapshot());
    _restore(undoStack.removeLast());
    message = '이전 수로 돌아갔습니다.';
  }

  void redo() {
    if (redoStack.isEmpty) {
      message = '다시 둘 수가 없습니다.';
      return;
    }
    undoStack.add(_snapshot());
    _restore(redoStack.removeLast());
    message = '다음 수로 이동했습니다.';
  }

  List<BoardPoint> legalMoves() {
    return [
      for (var row = 0; row < size; row++)
        for (var col = 0; col < size; col++)
          if (isLegalMove(row, col)) BoardPoint(row, col),
    ];
  }

  bool isLegalMove(int row, int col) {
    if (row < 0 || row >= size || col < 0 || col >= size) {
      return false;
    }
    if (board[row][col] != Stone.empty) {
      return false;
    }

    final trial = copy();
    trial.board[row][col] = turn;
    trial._captureAround(row, col);
    return trial._liberties(trial._group(row, col)).isNotEmpty;
  }

  String formatCoord(int row, int col) {
    const letters = 'ABCDEFGHJKLMNOPQRST';
    return '${letters[col]}${size - row}';
  }

  int _captureAround(int row, int col) {
    var captured = 0;
    final opponent = turn == Stone.black ? Stone.white : Stone.black;
    for (final point in _neighbors(row, col)) {
      if (board[point.$1][point.$2] != opponent) {
        continue;
      }
      final group = _group(point.$1, point.$2);
      if (_liberties(group).isEmpty) {
        captured += group.length;
        for (final stone in group) {
          board[stone.$1][stone.$2] = Stone.empty;
        }
      }
    }
    return captured;
  }

  List<(int, int)> _group(int row, int col) {
    final color = board[row][col];
    final visited = <(int, int)>{};
    final queue = <(int, int)>[(row, col)];
    visited.add((row, col));
    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      for (final next in _neighbors(current.$1, current.$2)) {
        if (board[next.$1][next.$2] == color && !visited.contains(next)) {
          visited.add(next);
          queue.add(next);
        }
      }
    }
    return visited.toList();
  }

  Set<(int, int)> _liberties(List<(int, int)> group) {
    final liberties = <(int, int)>{};
    for (final stone in group) {
      for (final next in _neighbors(stone.$1, stone.$2)) {
        if (board[next.$1][next.$2] == Stone.empty) {
          liberties.add(next);
        }
      }
    }
    return liberties;
  }

  List<(int, int)> _neighbors(int row, int col) {
    return [(row - 1, col), (row + 1, col), (row, col - 1), (row, col + 1)]
        .where(
          (point) =>
              point.$1 >= 0 &&
              point.$1 < size &&
              point.$2 >= 0 &&
              point.$2 < size,
        )
        .toList();
  }

  GameSnapshot _snapshot() {
    return GameSnapshot(
      board.map((row) => List<Stone>.from(row)).toList(),
      turn,
      blackCaptures,
      whiteCaptures,
    );
  }

  void _restore(GameSnapshot snapshot) {
    board = snapshot.board.map((row) => List<Stone>.from(row)).toList();
    turn = snapshot.turn;
    blackCaptures = snapshot.blackCaptures;
    whiteCaptures = snapshot.whiteCaptures;
  }
}

class GameSnapshot {
  GameSnapshot(this.board, this.turn, this.blackCaptures, this.whiteCaptures);

  final List<List<Stone>> board;
  final Stone turn;
  final int blackCaptures;
  final int whiteCaptures;
}

extension on UserRole {
  String get label => switch (this) {
        UserRole.user => '일반사용자',
        UserRole.admin => '관리자',
      };
}

extension on GameMode {
  String get label => switch (this) {
        GameMode.humanVsHuman => '사람 vs 사람',
        GameMode.humanVsAi => '사람 vs AI',
        GameMode.aiVsAi => 'AI vs AI',
      };
}

extension on AiDifficulty {
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

extension on Stone {
  String get label => switch (this) {
        Stone.black => '흑',
        Stone.white => '백',
        Stone.empty => '빈칸',
      };

  Stone get opponent => switch (this) {
        Stone.black => Stone.white,
        Stone.white => Stone.black,
        Stone.empty => Stone.empty,
      };
}
