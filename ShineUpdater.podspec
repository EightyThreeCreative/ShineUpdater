Pod::Spec.new do |s|
  s.name         = "ShineUpdater"
  s.version      = "1.2.2"
  s.summary      = "An Enterprise app update framework for iOS"
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.author       = { "Cory Imdieke" => "cimdieke@eightythreecreative.com" }
  s.homepage	 = "http://www.eightythreecreative.com"

  s.source = { :git => 'https://github.com/EightyThreeCreative/ShineUpdater.git', :tag => s.version }

  s.platform = :ios
  s.ios.deployment_target = '9.3'
  s.swift_version = '4.1'

  s.source_files = 'Shine/**/*.{swift}'

  s.ios.frameworks = 'UIKit', 'Foundation'

  s.dependency 'SWXMLHash', '~> 4.6.0'

end
