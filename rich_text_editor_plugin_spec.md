# Flutter Rich Text Editor Plugin — Full Implementation Spec

## Overview

Build a Flutter plugin called `rich_text_editor_plus` that provides a rich text editor widget with a customizable toolbar. The editor uses a `contenteditable` HTML div under the hood — rendered via `webview_flutter` on mobile (Android/iOS) and via `HtmlElementView` on Flutter Web. The toolbar is built entirely in Flutter, giving full design control and native look.

**Key principle:** The browser engine handles all text editing, formatting, selection, undo/redo, paste, nested lists, and cursor behavior. Flutter handles the UI chrome (toolbar, theming) and communicates with the browser via a JavaScript bridge.

---

## Project Structure

```
rich_text_editor_plus/
├── lib/
│   ├── rich_text_editor_plus.dart        # Barrel export
│   └── src/
│       ├── controller.dart                # RichEditorController
│       ├── editor.dart                    # RichTextEditor widget
│       ├── toolbar.dart                   # RichEditorToolbar widget
│       ├── toolbar_config.dart            # ToolbarAction enum, config
│       ├── theme.dart                     # RichEditorTheme
│       ├── models/
│       │   ├── content.dart               # EditorContent (html, plainText)
│       │   └── selection_style.dart       # SelectionStyle
│       ├── platform/
│       │   ├── editor_platform.dart       # Abstract EditorPlatform
│       │   ├── mobile_editor.dart         # WebView implementation
│       │   └── web_editor.dart            # HtmlElementView implementation
│       └── js/
│           └── editor_html.dart           # HTML + CSS + JS as Dart string constants
├── example/
│   └── lib/
│       └── main.dart                      # Demo app
├── pubspec.yaml
├── README.md
├── LICENSE
└── CHANGELOG.md
```

---

## pubspec.yaml

```yaml
name: rich_text_editor_plus
description: A rich text editor plugin for Flutter with a native Flutter toolbar and browser-based editing. Supports bold, italic, underline, strikethrough, links, ordered/unordered nested lists, alignment, and HTML import/export. Works on Android, iOS, and Web.
version: 0.1.0
homepage: https://github.com/your-username/rich_text_editor_plus

environment:
  sdk: '>=3.2.0 <4.0.0'
  flutter: '>=3.16.0'

dependencies:
  flutter:
    sdk: flutter
  webview_flutter: ^4.10.0
  webview_flutter_android: ^4.1.0
  webview_flutter_wkwebview: ^3.16.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0

flutter:
  plugin:
    platforms:
      android:
        dartPluginClass: none
      ios:
        dartPluginClass: none
      web:
        dartPluginClass: none
```

---

## File 1: `lib/rich_text_editor_plus.dart` — Barrel Export

```dart
library rich_text_editor_plus;

export 'src/controller.dart';
export 'src/editor.dart';
export 'src/toolbar.dart';
export 'src/toolbar_config.dart';
export 'src/theme.dart';
export 'src/models/content.dart';
export 'src/models/selection_style.dart';
```

---

## File 2: `lib/src/models/content.dart` — EditorContent

```dart
/// Represents the editor's content in multiple formats.
class EditorContent {
  /// The HTML representation of the editor content.
  final String html;

  /// The plain text representation with line breaks and list formatting preserved.
  final String plainText;

  const EditorContent({
    required this.html,
    required this.plainText,
  });

  /// Empty content.
  static const EditorContent empty = EditorContent(html: '', plainText: '');

  bool get isEmpty => html.isEmpty && plainText.isEmpty;
  bool get isNotEmpty => !isEmpty;

  @override
  String toString() => 'EditorContent(html: ${html.length} chars, plainText: ${plainText.length} chars)';
}
```

---

## File 3: `lib/src/models/selection_style.dart` — SelectionStyle

```dart
/// Represents the formatting state at the current cursor position or selection.
///
/// Updated every time the selection changes inside the editor.
class SelectionStyle {
  final bool isBold;
  final bool isItalic;
  final bool isUnderline;
  final bool isStrikethrough;
  final bool isOrderedList;
  final bool isUnorderedList;
  final String? linkUrl;
  final String alignment; // 'left', 'center', 'right', 'justify'

  const SelectionStyle({
    this.isBold = false,
    this.isItalic = false,
    this.isUnderline = false,
    this.isStrikethrough = false,
    this.isOrderedList = false,
    this.isUnorderedList = false,
    this.linkUrl,
    this.alignment = 'left',
  });

  /// Whether a link is active at the current selection.
  bool get hasLink => linkUrl != null && linkUrl!.isNotEmpty;

  /// Default empty style.
  static const SelectionStyle none = SelectionStyle();

  /// Parse from a JSON map sent by the JS bridge.
  factory SelectionStyle.fromJson(Map<String, dynamic> json) {
    return SelectionStyle(
      isBold: json['bold'] == true,
      isItalic: json['italic'] == true,
      isUnderline: json['underline'] == true,
      isStrikethrough: json['strikethrough'] == true,
      isOrderedList: json['orderedList'] == true,
      isUnorderedList: json['unorderedList'] == true,
      linkUrl: json['linkUrl'] as String?,
      alignment: (json['alignment'] as String?) ?? 'left',
    );
  }

  @override
  String toString() {
    final active = <String>[];
    if (isBold) active.add('bold');
    if (isItalic) active.add('italic');
    if (isUnderline) active.add('underline');
    if (isStrikethrough) active.add('strikethrough');
    if (isOrderedList) active.add('OL');
    if (isUnorderedList) active.add('UL');
    if (hasLink) active.add('link:$linkUrl');
    active.add('align:$alignment');
    return 'SelectionStyle(${active.join(', ')})';
  }
}
```

---

## File 4: `lib/src/toolbar_config.dart` — ToolbarAction enum and config

```dart
import 'package:flutter/material.dart';

/// All supported toolbar actions.
///
/// To add a new formatting action in the future:
/// 1. Add an enum value here.
/// 2. Add the corresponding execCommand in the JS bridge (editor_html.dart).
/// 3. Add the icon mapping below.
/// 4. Add the selectionStyle field in SelectionStyle.
enum ToolbarAction {
  bold,
  italic,
  underline,
  strikethrough,
  link,
  orderedList,
  unorderedList,
  alignLeft,
  alignCenter,
  alignRight,
  alignJustify,
  indent,
  outdent,
  undo,
  redo,
  clearFormatting,
}

/// Returns the default icon for a toolbar action.
IconData getToolbarActionIcon(ToolbarAction action) {
  switch (action) {
    case ToolbarAction.bold:
      return Icons.format_bold;
    case ToolbarAction.italic:
      return Icons.format_italic;
    case ToolbarAction.underline:
      return Icons.format_underlined;
    case ToolbarAction.strikethrough:
      return Icons.format_strikethrough;
    case ToolbarAction.link:
      return Icons.link;
    case ToolbarAction.orderedList:
      return Icons.format_list_numbered;
    case ToolbarAction.unorderedList:
      return Icons.format_list_bulleted;
    case ToolbarAction.alignLeft:
      return Icons.format_align_left;
    case ToolbarAction.alignCenter:
      return Icons.format_align_center;
    case ToolbarAction.alignRight:
      return Icons.format_align_right;
    case ToolbarAction.alignJustify:
      return Icons.format_align_justify;
    case ToolbarAction.indent:
      return Icons.format_indent_increase;
    case ToolbarAction.outdent:
      return Icons.format_indent_decrease;
    case ToolbarAction.undo:
      return Icons.undo;
    case ToolbarAction.redo:
      return Icons.redo;
    case ToolbarAction.clearFormatting:
      return Icons.format_clear;
  }
}

/// Returns the tooltip string for a toolbar action.
String getToolbarActionTooltip(ToolbarAction action) {
  switch (action) {
    case ToolbarAction.bold:
      return 'Bold (Ctrl+B)';
    case ToolbarAction.italic:
      return 'Italic (Ctrl+I)';
    case ToolbarAction.underline:
      return 'Underline (Ctrl+U)';
    case ToolbarAction.strikethrough:
      return 'Strikethrough';
    case ToolbarAction.link:
      return 'Insert Link (Ctrl+K)';
    case ToolbarAction.orderedList:
      return 'Numbered List';
    case ToolbarAction.unorderedList:
      return 'Bulleted List';
    case ToolbarAction.alignLeft:
      return 'Align Left';
    case ToolbarAction.alignCenter:
      return 'Align Center';
    case ToolbarAction.alignRight:
      return 'Align Right';
    case ToolbarAction.alignJustify:
      return 'Justify';
    case ToolbarAction.indent:
      return 'Indent';
    case ToolbarAction.outdent:
      return 'Outdent';
    case ToolbarAction.undo:
      return 'Undo (Ctrl+Z)';
    case ToolbarAction.redo:
      return 'Redo (Ctrl+Y)';
    case ToolbarAction.clearFormatting:
      return 'Clear Formatting';
  }
}

/// Default toolbar configuration with all common actions.
class ToolbarConfig {
  final List<ToolbarAction> actions;

  const ToolbarConfig({required this.actions});

  /// Standard toolbar with all formatting options.
  static const ToolbarConfig standard = ToolbarConfig(
    actions: [
      ToolbarAction.undo,
      ToolbarAction.redo,
      ToolbarAction.bold,
      ToolbarAction.italic,
      ToolbarAction.underline,
      ToolbarAction.strikethrough,
      ToolbarAction.link,
      ToolbarAction.orderedList,
      ToolbarAction.unorderedList,
      ToolbarAction.indent,
      ToolbarAction.outdent,
      ToolbarAction.alignLeft,
      ToolbarAction.alignCenter,
      ToolbarAction.alignRight,
      ToolbarAction.clearFormatting,
    ],
  );

  /// Minimal toolbar with just basic text formatting.
  static const ToolbarConfig minimal = ToolbarConfig(
    actions: [
      ToolbarAction.bold,
      ToolbarAction.italic,
      ToolbarAction.underline,
      ToolbarAction.link,
      ToolbarAction.orderedList,
      ToolbarAction.unorderedList,
    ],
  );
}
```

---

## File 5: `lib/src/theme.dart` — RichEditorTheme

```dart
import 'package:flutter/material.dart';

/// Theme configuration for the rich text editor.
class RichEditorTheme {
  /// Background color of the toolbar.
  final Color toolbarColor;

  /// Color of toolbar icons when inactive.
  final Color toolbarIconColor;

  /// Color of toolbar icons when the format is active at the cursor.
  final Color activeIconColor;

  /// Background highlight for active toolbar buttons.
  final Color? activeBackgroundColor;

  /// Background color of the editor area.
  final Color editorBackground;

  /// Text color inside the editor.
  final Color editorTextColor;

  /// Font family for editor content.
  final String editorFontFamily;

  /// Base font size in the editor (in px).
  final double editorFontSize;

  /// Line height multiplier for editor content.
  final double editorLineHeight;

  /// Padding inside the editor content area.
  final EdgeInsets editorPadding;

  /// Spacing between toolbar buttons.
  final double toolbarSpacing;

  /// Size of toolbar icons.
  final double toolbarIconSize;

  /// Height of the toolbar.
  final double toolbarHeight;

  /// Border radius for the entire editor container.
  final BorderRadius borderRadius;

  /// Border for the entire editor container.
  final BoxBorder? border;

  /// Hint text shown when the editor is empty.
  final String? placeholder;

  /// Color of the placeholder text.
  final Color placeholderColor;

  /// Whether to show a divider between toolbar and editor.
  final bool showToolbarDivider;

  /// Color of the divider between toolbar and editor.
  final Color dividerColor;

  const RichEditorTheme({
    this.toolbarColor = const Color(0xFFF8F9FA),
    this.toolbarIconColor = const Color(0xFF5F6368),
    this.activeIconColor = const Color(0xFF1A73E8),
    this.activeBackgroundColor = const Color(0xFFE8F0FE),
    this.editorBackground = Colors.white,
    this.editorTextColor = const Color(0xFF202124),
    this.editorFontFamily = '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
    this.editorFontSize = 16,
    this.editorLineHeight = 1.6,
    this.editorPadding = const EdgeInsets.all(16),
    this.toolbarSpacing = 2,
    this.toolbarIconSize = 20,
    this.toolbarHeight = 44,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.border,
    this.placeholder = 'Start typing...',
    this.placeholderColor = const Color(0xFF9AA0A6),
    this.showToolbarDivider = true,
    this.dividerColor = const Color(0xFFDADCE0),
  });

  /// A light theme inspired by Google Docs.
  factory RichEditorTheme.light() => const RichEditorTheme();

  /// A dark theme.
  factory RichEditorTheme.dark() => const RichEditorTheme(
        toolbarColor: Color(0xFF2D2D2D),
        toolbarIconColor: Color(0xFFB0B0B0),
        activeIconColor: Color(0xFF8AB4F8),
        activeBackgroundColor: Color(0xFF3C4043),
        editorBackground: Color(0xFF1E1E1E),
        editorTextColor: Color(0xFFE8EAED),
        placeholderColor: Color(0xFF6B6B6B),
        dividerColor: Color(0xFF3C4043),
        border: null,
      );

  /// Creates a copy with overrides.
  RichEditorTheme copyWith({
    Color? toolbarColor,
    Color? toolbarIconColor,
    Color? activeIconColor,
    Color? activeBackgroundColor,
    Color? editorBackground,
    Color? editorTextColor,
    String? editorFontFamily,
    double? editorFontSize,
    double? editorLineHeight,
    EdgeInsets? editorPadding,
    double? toolbarSpacing,
    double? toolbarIconSize,
    double? toolbarHeight,
    BorderRadius? borderRadius,
    BoxBorder? border,
    String? placeholder,
    Color? placeholderColor,
    bool? showToolbarDivider,
    Color? dividerColor,
  }) {
    return RichEditorTheme(
      toolbarColor: toolbarColor ?? this.toolbarColor,
      toolbarIconColor: toolbarIconColor ?? this.toolbarIconColor,
      activeIconColor: activeIconColor ?? this.activeIconColor,
      activeBackgroundColor: activeBackgroundColor ?? this.activeBackgroundColor,
      editorBackground: editorBackground ?? this.editorBackground,
      editorTextColor: editorTextColor ?? this.editorTextColor,
      editorFontFamily: editorFontFamily ?? this.editorFontFamily,
      editorFontSize: editorFontSize ?? this.editorFontSize,
      editorLineHeight: editorLineHeight ?? this.editorLineHeight,
      editorPadding: editorPadding ?? this.editorPadding,
      toolbarSpacing: toolbarSpacing ?? this.toolbarSpacing,
      toolbarIconSize: toolbarIconSize ?? this.toolbarIconSize,
      toolbarHeight: toolbarHeight ?? this.toolbarHeight,
      borderRadius: borderRadius ?? this.borderRadius,
      border: border ?? this.border,
      placeholder: placeholder ?? this.placeholder,
      placeholderColor: placeholderColor ?? this.placeholderColor,
      showToolbarDivider: showToolbarDivider ?? this.showToolbarDivider,
      dividerColor: dividerColor ?? this.dividerColor,
    );
  }
}
```

---

## File 6: `lib/src/js/editor_html.dart` — HTML + CSS + JS Bridge

This is the core. The entire contenteditable editor runs inside this HTML. Both mobile (WebView) and web (HtmlElementView) load this same HTML.

```dart
import '../theme.dart';

/// Generates the full HTML document for the contenteditable editor.
///
/// The HTML includes:
/// - A styled contenteditable div
/// - JavaScript bridge functions for executing commands
/// - Event listeners that report content and selection changes back to Flutter
///
/// Communication protocol:
///   Flutter → JS:  evaluateJavascript / postMessage calling window.editorBridge.*
///   JS → Flutter:  window.flutter_channel.postMessage(JSON.stringify({...}))
///                   On web: window.parent.postMessage(...)
///
/// Message types FROM JS:
///   { type: 'contentChanged', html: '...', plainText: '...' }
///   { type: 'selectionStyle', bold: bool, italic: bool, ... }
///   { type: 'ready' }
///   { type: 'focus' }
///   { type: 'blur' }
String generateEditorHtml(RichEditorTheme theme) {
  final bgColor = _colorToHex(theme.editorBackground);
  final textColor = _colorToHex(theme.editorTextColor);
  final placeholderColor = _colorToHex(theme.placeholderColor);
  final fontFamily = theme.editorFontFamily;
  final fontSize = theme.editorFontSize;
  final lineHeight = theme.editorLineHeight;
  final paddingTop = theme.editorPadding.top;
  final paddingRight = theme.editorPadding.right;
  final paddingBottom = theme.editorPadding.bottom;
  final paddingLeft = theme.editorPadding.left;
  final placeholder = theme.placeholder ?? '';

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

  /* Prevent img/object paste from breaking layout */
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
      // Fallback: window.postMessage for web platform
      if (window.parent && window.parent !== window) {
        window.parent.postMessage(msg, '*');
        return;
      }
      // Another fallback for web: custom event
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
    // Walk the DOM tree to produce clean plain text with proper spacing.
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
        prefix = '• ';
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
      // Split child text in case there are nested lists
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
      // Don't double-add newlines for lists (li already adds them)
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

    // Detect alignment from the current block
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
          // Also check align attribute
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
  // Bridge API — called from Flutter via evaluateJavascript
  // -----------------------------------------------------------------------
  window.editorBridge = {

    // Execute a formatting command
    execCommand: function(command, value) {
      editor.focus();
      document.execCommand(command, false, value || null);
      reportContent();
      reportSelectionStyle();
    },

    // Insert a link
    insertLink: function(url, text) {
      editor.focus();
      var sel = window.getSelection();
      if (sel.toString().length > 0) {
        // Wrap selection in a link
        document.execCommand('createLink', false, url);
      } else if (text) {
        // Insert new link with text
        var a = document.createElement('a');
        a.href = url;
        a.textContent = text;
        a.target = '_blank';
        var range = sel.getRangeAt(0);
        range.insertNode(a);
        // Move cursor after the link
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

    // Remove a link at the cursor
    removeLink: function() {
      editor.focus();
      document.execCommand('unlink', false, null);
      reportContent();
      reportSelectionStyle();
    },

    // Set editor HTML content
    setHtml: function(html) {
      editor.innerHTML = html;
      reportContent();
    },

    // Get editor HTML content
    getHtml: function() {
      return editor.innerHTML;
    },

    // Get plain text content
    getPlainText: function() {
      return getPlainText();
    },

    // Insert HTML at cursor
    insertHtml: function(html) {
      editor.focus();
      document.execCommand('insertHTML', false, html);
      reportContent();
    },

    // Clear all content
    clear: function() {
      editor.innerHTML = '';
      reportContent();
    },

    // Focus the editor
    focus: function() {
      editor.focus();
    },

    // Blur the editor
    blur: function() {
      editor.blur();
    },

    // Set alignment
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

    // Check if editor is empty
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

  // Handle paste — allow HTML paste natively, the browser handles it
  editor.addEventListener('paste', function(e) {
    // The browser's default paste handles HTML→contenteditable well.
    // We just report the content change after paste completes.
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

  // Signal that the editor is ready
  sendToFlutter({ type: 'ready' });

})();
</script>
</body>
</html>
''';
}

/// Convert a Flutter Color to a hex CSS string.
String _colorToHex(dynamic color) {
  // color is Color type, access its properties
  // Since this is generated code, we receive Color objects
  // We extract ARGB values
  if (color is int) {
    return '#${color.toRadixString(16).padLeft(8, '0').substring(2)}';
  }
  // For Color objects, access .value
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
```

---

## File 7: `lib/src/controller.dart` — RichEditorController

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

  /// Completer for getHtml/getPlainText calls that need async JS evaluation.
  final Map<String, Completer<String>> _pendingQueries = {};

  /// Queue of commands to execute once JS is ready.
  final List<_PendingCommand> _commandQueue = [];

  /// Function to evaluate JavaScript. Set by the platform editor widget.
  Future<String?> Function(String js)? evaluateJavascript;

  /// Initialize with optional initial HTML content.
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
          // Set initial content if provided
          if (initialHtml != null && initialHtml!.isNotEmpty) {
            _executeJs("window.editorBridge.setHtml(${jsonEncode(initialHtml)})");
          }
          // Flush queued commands
          for (final cmd in _commandQueue) {
            _executeJs(cmd.js);
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
  // Commands to JS
  // -----------------------------------------------------------------------

  /// Execute a formatting command (bold, italic, etc.)
  void execCommand(String command, [String? value]) {
    if (value != null) {
      _executeJs("window.editorBridge.execCommand('$command', ${jsonEncode(value)})");
    } else {
      _executeJs("window.editorBridge.execCommand('$command')");
    }
  }

  /// Set the editor's HTML content.
  void setHtml(String html) {
    _executeJs("window.editorBridge.setHtml(${jsonEncode(html)})");
  }

  /// Get the current HTML content.
  ///
  /// Returns the cached content synchronously. For the most up-to-date value
  /// after recent edits, use [getHtmlAsync].
  String getHtml() => _content.html;

  /// Get the current HTML content asynchronously from JS.
  Future<String> getHtmlAsync() async {
    final result = await _executeJsWithResult("window.editorBridge.getHtml()");
    return result ?? _content.html;
  }

  /// Get the current plain text content.
  String getPlainText() => _content.plainText;

  /// Get the current plain text content asynchronously from JS.
  Future<String> getPlainTextAsync() async {
    final result = await _executeJsWithResult("window.editorBridge.getPlainText()");
    return result ?? _content.plainText;
  }

  /// Insert a link. If text is selected, wraps it. Otherwise inserts new text.
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

  /// Handle a toolbar action. This maps ToolbarAction enums to JS commands.
  /// The toolbar widget calls this method.
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
      _commandQueue.add(_PendingCommand(js));
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
    _pendingQueries.clear();
    super.dispose();
  }
}

class _PendingCommand {
  final String js;
  _PendingCommand(this.js);
}
```

---

## File 8: `lib/src/platform/editor_platform.dart` — Abstract Interface

```dart
import 'package:flutter/widgets.dart';

import '../controller.dart';
import '../theme.dart';

/// Abstract interface for platform-specific editor implementations.
///
/// Mobile uses WebView, Web uses HtmlElementView.
abstract class EditorPlatform extends StatefulWidget {
  final RichEditorController controller;
  final RichEditorTheme theme;
  final double? height;

  const EditorPlatform({
    super.key,
    required this.controller,
    required this.theme,
    this.height,
  });
}
```

---

## File 9: `lib/src/platform/mobile_editor.dart` — WebView Implementation

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
              // Wire up the JS evaluation function
              widget.controller.evaluateJavascript = (String js) async {
                final result = await _webViewController.runJavaScriptReturningResult(js);
                return result?.toString();
              };
            }
          },
          // Prevent navigation away from the editor (e.g., tapping links)
          onNavigationRequest: (NavigationRequest request) {
            if (request.url.startsWith('data:') || request.url == 'about:blank') {
              return NavigationDecision.navigate;
            }
            // Could open links externally here via url_launcher
            return NavigationDecision.prevent;
          },
        ),
      );

    // Load the editor HTML
    final html = generateEditorHtml(widget.theme);
    final encodedHtml = Uri.dataFromString(
      html,
      mimeType: 'text/html',
      encoding: Encoding.getByName('utf-8'),
    ).toString();
    _webViewController.loadRequest(Uri.parse(encodedHtml));
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

## File 10: `lib/src/platform/web_editor.dart` — Web Implementation

**IMPORTANT:** This file uses `dart:html` and `dart:ui_web` which are only available on Flutter Web. It must be conditionally imported. Use the stub/conditional import pattern described below.

```dart
// This file should only be imported on web platform.
// Use conditional imports in editor.dart:
//   import 'platform/web_editor_stub.dart'
//       if (dart.library.html) 'platform/web_editor.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

import '../controller.dart';
import '../js/editor_html.dart';
import '../theme.dart';
import 'editor_platform.dart';

/// Web editor implementation using an iframe with HtmlElementView.
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
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      _iframe = html.IFrameElement()
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..srcdoc = generateEditorHtml(widget.theme);

      // Wire up JS evaluation via iframe's contentWindow
      widget.controller.evaluateJavascript = (String js) async {
        try {
          final result = _iframe?.contentWindow?.callMethod('eval', [js]);
          return result?.toString();
        } catch (e) {
          // eval may fail for void expressions; that's fine
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
          // Check if this message is from our editor
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

### Stub file for non-web platforms: `lib/src/platform/web_editor_stub.dart`

```dart
// Stub for web editor on non-web platforms.
// This file is used when dart.library.html is not available.

import 'package:flutter/material.dart';

import '../controller.dart';
import '../theme.dart';
import 'editor_platform.dart';

/// Stub — should never be instantiated on non-web platforms.
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
    return const Center(child: Text('Web editor not supported on this platform'));
  }
}
```

---

## File 11: `lib/src/toolbar.dart` — RichEditorToolbar

```dart
import 'package:flutter/material.dart';

import 'controller.dart';
import 'models/selection_style.dart';
import 'theme.dart';
import 'toolbar_config.dart';

/// A customizable toolbar for the rich text editor.
///
/// Listens to the [RichEditorController] and highlights active formatting.
class RichEditorToolbar extends StatelessWidget {
  final RichEditorController controller;
  final RichEditorTheme theme;
  final ToolbarConfig config;

  /// Optional callback to show a link dialog.
  /// If null, a default dialog is used.
  final Future<LinkDialogResult?> Function(BuildContext context, String? currentUrl)?
      onLinkDialog;

  const RichEditorToolbar({
    super.key,
    required this.controller,
    required this.theme,
    this.config = ToolbarConfig.standard,
    this.onLinkDialog,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final style = controller.selectionStyle;
        return Container(
          height: theme.toolbarHeight,
          decoration: BoxDecoration(
            color: theme.toolbarColor,
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: _buildButtons(context, style),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildButtons(BuildContext context, SelectionStyle style) {
    final buttons = <Widget>[];
    ToolbarAction? lastAction;

    for (final action in config.actions) {
      // Add a separator between different groups of actions
      if (lastAction != null && _shouldAddSeparator(lastAction, action)) {
        buttons.add(_buildSeparator());
      }

      buttons.add(
        _ToolbarButton(
          icon: getToolbarActionIcon(action),
          tooltip: getToolbarActionTooltip(action),
          isActive: _isActionActive(action, style),
          iconColor: theme.toolbarIconColor,
          activeColor: theme.activeIconColor,
          activeBackground: theme.activeBackgroundColor,
          iconSize: theme.toolbarIconSize,
          spacing: theme.toolbarSpacing,
          onPressed: () => _handleAction(context, action),
        ),
      );

      lastAction = action;
    }

    return buttons;
  }

  Widget _buildSeparator() {
    return Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: theme.dividerColor,
    );
  }

  bool _shouldAddSeparator(ToolbarAction prev, ToolbarAction current) {
    // Group: undo/redo | bold/italic/underline/strikethrough | link | lists/indent | alignment | clear
    final group = _getGroup;
    return group(prev) != group(current);
  }

  int Function(ToolbarAction) get _getGroup => (ToolbarAction action) {
        switch (action) {
          case ToolbarAction.undo:
          case ToolbarAction.redo:
            return 0;
          case ToolbarAction.bold:
          case ToolbarAction.italic:
          case ToolbarAction.underline:
          case ToolbarAction.strikethrough:
            return 1;
          case ToolbarAction.link:
            return 2;
          case ToolbarAction.orderedList:
          case ToolbarAction.unorderedList:
          case ToolbarAction.indent:
          case ToolbarAction.outdent:
            return 3;
          case ToolbarAction.alignLeft:
          case ToolbarAction.alignCenter:
          case ToolbarAction.alignRight:
          case ToolbarAction.alignJustify:
            return 4;
          case ToolbarAction.clearFormatting:
            return 5;
        }
      };

  bool _isActionActive(ToolbarAction action, SelectionStyle style) {
    switch (action) {
      case ToolbarAction.bold:
        return style.isBold;
      case ToolbarAction.italic:
        return style.isItalic;
      case ToolbarAction.underline:
        return style.isUnderline;
      case ToolbarAction.strikethrough:
        return style.isStrikethrough;
      case ToolbarAction.orderedList:
        return style.isOrderedList;
      case ToolbarAction.unorderedList:
        return style.isUnorderedList;
      case ToolbarAction.alignLeft:
        return style.alignment == 'left';
      case ToolbarAction.alignCenter:
        return style.alignment == 'center';
      case ToolbarAction.alignRight:
        return style.alignment == 'right';
      case ToolbarAction.alignJustify:
        return style.alignment == 'justify';
      case ToolbarAction.link:
        return style.hasLink;
      default:
        return false;
    }
  }

  void _handleAction(BuildContext context, ToolbarAction action) async {
    if (action == ToolbarAction.link) {
      await _handleLinkAction(context);
      return;
    }
    controller.handleToolbarAction(action.name);
  }

  Future<void> _handleLinkAction(BuildContext context) async {
    final currentUrl = controller.selectionStyle.linkUrl;

    LinkDialogResult? result;
    if (onLinkDialog != null) {
      result = await onLinkDialog!(context, currentUrl);
    } else {
      result = await _showDefaultLinkDialog(context, currentUrl);
    }

    if (result == null) return;

    if (result.shouldRemove) {
      controller.removeLink();
    } else if (result.url != null && result.url!.isNotEmpty) {
      controller.insertLink(result.url!, result.text);
    }
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
}

/// Result from a link dialog.
class LinkDialogResult {
  final String? url;
  final String? text;
  final bool shouldRemove;

  LinkDialogResult({this.url, this.text, this.shouldRemove = false});
}

/// A single toolbar button with active state.
class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isActive;
  final Color iconColor;
  final Color activeColor;
  final Color? activeBackground;
  final double iconSize;
  final double spacing;
  final VoidCallback onPressed;

  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.isActive,
    required this.iconColor,
    required this.activeColor,
    this.activeBackground,
    required this.iconSize,
    required this.spacing,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: spacing),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: isActive ? (activeBackground ?? activeColor.withOpacity(0.1)) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          child: InkWell(
            borderRadius: BorderRadius.circular(4),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                icon,
                size: iconSize,
                color: isActive ? activeColor : iconColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

---

## File 12: `lib/src/editor.dart` — RichTextEditor Widget

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'controller.dart';
import 'theme.dart';
import 'toolbar.dart';
import 'toolbar_config.dart';
import 'models/content.dart';

// Conditional import for web platform
import 'platform/mobile_editor.dart';
// NOTE: For web support, you need conditional imports:
//   import 'platform/web_editor_stub.dart'
//       if (dart.library.html) 'platform/web_editor.dart';
// For simplicity in this spec, the editor widget checks kIsWeb at runtime
// and uses the appropriate platform. In production, use conditional imports.

/// The main rich text editor widget.
///
/// Combines a toolbar and the platform-specific editor surface.
///
/// Usage:
/// ```dart
/// RichTextEditor(
///   controller: _controller,
///   onChanged: (content) => print(content.html),
/// )
/// ```
class RichTextEditor extends StatefulWidget {
  /// Controller for the editor.
  final RichEditorController controller;

  /// Theme for the editor appearance.
  final RichEditorTheme theme;

  /// Toolbar configuration. Use [ToolbarConfig.standard] or [ToolbarConfig.minimal].
  final ToolbarConfig toolbarConfig;

  /// Called when the editor content changes.
  final ContentChangedCallback? onChanged;

  /// Called when the editor gains focus.
  final VoidCallback? onFocus;

  /// Called when the editor loses focus.
  final VoidCallback? onBlur;

  /// Height of the editor area (not including toolbar).
  /// If null, defaults to 300.
  final double? editorHeight;

  /// Whether to show the toolbar.
  final bool showToolbar;

  /// Whether to place the toolbar at the top (true) or bottom (false).
  final bool toolbarAtTop;

  /// Custom link dialog builder. If null, uses the default dialog.
  final Future<LinkDialogResult?> Function(BuildContext context, String? currentUrl)?
      onLinkDialog;

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
  @override
  void initState() {
    super.initState();
    widget.controller.onContentChanged = widget.onChanged;
    widget.controller.onLinkRequest = _handleLinkRequest;
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant RichTextEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
      widget.controller.onContentChanged = widget.onChanged;
      widget.controller.onLinkRequest = _handleLinkRequest;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    // Notify focus/blur callbacks
    if (widget.controller.hasFocus) {
      widget.onFocus?.call();
    } else {
      widget.onBlur?.call();
    }
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

    // Build the platform editor
    // On web: use WebEditor (HtmlElementView)
    // On mobile: use MobileEditor (WebView)
    //
    // NOTE: In production, use conditional imports instead of kIsWeb check.
    // The kIsWeb check here is for clarity in this specification.
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
    // For both web and mobile, we use the mobile editor (WebView) approach.
    // On web, if you want the HtmlElementView approach, use conditional imports
    // to swap MobileEditor for WebEditor.
    //
    // The WebView approach actually works on web too (webview_flutter has web support),
    // but the HtmlElementView approach is more efficient.
    //
    // For this spec, MobileEditor is the default. To enable the web-specific
    // implementation, add conditional imports in your project:
    //
    //   import 'platform/web_editor_stub.dart'
    //       if (dart.library.html) 'platform/web_editor.dart';
    //
    // Then check kIsWeb here and return WebEditor for web.

    if (kIsWeb) {
      // On web, MobileEditor (webview_flutter) also works, but for best
      // performance use WebEditor with conditional imports.
      // Falling through to MobileEditor for now.
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

## File 13: `example/lib/main.dart` — Demo App

```dart
import 'package:flutter/material.dart';
import 'package:rich_text_editor_plus/rich_text_editor_plus.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rich Text Editor Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const EditorDemoPage(),
    );
  }
}

class EditorDemoPage extends StatefulWidget {
  const EditorDemoPage({super.key});

  @override
  State<EditorDemoPage> createState() => _EditorDemoPageState();
}

class _EditorDemoPageState extends State<EditorDemoPage> {
  late final RichEditorController _controller;
  bool _isDarkTheme = false;

  @override
  void initState() {
    super.initState();
    _controller = RichEditorController(
      initialHtml: '<p>Welcome to <b>Rich Text Editor</b>!</p>'
          '<p>Try formatting with the toolbar above.</p>'
          '<ul><li>Bold, italic, underline</li>'
          '<li>Ordered and unordered lists<ul><li>With nesting!</li></ul></li>'
          '<li><a href="https://flutter.dev">Links</a></li></ul>'
          '<p>Paste HTML content and it will be parsed automatically.</p>',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = _isDarkTheme ? RichEditorTheme.dark() : RichEditorTheme.light();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rich Text Editor'),
        actions: [
          IconButton(
            icon: Icon(_isDarkTheme ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => setState(() => _isDarkTheme = !_isDarkTheme),
            tooltip: 'Toggle theme',
          ),
          IconButton(
            icon: const Icon(Icons.code),
            onPressed: () => _showHtmlOutput(context),
            tooltip: 'View HTML',
          ),
          IconButton(
            icon: const Icon(Icons.text_snippet),
            onPressed: () => _showPlainTextOutput(context),
            tooltip: 'View Plain Text',
          ),
          IconButton(
            icon: const Icon(Icons.paste),
            onPressed: () => _showSetHtmlDialog(context),
            tooltip: 'Set HTML',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: RichTextEditor(
          controller: _controller,
          theme: theme,
          toolbarConfig: ToolbarConfig.standard,
          editorHeight: 400,
          onChanged: (content) {
            // Content is available via content.html and content.plainText
            debugPrint('Content changed: ${content.html.length} chars');
          },
        ),
      ),
    );
  }

  void _showHtmlOutput(BuildContext context) {
    final html = _controller.getHtml();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('HTML Output'),
        content: SingleChildScrollView(
          child: SelectableText(
            html.isEmpty ? '(empty)' : html,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showPlainTextOutput(BuildContext context) {
    final text = _controller.getPlainText();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Plain Text Output'),
        content: SingleChildScrollView(
          child: SelectableText(
            text.isEmpty ? '(empty)' : text,
            style: const TextStyle(fontSize: 14),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showSetHtmlDialog(BuildContext context) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set HTML Content'),
        content: TextField(
          controller: textController,
          maxLines: 8,
          decoration: const InputDecoration(
            hintText: 'Paste HTML here...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              _controller.setHtml(textController.text);
              Navigator.of(ctx).pop();
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}
```

---

## File 14: `example/pubspec.yaml`

```yaml
name: rich_text_editor_example
description: Demo app for rich_text_editor_plus plugin.
publish_to: 'none'

environment:
  sdk: '>=3.2.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  rich_text_editor_plus:
    path: ../

flutter:
  uses-material-design: true
```

---

## Web Platform Support — Conditional Import Setup

For proper web support, the `editor.dart` file needs conditional imports. Here is the pattern Claude Code should implement:

### Create `lib/src/platform/platform_selector.dart`:

```dart
// This file exports the correct editor based on platform.
export 'mobile_editor.dart'; // Default for mobile
```

### Create `lib/src/platform/platform_selector_web.dart`:

```dart
// Web-specific export.
export 'web_editor.dart';
```

### In `editor.dart`, replace the import:

```dart
// Instead of:
//   import 'platform/mobile_editor.dart';
// Use:
import 'platform/platform_selector.dart'
    if (dart.library.html) 'platform/platform_selector_web.dart';
```

This ensures `dart:html` is never imported on mobile.

---

## Android Configuration

In `example/android/app/build.gradle`, ensure `minSdkVersion` is at least 19 (for WebView):

```gradle
android {
    defaultConfig {
        minSdkVersion 19
    }
}
```

## iOS Configuration

In `example/ios/Runner/Info.plist`, no special configuration needed. WKWebView is available by default.

---

## Limitations and Known Edge Cases

### What Works Well
- All inline formatting (bold, italic, underline, strikethrough) with toggle behavior
- Nested ordered and unordered lists with proper indentation
- Links with insert/edit/remove via dialog
- Text alignment (left, center, right, justify)
- Indent / outdent for lists
- Undo / redo (browser-native)
- HTML paste with automatic rich text rendering
- Plain text paste
- HTML export and plain text export with proper formatting
- Keyboard shortcuts (Ctrl+B/I/U/K)
- Light and dark theming
- Selection-based formatting (select text, apply style)

### Limitations
1. **Desktop platforms (Windows, Linux, macOS):** Not supported in this initial version. `webview_flutter` has limited desktop support. Can be added later.
2. **`document.execCommand` deprecation:** Technically deprecated in web standards but universally supported. No browser has removed it or plans to. The replacement (Input Events Level 2) is vastly more complex and not needed here.
3. **Async communication:** All Flutter ↔ JS communication is async. There's a ~1-2ms delay for toolbar state updates. Imperceptible to users but means you can't synchronously query editor state.
4. **WebView overhead:** ~100-300ms initial load time for the WebView. Fine for editor screens, not ideal for embedding dozens of editors in a list.
5. **No table support:** Tables in contenteditable are notoriously complex. Would need a separate UI component.
6. **No image embedding:** Could be added via `insertHTML` with `<img>` tags, but image upload/hosting is app-specific.
7. **Selection handles on mobile:** Use the platform's native WebView selection handles, which may look slightly different from Flutter's native ones.
8. **No collaborative editing:** No OT/CRDT support. This is a single-user editor.
9. **IME edge cases:** Some complex IME inputs (Chinese, Japanese, Korean) work via composition events but edge cases may exist.

### Adding New Features Later

| Feature | Effort | How |
|---|---|---|
| Strikethrough | ✅ Already included | — |
| Font size | Low | Add `execCommand('fontSize', value)` + toolbar dropdown |
| Font color | Low | Add `execCommand('foreColor', '#hex')` + color picker |
| Background color | Low | Add `execCommand('hiliteColor', '#hex')` + color picker |
| Headings (H1-H6) | Low | Add `execCommand('formatBlock', '<h1>')` + toolbar dropdown |
| Blockquote | Low | Add `execCommand('formatBlock', '<blockquote>')` |
| Horizontal rule | Low | Add `execCommand('insertHorizontalRule')` |
| Image insert | Medium | `insertHTML('<img src="...">')` + upload UI |
| Table | High | Need custom table UI + contenteditable table handling |
| Mentions (@user) | Medium | Custom dropdown overlay + special span insertion |
| Emoji picker | Medium | Toolbar button + picker UI + `insertHTML` |
| Code blocks | Medium | `formatBlock` + custom CSS for `<pre>` |
| Read-only mode | Low | Toggle `contenteditable` attribute via JS |
| Character/word count | Low | JS reports counts alongside content changes |
| Max length | Low | JS checks length on input, prevents if over limit |
| Custom fonts | Low | Inject `@font-face` into the HTML template |
| RTL support | Low | Set `dir="auto"` on the editor div |
| Print/export PDF | Medium | Use the WebView's print capabilities or generate PDF from HTML |

---

## Instructions for Claude Code

1. Create a Flutter plugin project: `flutter create --template=plugin --platforms=android,ios,web rich_text_editor_plus`
2. Replace the generated files with the code above, following the exact file structure.
3. Set up conditional imports for web/mobile as described in the "Web Platform Support" section.
4. Run `flutter pub get` in both the root and `example/` directories.
5. Test on Android: `cd example && flutter run -d android`
6. Test on iOS: `cd example && flutter run -d ios`
7. Test on web: `cd example && flutter run -d chrome`
8. Verify: toolbar buttons toggle correctly, formatting applies to selected text, HTML/plain text output buttons work, paste HTML into the editor and confirm it renders as rich text.

### Key Implementation Notes for Claude Code

- The `_colorToHex` function in `editor_html.dart` receives Flutter `Color` objects. In Dart, access `color.value` to get the ARGB int. Handle the conversion carefully — the function receives the `Color` type from `dart:ui`, not a raw int.
- The `AnimatedBuilder` in `toolbar.dart` should be `ListenableBuilder` (Flutter 3.16+) or `AnimatedBuilder` with the `animation` parameter set to the controller. Both work — `ListenableBuilder` is preferred on newer Flutter versions.
- For the web editor, `dart:html`'s `callMethod` may need adjustment depending on Flutter's web renderer (html vs canvaskit). Test with both: `flutter run -d chrome --web-renderer html` and `--web-renderer canvaskit`.
- The `uri.dataFromString` approach for loading HTML into WebView works on both Android and iOS. If you hit encoding issues with very large HTML content, switch to `loadHtmlString` method from `webview_flutter`.
