Pod::Spec.new do |s|
  s.name          = 'ServerlessPushService'
  s.version       = '0.8.1'
  s.summary       = 'Framework to play with the Apple Push Notification service (APNs).'
  s.homepage      = 'https://github.com/PauliusVindzigelskis/ServerlessPushService'
  s.license       = { :type => 'MIT', :file => 'LICENSE' }
  s.author        = { 'Paulius Vindzigelskis' => 'p.vindzigelskis@gmail.com' }

  s.ios.deployment_target = '11.0'
  s.requires_arc  = true
  s.source        = { :git => 'https://github.com/PauliusVindzigelskis/ServerlessPushService.git', :tag => s.version.to_s }
  s.source_files  = 'Source/*.{swift}'
  s.swift_versions= ['4.2', '5.0']
end
