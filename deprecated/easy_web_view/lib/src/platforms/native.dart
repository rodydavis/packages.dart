import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart' as wv;

import 'base.dart';

class NativeWebView extends WebView {
  const NativeWebView({
    required Key? key,
    required String src,
    required double? width,
    required double? height,
    required OnLoaded? onLoaded,
    required this.options,
  }) : super(
          key: key,
          src: src,
          width: width,
          height: height,
          onLoaded: onLoaded,
        );

  final WebViewOptions options;

  @override
  State<WebView> createState() => NativeWebViewState();
}

class EasyWebViewControllerWrapper extends EasyWebViewControllerWrapperBase {
  final wv.WebViewController _controller;

  EasyWebViewControllerWrapper._(this._controller);

  @override
  Future<void> evaluateJSMobile(String js) async {
    return await _controller.runJavaScript(js);
  }

  @override
  Future<String> evaluateJSWithResMobile(String js) async {
    final result = _controller.runJavaScriptReturningResult(js);
    return result.toString();
  }

  @override
  Object get nativeWrapper => _controller;

  @override
  void postMessageWeb(dynamic message, String targetOrigin) =>
      throw UnsupportedError("the platform doesn't support this operation");
}

class NativeWebViewState extends WebViewState<NativeWebView> {
  wv.WebViewController controller = wv.WebViewController();
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void didUpdateWidget(covariant NativeWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.src != widget.src) {
      reload();
    }
  }

  Future<void> reload() async {
    if (!_initialized) {
      _initialized = true;
      await controller.setJavaScriptMode(wv.JavaScriptMode.unrestricted);
      await controller.setNavigationDelegate(wv.NavigationDelegate(
        onNavigationRequest: (navigationRequest) async {
          if (widget.options.navigationDelegate == null) {
            return wv.NavigationDecision.navigate;
          }
          final _navDecision = await widget.options
              .navigationDelegate!(WebNavigationRequest(navigationRequest.url));
          return _navDecision == WebNavigationDecision.prevent
              ? wv.NavigationDecision.prevent
              : wv.NavigationDecision.navigate;
        },
        onPageFinished: (value) {
          if (widget.onLoaded != null) {
            widget.onLoaded!(EasyWebViewControllerWrapper._(controller));
          }
        },
      ));
      if (widget.options.crossWindowEvents.isNotEmpty) {
        for (final channel in widget.options.crossWindowEvents) {
          await controller.addJavaScriptChannel(
            channel.name,
            onMessageReceived: (javascriptMessage) {
              channel.eventAction(javascriptMessage.message);
            },
          );
        }
      }
    }
    await controller.loadRequest(Uri.parse(url));
  }

  @override
  Widget builder(BuildContext context, Size size, String contents) {
    return wv.WebViewWidget(
      key: widget.key,
      controller: controller,
    );
  }
}
