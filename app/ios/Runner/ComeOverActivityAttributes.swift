import ActivityKit
import Foundation

/// Shared between the app and the Live Activity widget extension.
@available(iOS 16.1, *)
struct ComeOverActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var phase: String
        var title: String
        var subtitle: String
        var shortText: String
        var distance: String
        var eta: String
        var memberName: String
        var memberAvatar: String
        var progress: Double
        var arrivalAt: Date?
        var updatedAt: Date
    }

    /// Static for the lifetime of the activity, so the widget can deep-link
    /// back into the same room.
    var roomCode: String
}
