import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import '../../utils/course_parser_utils.dart';
import 'edu_import_models.dart';

class StrongWisdomParser {
  static const String version2024 = '强智 2024 工具提示版';
  static const String version2017 = '强智 2017 Element UI 版';
  static const String versionCommon = '强智通用表格版';
  static const String versionLegacy = '强智旧版';

  static EduImportBatch parse(CapturedPageBundle bundle) {
    final allDrafts = <ImportedCourseDraft>[];
    final parserVersions = <String>[];

    for (final captured in bundle.documents) {
      final document = html_parser.parse(captured.html);
      final attempts = <_ParseAttempt>[
        _parse2024(document),
        _parse2017(document),
        _parseCommon(document),
        _parseLegacy(document),
      ];

      _ParseAttempt? selected;
      for (final attempt in attempts) {
        if (attempt.drafts.any((draft) => draft.isValid)) {
          selected = attempt;
          break;
        }
      }
      selected ??= attempts.cast<_ParseAttempt?>().firstWhere(
        (attempt) => attempt!.drafts.isNotEmpty,
        orElse: () => null,
      );
      if (selected == null) continue;

      allDrafts.addAll(selected.drafts);
      if (!parserVersions.contains(selected.version)) {
        parserVersions.add(selected.version);
      }
    }

    final unique = <String, ImportedCourseDraft>{};
    for (final draft in allDrafts) {
      unique.putIfAbsent(draft.fingerprint, () => draft);
    }

    return EduImportBatch(
      drafts: unique.values.toList(growable: false),
      parserVersions: parserVersions,
      blockedCrossOriginFrameCount: bundle.blockedCrossOriginFrameCount,
    );
  }

  static _ParseAttempt _parse2024(Document document) {
    final cells = document.querySelectorAll('[name="kbDataTd"]');
    if (cells.isEmpty) return const _ParseAttempt(version2024, []);
    return _ParseAttempt(
      version2024,
      _parseCourseCells(
        document,
        cells,
        courseSelector:
            '.qz-tooltipContent-item, .qz-toolitiplists, .course-item',
      ),
    );
  }

  static _ParseAttempt _parse2017(Document document) {
    final body = document.querySelector('.el-table__body');
    if (body == null) return const _ParseAttempt(version2017, []);
    final header = document.querySelector('.el-table__header');
    return _ParseAttempt(
      version2017,
      _parseTable(
        body,
        headerTable: header,
        courseSelector: '.course-item, .kbcontent',
      ),
    );
  }

  static _ParseAttempt _parseCommon(Document document) {
    final tables = document
        .querySelectorAll('table')
        .where(
          (table) =>
              table.id == 'kbtable' ||
              table.classes.contains('timetable') ||
              table.querySelector('.kbcontent') != null,
        )
        .toList(growable: false);
    final drafts = <ImportedCourseDraft>[];
    for (final table in tables) {
      drafts.addAll(_parseTable(table, courseSelector: '.kbcontent'));
    }
    return _ParseAttempt(versionCommon, drafts);
  }

  static _ParseAttempt _parseLegacy(Document document) {
    final table = document.querySelector('table#kb, #kb table');
    if (table != null) {
      return _ParseAttempt(
        versionLegacy,
        _parseTable(table, courseSelector: '[title], .kb, a'),
      );
    }

    final nodes = document.querySelectorAll(
      '#kb[title], #kb [title], .kb[title]',
    );
    final drafts = nodes
        .map((node) => _draftFromNode(node, dayHint: _dayFromElement(node)))
        .toList(growable: false);
    return _ParseAttempt(versionLegacy, drafts);
  }

  static List<ImportedCourseDraft> _parseCourseCells(
    Document document,
    List<Element> cells, {
    required String courseSelector,
  }) {
    final headerDays = _headerDays(document.querySelector('table'));
    final drafts = <ImportedCourseDraft>[];
    for (final cell in cells) {
      final day =
          _dayFromElement(cell) ??
          _dayFromTableCell(cell, headerDays) ??
          _dayFromText(cell.text);
      drafts.addAll(
        _draftsFromCell(cell, dayHint: day, courseSelector: courseSelector),
      );
    }
    return drafts;
  }

  static List<ImportedCourseDraft> _parseTable(
    Element table, {
    Element? headerTable,
    required String courseSelector,
  }) {
    final headerDays = _headerDays(headerTable ?? table);
    final drafts = <ImportedCourseDraft>[];
    final rows = table.querySelectorAll('tr');
    for (final row in rows) {
      final cells = row.children
          .where((element) => element.localName == 'td')
          .toList(growable: false);
      for (final cell in cells) {
        final day =
            _dayFromElement(cell) ??
            _dayFromTableCell(cell, headerDays) ??
            _dayFromText(cell.text);
        if (!_looksLikeCourseCell(cell, courseSelector)) continue;
        drafts.addAll(
          _draftsFromCell(cell, dayHint: day, courseSelector: courseSelector),
        );
      }
    }
    return drafts;
  }

  static bool _looksLikeCourseCell(Element cell, String selector) {
    if (cell.querySelectorAll(selector).isNotEmpty) return true;
    final text = _textWithBreaks(cell);
    return text.contains('周') && text.contains('节');
  }

  static List<ImportedCourseDraft> _draftsFromCell(
    Element cell, {
    required int? dayHint,
    required String courseSelector,
  }) {
    final nodes = cell.querySelectorAll(courseSelector);
    if (nodes.isNotEmpty) {
      final leafNodes = nodes
          .where((candidate) {
            return !nodes.any(
              (other) =>
                  other != candidate &&
                  other.querySelectorAll(courseSelector).contains(candidate),
            );
          })
          .toList(growable: false);
      final targets = leafNodes.isEmpty ? nodes : leafNodes;
      return targets
          .map((node) => _draftFromNode(node, dayHint: dayHint))
          .toList(growable: false);
    }

    final parts = _textWithBreaks(
      cell,
    ).split(RegExp(r'\n\s*-{3,}\s*\n')).where((part) => part.trim().isNotEmpty);
    return parts
        .map((part) => _draftFromText(part, source: cell, dayHint: dayHint))
        .toList(growable: false);
  }

  static ImportedCourseDraft _draftFromNode(
    Element node, {
    required int? dayHint,
  }) {
    final title = node.attributes['title']?.trim();
    final text = title != null && title.isNotEmpty
        ? title.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        : _textWithBreaks(node);
    return _draftFromText(text, source: node, dayHint: dayHint);
  }

  static ImportedCourseDraft _draftFromText(
    String rawText, {
    required Element source,
    required int? dayHint,
  }) {
    final lines = rawText
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((line) => line.isNotEmpty && line != '&nbsp;')
        .toList(growable: false);

    String attribute(String name) => source.attributes[name]?.trim() ?? '';

    final scheduleLine = lines.firstWhere(
      (line) => line.contains('周') || line.contains('节'),
      orElse: () => '',
    );
    final weeksText = _firstNonEmpty([
      attribute('data-weeks'),
      _titledValue(source, const ['周次', '周数', '上课周次']),
      lines.firstWhere(
        (line) => line.contains('周'),
        orElse: () => scheduleLine,
      ),
    ]);
    final periodText = _firstNonEmpty([
      attribute('data-period'),
      _titledValue(source, const ['节次', '节/周', '上课节次']),
      lines.firstWhere(
        (line) => line.contains('节'),
        orElse: () => scheduleLine,
      ),
    ]);

    final name =
        (attribute('data-name').isNotEmpty
                ? attribute('data-name')
                : lines.firstWhere(
                    (line) =>
                        !_isMetadataLine(line) &&
                        !line.contains('周') &&
                        !line.contains('节'),
                    orElse: () => '',
                  ))
            .trim();
    final teacher = _firstNonEmpty([
      attribute('data-teacher'),
      _titledValue(source, const ['老师', '教师', '任课老师', '任课教师']),
      _labeledValue(lines, const ['老师', '教师', '任课老师', '任课教师']),
    ]);
    final room = _firstNonEmpty([
      attribute('data-room'),
      _titledValue(source, const ['教室', '地点', '上课地点']),
      _labeledValue(lines, const ['教室', '地点', '上课地点']),
    ]);
    final note = _firstNonEmpty([
      attribute('data-note'),
      _labeledValue(lines, const ['备注']),
    ]);

    final day =
        _parseDay(attribute('data-day')) ?? dayHint ?? _dayFromText(rawText);
    final periods = _parsePeriods(periodText);
    final weeks = CourseParserUtils.parseWeeks(weeksText);
    final issues = <String>[];
    if (name.isEmpty) issues.add('缺少课程名称');
    if (day == null) issues.add('无法识别星期');
    if (periods == null) issues.add('无法识别节次');
    if (weeks.isEmpty) issues.add('无法识别有效周次');

    return ImportedCourseDraft(
      name: name,
      teacher: teacher,
      room: room,
      day: day,
      startPeriod: periods?.$1,
      duration: periods == null ? null : periods.$2 - periods.$1 + 1,
      activeWeeks: weeks,
      note: note,
      validationIssues: issues,
    );
  }

  static String _labeledValue(List<String> lines, List<String> labels) {
    for (final line in lines) {
      for (final label in labels) {
        final match = RegExp('^$label[：:]?\\s*(.+)\$').firstMatch(line);
        if (match != null) return match.group(1)?.trim() ?? '';
      }
    }
    return '';
  }

  static String _titledValue(Element source, List<String> labels) {
    final normalizedLabels = labels.map(_normalizeLabel).toSet();
    final candidates = <Element>[source, ...source.querySelectorAll('[title]')];
    for (final candidate in candidates) {
      final title = candidate.attributes['title'];
      if (title == null || !normalizedLabels.contains(_normalizeLabel(title))) {
        continue;
      }
      final value = _textWithBreaks(
        candidate,
      ).replaceAll(RegExp(r'\s+'), ' ').trim();
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  static String _normalizeLabel(String value) {
    return value.replaceAll(RegExp(r'[\s：:]+'), '');
  }

  static String _firstNonEmpty(Iterable<String> values) {
    return values.firstWhere(
      (value) => value.trim().isNotEmpty,
      orElse: () => '',
    );
  }

  static bool _isMetadataLine(String line) {
    return RegExp(r'^(教师|老师|任课教师|任课老师|教室|地点|上课地点|备注)[：:]').hasMatch(line);
  }

  static (int, int)? _parsePeriods(String value) {
    final range = RegExp(
      r'(?:第|\[|【)?\s*0*(\d{1,2})\s*[-~—－至]\s*0*(\d{1,2})\s*节',
    ).firstMatch(value);
    if (range != null) {
      final start = int.tryParse(range.group(1)!);
      final end = int.tryParse(range.group(2)!);
      if (start != null && end != null && start >= 1 && end >= start) {
        return (start, end);
      }
    }
    final single = RegExp(r'(?:第|\[|【)?\s*0*(\d{1,2})\s*节').firstMatch(value);
    final period = single == null ? null : int.tryParse(single.group(1)!);
    return period == null || period < 1 ? null : (period, period);
  }

  static List<int?> _headerDays(Element? table) {
    if (table == null) return const [];
    final headerRow =
        table.querySelector('thead tr') ?? table.querySelector('tr');
    if (headerRow == null) return const [];
    return headerRow.children.map((cell) => _dayFromText(cell.text)).toList();
  }

  static int? _dayFromTableCell(Element cell, List<int?> headerDays) {
    final index = cell.parent?.children.indexOf(cell) ?? -1;
    if (index < 0 || index >= headerDays.length) return null;
    return headerDays[index];
  }

  static int? _dayFromElement(Element element) {
    return _parseDay(element.attributes['data-day'] ?? '') ??
        _parseDay(element.attributes['data-weekday'] ?? '');
  }

  static int? _parseDay(String value) {
    final numeric = int.tryParse(value.trim());
    if (numeric != null && numeric >= 1 && numeric <= 7) return numeric;
    return _dayFromText(value);
  }

  static int? _dayFromText(String text) {
    final normalized = text.replaceAll('星期', '周').replaceAll('礼拜', '周');
    const labels = {
      '周一': 1,
      '周二': 2,
      '周三': 3,
      '周四': 4,
      '周五': 5,
      '周六': 6,
      '周日': 7,
      '周天': 7,
    };
    for (final entry in labels.entries) {
      if (normalized.contains(entry.key)) return entry.value;
    }
    return null;
  }

  static String _textWithBreaks(Node node) {
    if (node is Text) return node.data;
    if (node is! Element) return '';
    if (node.localName == 'script' || node.localName == 'style') return '';
    if (node.localName == 'br' || node.localName == 'hr') return '\n';
    return node.nodes.map(_textWithBreaks).join();
  }
}

class _ParseAttempt {
  const _ParseAttempt(this.version, this.drafts);

  final String version;
  final List<ImportedCourseDraft> drafts;
}
