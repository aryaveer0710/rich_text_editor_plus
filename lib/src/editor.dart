import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'controller.dart';
import 'theme.dart';
import 'toolbar.dart';
import 'toolbar_config.dart';

// Conditional import: picks the right platform files
import 'platform/platform_editor.dart' if (dart.library.html) 'platform/platform_editor_web.dart';

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
  final Future<LinkDialogResult?> Function(BuildContext context, String? currentUrl)? onLinkDialog;

  /// Optional custom toolbar widget. When provided, this widget is rendered
  /// in the toolbar position instead of the default [RichEditorToolbar].
  /// Set [showToolbar] to false to hide the toolbar entirely.
  final Widget? toolbar;

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
    this.toolbar,
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

  Future<LinkDialogResult?> _showDefaultLinkDialog(BuildContext context, String? currentUrl) async {
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
                child: const Text('Remove Link', style: TextStyle(color: Colors.red)),
              ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(
                LinkDialogResult(
                  url: urlController.text,
                  text: textController.text.isNotEmpty ? textController.text : null,
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
    final toolbar = !widget.showToolbar
        ? null
        : widget.toolbar ??
            RichEditorToolbar(
              controller: widget.controller,
              theme: widget.theme,
              config: widget.toolbarConfig,
              onLinkDialog: widget.onLinkDialog,
            );

    final divider = widget.theme.showToolbarDivider && widget.showToolbar ? Divider(height: 1, thickness: 1, color: widget.theme.dividerColor) : null;

    final editor = _buildPlatformEditor();

    return Container(
      decoration: BoxDecoration(
        borderRadius: widget.theme.borderRadius,
        border: widget.theme.border ?? Border.all(color: widget.theme.dividerColor, width: 1),
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
