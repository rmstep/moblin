import CoreGraphics
import Foundation

// Multiple instant replay buttons ("presets"). Each preset has its own name, duration,
// trigger delay, speed, replay window (crop + position/size) and optionally a resized
// live video underneath while the replay plays (e.g. picture-in-picture during a game).

let replayPresetQuickButtonTypes: [SettingsQuickButtonType] = [
    .instantReplayPreset1,
    .instantReplayPreset2,
    .instantReplayPreset3,
    .instantReplayPreset4,
]

extension SettingsQuickButtonType {
    func replayPresetIndex() -> Int? {
        replayPresetQuickButtonTypes.firstIndex(of: self)
    }
}

struct SettingsReplayPresetLayout: Codable, Equatable {
    var x: Double = 0.0
    var y: Double = 0.0
    var size: Double = 100.0
    var alignment: SettingsAlignment = .topLeft

    init(x: Double = 0.0, y: Double = 0.0, size: Double = 100.0, alignment: SettingsAlignment = .topLeft) {
        self.x = x
        self.y = y
        self.size = size
        self.alignment = alignment
    }

    enum CodingKeys: CodingKey {
        case x
        case y
        case size
        case alignment
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.x, x)
        try container.encode(.y, y)
        try container.encode(.size, size)
        try container.encode(.alignment, alignment)
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        x = container.decode(.x, Double.self, 0.0)
        y = container.decode(.y, Double.self, 0.0)
        size = container.decode(.size, Double.self, 100.0)
        alignment = container.decode(.alignment, SettingsAlignment.self, .topLeft)
    }

    func toWidgetLayout() -> SettingsWidgetLayout {
        var layout = SettingsWidgetLayout()
        layout.x = x
        layout.updateXString()
        layout.y = y
        layout.updateYString()
        layout.size = size
        layout.updateSizeString()
        layout.alignment = alignment
        return layout
    }
}

// Crop given as fractions (0...1) of the replay video, origin top left.
struct SettingsReplayPresetCrop: Codable, Equatable {
    var x: Double = 0.0
    var y: Double = 0.0
    var width: Double = 1.0
    var height: Double = 1.0

    init(x: Double = 0.0, y: Double = 0.0, width: Double = 1.0, height: Double = 1.0) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    enum CodingKeys: CodingKey {
        case x
        case y
        case width
        case height
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.x, x)
        try container.encode(.y, y)
        try container.encode(.width, width)
        try container.encode(.height, height)
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        x = container.decode(.x, Double.self, 0.0)
        y = container.decode(.y, Double.self, 0.0)
        width = container.decode(.width, Double.self, 1.0)
        height = container.decode(.height, Double.self, 1.0)
    }

    func clamped() -> SettingsReplayPresetCrop {
        let x = min(max(x, 0), 0.9)
        let y = min(max(y, 0), 0.9)
        let width = min(max(width, 0.1), 1 - x)
        let height = min(max(height, 0.1), 1 - y)
        return .init(x: x, y: y, width: width, height: height)
    }

    // Core Image pixel region. Core Image origin is bottom left, so flip y.
    func coreImageRegion(_ extent: CGRect) -> CGRect {
        let crop = clamped()
        return CGRect(x: extent.minX + crop.x * extent.width,
                      y: extent.minY + (1 - crop.y - crop.height) * extent.height,
                      width: crop.width * extent.width,
                      height: crop.height * extent.height)
    }

    // MetalPetal layer content region. Origin is top left.
    func metalPetalRegion(_ extent: CGRect) -> CGRect {
        let crop = clamped()
        return CGRect(x: extent.minX + crop.x * extent.width,
                      y: extent.minY + crop.y * extent.height,
                      width: crop.width * extent.width,
                      height: crop.height * extent.height)
    }

    func isFull() -> Bool {
        let crop = clamped()
        return crop.x == 0 && crop.y == 0 && crop.width == 1 && crop.height == 1
    }
}

class SettingsReplayPreset: Codable, Identifiable, ObservableObject {
    static let maximumDuration = 30.0
    var id: UUID = .init()
    @Published var name: String = ""
    @Published var duration: Double = 10.0
    @Published var postTriggerDelay: Int = 3
    @Published var speed: SettingsReplaySpeed = .one
    @Published var replayCropEnabled: Bool = false
    @Published var replayCrop: SettingsReplayPresetCrop = .init()
    @Published var tapToAimCrop: Bool = false
    @Published var aimZoom: Double = 0.4
    @Published var replayLayout: SettingsReplayPresetLayout = .init()
    @Published var replayBorder: Bool = false
    @Published var liveVideoEnabled: Bool = false
    @Published var liveVideoLayout: SettingsReplayPresetLayout = .init(x: 0,
                                                                       y: 0,
                                                                       size: 80,
                                                                       alignment: .bottomRight)

    init(name: String) {
        self.name = name
    }

    enum CodingKeys: CodingKey {
        case id
        case name
        case duration
        case postTriggerDelay
        case speed
        case replayCropEnabled
        case replayCrop
        case tapToAimCrop
        case aimZoom
        case replayLayout
        case replayBorder
        case liveVideoEnabled
        case liveVideoLayout
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.name, name)
        try container.encode(.duration, duration)
        try container.encode(.postTriggerDelay, postTriggerDelay)
        try container.encode(.speed, speed)
        try container.encode(.replayCropEnabled, replayCropEnabled)
        try container.encode(.replayCrop, replayCrop)
        try container.encode(.tapToAimCrop, tapToAimCrop)
        try container.encode(.aimZoom, aimZoom)
        try container.encode(.replayLayout, replayLayout)
        try container.encode(.replayBorder, replayBorder)
        try container.encode(.liveVideoEnabled, liveVideoEnabled)
        try container.encode(.liveVideoLayout, liveVideoLayout)
    }

    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        name = container.decode(.name, String.self, "")
        duration = container.decode(.duration, Double.self, 10.0)
        postTriggerDelay = container.decode(.postTriggerDelay, Int.self, 3)
        speed = container.decode(.speed, SettingsReplaySpeed.self, .one)
        replayCropEnabled = container.decode(.replayCropEnabled, Bool.self, false)
        replayCrop = container.decode(.replayCrop, SettingsReplayPresetCrop.self, .init())
        tapToAimCrop = container.decode(.tapToAimCrop, Bool.self, false)
        aimZoom = container.decode(.aimZoom, Double.self, 0.4)
        replayLayout = container.decode(.replayLayout, SettingsReplayPresetLayout.self, .init())
        replayBorder = container.decode(.replayBorder, Bool.self, false)
        liveVideoEnabled = container.decode(.liveVideoEnabled, Bool.self, false)
        liveVideoLayout = container.decode(.liveVideoLayout,
                                           SettingsReplayPresetLayout.self,
                                           .init(x: 0, y: 0, size: 80, alignment: .bottomRight))
    }

    func clampedDuration() -> Double {
        min(max(duration, 1), SettingsReplayPreset.maximumDuration)
    }

    func cropForEffect() -> SettingsReplayPresetCrop? {
        guard replayCropEnabled, !replayCrop.isFull() else {
            return nil
        }
        return replayCrop.clamped()
    }

    func aimCrop(x: Double, y: Double) -> SettingsReplayPresetCrop {
        let size = min(max(aimZoom, 0.1), 1)
        return .init(x: min(max(x - size / 2, 0), 1 - size),
                     y: min(max(y - size / 2, 0), 1 - size),
                     width: size,
                     height: size)
    }

    func previewCrop() -> SettingsReplayPresetCrop {
        if tapToAimCrop {
            return aimCrop(x: 0.5, y: 0.5)
        }
        return replayCropEnabled ? replayCrop.clamped() : SettingsReplayPresetCrop()
    }

    func liveVideoLayoutForEffect() -> SettingsWidgetLayout? {
        guard liveVideoEnabled else {
            return nil
        }
        return liveVideoLayout.toWidgetLayout()
    }
}

func makeDefaultReplayPresets() -> [SettingsReplayPreset] {
    let fullScreen = SettingsReplayPreset(name: String(localized: "Replay"))
    fullScreen.duration = 10
    let pictureInPicture = SettingsReplayPreset(name: String(localized: "PiP replay"))
    pictureInPicture.duration = 8
    pictureInPicture.replayCropEnabled = true
    pictureInPicture.replayCrop = .init(x: 0.1, y: 0.1, width: 0.8, height: 0.8)
    pictureInPicture.replayLayout = .init(x: 2, y: 2, size: 45, alignment: .topLeft)
    pictureInPicture.replayBorder = true
    pictureInPicture.liveVideoEnabled = true
    pictureInPicture.liveVideoLayout = .init(x: 0, y: 0, size: 80, alignment: .bottomRight)
    let slowMotion = SettingsReplayPreset(name: String(localized: "Slow-mo"))
    slowMotion.duration = 5
    slowMotion.speed = .oneHalf
    let long = SettingsReplayPreset(name: String(localized: "Long replay"))
    long.duration = 20
    return [fullScreen, pictureInPicture, slowMotion, long]
}

@MainActor
func addMissingReplayPresets(database: Database) {
    let defaults = makeDefaultReplayPresets()
    while database.replay.presets.count < replayPresetQuickButtonTypes.count {
        database.replay.presets.append(defaults[database.replay.presets.count])
    }
    syncReplayPresetQuickButtonNames(database: database)
}

@MainActor
func syncReplayPresetQuickButtonNames(database: Database) {
    for (index, type) in replayPresetQuickButtonTypes.enumerated() {
        guard index < database.replay.presets.count,
              let button = database.quickButtons.first(where: { $0.type == type })
        else {
            continue
        }
        let name = database.replay.presets[index].name
        button.name = name.isEmpty ? type.toString() : name
    }
}
