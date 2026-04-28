//
//  PinchSoundApp.swift
//  PinchSound
//
//  Replace your existing @main App file with this.
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
        .windowStyle(.volumetric)
        .defaultSize(width: 0.5, height: 0.45, depth: 0.01, in: .meters)

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
        .immersionStyle(selection: .constant(.progressive), in: .progressive)

        // Plain ring of spheres experience
        ImmersiveSpace(id: appModel.ringSpaceID) {
            RingImmersiveView()
                .environment(appModel)
                .onAppear  { appModel.immersiveSpaceState = .open }
                .onDisappear {
                    appModel.immersiveSpaceState = .closed
                    appModel.activeSpaceID = nil
                }
        }
        .immersionStyle(selection: .constant(.progressive), in: .progressive)
    }
}
