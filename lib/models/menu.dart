import 'package:flutter/material.dart';

/// A titled group of [MenuItem]s shown in [AppMenu] (see
/// lib/widgets/app_menu.dart).
class MenuSection {
  MenuSection({required this.title, required this.items});

  final String title;
  final List<MenuItem> items;
}

/// A single tappable menu entry.
class MenuItem {
  MenuItem(this.label, this.icon, this.onTap);

  final String label;
  final IconData icon;
  final VoidCallback onTap;
}
