import AVFoundation
import Foundation

@MainActor
final class AudioRecorder: NSObject, ObservableObject {
    enum RecorderError: LocalizedError {
        case permissionDenied
        case sessionFailed(Error)
        case engineFailed(Error)
        case converterUnavailable

        var errorDescription: String? {
            switch self {
            case .permissionDenied: return "Microphone permission denied"
            case .sessionFailed(let e): return "Audio session error: \(e.localizedDescription)"
            case .engineFailed(let e): return "Engine error: \(e.localizedDescription)"
            case .converterUnavailable: return "Could not build PCM converter"
            }
        }
    }

    @Published private(set) var isRecording = false
    @Published private(set) var level: Float = 0
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var lastError: String?

    private let targetSampleRate: Double = 16_000
    private var engine: AVAudioEngine?
    private let buffer = SamplesBuffer()
    private var startedAt: Date?
    private var tickTimer: Timer?

    func requestPermission() async -> Bool {
        if #available(iOS 17.0, *) {
            return await AVAudioApplication.requestRecordPermission()
        }
        return await withCheckedContinuation { cont in
            AVAudioSession.sharedInstance().requestRecordPermission { cont.resume(returning: $0) }
        }
    }

    func start() async throws {
        guard !isRecording else { return }
        guard await requestPermission() else { throw RecorderError.permissionDenied }

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true, options: [])
        } catch {
            throw RecorderError.sessionFailed(error)
        }

        let engine = AVAudioEngine()
        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: targetSampleRate,
            channels: 1,
            interleaved: true
        ), let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw RecorderError.converterUnavailable
        }

        buffer.removeAll()

        let sampleBuffer = self.buffer
        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] pcm, _ in
            self?.process(pcm: pcm, converter: converter, target: targetFormat, input: inputFormat, sink: sampleBuffer)
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            throw RecorderError.engineFailed(error)
        }
        self.engine = engine
        isRecording = true
        lastError = nil
        startedAt = Date()
        elapsed = 0
        tickTimer?.invalidate()
        tickTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let start = self.startedAt else { return }
                self.elapsed = Date().timeIntervalSince(start)
            }
        }
    }

    func stop() -> URL? {
        guard isRecording else { return nil }
        tickTimer?.invalidate()
        tickTimer = nil
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
        isRecording = false
        level = 0
        elapsed = 0
        startedAt = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])

        let captured = buffer.takeAll()
        guard captured.count >= 1600 else { return nil }  // <100ms is noise; drop it

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("utterance-\(UUID().uuidString).wav")
        do {
            let wav = makeWAV(samples: captured, sampleRate: Int(targetSampleRate))
            try wav.write(to: url)
            return url
        } catch {
            lastError = "Write failed: \(error.localizedDescription)"
            return nil
        }
    }

    private nonisolated func process(
        pcm: AVAudioPCMBuffer,
        converter: AVAudioConverter,
        target: AVAudioFormat,
        input: AVAudioFormat,
        sink: SamplesBuffer
    ) {
        let ratio = target.sampleRate / input.sampleRate
        let outCapacity = AVAudioFrameCount(Double(pcm.frameLength) * ratio) + 1024
        guard let out = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: outCapacity) else { return }

        var error: NSError?
        var delivered = false
        let status = converter.convert(to: out, error: &error) { _, outStatus in
            if delivered {
                outStatus.pointee = .noDataNow
                return nil
            }
            delivered = true
            outStatus.pointee = .haveData
            return pcm
        }
        guard status != .error, let int16Ptr = out.int16ChannelData?[0] else { return }

        let frameLength = Int(out.frameLength)
        let chunk = Array(UnsafeBufferPointer(start: int16Ptr, count: frameLength))
        sink.append(chunk)

        var sumSquares: Float = 0
        for i in 0..<frameLength {
            let s = Float(int16Ptr[i]) / 32768.0
            sumSquares += s * s
        }
        let rms = sqrtf(sumSquares / Float(max(frameLength, 1)))
        let db = 20 * log10f(max(rms, 0.000_01))
        let normalized = max(0, min(1, (db + 60) / 60))
        Task { @MainActor [weak self] in
            self?.level = normalized
        }
    }

}

func makeWAV(samples: [Int16], sampleRate: Int) -> Data {
    let numChannels: UInt16 = 1
    let bitsPerSample: UInt16 = 16
    let byteRate = UInt32(sampleRate) * UInt32(numChannels) * UInt32(bitsPerSample) / 8
    let blockAlign = numChannels * bitsPerSample / 8
    let dataSize = UInt32(samples.count) * UInt32(bitsPerSample) / 8
    let fileSize = UInt32(36) + dataSize

    var data = Data(capacity: Int(fileSize) + 8)
    data.append("RIFF".data(using: .ascii)!)
    data.append(le: fileSize)
    data.append("WAVE".data(using: .ascii)!)
    data.append("fmt ".data(using: .ascii)!)
    data.append(le: UInt32(16))
    data.append(le: UInt16(1))
    data.append(le: numChannels)
    data.append(le: UInt32(sampleRate))
    data.append(le: byteRate)
    data.append(le: blockAlign)
    data.append(le: bitsPerSample)
    data.append("data".data(using: .ascii)!)
    data.append(le: dataSize)
    samples.withUnsafeBufferPointer { buf in
        buf.baseAddress?.withMemoryRebound(to: UInt8.self, capacity: buf.count * MemoryLayout<Int16>.size) { byteBase in
            data.append(byteBase, count: buf.count * MemoryLayout<Int16>.size)
        }
    }
    return data
}

private extension Data {
    mutating func append<T: FixedWidthInteger>(le value: T) {
        var v = value.littleEndian
        Swift.withUnsafeBytes(of: &v) { raw in
            self.append(raw.bindMemory(to: UInt8.self).baseAddress!, count: raw.count)
        }
    }
}

final class SamplesBuffer: @unchecked Sendable {
    private var samples: [Int16] = []
    private let lock = NSLock()

    func append(_ chunk: [Int16]) {
        lock.lock(); samples.append(contentsOf: chunk); lock.unlock()
    }

    func takeAll() -> [Int16] {
        lock.lock()
        let out = samples
        samples.removeAll(keepingCapacity: false)
        lock.unlock()
        return out
    }

    func removeAll() {
        lock.lock(); samples.removeAll(keepingCapacity: true); lock.unlock()
    }
}
