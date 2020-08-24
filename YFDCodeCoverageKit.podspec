Pod::Spec.new do |s|
  s.name = 'YFDCodeCoverageKit'
  s.version = '0.6.0'
  s.summary = 'Automatically collect code coverage data being executed.'
  s.description = <<-DESC
Automatically collect code coverage data being executed.
U can find more info on the official website `coco.zhenguanyu.com`.
                     DESC

  s.homepage = 'https://gerrit.zhenguanyu.com/admin/repos/ios-module-YFDCodeCoverageKit'
  s.license = { :type => "Private", :text => "Private project" }
  s.author = { 'lixinbj05' => 'lixinbj05@fenbi.com' }
  s.source = { :git => 'ssh://gerrit.zhenguanyu.com:29418/ios-module-YFDCodeCoverageKit', :tag => s.version.to_s }

  s.ios.deployment_target = '9.0'
  s.source_files = 'Sources/**/*'
  s.exclude_files = 'Sources/**/*.plist'
  s.swift_version = '5.2'

  s.dependency 'Alamofire', '~> 4.9'
end
