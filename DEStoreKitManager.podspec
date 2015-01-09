Pod::Spec.new do |s|

  s.name         = "DEStoreKitManager"
  s.version      = "0.1"
  s.summary      = "iOS StoreKit Convenience Manager"

  s.homepage     = "https://github.com/dreamengine/DEStoreKitManager"

  s.license      = { :type => "MIT", :file => "LICENSE" }

  s.author             = { "Dream Engine" => "contact@dreamengine.com" }

  s.platform     = :ios, '7.0'

  s.source       = { :git => "https://github.com/dreamengine/DEStoreKitManager.git", :tag => "0.1" }

  s.source_files  = "DEStoreKitManager.{h,m}"

  s.requires_arc = true

end
