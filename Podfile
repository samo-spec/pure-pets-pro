platform :ios, '13.0'
#A8FA0353-3356-456B-9AF3-46DD11AB9108
target 'PurePetsPro' do
  
  use_frameworks! :linkage => :static
  #inhibit_all_warnings!
  pod 'YYKit', :inhibit_warnings => true
  pod 'FirebaseInstallations'

  # ===== Auth: Google Sign-In =====
  pod 'GoogleSignIn', '8.0.0'

  # ===== Firebase =====
  pod 'Firebase/Core'
  pod 'Firebase/Auth'
  pod 'FirebaseAppCheck'
   pod 'Firebase/Firestore'
  pod 'Firebase/Storage'
  pod 'Firebase/Messaging'

  # ===== UI & Media =====
  pod 'SDWebImage'
  pod 'lottie-ios', '~> 2.5.3'
  pod 'XLForm'
  pod 'IQKeyboardManager'
  
  
  pod 'SSZipArchive'
  pod 'PopupDialog', '~> 1.1'
  pod 'Firebase/Functions'

  pod 'ShowTime'
     
  pod 'JGProgressHUD'
  pod 'JDStatusBarNotification'
  pod 'TOCropViewController'
  pod 'YesWeScan'
  
end

post_install do |installer|
  admin_header_paths = [
    '${PODS_ROOT}/XLForm/XLForm/XL',
    '${PODS_ROOT}/XLForm/XLForm/XL/**',
    '${PODS_ROOT}/HXPhotoPickerObjC/HXPhotoPicker',
    '${PODS_ROOT}/HXPhotoPickerObjC/HXPhotoPicker/**',
    '${PODS_ROOT}/TOCropViewController/Objective-C/TOCropViewController',
    '${PODS_ROOT}/TOCropViewController/Objective-C/TOCropViewController/**',
    '${PODS_ROOT}/JGProgressHUD/JGProgressHUD/JGProgressHUD/include',
    '${PODS_ROOT}/YYKit/YYKit',
    '${PODS_ROOT}/YYKit/YYKit/**',
    '${PODS_ROOT}/SSZipArchive/SSZipArchive',
    '${PODS_ROOT}/SSZipArchive/SSZipArchive/**',
    '${PODS_ROOT}/SDWebImage/SDWebImage/Core',
    '${PODS_ROOT}/SDWebImage/SDWebImage/Core/**',
    '${PODS_ROOT}/SDWebImage/WebImage',
    '${PODS_ROOT}/lottie-ios/lottie-ios/Classes/PublicHeaders',
    '${PODS_ROOT}/lottie-ios/lottie-ios/Classes/PublicHeaders/**',
    '${PODS_ROOT}/FirebaseCore/FirebaseCore/Sources/Public/FirebaseCore',
    '${PODS_ROOT}/FirebaseMessaging/FirebaseMessaging/Sources/Public/FirebaseMessaging',
    '${PODS_ROOT}/FirebaseAuth/FirebaseAuth/Sources/Public/FirebaseAuth'
  ]

  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
      # YYKit bundles an old WebP.framework that lacks a simulator arm64 slice.
      # Keep simulator builds on x86_64 so the vendored binary can still link.
      config.build_settings["EXCLUDED_ARCHS[sdk=iphonesimulator*]"] = 'arm64'
    end
    # Suppress chained-comparison error in YYKit (unmaintained pod)
    if target.name == 'YYKit'
      target.build_configurations.each do |config|
        flags = config.build_settings['OTHER_CFLAGS'] || '$(inherited)'
        unless flags.include?('-Wno-parentheses')
          config.build_settings['OTHER_CFLAGS'] = "#{flags} -Wno-parentheses"
        end
      end
    end
    # Fix FirebaseFirestore-Swift.h not found (Xcode 16+)
    if target.name == 'FirebaseFirestore'
      target.build_configurations.each do |config|
        config.build_settings['SWIFT_INSTALL_OBJC_HEADER'] = 'NO'
      end
    end
  end

  # Strip -weak_framework flags for statically-linked pods that are already
  # referenced via -framework. The classic linker crashes (dylibToOrdinal
  # assertion) when a static framework appears as both -framework and
  # -weak_framework.
  Dir.glob(File.join(installer.sandbox.root,
           'Target Support Files', '**', '*.xcconfig')) do |xcconfig_path|
    content = File.read(xcconfig_path)
    if content.include?('-weak_framework "FirebaseFirestoreInternal"')
      content.gsub!(' -weak_framework "FirebaseFirestoreInternal"', '')
      File.write(xcconfig_path, content)
    end
  end

  installer.aggregate_targets.each do |aggregate_target|
    user_project = aggregate_target.user_project
    user_project.native_targets.each do |target|
      next unless ['PurePetsPro', 'PurePetsProTests', 'PurePetsProUITests'].include?(target.name)

      target.build_configurations.each do |config|
        existing = config.build_settings['HEADER_SEARCH_PATHS']
        existing = ['$(inherited)'] if existing.nil?
        existing = [existing] unless existing.is_a?(Array)

        config.build_settings['HEADER_SEARCH_PATHS'] = (existing + admin_header_paths).uniq
        config.build_settings["EXCLUDED_ARCHS[sdk=iphonesimulator*]"] = 'arm64'
      end
    end
    user_project.save
  end
end
