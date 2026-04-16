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
