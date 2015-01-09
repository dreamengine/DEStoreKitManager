Pod::Spec.new do |s|

  s.name         = "DEStoreKitManager"
  s.version      = "0.1"
  s.summary      = "iOS StoreKit Convenience Manager"

  s.homepage     = "https://github.com/dreamengine/DEStoreKitManager"

  s.license      = { :type => "MIT", :file => "LICENSE" }

  s.author             = { "Dream Engine" => "contact@dreamengine.com" }

  s.platform     = :ios

  s.source       = { :git => "https://github.com/dreamengine/DEStoreKitManager.git", :commit => "4088e37118a8a394fde99c2d7f44290cd20d5e15" }

  s.source_files  = "DEStoreKitManager.{h,m}"

  s.requires_arc = false

end
