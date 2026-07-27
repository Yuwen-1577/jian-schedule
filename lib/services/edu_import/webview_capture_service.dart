import 'dart:convert';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'edu_import_models.dart';

class WebViewCaptureService {
  static const String _captureScript = r'''
    (function () {
      const documents = [];
      let blockedCrossOriginFrameCount = 0;

      function capture(currentDocument, frameDepth) {
        documents.push({
          html: currentDocument.documentElement.outerHTML,
          frameDepth: frameDepth
        });
        const frames = currentDocument.querySelectorAll('iframe, frame');
        for (const frame of frames) {
          try {
            const childDocument = frame.contentDocument;
            if (!childDocument || !childDocument.documentElement) {
              blockedCrossOriginFrameCount += 1;
              continue;
            }
            capture(childDocument, frameDepth + 1);
          } catch (_) {
            blockedCrossOriginFrameCount += 1;
          }
        }
      }

      capture(document, 0);
      return JSON.stringify({
        documents: documents,
        blockedCrossOriginFrameCount: blockedCrossOriginFrameCount
      });
    })();
  ''';

  static Future<CapturedPageBundle> capture(
    InAppWebViewController controller,
  ) async {
    final raw = await controller.evaluateJavascript(source: _captureScript);
    if (raw == null) {
      throw const FormatException('网页没有返回可解析内容');
    }
    final decoded = jsonDecode(raw.toString());
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('网页内容格式不受支持');
    }
    final rawDocuments = decoded['documents'];
    if (rawDocuments is! List || rawDocuments.isEmpty) {
      throw const FormatException('当前页面没有可读取的文档');
    }

    final documents = rawDocuments
        .whereType<Map>()
        .map(
          (item) => CapturedPageDocument(
            html: item['html']?.toString() ?? '',
            frameDepth: (item['frameDepth'] as num?)?.toInt() ?? 0,
          ),
        )
        .where((document) => document.html.isNotEmpty)
        .toList(growable: false);
    if (documents.isEmpty) {
      throw const FormatException('当前页面没有可读取的文档');
    }
    return CapturedPageBundle(
      documents: documents,
      blockedCrossOriginFrameCount:
          (decoded['blockedCrossOriginFrameCount'] as num?)?.toInt() ?? 0,
    );
  }
}
