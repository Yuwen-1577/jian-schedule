import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/course.dart';
import '../providers/schedule_provider.dart';
import '../theme/app_theme.dart';
import '../utils/constants.dart';
import '../widgets/color_picker.dart';

class CourseEditBottomSheet extends StatefulWidget {
  final Course? initialCourse;
  final int? initialDay;
  final int? initialStartPeriod;
  final int? initialDuration;

  const CourseEditBottomSheet({
    super.key,
    this.initialCourse,
    this.initialDay,
    this.initialStartPeriod,
    this.initialDuration,
  });

  static Future<void> show(
    BuildContext context, {
    Course? course,
    int? day,
    int? startPeriod,
    int? duration,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: CourseEditBottomSheet(
          initialCourse: course,
          initialDay: day,
          initialStartPeriod: startPeriod,
          initialDuration: duration,
        ),
      ),
    );
  }

  @override
  State<CourseEditBottomSheet> createState() => _CourseEditBottomSheetState();
}

class _CourseEditBottomSheetState extends State<CourseEditBottomSheet> {
  static const List<int> _reminderOptions = [0, 5, 10, 15, 30, 60];

  final _formKey = GlobalKey<FormState>();
  bool _showAdvanced = false;

  late TextEditingController _nameCtrl;
  late TextEditingController _roomCtrl;
  late TextEditingController _teacherCtrl;
  late int _day;
  late int _startPeriod;
  late int _duration;
  late List<int> _activeWeeks;
  late int _colorValue;
  late int _reminderMinutesBefore;
  int? _reminderDropdownValue;

  @override
  void initState() {
    super.initState();
    final course = widget.initialCourse;
    _nameCtrl = TextEditingController(text: course?.name ?? '');
    _roomCtrl = TextEditingController(text: course?.room ?? '');
    _teacherCtrl = TextEditingController(text: course?.teacher ?? '');

    _day = course?.day ?? widget.initialDay ?? 1;
    _startPeriod = course?.startPeriod ?? widget.initialStartPeriod ?? 1;
    _duration = course?.duration ?? widget.initialDuration ?? 2;
    _activeWeeks = List.from(course?.activeWeeks ?? []);
    if (_activeWeeks.isEmpty && course == null) {
      _activeWeeks = List.generate(maxWeekCount, (i) => i + 1);
    }
    _colorValue = course?.colorValue ?? presetColors[0];
    final reminder = course?.reminderMinutesBefore ?? 15;
    _reminderMinutesBefore = reminder;
    _reminderDropdownValue = _reminderOptions.contains(reminder)
        ? reminder
        : null;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _roomCtrl.dispose();
    _teacherCtrl.dispose();
    super.dispose();
  }

  Future<void> _editTime() async {
    final provider = context.read<ScheduleProvider>();
    final maxPeriods = provider.timeSlots.length;
    if (maxPeriods == 0) return;

    int tempDay = _day;
    int tempStart = _startPeriod.clamp(1, maxPeriods);
    int tempDuration = _duration;
    if (tempStart + tempDuration - 1 > maxPeriods) {
      tempDuration = maxPeriods - tempStart + 1;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final cs = Theme.of(ctx).colorScheme;
            return AlertDialog(
              title: const Text('修改上课时间', style: TextStyle(fontSize: 18)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('星期'),
                      DropdownButton<int>(
                        value: tempDay,
                        underline: const SizedBox(),
                        items: List.generate(
                          7,
                          (i) => DropdownMenuItem(
                            value: i + 1,
                            child: Text(weekdayNames[i]),
                          ),
                        ),
                        onChanged: (v) => setDialogState(() => tempDay = v!),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('开始节次'),
                      DropdownButton<int>(
                        value: tempStart,
                        underline: const SizedBox(),
                        items: List.generate(
                          maxPeriods,
                          (i) => DropdownMenuItem(
                            value: i + 1,
                            child: Text('第 ${i + 1} 节'),
                          ),
                        ),
                        onChanged: (v) {
                          setDialogState(() {
                            tempStart = v!;
                            if (tempStart + tempDuration - 1 > maxPeriods) {
                              tempDuration = maxPeriods - tempStart + 1;
                            }
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('持续节次'),
                      DropdownButton<int>(
                        value: tempDuration,
                        underline: const SizedBox(),
                        items: List.generate(
                          maxPeriods - tempStart + 1,
                          (i) => DropdownMenuItem(
                            value: i + 1,
                            child: Text('${i + 1} 节'),
                          ),
                        ),
                        onChanged: (v) =>
                            setDialogState(() => tempDuration = v!),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: TextButton.styleFrom(foregroundColor: cs.primary),
                  child: const Text('确定'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      setState(() {
        _day = tempDay;
        _startPeriod = tempStart;
        _duration = tempDuration;
      });
    }
  }

  String _formatActiveWeeks() {
    if (_activeWeeks.isEmpty) return '未设置';
    final tempCourse = Course(
      id: '',
      name: '',
      day: 1,
      startPeriod: 1,
      activeWeeks: _activeWeeks,
    );
    return tempCourse.formattedWeeks;
  }

  String _formatReminder(int minutes) {
    if (minutes <= 0) return '不提醒';
    if (minutes >= 60) return '1小时前';
    return '$minutes分钟前';
  }

  Future<void> _editWeeks() async {
    final tempWeeks = List<int>.from(_activeWeeks);
    final cs = Theme.of(context).colorScheme;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              contentPadding: const EdgeInsets.all(16),
              title: const Text(
                '选择上课周数',
                style: TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: GridView.builder(
                        shrinkWrap: true,
                        itemCount: maxWeekCount,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 5,
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                            ),
                        itemBuilder: (context, index) {
                          final week = index + 1;
                          final isSelected = tempWeeks.contains(week);
                          return InkWell(
                            onTap: () {
                              setDialogState(() {
                                if (isSelected) {
                                  tempWeeks.remove(week);
                                } else {
                                  tempWeeks.add(week);
                                }
                              });
                            },
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected
                                    ? cs.primary
                                    : cs.surfaceContainerHigh,
                              ),
                              child: Text(
                                '$week',
                                style: TextStyle(
                                  color: isSelected
                                      ? cs.onPrimary
                                      : cs.onSurface,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton(
                          onPressed: () {
                            setDialogState(() {
                              tempWeeks.clear();
                              tempWeeks.addAll(
                                List.generate(maxWeekCount, (i) => i + 1),
                              );
                            });
                          },
                          child: const Text('全周'),
                        ),
                        TextButton(
                          onPressed: () {
                            setDialogState(() {
                              tempWeeks.clear();
                              tempWeeks.addAll(
                                List.generate(
                                  maxWeekCount,
                                  (i) => i + 1,
                                ).where((w) => w % 2 == 1),
                              );
                            });
                          },
                          child: const Text('单周'),
                        ),
                        TextButton(
                          onPressed: () {
                            setDialogState(() {
                              tempWeeks.clear();
                              tempWeeks.addAll(
                                List.generate(
                                  maxWeekCount,
                                  (i) => i + 1,
                                ).where((w) => w % 2 == 0),
                              );
                            });
                          },
                          child: const Text('双周'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: TextButton.styleFrom(foregroundColor: cs.primary),
                  child: const Text('确定'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      setState(() {
        _activeWeeks = tempWeeks;
      });
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<ScheduleProvider>();
    final course = Course(
      id: widget.initialCourse?.id ?? const Uuid().v4(),
      name: _nameCtrl.text.trim(),
      room: _roomCtrl.text.trim(),
      teacher: _teacherCtrl.text.trim(),
      day: _day,
      startPeriod: _startPeriod,
      duration: _duration,
      activeWeeks: _activeWeeks,
      colorValue: _colorValue,
      note: widget.initialCourse?.note ?? '',
      scheduleSetId:
          widget.initialCourse?.scheduleSetId ?? provider.activeSetId,
      reminderMinutesBefore: _reminderMinutesBefore,
    );

    if (widget.initialCourse != null) {
      provider.updateCourse(course);
    } else {
      provider.addCourse(course);
    }
    Navigator.pop(context);
  }

  void _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除课程'),
        content: const Text('确定要删除这门课程吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      context.read<ScheduleProvider>().deleteCourse(widget.initialCourse!.id);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isEditing = widget.initialCourse != null;

    return Container(
      padding: const EdgeInsets.all(Gap.xl),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.lg),
        ),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 48),
                  Expanded(
                    child: Text(
                      isEditing ? '编辑课程' : '添加课程',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  if (isEditing)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: _delete,
                    )
                  else
                    const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: Gap.xl),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: '课程名称'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '请输入名称' : null,
              ),
              const SizedBox(height: Gap.md),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _roomCtrl,
                      decoration: const InputDecoration(labelText: '教室'),
                    ),
                  ),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: TextFormField(
                      controller: _teacherCtrl,
                      decoration: const InputDecoration(labelText: '教师'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Gap.lg),

              Material(
                color: cs.surfaceContainer,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: InkWell(
                  onTap: _editTime,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Padding(
                    padding: const EdgeInsets.all(Gap.md),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '上课时间',
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                        Row(
                          children: [
                            Text(
                              '${weekdayNames[_day - 1]} 第$_startPeriod-${_startPeriod + _duration - 1}节',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface,
                              ),
                            ),
                            const SizedBox(width: Gap.sm),
                            Icon(
                              Icons.edit_outlined,
                              size: 16,
                              color: cs.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: Gap.md),
              Material(
                color: cs.surfaceContainer,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: InkWell(
                  onTap: _editWeeks,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Padding(
                    padding: const EdgeInsets.all(Gap.md),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '上课周数',
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Flexible(
                                child: Text(
                                  _formatActiveWeeks(),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: cs.onSurface,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.right,
                                ),
                              ),
                              const SizedBox(width: Gap.sm),
                              Icon(
                                Icons.edit_outlined,
                                size: 16,
                                color: cs.onSurfaceVariant,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: Gap.md),
              Material(
                color: cs.surfaceContainer,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Gap.md,
                    vertical: Gap.sm,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '上课提醒',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                      DropdownButton<int>(
                        value: _reminderDropdownValue,
                        hint: Text(
                          '保留 ${_formatReminder(_reminderMinutesBefore)}',
                        ),
                        underline: const SizedBox(),
                        items: _reminderOptions
                            .map(
                              (minutes) => DropdownMenuItem<int>(
                                value: minutes,
                                child: Text(_formatReminder(minutes)),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _reminderDropdownValue = value;
                            _reminderMinutesBefore = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: Gap.lg),
              GestureDetector(
                onTap: () => setState(() => _showAdvanced = !_showAdvanced),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '高级选项 (颜色)',
                      style: TextStyle(color: cs.primary, fontSize: 13),
                    ),
                    Icon(
                      _showAdvanced
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: cs.primary,
                      size: 16,
                    ),
                  ],
                ),
              ),

              if (_showAdvanced) ...[
                const SizedBox(height: Gap.lg),
                CourseColorPicker(
                  selectedColor: _colorValue,
                  onColorSelected: (c) => setState(() => _colorValue = c),
                ),
              ],

              const SizedBox(height: Gap.xl),
              ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                child: const Text(
                  '保存',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
