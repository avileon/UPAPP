import 'package:flutter/material.dart';

import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';

enum UpTab { home, nearby, chats, me }

/// The count on the chats icon.
///
/// It grew a ring, a shadow and a beat because the previous one — 9.5pt type
/// in a 15px pill, flat against a dark bar — was invisible in exactly the
/// situation it exists for: a phone at arm's length in a room with the lights
/// down. The ring separates it from whatever is behind it, and the single
/// slow pulse is what makes peripheral vision notice a thing that was not
/// there a second ago. One pulse per new arrival, not forever: a badge that
/// never stops moving is one you learn to ignore.
class _UnreadBadge extends StatefulWidget {
  const _UnreadBadge({
    required this.count,
    required this.fill,
    required this.text,
    required this.ring,
  });

  final int count;
  final Color fill;
  final Color text;
  final Color ring;

  @override
  State<_UnreadBadge> createState() => _UnreadBadgeState();
}

class _UnreadBadgeState extends State<_UnreadBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: Motion.slow,
  );

  @override
  void initState() {
    super.initState();
    _pulse.forward();
  }

  @override
  void didUpdateWidget(_UnreadBadge old) {
    super.didUpdateWidget(old);
    // Only when the number goes up. Reading a thread lowers it, and that is
    // not an event worth a flash.
    if (widget.count > old.count) {
      _pulse.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String label = widget.count > 9 ? '9+' : '${widget.count}';
    return ScaleTransition(
      scale: Tween<double>(begin: 1.55, end: 1).animate(
        CurvedAnimation(parent: _pulse, curve: Curves.elasticOut),
      ),
      child: Container(
        constraints: const BoxConstraints(minWidth: 19, minHeight: 19),
        padding: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          color: widget.fill,
          borderRadius: BorderRadius.circular(Radii.pill),
          border: Border.all(color: widget.ring, width: 2),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: widget.fill.withValues(alpha: 0.5),
              blurRadius: 8,
            ),
          ],
        ),
        child: Center(
          widthFactor: 1,
          child: Text(
            label,
            style: TextStyle(
              color: widget.text,
              fontSize: 11,
              height: 1.1,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

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
                    // A tinted pill behind the current tab. Colour alone was
                    // carrying the whole job of saying where you are, and
                    // amber-on-dark at 21px is a weak signal on a phone held
                    // at arm's length — and no signal at all to anyone who
                    // does not separate those two hues.
                    child: AnimatedContainer(
                      duration: Motion.fast,
                      curve: Curves.easeOut,
                      margin: const EdgeInsets.symmetric(horizontal: Insets.xs),
                      padding: const EdgeInsets.symmetric(
                        vertical: Insets.sm,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? p.amber.withValues(alpha: 0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(Radii.md),
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
                                  top: -6,
                                  end: -9,
                                  child: _UnreadBadge(
                                    count: unreadCount,
                                    fill: p.amber,
                                    text: p.onAmber,
                                    ring: p.surface,
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
