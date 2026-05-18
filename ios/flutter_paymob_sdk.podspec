Pod::Spec.new do |s|
  s.name             = 'flutter_paymob_sdk'
  s.version          = '1.0.0'
  s.summary          = 'A Flutter plugin for integrating Paymob payment gateway.'
  s.description      = <<-DESC
A Flutter plugin for integrating Paymob payment gateway with native Android and iOS SDKs support.
                       DESC
  s.homepage         = 'https://github.com/motazyusuf/flutter_paymob_sdk'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Moataz Medhat Yusuf' => 'motazyusuf@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'

  s.vendored_frameworks = 'Frameworks/PaymobSDK.xcframework'

  s.dependency 'Flutter'

  s.platform = :ios, '13.0'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }
  s.swift_version = '5.0'
end
