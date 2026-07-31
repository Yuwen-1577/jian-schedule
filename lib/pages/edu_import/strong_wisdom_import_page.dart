import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';

import '../../providers/schedule_provider.dart';
import '../../services/edu_import/edu_import_diagnostic_export_service.dart';
import '../../services/edu_import/edu_import_diagnostics.dart';
import '../../services/edu_import/strong_wisdom_parser.dart';
import '../../services/edu_import/webview_capture_service.dart';
import 'edu_import_diagnostic_dialog.dart';
import 'edu_import_preview_page.dart';

class StrongWisdomImportPage extends StatefulWidget {
  const StrongWisdomImportPage({super.key, this.diagnosticExporter});

  final EduImportDiagnosticExportCallback? diagnosticExporter;

  @override
  State<StrongWisdomImportPage> createState() => _StrongWisdomImportPageState();
}

class _StrongWisdomImportPageState extends State<StrongWisdomImportPage> {
  final _urlController = TextEditingController();
  final _httpAllowedHosts = <String>{};
  InAppWebViewController? _webViewController;
  double _progress = 0;
  bool _isLoadingPage = false;
  bool _isCapturing = false;
  bool _isExportingDiagnostics = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    unawaited(_clearSessionData());
  }

  @override
  void dispose() {
    _urlController.dispose();
    unawaited(_clearSessionData());
    super.dispose();
  }

  Future<void> _clearSessionData() async {
    try {
      await CookieManager.instance().deleteAllCookies();
      await WebStorageManager.instance().deleteAllData();
      await InAppWebViewController.clearAllCache();
    } catch (_) {
      // 清理属于尽力而为流程，不记录网页或会话细节。
    }
  }

  Future<Uri?> _normalizeUrl(String raw) async {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      _showMessage('请先输入教务系统网址');
      return null;
    }

    Uri uri;
    try {
      uri = Uri.parse(trimmed.contains('://') ? trimmed : 'https://$trimmed');
    } on FormatException {
      _showMessage('网址格式不正确');
      return null;
    }
    if (!uri.hasAuthority || (uri.scheme != 'https' && uri.scheme != 'http')) {
      _showMessage('请输入 HTTP 或 HTTPS 网址');
      return null;
    }
    if (uri.scheme == 'http' && !await _allowHttpHost(uri)) return null;
    return uri;
  }

  Future<bool> _allowHttpHost(Uri uri) async {
    if (!kDebugMode) {
      _showMessage('正式版本不允许访问未加密的 HTTP 页面');
      return false;
    }
    final host = uri.host.toLowerCase();
    if (_httpAllowedHosts.contains(host)) return true;
    final allowed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('访问未加密页面？'),
        content: Text(
          '“$host”使用 HTTP，登录内容可能被同一网络中的其他人看到。'
          '\n\n只在你确认这是学校官方地址且网络可信时继续。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('本次继续'),
          ),
        ],
      ),
    );
    if (allowed == true) _httpAllowedHosts.add(host);
    return allowed == true;
  }

  Future<void> _openTypedUrl() async {
    final uri = await _normalizeUrl(_urlController.text);
    if (uri == null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _loadError = null);
    await _webViewController?.loadUrl(
      urlRequest: URLRequest(url: WebUri(uri.toString())),
    );
  }

  Future<EduImportParseResult> _captureAndParse(
    InAppWebViewController controller,
  ) async {
    final bundle = await WebViewCaptureService.capture(controller);
    return StrongWisdomParser.parseDetailed(bundle);
  }

  Future<void> _exportDiagnostics(EduImportDiagnostics diagnostics) async {
    if (_isExportingDiagnostics) return;
    setState(() => _isExportingDiagnostics = true);
    try {
      final exporter =
          widget.diagnosticExporter ??
          EduImportDiagnosticExportService.platform().save;
      await exportEduImportDiagnostics(
        context: context,
        diagnostics: diagnostics,
        exporter: exporter,
      );
    } finally {
      if (mounted) setState(() => _isExportingDiagnostics = false);
    }
  }

  Future<void> _captureAndPreview() async {
    final controller = _webViewController;
    if (controller == null || _isCapturing) return;
    setState(() => _isCapturing = true);

    try {
      final parseResult = await _captureAndParse(controller);
      final batch = parseResult.batch;
      if (!mounted) return;
      if (batch.drafts.isEmpty) {
        final shouldExport = await _showNoCoursesDialog();
        if (shouldExport && mounted) {
          await _exportDiagnostics(parseResult.diagnostics);
        }
        return;
      }

      final provider = context.read<ScheduleProvider>();
      final mode = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EduImportPreviewPage(
            batch: batch,
            diagnostics: parseResult.diagnostics,
            onExportDiagnostics: _exportDiagnostics,
            existingCourses: provider.courses,
            scheduleSetName: provider.activeSet?.name ?? '当前课表',
          ),
        ),
      );
      if (mode == null || !mounted) return;

      final result = await provider.commitEduImport(batch, mode);
      if (!mounted) return;
      final message = result.insertedCount == 0
          ? '没有写入新课程；已跳过 ${result.skippedCount} 项'
          : '已写入 ${result.insertedCount} 门课程'
                '${result.skippedCount > 0 ? '，跳过 ${result.skippedCount} 项' : ''}';
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (mounted) {
        _showMessage('读取失败。请确认已进入课表页面后重试');
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  Future<bool> _showNoCoursesDialog() {
    return showNoEduImportCoursesDialog(context);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('从强智教务导入'),
        bottom: _isLoadingPage
            ? PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: LinearProgressIndicator(
                  value: _progress == 0 ? null : _progress,
                ),
              )
            : null,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _urlController,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.go,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: '教务系统网址',
                      hintText: '例如：学校教务系统域名',
                      helperText: '网址、账号和网页内容不会保存或上传',
                      prefixIcon: const Icon(Icons.language),
                      suffixIcon: IconButton(
                        tooltip: '打开网址',
                        onPressed: _openTypedUrl,
                        icon: const Icon(Icons.arrow_forward),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _openTypedUrl(),
                  ),
                  if (_loadError != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 18,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _loadError!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _openTypedUrl,
                          child: const Text('重试'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  InAppWebView(
                    initialSettings: InAppWebViewSettings(
                      incognito: true,
                      cacheEnabled: false,
                      clearCache: true,
                      thirdPartyCookiesEnabled: true,
                      useShouldOverrideUrlLoading: true,
                    ),
                    onWebViewCreated: (controller) {
                      _webViewController = controller;
                    },
                    shouldOverrideUrlLoading:
                        (controller, navigationAction) async {
                          final uri = navigationAction.request.url;
                          if (uri == null || uri.scheme != 'http') {
                            return NavigationActionPolicy.ALLOW;
                          }
                          final allowed = await _allowHttpHost(
                            Uri.parse(uri.toString()),
                          );
                          return allowed
                              ? NavigationActionPolicy.ALLOW
                              : NavigationActionPolicy.CANCEL;
                        },
                    onLoadStart: (controller, url) {
                      if (!mounted) return;
                      setState(() {
                        _isLoadingPage = true;
                        _progress = 0;
                        _loadError = null;
                      });
                    },
                    onProgressChanged: (controller, progress) {
                      if (!mounted) return;
                      setState(() => _progress = progress / 100);
                    },
                    onLoadStop: (controller, url) {
                      if (!mounted) return;
                      setState(() {
                        _isLoadingPage = false;
                        _progress = 1;
                      });
                    },
                    onReceivedError: (controller, request, error) {
                      if (request.isForMainFrame != true || !mounted) return;
                      setState(() {
                        _isLoadingPage = false;
                        _loadError = '页面加载失败，请检查网址和网络后重试';
                      });
                    },
                  ),
                  if (_urlController.text.trim().isEmpty && !_isLoadingPage)
                    IgnorePointer(
                      child: ColoredBox(
                        color: theme.colorScheme.surface,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.login,
                                  size: 40,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  '输入网址并手动登录',
                                  style: theme.textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '登录后进入课表页面，再点击下方按钮进行本地解析。',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed:
                _isLoadingPage || _isCapturing || _urlController.text.isEmpty
                ? null
                : _captureAndPreview,
            icon: _isCapturing
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.document_scanner_outlined),
            label: Text(_isCapturing ? '正在本地解析…' : '我已打开课表，开始解析'),
          ),
        ),
      ),
    );
  }
}
