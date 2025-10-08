import Foundation

/// Enumeration of possible errors that might occur while using ``StreamSocket``.
public enum StreamSocketError: String, Error {
  case connectionError
  case transportError
  case encodingError
  case decodingError
  case disconnected
  case closed
}

public class StreamSocket {

  // The underlying websocket connection
  private let webSocketTask: URLSessionWebSocketTask

  // TODO: Expose these to be configurable
  private let encoder: JSONEncoder = Defaults.encoder
  private let decoder: JSONDecoder = Defaults.decoder

  internal init(webSocketTask: URLSessionWebSocketTask) {
    self.webSocketTask = webSocketTask

    // Make sure the websocket is up and running, if not already.
    self.webSocketTask.resume()
  }

  deinit {
    // Make sure to cancel the WebSocketTask (if not already canceled or completed)
    self.close()
  }

  /**
     * Send raw data (such as audio bytes)
     */
  public func sendData(message: Data) async throws {
    try await sendData(message)
  }

  /**
     * Send audio input
     */
  public func sendAudioInput(message: AudioInput) async throws {
    try await send(message)
  }

  /**
     * Send session settings
     */
  public func sendSessionSettings(message: SessionSettings) async throws {
    try await send(message)
  }

  /**
     * Send assistant input
     */
  public func sendAssistantInput(message: AssistantInput) async throws {
    try await send(message)
  }

  /**
     * Send pause assistant message
     */
  public func pauseAssistant(message: PauseAssistantMessage) async throws {
    try await send(message)
  }

  /**
     * Send resume assistant message
     */
  public func resumeAssistant(message: ResumeAssistantMessage) async throws {
    try await send(message)
  }

  /**
     Send text input
     */
  public func sendTextInput(text: String) async throws {
    try await send(UserInput(text: text))
  }

  private func receiveSingleMessage() async throws -> SubscribeEvent {
    switch try await webSocketTask.receive() {
    case .data:
      assertionFailure("Did not expect to receive message as data")
      throw StreamSocketError.decodingError

    case .string(let text):
      guard
        let messageData = text.data(using: .utf8)
      else {
        throw StreamSocketError.decodingError
      }

      guard let event = try? decoder.decode(SubscribeEvent.self, from: messageData) else {
        throw StreamSocketError.decodingError
      }
      return event

    @unknown default:
      assertionFailure("Unknown message type")

      // Unsupported data, closing the WebSocket Connection
      webSocketTask.cancel(with: .unsupportedData, reason: nil)
      throw StreamSocketError.decodingError
    }
  }

  public func receiveOnce() async throws -> SubscribeEvent {
    do {
      return try await receiveSingleMessage()
    } catch let error as StreamSocketError {
      throw error
    } catch {
      switch webSocketTask.closeCode {
      case .invalid:
        throw StreamSocketError.connectionError

      case .goingAway:
        throw StreamSocketError.disconnected

      case .normalClosure:
        throw StreamSocketError.closed

      default:
        throw StreamSocketError.transportError
      }
    }
  }

  public func receive() -> AsyncThrowingStream<SubscribeEvent, Error> {
    AsyncThrowingStream { [weak self] in
      guard let self = self else {
        // Self is gone, return nil to end the stream
        return nil
      }

      let message = try await self.receiveOnce()
      // End the stream (by returning nil) if the calling Task was canceled
      return Task.isCancelled || webSocketTask.state != .running ? nil : message
    }
  }

  /**
     * Closes the underlying socket.
     */
  func close() {
    Logger.info("Closing socket")
    guard webSocketTask.state == .running else {
      Logger.debug("socket already closed")
      return
    }
    webSocketTask.cancel(with: .normalClosure, reason: nil)
    Logger.info("Socket is closed")
  }

  // MARK: - Private Functions -
  private func send(_ message: Codable) async throws {
    Logger.info("Sending message: \(message)")
    guard
      let messageData = try? encoder.encode(message),
      let jsonString = String(data: messageData, encoding: .utf8)
    else {
      throw StreamSocketError.encodingError
    }

    try await self.sendSocketMessage(.string(jsonString))
  }

  private func sendData(_ message: Data) async throws {
    try await self.sendSocketMessage(.data(message))
  }

  private func sendSocketMessage(_ message: URLSessionWebSocketTask.Message) async throws {
    do {
      try await webSocketTask.send(message)
    } catch {
      Logger.debug("Close code: \(String(describing: webSocketTask.closeCode))")
      switch webSocketTask.closeCode {
      case .invalid:
        Logger.error("Socket connection error", error)
        throw StreamSocketError.connectionError

      case .goingAway:
        throw StreamSocketError.disconnected

      case .normalClosure:
        throw StreamSocketError.closed

      default:
        Logger.error("Stream socket transport error", error)
        throw StreamSocketError.transportError
      }
    }
  }

}
