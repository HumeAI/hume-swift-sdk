#if HUME_IOS
  //
  //  VoiceProviderStateActor.swift
  //  Hume
  //
  //  Created by Chris on 11/17/25.
  //

  import Combine
  import Foundation

  public actor VoiceProviderStateActor {
    private var state: VoiceProviderState = .disconnected {
      didSet {
        Task { await MainActor.run { [state] in stateSubject.send(state) } }
      }
    }
    internal let stateSubject: CurrentValueSubject<VoiceProviderState, Never>

    private var waiters: [VoiceProviderState: [CheckedContinuation<Void, Never>]] = [:]

    public init() {
      self.stateSubject = CurrentValueSubject<VoiceProviderState, Never>(state)
    }

    public func getState() -> VoiceProviderState {
      state
    }

    public func transition(to newState: VoiceProviderState) {
      Logger.debug("VoiceProvider transitioning from \(state) to \(newState)")
      guard isValidTransition(from: state, to: newState) else {
        assertionFailure("Invalid VoiceProvider state transition: \(state) → \(newState)")
        return
      }

      state = newState

      // Resume any waiters waiting for this state
      if var continuations = waiters[newState] {
        waiters[newState] = nil
        for continuation in continuations {
          continuation.resume()
        }
      }
    }

    public func waitUntil(_ target: VoiceProviderState) async {
      if state == target { return }

      await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
        waiters[target, default: []].append(continuation)
      }
    }

    private func isValidTransition(from: VoiceProviderState, to: VoiceProviderState) -> Bool {
      switch (from, to) {
      case (.disconnected, .connecting),
        (.connecting, .connected),
        (.connecting, .disconnected),
        (.connecting, .disconnecting),
        (.connected, .disconnecting),
        (.disconnecting, .disconnected):
        return true

      default:
        return false
      }
    }
  }
#endif
