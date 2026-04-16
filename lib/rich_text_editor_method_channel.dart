import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'rich_text_editor_platform_interface.dart';

/// An implementation of [RichTextEditorPlatform] that uses method channels.
class MethodChannelRichTextEditor extends RichTextEditorPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('rich_text_editor');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
