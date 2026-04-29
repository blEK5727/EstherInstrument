import SwiftUI

@main
struct PinchSoundApp: App {
    @State private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appModel)
        }

        // Mbira + spheres experience
        ImmersiveSpace(id: appModel.instrumentSpaceID) {
            ImmersiveView()
                .environment(appModel)
                .onAppear  { appModel.immersiveSpaceState = .open }
                .onDisappear {
                    appModel.immersiveSpaceState = .closed
                    appModel.activeSpaceID = nil
                }
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)

        // Ring of spheres experience
        ImmersiveSpace(id: appModel.ringSpaceID) {
            RingImmersiveView()
                .environment(appModel)
                .onAppear  { appModel.immersiveSpaceState = .open }
                .onDisappear {
                    appModel.immersiveSpaceState = .closed
                    appModel.activeSpaceID = nil
                }
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
        
        // 🆕 Christy's tilted ring of bars
        ImmersiveSpace(id: appModel.christyInstrumentSpaceID) {
            InstrumentImmersiveView()
                .environment(appModel)
                .onAppear  { appModel.immersiveSpaceState = .open }
                .onDisappear {
                    appModel.immersiveSpaceState = .closed
                    appModel.activeSpaceID = nil
                }
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}
