import Foundation
import AVFoundation
import Speech

// MARK: - 语音服务
class VoiceService: NSObject {
    static let shared = VoiceService()
    
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var synthesizer: AVSpeechSynthesizer?
    
    private override init() {
        super.init()
        synthesizer = AVSpeechSynthesizer()
    }
    
    // MARK: - 语音识别权限
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                completion(status == .authorized)
            }
        }
    }
    
    // MARK: - 开始语音识别
    func startRecording(completion: @escaping (String?, Error?) -> Void) {
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh_CN")) else {
            completion(nil, NSError(domain: "VoiceService", code: -1, userInfo: [NSLocalizedDescriptionKey: "语音识别不可用"]))
            return
        }
        speechRecognizer = recognizer
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else {
            completion(nil, NSError(domain: "VoiceService", code: -2, userInfo: [NSLocalizedDescriptionKey: "无法创建识别请求"]))
            return
        }
        request.shouldReportPartialResults = true
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }
        
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            completion(nil, error)
            return
        }
        
        recognitionTask = recognizer.recognitionTask(with: request) { result, error in
            if let result = result {
                completion(result.bestTranscription.formattedString, nil)
            }
            if let error = error {
                completion(nil, error)
                self.stopRecording()
            }
        }
    }
    
    // MARK: - 停止语音识别
    func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
    }
    
    var isRecording: Bool {
        return audioEngine.isRunning
    }
    
    // MARK: - 文字转语音
    func speak(_ text: String, language: String = "zh-CN") {
        guard !text.isEmpty else { return }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        synthesizer?.speak(utterance)
    }
    
    func stopSpeaking() {
        synthesizer?.stopSpeaking(at: .immediate)
    }
    
    var isSpeaking: Bool {
        return synthesizer?.isSpeaking ?? false
    }
}
