import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'rich_text_editor_method_channel.dart';

abstract class RichTextEditorPlatform extends PlatformInterface {
  /// Constructs a RichTextEditorPlatform.
  RichTextEditorPlatform() : super(token: _token);

  static final Object _token = Object();

  static RichTextEditorPlatform _instance = MethodChannelRichTextEditor();

  /// The default instance of [RichTextEditorPlatform] to use.
  ///
  /// Defaults to [MethodChannelRichTextEditor].
  static RichTextEditorPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [RichTextEditorPlatform] when
  /// they register themselves.
  static set instance(RichTextEditorPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
