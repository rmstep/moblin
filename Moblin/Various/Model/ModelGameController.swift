import GameController

private let thumbStickDeadZone: Float = 0.1

extension Model {
    func handleControllerFunction(buttonId: String,
                                  function: SettingsControllerFunction,
                                  functionData: SettingsControllerFunctionData,
                                  pressed: Bool)
    {
        switch function {
        case .unused:
            break
        case .record:
            if !pressed {
                toggleRecording()
            }
        case .stream:
            if !pressed {
                toggleStream()
            }
        case .zoomIn:
            handleGameControllerButtonZoom(pressed: pressed, x: .infinity)
        case .zoomOut:
            handleGameControllerButtonZoom(pressed: pressed, x: 0)
        case .gimbalUp:
            setGimbalMovement(x: pressed ? 1 : 0, y: 0)
        case .gimbalDown:
            setGimbalMovement(x: pressed ? -1 : 0, y: 0)
        case .gimbalLeft:
            setGimbalMovement(x: 0, y: pressed ? 1 : 0)
        case .gimbalRight:
            setGimbalMovement(x: 0, y: pressed ? -1 : 0)
        case .gimbalPreset:
            let timer = gimbalPresetLongPressTimers.removeValue(forKey: buttonId)
            timer?.stop()
            if !pressed {
                if let gimbalPresetId = functionData.gimbalPresetId, timer != nil {
                    moveToGimbalPreset(id: gimbalPresetId)
                }
            } else if let gimbalPresetId = functionData.gimbalPresetId {
                let timer = MainTimer()
                timer.startSingleShot(timeout: 0.5) { [weak self] in
                    self?.gimbalPresetLongPressTimers.removeValue(forKey: buttonId)
                    self?.saveGimbalPreset(id: gimbalPresetId)
                    self?.makeToast(title: String(localized: "Gimbal preset updated"))
                }
                gimbalPresetLongPressTimers[buttonId] = timer
            }
        case .gimbalAnimate:
            if !pressed, #available(iOS 18.0, *) {
                Gimbal.shared?.animate(motion: functionData.gimbalMotion)
            }
        case .torch:
            if !pressed {
                toggleTorch()
                toggleQuickButton(type: .torch)
            }
        case .mute:
            if !pressed {
                toggleMute()
                toggleQuickButton(type: .mute)
            }
        case .blackScreen:
            if !pressed {
                toggleStealthMode()
            }
        case .scene:
            if let sceneId = functionData.sceneId, !pressed {
                selectScene(id: sceneId)
            }
        case .switchScene:
            if !pressed {
                switchToNextSceneRoundRobin()
            }
        case .widget:
            if let widgetId = functionData.widgetId, !pressed {
                toggleWidgetOnOff(id: widgetId)
            }
        case .macro:
            if let macroId = functionData.macroId, !pressed {
                toggleMacroStartStop(id: macroId)
            }
        case .streamDeckLayout:
            if !pressed {
                database.streamDecks.selectedId = functionData.streamDeckLayoutId
                setSelectedStreamDeck()
            }
        case .instantReplay:
            if !pressed {
                instantReplay()
            }
        case .instantReplay1:
            if !pressed {
                instantReplay(presetIndex: 0)
            }
        case .instantReplay2:
            if !pressed {
                instantReplay(presetIndex: 1)
            }
        case .instantReplay3:
            if !pressed {
                instantReplay(presetIndex: 2)
            }
        case .instantReplay4:
            if !pressed {
                instantReplay(presetIndex: 3)
            }
        case .stopReplay:
            if !pressed {
                replay.isPlaying = false
                replayCancel()
            }
        case .snapshot:
            if !pressed {
                takeSnapshot(age: 0.0, isChatBot: false, message: nil)
            }
        case .pauseTts:
            if !pressed {
                toggleTextToSpeechPaused()
            }
        case .pixellate:
            if !pressed {
                togglePixellateQuickButton()
            }
        case .movie:
            if !pressed {
                toggleFilterQuickButton(type: .movie)
            }
        case .grayScale:
            if !pressed {
                toggleFilterQuickButton(type: .grayScale)
            }
        case .sepia:
            if !pressed {
                toggleFilterQuickButton(type: .sepia)
            }
        case .triple:
            if !pressed {
                toggleFilterQuickButton(type: .triple)
            }
        case .twin:
            if !pressed {
                toggleFilterQuickButton(type: .twin)
            }
        case .cameraMan:
            if !pressed {
                toggleCameraManQuickButton()
            }
        case .fourThree:
            if !pressed {
                toggleFilterQuickButton(type: .fourThree)
            }
        case .pinch:
            if !pressed {
                togglePinchQuickButton()
            }
        case .whirlpool:
            if !pressed {
                toggleWhirlpoolQuickButton()
            }
        case .poll:
            if !pressed {
                togglePollQuickButton()
            }
        case .blurFaces:
            if !pressed {
                toggleBlurFaces()
            }
        case .privacy:
            if !pressed {
                togglePrivacy()
            }
        case .beauty:
            if !pressed {
                toggleBeautyQuickButton()
            }
        case .gimbalTracking:
            if !pressed {
                toggleGimbalTracking()
            }
        }
    }

    func isGameControllerConnected() -> Bool {
        numberOfGameControllers() > 0
    }

    private func handleGameControllerButtonZoom(pressed: Bool, x: Float) {
        if pressed {
            setZoomX(x: x, rate: database.zoom.speed)
        } else {
            if let x = stopCameraZoom() {
                setZoomXWhenInRange(x: x)
            }
        }
    }

    private func handleGameControllerThumbStick(
        _ gameController: GCController,
        left: Bool,
        xValue: Float,
        yValue: Float
    ) {
        guard let index = getGameControllerIndex(gameController) else {
            return
        }
        let settings = database.gameControllers[index]
        let function = left ? settings.leftThumbStickFunction : settings.rightThumbStickFunction
        switch function {
        case .unused:
            break
        case .gimbalPanTilt:
            let x = abs(xValue) > thumbStickDeadZone ? xValue : 0
            let y = abs(yValue) > thumbStickDeadZone ? yValue : 0
            setGimbalMovement(x: y, y: -x)
        case .zoom:
            let y = abs(yValue) > thumbStickDeadZone ? yValue : 0
            handleGameControllerThumbStickZoom(y: y, zoomSpeed: settings.zoomSpeed)
        }
    }

    private func handleGameControllerThumbStickZoom(y: Float, zoomSpeed: Float) {
        let speed = (y * zoomSpeed / 50 * 20).rounded() / 20
        guard speed != gameControllerZoomSpeed else {
            return
        }
        gameControllerZoomSpeed = speed
        if speed == 0 {
            stopZoomSpeed()
        } else {
            setZoomSpeed(speed: speed)
        }
    }

    private func getGameControllerIndex(_ gameController: GCController) -> Int? {
        guard let index = gameControllers.firstIndex(of: gameController),
              index < database.gameControllers.count
        else {
            return nil
        }
        return index
    }

    private func handleGameControllerButton(
        _ gameController: GCController,
        _ button: GCControllerButtonInput,
        _: Float,
        _ pressed: Bool
    ) {
        guard let index = getGameControllerIndex(gameController),
              let name = gameControllerButtonName(button),
              let button = database.gameControllers[index].buttons.first(where: { $0.name == name })
        else {
            return
        }
        handleControllerFunction(buttonId: "gc:\(index):\(name)",
                                 function: button.function,
                                 functionData: button.functionData,
                                 pressed: pressed)
    }

    private func numberOfGameControllers() -> Int {
        gameControllers.count(where: { $0 != nil })
    }

    private func updateGameControllers() {
        statusTopRight.gameControllersTotal = String(numberOfGameControllers())
    }

    private func gameControllerNumber(gameController: GCController) -> Int? {
        if let gameControllerIndex = gameControllers.firstIndex(of: gameController) {
            return gameControllerIndex + 1
        }
        return nil
    }

    private func gameControllerButtonName(_ button: GCControllerButtonInput) -> String? {
        button.sfSymbolsName ?? button.localizedName
    }

    private func addMissingGameControllerButtons(_ gameController: GCController,
                                                 _ buttons: [GCControllerButtonInput])
    {
        guard let index = getGameControllerIndex(gameController) else {
            return
        }
        let settings = database.gameControllers[index]
        for button in buttons {
            guard let name = gameControllerButtonName(button),
                  !settings.buttons.contains(where: { $0.name == name })
            else {
                continue
            }
            let newButton = SettingsGameControllerButton()
            newButton.name = name
            newButton.text = button.localizedName ?? name
            settings.buttons.append(newButton)
        }
    }

    private func setupGenericGameController(_ gameController: GCController) {
        let profile = gameController.physicalInputProfile
        var buttons = Array(profile.allButtons)
        var thumbSticks = 0
        for dpad in profile.allDpads.sorted(by: { ($0.localizedName ?? "") < ($1.localizedName ?? "") }) {
            if dpad.isAnalog {
                let left = thumbSticks == 0
                thumbSticks += 1
                dpad.valueChangedHandler = { _, xValue, yValue in
                    self.handleGameControllerThumbStick(gameController, left: left, xValue: xValue, yValue: yValue)
                }
            } else {
                buttons += [dpad.up, dpad.down, dpad.left, dpad.right]
            }
        }
        for button in buttons {
            button.pressedChangedHandler = { button, value, pressed in
                self.handleGameControllerButton(gameController, button, value, pressed)
            }
        }
        addMissingGameControllerButtons(gameController, buttons)
    }

    @objc func handleGameControllerDidConnect(_ notification: Notification) {
        guard let gameController = notification.object as? GCController else {
            return
        }
        logger.info("game-controller: Connected \(gameController.vendorName ?? "unknown")")
        if let index = gameControllers.firstIndex(of: nil) {
            gameControllers[index] = gameController
        } else {
            gameControllers.append(gameController)
        }
        if let gamepad = gameController.extendedGamepad {
            setupExtendedGameController(gameController, gamepad)
        } else {
            setupGenericGameController(gameController)
        }
        if let number = gameControllerNumber(gameController: gameController) {
            makeToast(title: String(localized: "Game controller \(number) connected"))
        }
        updateGameControllers()
    }

    private func setupExtendedGameController(_ gameController: GCController, _ gamepad: GCExtendedGamepad) {
        gamepad.dpad.left.pressedChangedHandler = { button, value, pressed in
            self.handleGameControllerButton(gameController, button, value, pressed)
        }
        gamepad.dpad.right.pressedChangedHandler = { button, value, pressed in
            self.handleGameControllerButton(gameController, button, value, pressed)
        }
        gamepad.dpad.up.pressedChangedHandler = { button, value, pressed in
            self.handleGameControllerButton(gameController, button, value, pressed)
        }
        gamepad.dpad.down.pressedChangedHandler = { button, value, pressed in
            self.handleGameControllerButton(gameController, button, value, pressed)
        }
        gamepad.buttonA.pressedChangedHandler = { button, value, pressed in
            self.handleGameControllerButton(gameController, button, value, pressed)
        }
        gamepad.buttonB.pressedChangedHandler = { button, value, pressed in
            self.handleGameControllerButton(gameController, button, value, pressed)
        }
        gamepad.buttonX.pressedChangedHandler = { button, value, pressed in
            self.handleGameControllerButton(gameController, button, value, pressed)
        }
        gamepad.buttonY.pressedChangedHandler = { button, value, pressed in
            self.handleGameControllerButton(gameController, button, value, pressed)
        }
        gamepad.buttonMenu.pressedChangedHandler = { button, value, pressed in
            self.handleGameControllerButton(gameController, button, value, pressed)
        }
        gamepad.leftShoulder.pressedChangedHandler = { button, value, pressed in
            self.handleGameControllerButton(gameController, button, value, pressed)
        }
        gamepad.rightShoulder.pressedChangedHandler = { button, value, pressed in
            self.handleGameControllerButton(gameController, button, value, pressed)
        }
        gamepad.leftTrigger.pressedChangedHandler = { button, value, pressed in
            self.handleGameControllerButton(gameController, button, value, pressed)
        }
        gamepad.rightTrigger.pressedChangedHandler = { button, value, pressed in
            self.handleGameControllerButton(gameController, button, value, pressed)
        }
        gamepad.leftThumbstick.valueChangedHandler = { _, xValue, yValue in
            self.handleGameControllerThumbStick(gameController, left: true, xValue: xValue, yValue: yValue)
        }
        gamepad.rightThumbstick.valueChangedHandler = { _, xValue, yValue in
            self.handleGameControllerThumbStick(gameController, left: false, xValue: xValue, yValue: yValue)
        }
    }

    @objc func handleGameControllerDidDisconnect(notification: Notification) {
        guard let gameController = notification.object as? GCController else {
            return
        }
        if let number = gameControllerNumber(gameController: gameController) {
            makeToast(title: String(localized: "Game controller \(number) disconnected"))
        }
        if let index = gameControllers.firstIndex(of: gameController) {
            gameControllers[index] = nil
        }
        updateGameControllers()
    }

    func isShowingStatusGameController() -> Bool {
        database.show.gameController && isGameControllerConnected()
    }
}
