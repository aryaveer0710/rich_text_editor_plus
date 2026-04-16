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
