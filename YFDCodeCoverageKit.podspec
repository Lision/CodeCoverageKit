Pod::Spec.new do |s|
  s.name             = 'YFDCodeCoverageKit'
  s.version          = '0.1.0'
  s.summary          = 'Automatically collect code coverage data being executed.'
  s.description      = <<-DESC
Automatically collect code coverage data being executed.
                       DESC

  s.homepage         = 'https://gerrit.zhenguanyu.com/admin/repos/ios-module-YFDCodeCoverageKit'
  s.license          = { :type => "Private", :text => "Private project" }
  s.author           = { 'lixinbj05' => 'lixinbj05@fenbi.com' }
  s.source           = { :git => 'ssh://gerrit.zhenguanyu.com:29418/ios-module-YFDCodeCoverageKit', :tag => s.version.to_s }

  s.ios.deployment_target = '9.0'
  s.source_files = 'Sources/**/*'

end
