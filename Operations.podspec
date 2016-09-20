Pod::Spec.new do |s|
  s.name              = "Operations"
  s.version           = "3.0.4"
  s.summary           = "Powerful NSOperation subclasses in Swift."
  s.description       = <<-DESC
  
A Swift framework inspired by Apple's WWDC 2015
session Advanced NSOperations: https://developer.apple.com/videos/wwdc/2015/?id=226

                       DESC
  s.homepage          = "https://github.com/cezarywojcik/Operations"
  s.license           = 'MIT'
  s.author            = { "Daniel Thorpe" => "@danthorpe" }
  s.source            = { :git => "https://github.com/cezarywojcik/Operations.git", :tag => s.version.to_s }
  s.module_name       = 'Operations'
  s.documentation_url = 'http://docs.danthorpe.me/operations/2.10.0/index.html'
  s.social_media_url  = 'https://twitter.com/danthorpe'
  s.requires_arc      = true
  s.ios.deployment_target = '8.0'
  s.watchos.deployment_target = '2.0'
  s.tvos.deployment_target = '9.0'
  s.osx.deployment_target = '10.10'

  # Defaul spec is 'Standard'
  s.default_subspec   = 'Standard'

  # Creates a framework suitable for an iOS, watchOS, tvOS or Mac OS application
  s.subspec 'Standard' do |ss|
    ss.source_files = [
      'Sources/Core/Shared', 
      'Sources/Core/iOS'
    ]
    ss.watchos.exclude_files = [
      'Sources/Core/iOS'
    ]
    ss.osx.exclude_files = [
      'Sources/Core/iOS'
    ]
  end

end


