# test_face_detaction

A new Flutter project.

## 2. Modify Your `ios/Podfile`

Inside the target `Runner` do block, add the native C API pod:

```ruby
pod 'TensorFlowLiteC'
```

Your `Podfile` should look like this:

```ruby
platform :ios, '16.0'

target 'Runner' do
  use_frameworks!

  flutter_install_all_ios_pods(File.dirname(File.realpath(__FILE__)))

  # Native TensorFlow Lite C API
  pod 'TensorFlowLiteC'

  target 'RunnerTests' do
    inherit! :search_paths
  end
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)

    # Ensure deployment target is respected
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '16.0'
    end
  end
end
```

---

## 3. Set Strip Style in Xcode (**Critical**)

This is required to prevent iOS from removing needed native symbols during release builds.

1. Open `ios/Runner.xcworkspace` in Xcode  
2. Select **Runner project** → **Build Settings**  
3. Search for **Strip Style**  
4. Change:

```
All Symbols → Non-Global Symbols
```

---

## 4. Clean and Rebuild

```bash
flutter clean
flutter pub get

cd ios
rm -rf Pods Podfile.lock
pod install
cd ..

flutter build ios --release
```

