import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class DefaultWebView extends StatefulWidget {
  const DefaultWebView({required this.url, super.key});
  final String url;

  // Static route method
  static Route<dynamic> route(String url) {
    return MaterialPageRoute<dynamic>(
      builder: (_) => DefaultWebView(url: url),
    );
  }

  @override
  State<DefaultWebView> createState() => _DefaultWebViewState();
}

class _DefaultWebViewState extends State<DefaultWebView> {
  late final WebViewController _controller;
  late String domainName;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(widget.url));

    domainName = extractDomain(widget.url);
  }

  String extractDomain(String url) {
    final regex = RegExp(r'https?:\/\/(?:www\.)?([^\/]+)');
    final match = regex.firstMatch(url);
    return match != null ? match.group(1)! : url;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Zicta Tariff Comparator',
              style: TextStyle(
                fontSize: 10,
              ),
            ),
            Text(
              domainName,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
