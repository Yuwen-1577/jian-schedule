import 'dart:convert';
import 'dart:math' as math;

import 'package:html/dom.dart';

import 'edu_import_models.dart';

enum EduImportDiagnosticLevel { structure, sanitizedHtml }

class EduImportParseResult {
  const EduImportParseResult({required this.batch, required this.diagnostics});

  final EduImportBatch batch;
  final EduImportDiagnostics diagnostics;
}

class EduImportRuleDiagnostic {
  const EduImportRuleDiagnostic({
    required this.documentIndex,
    required this.ruleId,
    required this.version,
    required this.selected,
    required this.draftCount,
    required this.validCount,
    required this.invalidCount,
    required this.validationIssueCounts,
  });

  final int documentIndex;
  final String ruleId;
  final String version;
  final bool selected;
  final int draftCount;
  final int validCount;
  final int invalidCount;
  final Map<String, int> validationIssueCounts;

  Map<String, Object> toJson() => {
    'documentIndex': documentIndex,
    'ruleId': ruleId,
    'version': version,
    'selected': selected,
    'draftCount': draftCount,
    'validCount': validCount,
    'invalidCount': invalidCount,
    'validationIssueCounts': validationIssueCounts,
  };
}

class EduImportTableDiagnostic {
  const EduImportTableDiagnostic({
    required this.rowCount,
    required this.maxColumnCount,
    required this.rowSpanCellCount,
    required this.columnSpanCellCount,
  });

  final int rowCount;
  final int maxColumnCount;
  final int rowSpanCellCount;
  final int columnSpanCellCount;

  Map<String, Object> toJson() => {
    'rowCount': rowCount,
    'maxColumnCount': maxColumnCount,
    'rowSpanCellCount': rowSpanCellCount,
    'columnSpanCellCount': columnSpanCellCount,
  };
}

class EduImportDocumentDiagnostic {
  const EduImportDocumentDiagnostic({
    required this.index,
    required this.frameDepth,
    required this.elementCount,
    required this.reportedElementCount,
    required this.truncated,
    required this.tagHistogram,
    required this.attributeNameHistogram,
    required this.tables,
    required this.frameElementCount,
  });

  final int index;
  final int frameDepth;
  final int elementCount;
  final int reportedElementCount;
  final bool truncated;
  final Map<String, int> tagHistogram;
  final Map<String, int> attributeNameHistogram;
  final List<EduImportTableDiagnostic> tables;
  final int frameElementCount;

  Map<String, Object> toJson() => {
    'index': index,
    'frameDepth': frameDepth,
    'elementCount': elementCount,
    'reportedElementCount': reportedElementCount,
    'truncated': truncated,
    'tagHistogram': tagHistogram,
    'attributeNameHistogram': attributeNameHistogram,
    'tables': tables.map((table) => table.toJson()).toList(growable: false),
    'frameElementCount': frameElementCount,
  };
}

class EduImportSanitizedDocument {
  const EduImportSanitizedDocument({
    required this.index,
    required this.frameDepth,
    required this.html,
    required this.truncated,
  });

  final int index;
  final int frameDepth;
  final String html;
  final bool truncated;
}

class EduImportDiagnostics {
  const EduImportDiagnostics({
    required this.documents,
    required this.ruleAttempts,
    required this.sanitizedDocuments,
    required this.blockedCrossOriginFrameCount,
    required this.truncated,
  });

  static const String schemaVersion = '1.0';

  final List<EduImportDocumentDiagnostic> documents;
  final List<EduImportRuleDiagnostic> ruleAttempts;
  final List<EduImportSanitizedDocument> sanitizedDocuments;
  final int blockedCrossOriginFrameCount;
  final bool truncated;

  String toStructureJson() {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert({
      'schemaVersion': schemaVersion,
      'reportType': 'structure',
      'documentCount': documents.length,
      'blockedCrossOriginFrameCount': blockedCrossOriginFrameCount,
      'truncated': truncated,
      'documents': documents
          .map((document) => document.toJson())
          .toList(growable: false),
      'ruleAttempts': ruleAttempts
          .map((attempt) => attempt.toJson())
          .toList(growable: false),
    });
  }

  String toSanitizedHtml() {
    const elementEscape = HtmlEscape(HtmlEscapeMode.element);
    final structureReport = elementEscape.convert(toStructureJson());
    final buffer = StringBuffer()
      ..writeln('<!doctype html>')
      ..writeln('<html lang="zh-CN">')
      ..writeln('<head>')
      ..writeln('<meta charset="utf-8">')
      ..writeln('<meta name="viewport" content="width=device-width">')
      ..writeln('<title>简课表深度脱敏诊断</title>')
      ..writeln('</head>')
      ..writeln('<body>')
      ..writeln('<h1>简课表深度脱敏诊断</h1>')
      ..writeln(
        '<p>此文件只包含脱敏后的页面结构，不包含网址、账号、Cookie、'
        '课程名、教师、教室或表单输入值。发送前仍请自行检查。</p>',
      )
      ..writeln('<h2>结构报告</h2>')
      ..writeln('<pre><code>$structureReport</code></pre>');

    for (final document in sanitizedDocuments) {
      buffer
        ..writeln(
          '<h2>文档 ${document.index + 1} · 框架深度 '
          '${document.frameDepth}</h2>',
        )
        ..writeln('<p>截断：${document.truncated ? '是' : '否'}</p>')
        ..writeln('<pre><code>')
        ..writeln(elementEscape.convert(document.html))
        ..writeln('</code></pre>');
    }

    buffer
      ..writeln('</body>')
      ..writeln('</html>');
    return buffer.toString();
  }
}

class EduImportDiagnosticBuilder {
  static const int maxElementCount = 20000;

  static const Set<String> _blockedElements = {
    'script',
    'style',
    'link',
    'meta',
    'base',
    'object',
    'embed',
    'source',
    'img',
    'video',
    'audio',
    'svg',
    'canvas',
    'noscript',
  };

  static const Set<String> _voidElements = {
    'area',
    'base',
    'br',
    'col',
    'embed',
    'hr',
    'img',
    'input',
    'link',
    'meta',
    'param',
    'source',
    'track',
    'wbr',
  };

  static const Set<String> _semanticTitles = {
    '老师',
    '教师',
    '任课老师',
    '任课教师',
    '教室',
    '地点',
    '上课地点',
    '周次',
    '周数',
    '上课周次',
    '节次',
    '节/周',
    '上课节次',
    '备注',
  };

  static EduImportDiagnostics build({
    required List<Document> parsedDocuments,
    required List<CapturedPageDocument> capturedDocuments,
    required List<EduImportRuleDiagnostic> ruleAttempts,
    required int blockedCrossOriginFrameCount,
  }) {
    var remainingElements = maxElementCount;
    var anyTruncated = false;
    final documentDiagnostics = <EduImportDocumentDiagnostic>[];
    final sanitizedDocuments = <EduImportSanitizedDocument>[];

    for (var index = 0; index < parsedDocuments.length; index++) {
      final document = parsedDocuments[index];
      final traversal = _collectElements(
        document.documentElement,
        remainingElements,
      );
      final reportedElements = traversal.elements;
      final reportedCount = reportedElements.length;
      final truncated = traversal.truncated;
      anyTruncated = anyTruncated || truncated;
      remainingElements -= reportedCount;

      final tagHistogram = <String, int>{};
      final attributeHistogram = <String, int>{};
      var frameElementCount = 0;
      for (final element in reportedElements) {
        final tag = element.localName ?? 'unknown';
        tagHistogram.update(tag, (count) => count + 1, ifAbsent: () => 1);
        if (tag == 'iframe' || tag == 'frame') frameElementCount += 1;
        for (final attribute in element.attributes.keys) {
          final category = _attributeCategory(attribute.toString());
          attributeHistogram.update(
            category,
            (count) => count + 1,
            ifAbsent: () => 1,
          );
        }
      }

      final tables = _inspectTables(reportedElements);
      documentDiagnostics.add(
        EduImportDocumentDiagnostic(
          index: index,
          frameDepth: capturedDocuments[index].frameDepth,
          elementCount: reportedCount,
          reportedElementCount: reportedCount,
          truncated: truncated,
          tagHistogram: _sortedHistogram(tagHistogram),
          attributeNameHistogram: _sortedHistogram(attributeHistogram),
          tables: tables,
          frameElementCount: frameElementCount,
        ),
      );

      final sanitizerBudget = _SanitizerBudget(reportedCount);
      final sanitized = document.documentElement == null
          ? ''
          : _sanitizeNode(document.documentElement!, sanitizerBudget);
      sanitizedDocuments.add(
        EduImportSanitizedDocument(
          index: index,
          frameDepth: capturedDocuments[index].frameDepth,
          html: sanitized,
          truncated: truncated || sanitizerBudget.truncated,
        ),
      );
    }

    return EduImportDiagnostics(
      documents: List.unmodifiable(documentDiagnostics),
      ruleAttempts: List.unmodifiable(ruleAttempts),
      sanitizedDocuments: List.unmodifiable(sanitizedDocuments),
      blockedCrossOriginFrameCount: blockedCrossOriginFrameCount,
      truncated: anyTruncated,
    );
  }

  static _LimitedElementTraversal _collectElements(Element? root, int limit) {
    if (root == null) {
      return const _LimitedElementTraversal([], false);
    }
    if (limit <= 0) {
      return const _LimitedElementTraversal([], true);
    }

    final elements = <Element>[];
    final pending = <Element>[root];
    while (pending.isNotEmpty && elements.length < limit) {
      final element = pending.removeLast();
      elements.add(element);
      for (var index = element.children.length - 1; index >= 0; index--) {
        pending.add(element.children[index]);
      }
    }
    return _LimitedElementTraversal(
      List.unmodifiable(elements),
      pending.isNotEmpty,
    );
  }

  static List<EduImportTableDiagnostic> _inspectTables(List<Element> elements) {
    final tableRows = <Element, List<Element>>{};
    for (final element in elements) {
      if (element.localName == 'table') {
        tableRows[element] = <Element>[];
      }
    }
    if (tableRows.isEmpty) return const [];

    for (final element in elements) {
      if (element.localName != 'tr') continue;
      Element? parent = element.parent;
      while (parent != null && parent.localName != 'table') {
        parent = parent.parent;
      }
      tableRows[parent]?.add(element);
    }
    return List.unmodifiable(
      tableRows.values.map(_inspectTableRows).toList(growable: false),
    );
  }

  static EduImportTableDiagnostic _inspectTableRows(List<Element> rows) {
    var maxColumnCount = 0;
    var rowSpanCellCount = 0;
    var columnSpanCellCount = 0;
    for (final row in rows) {
      var columns = 0;
      final cells = row.children.where(
        (child) => child.localName == 'td' || child.localName == 'th',
      );
      for (final cell in cells) {
        final columnSpan = int.tryParse(cell.attributes['colspan'] ?? '') ?? 1;
        final rowSpan = int.tryParse(cell.attributes['rowspan'] ?? '') ?? 1;
        columns += columnSpan.clamp(1, 100);
        if (columnSpan > 1) columnSpanCellCount += 1;
        if (rowSpan > 1) rowSpanCellCount += 1;
      }
      maxColumnCount = math.max(maxColumnCount, columns);
    }
    return EduImportTableDiagnostic(
      rowCount: rows.length,
      maxColumnCount: maxColumnCount,
      rowSpanCellCount: rowSpanCellCount,
      columnSpanCellCount: columnSpanCellCount,
    );
  }

  static Map<String, int> _sortedHistogram(Map<String, int> values) {
    final entries = values.entries.toList()
      ..sort((left, right) => left.key.compareTo(right.key));
    return Map.unmodifiable(Map.fromEntries(entries));
  }

  static String _attributeCategory(String rawName) {
    final name = rawName.toLowerCase();
    if (name.startsWith('data-')) return 'data-*';
    if (name.startsWith('aria-')) return 'aria-*';
    if (name.startsWith('on')) return 'event-handler';
    const known = {
      'class',
      'id',
      'name',
      'title',
      'rowspan',
      'colspan',
      'scope',
      'role',
      'href',
      'src',
      'action',
      'value',
      'type',
    };
    return known.contains(name) ? name : 'custom';
  }

  static String _sanitizeNode(Node node, _SanitizerBudget budget) {
    if (node is Text) {
      return _sanitizeText(node.data);
    }
    if (node is! Element) return '';
    if (budget.remaining <= 0) {
      budget.truncated = true;
      if (budget.markerWritten) return '';
      budget.markerWritten = true;
      return '<!-- 内容已截断 -->';
    }
    budget.remaining -= 1;

    final tag = (node.localName ?? 'div').toLowerCase();
    if (_blockedElements.contains(tag)) return '';
    if (tag == 'iframe' || tag == 'frame') {
      return '<$tag data-redacted-frame="true"></$tag>';
    }
    if (tag == 'input' || tag == 'textarea' || tag == 'select') {
      return '<$tag data-redacted-input="true"></$tag>';
    }

    final attributes = _sanitizeAttributes(node);
    final buffer = StringBuffer('<$tag$attributes>');
    if (!_voidElements.contains(tag)) {
      for (final child in node.nodes) {
        buffer.write(_sanitizeNode(child, budget));
      }
      buffer.write('</$tag>');
    }
    return buffer.toString();
  }

  static String _sanitizeAttributes(Element element) {
    const attributeEscape = HtmlEscape(HtmlEscapeMode.attribute);
    final attributes = <String, String>{};
    for (final entry in element.attributes.entries) {
      final rawName = entry.key.toString().toLowerCase();
      final rawValue = entry.value.trim();
      if (rawName == 'class') {
        final safeTokens = rawValue
            .split(RegExp(r'\s+'))
            .where(_isSafeIdentifier)
            .toList(growable: false);
        if (safeTokens.isNotEmpty) {
          attributes['class'] = safeTokens.join(' ');
        }
      } else if (rawName == 'id' || rawName == 'name') {
        if (_isSafeIdentifier(rawValue)) attributes[rawName] = rawValue;
      } else if (rawName == 'rowspan' || rawName == 'colspan') {
        final value = int.tryParse(rawValue);
        if (value != null && value >= 1 && value <= 100) {
          attributes[rawName] = value.toString();
        }
      } else if (rawName == 'scope') {
        if (const {'row', 'col', 'rowgroup', 'colgroup'}.contains(rawValue)) {
          attributes[rawName] = rawValue;
        }
      } else if (rawName == 'title') {
        final normalized = rawValue.replaceAll(RegExp(r'[\s：:]+'), '');
        final title = _semanticTitles.firstWhere(
          (candidate) =>
              candidate.replaceAll(RegExp(r'[\s：:]+'), '') == normalized,
          orElse: () => '',
        );
        if (title.isNotEmpty) attributes['title'] = title;
      } else if (rawName.startsWith('data-') &&
          _isSafeAttributeIdentifier(rawName)) {
        attributes[rawName] = _dataAttributePlaceholder(rawName);
      }
    }
    final entries = attributes.entries.toList()
      ..sort((left, right) => left.key.compareTo(right.key));
    return entries
        .map(
          (entry) => ' ${entry.key}="${attributeEscape.convert(entry.value)}"',
        )
        .join();
  }

  static bool _isSafeIdentifier(String value) {
    if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_-]{0,63}$').hasMatch(value)) {
      return false;
    }
    if (RegExp(r'\d{3,}').hasMatch(value)) return false;
    final lower = value.toLowerCase();
    return !lower.contains('password') &&
        !lower.contains('passwd') &&
        !lower.contains('account') &&
        !lower.contains('studentid') &&
        !lower.contains('userid') &&
        !lower.contains('cookie') &&
        !lower.contains('token');
  }

  static bool _isSafeAttributeIdentifier(String value) {
    return RegExp(r'^data-[a-z][a-z0-9_-]{0,48}$').hasMatch(value) &&
        !RegExp(r'\d{3,}').hasMatch(value);
  }

  static String _dataAttributePlaceholder(String name) {
    const placeholders = {
      'data-name': '课程名称',
      'data-teacher': '教师',
      'data-room': '教室',
      'data-weeks': '周次',
      'data-period': '节次',
      'data-day': '星期',
      'data-weekday': '星期',
      'data-note': '备注',
    };
    return placeholders[name] ?? '已脱敏';
  }

  static String _sanitizeText(String rawText) {
    final text = rawText.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isEmpty) return '';

    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日', '周天'];
    for (final weekday in weekdays) {
      if (text.contains(weekday)) return weekday;
    }
    if (RegExp(r'任课教师|任课老师|教师|老师').hasMatch(text)) return '教师';
    if (RegExp(r'上课地点|教室|地点').hasMatch(text)) return '教室';
    if (RegExp(r'上课周次|周次|周数').hasMatch(text)) return '周次';
    if (RegExp(r'上课节次|节次|节/周').hasMatch(text)) return '节次';
    if (RegExp(r'\d+\s*[-~—－至,，、]?\s*\d*\s*周').hasMatch(text)) {
      return '1-2周';
    }
    if (RegExp(r'\d+\s*[-~—－至]?\s*\d*\s*节').hasMatch(text)) {
      return '1-2节';
    }
    return '文本';
  }
}

class _LimitedElementTraversal {
  const _LimitedElementTraversal(this.elements, this.truncated);

  final List<Element> elements;
  final bool truncated;
}

class _SanitizerBudget {
  _SanitizerBudget(this.remaining);

  int remaining;
  bool truncated = false;
  bool markerWritten = false;
}
