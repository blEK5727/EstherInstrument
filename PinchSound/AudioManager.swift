//
//  AudioManager.swift
//  IDSN First Try
//

import AVFoundation

class AudioManager: ObservableObject {
    private let engine  = AVAudioEngine()
    private var players: [Int: AVAudioPlayerNode]  = [:]
    private var buffers: [Int: AVAudioPCMBuffer]   = [:]

    init() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
            print("✅ AVAudioSession configured")
        } catch {
            print("❌ AVAudioSession setup failed: \(error)")
        }
        // Do NOT start the engine here — it needs nodes attached first
    }

    // MARK: - Preloading

    /// Call once (e.g. from .task) to load all audio files into memory.
    func preloadAll(notes: [NoteData]) {
        for note in notes {
            guard buffers[note.id] == nil else { continue }
            loadAudio(id: note.id, filename: note.audioFile)
        }
    }

    /// Searches the app bundle for `filename` with common audio extensions.
    private func loadAudio(id: Int, filename: String) {
        let extensions = ["mp3", "wav", "aiff", "m4a", "caf"]
        var fileURL: URL?
        for ext in extensions {
            if let url = Bundle.main.url(forResource: filename, withExtension: ext) {
                fileURL = url
                break
            }
        }
        guard let url = fileURL else {
            print("⚠️ Audio file '\(filename)' not found in bundle — note \(id) will be silent")
            return
        }
        do {
            let file  = try AVAudioFile(forReading: url)
            let count = AVAudioFrameCount(file.length)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                                frameCapacity: count) else { return }
            try file.read(into: buffer)
            buffers[id] = buffer
            print("✅ Loaded '\(filename)' for note \(id)")
        } catch {
            print("❌ Failed to load '\(filename)': \(error)")
        }
    }

    // MARK: - Playback

    func startNote(id: Int) {
        guard players[id] == nil else { return }
        guard let buffer = buffers[id] else {
            print("⚠️ No audio buffer for note \(id)")
            return
        }

        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: buffer.format)

        if !engine.isRunning {
            do {
                try engine.start()
                print("✅ engine started")
            } catch {
                print("❌ engine start failed: \(error)")
                engine.detach(player)
                return
            }
        }

        player.scheduleBuffer(buffer, at: nil, options: .loops)
        player.play()
        players[id] = player
        print("✅ note \(id) playing")
    }

    func stopNote(id: Int) {
        guard let player = players.removeValue(forKey: id) else { return }
        player.stop()
        engine.detach(player)
        print("⏹ note \(id) stopped")
    }
}
