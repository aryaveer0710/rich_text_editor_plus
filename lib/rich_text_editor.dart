import 'rich_text_editor_platform_interface.dart';

class RichTextEditor {
  Future<String?> getPlatformVersion() {
    return RichTextEditorPlatform.instance.getPlatformVersion();
  }
}
