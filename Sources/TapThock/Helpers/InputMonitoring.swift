import AppKit
import ApplicationServices
import IOKit.hid

enum InputMonitoring {
    enum AccessStatus: String {
        case granted
        case denied
        case unknown
    }

    struct Diagnostics {
        let listenEventStatus: AccessStatus
        let postEventStatus: AccessStatus
        let cgListenPreflightGranted: Bool

        var metadata: [String: String] {
            [
                "cgListenPreflightGranted": "\(cgListenPreflightGranted)",
                "listenEventStatus": listenEventStatus.rawValue,
                "postEventStatus": postEventStatus.rawValue,
            ]
        }
    }

    static var diagnostics: Diagnostics {
        Diagnostics(
            listenEventStatus: accessStatus(for: kIOHIDRequestTypeListenEvent),
            postEventStatus: accessStatus(for: kIOHIDRequestTypePostEvent),
            cgListenPreflightGranted: CGPreflightListenEventAccess()
        )
    }

    static var accessStatus: AccessStatus {
        diagnostics.listenEventStatus
    }

    static var hasAccess: Bool {
        accessStatus == .granted
    }

    private static func accessStatus(for requestType: IOHIDRequestType) -> AccessStatus {
        switch IOHIDCheckAccess(requestType) {
        case kIOHIDAccessTypeGranted:
            .granted
        case kIOHIDAccessTypeDenied:
            .denied
        default:
            .unknown
        }
    }

    static func requestAccess() {
        let diagnosticsBeforeRequest = diagnostics
        AppLog.info("InputMonitoring", "Requesting input monitoring permission", metadata: [
            "statusBeforeRequest": accessStatus.rawValue,
        ].merging(diagnosticsBeforeRequest.metadata) { _, newValue in newValue })
        let requestGranted = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        let diagnosticsAfterRequest = diagnostics
        AppLog.info("InputMonitoring", "Finished input monitoring permission request", metadata: [
            "requestGranted": "\(requestGranted)",
        ].merging(diagnosticsAfterRequest.metadata) { _, newValue in newValue })

        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            AppLog.info("InputMonitoring", "Opening System Settings", metadata: [
                "url": url.absoluteString,
            ])
            NSWorkspace.shared.open(url)
        }
    }
}
