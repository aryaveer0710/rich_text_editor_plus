# Rich Text Editor Plugin — Part 5 of 5: Example App & Final Setup

## Context

Parts 1-4 built the complete plugin. Now we create the example app, configure platform settings, and document how to extend the editor in the future.

---

## Step 1: `example/pubspec.yaml`

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

Run `flutter pub get` inside the `example/` directory after creating this.

---

## Step 2: `example/lib/main.dart`

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
    final theme =
        _isDarkTheme ? RichEditorTheme.dark() : RichEditorTheme.light();

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
                toolbarConfig: ToolbarConfig.standard,
                editorHeight: double.infinity,
                onChanged: (content) {
                  debugPrint(
                      'Content changed: ${content.html.length} chars HTML, '
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
    );
  }
}
```

---

## Step 3: Android Configuration

In `example/android/app/build.gradle`, ensure `minSdkVersion` is at least **19** (required by `webview_flutter`):

```gradle
android {
    defaultConfig {
        minSdkVersion 19
        // ... rest stays the same
    }
}
```

If using newer Flutter templates that use `flutter.minSdkVersion`, update `example/android/local.properties` or the `build.gradle` to set `minSdk = 19` or higher.

---

## Step 4: iOS Configuration

No special configuration needed. WKWebView is available by default on all supported iOS versions.

If you want to allow the WebView to load the data URI (our HTML), this should work out of the box. If you encounter issues, add this to `example/ios/Runner/Info.plist`:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

---

## Step 5: Web Configuration

No special configuration needed for Flutter Web. The `HtmlElementView` with an iframe works out of the box.

To run on web:

```bash
cd example
flutter run -d chrome
```

If you encounter issues with the web renderer, try:

```bash
flutter run -d chrome --web-renderer html
```

The `html` renderer works best with `HtmlElementView` / platform views. The `canvaskit` renderer also works but may need the `--web-renderer html` flag for platform views.

---

## Step 6: Run and Test

```bash
cd example

# Android
flutter run -d android

# iOS
flutter run -d ios

# Web
flutter run -d chrome
```

### Test Checklist

1. **Typing:** Type text in the editor. It should appear naturally.
2. **Bold/Italic/Underline:** Select text → tap toolbar button → text should format. Tap again → format removed.
3. **Strikethrough:** Same as above.
4. **Toolbar state:** Click inside bold text → Bold button should highlight. Click outside → unhighlight.
5. **Ordered list:** Tap OL button → current line becomes a numbered list item. Press Enter → new list item. Press Enter on empty item → exits list.
6. **Unordered list:** Same as ordered but with bullets.
7. **Nested list:** Inside a list item, tap Indent button → item nests under the previous item. Tap Outdent → un-nests.
8. **Link:** Select text → tap Link button → enter URL → text becomes a link. Click on linked text → Link button highlights, dialog shows "Edit Link" with option to remove.
9. **Alignment:** Place cursor in a paragraph → tap Center align → text centers.
10. **Undo/Redo:** Make changes → tap Undo → changes revert. Tap Redo → changes re-apply.
11. **Clear formatting:** Select formatted text → tap Clear → formatting removed.
12. **HTML output:** Tap code icon in app bar → see clean HTML.
13. **Plain text output:** Tap text icon → see plain text with proper line breaks, list bullets, and indentation.
14. **Set HTML:** Tap paste icon → paste HTML like `<p>Test <b>bold</b></p>` → Apply → see it rendered.
15. **Paste:** Copy HTML from a website → paste into editor → should render as rich text.
16. **Keyboard shortcuts:** Ctrl+B, Ctrl+I, Ctrl+U, Ctrl+K should work.
17. **Dark theme:** Toggle theme → editor and toolbar should switch to dark colors.

---

## How to Extend the Editor in the Future

### Adding a New Inline Format (e.g., Superscript)

**1. Add to `toolbar_config.dart`:**
```dart
enum ToolbarAction {
  // ... existing values ...
  superscript,   // ← add this
}

// In getToolbarActionIcon:
case ToolbarAction.superscript:
  return Icons.superscript;

// In getToolbarActionTooltip:
case ToolbarAction.superscript:
  return 'Superscript';
```

**2. Add to `controller.dart` handleToolbarAction:**
```dart
case 'superscript':
  execCommand('superscript');
  break;
```

**3. Add to `selection_style.dart`:**
```dart
final bool isSuperscript;
// ... add to constructor, fromJson, toString
```

**4. Add to JS `reportSelectionStyle` in `editor_html.dart`:**
```javascript
superscript: document.queryCommandState('superscript'),
```

**5. Add to toolbar's `_isActionActive`:**
```dart
case ToolbarAction.superscript:
  return style.isSuperscript;
```

**6. Add to your `ToolbarConfig`:**
```dart
static const ToolbarConfig myConfig = ToolbarConfig(
  actions: [
    // ... existing ...
    ToolbarAction.superscript,
  ],
);
```

That's it. ~15 lines of code across 4 files.

### Adding Font Size

```dart
// In controller:
void setFontSize(int size) {
  execCommand('fontSize', size.toString());
}

// In toolbar: add a dropdown instead of a toggle button
DropdownButton<int>(
  value: currentSize,
  items: [1, 2, 3, 4, 5, 6, 7].map((s) =>
    DropdownMenuItem(value: s, child: Text('Size $s'))
  ).toList(),
  onChanged: (size) => controller.setFontSize(size!),
)
```

### Adding Font Color

```dart
// In controller:
void setFontColor(String hexColor) {
  execCommand('foreColor', hexColor);
}

// In toolbar: add a color picker button
// Use Flutter's ColorPicker or a simple grid of colors
```

### Adding Headings

```dart
// In controller:
void setHeading(int level) {
  if (level == 0) {
    execCommand('formatBlock', '<p>');
  } else {
    execCommand('formatBlock', '<h$level>');
  }
}

// In toolbar: add a dropdown
// H1, H2, H3, H4, H5, H6, Normal
```

### Adding Block Quote

```dart
controller.execCommand('formatBlock', '<blockquote>');
// Add CSS for blockquote in editor_html.dart
```

### Adding Image Insert

```dart
controller.insertHtml('<img src="$imageUrl" alt="$altText" />');
// Add CSS for images in editor_html.dart (already has max-width: 100%)
```

### Adding Read-Only Mode

```dart
// In controller:
void setReadOnly(bool readOnly) {
  _executeJs("document.getElementById('editor').contentEditable = ${!readOnly}");
}
```

### Adding Character/Word Count

```javascript
// In JS reportContent:
sendToFlutter({
  type: 'contentChanged',
  html: editor.innerHTML,
  plainText: getPlainText(),
  charCount: editor.innerText.length,
  wordCount: editor.innerText.trim().split(/\s+/).filter(w => w.length > 0).length
});
```

---

## Known Limitations

1. **Desktop platforms (Windows, Linux, macOS):** Not supported yet. `webview_flutter` has limited desktop support. Can be added later with `webview_windows` or `webview_macos` packages.

2. **`document.execCommand` is technically deprecated** in web standards but universally supported. No browser plans to remove it. The replacement (Input Events Level 2) is far more complex.

3. **Async communication:** Flutter ↔ JS is async (~1-2ms delay). Toolbar state updates are nearly instant but not synchronous.

4. **WebView load time:** ~100-300ms initial load. Fine for editor screens.

5. **No tables:** Tables in contenteditable need a separate UI. Not practical to add with just `execCommand`.

6. **Selection handles:** Use the platform's WebView handles, which may look slightly different from Flutter's native ones.

7. **No collaborative editing:** Single-user only.

8. **Web renderer:** On Flutter Web, `HtmlElementView` works best with the `html` renderer. The `canvaskit` renderer supports it but may have quirks with platform views.

---

## Final File Listing

After completing all 5 parts, your project should have:

```
rich_text_editor_plus/
├── lib/
│   ├── rich_text_editor_plus.dart           # Barrel export
│   └── src/
│       ├── controller.dart                   # RichEditorController
│       ├── editor.dart                       # RichTextEditor widget
│       ├── toolbar.dart                      # RichEditorToolbar + LinkDialogResult
│       ├── toolbar_config.dart               # ToolbarAction enum + ToolbarConfig
│       ├── theme.dart                        # RichEditorTheme
│       ├── models/
│       │   ├── content.dart                  # EditorContent
│       │   └── selection_style.dart          # SelectionStyle
│       ├── platform/
│       │   ├── editor_platform.dart          # Abstract base
│       │   ├── mobile_editor.dart            # WebView (Android/iOS)
│       │   ├── web_editor.dart               # HtmlElementView (Web)
│       │   ├── web_editor_stub.dart          # Stub for non-web
│       │   ├── platform_editor.dart          # Default conditional export
│       │   └── platform_editor_web.dart      # Web conditional export
│       └── js/
│           └── editor_html.dart              # HTML + CSS + JS bridge
├── example/
│   ├── lib/
│   │   └── main.dart                         # Demo app
│   └── pubspec.yaml
├── pubspec.yaml
├── README.md
├── LICENSE
└── CHANGELOG.md
```

**Total: 16 files.** The plugin is now complete and ready to use.
