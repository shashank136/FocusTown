import ActivityKit
import Foundation

/// The lock screen status of a running session. Shared by the app (which
/// starts and updates it) and the FocusStatus extension (which draws it).
struct FocusActivityAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    /// When the session is planned to end; the lock screen counts down to it.
    var endsAt: Date
    /// A tier name, or "repair".
    var title: String
    /// True while the user is away and the builders are waiting.
    var away: Bool
  }
}
