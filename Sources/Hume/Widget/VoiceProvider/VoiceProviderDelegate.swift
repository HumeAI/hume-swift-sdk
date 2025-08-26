#if HUME_WIDGET
  //
  //  VoiceProviderDelegate.swift
  //  Hume
  //
  //  Created by Chris on 6/12/25.
  //

  import Foundation

  /// All methods in this protocol have default empty implementations via an extension, so conformers may override only those they need.
  public protocol VoiceProviderDelegate: AnyObject {
    func voiceProvider(_ voiceProvider: any VoiceProvidable, didProduceEvent event: SubscribeEvent)
    func voiceProvider(
      _ voiceProvider: any VoiceProvidable, didProduceError error: VoiceProviderError)
    /// Handler for meter data from the microphone. Note: This is disabled. TODO: make it configurable to set this
    func voiceProvider(
      _ voiceProvider: any VoiceProvidable, didReceieveAudioInputMeter audioInputMeter: Float)
    func voiceProvider(
      _ voiceProvider: any VoiceProvidable, didReceieveAudioOutputMeter audioInputMeter: Float)

    /// Voice provider is about to disconnect. This is called before the provider is disconnected.
    func voiceProviderWillDisconnect(_ voiceProvider: any VoiceProvidable)
    /// Called when the provider has disconnected and is no longer available.
    func voiceProviderDidDisconnect(_ voiceProvider: any VoiceProvidable)
    /// Called when the provider has connected and is ready for use.
    func voiceProviderDidConnect(_ voiceProvider: any VoiceProvidable)
    /// Called when a sound clip is played.
    func voiceProvider(_ voiceProvider: any VoiceProvidable, didPlayClip clip: SoundClip)
  }

  extension VoiceProviderDelegate {
    public func voiceProvider(
      _ voiceProvider: any VoiceProvidable, didProduceEvent event: SubscribeEvent
    ) {}
    public func voiceProvider(
      _ voiceProvider: any VoiceProvidable, didProduceError error: VoiceProviderError
    ) {}
    public func voiceProvider(
      _ voiceProvider: any VoiceProvidable, didReceieveAudioInputMeter audioInputMeter: Float
    ) {}
    public func voiceProvider(
      _ voiceProvider: any VoiceProvidable, didReceieveAudioOutputMeter audioInputMeter: Float
    ) {}
    public func voiceProviderWillDisconnect(_ voiceProvider: any VoiceProvidable) {}
    public func voiceProviderDidDisconnect(_ voiceProvider: any VoiceProvidable) {}
    public func voiceProviderDidConnect(_ voiceProvider: any VoiceProvidable) {}
    public func voiceProvider(_ voiceProvider: any VoiceProvidable, didPlayClip clip: SoundClip) {}
  }
#endif
