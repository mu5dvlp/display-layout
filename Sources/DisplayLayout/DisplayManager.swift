import AppKit
import CoreGraphics

struct DisplayInfo {
    let id: CGDirectDisplayID
    var bounds: CGRect
    let isMain: Bool
    let name: String
}

enum DisplayManager {
    static func activeDisplays() -> [DisplayInfo] {
        var displayIDs = [CGDirectDisplayID](repeating: 0, count: 16)
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(16, &displayIDs, &count) == .success else {
            return []
        }

        let screenNames: [CGDirectDisplayID: String] = {
            var map = [CGDirectDisplayID: String]()
            for screen in NSScreen.screens {
                if let num = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID {
                    map[num] = screen.localizedName
                }
            }
            return map
        }()

        return (0..<Int(count)).map { i in
            let id = displayIDs[i]
            let bounds = CGDisplayBounds(id)
            let isMain = CGDisplayIsMain(id) != 0
            let name = screenNames[id] ?? "ディスプレイ \(id)"
            return DisplayInfo(id: id, bounds: bounds, isMain: isMain, name: name)
        }
    }

    static func apply(origins: [CGDirectDisplayID: CGPoint]) -> Bool {
        var config: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&config) == .success, let config = config else {
            return false
        }

        for (id, origin) in origins {
            let result = CGConfigureDisplayOrigin(config, id, Int32(origin.x), Int32(origin.y))
            if result != .success {
                CGCancelDisplayConfiguration(config)
                return false
            }
        }

        let result = CGCompleteDisplayConfiguration(config, .permanently)
        if result != .success {
            CGCancelDisplayConfiguration(config)
            return false
        }
        return true
    }
}
