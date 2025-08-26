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

**Adding to your Xcode project**
1. Open project settings > Package Dependencies
2. Click the + button to add a package dependency
3. Enter SDK URL (`https://github.com/HumeAI/hume-swift-sdk.git`)
4. Set the version rule (we recommend pinning to a specific version)
5. Click "Add Package"
6. Add the `Privacy - Microphone Usage Description` entry to your `Info.plist`
7. (Optional) If you plan to support background audio, select the "Audio, Airplay, and Picture and Picture" option in the "Background Modes" section of your project capabilities.

**Adding to your `Package.swift`**

```
    dependencies: [
        .package(url: "https://github.com/HumeAI/hume-swift-sdk.git", from: "x.x.x")
    ]
```

## Usage

### Voice Chat

The SDK provides a [`VoiceProvider`](Sources/Hume/Widget/VoiceProvider/VoiceProvider.swift) abstraction that manages active socket connection against the `/chat` endpoint. This abstraction handles and coordinates the audio stack.

**Capabilities**
- Pipes output audio from `audio_output` events into SoundPlayer to play back in realtime.
- `VoiceProvider.connect(...)` opens and connects to the `/chat`socket, waits for the `chat_metadata` event to be received, and starts the microphone. 
- `VoiceProvider.disconnect()` closes the socket, stops the microphone, and stops all playback.

**Example**
```swift
import Hume

let token = try await myAccessTokenClient.fetchAccessToken()
humeClient = HumeClient(options: .accessToken(token: token))

let voiceProvider = VoiceProvider(client: humeClient)
voiceProvider.delegate = myDelegate

// Request permission to record audio. Be sure to add `Privacy - Microphone Usage Description`
// to your Info.plist

if MicrophonePermission.current == .undetermined {
    let granted = await MicrophonePermission.requestPermissions()
    guard granted else {
        print("user declined mic permsissions")
        return 
    }
} else if MicrophonePermission.current == .denied {
    print("user previously declined mic permissions") // ask user to update in settings
    return 
}

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

#### Listening for `VoiceProvider` updates
Implement [`VoiceProviderDelegate`](Sources/Hume/Widget/VoiceProvider/VoiceProviderDelegate.swift) methods to be notified of events, errors, meter data, state, etc.  


### TTS

**Example**
```swift
import Hume

let token = try await myAccessTokenClient.fetchAccessToken()
humeClient = HumeClient(options: .accessToken(token: token))

let ttsClient = humeClient.tts

let postedUtterances: [PostedUtterance] = [PostedUtterance(
    description: voiceDescription,
    speed: speed,
    trailingSilence: trailingSilence,
    text: text,
    voice: .postedUtteranceVoiceWithId(PostedUtteranceVoiceWithId(id: "<config ID>", provider: .humeAi))
)]
let fmt = .wav(FormatWav()
let request = PostedTts(
    context: nil,
    numGenerations: 1,
    splitUtterances: nil,
    stripHeaders: nil,
    utterances: postedUtterances,
    instantMode: true,
    format: fmt)

let stream = tts.synthesizeFileStreaming(request: request)
for try await data in stream {
    // convert data to SoundClip
    guard let soundClip = SoundClip.from(data) else {
        print("warn: failed to create sound clip")
        return
    }
            
    // play SoundClip with ttsPlayer
    try await ttsPlayer.play(soundClip: soundClip, format: fmt)
    _data.append(data)
    
}
```


## Beta Status
This SDK is in beta, and there may be breaking changes between versions without a major 
version update. Therefore, we recommend pinning the package version to a specific version. 
This way, you can install the same version each time without breaking changes.

### Known Issues and Limitations
- Audio interruptions (e.g. phone calls) are not yet handled.
- Manually starting/stopping `AVAudioSession` will likely break an active voice session. Leave all audio handling to `AudioHub`. If you need to add your own output audio nodes, see `AudioHub.addNode(_:)
- Input metering is not yet implemented.
