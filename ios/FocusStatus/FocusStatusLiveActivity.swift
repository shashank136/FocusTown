import ActivityKit
import SwiftUI
import WidgetKit

private extension FocusActivityAttributes.ContentState {
  var heading: String {
    title == "repair" ? "Repairing a ruin" : "Building a \(title)"
  }

  var detail: String {
    away ? "Away: come back soon" : "Builders working"
  }

  var icon: String { away ? "pause.circle.fill" : "hammer.fill" }

  // `timerInterval` needs a valid range even after the planned end.
  var countdown: ClosedRange<Date> {
    let now = Date()
    return now...max(now, endsAt)
  }
}

struct FocusStatusLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: FocusActivityAttributes.self) { context in
      LockScreenView(state: context.state)
        .padding()
        .activityBackgroundTint(Color.black.opacity(0.75))
        .activitySystemActionForegroundColor(.white)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Image(systemName: context.state.icon).font(.title2)
        }
        DynamicIslandExpandedRegion(.trailing) {
          Text(timerInterval: context.state.countdown, countsDown: true)
            .monospacedDigit()
            .font(.title2)
            .frame(maxWidth: 90, alignment: .trailing)
        }
        DynamicIslandExpandedRegion(.bottom) {
          Text("\(context.state.heading) · \(context.state.detail)")
            .font(.footnote)
        }
      } compactLeading: {
        Image(systemName: context.state.icon)
      } compactTrailing: {
        Text(timerInterval: context.state.countdown, countsDown: true)
          .monospacedDigit()
          .frame(maxWidth: 48)
      } minimal: {
        Image(systemName: context.state.icon)
      }
    }
  }
}

private struct LockScreenView: View {
  let state: FocusActivityAttributes.ContentState

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: state.icon)
        .font(.title)
      VStack(alignment: .leading, spacing: 2) {
        Text(state.heading).font(.headline)
        Text(state.detail).font(.subheadline).opacity(0.8)
      }
      Spacer()
      Text(timerInterval: state.countdown, countsDown: true)
        .monospacedDigit()
        .font(.title)
        .frame(maxWidth: 110, alignment: .trailing)
    }
    .foregroundColor(.white)
  }
}
