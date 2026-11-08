import SwiftUI

struct GameControllersControllerSettingsView: View {
    let model: Model
    @ObservedObject var gameController: SettingsGameController

    var body: some View {
        Form {
            Section("Buttons") {
                ForEach(gameController.buttons) { button in
                    GameControllersControllerButtonSettingsView(model: model, button: button)
                }
            }
            Section {
                GameControllersControllerThumbStickSettingsView(
                    image: "l.joystick",
                    name: "Left",
                    function: $gameController.leftThumbStickFunction
                )
                GameControllersControllerThumbStickSettingsView(
                    image: "r.joystick",
                    name: "Right",
                    function: $gameController.rightThumbStickFunction
                )
                GameControllersControllerThumbStickSettingsView(
                    image: "dpad",
                    name: "D-pad",
                    function: $gameController.dpadFunction
                )
            } header: {
                Text("Thumb sticks")
            } footer: {
                Text("""
                Some controllers, like a single Joy-Con, report their stick as a D-pad. Set a function \
                on the D-pad to use it like a stick. Its buttons then stop doing their own functions.
                """)
            }
            if gameController.leftThumbStickFunction == .zoom || gameController.rightThumbStickFunction == .zoom
                || gameController.dpadFunction == .zoom
            {
                Section {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("Zoom speed")
                            Spacer()
                            GrayTextView(text: "\(Int(gameController.zoomSpeed.rounded())) %")
                        }
                        Slider(value: $gameController.zoomSpeed, in: 5 ... 100, step: 1)
                    }
                    Toggle("Limit zoom", isOn: $gameController.zoomLimitEnabled)
                    if gameController.zoomLimitEnabled {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text("Most zoomed out")
                                Spacer()
                                GrayTextView(text: String(format: "%.1fx", gameController.zoomMinimum))
                            }
                            Slider(value: $gameController.zoomMinimum, in: 0.5 ... 10, step: 0.1)
                                .onChange(of: gameController.zoomMinimum) { _ in
                                    gameController.zoomMaximum = max(gameController.zoomMaximum,
                                                                     gameController.zoomMinimum)
                                }
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text("Most zoomed in")
                                Spacer()
                                GrayTextView(text: String(format: "%.1fx", gameController.zoomMaximum))
                            }
                            Slider(value: $gameController.zoomMaximum, in: 1 ... 40, step: 0.5)
                                .onChange(of: gameController.zoomMaximum) { _ in
                                    gameController.zoomMinimum = min(gameController.zoomMinimum,
                                                                     gameController.zoomMaximum)
                                }
                        }
                    }
                } footer: {
                    Text("""
                    Push the stick up to zoom in and down to zoom out. The farther you push, the \
                    faster it zooms. Lower the speed for finer control.
                    """)
                }
            }
        }
        .navigationTitle("Controller")
    }
}
