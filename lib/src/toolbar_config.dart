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
