//
//  ContentView.swift
//

import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    var body: some View {
        VStack(spacing: 12) {
            Text("Dimensional Soundscape")
                .font(.title2)
                .fontWeight(.bold)

            Text("Choose an experience")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Divider()
                .padding(.vertical, 4)

            SpaceButton(
                title: "Mbira",
                subtitle: "Pinch the mbira to unlock music notes",
                systemImage: "waveform.and.mic",
                isActive: appModel.activeSpaceID == appModel.instrumentSpaceID,
                disabled: appModel.immersiveSpaceState == .inTransition
            ) {
                await toggleSpace(id: appModel.instrumentSpaceID)
            }

            SpaceButton(
                title: "Glockenspiel Rings",
                subtitle: "Pinch any cube to play a note",
                systemImage: "circle.grid.3x3.fill",
                isActive: appModel.activeSpaceID == appModel.ringSpaceID,
                disabled: appModel.immersiveSpaceState == .inTransition
            ) {
                await toggleSpace(id: appModel.ringSpaceID)
            }

            SpaceButton(
                title: "Gu-Zheng Ring",
                subtitle: "Look and pinch to play",
                systemImage: "slider.vertical.3",
                isActive: appModel.activeSpaceID == appModel.staggerSpaceID,
                disabled: appModel.immersiveSpaceState == .inTransition
            ) {
                await toggleSpace(id: appModel.staggerSpaceID)
            }

            SpaceButton(
                title: "Ambient Soundscape",
                subtitle: "Pinch shapes to layer ambient sounds",
                systemImage: "waveform.path.ecg",
                isActive: appModel.activeSpaceID == appModel.ambientSpaceID,
                disabled: appModel.immersiveSpaceState == .inTransition
            ) {
                await toggleSpace(id: appModel.ambientSpaceID)
            }
        }
        .padding(24)
        .frame(width: 340)
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
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.body)
                    .foregroundStyle(isActive ? .white : .primary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(isActive ? .white : .primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(isActive ? .white.opacity(0.8) : .secondary)
                }
                Spacer()

                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isActive ? Color.accentColor : Color.primary.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
        .environment(AppModel())
}
