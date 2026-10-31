import ActivityKit
import CoreLocation
import Flutter
import UIKit

/// Starts, updates and ends the ComeOver Live Activity from Flutter.
final class LiveStatusBridge {
    private let channel: FlutterMethodChannel
    private let locationManager = CLLocationManager()

    init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: "dev.comeover/live_status", binaryMessenger: messenger)
        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result: result)
        }
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isSupported":
            if #available(iOS 16.1, *) {
                result(true)
            } else {
                result(false)
            }
        case "hasPermission", "requestPermission":
            if #available(iOS 16.1, *) {
                result(ActivityAuthorizationInfo().areActivitiesEnabled)
            } else {
                result(false)
            }
        case "start":
            guard #available(iOS 16.1, *),
                  let payload = Self.payload(from: call.arguments) else {
                result(false)
                return
            }
            Task { @MainActor in
                do {
                    try await Self.start(attributes: payload.0, state: payload.1)
                    result(true)
                } catch {
                    result(false)
                }
            }
        case "update":
            guard #available(iOS 16.1, *),
                  let payload = Self.payload(from: call.arguments) else {
                result(nil)
                return
            }
            Task { @MainActor in
                await Self.update(state: payload.1)
                result(nil)
            }
        case "end":
            if #available(iOS 16.1, *) {
                Task { @MainActor in
                    await Self.end()
                    result(nil)
                }
            } else {
                result(nil)
            }
        case "openSettings":
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
            result(nil)
        case "requestBackgroundLocation":
            // Once when-in-use is granted, ask to keep sharing with the screen
            // off so the Live Activity's distance/ETA keep moving.
            let status = locationManager.authorizationStatus
            if status == .authorizedWhenInUse || status == .notDetermined {
                locationManager.requestAlwaysAuthorization()
            }
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    @available(iOS 16.1, *)
    private static func payload(
        from arguments: Any?
    ) -> (ComeOverActivityAttributes, ComeOverActivityAttributes.ContentState)? {
        guard let map = arguments as? [String: Any] else { return nil }
        let arrival = (map["arrivalAt"] as? NSNumber).map {
            Date(timeIntervalSince1970: $0.doubleValue / 1000)
        }
        let updated = (map["updatedAt"] as? NSNumber).map {
            Date(timeIntervalSince1970: $0.doubleValue / 1000)
        } ?? Date()
        let state = ComeOverActivityAttributes.ContentState(
            phase: map["phase"] as? String ?? "waiting",
            title: map["title"] as? String ?? "ComeOver",
            subtitle: map["subtitle"] as? String ?? "",
            shortText: map["shortText"] as? String ?? "",
            distance: map["distance"] as? String ?? "",
            eta: map["eta"] as? String ?? "",
            memberName: map["memberName"] as? String ?? "",
            memberAvatar: map["memberAvatar"] as? String ?? "📍",
            progress: (map["progress"] as? NSNumber)?.doubleValue ?? 0,
            arrivalAt: arrival,
            updatedAt: updated
        )
        return (ComeOverActivityAttributes(roomCode: map["roomCode"] as? String ?? ""), state)
    }

    @available(iOS 16.1, *)
    @MainActor
    private static func start(
        attributes: ComeOverActivityAttributes,
        state: ComeOverActivityAttributes.ContentState
    ) async throws {
        // A previous process may have left an activity behind. Reuse it rather
        // than stacking a second countdown on the Lock Screen.
        guard Activity<ComeOverActivityAttributes>.activities.isEmpty else {
            await update(state: state)
            return
        }
        if #available(iOS 16.2, *) {
            let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(120))
            _ = try Activity.request(attributes: attributes, content: content, pushType: nil)
        } else {
            _ = try Activity.request(attributes: attributes, contentState: state, pushType: nil)
        }
    }

    @available(iOS 16.1, *)
    @MainActor
    private static func update(state: ComeOverActivityAttributes.ContentState) async {
        for activity in Activity<ComeOverActivityAttributes>.activities {
            if #available(iOS 16.2, *) {
                let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(120))
                await activity.update(content)
            } else {
                await activity.update(using: state)
            }
        }
    }

    @available(iOS 16.1, *)
    @MainActor
    private static func end() async {
        for activity in Activity<ComeOverActivityAttributes>.activities {
            if #available(iOS 16.2, *) {
                await activity.end(nil, dismissalPolicy: .immediate)
            } else {
                await activity.end(using: nil, dismissalPolicy: .immediate)
            }
        }
    }
}
