# Rich Text Editor Plugin — Part 2 of 5: JS Bridge & Controller

## Context

Part 1 created the project structure, models, theme, and toolbar config. Now we build the two core pieces:
1. **JS Bridge** — the HTML/CSS/JS that runs inside the WebView/iframe
2. **Controller** — the Dart class that communicates with the JS bridge

---

## Step 1: `lib/src/js/editor_html.dart` — The Editor HTML + JS Bridge

This is the most important file. It generates the full HTML document loaded by both WebView (mobile) and iframe (web). It contains the `contenteditable` div, styling, and all JavaScript bridge functions.

```dart
import '../theme.dart';

/// Generates the full HTML document for the contenteditable editor.
///
/// Communication protocol:
///   Flutter → JS:  evaluateJavascript calling window.editorBridge.*
///   JS → Flutter:  window.flutter_channel.postMessage(JSON.stringify({...}))
///                   On web: window.parent.postMessage(...)
///
/// Message types FROM JS to Flutter:
///   { type: 'contentChanged', html: '...', plainText: '...' }
///   { type: 'selectionStyle', bold: bool, italic: bool, ... }
///   { type: 'ready' }
///   { type: 'focus' }
///   { type: 'blur' }
///   { type: 'linkRequest' }  (when user presses Ctrl+K)
String generateEditorHtml(RichEditorTheme theme) {
  final bgColor = _colorToCss(theme.editorBackground);
  final textColor = _colorToCss(theme.editorTextColor);
  final placeholderColor = _colorToCss(theme.placeholderColor);
  final fontFamily = theme.editorFontFamily;
  final fontSize = theme.editorFontSize;
  final lineHeight = theme.editorLineHeight;
  final paddingTop = theme.editorPadding.top;
  final paddingRight = theme.editorPadding.right;
  final paddingBottom = theme.editorPadding.bottom;
  final paddingLeft = theme.editorPadding.left;
  final placeholder = _escapeHtml(theme.placeholder ?? '');

  return '''
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<style>
  * {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
  }

  html, body {
    height: 100%;
    width: 100%;
    overflow: hidden;
    background: $bgColor;
  }

  #editor {
    width: 100%;
    min-height: 100%;
    padding: ${paddingTop}px ${paddingRight}px ${paddingBottom}px ${paddingLeft}px;
    font-family: $fontFamily;
    font-size: ${fontSize}px;
    line-height: $lineHeight;
    color: $textColor;
    background: $bgColor;
    outline: none;
    overflow-y: auto;
    word-wrap: break-word;
    white-space: pre-wrap;
  }

  #editor:empty:before {
    content: attr(data-placeholder);
    color: $placeholderColor;
    pointer-events: none;
    display: block;
  }

  /* List styles */
  #editor ol, #editor ul {
    padding-left: 24px;
    margin: 4px 0;
  }

  #editor ol ol, #editor ul ul, #editor ol ul, #editor ul ol {
    margin: 2px 0;
  }

  #editor li {
    margin: 2px 0;
  }

  /* Link styles */
  #editor a {
    color: #1A73E8;
    text-decoration: underline;
    cursor: pointer;
  }

  /* Paragraph spacing */
  #editor p {
    margin: 0;
    min-height: 1em;
  }

  #editor p + p {
    margin-top: 0.4em;
  }

  /* Prevent pasted images from breaking layout */
  #editor img {
    max-width: 100%;
    height: auto;
  }
</style>
</head>
<body>
<div id="editor" contenteditable="true" data-placeholder="$placeholder" spellcheck="true"></div>

<script>
(function() {
  'use strict';

  var editor = document.getElementById('editor');
  var isComposing = false;
  var debounceTimer = null;

  // -----------------------------------------------------------------------
  // Communication: send messages to Flutter
  // -----------------------------------------------------------------------
  function sendToFlutter(data) {
    var msg = JSON.stringify(data);
    try {
      // Mobile WebView channel (Android/iOS)
      if (window.flutter_channel && window.flutter_channel.postMessage) {
        window.flutter_channel.postMessage(msg);
        return;
      }
      // Web platform: postMessage to parent frame
      if (window.parent && window.parent !== window) {
        window.parent.postMessage(msg, '*');
        return;
      }
      // Fallback: custom event
      window.dispatchEvent(new CustomEvent('editorMessage', { detail: msg }));
    } catch (e) {
      console.error('sendToFlutter error:', e);
    }
  }

  // -----------------------------------------------------------------------
  // Content reporting
  // -----------------------------------------------------------------------
  function reportContent() {
    if (debounceTimer) clearTimeout(debounceTimer);
    debounceTimer = setTimeout(function() {
      sendToFlutter({
        type: 'contentChanged',
        html: editor.innerHTML,
        plainText: getPlainText()
      });
    }, 50);
  }

  function getPlainText() {
    return domToPlainText(editor).replace(/\\n{3,}/g, '\\n\\n').trim();
  }

  function domToPlainText(node) {
    if (node.nodeType === Node.TEXT_NODE) {
      return node.textContent;
    }
    if (node.nodeType !== Node.ELEMENT_NODE) return '';

    var tag = node.tagName.toLowerCase();
    var result = '';

    // Handle list items with bullet/number prefix
    if (tag === 'li') {
      var parent = node.parentElement;
      var prefix = '';
      if (parent && parent.tagName.toLowerCase() === 'ol') {
        var index = Array.from(parent.children).indexOf(node) + 1;
        prefix = index + '. ';
      } else {
        prefix = '\\u2022 ';
      }
      // Calculate nesting depth for indentation
      var depth = 0;
      var p = node.parentElement;
      while (p && p !== editor) {
        if (p.tagName.toLowerCase() === 'ol' || p.tagName.toLowerCase() === 'ul') {
          depth++;
        }
        p = p.parentElement;
      }
      var indent = '  '.repeat(Math.max(0, depth - 1));
      var childText = '';
      for (var i = 0; i < node.childNodes.length; i++) {
        childText += domToPlainText(node.childNodes[i]);
      }
      var lines = childText.split('\\n');
      result = indent + prefix + lines[0];
      for (var j = 1; j < lines.length; j++) {
        result += '\\n' + lines[j];
      }
      result += '\\n';
      return result;
    }

    // Block-level elements get line breaks
    var isBlock = ['p', 'div', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
                   'blockquote', 'pre', 'ol', 'ul', 'table', 'hr'].indexOf(tag) >= 0;

    for (var k = 0; k < node.childNodes.length; k++) {
      result += domToPlainText(node.childNodes[k]);
    }

    if (tag === 'br') return '\\n';
    if (isBlock && result.length > 0) {
      if (tag !== 'ol' && tag !== 'ul') {
        if (!result.endsWith('\\n')) result += '\\n';
      }
    }

    return result;
  }

  // -----------------------------------------------------------------------
  // Selection style reporting
  // -----------------------------------------------------------------------
  function reportSelectionStyle() {
    var linkUrl = null;
    var sel = window.getSelection();
    if (sel && sel.rangeCount > 0) {
      var node = sel.anchorNode;
      while (node && node !== editor) {
        if (node.nodeType === Node.ELEMENT_NODE && node.tagName.toLowerCase() === 'a') {
          linkUrl = node.getAttribute('href');
          break;
        }
        node = node.parentNode;
      }
    }

    var alignment = 'left';
    if (sel && sel.rangeCount > 0) {
      var block = sel.anchorNode;
      while (block && block !== editor) {
        if (block.nodeType === Node.ELEMENT_NODE) {
          var ta = block.style.textAlign || window.getComputedStyle(block).textAlign;
          if (ta === 'center' || ta === 'right' || ta === 'justify') {
            alignment = ta;
            break;
          }
          var align = block.getAttribute('align');
          if (align) {
            alignment = align;
            break;
          }
        }
        block = block.parentNode;
      }
    }

    sendToFlutter({
      type: 'selectionStyle',
      bold: document.queryCommandState('bold'),
      italic: document.queryCommandState('italic'),
      underline: document.queryCommandState('underline'),
      strikethrough: document.queryCommandState('strikeThrough'),
      orderedList: document.queryCommandState('insertOrderedList'),
      unorderedList: document.queryCommandState('insertUnorderedList'),
      linkUrl: linkUrl,
      alignment: alignment
    });
  }

  // -----------------------------------------------------------------------
  // Bridge API: called from Flutter via evaluateJavascript
  // -----------------------------------------------------------------------
  window.editorBridge = {

    execCommand: function(command, value) {
      editor.focus();
      document.execCommand(command, false, value || null);
      reportContent();
      reportSelectionStyle();
    },

    insertLink: function(url, text) {
      editor.focus();
      var sel = window.getSelection();
      if (sel.toString().length > 0) {
        document.execCommand('createLink', false, url);
      } else if (text) {
        var a = document.createElement('a');
        a.href = url;
        a.textContent = text;
        a.target = '_blank';
        var range = sel.getRangeAt(0);
        range.insertNode(a);
        range.setStartAfter(a);
        range.collapse(true);
        sel.removeAllRanges();
        sel.addRange(range);
      } else {
        document.execCommand('createLink', false, url);
      }
      reportContent();
      reportSelectionStyle();
    },

    removeLink: function() {
      editor.focus();
      document.execCommand('unlink', false, null);
      reportContent();
      reportSelectionStyle();
    },

    setHtml: function(html) {
      editor.innerHTML = html;
      reportContent();
    },

    getHtml: function() {
      return editor.innerHTML;
    },

    getPlainText: function() {
      return getPlainText();
    },

    insertHtml: function(html) {
      editor.focus();
      document.execCommand('insertHTML', false, html);
      reportContent();
    },

    clear: function() {
      editor.innerHTML = '';
      reportContent();
    },

    focus: function() {
      editor.focus();
    },

    blur: function() {
      editor.blur();
    },

    setAlignment: function(alignment) {
      editor.focus();
      switch (alignment) {
        case 'left':
          document.execCommand('justifyLeft', false, null);
          break;
        case 'center':
          document.execCommand('justifyCenter', false, null);
          break;
        case 'right':
          document.execCommand('justifyRight', false, null);
          break;
        case 'justify':
          document.execCommand('justifyFull', false, null);
          break;
      }
      reportContent();
      reportSelectionStyle();
    },

    isEmpty: function() {
      var text = editor.innerText.trim();
      return text.length === 0 || text === '\\n';
    }
  };

  // -----------------------------------------------------------------------
  // Event listeners
  // -----------------------------------------------------------------------

  editor.addEventListener('input', function() {
    if (!isComposing) {
      reportContent();
    }
  });

  editor.addEventListener('compositionstart', function() {
    isComposing = true;
  });

  editor.addEventListener('compositionend', function() {
    isComposing = false;
    reportContent();
  });

  document.addEventListener('selectionchange', function() {
    reportSelectionStyle();
  });

  editor.addEventListener('focus', function() {
    sendToFlutter({ type: 'focus' });
  });

  editor.addEventListener('blur', function() {
    sendToFlutter({ type: 'blur' });
    reportContent();
  });

  // Paste: let the browser handle it natively, then report changes
  editor.addEventListener('paste', function(e) {
    setTimeout(function() {
      reportContent();
      reportSelectionStyle();
    }, 50);
  });

  // Keyboard shortcuts
  editor.addEventListener('keydown', function(e) {
    if ((e.ctrlKey || e.metaKey) && !e.shiftKey) {
      switch (e.key.toLowerCase()) {
        case 'b':
          e.preventDefault();
          window.editorBridge.execCommand('bold');
          break;
        case 'i':
          e.preventDefault();
          window.editorBridge.execCommand('italic');
          break;
        case 'u':
          e.preventDefault();
          window.editorBridge.execCommand('underline');
          break;
        case 'k':
          e.preventDefault();
          sendToFlutter({ type: 'linkRequest' });
          break;
      }
    }
  });

  // Signal ready
  sendToFlutter({ type: 'ready' });

})();
</script>
</body>
</html>
''';
}

/// Convert a Flutter Color to a CSS color string.
String _colorToCss(dynamic color) {
  try {
    final int value = (color as dynamic).value;
    final int r = (value >> 16) & 0xFF;
    final int g = (value >> 8) & 0xFF;
    final int b = value & 0xFF;
    final double a = ((value >> 24) & 0xFF) / 255.0;
    if (a < 1.0) {
      return 'rgba($r, $g, $b, ${a.toStringAsFixed(2)})';
    }
    return '#${r.toRadixString(16).padLeft(2, '0')}${g.toRadixString(16).padLeft(2, '0')}${b.toRadixString(16).padLeft(2, '0')}';
  } catch (_) {
    return '#000000';
  }
}

/// Escape HTML special characters in a string.
String _escapeHtml(String text) {
  return text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}
```

---

## Step 2: `lib/src/controller.dart` — RichEditorController

```dart
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
            _executeJs(
                "window.editorBridge.setHtml(${jsonEncode(initialHtml)})");
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
      _executeJs(
          "window.editorBridge.execCommand('$command', ${jsonEncode(value)})");
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
    final result =
        await _executeJsWithResult("window.editorBridge.getHtml()");
    return result ?? _content.html;
  }

  /// Get the current plain text content (cached, synchronous).
  String getPlainText() => _content.plainText;

  /// Get the current plain text content directly from JS (async).
  Future<String> getPlainTextAsync() async {
    final result =
        await _executeJsWithResult("window.editorBridge.getPlainText()");
    return result ?? _content.plainText;
  }

  /// Insert a link. If text is selected, wraps it. Otherwise inserts new linked text.
  void insertLink(String url, [String? text]) {
    if (text != null) {
      _executeJs(
          "window.editorBridge.insertLink(${jsonEncode(url)}, ${jsonEncode(text)})");
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
    _executeJs(
        "window.editorBridge.setAlignment(${jsonEncode(alignment)})");
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
```

---

## Checkpoint

After completing Part 2 you should have these new files:

- ✅ `lib/src/js/editor_html.dart`
- ✅ `lib/src/controller.dart`

The controller and JS bridge form the core communication layer. The toolbar (Part 3) and platform widgets (Part 4) will use these.

**Proceed to Part 3 to build the toolbar.**
