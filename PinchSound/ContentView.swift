//
//  ContentView.swift
//

import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    var body: some View {
        VStack(spacing: 24) {
            Text("Instruments")
                .font(.extraLargeTitle2)
                .fontWeight(.bold)

            Text("Choose an experience")
                .foregroundStyle(.secondary)

            Divider()
                .padding(.vertical, 8)

            SpaceButton(
                title: "Mbira Instrument",
                subtitle: "Pinch the mbira to unlock spheres",
                systemImage: "waveform.and.mic",
                isActive: appModel.activeSpaceID == appModel.instrumentSpaceID,
                disabled: appModel.immersiveSpaceState == .inTransition
            ) {
                await toggleSpace(id: appModel.instrumentSpaceID)
            }

            SpaceButton(
                title: "Ring of Spheres",
                subtitle: "Pinch any sphere to play a note",
                systemImage: "circle.grid.3x3.fill",
                isActive: appModel.activeSpaceID == appModel.ringSpaceID,
                disabled: appModel.immersiveSpaceState == .inTransition
            ) {
                await toggleSpace(id: appModel.ringSpaceID)
            }

            SpaceButton(
                title: "Stagger Ring",
                subtitle: "Tilted ring of bars — look and pinch to play",
                systemImage: "slider.vertical.3",
                isActive: appModel.activeSpaceID == appModel.staggerSpaceID,
                disabled: appModel.immersiveSpaceState == .inTransition
            ) {
                await toggleSpace(id: appModel.staggerSpaceID)
            }
        }
        .padding(40)
    }

    // Opens the tapped space, closing any currently open space first.
    private func toggleSpace(id: String) async {
        switch appModel.immersiveSpaceState {
        case .open:
            appModel.immersiveSpaceState = .inTransition
            await dismissImmersiveSpace()
            if appModel.activeSpaceID != id {
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

// MARK: - Reusable button

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
