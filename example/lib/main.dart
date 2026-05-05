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
          '<p>Try the toolbar to format text. Here are some things to test:</p>'
          '<ul>'
          '<li><b>Bold</b>, <i>italic</i>, <u>underline</u>, '
          '<s>strikethrough</s></li>'
          '<li>Ordered and unordered lists'
          '<ul><li>Nested lists work too!</li>'
          '<li>Try indenting with the toolbar</li></ul></li>'
          '<li><a href="https://flutter.dev">Links</a> — '
          'select text and click the link icon</li>'
          '</ul>'
          '<p>Try pasting HTML content into the editor — it will be '
          'rendered as rich text automatically.</p>'
          '<p style="text-align: center;">This paragraph is centered.</p>',
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

    // Custom toolbar theme built in the example app — demonstrates the toolbar
    // slot pattern: consumers control styling just like Clear/Set HTML buttons.
    final toolbarTheme = _isDarkTheme
        ? RichEditorTheme.dark().copyWith(
            toolbarColor: const Color(0xFF1A237E),
            activeIconColor: Colors.amber,
          )
        : RichEditorTheme.light().copyWith(
            toolbarColor: const Color(0xFFE8EAF6),
            activeIconColor: Colors.indigo,
            activeBackgroundColor: Colors.indigo.withValues(alpha: 0.15),
          );

    final myToolbar = RichEditorToolbar(
      controller: _controller,
      theme: toolbarTheme,
      config: ToolbarConfig.standard,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rich Text Editor'),
        actions: [
          // Toggle dark/light theme
          IconButton(
            icon: Icon(_isDarkTheme ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => setState(() => _isDarkTheme = !_isDarkTheme),
            tooltip: 'Toggle theme',
          ),
          // View HTML output
          IconButton(
            icon: const Icon(Icons.code),
            onPressed: () => _showOutput(
              context,
              title: 'HTML Output',
              content: _controller.getHtml(),
              isMono: true,
            ),
            tooltip: 'View HTML',
          ),
          // View plain text output
          IconButton(
            icon: const Icon(Icons.text_snippet),
            onPressed: () => _showOutput(
              context,
              title: 'Plain Text Output',
              content: _controller.getPlainText(),
              isMono: false,
            ),
            tooltip: 'View Plain Text',
          ),
          // Load HTML into editor
          IconButton(
            icon: const Icon(Icons.paste),
            onPressed: () => _showSetHtmlDialog(context),
            tooltip: 'Set HTML',
          ),
          // Clear editor
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _controller.clear(),
            tooltip: 'Clear',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: RichTextEditor(
                controller: _controller,
                theme: theme,
                toolbar: myToolbar,
                toolbarConfig: ToolbarConfig.standard,
                editorHeight: double.infinity,
                onChanged: (content) {
                  debugPrint('Content changed: ${content.html.length} chars HTML, '
                      '${content.plainText.length} chars plain');
                },
                onFocus: () => debugPrint('Editor focused'),
                onBlur: () => debugPrint('Editor blurred'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showOutput(
    BuildContext context, {
    required String title,
    required String content,
    required bool isMono,
  }) {
    _controller.disablePointerEvents();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              content.isEmpty ? '(empty)' : content,
              style: TextStyle(
                fontFamily: isMono ? 'monospace' : null,
                fontSize: 13,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    ).then((_) => _controller.enablePointerEvents());
  }

  void _showSetHtmlDialog(BuildContext context) {
    _controller.disablePointerEvents();
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set HTML Content'),
        content: TextField(
          controller: textController,
          maxLines: 8,
          decoration: const InputDecoration(
            hintText: '<p>Paste or type HTML here...</p>',
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
    ).then((_) => _controller.enablePointerEvents());
  }
}
