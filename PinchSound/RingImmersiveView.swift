import SwiftUI
import RealityKit

// MARK: - Isolated State (no clash with SceneState / ScenePhase in ImmersiveView.swift)

enum RingPhase {
    case idle
    case active
}

@Observable
class RingSceneState {
    var phase: RingPhase = .idle
    var ringBalls: [Entity] = []
    var audioResources: [AudioFileResource] = []
    var content: RealityViewContent?
}

// MARK: - RingImmersiveView

struct RingImmersiveView: View {

    // Ring configuration
    let ringBallCount  = 9
    let ringRadius: Float = 0.7       // metres from centre
    let ringCentreY: Float = 1.5      // height above floor
    let ringCentreZ: Float = -1.0     // distance in front of user
    let noteCount      = 5            // matches your sound1–sound5 assets

    @State private var ringState = RingSceneState()

    var body: some View {
        RealityView { content in
            ringState.content = content
            await loadAudio()
            spawnRing(in: content)
        }
        // Pinch / tap on any entity
        .gesture(
            SpatialTapGesture()
                .targetedToAnyEntity()
                .onEnded { value in
                    handlePinch(on: value.entity)
                }
        )
    }

    // MARK: - Audio

    func loadAudio() async {
        for i in 1...noteCount {
            let name = "sound\(i)"
            do {
                let res = try await AudioFileResource(named: "\(name).mp3")
                ringState.audioResources.append(res)
                print("✅ RingView loaded \(name).mp3")
            } catch {
                print("❌ RingView failed to load \(name).mp3: \(error)")
            }
        }
    }

    // MARK: - Spawn ring

    func spawnRing(in content: RealityViewContent) {
        let centre = SIMD3<Float>(0, ringCentreY, ringCentreZ)

        for i in 0..<ringBallCount {
            let angle = Float(i) / Float(ringBallCount) * 2 * Float.pi
            let x = centre.x + cos(angle) * ringRadius
            let z = centre.z + sin(angle) * ringRadius
            let position = SIMD3<Float>(x, centre.y, z)

            let ball = makeRingBall(index: i)
            ball.position = position

            // Scale in from zero for a nice entrance
            ball.scale = .init(repeating: 0.01)
            content.add(ball)
            ringState.ringBalls.append(ball)

            // Staggered pop-in animation
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(i) * 120_000_000)
                ball.move(
                    to: Transform(
                        scale: .init(repeating: 1.0),
                        rotation: ball.orientation,
                        translation: position
                    ),
                    relativeTo: ball.parent,
                    duration: 0.5,
                    timingFunction: .easeOut
                )
            }
        }

        // Start gentle float animation for all balls
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(ringBallCount) * 120_000_000 + 600_000_000)
            startFloating()
        }

        ringState.phase = .active
        print("✅ Ring spawned with \(ringBallCount) balls")
    }

    // MARK: - Ball factory

    func makeRingBall(index: Int) -> ModelEntity {
        let mesh = MeshResource.generateSphere(radius: 0.05)

        var mat = PhysicallyBasedMaterial()
        let color = ringGradientColor(index: index, total: ringBallCount)
        mat.baseColor        = .init(tint: color.withAlphaComponent(0.55))
        mat.emissiveColor    = .init(color: color)
        mat.emissiveIntensity = 1.8
        mat.blending         = .transparent(opacity: .init(floatLiteral: 0.6))
        mat.roughness        = .init(floatLiteral: 0.05)
        mat.metallic         = .init(floatLiteral: 0.1)
        mat.clearcoat        = .init(floatLiteral: 1.0)
        mat.clearcoatRoughness = .init(floatLiteral: 0.05)

        let ball = ModelEntity(mesh: mesh, materials: [mat])
        ball.name = "ringball_\(index)"

        ball.components.set(CollisionComponent(shapes: [.generateSphere(radius: 0.05)]))
        ball.components.set(InputTargetComponent())
        ball.components.set(HoverEffectComponent())

        return ball
    }

    func ringGradientColor(index: Int, total: Int) -> UIColor {
        // Full hue sweep around the ring
        let hue = CGFloat(index) / CGFloat(total)
        return UIColor(hue: hue, saturation: 0.8, brightness: 1.0, alpha: 1.0)
    }

    // MARK: - Gentle float

    func startFloating() {
        for (i, ball) in ringState.ringBalls.enumerated() {
            let phaseOffset = Float(i) / Float(ringBallCount) * 2 * Float.pi
            let baseY = ball.position.y

            Task { @MainActor in
                let start = Date()
                while !Task.isCancelled {
                    let elapsed = Float(Date().timeIntervalSince(start))
                    let offset  = sin(elapsed * 1.5 + phaseOffset) * 0.025
                    ball.position.y = baseY + offset
                    try? await Task.sleep(nanoseconds: 16_000_000) // ~60 fps
                }
            }
        }
    }

    // MARK: - Pinch handler

    func handlePinch(on entity: Entity) {
        guard entity.name.hasPrefix("ringball_") else { return }

        let index     = Int(entity.name.replacingOccurrences(of: "ringball_", with: "")) ?? 0
        let noteIndex = index % noteCount

        print("👌 Pinched ringball_\(index) → playing sound\(noteIndex + 1)")

        if noteIndex < ringState.audioResources.count {
            entity.playAudio(ringState.audioResources[noteIndex])
        }

        ringFlash(entity)
        ringRipple(entity)
    }

    // MARK: - Visual feedback

    func ringFlash(_ ball: Entity) {
        guard let model = ball as? ModelEntity,
              var mat   = model.model?.materials.first as? PhysicallyBasedMaterial else { return }

        let peak: Float    = 8.0
        let restore: Float = 1.8
        mat.emissiveIntensity = peak
        model.model?.materials = [mat]

        Task { @MainActor in
            let steps = 20
            for step in 0..<steps {
                try? await Task.sleep(nanoseconds: 20_000_000)
                let t = Float(step) / Float(steps)
                if var m = model.model?.materials.first as? PhysicallyBasedMaterial {
                    m.emissiveIntensity = peak - (peak - restore) * t
                    model.model?.materials = [m]
                }
            }
        }
    }

    func ringRipple(_ ball: Entity) {
        guard let content = ringState.content else { return }

        let idx   = Int(ball.name.replacingOccurrences(of: "ringball_", with: "")) ?? 0
        let color = ringGradientColor(index: idx, total: ringBallCount)

        let rippleMesh = MeshResource.generateSphere(radius: 0.05)
        var rippleMat  = PhysicallyBasedMaterial()
        rippleMat.baseColor        = .init(tint: color.withAlphaComponent(0.0))
        rippleMat.emissiveColor    = .init(color: color)
        rippleMat.emissiveIntensity = 4.0
        rippleMat.blending         = .transparent(opacity: .init(floatLiteral: 0.55))
        rippleMat.roughness        = .init(floatLiteral: 0.4)

        let ripple = ModelEntity(mesh: rippleMesh, materials: [rippleMat])
        ripple.position = ball.position(relativeTo: nil)
        content.add(ripple)

        ripple.move(
            to: Transform(
                scale: [5.0, 5.0, 5.0],
                rotation: ripple.orientation,
                translation: ripple.position
            ),
            relativeTo: nil,
            duration: 0.6,
            timingFunction: .easeOut
        )

        Task { @MainActor in
            let steps = 18
            for step in 0..<steps {
                try? await Task.sleep(nanoseconds: 33_000_000)
                let t = Float(step) / Float(steps)
                if var m = ripple.model?.materials.first as? PhysicallyBasedMaterial {
                    m.emissiveIntensity = 4.0 * (1.0 - t)
                    m.blending          = .transparent(opacity: .init(floatLiteral: Float(0.55) * (1.0 - t)))
                    ripple.model?.materials = [m]
                }
            }
            ripple.removeFromParent()
        }
    }
}

#Preview(immersionStyle: .mixed) {
    RingImmersiveView()
}
