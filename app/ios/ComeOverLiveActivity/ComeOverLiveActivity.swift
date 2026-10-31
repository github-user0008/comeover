import ActivityKit
import SwiftUI
import WidgetKit

private let plum = Color(red: 0.078, green: 0.059, blue: 0.125)
private let mint = Color(red: 0.608, green: 0.965, blue: 1.0)
private let lavender = Color(red: 0.804, green: 0.741, blue: 1.0)

@available(iOS 16.1, *)
struct ComeOverLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ComeOverActivityAttributes.self) { context in
            LockScreenView(state: context.state)
                .activityBackgroundTint(plum)
                .activitySystemActionForegroundColor(lavender)
                .widgetURL(deepLink(context.attributes.roomCode))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        Text(context.state.memberAvatar)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(context.state.title)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                            if !context.state.distance.isEmpty {
                                Text(context.state.distance)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 1) {
                        CountdownText(state: context.state)
                            .font(.title3)
                            .fontWeight(.bold)
                            .monospacedDigit()
                        if !context.state.eta.isEmpty {
                            Text(context.state.eta)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        ProgressView(value: context.state.progress)
                            .tint(mint)
                        Text(context.state.subtitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            } compactLeading: {
                Text(context.state.memberAvatar)
                    .font(.caption)
            } compactTrailing: {
                CountdownText(state: context.state)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .monospacedDigit()
            } minimal: {
                Image(systemName: "figure.walk")
                    .foregroundStyle(mint)
            }
            .keylineTint(mint)
            .widgetURL(deepLink(context.attributes.roomCode))
        }
    }

    private func deepLink(_ code: String) -> URL? {
        guard !code.isEmpty else { return nil }
        return URL(string: "comeover://join/\(code)")
    }
}

@available(iOS 16.1, *)
private struct LockScreenView: View {
    let state: ComeOverActivityAttributes.ContentState

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(mint.opacity(0.18))
                        .frame(width: 46, height: 46)
                    Text(state.memberAvatar)
                        .font(.title3)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(state.title)
                        .font(.headline)
                        .lineLimit(1)
                    Text(state.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    CountdownText(state: state)
                        .font(.title2)
                        .fontWeight(.bold)
                        .monospacedDigit()
                    if !state.distance.isEmpty {
                        Text(state.distance)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            ProgressView(value: state.progress)
                .tint(mint)
            HStack {
                Label("ComeOver", systemImage: "location.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                if !state.eta.isEmpty {
                    Text("ETA \(state.eta)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
    }
}

@available(iOS 16.1, *)
private struct CountdownText: View {
    let state: ComeOverActivityAttributes.ContentState

    var body: some View {
        if state.phase == "arrived" {
            Text("Here")
        } else if let arrival = state.arrivalAt, arrival > Date() {
            Text(timerInterval: Date()...arrival, countsDown: true)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 72, alignment: .trailing)
        } else if !state.shortText.isEmpty {
            Text(state.shortText)
        } else {
            Text("Live")
        }
    }
}
