//
//  PinchSoundApp.swift  (or yayApp.swift — rename to match your @main file)
//

import SwiftUI

@main
struct PinchSoundApp: App {
    @State private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appModel)
        }

        // 1 — Mbira + spiral spheres
        ImmersiveSpace(id: appModel.instrumentSpaceID) {
            ImmersiveView()
                .environment(appModel)
                .onAppear {
                    appModel.immersiveSpaceState = .open
                    appModel.activeSpaceID = appModel.instrumentSpaceID
                }
                .onDisappear {
                    appModel.immersiveSpaceState = .closed
                    appModel.activeSpaceID = nil
                }
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)

        // 2 — Green box ring
        ImmersiveSpace(id: appModel.ringSpaceID) {
            RingImmersiveView()
                .environment(appModel)
                .onAppear {
                    appModel.immersiveSpaceState = .open
                    appModel.activeSpaceID = appModel.ringSpaceID
                }
                .onDisappear {
                    appModel.immersiveSpaceState = .closed
                    appModel.activeSpaceID = nil
                }
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)

        // 3 — Tilted stagger bar ring
        ImmersiveSpace(id: appModel.staggerSpaceID) {
            InstrumentImmersiveView()
                .environment(appModel)
                .onAppear {
                    appModel.immersiveSpaceState = .open
                    appModel.activeSpaceID = appModel.staggerSpaceID
                }
                .onDisappear {
                    appModel.immersiveSpaceState = .closed
                    appModel.activeSpaceID = nil
                }
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)

        // 4 — Ambient soundscape orbs
        ImmersiveSpace(id: appModel.ambientSpaceID) {
            AmbientImmersiveView()
                .environment(appModel)
                .onAppear {
                    appModel.immersiveSpaceState = .open
                    appModel.activeSpaceID = appModel.ambientSpaceID
                }
                .onDisappear {
                    appModel.immersiveSpaceState = .closed
                    appModel.activeSpaceID = nil
                }
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}
