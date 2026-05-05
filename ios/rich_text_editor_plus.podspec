#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint rich_text_editor_plus.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'rich_text_editor_plus'
  s.version          = '0.1.3'
  s.summary          = 'A rich text editor plugin for Flutter.'
  s.description      = <<-DESC
A rich text editor plugin for Flutter with a native Flutter toolbar and browser-based editing.
Supports bold, italic, underline, strikethrough, links, ordered/unordered nested lists,
alignment, and HTML import/export. Works on Android, iOS, and Web.
                       DESC
  s.homepage         = 'https://github.com/aryaveer0710/rich_text_editor_plus'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'aryaveer0710' => 'aryaveer.chaudhary@runo.ai' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # s.resource_bundles = {'rich_text_editor_plus_privacy' => ['Resources/PrivacyInfo.xcprivacy']}
end
