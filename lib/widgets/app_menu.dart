import 'package:flutter/material.dart';

import '../models/enums.dart';
import '../models/menu.dart';

/// Left-hand navigation menu, grouped into collapsible [MenuSection]s.
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
