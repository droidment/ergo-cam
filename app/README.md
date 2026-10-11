# ErgoCam app

Flutter app for ErgoCam. Project overview and rules: [`../CLAUDE.md`](../CLAUDE.md).

```bash
flutter pub get
flutter run        # physical device required (camera)
flutter analyze
flutter test
```

## Permissions
Camera only. The camera plugin declares `RECORD_AUDIO`; it is stripped in
`android/app/src/main/AndroidManifest.xml` (`tools:node="remove"`), so any
`CameraController` must be created with `enableAudio: false`.

`permission_handler` is pinned to `^12.0.3`: 13.x pulls `permission_handler_android`
14.x, which compiles against Android SDK 37 and fails with AGP 9.1
(`Failed to find target with hash string 'android-37'`). Revisit when AGP is bumped.

### iOS (secondary target)
`NSCameraUsageDescription` is set in `ios/Runner/Info.plist`. The `Podfile` is
generated on first build on a Mac; after that, enable only the camera permission
for `permission_handler` by adding to its `post_install` block:

```ruby
target.build_configurations.each do |config|
  config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= ['$(inherited)', 'PERMISSION_CAMERA=1']
end
```
