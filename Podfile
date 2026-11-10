platform :ios, '26.0'

target 'Fee Calculator For Paypal Fees' do
  use_frameworks!

  pod 'Google-Mobile-Ads-SDK', '~> 13.0'
  pod 'GoogleUserMessagingPlatform', '~> 3.0'

  post_install do |installer|
    installer.pods_project.targets.each do |target|
      target.build_configurations.each do |config|
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '26.0'
      end
    end
  end
end
