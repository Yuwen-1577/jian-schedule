import '../../models/course.dart';

/// 教务系统课表导入的通用策略接口
abstract class EduImportStrategy {
  /// 抓取并解析课程
  Future<List<Course>> fetchCourses();
}
