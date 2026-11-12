import ActivityKit
import Flutter

/// Shows the running session on the lock screen as a Live Activity.
///
/// `focus/liveStatus` method `show` takes `{endsAtMs, title, away}` and starts
/// the activity or updates the one that is showing. Method `end` removes it.
final class LiveStatusPlugin: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "focus/liveStatus",
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(LiveStatusPlugin(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "show":
      guard let args = call.arguments as? [String: Any],
        let ms = args["endsAtMs"] as? Int,
        let title = args["title"] as? String,
        let away = args["away"] as? Bool
      else {
        result(FlutterError(code: "bad_args", message: nil, details: nil))
        return
      }
      let state = FocusActivityAttributes.ContentState(
        endsAt: Date(timeIntervalSince1970: Double(ms) / 1000),
        title: title,
        away: away
      )
      Task {
        await Self.show(state)
        result(nil)
      }
    case "end":
      Task {
        await Self.end()
        result(nil)
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // The user can turn Live Activities off; then there is nothing to show.
  private static func show(_ state: FocusActivityAttributes.ContentState) async {
    guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
    let content = ActivityContent(
      state: state,
      staleDate: state.endsAt.addingTimeInterval(60)
    )
    if let current = Activity<FocusActivityAttributes>.activities.first {
      await current.update(content)
    } else {
      _ = try? Activity.request(
        attributes: FocusActivityAttributes(),
        content: content
      )
    }
  }

  private static func end() async {
    for activity in Activity<FocusActivityAttributes>.activities {
      await activity.end(nil, dismissalPolicy: .immediate)
    }
  }
}
