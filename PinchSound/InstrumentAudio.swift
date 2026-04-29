//
//  InstrumentAudio.swift
//  yay
//
//  Loads one AVAudioPlayer per note (C major pentatonic, 2 octaves) and
//  plays them on demand. Missing files no-op so visuals work even before
//  audio assets are dropped in.
//

import AVFoundation

@MainActor
@Observable
final class InstrumentAudio {
    // Guzheng samples we have on disk, sorted low → high.
    // (A3 is absent from the set, A5 sits an octave above A4 as a high accent.)
    static let noteNames = ["C3", "D3", "E3", "G3",
                            "C4", "D4", "E4", "G4", "A4",
                            "A5"]

    private var players: [AVAudioPlayer?] = []

    init() {
        configureSession()
        players = Self.noteNames.map(Self.loadPlayer(named:))
    }

    func play(noteIndex i: Int) {
        guard players.indices.contains(i), let player = players[i] else { return }
        player.stop()
        player.currentTime = 0
        player.play()
    }

    // MARK: - Setup helpers

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("[InstrumentAudio] AVAudioSession setup failed: \(error)")
        }
    }

    private static func loadPlayer(named name: String) -> AVAudioPlayer? {
        let extensions = ["wav", "m4a", "mp3", "aiff", "caf"]
        for ext in extensions {
            if let url = Bundle.main.url(forResource: name, withExtension: ext) {
                do {
                    let player = try AVAudioPlayer(contentsOf: url)
                    player.prepareToPlay()
                    return player
                } catch {
                    print("[InstrumentAudio] Failed to load \(name).\(ext): \(error)")
                }
            }
        }
        print("[InstrumentAudio] No audio file found for note \(name) — sphere will be silent")
        return nil
    }
}
