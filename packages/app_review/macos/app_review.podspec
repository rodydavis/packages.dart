#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint app_review.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'app_review'
  s.version          = '0.0.1'
  s.summary          = 'Request and Write Reviews and Open Store Listing for Android/iOS/macOS in Flutter.'
  s.description      = <<-DESC
Request and Write Reviews and Open Store Listing for Android/iOS/macOS in Flutter.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'FlutterMacOS'

  s.platform = :osx, '10.14'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
