import Foundation
import CoreAudio
import IOKit

func address(_ selector: AudioObjectPropertySelector, _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
}
func stringProperty(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector) -> String? {
    var a = address(selector)
    var value: Unmanaged<CFString>?
    var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
    guard AudioObjectGetPropertyData(id, &a, 0, nil, &size, &value) == noErr else { return nil }
    return value?.takeUnretainedValue() as String?
}
struct InputDevice {
    let id: AudioObjectID
    let name: String
    let uid: String
    let transport: UInt32
    var wireless: Bool {
        transport == kAudioDeviceTransportTypeBluetooth || transport == kAudioDeviceTransportTypeBluetoothLE
    }
}
func uintProperty(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector) -> UInt32? {
    var a = address(selector)
    var value: UInt32 = 0
    var size = UInt32(MemoryLayout<UInt32>.size)
    guard AudioObjectGetPropertyData(id, &a, 0, nil, &size, &value) == noErr else { return nil }
    return value
}
struct Preferences: Codable {
    var internalUID: String?
    var continuityUID: String?
}
func role(_ device: InputDevice, closed: Bool) -> Bool {
    // FourCC transport IDs are stable CoreAudio properties, independent of names/locales.
    closed ? [UInt32(0x63637764), UInt32(0x6363776c), UInt32(0x63636170)].contains(device.transport)
           : device.transport == kAudioDeviceTransportTypeBuiltIn
}
func selectInput(_ devices: [InputDevice], lidClosed: Bool?, currentID: AudioObjectID?, preferences: Preferences = Preferences()) -> InputDevice? {
    let wireless = devices.filter { $0.wireless }.sorted { $0.uid < $1.uid }
    if let headset = wireless.first(where: { $0.id == currentID }) ?? wireless.first { return headset }
    guard let lidClosed else { return nil }
    let candidates = devices.filter { role($0, closed: lidClosed) }
    let chosen = lidClosed ? preferences.continuityUID : preferences.internalUID
    if let chosen { return candidates.first { $0.uid == chosen } }
    return candidates.count == 1 ? candidates.first : nil
}
func audioDeviceIDs() -> [AudioObjectID] {
    var a = address(kAudioHardwarePropertyDevices)
    var size: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &a, 0, nil, &size) == noErr, size > 0 else { return [] }
    var devices = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
    let result = devices.withUnsafeMutableBytes { AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &a, 0, nil, &size, $0.baseAddress!) }
    guard result == noErr else { return [] }
    return Array(devices.prefix(Int(size) / MemoryLayout<AudioObjectID>.size))
}
func inputs() -> [InputDevice] {
    audioDeviceIDs().compactMap { id in
        var streams = address(kAudioDevicePropertyStreams, kAudioObjectPropertyScopeInput)
        var bytes: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &streams, 0, nil, &bytes) == noErr, bytes > 0,
              let name = stringProperty(id, kAudioObjectPropertyName) else { return nil }
        guard uintProperty(id, kAudioDevicePropertyDeviceIsAlive) == 1 else { return nil }
        return InputDevice(id: id, name: name, uid: stringProperty(id, kAudioDevicePropertyDeviceUID) ?? String(id), transport: uintProperty(id, kAudioDevicePropertyTransportType) ?? 0)
    }
}
func closed() -> Bool? {
    let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
    guard service != 0 else { return nil }
    defer { IOObjectRelease(service) }
    return IORegistryEntryCreateCFProperty(service, "AppleClamshellState" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Bool
}
func current() -> AudioObjectID? {
    var a = address(kAudioHardwarePropertyDefaultInputDevice)
    var id: AudioObjectID = 0
    var size = UInt32(MemoryLayout<AudioObjectID>.size)
    return AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &a, 0, nil, &size, &id) == noErr ? id : nil
}
func apply(dryRun: Bool = false) -> (String, Bool) {
    let lidClosed = closed()
    let devices = inputs()
    let currentID = current()
    guard let target = selectInput(devices, lidClosed: lidClosed, currentID: currentID, preferences: readPreferences()) else {
        let reason = lidClosed.map { $0 ? "Waiting for a unique Continuity microphone (run Enable if ambiguous)" : "Waiting for a unique built-in microphone (run Enable if ambiguous)" } ?? "Cannot read lid state"
        return ("\(reason); microphone unchanged.", false)
    }
    let targetName = target.name
    if dryRun {
        let lid = lidClosed.map { $0 ? "closed" : "open" } ?? "unknown"
        return ("Lid: \(lid); target: \(targetName); current: \(devices.first(where: { $0.id == currentID })?.name ?? "unknown"); Bluetooth inputs: \(devices.filter { $0.wireless }.map { $0.name }.joined(separator: ", "))", true)
    }
    if currentID == target.id { return ("Using \(targetName).", true) }
    var a = address(kAudioHardwarePropertyDefaultInputDevice)
    var id = target.id
    let status = AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &a, 0, nil, UInt32(MemoryLayout<AudioObjectID>.size), &id)
    guard status == noErr, current() == target.id else { return ("Could not switch to \(targetName) (status \(status)).", false) }
    return ("Using \(targetName).", true)
}
