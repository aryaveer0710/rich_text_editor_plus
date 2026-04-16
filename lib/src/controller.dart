import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'models/content.dart';
import 'models/selection_style.dart';

/// Callback type for content changes.
typedef ContentChangedCallback = void Function(EditorContent content);

/// Callback type for requesting a link dialog (triggered by Ctrl+K).
typedef LinkRequestCallback = void Function();

/// Controller for the Rich Text Editor.
///
/// Manages communication between the Flutter UI and the JS-based editor.
/// Maintains the current content and selection style state.
///
/// Usage:
/// ```dart
/// final controller = RichEditorController(
///   initialHtml: '<p>Hello <b>world</b></p>',
/// );
/// controller.execCommand('bold');
/// print(controller.getHtml());
/// ```
class RichEditorController extends ChangeNotifier {
  /// Current content of the editor.
  EditorContent _content = EditorContent.empty;
  EditorContent get content => _content;

  /// Current selection style at the cursor.
  SelectionStyle _selectionStyle = SelectionStyle.none;
  SelectionStyle get selectionStyle => _selectionStyle;

  /// Whether the editor has focus.
  bool _hasFocus = false;
  bool get hasFocus => _hasFocus;

  /// Whether the JS editor is ready.
  bool _isReady = false;
  bool get isReady => _isReady;

  /// Callback for content changes.
  ContentChangedCallback? onContentChanged;

  /// Callback when Ctrl+K requests a link dialog.
  LinkRequestCallback? onLinkRequest;

  /// Queue of commands to execute once JS is ready.
  final List<String> _commandQueue = [];

  /// Function to evaluate JavaScript. Set by the platform editor widget.
  Future<String?> Function(String js)? evaluateJavascript;

  /// Optional initial HTML content to load when the editor is ready.
  String? initialHtml;

  RichEditorController({this.initialHtml});

  // -----------------------------------------------------------------------
  // Handle messages from JS
  // -----------------------------------------------------------------------

  /// Process a message received from the JS editor bridge.
  void handleMessage(String messageJson) {
    try {
      final data = jsonDecode(messageJson) as Map<String, dynamic>;
      final type = data['type'] as String?;

      switch (type) {
        case 'contentChanged':
          _content = EditorContent(
            html: data['html'] as String? ?? '',
            plainText: data['plainText'] as String? ?? '',
          );
          onContentChanged?.call(_content);
          notifyListeners();
          break;

        case 'selectionStyle':
          _selectionStyle = SelectionStyle.fromJson(data);
          notifyListeners();
          break;

        case 'ready':
          _isReady = true;
          if (initialHtml != null && initialHtml!.isNotEmpty) {
            _executeJs("window.editorBridge.setHtml(${jsonEncode(initialHtml)})");
          }
          // Flush queued commands
          for (final js in _commandQueue) {
            _executeJs(js);
          }
          _commandQueue.clear();
          notifyListeners();
          break;

        case 'focus':
          _hasFocus = true;
          notifyListeners();
          break;

        case 'blur':
          _hasFocus = false;
          notifyListeners();
          break;

        case 'linkRequest':
          onLinkRequest?.call();
          break;

        default:
          debugPrint('RichEditorController: unknown message type: $type');
      }
    } catch (e) {
      debugPrint('RichEditorController: error handling message: $e');
    }
  }

  // -----------------------------------------------------------------------
  // Public API: Commands to JS
  // -----------------------------------------------------------------------

  /// Execute a formatting command (bold, italic, insertOrderedList, etc.).
  void execCommand(String command, [String? value]) {
    if (value != null) {
      _executeJs("window.editorBridge.execCommand('$command', ${jsonEncode(value)})");
    } else {
      _executeJs("window.editorBridge.execCommand('$command')");
    }
  }

  /// Set the editor's HTML content, replacing everything.
  void setHtml(String html) {
    _executeJs("window.editorBridge.setHtml(${jsonEncode(html)})");
  }

  /// Get the current HTML content (cached, synchronous).
  String getHtml() => _content.html;

  /// Get the current HTML content directly from JS (async, most up-to-date).
  Future<String> getHtmlAsync() async {
    final result = await _executeJsWithResult("window.editorBridge.getHtml()");
    return result ?? _content.html;
  }

  /// Get the current plain text content (cached, synchronous).
  String getPlainText() => _content.plainText;

  /// Get the current plain text content directly from JS (async).
  Future<String> getPlainTextAsync() async {
    final result = await _executeJsWithResult("window.editorBridge.getPlainText()");
    return result ?? _content.plainText;
  }

  /// Insert a link. If text is selected, wraps it. Otherwise inserts new linked text.
  void insertLink(String url, [String? text]) {
    if (text != null) {
      _executeJs("window.editorBridge.insertLink(${jsonEncode(url)}, ${jsonEncode(text)})");
    } else {
      _executeJs("window.editorBridge.insertLink(${jsonEncode(url)})");
    }
  }

  /// Remove the link at the current cursor position.
  void removeLink() {
    _executeJs("window.editorBridge.removeLink()");
  }

  /// Insert HTML at the current cursor position.
  void insertHtml(String html) {
    _executeJs("window.editorBridge.insertHtml(${jsonEncode(html)})");
  }

  /// Set text alignment for the current block.
  void setAlignment(String alignment) {
    _executeJs("window.editorBridge.setAlignment(${jsonEncode(alignment)})");
  }

  /// Clear all content.
  void clear() {
    _executeJs("window.editorBridge.clear()");
  }

  /// Focus the editor.
  void focus() {
    _executeJs("window.editorBridge.focus()");
  }

  /// Blur the editor.
  void blur() {
    _executeJs("window.editorBridge.blur()");
  }

  // -----------------------------------------------------------------------
  // Toolbar action dispatch
  // -----------------------------------------------------------------------

  /// Handle a toolbar action by name. Maps action names to JS commands.
  void handleToolbarAction(String action) {
    switch (action) {
      case 'bold':
        execCommand('bold');
        break;
      case 'italic':
        execCommand('italic');
        break;
      case 'underline':
        execCommand('underline');
        break;
      case 'strikethrough':
        execCommand('strikeThrough');
        break;
      case 'orderedList':
        execCommand('insertOrderedList');
        break;
      case 'unorderedList':
        execCommand('insertUnorderedList');
        break;
      case 'indent':
        execCommand('indent');
        break;
      case 'outdent':
        execCommand('outdent');
        break;
      case 'alignLeft':
        setAlignment('left');
        break;
      case 'alignCenter':
        setAlignment('center');
        break;
      case 'alignRight':
        setAlignment('right');
        break;
      case 'alignJustify':
        setAlignment('justify');
        break;
      case 'undo':
        execCommand('undo');
        break;
      case 'redo':
        execCommand('redo');
        break;
      case 'clearFormatting':
        execCommand('removeFormat');
        break;
      case 'link':
        onLinkRequest?.call();
        break;
      default:
        debugPrint('RichEditorController: unknown action: $action');
    }
  }

  // -----------------------------------------------------------------------
  // Internal
  // -----------------------------------------------------------------------

  void _executeJs(String js) {
    if (_isReady && evaluateJavascript != null) {
      evaluateJavascript!(js);
    } else {
      _commandQueue.add(js);
    }
  }

  Future<String?> _executeJsWithResult(String js) async {
    if (evaluateJavascript != null) {
      return evaluateJavascript!(js);
    }
    return null;
  }

  @override
  void dispose() {
    _commandQueue.clear();
    super.dispose();
  }
}
