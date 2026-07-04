import 'package:flutter/material.dart';

import 'info_panel.dart';

/// Admin-only "사용자 관리" screen. Currently a static mock table -- it is
/// not wired up to the backend's `users` table or any API endpoint yet.
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

/// Admin-only "기보관리" screen. Placeholder text only -- no SGF listing,
/// search, or export functionality is implemented yet.
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
