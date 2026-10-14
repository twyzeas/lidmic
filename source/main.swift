import Foundation
import Darwin

let fm = FileManager.default
#if TESTING
let home = URL(fileURLWithPath: ProcessInfo.processInfo.environment["LID_TEST_HOME"]!)
#else
let home = fm.homeDirectoryForCurrentUser
#endif
let label = "local.lid-microphone"
let base = home.appendingPathComponent("Library/Application Support/Lid Microphone")
let executable = base.appendingPathComponent("lid-microphone")
let config = base.appendingPathComponent("preferences.json")
let agent = home.appendingPathComponent("Library/LaunchAgents/\(label).plist")
let domain = "gui/\(getuid())"
func readPreferences() -> Preferences {
    (try? JSONDecoder().decode(Preferences.self, from: Data(contentsOf: config))) ?? Preferences()
}
@discardableResult func command(_ path: String, _ args: [String]) throws -> (Int32, String) {
    let p = Process(); p.executableURL = URL(fileURLWithPath: path); p.arguments = args
    let pipe = Pipe(); p.standardOutput = pipe; p.standardError = pipe
    try p.run()
    let data = pipe.fileHandleForReading.readDataToEndOfFile(); p.waitUntilExit()
    return (p.terminationStatus, String(decoding: data, as: UTF8.self))
}
@discardableResult func launch(_ args: [String]) throws -> (Int32, String) {
#if TESTING
    let marker = home.appendingPathComponent("loaded")
    if args[0] == "print" { return (fm.fileExists(atPath: marker.path) ? 0 : 113, "") }
    if args[0] == "bootout" { try? fm.removeItem(at: marker); return (0, "") }
    if args[0] == "bootstrap" { try Data().write(to: marker); return (0, "") }
    return (0, "")
#else
    return try command("/bin/launchctl", args)
#endif
}
func loaded() throws -> Bool { try launch(["print", "\(domain)/\(label)"]).0 == 0 }
func stop() throws {
    if try loaded() {
        let result = try launch(["bootout", "\(domain)/\(label)"])
        guard result.0 == 0 else { throw failure("Could not stop microphone switching. Try again.") }
    }
}
func failure(_ message: String) -> NSError { NSError(domain: label, code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
func configure() throws -> Preferences {
    var prefs = readPreferences()
    for isClosed in [false, true] {
        let devices = inputs().filter { role($0, closed: isClosed) }.sorted { $0.uid < $1.uid }
        let existing = isClosed ? prefs.continuityUID : prefs.internalUID
        if let existing, devices.contains(where: { $0.uid == existing }) { continue }
        guard devices.count > 1 else { continue }
        let names = devices.enumerated().map { "\($0.offset + 1). \($0.element.name)" }
        let prompt = isClosed ? "Choose your iPhone microphone." : "Choose your MacBook microphone."
        let script = """
        on run argv
            set selection to choose from list (items 2 thru -1 of argv) with prompt (item 1 of argv)
            if selection is false then error "Setup cancelled" number -128
            return item 1 of selection
        end run
        """
        let result = try command("/usr/bin/osascript", ["-e", script, prompt] + names)
        guard result.0 == 0, let index = names.firstIndex(of: result.1.trimmingCharacters(in: .whitespacesAndNewlines)) else { throw failure("Setup cancelled.") }
        if isClosed { prefs.continuityUID = devices[index].uid } else { prefs.internalUID = devices[index].uid }
    }
    return prefs
}
func enable() throws {
#if TESTING
    let prefs = Preferences()
#else
    let prefs = try configure()
#endif
    try fm.createDirectory(at: base, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    try fm.createDirectory(at: agent.deletingLastPathComponent(), withIntermediateDirectories: true)
    let source = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
    let payload = try Data(contentsOf: source)
    // Validate the complete replacement before stopping an existing installation.
    let staged = base.appendingPathComponent(".lid-microphone.new")
    try payload.write(to: staged, options: .atomic)
    try fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: staged.path)
    let validation = try command("/usr/bin/codesign", ["--verify", "--strict", staged.path])
    guard validation.0 == 0 else { try? fm.removeItem(at: staged); throw failure("Could not verify the download. Download the shortcut again.") }
    try stop()
    guard rename(staged.path, executable.path) == 0 else { throw failure("Could not install. Try Enable again.") }
    try JSONEncoder().encode(prefs).write(to: config, options: .atomic)
    let plist: [String: Any] = ["Label": label, "ProgramArguments": [executable.path, "--watch"], "RunAtLoad": true, "KeepAlive": true, "ThrottleInterval": 10, "ProcessType": "Background"]
    try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0).write(to: agent, options: .atomic)
    _ = try launch(["enable", "\(domain)/\(label)"])
    let result = try launch(["bootstrap", domain, agent.path])
    guard result.0 == 0, try loaded() else { throw failure("Could not start microphone switching. Try Enable again.") }
    print("Microphone switching enabled.")
}
let action = CommandLine.arguments.dropFirst().first ?? "--status"
do {
    if action == "--watch" || action == "--measure" {
        let watcher = InputWatcher(measure: action == "--measure")
        watcher.startWatching()
        withExtendedLifetime(watcher) { RunLoop.main.run() }
    } else if action == "--status" {
        print(try loaded() ? "Microphone switching enabled." : "Microphone switching disabled.")
        if let id = current(), let device = inputs().first(where: { $0.id == id }) {
            print("Microphone: \(device.name)")
        }
    } else {
        // Serialize lifecycle operations, including concurrent shortcut invocations.
        let support = base.deletingLastPathComponent()
        try fm.createDirectory(at: support, withIntermediateDirectories: true)
        let lock = support.appendingPathComponent(".lid-microphone.lock")
        let fd = open(lock.path, O_CREAT | O_RDWR | O_NOFOLLOW, 0o600)
        guard fd >= 0 else { throw failure("Could not start setup. Try again.") }
        defer { close(fd) }
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else { throw failure("Setup is already running. Try again shortly.") }
        switch action {
        case "--enable": try enable()
        case "--disable", "--uninstall":
            try stop()
            if fm.fileExists(atPath: agent.path) { try fm.removeItem(at: agent) }
            if action == "--uninstall", fm.fileExists(atPath: base.path) { try fm.removeItem(at: base) }
            print(action == "--uninstall" ? "Microphone switching uninstalled. You can delete this shortcut. Change your input in System Settings → Sound if needed." : "Microphone switching disabled. Change your input in System Settings → Sound if needed.")
        default: throw failure("Unknown operation.")
        }
    }
} catch { fputs("\(error.localizedDescription)\n", stderr); exit(1) }
