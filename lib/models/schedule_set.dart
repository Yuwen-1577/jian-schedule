import 'package:uuid/uuid.dart';
import '../utils/constants.dart';

class ScheduleSet {
  final String id;
  String name;
  DateTime semesterStart;
  int sortOrder;

  ScheduleSet({
    String? id,
    required this.name,
    required this.semesterStart,
    this.sortOrder = 0,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'semesterStart': semesterStart.toIso8601String(),
      'sortOrder': sortOrder,
    };
  }

  factory ScheduleSet.fromMap(Map<String, dynamic> map) {
    return ScheduleSet(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      semesterStart:
          DateTime.tryParse(map['semesterStart'] as String? ?? '') ??
          defaultSemesterStart,
      sortOrder: map['sortOrder'] as int? ?? 0,
    );
  }
}
