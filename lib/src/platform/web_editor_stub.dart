import 'package:flutter/material.dart';

import 'editor_platform.dart';

/// Stub for web editor on non-web platforms.
/// Never actually instantiated on mobile — MobileEditor is used instead.
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
    return const Center(
      child: Text('Web editor is not supported on this platform.'),
    );
  }
}
