## Build and Test Commands

```bash
# Build for iOS device  
swift build --triple arm64-apple-ios --sdk $(xcrun --sdk iphoneos --show-sdk-path)

# Run all tests on iOS Simulator
xcodebuild test -scheme Hume-Package -destination 'platform=iOS Simulator,name=iPhone 16'

# Run a specific test
swift test --filter HumeTests.HumeClientTests/test_empathicVoice_returnsLazily --triple arm64-apple-ios --sdk $(xcrun --sdk iphoneos --show-sdk-path)
```

