import SwiftUI
import RealityKit
import RealityKitContent

struct ImmersiveView: View {
    
    let ballCount = 15
    let noteCount = 5
    
    let spiralTurns: Float = 2.0
    let spiralRadius: Float = 0.7
    let spiralBottomY: Float = 1.0
    let spiralTopY: Float = 2.0
    let clusterCenter: SIMD3<Float> = [0, 2.0, -2.2]
    let playerCenter: SIMD3<Float> = [0, 1.5, 0]
    
    let songNotes: [Int] = [1, 2, 3, 2, 1, 3, 5, 1]
    
    let mbiraTriggerCount = 3
    let bubbleAppearDelay: UInt64 = 5_000_000_000
    
    var body: some View {
        RealityView { content, attachments in
            
            // Phase 1: mbira
            await setupMbira(content: content, attachments: attachments)
            
            // Ball cluster (hidden until phase 2)
            let clusterRoot = Entity()
            clusterRoot.name = "clusterRoot"
            clusterRoot.position = clusterCenter
            clusterRoot.isEnabled = false
            
            for i in 0..<ballCount {
                let ball = makeBall(index: i, total: ballCount)
                ball.position = clusterOffset(index: i, total: ballCount)
                clusterRoot.addChild(ball)
            }
            
            content.add(clusterRoot)
            
            await preloadAudioResources()
            
            state.clusterRoot = clusterRoot
            state.content = content
            
        } attachments: {
            Attachment(id: "mbiraHint") {
                Text("Pinch to explore the mbira")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
            }
        }
        .gesture(
            SpatialTapGesture()
                .targetedToAnyEntity()
                .onEnded { value in
                    handlePinch(on: value.entity)
                }
        )
    }
    
    @State private var state = SceneState()
    
    // MARK: - Setup mbira
    
    func setupMbira(content: RealityViewContent, attachments: RealityViewAttachments) async {
        guard let scene = try? await Entity(named: "Immersive", in: realityKitContentBundle) else {
            print("❌ Failed to load Immersive scene")
            return
        }
        
        guard let mbira = scene.findEntity(named: "mbira") else {
            print("❌ Couldn't find 'mbira' entity in scene")
            return
        }
        
        let collisionBounds = mbira.visualBounds(relativeTo: mbira)
        mbira.components.set(CollisionComponent(
            shapes: [.generateBox(size: collisionBounds.extents)]
        ))
        mbira.components.set(InputTargetComponent())
        mbira.components.set(HoverEffectComponent())
        
        content.add(scene)
        state.mbira = mbira
        state.mbiraOriginalRotation = mbira.orientation
        
        if let hintPanel = attachments.entity(for: "mbiraHint") {
            hintPanel.position = [0, 0.25, 0]
            mbira.addChild(hintPanel)
            state.mbiraHintPanel = hintPanel
            print("✅ Hint panel attached")
        } else {
            print("❌ Hint panel not found")
        }
        
        startMbiraFloating(mbira)
        
        print("✅ mbira loaded. Pinch \(mbiraTriggerCount) times to start")
    }
    
    func startMbiraFloating(_ mbira: Entity) {
        let baseY = mbira.position.y
        Task { @MainActor in
            let startTime = Date()
            while !Task.isCancelled {
                if state.phase != .intro && state.phase != .listening { break }
                let elapsed = Float(Date().timeIntervalSince(startTime))
                let offset = sin(elapsed * 2.0 * .pi / 4.0) * 0.02
                mbira.position.y = baseY + offset
                try? await Task.sleep(nanoseconds: 16_000_000)
            }
        }
    }
    
    // MARK: - Audio preload
    
    func preloadAudioResources() async {
        for i in 1...noteCount {
            let filename = "sound\(i)"
            do {
                let resource = try await AudioFileResource(named: "\(filename).mp3")
                state.audioResources.append(resource)
                print("✅ Loaded audio: \(filename).mp3")
            } catch {
                print("❌ Failed to load \(filename).mp3 — \(error)")
            }
        }
        
        do {
            let bg = try await AudioFileResource(
                named: "mbira_song.mp3",
                configuration: .init(shouldLoop: false)
            )
            state.backgroundMusic = bg
            print("✅ Loaded background music")
        } catch {
            print("❌ Failed to load background music: \(error)")
        }
    }
    
    // MARK: - Pinch handler
    
    func handlePinch(on entity: Entity) {
        // Phase 1: pinch mbira
        if state.phase == .intro && (entity.name == "mbira" || isPartOfMbira(entity)) {
            handleMbiraPinch()
            return
        }
        
        // Pinch bubble
        if entity.name == "bubble", state.phase == .listening {
            print("🫧 Bubble pinched, entering ball phase")
            state.phase = .activated
            dismissBubble()
            
            state.mbiraHintPanel?.removeFromParent()
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 300_000_000)
                fadeOutBackgroundMusic()
                showClusterAndStartReleasing()
            }
            return
        }
        
        // Phase 2: pinch ball
        if entity.name.hasPrefix("ball_"), state.phase == .performing {
            playBall(entity)
            return
        }
        
        print("⚠️ Pinch ignored (entity=\(entity.name), phase=\(state.phase))")
    }
    
    func isPartOfMbira(_ entity: Entity) -> Bool {
        var current: Entity? = entity
        while current != nil {
            if current?.name == "mbira" {
                return true
            }
            current = current?.parent
        }
        return false
    }
    
    // MARK: - mbira pinch
    
    func handleMbiraPinch() {
        guard let mbira = state.mbira else { return }
        guard !state.mbiraIsRotating else {
            print("⏳ mbira rotating, ignoring pinch")
            return
        }
        
        state.mbiraPinchCount += 1
        print("👌 mbira pinch #\(state.mbiraPinchCount)")
        
        rotateMbira120Degrees(mbira)
        
        if state.mbiraPinchCount >= mbiraTriggerCount {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                startBackgroundMusic()
            }
        }
    }
    
    func rotateMbira120Degrees(_ mbira: Entity) {
        state.mbiraIsRotating = true
        
        let currentRotation = mbira.orientation
        let increment = simd_quatf(angle: 2.0 * .pi / 3.0, axis: [0, 1, 0])
        let targetRotation = currentRotation * increment
        
        Task { @MainActor in
            let duration: Double = 1.0
            let steps = 30
            let stepDuration: UInt64 = UInt64(duration / Double(steps) * 1_000_000_000)
            
            for step in 1...steps {
                let t = Float(step) / Float(steps)
                let easedT = t * t * (3 - 2 * t)
                let interpolated = simd_slerp(currentRotation, targetRotation, easedT)
                mbira.orientation = interpolated
                try? await Task.sleep(nanoseconds: stepDuration)
            }
            
            mbira.orientation = targetRotation
            state.mbiraIsRotating = false
        }
    }
    
    // MARK: - Background music
    
    func startBackgroundMusic() {
        guard let mbira = state.mbira else { return }
        guard let bg = state.backgroundMusic else {
            print("❌ Background music not loaded")
            return
        }
        
        print("🎵 Starting background music")
        state.phase = .listening
        
        let playbackController = mbira.playAudio(bg)
        state.audioController = playbackController
        
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: bubbleAppearDelay)
            spawnBubble()
        }
    }
    
    // MARK: - Bubble
    
    func spawnBubble() {
        guard let content = state.content,
              let mbira = state.mbira else { return }
        
        print("🫧 Bubble appearing")
        
        let bubbleMesh = MeshResource.generateSphere(radius: 0.04)
        var bubbleMat = PhysicallyBasedMaterial()
        let bubbleColor = UIColor(hue: 0.55, saturation: 0.4, brightness: 1.0, alpha: 1.0)
        bubbleMat.baseColor = .init(tint: bubbleColor.withAlphaComponent(0.3))
        bubbleMat.emissiveColor = .init(color: bubbleColor)
        bubbleMat.emissiveIntensity = 4.0
        bubbleMat.blending = .transparent(opacity: .init(floatLiteral: 0.5))
        bubbleMat.roughness = .init(floatLiteral: 0.05)
        bubbleMat.clearcoat = .init(floatLiteral: 1.0)
        
        let bubble = ModelEntity(mesh: bubbleMesh, materials: [bubbleMat])
        bubble.name = "bubble"
        
        let mbiraWorldPos = mbira.position(relativeTo: nil)
        bubble.position = [mbiraWorldPos.x, mbiraWorldPos.y + 0.4, mbiraWorldPos.z]
        
        bubble.components.set(CollisionComponent(shapes: [.generateSphere(radius: 0.04)]))
        bubble.components.set(InputTargetComponent())
        bubble.components.set(HoverEffectComponent())
        
        bubble.scale = [0.01, 0.01, 0.01]
        content.add(bubble)
        state.bubble = bubble
        
        bubble.move(
            to: Transform(scale: [1.0, 1.0, 1.0], rotation: bubble.orientation, translation: bubble.position),
            relativeTo: bubble.parent,
            duration: 0.8,
            timingFunction: .easeOut
        )
        
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 800_000_000)
            startBubblePulse(bubble)
        }
    }
    
    func startBubblePulse(_ bubble: Entity) {
        Task { @MainActor in
            let startTime = Date()
            while !Task.isCancelled {
                if state.phase != .listening { break }
                let elapsed = Float(Date().timeIntervalSince(startTime))
                let scale = 1.0 + sin(elapsed * 2.0 * .pi / 2.0) * 0.15
                bubble.scale = SIMD3<Float>(repeating: scale)
                try? await Task.sleep(nanoseconds: 16_000_000)
            }
        }
    }
    
    func dismissBubble() {
        guard let bubble = state.bubble else { return }
        
        bubble.move(
            to: Transform(scale: [0.01, 0.01, 0.01], rotation: bubble.orientation, translation: bubble.position),
            relativeTo: bubble.parent,
            duration: 0.4,
            timingFunction: .easeIn
        )
        
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            bubble.removeFromParent()
            state.bubble = nil
        }
    }
    
    func fadeOutBackgroundMusic() {
        guard let controller = state.audioController else { return }
        controller.fade(to: .zero, duration: 1.5)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            controller.stop()
            state.audioController = nil
        }
    }
    
    // MARK: - Cluster reveal
    
    func showClusterAndStartReleasing() {
        guard let cluster = state.clusterRoot else { return }
        cluster.isEnabled = true
        
        if let mbira = state.mbira {
            mbira.move(
                to: Transform(
                    scale: [0.001, 0.001, 0.001],
                    rotation: mbira.orientation,
                    translation: mbira.position
                ),
                relativeTo: mbira.parent,
                duration: 1.0,
                timingFunction: .easeIn
            )
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_100_000_000)
                mbira.isEnabled = false
            }
        }
        
        startRotation(entity: cluster)
        
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            startBallsRelease()
        }
    }
    
    // MARK: - Ball play (tutorial mode)
    
    func playBall(_ ball: Entity) {
        let ballIndex = Int(ball.name.replacingOccurrences(of: "ball_", with: "")) ?? 0
        let noteIndex = ballIndex % noteCount
        let noteNumber = noteIndex + 1
        
        let expectedNote = state.currentExpectedNote
        let isCorrect = (noteNumber == expectedNote)
        
        if !isCorrect {
            print("❌ Wrong note. Expected sound\(expectedNote), got sound\(noteNumber)")
            flashError(ball)
            return
        }
        
        print("✅ Correct! sound\(noteNumber)")
        
        if noteIndex < state.audioResources.count {
            let resource = state.audioResources[noteIndex]
            ball.playAudio(resource)
        }
        
        emitRipple(from: ball)
        flashHighlight(ball)
        clearHighlights()
        
        state.songProgress += 1
        
        if state.songProgress >= songNotes.count {
            print("🎉 Song complete!")
            songCompleted()
        } else {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 500_000_000)
                highlightNextNote()
            }
        }
    }
    
    func highlightNextNote() {
        guard state.songProgress < songNotes.count else { return }
        let expectedNote = songNotes[state.songProgress]
        state.currentExpectedNote = expectedNote
        print("👉 Next: sound\(expectedNote)")
        
        for ball in state.spiralBalls {
            guard let model = ball as? ModelEntity else { continue }
            let ballIndex = Int(ball.name.replacingOccurrences(of: "ball_", with: "")) ?? 0
            let noteNumber = (ballIndex % noteCount) + 1
            
            if noteNumber == expectedNote {
                startHighlightAnimation(model)
            }
        }
    }
    
    func startHighlightAnimation(_ ball: ModelEntity) {
        let ballName = ball.name
        state.highlightedBalls.insert(ballName)
        
        Task { @MainActor in
            let startTime = Date()
            while !Task.isCancelled {
                if !state.highlightedBalls.contains(ballName) { break }
                let elapsed = Float(Date().timeIntervalSince(startTime))
                let pulse = 6.0 + sin(elapsed * 2.0 * .pi / 1.0) * 2.0
                
                if var mat = ball.model?.materials.first as? PhysicallyBasedMaterial {
                    mat.emissiveIntensity = pulse
                    ball.model?.materials = [mat]
                }
                try? await Task.sleep(nanoseconds: 33_000_000)
            }
            
            if var mat = ball.model?.materials.first as? PhysicallyBasedMaterial {
                mat.emissiveIntensity = 1.5
                ball.model?.materials = [mat]
            }
        }
    }
    
    func clearHighlights() {
        state.highlightedBalls.removeAll()
    }
    
    func flashError(_ ball: Entity) {
        guard let model = ball as? ModelEntity else { return }
        guard var mat = model.model?.materials.first as? PhysicallyBasedMaterial else { return }
        
        let originalColor = colorOfBall(ball)
        mat.emissiveColor = .init(color: UIColor.red)
        mat.emissiveIntensity = 5.0
        model.model?.materials = [mat]
        
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            if var restored = model.model?.materials.first as? PhysicallyBasedMaterial {
                restored.emissiveColor = .init(color: originalColor)
                restored.emissiveIntensity = 1.5
                model.model?.materials = [restored]
            }
        }
    }
    
    func songCompleted() {
        for ball in state.spiralBalls {
            guard let model = ball as? ModelEntity else { continue }
            flashHighlight(model)
            emitRipple(from: model)
        }
        
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            state.songProgress = 0
            print("🔄 Reset, play again")
            highlightNextNote()
        }
    }
    
    // MARK: - Ripple & highlight
    
    func emitRipple(from ball: Entity) {
        guard let content = state.content else { return }
        let ballColor = colorOfBall(ball)
        
        let rippleMesh = MeshResource.generateSphere(radius: 0.04)
        var rippleMaterial = PhysicallyBasedMaterial()
        rippleMaterial.baseColor = .init(tint: ballColor.withAlphaComponent(0.0))
        rippleMaterial.emissiveColor = .init(color: ballColor)
        rippleMaterial.emissiveIntensity = 4.0
        rippleMaterial.blending = .transparent(opacity: .init(floatLiteral: 0.6))
        rippleMaterial.roughness = .init(floatLiteral: 0.5)
        
        let ripple = ModelEntity(mesh: rippleMesh, materials: [rippleMaterial])
        ripple.position = ball.position(relativeTo: nil)
        content.add(ripple)
        
        ripple.move(
            to: Transform(scale: [6.0, 6.0, 6.0], rotation: ripple.orientation, translation: ripple.position),
            relativeTo: nil,
            duration: 0.6,
            timingFunction: .easeOut
        )
        
        Task { @MainActor in
            let steps = 20
            for step in 0..<steps {
                try? await Task.sleep(nanoseconds: 30_000_000)
                let t = Float(step) / Float(steps)
                if var mat = ripple.model?.materials.first as? PhysicallyBasedMaterial {
                    mat.emissiveIntensity = 4.0 * (1.0 - t)
                    mat.blending = .transparent(opacity: .init(floatLiteral: 0.6 * (1.0 - t)))
                    ripple.model?.materials = [mat]
                }
            }
            ripple.removeFromParent()
        }
    }
    
    func flashHighlight(_ ball: Entity) {
        guard let model = ball as? ModelEntity else { return }
        guard var material = model.model?.materials.first as? PhysicallyBasedMaterial else { return }
        
        let originalIntensity: Float = 1.5
        let peakIntensity: Float = 6.0
        material.emissiveIntensity = peakIntensity
        model.model?.materials = [material]
        
        Task { @MainActor in
            let steps = 15
            for step in 0..<steps {
                try? await Task.sleep(nanoseconds: 25_000_000)
                let t = Float(step) / Float(steps)
                if var mat = model.model?.materials.first as? PhysicallyBasedMaterial {
                    mat.emissiveIntensity = peakIntensity - (peakIntensity - originalIntensity) * t
                    model.model?.materials = [mat]
                }
            }
        }
    }
    
    func colorOfBall(_ ball: Entity) -> UIColor {
        if ball.name.hasPrefix("ball_") {
            let idx = Int(ball.name.replacingOccurrences(of: "ball_", with: "")) ?? 0
            return greenGradientColor(index: idx, total: ballCount)
        }
        return UIColor(hue: 0.33, saturation: 0.7, brightness: 1.0, alpha: 1.0)
    }
    
    // MARK: - Ball release
    
    func startBallsRelease() {
        guard let clusterRoot = state.clusterRoot,
              let content = state.content else { return }
        
        let balls = clusterRoot.children
            .filter { $0.name.hasPrefix("ball_") }
            .sorted { (a, b) -> Bool in
                let aIdx = Int(a.name.replacingOccurrences(of: "ball_", with: "")) ?? 0
                let bIdx = Int(b.name.replacingOccurrences(of: "ball_", with: "")) ?? 0
                return aIdx < bIdx
            }
        
        state.spiralBalls = Array(balls)
        
        for (i, ball) in balls.enumerated() {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(i) * 200_000_000)
                releaseBall(ball, toSpiralIndex: i, total: balls.count, content: content)
            }
        }
        
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(balls.count) * 200_000_000 + 2_200_000_000)
            enterPerformanceMode()
        }
    }
    
    func enterPerformanceMode() {
        print("🎼 Performance mode, tutorial starting")
        state.phase = .performing
        
        for ball in state.spiralBalls {
            guard let model = ball as? ModelEntity else { continue }
            model.components.set(CollisionComponent(shapes: [.generateSphere(radius: 0.04)]))
            model.components.set(InputTargetComponent())
            model.components.set(HoverEffectComponent())
        }
        
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            highlightNextNote()
        }
    }
    
    func releaseBall(_ ball: Entity, toSpiralIndex i: Int, total: Int, content: RealityViewContent) {
        let currentWorldPos = ball.position(relativeTo: nil)
        ball.removeFromParent()
        ball.setPosition(currentWorldPos, relativeTo: nil)
        content.add(ball)
        
        let targetPos = spiralPosition(index: i, total: total)
        let midPoint = midCurvePoint(from: currentWorldPos, to: targetPos)
        
        ball.move(
            to: Transform(scale: ball.scale, rotation: ball.orientation, translation: midPoint),
            relativeTo: nil,
            duration: 1.2,
            timingFunction: .easeOut
        )
        
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            ball.move(
                to: Transform(scale: ball.scale, rotation: ball.orientation, translation: targetPos),
                relativeTo: nil,
                duration: 1.0,
                timingFunction: .easeInOut
            )
        }
    }
    
    func spiralPosition(index: Int, total: Int) -> SIMD3<Float> {
        let t = Float(index) / Float(total - 1)
        let angle = t * spiralTurns * 2 * .pi
        let y = spiralBottomY + t * (spiralTopY - spiralBottomY)
        let x = playerCenter.x + cos(angle) * spiralRadius
        let z = playerCenter.z + sin(angle) * spiralRadius
        return [x, y, z]
    }
    
    func midCurvePoint(from start: SIMD3<Float>, to end: SIMD3<Float>) -> SIMD3<Float> {
        let mid = (start + end) * 0.5
        return [mid.x, mid.y + 0.3, mid.z]
    }
    
    func startRotation(entity: Entity) {
        Task { @MainActor in
            let startTime = Date()
            while !Task.isCancelled {
                if state.phase == .performing { break }
                let elapsed = Float(Date().timeIntervalSince(startTime))
                let angle = elapsed * (.pi * 2 / 20)
                let tilt = simd_quatf(angle: .pi / 12, axis: [0, 0, 1])
                let spin = simd_quatf(angle: angle, axis: [0, 1, 0])
                entity.orientation = tilt * spin
                try? await Task.sleep(nanoseconds: 16_000_000)
            }
        }
    }
    
    func makeBall(index: Int, total: Int) -> ModelEntity {
        let mesh = MeshResource.generateSphere(radius: 0.045)
        let color = greenGradientColor(index: index, total: total)
        
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: color.withAlphaComponent(0.5))
        material.emissiveColor = .init(color: color)
        material.emissiveIntensity = 1.5
        material.blending = .transparent(opacity: .init(floatLiteral: 0.55))
        material.roughness = .init(floatLiteral: 0.05)
        material.metallic = .init(floatLiteral: 0.1)
        material.clearcoat = .init(floatLiteral: 1.0)
        material.clearcoatRoughness = .init(floatLiteral: 0.05)
        
        let ball = ModelEntity(mesh: mesh, materials: [material])
        ball.name = "ball_\(index)"
        return ball
    }
    
    // Green gradient: light yellow-green -> deep emerald
    func greenGradientColor(index: Int, total: Int) -> UIColor {
        let t = Float(index) / Float(total - 1)
        let hue = CGFloat(0.22 + 0.13 * t)  // 0.22 (yellow-green) -> 0.35 (emerald)
        let saturation = CGFloat(0.65 + 0.25 * Double(t))
        let brightness = CGFloat(1.0 - 0.15 * Double(t))
        return UIColor(hue: hue, saturation: saturation, brightness: brightness, alpha: 1.0)
    }
    
    func clusterOffset(index: Int, total: Int) -> SIMD3<Float> {
        let goldenAngle = Float.pi * (3.0 - sqrt(5.0))
        let i = Float(index)
        let n = Float(total)
        let y = 1.0 - (i / (n - 1)) * 2.0
        let radiusAtY = sqrt(1.0 - y * y)
        let theta = goldenAngle * i
        let x = cos(theta) * radiusAtY
        let z = sin(theta) * radiusAtY
        let clusterRadius: Float = 0.08
        return SIMD3<Float>(x, y, z) * clusterRadius
    }
}

enum ScenePhase {
    case intro
    case listening
    case activated
    case performing
}

@Observable
class SceneState {
    var phase: ScenePhase = .intro
    var clusterRoot: Entity?
    var content: RealityViewContent?
    var audioResources: [AudioFileResource] = []
    var spiralBalls: [Entity] = []
    
    // Tutorial mode
    var songProgress: Int = 0
    var currentExpectedNote: Int = -1
    var highlightedBalls: Set<String> = []
    
    // Phase 1
    var mbira: Entity?
    var mbiraOriginalRotation: simd_quatf = simd_quatf()
    var mbiraPinchCount: Int = 0
    var mbiraIsRotating: Bool = false
    var mbiraHintPanel: Entity?
    var backgroundMusic: AudioFileResource?
    var audioController: AudioPlaybackController?
    var bubble: Entity?
}

#Preview(immersionStyle: .mixed) {
    ImmersiveView()
}
