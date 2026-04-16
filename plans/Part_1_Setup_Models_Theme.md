
# Rich Text Editor Plugin — Part 1 of 5: Project Setup, Models & Theme

## Overview

We're building a Flutter plugin called `rich_text_editor_plus` — a rich text editor that uses `contenteditable` HTML under the hood via `webview_flutter` on mobile and `HtmlElementView` on web. The toolbar is pure Flutter.

This is Part 1. Complete this fully before moving to Part 2.

---

## Step 1: Create the Plugin Project

```bash
flutter create --template=plugin --platforms=android,ios,web rich_text_editor_plus
cd rich_text_editor_plus
```

Delete all generated example code and lib code. We'll replace everything.

---

## Step 2: `pubspec.yaml` (root)

Replace the root `pubspec.yaml` with:

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

## Step 3: File Structure

Create this folder structure inside `lib/`:

```
lib/
├── rich_text_editor_plus.dart
└── src/
    ├── controller.dart            (Part 2)
    ├── editor.dart                (Part 4)
    ├── toolbar.dart               (Part 3)
    ├── toolbar_config.dart
    ├── theme.dart
    ├── models/
    │   ├── content.dart
    │   └── selection_style.dart
    ├── platform/
    │   ├── editor_platform.dart   (Part 4)
    │   ├── mobile_editor.dart     (Part 4)
    │   ├── web_editor.dart        (Part 4)
    │   └── web_editor_stub.dart   (Part 4)
    └── js/
        └── editor_html.dart       (Part 2)
```

Create all folders now. We'll fill files marked with (Part N) in later parts.

---

## Step 4: Barrel Export — `lib/rich_text_editor_plus.dart`

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

## Step 5: `lib/src/models/content.dart`

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
  String toString() =>
      'EditorContent(html: ${html.length} chars, plainText: ${plainText.length} chars)';
}
```

---

## Step 6: `lib/src/models/selection_style.dart`

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

## Step 7: `lib/src/toolbar_config.dart`

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

## Step 8: `lib/src/theme.dart`

```dart
import 'package:flutter/material.dart';

/// Theme configuration for the rich text editor.
class RichEditorTheme {
  final Color toolbarColor;
  final Color toolbarIconColor;
  final Color activeIconColor;
  final Color? activeBackgroundColor;
  final Color editorBackground;
  final Color editorTextColor;
  final String editorFontFamily;
  final double editorFontSize;
  final double editorLineHeight;
  final EdgeInsets editorPadding;
  final double toolbarSpacing;
  final double toolbarIconSize;
  final double toolbarHeight;
  final BorderRadius borderRadius;
  final BoxBorder? border;
  final String? placeholder;
  final Color placeholderColor;
  final bool showToolbarDivider;
  final Color dividerColor;

  const RichEditorTheme({
    this.toolbarColor = const Color(0xFFF8F9FA),
    this.toolbarIconColor = const Color(0xFF5F6368),
    this.activeIconColor = const Color(0xFF1A73E8),
    this.activeBackgroundColor = const Color(0xFFE8F0FE),
    this.editorBackground = Colors.white,
    this.editorTextColor = const Color(0xFF202124),
    this.editorFontFamily =
        '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
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
      activeBackgroundColor:
          activeBackgroundColor ?? this.activeBackgroundColor,
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

## Step 9: `lib/src/platform/editor_platform.dart`

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

**Note:** This file references `RichEditorController` from `controller.dart` which we'll create in Part 2. Create this file now but it won't compile until Part 2 is done. That's fine.

---

## Checkpoint

After completing Part 1 you should have these files created:

- ✅ `pubspec.yaml`
- ✅ `lib/rich_text_editor_plus.dart`
- ✅ `lib/src/models/content.dart`
- ✅ `lib/src/models/selection_style.dart`
- ✅ `lib/src/toolbar_config.dart`
- ✅ `lib/src/theme.dart`
- ✅ `lib/src/platform/editor_platform.dart`
- ✅ Empty folders: `lib/src/js/`, `lib/src/platform/`

Don't run `flutter pub get` yet — it will fail because `controller.dart` and other files referenced in the barrel export don't exist yet.

**Proceed to Part 2 to create the JS bridge and controller.**
