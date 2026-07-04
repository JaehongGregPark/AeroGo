import 'package:flutter/material.dart';

/// Generic card used for the many "placeholder" screens (analysis, SGF
/// import, admin settings, etc.) that just show a title/icon and a list of
/// explanatory widgets.
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
