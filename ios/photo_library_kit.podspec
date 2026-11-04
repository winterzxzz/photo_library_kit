#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint photo_library_kit.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'photo_library_kit'
  s.version          = '0.0.1'
  s.summary          = 'Fast, ergonomic access to the device photo & video library with paged queries, cached thumbnails and change streams.'
  s.description      = <<-DESC
Fast, ergonomic access to the device photo & video library with paged queries, cached thumbnails and change streams.
                       DESC
  s.homepage         = 'https://github.com/winterzxzz/photo_library_kit'
  s.license          = { :file => '../LICENSE' }
  s.author           = 'winterzxzz'
  s.source           = { :path => '.' }
  s.source_files = 'photo_library_kit/Sources/photo_library_kit/**/*.swift'
  s.dependency 'Flutter'
  s.frameworks = 'Photos', 'PhotosUI', 'UIKit', 'UniformTypeIdentifiers'
  s.platform = :ios, '15.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.9'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  s.resource_bundles = {'photo_library_kit_privacy' => ['photo_library_kit/Sources/photo_library_kit/PrivacyInfo.xcprivacy']}
end
