Pod::Spec.new do |s|
  s.name = 'LocationManager'
  s.version = '0.2'
  s.license = 'Unlicensed'
  s.summary = 'Location updating and reverse geo coding made easy'
  s.homepage = 'https://github.com/jensgrud/LocationManager'
  s.authors = { 'Jens Grud' => 'jens@heapsapp.com' }
  s.source = { :git => 'https://github.com/jensgrud/LocationManager.git', :tag => s.version }

  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.10'

  s.source_files = '*.swift'
  s.requires_arc = true
end