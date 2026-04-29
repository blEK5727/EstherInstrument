//
//  ContentView.swift
//  PinchSound
//

import SwiftUI
import RealityKit
import RealityKitContent

struct ContentView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    var body: some View {
        VStack(spacing: 24) {
            Text("PinchSound")
                .font(.extraLargeTitle2)
                .fontWeight(.bold)

            Text("Choose an experience")
                .foregroundStyle(.secondary)

            Divider()
                .padding(.vertical, 8)

            // --- Mbira experience ---
            SpaceButton(
                title: "Mbira Instrument",
                subtitle: "Pinch the mbira to unlock spheres",
                systemImage: "waveform.and.mic",
                isActive: appModel.activeSpaceID == appModel.instrumentSpaceID,
                disabled: appModel.immersiveSpaceState == .inTransition
            ) {
                await toggleSpace(id: appModel.instrumentSpaceID)
            }

            // --- Ring experience ---
            SpaceButton(
                title: "Ring of Spheres",
                subtitle: "Pinch any sphere to play a note",
                systemImage: "circle.grid.3x3.fill",
                isActive: appModel.activeSpaceID == appModel.ringSpaceID,
                disabled: appModel.immersiveSpaceState == .inTransition
            ) {
                await toggleSpace(id: appModel.ringSpaceID)
            }
            // 🆕 --- Christy's tilted ring instrument ---
            SpaceButton(
                title: "Tilted Ring Bars",
                subtitle: "Pinch a hanging bar to play a pentatonic note",
                systemImage: "music.note.list",
                isActive: appModel.activeSpaceID == appModel.christyInstrumentSpaceID,
                disabled: appModel.immersiveSpaceState == .inTransition
            ) {
                await toggleSpace(id: appModel.christyInstrumentSpaceID)
            }
        }
        .padding(40)
    }

    // Opens the requested space, or closes it if it's already open.
    // Closes any other open space first.
    private func toggleSpace(id: String) async {
        switch appModel.immersiveSpaceState {
        case .open:
            appModel.immersiveSpaceState = .inTransition
            await dismissImmersiveSpace()
            // If the user tapped a different button, open the new space
            if appModel.activeSpaceID != id {
                appModel.immersiveSpaceState = .inTransition
                await openSpace(id: id)
            }
        case .closed:
            await openSpace(id: id)
        case .inTransition:
            break
        }
    }

    private func openSpace(id: String) async {
        appModel.immersiveSpaceState = .inTransition
        switch await openImmersiveSpace(id: id) {
        case .opened:
            appModel.activeSpaceID = id
        case .userCancelled, .error:
            fallthrough
        @unknown default:
            appModel.immersiveSpaceState = .closed
            appModel.activeSpaceID = nil
        }
    }
}

// MARK: - Reusable button component

private struct SpaceButton: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let isActive: Bool
    let disabled: Bool
    let action: () async -> Void

    var body: some View {
        Button {
            Task { @MainActor in await action() }
        } label: {
            HStack(spacing: 16) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(isActive ? .white : .primary)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(isActive ? .white : .primary)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(isActive ? .white.opacity(0.8) : .secondary)
                }
                Spacer()

                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(isActive ? Color.accentColor : Color.primary.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
        .environment(AppModel())
}
