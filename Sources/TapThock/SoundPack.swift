import AppKit
import Foundation

enum KeyType: String, CaseIterable, Sendable {
    case alphanumeric
    case space
    case enter
    case backspace
    case tab
    case escape
    case modifier
    case mouseLeft
    case mouseRight
    case mouseMiddle
    case mouseBack
    case mouseForward
    case scroll

    fileprivate var baseFilename: String {
        switch self {
        case .alphanumeric: "alphanumeric"
        case .space: "space"
        case .enter: "enter"
        case .backspace: "backspace"
        case .tab: "tab"
        case .escape: "escape"
        case .modifier: "modifier"
        case .mouseLeft: "mouse-left"
        case .mouseRight: "mouse-right"
        case .mouseMiddle: "mouse-middle"
        case .mouseBack: "mouse-back"
        case .mouseForward: "mouse-forward"
        case .scroll: "scroll"
        }
    }

    static func from(event: NSEvent) -> KeyType {
        switch event.keyCode {
        case 36, 76: .enter
        case 48: .tab
        case 49: .space
        case 51, 117: .backspace
        case 53: .escape
        case 54, 55, 56, 57, 58, 59, 60, 61, 62, 63: .modifier
        default: .alphanumeric
        }
    }
}

enum MouseButton: Sendable {
    case left
    case right
    case middle
    case back
    case forward

    var keyType: KeyType {
        switch self {
        case .left: .mouseLeft
        case .right: .mouseRight
        case .middle: .mouseMiddle
        case .back: .mouseBack
        case .forward: .mouseForward
        }
    }
}

struct SoundPack: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let folderURL: URL
    let variantCount: Int

    func soundURL(for keyType: KeyType, variant: Int = 0) -> URL {
        if keyType == .alphanumeric {
            return folderURL.appending(path: "\(keyType.baseFilename)-\(max(0, min(variant, variantCount - 1))).caf")
        }

        return folderURL.appending(path: "\(keyType.baseFilename).caf")
    }

    func randomVariantURL(for keyType: KeyType) -> URL {
        let variant = Int.random(in: 0..<max(variantCount, 1))
        return soundURL(for: keyType, variant: variant)
    }

    func pitchShift(for keyCode: UInt16) -> Double {
        let seed = Double((Int(keyCode) % 13) - 6)
        let random = Double.random(in: -0.012...0.012)
        return seed * 0.001 + random
    }

    var allURLs: [URL] {
        KeyType.allCases.flatMap { keyType in
            if keyType == .alphanumeric {
                return (0..<max(variantCount, 1)).map { soundURL(for: keyType, variant: $0) }
            }

            return [soundURL(for: keyType)]
        }
    }
}
