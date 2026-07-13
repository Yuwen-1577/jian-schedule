import 'package:flutter/material.dart';
import 'schedule_page.dart';
import 'day_view_page.dart';
import '../theme/app_theme.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 1;

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
            bottom: Gap.xl,
            left: 0,
            right: 0,
            child: Center(
              child: _AnimatedFloatingToggle(
                currentIndex: _currentIndex,
                onChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedFloatingToggle extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onChanged;

  const _AnimatedFloatingToggle({
    required this.currentIndex,
    required this.onChanged,
  });

  @override
  State<_AnimatedFloatingToggle> createState() =>
      _AnimatedFloatingToggleState();
}

class _AnimatedFloatingToggleState extends State<_AnimatedFloatingToggle> {
  bool _isExpanded = false;

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  void _select(int index) {
    widget.onChanged(index);
    setState(() {
      _isExpanded = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    final width = _isExpanded ? 240.0 : 56.0;
    const height = 56.0;

    return GestureDetector(
      // 点击外部区域不会收起，因为它是局部的 Widget。
      // 可以通过外部 Scaffold 给一个全屏 GestureDetector 来实现，但更简单的是用户点击任意选项就收起
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: cs.primaryContainer,
          borderRadius: BorderRadius.circular(28.0),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black45 : Colors.black26,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28.0),
          child: Material(
            color: Colors.transparent,
            child: _isExpanded
                ? Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _select(0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: widget.currentIndex == 0
                                  ? cs.primary
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(28.0),
                            ),
                            alignment: Alignment.center,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const NeverScrollableScrollPhysics(),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.calendar_view_week,
                                    size: 20,
                                    color: widget.currentIndex == 0
                                        ? cs.onPrimary
                                        : cs.onPrimaryContainer,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '周视图',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: widget.currentIndex == 0
                                          ? cs.onPrimary
                                          : cs.onPrimaryContainer,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () => _select(1),
                          child: Container(
                            decoration: BoxDecoration(
                              color: widget.currentIndex == 1
                                  ? cs.primary
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(28.0),
                            ),
                            alignment: Alignment.center,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const NeverScrollableScrollPhysics(),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.view_day,
                                    size: 20,
                                    color: widget.currentIndex == 1
                                        ? cs.onPrimary
                                        : cs.onPrimaryContainer,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '日视图',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: widget.currentIndex == 1
                                          ? cs.onPrimary
                                          : cs.onPrimaryContainer,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : InkWell(
                    onTap: _toggleExpand,
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
