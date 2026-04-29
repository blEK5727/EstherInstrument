//
//  InstrumentImmersiveView.swift
//  yay
//
//  10 thin cylinders arranged in a ring around the player, the ring tilted 45°
//  about the world Z axis (left side low, right side high). Each cylinder
//  hangs vertically downward from its ring point; the higher its top sits, the
//  longer it dangles (lowest = 1×, highest = 2×). Look at one and pinch to
//  play its pentatonic note.
//

import SwiftUI
import RealityKit

struct InstrumentImmersiveView: View {
    @State private var audio = InstrumentAudio()

    private let barCount = 10
    private let ringRadius: Float = 1.0
    private let barLength: Float = 0.20      // length of the LOWEST bar; highest = 2×
    private let barRadius: Float = 0.008     // very thin
    private let ringCenter = SIMD3<Float>(0, 1.5, 0)
    private let tiltRadians: Float = .pi / 4

    var body: some View {
        RealityView { content in
            for i in 0..<barCount {
                content.add(makeBar(index: i))
            }
        }
        .gesture(
            SpatialTapGesture()
                .targetedToAnyEntity()
                .onEnded { value in
                    let entity = value.entity
                    guard entity.name.hasPrefix("note_"),
                          let idx = Int(entity.name.dropFirst("note_".count))
                    else { return }
                    audio.play(noteIndex: idx)
                    pulse(entity)
                }
        )
    }

    // MARK: - Bar construction

    private func makeBar(index i: Int) -> ModelEntity {
        let theta = (Float(i) / Float(barCount)) * 2 * .pi
        let cosT = cos(tiltRadians)
        let sinT = sin(tiltRadians)

        // Base ring (XZ plane) position, then rotate about world Z by 45°.
        let bx = ringRadius * sin(theta)
        let bz = ringRadius * cos(theta)
        let topPosition = ringCenter + SIMD3<Float>(bx * cosT, bx * sinT, bz)

        // Length scales with altitude: lowest bar (sin θ = -1) → 1× barLength,
        // highest bar (sin θ = +1) → 2× barLength, linear in between.
        let altitudeFactor = (sin(theta) + 1) / 2          // 0 … 1
        let length = barLength * (1 + altitudeFactor)

        var material = UnlitMaterial()
        material.color = .init(tint: morandiBlue(altitudeFactor: CGFloat(altitudeFactor)))

        let entity = ModelEntity(
            mesh: .generateCylinder(height: length, radius: barRadius),
            materials: [material]
        )
        entity.name = "note_\(i)"
        // Cylinder mesh is centered on the entity origin; offset down so the
        // TOP of every cylinder lines up with the original ring point.
        entity.position = topPosition - SIMD3<Float>(0, length / 2, 0)
        // Sphere collider sized to cover the whole cylinder + a bit of margin
        // for forgiving gaze targeting.
        let hitRadius = length / 2 + 0.04
        entity.components.set(CollisionComponent(shapes: [.generateSphere(radius: hitRadius)]))
        entity.components.set(InputTargetComponent())
        entity.components.set(HoverEffectComponent())
        return entity
    }

    // Morandi-style blue, deeper as the bar's altitude rises.
    // factor = 0 (lowest) keeps the original soft dusty blue;
    // factor = 1 (highest) drops brightness and bumps saturation slightly.
    private func morandiBlue(altitudeFactor f: CGFloat) -> UIColor {
        let hue: CGFloat = 0.58
        let saturation = 0.22 + 0.13 * f      // 0.22 → 0.35
        let brightness = 0.72 - 0.37 * f      // 0.72 → 0.35
        return UIColor(hue: hue, saturation: saturation, brightness: brightness, alpha: 1.0)
    }

    // MARK: - Pulse animation

    private func pulse(_ entity: Entity) {
        let original = entity.transform
        var bigger = original
        bigger.scale = original.scale * 1.25

        entity.move(to: bigger, relativeTo: entity.parent, duration: 0.08, timingFunction: .easeOut)
        Task {
            try? await Task.sleep(nanoseconds: 90_000_000)
            entity.move(to: original, relativeTo: entity.parent, duration: 0.18, timingFunction: .easeIn)
        }
    }
}
