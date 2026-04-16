import 'package:flutter_test/flutter_test.dart';
import 'package:rich_text_editor_plus/rich_text_editor.dart';
import 'package:rich_text_editor_plus/rich_text_editor_platform_interface.dart';
import 'package:rich_text_editor_plus/rich_text_editor_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockRichTextEditorPlatform
    with MockPlatformInterfaceMixin
    implements RichTextEditorPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final RichTextEditorPlatform initialPlatform = RichTextEditorPlatform.instance;

  test('$MethodChannelRichTextEditor is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelRichTextEditor>());
  });

  test('getPlatformVersion', () async {
    RichTextEditor richTextEditorPlugin = RichTextEditor();
    MockRichTextEditorPlatform fakePlatform = MockRichTextEditorPlatform();
    RichTextEditorPlatform.instance = fakePlatform;

    expect(await richTextEditorPlugin.getPlatformVersion(), '42');
  });
}
