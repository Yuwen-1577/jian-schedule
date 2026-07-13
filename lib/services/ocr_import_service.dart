import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../models/course.dart';
import '../utils/constants.dart';

class OcrImportService {
  static const String _systemPrompt = '''
你是一个专业的课表结构识别引擎。用户会上传一张课程表截图，你需要精确解析表格中的课程信息，并输出严格的 JSON 格式。

表结构理解规则：
1. 课程表通常为二维网格，列代表星期几（1-7，周一到周日），行代表节次。
2. 每个单元格如果包含课程，提取以下信息：
   - name: 课程名称（必需，如"高等数学"）
   - teacher: 授课教师（如"张三"，无则为空字符串）
   - room: 上课地点/教室（如"教学楼A101"，无则为空字符串）
   - day: 星期几（1代表周一，7代表周日，整数）
   - startPeriod: 开始节次（如第一节开始则为1，整数）
   - duration: 持续节次（如占用1、2节，则duration为2，整数）
   - activeWeeks: 上课的周次列表（整数数组）。
     - 若写明"1-8周"，则解析为 [1,2,3,4,5,6,7,8]
     - 若写明"1-8周单周"，则解析为 [1,3,5,7]
     - 若未明确标出周次，默认假定为 1-25 周

输出要求：
必须只输出以下格式的纯净 JSON，不要包含任何 markdown 代码块（如 ```json 等），直接返回 `{` 开头的数据。
{
  "courses": [
    {
      "name": "课程名称",
      "teacher": "教师",
      "room": "教室",
      "day": 1,
      "startPeriod": 1,
      "duration": 2,
      "activeWeeks": [1, 2, 3, 4]
    }
  ]
}
''';

  static Future<List<Course>> parseImage(
    String imagePath,
    String apiUrl,
    String apiKey,
    String modelName,
  ) async {
    if (apiUrl.isEmpty || apiKey.isEmpty || modelName.isEmpty) {
      throw Exception('请先在设置中配置完整的 OCR 大模型 API 信息');
    }

    final bytes = await File(imagePath).readAsBytes();
    final base64Image = base64Encode(bytes);

    final requestBody = {
      "model": modelName,
      "messages": [
        {"role": "system", "content": _systemPrompt},
        {
          "role": "user",
          "content": [
            {"type": "text", "text": "请提取这张课表截图中的所有课程信息。"},
            {
              "type": "image_url",
              "image_url": {"url": "data:image/jpeg;base64,$base64Image"},
            },
          ],
        },
      ],
      "temperature": 0.1,
    };

    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode(requestBody),
    );

    if (response.statusCode != 200) {
      throw Exception('模型请求失败: ${response.statusCode}\n${response.body}');
    }

    final responseData = jsonDecode(utf8.decode(response.bodyBytes));
    final choices = responseData['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      throw Exception('模型返回数据格式异常');
    }

    String content = choices[0]['message']['content'] ?? '';

    content = content.trim();
    if (content.startsWith('```')) {
      final match = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(content);
      if (match != null) {
        content = match.group(1)!.trim();
      }
    }

    try {
      final Map<String, dynamic> jsonMap = jsonDecode(content);
      final List<dynamic> courseList = jsonMap['courses'] ?? [];

      return courseList.map((c) {
        final List<dynamic> weeksDynamic = c['activeWeeks'] ?? [];
        final List<int> weeks =
            weeksDynamic
                .whereType<num>()
                .map((week) => week.toInt())
                .where((week) => week >= 1 && week <= maxWeekCount)
                .toSet()
                .toList()
              ..sort();
        final randomColor = presetColors[Random().nextInt(presetColors.length)];

        return Course(
          id: const Uuid().v4(),
          name: c['name'] ?? '未知课程',
          room: c['room'] ?? '',
          teacher: c['teacher'] ?? '',
          day: c['day'] ?? 1,
          startPeriod: c['startPeriod'] ?? 1,
          duration: c['duration'] ?? 1,
          activeWeeks: weeks.isEmpty
              ? List.generate(maxWeekCount, (i) => i + 1)
              : weeks,
          colorValue: randomColor,
        );
      }).toList();
    } catch (e) {
      throw Exception('JSON 解析失败: $e\n模型原始输出: $content');
    }
  }
}
