import SwiftUI

@MainActor
class ReplayProvider: ObservableObject {
    @Published var selectedId: UUID?
    @Published var isSaving = false
    @Published var previewImage: UIImage?
    @Published var isPlaying = false
    @Published var startFromEnd = 10.0
    @Published var speed: SettingsReplaySpeed? = .one
    @Published var instantReplayCountdown = 0
    @Published var timeLeft = 0
    // Which instant replay preset (if any) is counting down / playing.
    @Published var countdownPresetId: UUID?
    @Published var playingPresetId: UUID?
    @Published var awaitingCropTapPresetId: UUID?
    @Published var aimCrop: SettingsReplayPresetCrop?
}

extension Model {
    func saveReplay(start: Double? = nil,
                    stop: Double? = nil,
                    delay: Int? = nil,
                    completion: (@MainActor (ReplaySettings) -> Void)? = nil) -> Bool
    {
        guard !replay.isSaving else {
            return false
        }
        replay.isSaving = true
        let delay = delay ?? stream.replay.postTriggerDelay
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(delay)) {
            self.replayBuffer.createFile { file in
                DispatchQueue.main.async {
                    self.replay.isSaving = false
                    guard let file else {
                        self.replayClearAim()
                        return
                    }
                    let replaySettings = self.replaysStorage.createReplay()
                    replaySettings.start = start ?? self.database.replay.start
                    replaySettings.stop = stop ?? self.database.replay.stop
                    replaySettings.duration = file.duration
                    try? FileManager.default.copyItem(
                        at: file.url,
                        to: self.replaysStorage.url(replay: replaySettings)
                    )
                    self.replaysStorage.append(replay: replaySettings)
                    completion?(replaySettings)
                }
            }
        }
        return true
    }

    func loadReplay(video: ReplaySettings, completion: (@MainActor () -> Void)? = nil) {
        replaySettings = video
        replay.startFromEnd = video.startFromEnd()
        replay.selectedId = video.id
        replayFrameExtractor = ReplayFrameExtractor(
            video: ReplayBufferFile(
                url: replaysStorage.url(replay: video),
                duration: video.duration,
                remove: false
            ),
            offset: video.thumbnailOffset(),
            pixelFormatType: stream.colorRange.pixelFormatType(),
            delegate: self,
            completion: completion
        )
    }

    func deleteSelectedReplay() {
        guard let replayId = replay.selectedId else {
            return
        }
        replaysStorage.delete(id: replayId)
    }

    func replaySpeedChanged() {
        database.replay.speed = replay.speed ?? .one
    }

    func instantReplay(start: Double? = nil, delay: Int? = nil) {
        guard replay.instantReplayCountdown == 0 else {
            return
        }
        let delay = delay ?? stream.replay.postTriggerDelay
        let savingStarted = saveReplay(start: start, delay: delay) { video in
            self.loadReplay(video: video) {
                self.replay.isPlaying = true
                if !self.replayPlay() {
                    self.replay.isPlaying = false
                }
            }
        }
        if savingStarted {
            replay.countdownPresetId = nil
            replay.instantReplayCountdown = delay + 1
            instantReplayCountdownTick()
        }
    }

    func instantReplay(preset: SettingsReplayPreset) {
        guard stream.replay.enabled else {
            makeReplayIsNotEnabledToast()
            return
        }
        guard replay.instantReplayCountdown == 0 else {
            return
        }
        let delay = preset.postTriggerDelay
        let stop = SettingsReplay.stop
        let start = stop - preset.clampedDuration()
        let savingStarted = saveReplay(start: start, stop: stop, delay: delay) { video in
            self.loadReplay(video: video) {
                self.replay.isPlaying = true
                self.replay.playingPresetId = preset.id
                if !self.replayPlay(preset: preset) {
                    self.replay.isPlaying = false
                }
            }
        }
        if savingStarted {
            replay.aimCrop = nil
            replay.awaitingCropTapPresetId = preset.tapToAimCrop ? preset.id : nil
            replay.countdownPresetId = preset.id
            replay.instantReplayCountdown = delay + 1
            instantReplayCountdownTick()
        }
    }

    func instantReplay(presetIndex: Int) {
        guard presetIndex >= 0, presetIndex < database.replay.presets.count else {
            return
        }
        instantReplay(preset: database.replay.presets[presetIndex])
    }

    func replayAimTap(x: Double, y: Double) {
        guard let presetId = replay.awaitingCropTapPresetId,
              let preset = database.replay.presets.first(where: { $0.id == presetId })
        else {
            return
        }
        replay.aimCrop = preset.aimCrop(x: x, y: y)
    }

    private func replayClearAim() {
        replay.awaitingCropTapPresetId = nil
        replay.aimCrop = nil
    }

    private func instantReplayCountdownTick() {
        guard replay.instantReplayCountdown != 0 else {
            return
        }
        replay.instantReplayCountdown -= 1
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
            self.instantReplayCountdownTick()
        }
    }

    func makeReplayIsNotEnabledToast() {
        makeToast(
            title: String(localized: "Replay is not enabled"),
            subTitle: String(localized: "Tap here to enable it.")
        ) {
            self.stream.replay.enabled = true
            self.streamReplayEnabledUpdated()
            self.makeToast(title: String(localized: "Replay enabled"))
        }
    }

    func makeReplayShouldBeDisabledToastIfNeeded() {
        guard stream.replay.enabled,
              let enterForegroundCountAtLatestUsage = stream.replay.enterForegroundCountAtLatestUsage
        else {
            return
        }
        let unusedCount = enterForegroundCount - enterForegroundCountAtLatestUsage
        guard unusedCount >= 20, unusedCount % 3 == 0 else {
            return
        }
        makeToast(
            title: String(localized: "Replay is enabled but seems unused"),
            subTitle: String(localized: "Tap here to disable it.")
        ) {
            self.stream.replay.enabled = false
            self.streamReplayEnabledUpdated()
            self.makeToast(title: String(localized: "Replay disabled"))
        }
    }

    func setReplayPosition(start: Double) {
        guard let replaySettings else {
            return
        }
        replaySettings.start = start
        replaySettings.stop = SettingsReplay.stop
        database.replay.start = start
        replayFrameExtractor?.seek(offset: replaySettings.thumbnailOffset())
    }

    func replayPlay(preset: SettingsReplayPreset? = nil) -> Bool {
        replayCancel()
        if preset == nil {
            self.replay.playingPresetId = nil
        }
        var crop = preset?.cropForEffect()
        if let preset, self.replay.awaitingCropTapPresetId == preset.id, let aimCrop = self.replay.aimCrop {
            crop = aimCrop
        }
        replayClearAim()
        guard let replayVideo, let replaySettings else {
            return false
        }
        let replay = stream.replay
        replay.enterForegroundCountAtLatestUsage = enterForegroundCount
        let transitionMode: ReplayEffectTransitionMode
        switch replay.transitionType {
        case .none:
            transitionMode = .none
        case .fade:
            transitionMode = .fade
        case .stingers:
            let inPath = replayTransitionsStorage.makePath(filename: replay.inStinger.makeFilename() ?? "")
            let outPath = replayTransitionsStorage.makePath(filename: replay.outStinger.makeFilename() ?? "")
            transitionMode = .stingers(inPath: inPath,
                                       inTransitionPoint: replay.inStinger.transitionPoint,
                                       outPath: outPath,
                                       outTransitionPoint: replay.outStinger.transitionPoint)
        }
        replayEffect = ReplayEffect(
            video: replayVideo,
            start: replaySettings.startFromVideoStart(),
            stop: replaySettings.stopFromVideoStart(),
            speed: preset?.speed.toNumber() ?? database.replay.speed.toNumber(),
            size: stream.dimensions(),
            layout: preset?.replayLayout.toWidgetLayout() ?? replay.layout,
            crop: crop,
            border: preset?.replayBorder ?? false,
            liveVideoLayout: preset?.liveVideoLayoutForEffect(),
            transitionMode: transitionMode,
            pixelFormatType: stream.colorRange.pixelFormatType(),
            delegate: self
        )
        media.registerEffectBack(replayEffect!)
        return true
    }

    func replayCancel() {
        replayEffect?.cancel()
        replayEffect = nil
    }

    func streamReplayEnabledUpdated() {
        replayBuffer = ReplayBuffer()
        media.setReplayBuffering(enabled: stream.replay.enabled)
        if stream.replay.enabled {
            startRecorderIfNeeded()
        } else {
            stopRecorderIfNeeded()
        }
        stream.replay.enterForegroundCountAtLatestUsage = enterForegroundCount
    }
}

extension Model: ReplayDelegate {
    nonisolated func replayOutputFrame(
        image: UIImage,
        offset _: Double,
        video: ReplayBufferFile,
        completion: (@MainActor () -> Void)?
    ) {
        DispatchQueue.main.async {
            self.replay.previewImage = image
            self.replayVideo = video
            completion?()
        }
    }
}

extension Model: ReplayEffectDelegate {
    nonisolated func replayEffectStatus(timeLeft: Int) {
        DispatchQueue.main.async {
            self.replay.timeLeft = timeLeft
        }
    }

    nonisolated func replayEffectCompleted() {
        DispatchQueue.main.async {
            self.replay.isPlaying = false
        }
    }

    nonisolated func replayEffectError(message: String) {
        makeErrorToastMain(title: message)
    }
}
