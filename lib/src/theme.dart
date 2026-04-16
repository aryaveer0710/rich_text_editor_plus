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
