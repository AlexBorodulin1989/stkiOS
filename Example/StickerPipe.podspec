
Pod::Spec.new do |s|

  s.name            = 'Stickerpipe'
  s.version         = '0.2.8'
  s.platform        = :ios, '7.0'
  s.summary         = 'Easy stickers SDK for integration in messangers.'
  s.homepage        = "https://github.com/908Inc/stkiOS"
  s.license         = "Apache License, Version 2.0"
  s.author          = "908 Inc."
  s.source          = { :git => 'https://github.com/908Inc/stkiOS.git', :tag => s.version }
  s.source_files    = "Stickerpipe/SDK/*.{h,m}"

  s.framework       = 'CoreData'
  s.requires_arc    = true
  s.dependency       'AFNetworking', '~> 2.0'
  s.dependency       'DFImageManager', '~> 0.5.0'
  s.dependency       'MD5Digest', '~> 1.1'
  s.dependency       'RMStore', '~> 0.7'
  s.dependency       'RMStore/KeychainPersistence'
  s.dependency       'RMStore/NSUserDefaultsPersistence'
  s.dependency       'SDWebImage', '~> 3.7'

  s.resources       = ['StickerPipe/SDK/Media.xcassets', 'ResBundle/*.{xcdatamodeld}','ResBundle/StickerPipe.xcassets', 'ResBundle/*.xib']

end