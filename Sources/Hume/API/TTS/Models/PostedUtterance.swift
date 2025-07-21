
public struct PostedUtterance: Codable, Hashable {
    public let description: String?
    public let speed: Double?
    public let text: String
    public let trailingSilence: Double?
    public let voice: PostedUtteranceVoice?
    
    /// An Utterance is a unit of input for Octave, and includes input text, an optional description to serve as the prompt for how the speech should be delivered, an optional voice specification, and additional controls to guide delivery for speed and trailing_silence.
    ///
    /// - Parameters:
    ///   - text: Required. The input text to be synthesized into speech. Must be ≤5000 characters.
    ///   - description: Optional. Natural language instructions describing how the speech should sound, such as tone, intonation, pacing, and accent. Max 1000 characters.
    ///     - If a voice is specified, this acts as acting directions. For best results, keep this under 100 characters.
    ///     - If no voice is specified, this acts as a prompt to generate a voice. See our voice prompting guide for design tips.
    ///   - speed: Optional. A multiplier controlling the speech rate. Defaults to 1. Valid range is 0.25–3.
    ///   - trailingSilence: Optional. Duration (in seconds) of silence to append after the utterance. Defaults to 0.35. Valid range is 0–5.
    ///   - voice: Optional. Voice object referencing a voice ID or name from the Voice Library. If provided, this voice will be used until another is specified. See our [voices guide](https://dev.hume.ai/docs/text-to-speech-tts/voices) for more details on generating and specifying Voices.
    public init(
        description: String? = nil,
        speed: Double? = nil,
        text: String,
        trailingSilence: Double? = nil,
        voice: PostedUtteranceVoice? = nil
    ) {
        self.description = description
        self.speed = speed
        self.text = text
        self.trailingSilence = trailingSilence
        self.voice = voice
    }
}
