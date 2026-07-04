import 'package:flutter/material.dart';

import 'info_panel.dart';

/// "무료 중계 서비스" (free broadcast services) menu screen: a static list
/// of external Go servers/broadcasters, shown as informational reference
/// links (AeroGo does not integrate with any of them yet).
class BroadcastServicePanel extends StatelessWidget {
  const BroadcastServicePanel({super.key});

  @override
  Widget build(BuildContext context) {
    return InfoPanel(
      title: '무료 중계 서비스',
      icon: Icons.live_tv,
      children: const [
        Text('AeroGo와 함께 사용할 수 있는 무료 또는 공개 관전 후보입니다.'),
        _BroadcastServiceRow(
          name: '타이젬',
          url: 'https://www.tygem.com/',
          note: '한국 프로대국 생중계 일정과 웹대국실 관전에 적합합니다.',
        ),
        _BroadcastServiceRow(
          name: 'KGS Go Server',
          url: 'https://www.gokgs.com/',
          note: '해외 공개 서버 관전과 대국 릴레이 문화가 강합니다.',
        ),
        _BroadcastServiceRow(
          name: 'Pandanet / IGS',
          url: 'https://pandanet-igs.com/',
          note: '일본 기전과 인터넷 바둑 서버 관전에 활용할 수 있습니다.',
        ),
        _BroadcastServiceRow(
          name: 'OGS',
          url: 'https://online-go.com/',
          note: '웹브라우저 기반 공개 바둑 서버입니다.',
        ),
        _BroadcastServiceRow(
          name: '바둑TV',
          url: 'https://www.tvbaduk.com/',
          note: '공식 방송 편성표와 공개 영상 확인용으로 적합합니다.',
        ),
        Text('AeroGo 자동 연동은 공개 API, 제휴, 또는 허가받은 SGF 데이터부터 연결하는 방식이 안전합니다.'),
      ],
    );
  }
}

class _BroadcastServiceRow extends StatelessWidget {
  const _BroadcastServiceRow({
    required this.name,
    required this.url,
    required this.note,
  });

  final String name;
  final String url;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: Theme.of(context).textTheme.titleSmall),
          SelectableText(url),
          Text(note),
        ],
      ),
    );
  }
}
