#if HUME_WIDGET
  import AVFAudio
  import Foundation

  final class AudioSessionNotificationHandler {
    typealias RouteChangeHandler = (AVAudioSession.RouteChangeReason) -> Void
    typealias InterruptionBeganHandler = () -> Void
    typealias InterruptionEndedHandler = (Bool) -> Void
    typealias EngineConfigurationChangedHandler = () -> Void

    private var observers: [NSObjectProtocol] = []
    private let notificationCenter: NotificationCenter

    private let onRouteChange: RouteChangeHandler?
    private let onInterruptionBegan: InterruptionBeganHandler?
    private let onInterruptionEnded: InterruptionEndedHandler?
    private let onEngineConfigurationChanged: EngineConfigurationChangedHandler?

    init(
      notificationCenter: NotificationCenter = .default,
      onRouteChange: RouteChangeHandler? = nil,
      onInterruptionBegan: InterruptionBeganHandler? = nil,
      onInterruptionEnded: InterruptionEndedHandler? = nil,
      onEngineConfigurationChanged: EngineConfigurationChangedHandler? = nil
    ) {
      self.notificationCenter = notificationCenter
      self.onRouteChange = onRouteChange
      self.onInterruptionBegan = onInterruptionBegan
      self.onInterruptionEnded = onInterruptionEnded
      self.onEngineConfigurationChanged = onEngineConfigurationChanged
    }

    func register() {
      unregister()

      let center = notificationCenter

      let routeObserver = center.addObserver(
        forName: AVAudioSession.routeChangeNotification,
        object: nil,
        queue: nil
      ) { [weak self] notification in
        self?.handleRouteChange(notification)
      }
      observers.append(routeObserver)

      let interruptionObserver = center.addObserver(
        forName: AVAudioSession.interruptionNotification,
        object: nil,
        queue: nil
      ) { [weak self] notification in
        self?.handleInterruption(notification)
      }
      observers.append(interruptionObserver)

      let engineObserver = center.addObserver(
        forName: .AVAudioEngineConfigurationChange,
        object: nil,
        queue: nil
      ) { [weak self] _ in
        self?.onEngineConfigurationChanged?()
      }
      observers.append(engineObserver)
    }

    func unregister() {
      guard !observers.isEmpty else { return }
      observers.forEach { notificationCenter.removeObserver($0) }
      observers.removeAll()
    }

    private func handleRouteChange(_ notification: Notification) {
      guard let rawReason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
        let reason = AVAudioSession.RouteChangeReason(rawValue: rawReason)
      else {
        Logger.warn("Route change reason is missing")
        return
      }
      onRouteChange?(reason)
    }

    private func handleInterruption(_ notification: Notification) {
      Logger.debug("Interruption notification received")
      guard let userInfo = notification.userInfo,
        let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
        let type = AVAudioSession.InterruptionType(rawValue: typeValue)
      else {
        return
      }
      switch type {
      case .began:
        onInterruptionBegan?()
      case .ended:
        guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else {
          return
        }
        let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
        onInterruptionEnded?(options.contains(.shouldResume))
      @unknown default:
        Logger.warn("Unhandled interruption type: \(type)")
      }
    }

    deinit {
      unregister()
    }
  }
#endif
