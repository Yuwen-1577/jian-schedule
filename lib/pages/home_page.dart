import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'day_view_page.dart';
import 'schedule_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: const [SchedulePage(), DayViewPage()],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: Gap.xl,
            child: Center(
              child: _ExpandablePillNavigation(
                currentIndex: _currentIndex,
                onChanged: (index) {
                  if (index == _currentIndex) return;
                  setState(() => _currentIndex = index);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpandablePillNavigation extends StatefulWidget {
  const _ExpandablePillNavigation({
    required this.currentIndex,
    required this.onChanged,
  });

  final int currentIndex;
  final ValueChanged<int> onChanged;

  @override
  State<_ExpandablePillNavigation> createState() =>
      _ExpandablePillNavigationState();
}

class _ExpandablePillNavigationState extends State<_ExpandablePillNavigation> {
  bool _isExpanded = false;

  void _select(int index) {
    widget.onChanged(index);
    setState(() => _isExpanded = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final currentLabel = widget.currentIndex == 0 ? '周课表' : '日视图';

    return Semantics(
      container: true,
      child: Material(
        color: cs.primaryContainer,
        elevation: 6,
        shadowColor: cs.shadow.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(AppRadius.full),
        clipBehavior: Clip.antiAlias,
        child: AnimatedContainer(
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 240),
          curve: Curves.easeInOutCubic,
          width: _isExpanded ? 272 : 56,
          height: 56,
          child: _isExpanded
              ? Row(
                  children: [
                    _PillDestination(
                      selected: widget.currentIndex == 0,
                      icon: Icons.calendar_view_week_outlined,
                      selectedIcon: Icons.calendar_view_week,
                      label: '周课表',
                      onTap: () => _select(0),
                    ),
                    _PillDestination(
                      selected: widget.currentIndex == 1,
                      icon: Icons.view_day_outlined,
                      selectedIcon: Icons.view_day,
                      label: '日视图',
                      onTap: () => _select(1),
                    ),
                  ],
                )
              : Semantics(
                  button: true,
                  label: '打开视图切换，当前$currentLabel',
                  child: InkWell(
                    onTap: () => setState(() => _isExpanded = true),
                    customBorder: const CircleBorder(),
                    child: Center(
                      child: Icon(
                        widget.currentIndex == 0
                            ? Icons.calendar_view_week
                            : Icons.view_day,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _PillDestination extends StatelessWidget {
  const _PillDestination({
    required this.selected,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final foreground = selected ? cs.onPrimary : cs.onPrimaryContainer;

    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.full),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: selected ? cs.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    selected ? selectedIcon : icon,
                    size: 21,
                    color: foreground,
                  ),
                  const SizedBox(width: Gap.sm),
                  Text(
                    label,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
