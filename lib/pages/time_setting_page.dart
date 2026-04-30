import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/time_slot.dart';
import '../providers/schedule_provider.dart';

class TimeSettingPage extends StatefulWidget {
  const TimeSettingPage({super.key});

  @override
  State<TimeSettingPage> createState() => _TimeSettingPageState();
}

class _TimeSettingPageState extends State<TimeSettingPage> {
  late List<TimeSlot> _slots;

  @override
  void initState() {
    super.initState();
    final provider = context.read<ScheduleProvider>();
    _slots = List.from(provider.timeSlots);
  }

  Future<void> _pickTime(BuildContext context, int index, bool isStart) async {
    final slot = _slots[index];
    final initialTime = isStart ? slot.startTime : slot.endTime;
    final parts = initialTime.split(':');
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      ),
    );
    if (time != null) {
      setState(() {
        final formatted =
            '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
        if (isStart) {
          _slots[index].startTime = formatted;
        } else {
          _slots[index].endTime = formatted;
        }
      });
    }
  }

  void _addSlot() {
    final newPeriod = _slots.isEmpty ? 1 : _slots.last.period + 1;
    String startTime = '08:00';
    String endTime = '08:45';
    if (_slots.isNotEmpty) {
      final last = _slots.last;
      final lastEndParts = last.endTime.split(':');
      final lastEndHour = int.parse(lastEndParts[0]);
      final lastEndMin = int.parse(lastEndParts[1]);
      final startMin = lastEndMin + 10;
      var newStartHour = lastEndHour;
      var newStartMin = startMin;
      if (newStartMin >= 60) {
        newStartHour += 1;
        newStartMin -= 60;
      }
      startTime =
          '${newStartHour.toString().padLeft(2, '0')}:${newStartMin.toString().padLeft(2, '0')}';
      var newEndHour = newStartHour;
      var newEndMin = newStartMin + 45;
      if (newEndMin >= 60) {
        newEndHour += 1;
        newEndMin -= 60;
      }
      endTime =
          '${newEndHour.toString().padLeft(2, '0')}:${newEndMin.toString().padLeft(2, '0')}';
    }
    setState(() {
      _slots.add(TimeSlot(
        period: newPeriod,
        startTime: startTime,
        endTime: endTime,
      ));
    });
  }

  void _removeSlot(int index) {
    if (_slots.length <= 1) return;
    setState(() {
      _slots.removeAt(index);
      for (int i = 0; i < _slots.length; i++) {
        _slots[i].period = i + 1;
      }
    });
  }

  void _save() {
    final provider = context.read<ScheduleProvider>();
    provider.saveTimeSlots(_slots);
    Navigator.pop(context);
  }

  void _resetToDefault() {
    setState(() {
      _slots = List.from(defaultTimeSlots);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('上课时间设置'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '恢复默认',
            onPressed: _resetToDefault,
          ),
          TextButton(
            onPressed: _save,
            child: const Text('保存'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _slots.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final item = _slots.removeAt(oldIndex);
                  _slots.insert(newIndex, item);
                  for (int i = 0; i < _slots.length; i++) {
                    _slots[i].period = i + 1;
                  }
                });
              },
              itemBuilder: (context, index) {
                final slot = _slots[index];
                return Card(
                  key: ValueKey(slot.period),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${slot.period}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => _pickTime(context, index, true),
                                  borderRadius: BorderRadius.circular(6),
                                  child: InputDecorator(
                                    decoration: const InputDecoration(
                                      labelText: '开始',
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                    ),
                                    child: Text(slot.startTime,
                                        style: const TextStyle(fontSize: 16)),
                                  ),
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Text('—', style: TextStyle(fontSize: 18)),
                              ),
                              Expanded(
                                child: InkWell(
                                  onTap: () => _pickTime(context, index, false),
                                  borderRadius: BorderRadius.circular(6),
                                  child: InputDecorator(
                                    decoration: const InputDecoration(
                                      labelText: '结束',
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                    ),
                                    child: Text(slot.endTime,
                                        style: const TextStyle(fontSize: 16)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline,
                              color: Colors.red, size: 20),
                          onPressed: _slots.length > 1
                              ? () => _removeSlot(index)
                              : null,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: OutlinedButton.icon(
              onPressed: _addSlot,
              icon: const Icon(Icons.add),
              label: const Text('添加时间段'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
