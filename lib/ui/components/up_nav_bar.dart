import 'package:flutter/material.dart';

import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';

enum UpTab { home, nearby, chats, me }

class UpNavBar extends StatelessWidget {
  const UpNavBar({
    required this.current,
    required this.onSelect,
    required this.labels,
    this.unreadCount = 0,
    super.key,
  });

  final UpTab current;
  final ValueChanged<UpTab> onSelect;
  final Map<UpTab, String> labels;
  final int unreadCount;

  static const Map<UpTab, IconData> _icons = <UpTab, IconData>{
    UpTab.home: Icons.bolt_rounded,
    UpTab.nearby: Icons.people_alt_rounded,
    UpTab.chats: Icons.chat_bubble_rounded,
    UpTab.me: Icons.person_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final UpPalette p = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.md,
            vertical: Insets.sm,
          ),
          child: Row(
            children: UpTab.values.map((UpTab tab) {
              final bool selected = tab == current;
              return Expanded(
                child: Semantics(
                  selected: selected,
                  button: true,
                  child: InkWell(
                    onTap: () => onSelect(tab),
                    borderRadius: BorderRadius.circular(Radii.md),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: Insets.sm,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Stack(
                            clipBehavior: Clip.none,
                            children: <Widget>[
                              Icon(
                                _icons[tab],
                                size: 21,
                                color: selected ? p.amber : p.dim,
                              ),
                              if (tab == UpTab.chats && unreadCount > 0)
                                PositionedDirectional(
                                  top: -4,
                                  end: -6,
                                  child: Container(
                                    constraints: const BoxConstraints(
                                      minWidth: 15,
                                      minHeight: 15,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: p.amber,
                                      borderRadius:
                                          BorderRadius.circular(Radii.pill),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '$unreadCount',
                                        style: TextStyle(
                                          color: p.onAmber,
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: Insets.xs),
                          Text(
                            labels[tab] ?? '',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: selected ? p.amber : p.dim,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(growable: false),
          ),
        ),
      ),
    );
  }
}
