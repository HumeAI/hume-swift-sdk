## Build and Test Commands

```bash
# Build for iOS device  
swift build --triple arm64-apple-ios --sdk $(xcrun --sdk iphoneos --show-sdk-path)

# Run all tests on an available iOS Simulator
# Replace "iPhone 16 Pro" with the name of a simulator available on your machine.
# You can list available simulators with `xcrun simctl list devices`
xcodebuild test -scheme Hume-Package -destination 'platform=iOS Simulator,name=iPhone 16 Pro'

# Run a specific test
swift test --filter HumeTests.HumeClientTests/test_empathicVoice_returnsLazily --triple arm64-apple-ios --sdk $(xcrun --sdk iphoneos --show-sdk-path)

# Lint the podspec
pod lib lint --allow-warnings
```

### Creating a new simulator

If you don't have a simulator available, you can create one with the following command:
```bash
xcrun simctl create "My iPhone" com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro
```
You can then use `"My iPhone"` as the name of the simulator in the test command.