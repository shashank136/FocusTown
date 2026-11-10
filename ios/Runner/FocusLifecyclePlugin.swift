import CallKit
import Flutter
import UIKit

/// Bridges lock, background, foreground, calls and uptime to Dart.
///
/// Events go over `focus/lifecycle/events` as `{type, wallMs, uptimeMs}`.
/// `focus/lifecycle` method `uptimeMs` returns the monotonic uptime.
final class FocusLifecyclePlugin: NSObject, FlutterPlugin, FlutterStreamHandler,
  CXCallObserverDelegate
{
  private var sink: FlutterEventSink?
  private var isLocked = false
  private var observers: [NSObjectProtocol] = []
  private let callObserver = CXCallObserver()
  private var activeCalls = Set<UUID>()

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = FocusLifecyclePlugin()
    FlutterEventChannel(
      name: "focus/lifecycle/events",
      binaryMessenger: registrar.messenger()
    ).setStreamHandler(instance)
    let methods = FlutterMethodChannel(
      name: "focus/lifecycle",
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(instance, channel: methods)
    instance.observeApplication()
    instance.callObserver.setDelegate(instance, queue: .main)
  }

  /// Continuous time in ms. Counts device sleep, unlike
  /// `ProcessInfo.systemUptime`, so a locked session is not measured short.
  static func uptimeMs() -> Int {
    Int(clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW) / 1_000_000)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "uptimeMs" {
      result(Self.uptimeMs())
    } else if call.method == "lowPowerMode" {
      result(ProcessInfo.processInfo.isLowPowerModeEnabled)
    } else {
      result(FlutterMethodNotImplemented)
    }
  }

  func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    sink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    return nil
  }

  private func emit(_ type: String) {
    sink?([
      "type": type,
      "wallMs": Int(Date().timeIntervalSince1970 * 1000),
      "uptimeMs": Self.uptimeMs(),
    ])
  }

  /// Ringing and dialing count as a call. Several calls (hold, conference)
  /// make one `callStarted` / `callEnded` pair around the whole group.
  func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) {
    if call.hasEnded {
      if activeCalls.remove(call.uuid) != nil && activeCalls.isEmpty {
        emit("callEnded")
      }
    } else {
      let wasEmpty = activeCalls.isEmpty
      activeCalls.insert(call.uuid)
      if wasEmpty { emit("callStarted") }
    }
  }

  private func emitLocked() {
    // One lock must produce one `locked`, however many signals arrive.
    if isLocked { return }
    isLocked = true
    emit("locked")
  }

  private func observeApplication() {
    let center = NotificationCenter.default
    let app = UIApplication.self
    observers = [
      center.addObserver(
        forName: app.protectedDataWillBecomeUnavailableNotification,
        object: nil, queue: .main
      ) { [weak self] _ in self?.emitLocked() },
      center.addObserver(
        forName: app.protectedDataDidBecomeAvailableNotification,
        object: nil, queue: .main
      ) { [weak self] _ in
        self?.isLocked = false
        self?.emit("unlocked")
      },
      center.addObserver(
        forName: app.didEnterBackgroundNotification,
        object: nil, queue: .main
      ) { [weak self] _ in
        // A locked device means the lock came first; order the events so.
        if !UIApplication.shared.isProtectedDataAvailable {
          self?.emitLocked()
        }
        self?.emit("backgrounded")
      },
      center.addObserver(
        forName: app.willEnterForegroundNotification,
        object: nil, queue: .main
      ) { [weak self] _ in self?.emit("foregrounded") },
    ]
  }

  deinit {
    observers.forEach(NotificationCenter.default.removeObserver)
  }
}
