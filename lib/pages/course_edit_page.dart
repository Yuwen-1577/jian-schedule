import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/course.dart';
import '../providers/schedule_provider.dart';
import '../theme/app_theme.dart';
import '../utils/constants.dart';
import '../widgets/color_picker.dart';

class CourseEditPage extends StatefulWidget {
  const CourseEditPage({super.key});

  @override
  State<CourseEditPage> createState() => _CourseEditPageState();
}

class _CourseEditPageState extends State<CourseEditPage> {
  final _formKey = GlobalKey<FormState>();
  Course? _editingCourse;
  bool get _isEditing => _editingCourse != null;

  static const List<int> _reminderOptions = [0, 5, 10, 15, 30, 60];
  static const List<String> _reminderLabels = [
    '不提醒', '5 分钟前', '10 分钟前', '15 分钟前', '30 分钟前', '1 小时前',
  ];

  late TextEditingController _nameCtrl;
  late TextEditingController _roomCtrl;
  late TextEditingController _teacherCtrl;
  late TextEditingController _noteCtrl;
  late int _day;
  late int _startPeriod;
  late int _duration;
  late int _startWeek;
  late int _endWeek;
  late int _weekType;
  late int _colorValue;
  late int _reminderMinutes;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _roomCtrl = TextEditingController();
    _teacherCtrl = TextEditingController();
    _noteCtrl = TextEditingController();
    _day = 1;
    _startPeriod = 1;
    _duration = 2;
    _startWeek = 1;
    _endWeek = 20;
    _weekType = 0;
    _colorValue = presetColors[0];
    _reminderMinutes = 15;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final course = ModalRoute.of(context)?.settings.arguments as Course?;
    if (course != null && _editingCourse == null) {
      _editingCourse = course;
      _nameCtrl.text = course.name;
      _roomCtrl.text = course.room;
      _teacherCtrl.text = course.teacher;
      _noteCtrl.text = course.note;
      _day = course.day;
      _startPeriod = course.startPeriod;
      _duration = course.duration;
      _startWeek = course.startWeek;
      _endWeek = course.endWeek;
      _weekType = course.weekType;
      _colorValue = course.colorValue;
      _reminderMinutes = course.reminderMinutesBefore;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _roomCtrl.dispose();
    _teacherCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<ScheduleProvider>();
    final course = Course(
      id: _editingCourse?.id ?? const Uuid().v4(),
      name: _nameCtrl.text.trim(),
      room: _roomCtrl.text.trim(),
      teacher: _teacherCtrl.text.trim(),
      day: _day,
      startPeriod: _startPeriod,
      duration: _duration,
      startWeek: _startWeek,
      endWeek: _endWeek,
      weekType: _weekType,
      colorValue: _colorValue,
      note: _noteCtrl.text.trim(),
      scheduleSetId: _editingCourse?.scheduleSetId ?? provider.activeSetId,
      reminderMinutesBefore: _reminderMinutes,
    );

    if (_isEditing) {
      provider.updateCourse(course);
    } else {
      provider.addCourse(course);
    }
    Navigator.pop(context);
  }

  void _delete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除课程'),
        content: Text('确定删除「${_nameCtrl.text}」？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              context.read<ScheduleProvider>().deleteCourse(_editingCourse!.id);
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final maxPeriod = context.read<ScheduleProvider>().maxPeriod;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '编辑课程' : '添加课程'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: Icon(Icons.delete_outline, color: cs.error),
              onPressed: _delete,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _save,
        icon: const Icon(Icons.check),
        label: const Text('保存'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, 100),
          children: [
            // ── 课程名 ──
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: '课程名称',
                prefixIcon: Icon(Icons.book_outlined),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '请输入课程名' : null,
            ),
            const SizedBox(height: Gap.md),

            // ── 教室 & 教师 ──
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _roomCtrl,
                    decoration: const InputDecoration(
                      labelText: '教室',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: TextFormField(
                    controller: _teacherCtrl,
                    decoration: const InputDecoration(
                      labelText: '教师',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Gap.xl),

            // ── 上课日 ── 横向 Chip，不用弹窗
            _buildSectionLabel('上课日'),
            const SizedBox(height: Gap.sm),
            Wrap(
              spacing: Gap.sm,
              children: List.generate(7, (i) {
                final isSelected = _day == i + 1;
                return ChoiceChip(
                  label: Text(weekdayShortNames[i]),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _day = i + 1),
                );
              }),
            ),
            const SizedBox(height: Gap.xl),

            // ── 节次 ── 开始 + 持续，数字 stepper
            _buildSectionLabel('节次'),
            const SizedBox(height: Gap.sm),
            Row(
              children: [
                Expanded(
                  child: _buildNumberStepper(
                    label: '开始',
                    value: _startPeriod,
                    min: 1,
                    max: maxPeriod,
                    onChanged: (v) => setState(() => _startPeriod = v),
                  ),
                ),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: _buildNumberStepper(
                    label: '持续',
                    value: _duration,
                    min: 1,
                    max: 8,
                    suffix: '节',
                    onChanged: (v) => setState(() => _duration = v),
                  ),
                ),
                const SizedBox(width: Gap.md),
                // 预览
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: Gap.md, vertical: Gap.sm + 2),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainer,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    '第$_startPeriod-${_startPeriod + _duration - 1}节',
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Gap.xl),

            // ── 周次 ── RangeSlider
            _buildSectionLabel('周次范围'),
            const SizedBox(height: Gap.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('第$_startWeek周',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: cs.primary)),
                Text('第$_endWeek周',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: cs.primary)),
              ],
            ),
            RangeSlider(
              values: RangeValues(_startWeek.toDouble(), _endWeek.toDouble()),
              min: 1,
              max: maxWeekCount.toDouble(),
              divisions: maxWeekCount - 1,
              labels: RangeLabels('$_startWeek', '$_endWeek'),
              onChanged: (v) => setState(() {
                _startWeek = v.start.round();
                _endWeek = v.end.round();
              }),
            ),
            const SizedBox(height: Gap.sm),

            // ── 单双周 ── SegmentedButton
            _buildSectionLabel('周类型'),
            const SizedBox(height: Gap.sm),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('全周')),
                ButtonSegment(value: 1, label: Text('单周')),
                ButtonSegment(value: 2, label: Text('双周')),
              ],
              selected: {_weekType},
              onSelectionChanged: (v) => setState(() => _weekType = v.first),
            ),
            const SizedBox(height: Gap.xl),

            // ── 颜色 ──
            _buildSectionLabel('课程颜色'),
            const SizedBox(height: Gap.sm),
            CourseColorPicker(
              selectedColor: _colorValue,
              onColorSelected: (c) => setState(() => _colorValue = c),
            ),
            const SizedBox(height: Gap.xl),

            // ── 提醒 ──
            _buildSectionLabel('上课提醒'),
            const SizedBox(height: Gap.sm),
            SegmentedButton<int>(
              segments: [
                for (int i = 0; i < _reminderOptions.length; i++)
                  ButtonSegment(
                    value: _reminderOptions[i],
                    label: Text(_reminderLabels[i]),
                  ),
              ],
              selected: {_reminderMinutes},
              onSelectionChanged: (v) =>
                  setState(() => _reminderMinutes = v.first),
              showSelectedIcon: false,
            ),
            const SizedBox(height: Gap.xl),

            // ── 备注 ──
            TextFormField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                labelText: '备注',
                prefixIcon: Icon(Icons.note_outlined),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildNumberStepper({
    required String label,
    required int value,
    required int min,
    required int max,
    String suffix = '',
    required ValueChanged<int> onChanged,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          _StepperButton(
            icon: Icons.remove,
            enabled: value > min,
            onTap: () => onChanged(value - 1),
          ),
          Expanded(
            child: Column(
              children: [
                Text(label,
                    style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                Text(
                  '$value$suffix',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
          ),
          _StepperButton(
            icon: Icons.add,
            enabled: value < max,
            onTap: () => onChanged(value + 1),
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _StepperButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.all(Gap.sm),
        child: Icon(
          icon,
          size: 18,
          color: enabled ? cs.onSurface : cs.outlineVariant,
        ),
      ),
    );
  }
}
