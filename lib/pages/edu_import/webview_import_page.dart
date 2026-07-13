import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';
import '../../providers/schedule_provider.dart';
import '../../services/edu_import/webview_html_parser.dart';

class WebviewImportPage extends StatefulWidget {
  const WebviewImportPage({super.key});

  @override
  State<WebviewImportPage> createState() => _WebviewImportPageState();
}

class _WebviewImportPageState extends State<WebviewImportPage> {
  InAppWebViewController? webViewController;
  final urlController = TextEditingController(
    text: 'http://jwgl.example.edu.cn',
  );
  double progress = 0;

  @override
  void dispose() {
    urlController.dispose();
    super.dispose();
  }

  Future<void> _extractHtml() async {
    if (webViewController == null) return;

    // 注入一段 JS 提取主页面及所有可能 iframe 中的 HTML
    const jsCode = '''
      (function() {
        let html = document.documentElement.outerHTML;
        let iframes = document.querySelectorAll('iframe');
        for (let i = 0; i < iframes.length; i++) {
          try {
            if (iframes[i].contentWindow && iframes[i].contentWindow.document) {
              html += iframes[i].contentWindow.document.documentElement.outerHTML;
            }
          } catch(e) {
            // 跨域 iframe 无法访问，忽略
          }
        }
        return html;
      })();
    ''';
    final html = await webViewController!.evaluateJavascript(source: jsCode);

    if (html == null || html.toString().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('获取网页内容失败')));
      }
      return;
    }

    if (!mounted) return;

    // 解析课表（目前只提供框架，如果 HTML 中包含明显的课表特征则解析）
    try {
      final courses = WebViewHtmlParser.parseHtml(html.toString());
      if (courses.isEmpty) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('提取失败'),
            content: const Text(
              '未在当前页面中找到课表数据。\n请确保您已经登录并导航到了“我的课表”或“班级课表”页面。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('好的'),
              ),
            ],
          ),
        );
        return;
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('成功获取课表'),
          content: Text('共获取到 ${courses.length} 门课程，是否导入当前课表集？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('导入'),
            ),
          ],
        ),
      );

      if (confirmed == true && mounted) {
        final provider = context.read<ScheduleProvider>();
        final importedCount = await provider.importCoursesToActiveSet(courses);
        if (mounted) {
          final messenger = ScaffoldMessenger.of(context);
          Navigator.pop(context); // 返回上一页
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                importedCount == 0
                    ? '没有发现新课程，已跳过重复数据'
                    : '成功导入 $importedCount 门课程！',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('解析出错: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('网页抓取课表'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4.0),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.transparent,
            valueColor: AlwaysStoppedAnimation<Color>(
              progress == 1.0 ? Colors.transparent : Colors.blue,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: urlController,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      hintText: '输入教务系统网址',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (value) {
                      var url = Uri.parse(value);
                      if (url.scheme.isEmpty) {
                        url = Uri.parse("http://$value");
                      }
                      webViewController?.loadUrl(
                        urlRequest: URLRequest(url: WebUri(url.toString())),
                      );
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: () {
                    var url = Uri.parse(urlController.text);
                    if (url.scheme.isEmpty) {
                      url = Uri.parse("http://${urlController.text}");
                    }
                    webViewController?.loadUrl(
                      urlRequest: URLRequest(url: WebUri(url.toString())),
                    );
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(urlController.text)),
              onWebViewCreated: (controller) {
                webViewController = controller;
              },
              onLoadStart: (controller, url) {
                setState(() {
                  urlController.text = url.toString();
                  progress = 0.0;
                });
              },
              onLoadStop: (controller, url) async {
                setState(() {
                  urlController.text = url.toString();
                  progress = 1.0;
                });
              },
              onProgressChanged: (controller, progress) {
                setState(() {
                  this.progress = progress / 100;
                });
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _extractHtml,
        label: const Text('我已看到课表，提取！'),
        icon: const Icon(Icons.downloading),
      ),
    );
  }
}
