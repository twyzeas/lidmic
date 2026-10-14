import Foundation
import CoreAudio
import IOKit
import IOKit.pwr_mgt

// All callbacks, retries and device changes run on the main queue.
final class InputWatcher {
    private let measure: Bool
    private let evaluate: (Bool) -> (String, Bool)
    private var port: IONotificationPortRef?
    private var root: io_service_t = 0
    private var notification: io_object_t = 0
    private var listeners: [(AudioObjectID, AudioObjectPropertyAddress, AudioObjectPropertyListenerBlock)] = []
    private var timer: DispatchSourceTimer?
    private var pollTimer: DispatchSourceTimer?
    private var generation = 0
    private var audioPending = false
    private var lastLid: Bool?
    private var pollLid: Bool?
    private var eventTime: TimeInterval?
    private let start = ProcessInfo.processInfo.systemUptime

    init(measure: Bool = false, evaluate: @escaping (Bool) -> (String, Bool) = { apply(dryRun: $0) }) {
        self.measure = measure
        self.evaluate = evaluate
    }
    private func log(_ text: String) {
        guard measure else { return }
        print(String(format: "%.3f %@", ProcessInfo.processInfo.systemUptime - start, text))
        fflush(stdout)
    }
    private func listen(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector, scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) {
        var a = address(selector, scope)
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            guard let self, !self.audioPending else { return }
            self.audioPending = true
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.audioPending = false
                self.receive("audio")
            }
        }
        let result = AudioObjectAddPropertyListenerBlock(id, &a, DispatchQueue.main, block)
        if result == noErr { listeners.append((id, a, block)) }
        else { log("listener unavailable: \(result); fallback remains active") }
    }
    private func refreshListeners() {
        let system = AudioObjectID(kAudioObjectSystemObject)
        let devices = Set(audioDeviceIDs())
        // Keep existing subscriptions: re-registering on every notification can
        // itself provoke more notifications on some audio drivers.
        listeners.removeAll { entry in
            let (id, original, block) = entry
            guard id != system && !devices.contains(id) else { return false }
            var a = original
            AudioObjectRemovePropertyListenerBlock(id, &a, DispatchQueue.main, block)
            return true
        }
        func missing(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector) -> Bool {
            !listeners.contains { $0.0 == id && $0.1.mSelector == selector }
        }
        for selector in [kAudioHardwarePropertyDevices, kAudioHardwarePropertyDefaultInputDevice] where missing(system, selector) {
            listen(system, selector)
        }
        for id in devices {
            if missing(id, kAudioDevicePropertyDeviceIsAlive) { listen(id, kAudioDevicePropertyDeviceIsAlive) }
            if missing(id, kAudioDevicePropertyStreams) { listen(id, kAudioDevicePropertyStreams, scope: kAudioObjectPropertyScopeInput) }
        }
    }
    func receive(_ reason: String) {
        let began = ProcessInfo.processInfo.systemUptime
        let lid = closed()
        if lid != lastLid {
            lastLid = lid
            eventTime = began
            log("lid event: \(lid.map { $0 ? "closed" : "open" } ?? "unknown") [\(reason)]")
        }
        // Device IDs can appear before their input streams are ready.
        if reason == "audio" || reason == "fallback" { refreshListeners() }
        generation += 1
        let ticket = generation
        let result = evaluate(measure)
        log(String(format: "%@ evaluation %.2f ms: %@", reason, (ProcessInfo.processInfo.systemUptime - began) * 1000, result.0))
        guard !result.1 && reason != "fallback" else { return }
        for delay in [0.25, 0.75, 1.5] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, self.generation == ticket else { return }
                let result = self.evaluate(self.measure)
                self.log("retry: \(result.0)")
                if result.1 { self.generation += 1 }
            }
        }
    }
    func startWatching() {
        lastLid = closed(); pollLid = lastLid
        root = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        port = IONotificationPortCreate(kIOMainPortDefault)
        if let port, root != 0 {
            IONotificationPortSetDispatchQueue(port, DispatchQueue.main)
            let result = IOServiceAddInterestNotification(port, root, kIOGeneralInterest, { context, _, message, _ in
                // IOPM.h kIOPMMessageClamshellStateChange is a C macro unavailable in Swift.
                guard message == ((0x38 << 26) | (13 << 14) | 0x100), let context else { return }
                Unmanaged<InputWatcher>.fromOpaque(context).takeUnretainedValue().receive("lid")
            }, Unmanaged.passUnretained(self).toOpaque(), &notification)
            log("lid listener registration: \(result)")
        } else { log("lid listener unavailable; fallback remains active") }
        refreshListeners()
        receive("startup")
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 10, repeating: 10, leeway: .milliseconds(500))
        timer.setEventHandler { [weak self] in self?.receive("fallback") }
        timer.resume(); self.timer = timer
        if measure {
            let poll = DispatchSource.makeTimerSource(queue: .main)
            poll.schedule(deadline: .now() + 2, repeating: 2)
            poll.setEventHandler { [weak self] in
                guard let self else { return }
                let lid = closed()
                if lid != self.pollLid {
                    self.pollLid = lid
                    if lid == self.lastLid, let event = self.eventTime {
                        self.log(String(format: "old poll detected lid; event lead %.1f ms", (ProcessInfo.processInfo.systemUptime - event) * 1000))
                    } else { self.log("old poll detected lid before event; notification missed") }
                }
            }
            poll.resume(); pollTimer = poll
            log("READY: read-only measurement; no microphone recording or switching")
        }
    }
    deinit {
        timer?.cancel(); pollTimer?.cancel()
        for (id, var a, block) in listeners { AudioObjectRemovePropertyListenerBlock(id, &a, DispatchQueue.main, block) }
        if notification != 0 { IOObjectRelease(notification) }
        if let port { IONotificationPortDestroy(port) }
        if root != 0 { IOObjectRelease(root) }
    }
}
