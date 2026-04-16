# Rich Text Editor Plugin — Part 4 of 5: Platform Editors & Main Widget

## Context

Parts 1-3 created models, theme, JS bridge, controller, and toolbar. Now we build the platform-specific editor widgets (mobile WebView + web iframe) and the main `RichTextEditor` widget that composes everything together.

---

## Step 1: `lib/src/platform/mobile_editor.dart` — WebView (Android/iOS)

```dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../controller.dart';
import '../js/editor_html.dart';
import '../theme.dart';
import 'editor_platform.dart';

/// Mobile (Android/iOS) editor implementation using webview_flutter.
class MobileEditor extends EditorPlatform {
  const MobileEditor({
    super.key,
    required super.controller,
    required super.theme,
    super.height,
  });

  @override
  State<MobileEditor> createState() => _MobileEditorState();
}

class _MobileEditorState extends State<MobileEditor> {
  late final WebViewController _webViewController;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(widget.theme.editorBackground)
      ..addJavaScriptChannel(
        'flutter_channel',
        onMessageReceived: (JavaScriptMessage message) {
          widget.controller.handleMessage(message.message);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (!_isInitialized) {
              _isInitialized = true;
              // Wire up JS evaluation so the controller can call into JS
              widget.controller.evaluateJavascript = (String js) async {
                try {
                  final result = await _webViewController
                      .runJavaScriptReturningResult(js);
                  return result?.toString();
                } catch (e) {
                  debugPrint('JS eval error: $e');
                  return null;
                }
              };
            }
          },
          // Prevent navigation away from the editor
          onNavigationRequest: (NavigationRequest request) {
            if (request.url.startsWith('data:') ||
                request.url == 'about:blank') {
              return NavigationDecision.navigate;
            }
            // External links: prevent navigation.
            // You could open them externally via url_launcher here.
            return NavigationDecision.prevent;
          },
        ),
      );

    // Load the editor HTML as a data URI
    final html = generateEditorHtml(widget.theme);
    final dataUri = Uri.dataFromString(
      html,
      mimeType: 'text/html',
      encoding: Encoding.getByName('utf-8'),
    ).toString();
    _webViewController.loadRequest(Uri.parse(dataUri));
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height ?? 300,
      child: WebViewWidget(controller: _webViewController),
    );
  }
}
```

---

## Step 2: `lib/src/platform/web_editor.dart` — HtmlElementView (Flutter Web)

**IMPORTANT:** This file uses `dart:html` and `dart:ui_web` which only exist on Flutter Web. It must ONLY be imported on web. We handle this with conditional imports (see Step 4).

```dart
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

import '../controller.dart';
import '../js/editor_html.dart';
import '../theme.dart';
import 'editor_platform.dart';

/// Web editor implementation using an iframe rendered via HtmlElementView.
///
/// More efficient than WebView on web since there's no WebView overhead —
/// it's a direct iframe in the browser.
class WebEditor extends EditorPlatform {
  const WebEditor({
    super.key,
    required super.controller,
    required super.theme,
    super.height,
  });

  @override
  State<WebEditor> createState() => _WebEditorState();
}

class _WebEditorState extends State<WebEditor> {
  late final String _viewType;
  html.IFrameElement? _iframe;
  StreamSubscription? _messageSubscription;

  @override
  void initState() {
    super.initState();
    _viewType = 'rich-editor-${DateTime.now().millisecondsSinceEpoch}';
    _registerView();
    _listenForMessages();
  }

  void _registerView() {
    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      _iframe = html.IFrameElement()
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..srcdoc = generateEditorHtml(widget.theme);

      // Wire up JS evaluation via the iframe's contentWindow
      widget.controller.evaluateJavascript = (String js) async {
        try {
          final result = _iframe?.contentWindow?.callMethod(
            'eval' as dynamic,
            [js] as List<dynamic>,
          );
          return result?.toString();
        } catch (e) {
          // eval may fail for void expressions; that's expected
          return null;
        }
      };

      return _iframe!;
    });
  }

  void _listenForMessages() {
    _messageSubscription = html.window.onMessage.listen((event) {
      try {
        final data = event.data;
        if (data is String) {
          final decoded = jsonDecode(data);
          if (decoded is Map && decoded.containsKey('type')) {
            widget.controller.handleMessage(data);
          }
        }
      } catch (_) {
        // Ignore non-JSON messages from other sources
      }
    });
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height ?? 300,
      child: HtmlElementView(viewType: _viewType),
    );
  }
}
```

---

## Step 3: `lib/src/platform/web_editor_stub.dart` — Stub for Non-Web

This stub is imported on Android/iOS so the code compiles without `dart:html`.

```dart
import 'package:flutter/material.dart';

import '../controller.dart';
import '../theme.dart';
import 'editor_platform.dart';

/// Stub for web editor on non-web platforms.
/// Never actually instantiated on mobile — MobileEditor is used instead.
class WebEditor extends EditorPlatform {
  const WebEditor({
    super.key,
    required super.controller,
    required super.theme,
    super.height,
  });

  @override
  State<WebEditor> createState() => _WebEditorStubState();
}

class _WebEditorStubState extends State<WebEditor> {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Web editor is not supported on this platform.'),
    );
  }
}
```

---

## Step 4: Conditional Import Files

Create two small files that enable platform-conditional imports:

### `lib/src/platform/platform_editor.dart` (default — used on mobile)

```dart
export 'mobile_editor.dart';
export 'web_editor_stub.dart';
```

### `lib/src/platform/platform_editor_web.dart` (used on web only)

```dart
export 'mobile_editor.dart';
export 'web_editor.dart';
```

---

## Step 5: `lib/src/editor.dart` — Main RichTextEditor Widget

This is the public-facing widget that users of your plugin will use.

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'controller.dart';
import 'models/content.dart';
import 'theme.dart';
import 'toolbar.dart';
import 'toolbar_config.dart';

// Conditional import: picks the right platform files
import 'platform/platform_editor.dart'
    if (dart.library.html) 'platform/platform_editor_web.dart';

/// A rich text editor widget with a customizable toolbar.
///
/// Uses a browser-based contenteditable editor under the hood (WebView on
/// mobile, iframe on web) with a pure Flutter toolbar on top.
///
/// Basic usage:
/// ```dart
/// final controller = RichEditorController();
///
/// RichTextEditor(
///   controller: controller,
///   onChanged: (content) {
///     print(content.html);
///     print(content.plainText);
///   },
/// )
/// ```
class RichTextEditor extends StatefulWidget {
  /// Controller for the editor. Create with [RichEditorController].
  final RichEditorController controller;

  /// Theme for the editor appearance.
  final RichEditorTheme theme;

  /// Toolbar configuration — which buttons to show.
  final ToolbarConfig toolbarConfig;

  /// Called when the editor content changes.
  final ContentChangedCallback? onChanged;

  /// Called when the editor gains focus.
  final VoidCallback? onFocus;

  /// Called when the editor loses focus.
  final VoidCallback? onBlur;

  /// Height of the editor area (not including toolbar).
  /// Defaults to 300 if not specified.
  final double? editorHeight;

  /// Whether to show the toolbar.
  final bool showToolbar;

  /// Whether to place the toolbar at the top (true) or bottom (false).
  final bool toolbarAtTop;

  /// Custom link dialog builder. If null, a default Material dialog is shown.
  final Future<LinkDialogResult?> Function(
      BuildContext context, String? currentUrl)? onLinkDialog;

  const RichTextEditor({
    super.key,
    required this.controller,
    this.theme = const RichEditorTheme(),
    this.toolbarConfig = ToolbarConfig.standard,
    this.onChanged,
    this.onFocus,
    this.onBlur,
    this.editorHeight,
    this.showToolbar = true,
    this.toolbarAtTop = true,
    this.onLinkDialog,
  });

  @override
  State<RichTextEditor> createState() => _RichTextEditorState();
}

class _RichTextEditorState extends State<RichTextEditor> {
  bool _wasFocused = false;

  @override
  void initState() {
    super.initState();
    _wireController();
  }

  @override
  void didUpdateWidget(covariant RichTextEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _unwireController(oldWidget.controller);
      _wireController();
    }
    if (oldWidget.onChanged != widget.onChanged) {
      widget.controller.onContentChanged = widget.onChanged;
    }
  }

  @override
  void dispose() {
    _unwireController(widget.controller);
    super.dispose();
  }

  void _wireController() {
    widget.controller.onContentChanged = widget.onChanged;
    widget.controller.onLinkRequest = _handleLinkRequest;
    widget.controller.addListener(_onControllerChanged);
  }

  void _unwireController(RichEditorController controller) {
    controller.removeListener(_onControllerChanged);
    controller.onContentChanged = null;
    controller.onLinkRequest = null;
  }

  void _onControllerChanged() {
    final focused = widget.controller.hasFocus;
    if (focused && !_wasFocused) {
      widget.onFocus?.call();
    } else if (!focused && _wasFocused) {
      widget.onBlur?.call();
    }
    _wasFocused = focused;
  }

  void _handleLinkRequest() {
    if (!mounted) return;

    final currentUrl = widget.controller.selectionStyle.linkUrl;

    // Show the link dialog directly — do NOT go through
    // controller.handleToolbarAction('link') as that would
    // call onLinkRequest again (infinite recursion).
    Future<LinkDialogResult?> dialogFuture;
    if (widget.onLinkDialog != null) {
      dialogFuture = widget.onLinkDialog!(context, currentUrl);
    } else {
      dialogFuture = _showDefaultLinkDialog(context, currentUrl);
    }

    dialogFuture.then((result) {
      if (result == null) return;
      if (result.shouldRemove) {
        widget.controller.removeLink();
      } else if (result.url != null && result.url!.isNotEmpty) {
        widget.controller.insertLink(result.url!, result.text);
      }
    });
  }

  Future<LinkDialogResult?> _showDefaultLinkDialog(
      BuildContext context, String? currentUrl) async {
    final urlController = TextEditingController(text: currentUrl ?? '');
    final textController = TextEditingController();

    return showDialog<LinkDialogResult>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(currentUrl != null ? 'Edit Link' : 'Insert Link'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: urlController,
                decoration: const InputDecoration(
                  labelText: 'URL',
                  hintText: 'https://example.com',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.url,
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textController,
                decoration: const InputDecoration(
                  labelText: 'Text (optional)',
                  hintText: 'Display text',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            if (currentUrl != null)
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(
                  LinkDialogResult(shouldRemove: true),
                ),
                child: const Text('Remove Link',
                    style: TextStyle(color: Colors.red)),
              ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(
                LinkDialogResult(
                  url: urlController.text,
                  text: textController.text.isNotEmpty
                      ? textController.text
                      : null,
                ),
              ),
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final toolbar = widget.showToolbar
        ? RichEditorToolbar(
            controller: widget.controller,
            theme: widget.theme,
            config: widget.toolbarConfig,
            onLinkDialog: widget.onLinkDialog,
          )
        : null;

    final divider = widget.theme.showToolbarDivider && widget.showToolbar
        ? Divider(height: 1, thickness: 1, color: widget.theme.dividerColor)
        : null;

    final editor = _buildPlatformEditor();

    return Container(
      decoration: BoxDecoration(
        borderRadius: widget.theme.borderRadius,
        border: widget.theme.border ??
            Border.all(color: widget.theme.dividerColor, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: widget.toolbarAtTop
            ? [
                if (toolbar != null) toolbar,
                if (divider != null) divider,
                Flexible(child: editor),
              ]
            : [
                Flexible(child: editor),
                if (divider != null) divider,
                if (toolbar != null) toolbar,
              ],
      ),
    );
  }

  Widget _buildPlatformEditor() {
    if (kIsWeb) {
      return WebEditor(
        controller: widget.controller,
        theme: widget.theme,
        height: widget.editorHeight,
      );
    }

    return MobileEditor(
      controller: widget.controller,
      theme: widget.theme,
      height: widget.editorHeight,
    );
  }
}
```

---

## Checkpoint

After completing Part 4 you should have these new files:

- ✅ `lib/src/platform/mobile_editor.dart`
- ✅ `lib/src/platform/web_editor.dart`
- ✅ `lib/src/platform/web_editor_stub.dart`
- ✅ `lib/src/platform/platform_editor.dart`
- ✅ `lib/src/platform/platform_editor_web.dart`
- ✅ `lib/src/editor.dart`

At this point, the plugin itself is complete. All files referenced in the barrel export (`lib/rich_text_editor_plus.dart`) now exist. You should be able to run `flutter pub get` in the root directory without errors.

**Proceed to Part 5 to create the example app and see the editor in action.**
