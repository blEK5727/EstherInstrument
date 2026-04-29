//
//  ImmersiveView.swift
//  IDSN First Try
//

import SwiftUI
import RealityKit

struct NoteData {
    let id: Int
    let audioFile: String
    let themeName: String
    let themeDescription: String
    let color: UIColor
    let position: SIMD3<Float>
    let radius: Float
    let boxiness: Float
    let xScale: Float
    let yScale: Float
    let zScale: Float
    let bumpiness: Float
}

// MARK: - Head-anchored notification

private struct ActiveThemeNotification: View {
    let activeNotes: Set<Int>
    let notes: [NoteData]

    private var activeThemes: [NoteData] {
        notes.filter { activeNotes.contains($0.id) }
    }

    var body: some View {
        VStack(alignment: .center, spacing: 10) {
            Text("Now Playing")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
                .textCase(.uppercase)
                .kerning(0.8)

            ForEach(activeThemes, id: \.id) { note in
                VStack(spacing: 4) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color(uiColor: note.color))
                            .frame(width: 8, height: 8)
                        Text(note.themeName)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    Text(note.themeDescription)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(minWidth: 200)
        .padding(.horizontal, 32)
        .padding(.vertical, 24)
        .glassBackgroundEffect()
        .opacity(activeNotes.isEmpty ? 0 : 1)
        .animation(.spring(duration: 0.35), value: activeNotes)
    }
}

struct AmbientImmersiveView: View {

    private let notes: [NoteData] = [
        NoteData(id: 0, audioFile: "fire",
                 themeName: "Fire",         themeDescription: "Crackling warmth",
                 color: UIColor(red: 128/255, green: 117/255, blue: 124/255, alpha: 1),
                 position: [ 0.40,  1.40, -1.80], radius: 0.098,
                 boxiness: 0.25, xScale: 0.90, yScale: 1.10, zScale: 0.90, bumpiness: 0.18),

        NoteData(id: 1, audioFile: "bird",
                 themeName: "Birds",        themeDescription: "Morning chorus",
                 color: UIColor(red: 205/255, green: 213/255, blue: 222/255, alpha: 1),
                 position: [ 1.80,  1.50, -0.50], radius: 0.15,
                 boxiness: 0.05, xScale: 0.65, yScale: 1.55, zScale: 0.65, bumpiness: 0.12),

        NoteData(id: 2, audioFile: "park",
                 themeName: "City Park",    themeDescription: "Urban ambience",
                 color: UIColor(red: 209/255, green: 198/255, blue: 188/255, alpha: 1),
                 position: [ 1.80,  1.25,  1.40], radius: 0.195,
                 boxiness: 0.15, xScale: 1.25, yScale: 0.55, zScale: 1.10, bumpiness: 0.20),

        NoteData(id: 3, audioFile: "forest",
                 themeName: "Forest",       themeDescription: "Deep woodland",
                 color: UIColor(red: 185/255, green: 189/255, blue: 210/255, alpha: 1),
                 position: [ 0.20,  1.35,  2.50], radius: 0.225,
                 boxiness: 0.00, xScale: 1.00, yScale: 1.00, zScale: 1.00, bumpiness: 0.32),

        NoteData(id: 4, audioFile: "rain",
                 themeName: "Rain",         themeDescription: "Soft rainfall",
                 color: UIColor(red: 196/255, green: 191/255, blue: 207/255, alpha: 1),
                 position: [-1.60,  1.60,  1.80], radius: 0.21,
                 boxiness: 0.55, xScale: 0.75, yScale: 1.45, zScale: 0.75, bumpiness: 0.10),

        NoteData(id: 5, audioFile: "wave",
                 themeName: "Ocean Waves",  themeDescription: "Coastal rhythm",
                 color: UIColor(red: 210/255, green: 190/255, blue: 202/255, alpha: 1),
                 position: [-2.00,  1.45,  0.30], radius: 0.135,
                 boxiness: 0.20, xScale: 1.50, yScale: 0.50, zScale: 0.90, bumpiness: 0.15),

        NoteData(id: 6, audioFile: "woodwind",
                 themeName: "Woodwind",     themeDescription: "Breathy tones",
                 color: UIColor(red: 245/255, green: 245/255, blue: 239/255, alpha: 1),
                 position: [-1.50,  1.30, -1.50], radius: 0.165,
                 boxiness: 0.65, xScale: 0.55, yScale: 1.65, zScale: 0.55, bumpiness: 0.08),

        NoteData(id: 7, audioFile: "dream",
                 themeName: "Dream",        themeDescription: "Ethereal drift",
                 color: UIColor(red: 205/255, green: 213/255, blue: 222/255, alpha: 1),
                 position: [-0.10,  1.50, -2.20], radius: 0.082,
                 boxiness: 0.00, xScale: 1.10, yScale: 0.85, zScale: 1.10, bumpiness: 0.08),
    ]

    @StateObject private var audio = AudioManager()
    @State private var activeNotes: Set<Int> = []

    var body: some View {
        RealityView { content, attachments in
            for note in notes {
                let mesh = makeOrganicMesh(note: note)
                    ?? MeshResource.generateSphere(radius: note.radius)

                var mat = PhysicallyBasedMaterial()
                mat.baseColor          = .init(tint: note.color.withAlphaComponent(0.5))
                mat.metallic           = .init(floatLiteral: 0.55)
                mat.roughness          = .init(floatLiteral: 0.25)
                mat.clearcoat          = .init(floatLiteral: 1.0)
                mat.clearcoatRoughness = .init(floatLiteral: 0.1)
                mat.blending           = .transparent(opacity: .init(floatLiteral: 0.5))

                let entity = ModelEntity(mesh: mesh, materials: [mat])
                entity.name = "Note_\(note.id)"
                entity.position = note.position
                entity.components.set(CollisionComponent(shapes: [.generateSphere(radius: note.radius)]))
                entity.components.set(InputTargetComponent())
                entity.components.set(makeParticleEmitter(for: note))
                content.add(entity)
            }

            if let notification = attachments.entity(for: "notification") {
                let headAnchor = AnchorEntity(.head)
                notification.position = SIMD3(0.0, -0.20, -0.55)
                headAnchor.addChild(notification)
                content.add(headAnchor)
            }
        } attachments: {
            Attachment(id: "notification") {
                ActiveThemeNotification(activeNotes: activeNotes, notes: notes)
            }
        }
        .task {
            audio.preloadAll(notes: notes)
        }
        .gesture(
            SpatialTapGesture()
                .targetedToAnyEntity()
                .onEnded { value in
                    let entity = value.entity
                    guard let id = noteID(for: entity) else { return }
                    if activeNotes.contains(id) {
                        activeNotes.remove(id)
                        audio.stopNote(id: id)
                        setVisual(entity: entity, id: id, active: false)
                    } else {
                        activeNotes.insert(id)
                        audio.startNote(id: id)
                        setVisual(entity: entity, id: id, active: true)
                    }
                }
        )
    }

    // MARK: - Particle effects

    /// Each sound theme gets a distinct particle effect.
    /// Effects are off by default and toggled via isEmitting when tapped.
    private func makeParticleEmitter(for note: NoteData) -> ParticleEmitterComponent {
        var e = ParticleEmitterComponent()
        e.isEmitting = false
        switch note.id {

        case 0: // Fire — rising ash/embers
            e.emitterShape               = .sphere
            e.emitterShapeSize           = SIMD3(repeating: note.radius * 0.8)
            e.mainEmitter.birthRate      = 90
            e.mainEmitter.lifeSpan       = 1.8

            e.mainEmitter.size           = 0.004
            e.mainEmitter.sizeVariation  = 0.002
            e.mainEmitter.spreadingAngle = 0.5
            e.mainEmitter.acceleration   = SIMD3(0, 0.12, 0)

        case 1: // Birds — tiny sparkles drifting in all directions
            e.emitterShape               = .sphere
            e.emitterShapeSize           = SIMD3(repeating: note.radius)
            e.mainEmitter.birthRate      = 35
            e.mainEmitter.lifeSpan       = 4.5

            e.mainEmitter.size           = 0.005
            e.mainEmitter.sizeVariation  = 0.003
            e.mainEmitter.spreadingAngle = .pi
            e.mainEmitter.acceleration   = SIMD3(0, 0.01, 0)

        case 2: // City Park — slow drifting pollen/dust
            e.emitterShape               = .sphere
            e.emitterShapeSize           = SIMD3(repeating: note.radius * 1.2)
            e.mainEmitter.birthRate      = 25
            e.mainEmitter.lifeSpan       = 6.0

            e.mainEmitter.size           = 0.004
            e.mainEmitter.sizeVariation  = 0.002
            e.mainEmitter.spreadingAngle = .pi

        case 3: // Forest — volumetric mist/fog
            e.emitterShape               = .sphere
            e.emitterShapeSize           = SIMD3(repeating: note.radius * 1.5)
            e.mainEmitter.birthRate      = 55
            e.mainEmitter.lifeSpan       = 4.0

            e.mainEmitter.size           = 0.018
            e.mainEmitter.sizeVariation  = 0.008
            e.mainEmitter.spreadingAngle = .pi

        case 4: // Rain — droplets falling downward
            e.emitterShape               = .sphere
            e.emitterShapeSize           = SIMD3(repeating: note.radius * 1.2)
            e.mainEmitter.birthRate      = 120
            e.mainEmitter.lifeSpan       = 1.2

            e.mainEmitter.size           = 0.003
            e.mainEmitter.sizeVariation  = 0.001
            e.mainEmitter.spreadingAngle = 0.3
            e.mainEmitter.acceleration   = SIMD3(0, -0.4, 0)

        case 5: // Ocean Waves — ring pulses expanding outward
            e.emitterShape               = .torus
            e.emitterShapeSize           = SIMD3(note.radius, note.radius * 0.1, note.radius)
            e.mainEmitter.birthRate      = 80
            e.mainEmitter.lifeSpan       = 2.5

            e.mainEmitter.size           = 0.005
            e.mainEmitter.sizeVariation  = 0.002
            e.mainEmitter.spreadingAngle = 0.25

        case 6: // Woodwind — circular breath waves
            e.emitterShape               = .torus
            e.emitterShapeSize           = SIMD3(note.radius * 0.6, note.radius * 0.08, note.radius * 0.6)
            e.mainEmitter.birthRate      = 50
            e.mainEmitter.lifeSpan       = 3.0

            e.mainEmitter.size           = 0.004
            e.mainEmitter.sizeVariation  = 0.002
            e.mainEmitter.spreadingAngle = 0.15

        case 7: // Dream — ultra-slow ethereal float
            e.emitterShape               = .sphere
            e.emitterShapeSize           = SIMD3(repeating: note.radius * 2.0)
            e.mainEmitter.birthRate      = 18
            e.mainEmitter.lifeSpan       = 8.0

            e.mainEmitter.size           = 0.007
            e.mainEmitter.sizeVariation  = 0.004
            e.mainEmitter.spreadingAngle = .pi
            e.mainEmitter.acceleration   = SIMD3(0, 0.003, 0)

        default:
            e.emitterShape               = .sphere
            e.emitterShapeSize           = SIMD3(repeating: 0.05)
            e.mainEmitter.birthRate      = 30
            e.mainEmitter.lifeSpan       = 3.0

            e.mainEmitter.size           = 0.005
            e.mainEmitter.spreadingAngle = .pi
        }

        return e
    }

    // MARK: - Organic mesh

    private func makeOrganicMesh(note: NoteData) -> MeshResource? {
        let latDivs = 32
        let lonDivs = 32
        let s = Float(note.id) * 1.618

        var positions: [SIMD3<Float>] = []
        var normals:   [SIMD3<Float>] = []
        var texCoords: [SIMD2<Float>] = []
        var indices:   [UInt32]       = []

        for lat in 0...latDivs {
            let theta    = Float(lat) * .pi / Float(latDivs)
            let sinTheta = sin(theta)
            let cosTheta = cos(theta)

            for lon in 0...lonDivs {
                let phi = Float(lon) * 2 * .pi / Float(lonDivs)
                let x = sinTheta * cos(phi)
                let y = cosTheta
                let z = sinTheta * sin(phi)

                let maxComp = max(abs(x), max(abs(y), abs(z)))
                let bx = x + (x / maxComp - x) * note.boxiness
                let by = y + (y / maxComp - y) * note.boxiness
                let bz = z + (z / maxComp - z) * note.boxiness

                let d1 = sin(bx * 3.1 + s * 1.7) * cos(by * 4.3 + s * 0.9)
                let d2 = sin(bz * 5.7 + s * 2.3) * cos(bx * 2.9 + s * 1.1)
                let d3 = cos(by * 6.1 + s * 0.5) * sin(bz * 3.7 + s * 1.9)
                let displacement = (d1 + d2 + d3) / 3.0 * note.bumpiness

                let r = note.radius * (1.0 + displacement)
                positions.append(SIMD3(bx * r * note.xScale,
                                       by * r * note.yScale,
                                       bz * r * note.zScale))
                normals.append(normalize(SIMD3(bx * note.xScale,
                                               by * note.yScale,
                                               bz * note.zScale)))
                texCoords.append(SIMD2(Float(lon) / Float(lonDivs),
                                       Float(lat) / Float(latDivs)))
            }
        }

        for lat in 0..<latDivs {
            for lon in 0..<lonDivs {
                let curr = UInt32(lat * (lonDivs + 1) + lon)
                let next = curr + UInt32(lonDivs + 1)
                indices.append(contentsOf: [curr, next, curr + 1,
                                            curr + 1, next, next + 1])
            }
        }

        var desc = MeshDescriptor()
        desc.positions          = MeshBuffer(positions)
        desc.normals            = MeshBuffer(normals)
        desc.textureCoordinates = MeshBuffer(texCoords)
        desc.primitives         = .triangles(indices)

        return try? MeshResource.generate(from: [desc])
    }

    // MARK: - Helpers
    
    private func noteID(for entity: Entity) -> Int? {
        let name  = entity.name
        let idStr = name.hasPrefix("Note_") ? String(name.dropFirst(5)) : name
        guard let id = Int(idStr), notes.indices.contains(id) else { return nil }
        return id
    }

    private func setVisual(entity: Entity, id: Int, active: Bool) {
        guard let model = entity as? ModelEntity else { return }

        // Toggle particle effect
        entity.components[ParticleEmitterComponent.self]?.isEmitting = active

        if active {
            model.transform.scale = SIMD3(repeating: 1.15)
            var pbr = PhysicallyBasedMaterial()
            pbr.baseColor          = .init(tint: notes[id].color.withAlphaComponent(1.0))
            pbr.emissiveColor      = .init(color: notes[id].color)
            pbr.emissiveIntensity  = 2.0
            pbr.metallic           = .init(floatLiteral: 0.6)
            pbr.roughness          = .init(floatLiteral: 0.15)
            pbr.clearcoat          = .init(floatLiteral: 1.0)
            pbr.clearcoatRoughness = .init(floatLiteral: 0.05)
            pbr.blending           = .transparent(opacity: .init(floatLiteral: 1.0))
            model.model?.materials = [pbr]
        } else {
            model.transform.scale = SIMD3(repeating: 1.0)
            var mat = PhysicallyBasedMaterial()
            mat.baseColor          = .init(tint: notes[id].color.withAlphaComponent(0.5))
            mat.metallic           = .init(floatLiteral: 0.55)
            mat.roughness          = .init(floatLiteral: 0.25)
            mat.clearcoat          = .init(floatLiteral: 1.0)
            mat.clearcoatRoughness = .init(floatLiteral: 0.1)
            mat.blending           = .transparent(opacity: .init(floatLiteral: 0.5))
            model.model?.materials = [mat]
        }
    }
}

#Preview(immersionStyle: .mixed) {
    AmbientImmersiveView()
        .environment(AppModel())
}
