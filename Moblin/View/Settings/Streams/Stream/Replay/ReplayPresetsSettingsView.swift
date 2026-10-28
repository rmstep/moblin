import CoreMedia
import SwiftUI

// Settings for the instant replay preset buttons. Each preset gets its own quick button
// ("Instant replay 1" ... "Instant replay 4").

private struct ReplayPresetLayoutEditView: View {
    @Binding var layout: SettingsReplayPresetLayout
    let minimumSize: Double

    private func alignmentButton(_ alignment: SettingsAlignment) -> some View {
        Button {
            layout.alignment = alignment
        } label: {
            Image(systemName: layout.alignment == alignment ? "square.fill" : "square")
        }
        .buttonStyle(.borderless)
        .font(.title2)
    }

    private func slider(_ title: LocalizedStringKey,
                        _ value: Binding<Double>,
                        _ range: ClosedRange<Double>) -> some View
    {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                Spacer()
                GrayTextView(text: "\(Int(value.wrappedValue.rounded())) %")
            }
            Slider(value: value, in: range, step: 1)
        }
    }

    var body: some View {
        HStack {
            Text("Alignment")
            Spacer()
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    alignmentButton(.topLeft)
                    alignmentButton(.topCenter)
                    alignmentButton(.topRight)
                }
                HStack(spacing: 4) {
                    alignmentButton(.leftCenter)
                    alignmentButton(.center)
                    alignmentButton(.rightCenter)
                }
                HStack(spacing: 4) {
                    alignmentButton(.bottomLeft)
                    alignmentButton(.bottomCenter)
                    alignmentButton(.bottomRight)
                }
            }
        }
        slider("Size", $layout.size, minimumSize ... 100)
        if !layout.alignment.isHorizontalCenter() {
            slider(layout.alignment.isLeft() ? "Distance from left" : "Distance from right", $layout.x, 0 ... 90)
        }
        if !layout.alignment.isVerticalCenter() {
            slider(layout.alignment.isTop() ? "Distance from top" : "Distance from bottom", $layout.y, 0 ... 90)
        }
    }
}

private func previewRect(_ layout: SettingsReplayPresetLayout,
                         _ contentSize: CGSize,
                         _ canvas: CGSize) -> CGRect
{
    let scale = min(layout.size / 100 * canvas.width / contentSize.width,
                    layout.size / 100 * canvas.height / contentSize.height)
    let width = contentSize.width * scale
    let height = contentSize.height * scale
    let x: Double
    if layout.alignment.isHorizontalCenter() {
        x = (canvas.width - width) / 2
    } else if layout.alignment.isLeft() {
        x = layout.x / 100 * canvas.width
    } else {
        x = canvas.width - layout.x / 100 * canvas.width - width
    }
    let y: Double
    if layout.alignment.isVerticalCenter() {
        y = (canvas.height - height) / 2
    } else if layout.alignment.isTop() {
        y = layout.y / 100 * canvas.height
    } else {
        y = canvas.height - layout.y / 100 * canvas.height - height
    }
    return CGRect(x: x, y: y, width: width, height: height)
}

// Approximate picture of what viewers will see while the replay plays.
private struct ReplayPresetPreviewView: View {
    @ObservedObject var preset: SettingsReplayPreset
    let streamSize: CGSize

    var body: some View {
        GeometryReader { geometry in
            let canvas = geometry.size
            let liveRect = preset.liveVideoEnabled
                ? previewRect(preset.liveVideoLayout, canvas, canvas)
                : CGRect(origin: .zero, size: canvas)
            let crop = preset.previewCrop()
            let replayContentSize = CGSize(width: crop.width * canvas.width, height: crop.height * canvas.height)
            let replayRect = previewRect(preset.replayLayout, replayContentSize, canvas)
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(.black)
                Rectangle()
                    .fill(Color.green.opacity(0.6))
                    .overlay(Text("LIVE").font(.caption2.bold()).foregroundStyle(.white))
                    .frame(width: liveRect.width, height: liveRect.height)
                    .offset(x: liveRect.minX, y: liveRect.minY)
                Rectangle()
                    .fill(Color.orange.opacity(0.85))
                    .overlay(Text("REPLAY").font(.caption2.bold()).foregroundStyle(.white))
                    .border(.white, width: preset.replayBorder ? 2 : 0)
                    .frame(width: replayRect.width, height: replayRect.height)
                    .offset(x: replayRect.minX, y: replayRect.minY)
            }
            .clipped()
        }
        .aspectRatio(streamSize.width / max(streamSize.height, 1), contentMode: .fit)
        .frame(maxWidth: .infinity)
    }
}

private struct ReplayPresetCropEditView: View {
    @Binding var crop: SettingsReplayPresetCrop

    private func slider(_ title: LocalizedStringKey,
                        _ value: Binding<Double>,
                        _ range: ClosedRange<Double>) -> some View
    {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                Spacer()
                GrayTextView(text: "\(Int((value.wrappedValue * 100).rounded())) %")
            }
            Slider(value: value, in: range, step: 0.01)
        }
    }

    var body: some View {
        slider("Left", $crop.x, 0 ... 0.9)
        slider("Top", $crop.y, 0 ... 0.9)
        slider("Width", $crop.width, 0.1 ... 1)
        slider("Height", $crop.height, 0.1 ... 1)
        Button("Center crop") {
            crop.x = (1 - crop.width) / 2
            crop.y = (1 - crop.height) / 2
        }
    }
}

struct ReplayPresetSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var preset: SettingsReplayPreset

    private func streamSize() -> CGSize {
        let dimensions = model.stream.resolution.dimensions(portrait: model.stream.portrait)
        return CGSize(width: Double(dimensions.width), height: Double(dimensions.height))
    }

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $preset.name)
                    .onChange(of: preset.name) { _ in
                        syncReplayPresetQuickButtonNames(database: model.database)
                        model.updateQuickButtonPairs()
                    }
            } header: {
                Text("Name")
            } footer: {
                Text("Shown on the quick button.")
            }
            Section {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Duration")
                        Spacer()
                        GrayTextView(text: formatShortDuration(seconds: Int(preset.clampedDuration())))
                    }
                    Slider(value: $preset.duration, in: 1 ... SettingsReplayPreset.maximumDuration, step: 1)
                }
                Picker("Post trigger delay", selection: $preset.postTriggerDelay) {
                    ForEach([0, 1, 2, 3, 4, 5], id: \.self) { delay in
                        Text(formatShortDuration(seconds: delay))
                    }
                }
                Picker("Speed", selection: $preset.speed) {
                    ForEach(SettingsReplaySpeed.allCases, id: \.self) { speed in
                        Text(speed.rawValue)
                    }
                }
            } header: {
                Text("Timing")
            } footer: {
                Text("""
                Duration is how far back the replay starts, measured from when the clip is saved \
                (tap + post trigger delay). The replay buffer holds 30 seconds.
                """)
            }
            Section {
                ReplayPresetPreviewView(preset: preset, streamSize: streamSize())
                    .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
            } header: {
                Text("Preview")
            }
            Section {
                Toggle("Tap to aim", isOn: $preset.tapToAimCrop)
                if preset.tapToAimCrop {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("Zoom box size")
                            Spacer()
                            GrayTextView(text: "\(Int((preset.aimZoom * 100).rounded())) %")
                        }
                        Slider(value: $preset.aimZoom, in: 0.1 ... 1, step: 0.01)
                    }
                }
                Toggle("Crop", isOn: $preset.replayCropEnabled)
                if preset.replayCropEnabled {
                    ReplayPresetCropEditView(crop: $preset.replayCrop)
                }
            } header: {
                Text("Replay crop")
            } footer: {
                Text("""
                With tap to aim, tap the stream preview after pressing the button to pick where to \
                zoom. You can tap again until the replay starts. If you don't tap, the crop below is used.
                """)
            }
            Section {
                ReplayPresetLayoutEditView(layout: $preset.replayLayout, minimumSize: 10)
                Toggle("White border", isOn: $preset.replayBorder)
            } header: {
                Text("Replay position and size")
            }
            Section {
                Toggle("Resize live video", isOn: $preset.liveVideoEnabled)
                if preset.liveVideoEnabled {
                    ReplayPresetLayoutEditView(layout: $preset.liveVideoLayout, minimumSize: 10)
                }
            } header: {
                Text("Live video during replay")
            } footer: {
                Text("""
                Keep showing the live camera, resized and moved, underneath the replay so \
                viewers don't miss what happens meanwhile. Empty areas are black.
                """)
            }
            Section {
                TextButtonView("Test replay") {
                    model.instantReplay(preset: preset)
                }
            } footer: {
                Text("Requires Replay to be enabled for the current stream.")
            }
        }
        .navigationTitle(preset.name.isEmpty ? String(localized: "Instant replay") : preset.name)
    }
}

private struct ReplayPresetRowView: View {
    let index: Int
    @ObservedObject var preset: SettingsReplayPreset

    var body: some View {
        NavigationLink {
            ReplayPresetSettingsView(preset: preset)
        } label: {
            HStack {
                Text(String(index + 1))
                    .foregroundStyle(.secondary)
                Text(preset.name)
                Spacer()
                GrayTextView(text: formatShortDuration(seconds: Int(preset.clampedDuration())))
                if preset.speed != .one {
                    GrayTextView(text: preset.speed.rawValue)
                }
                if preset.liveVideoEnabled {
                    Image(systemName: "pip")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct ReplayPresetsSettingsView: View {
    @ObservedObject var replay: SettingsReplay

    var body: some View {
        Form {
            Section {
                ForEach(Array(replay.presets.enumerated()), id: \.element.id) { index, preset in
                    ReplayPresetRowView(index: index, preset: preset)
                }
            } footer: {
                Text("""
                Each preset has its own quick button, "Instant replay 1" to "Instant replay 4". \
                Enable them in Settings → Display → Quick buttons. Long press a button to edit it.
                """)
            }
        }
        .navigationTitle("Instant replay buttons")
    }
}

// Shown in the quick button settings panel (long press on the button).
struct ReplayPresetQuickButtonSettingsView: View {
    @EnvironmentObject var model: Model
    let type: SettingsQuickButtonType

    var body: some View {
        if let index = type.replayPresetIndex(), index < model.database.replay.presets.count {
            Section {
                NavigationLink {
                    ReplayPresetSettingsView(preset: model.database.replay.presets[index])
                } label: {
                    Label("Replay settings", systemImage: "memories")
                }
            }
        }
    }
}
