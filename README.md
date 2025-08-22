<div align="center">
  <img src="https://storage.googleapis.com/hume-public-logos/hume/hume-banner.png">
  <h1>Hume AI Swift SDK</h1>

  <p>
    <strong>Integrate Hume APIs directly into your Swift application</strong>
  </p>
</div>

## Documentation

API reference documentation is available [here](https://dev.hume.ai/reference/).

## Installation

Add to your `Package.swift`

```
    dependencies: [
        .package(url: "https://github.com/HumeAI/hume-swift-sdk.git", from: "x.x.x")
    ]
```

**Supported Platforms:** iOS 16+, macOS 12+, and Linux

## Usage

The SDK provides a `VoiceProvider` abstraction that you can use to directly integrate
with microphones. 

```swift
import Hume

let token = try await myAccessTokenClient.fetchAccessToken()
humeClient = HumeClient(options: .accessToken(token: token))

let voiceProvider = VoiceProvider(client: humeClient)
voiceProvider.delegate = myDelegate

// Request permission to record audio. Be sure to add `Privacy - Microphone Usage Description`
// to your Info.plist
let granted = await MicrophonePermission.requestPermissions()
guard granted else { return }

let sessionSettings = SessionSettings(
    systemPrompt: "my optional system prompt",
    variables: ["myCustomVariable": myValue, "datetime": Date().formattedForSessionSettings()])

try await voiceProvider.connect(
    configId: myConfigId,
    configVersion: nil,
    sessionSettings: sessionSettings)

// Sending user text input manually
await self.voiceProvider.sendUserInput(message: "Hey, how are you?")
```

### Listening for VoiceProvider updates
Implement `VoiceProviderDelegate` methods to be notified of events, errors, meter data, state, etc.  


## Beta Status
This SDK is in beta, and there may be breaking changes between versions without a major 
version update. Therefore, we recommend pinning the package version to a specific version. 
This way, you can install the same version each time without breaking changes.

### Known Issues and Limitations
- Audio interruptions (e.g. phone calls) are not yet handled.
- Manually starting/stopping `AVAudioSession` will likely break an active voice session.
- Input metering is not yet implemented.

## Build

### Building for iOS
```bash
swift build --triple arm64-apple-ios --sdk $(xcrun --sdk iphoneos --show-sdk-path)
```

### Building for macOS
```bash
swift build --triple x86_64-apple-macosx --sdk $(xcrun --sdk macosx --show-sdk-path)
```

### Building for Linux
```bash
swift build
```

**Platform Support:**
- **iOS**: Full functionality including Widget module (audio processing, microphone handling, TTS playback)
- **macOS**: Core API functionality only (no Widget module)
- **Linux**: Core API functionality only (no Widget module)

**Note:** The Widget module is iOS-specific and contains audio processing, microphone handling, and TTS playback functionality. On macOS and Linux, only the core API functionality (HTTP clients, models, networking) is available.
