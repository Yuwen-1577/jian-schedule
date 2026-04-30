import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/course.dart';
import '../providers/schedule_provider.dart';
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

  // 表单字段
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
    );

    if (_isEditing) {
      provider.updateCourse(course);
    } else {
      provider.addCourse(course);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '编辑课程' : '添加课程'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('保存'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 课程名
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: '课程名称 *',
                prefixIcon: Icon(Icons.book),
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? '请输入课程名' : null,
            ),
            const SizedBox(height: 14),

            // 教室 & 教师
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _roomCtrl,
                    decoration: const InputDecoration(
                      labelText: '教室',
                      prefixIcon: Icon(Icons.location_on_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _teacherCtrl,
                    decoration: const InputDecoration(
                      labelText: '教师',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 上课日
            _buildPickerRow(
              '上课日',
              Icons.calendar_today,
              weekdayNames[_day - 1],
              () => _showPicker(
                title: '选择上课日',
                current: _day - 1,
                items: weekdayNames,
                onSelected: (i) => setState(() => _day = i + 1),
              ),
            ),
            const SizedBox(height: 10),

            // 开始节次 & 持续节数
            Row(
              children: [
                Expanded(
                  child: _buildPickerRow(
                    '开始节次',
                    Icons.access_time,
                    '第$_startPeriod节',
                    () => _showPicker(
                      title: '选择开始节次',
                      current: _startPeriod - 1,
                      items: List.generate(12, (i) => '第${i + 1}节'),
                      onSelected: (i) => setState(() => _startPeriod = i + 1),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildPickerRow(
                    '持续节数',
                    Icons.more_time,
                    '$_duration节',
                    () => _showPicker(
                      title: '选择持续节数',
                      current: _duration - 1,
                      items: List.generate(8, (i) => '${i + 1}节'),
                      onSelected: (i) =>
                          setState(() => _duration = i + 1),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 起止周
            Row(
              children: [
                Expanded(
                  child: _buildPickerRow(
                    '起始周',
                    Icons.play_arrow,
                    '第$_startWeek周',
                    () => _showPicker(
                      title: '选择起始周',
                      current: _startWeek - 1,
                      items: List.generate(25, (i) => '第${i + 1}周'),
                      onSelected: (i) =>
                          setState(() => _startWeek = i + 1),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildPickerRow(
                    '结束周',
                    Icons.stop,
                    '第$_endWeek周',
                    () => _showPicker(
                      title: '选择结束周',
                      current: _endWeek - 1,
                      items: List.generate(25, (i) => '第${i + 1}周'),
                      onSelected: (i) =>
                          setState(() => _endWeek = i + 1),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 单双周
            _buildSegmentSelector(
              '周类型',
              Icons.repeat,
              weekTypeNames,
              _weekType,
              (i) => setState(() => _weekType = i),
            ),
            const SizedBox(height: 16),

            // 颜色选择
            const Text('课程颜色', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            CourseColorPicker(
              selectedColor: _colorValue,
              onColorSelected: (c) => setState(() => _colorValue = c),
            ),
            const SizedBox(height: 14),

            // 备注
            TextFormField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                labelText: '备注',
                prefixIcon: Icon(Icons.note_outlined),
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 20),

            // 删除按钮 (仅编辑模式)
            if (_isEditing)
              OutlinedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('确认删除'),
                      content: Text('确定要删除课程"${_nameCtrl.text}"吗？'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('取消'),
                        ),
                        TextButton(
                          onPressed: () {
                            context
                                .read<ScheduleProvider>()
                                .deleteCourse(_editingCourse!.id);
                            Navigator.pop(ctx);
                            Navigator.pop(context);
                          },
                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                          child: const Text('删除'),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                label: const Text('删除课程', style: TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickerRow(
      String label, IconData icon, String value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          border: const OutlineInputBorder(),
        ),
        child: Text(value),
      ),
    );
  }

  Widget _buildSegmentSelector(
      String label, IconData icon, List<String> options, int selected, ValueChanged<int> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: Colors.grey[600]),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: List.generate(options.length, (i) {
            final isSelected = i == selected;
            return Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : null,
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey[400]!,
                    ),
                    borderRadius: i == 0
                        ? const BorderRadius.only(
                            topLeft: Radius.circular(6),
                            bottomLeft: Radius.circular(6),
                          )
                        : i == options.length - 1
                            ? const BorderRadius.only(
                                topRight: Radius.circular(6),
                                bottomRight: Radius.circular(6),
                              )
                            : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    options[i],
                    style: TextStyle(
                      color: isSelected
                          ? Theme.of(context).colorScheme.onPrimary
                          : null,
                      fontWeight:
                          isSelected ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  void _showPicker({
    required String title,
    required int current,
    required List<String> items,
    required ValueChanged<int> onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        height: 280,
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (_, i) => ListTile(
                  title: Text(items[i]),
                  trailing: i == current
                      ? const Icon(Icons.check, color: Colors.blue)
                      : null,
                  onTap: () {
                    onSelected(i);
                    Navigator.pop(ctx);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
