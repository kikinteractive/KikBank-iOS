Pod::Spec.new do |s|

  s.name         = "KikBank"
  s.version      = "0.0.1"
  s.summary      = "URL Data fetch and cache framework"

  s.description  = <<-DESC
                   "Kik Bank is a basic URL -> Data fetch and cache framework based around RxSwift"
                   DESC

  s.homepage     = "https://github.com/kikinteractive/KikBank-iOS"
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.author       = { "JamesRagnar" => "2214827+JamesRagnar@users.noreply.github.com" }
  s.source       = { :git => "https://github.com/kikinteractive/KikBank-iOS.git", :tag => s.version.to_s }

  s.ios.deployment_target = '8.0'
  s.platform = :ios, '8.0'
  s.swift_version = '4.0'

  s.source_files  = "Classes", "KikBank/Classes/*.{h,m,swift}"

  s.dependency 'RxSwift', '~> 4.0'

end
