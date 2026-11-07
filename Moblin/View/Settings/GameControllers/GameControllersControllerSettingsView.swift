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
            Section("Thumb sticks") {
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
            }
            if gameController.leftThumbStickFunction == .zoom || gameController.rightThumbStickFunction == .zoom {
                Section {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("Zoom speed")
                            Spacer()
                            GrayTextView(text: "\(Int(gameController.zoomSpeed.rounded())) %")
                        }
                        Slider(value: $gameController.zoomSpeed, in: 5 ... 100, step: 1)
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
