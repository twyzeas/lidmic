#!/usr/bin/env python3
"""Exercise real watcher retry scheduling without changing the microphone."""
import pathlib, subprocess, tempfile
root = pathlib.Path(__file__).resolve().parent
with tempfile.TemporaryDirectory() as directory:
    main = pathlib.Path(directory) / 'main.swift'
    main.write_text('''import Foundation
func readPreferences() -> Preferences { Preferences() }
func wait(_ seconds: Double) { RunLoop.main.run(until: Date().addingTimeInterval(seconds)) }
var count = 0
var succeeds = false
let watcher = InputWatcher(evaluate: { _ in count += 1; return ("test", succeeds) })
watcher.receive("lid")
precondition(count == 1, "Event must evaluate immediately")
wait(0.35)
precondition(count == 2, "Unavailable device should retry")
succeeds = true
watcher.receive("lid")
precondition(count == 3)
wait(1.6)
precondition(count == 3, "New successful event must cancel stale retries")
succeeds = false
watcher.receive("lid")
wait(1.7)
precondition(count == 7, "Unavailable device gets exactly three retries")
wait(0.4)
precondition(count == 7, "Retries must stop")
watcher.receive("fallback")
wait(1.7)
precondition(count == 8, "Fallback must not start a fast retry loop")
print("Watcher immediate response, retry, cancellation, and retry-bound checks passed")
''')
    binary = pathlib.Path(directory) / 'watcher-test'
    subprocess.run(['xcrun', 'swiftc', '-module-cache-path', str(root/'build/module-cache'), str(root/'Audio.swift'), str(root/'Watcher.swift'), str(main), '-o', str(binary)], check=True)
    subprocess.run([str(binary)], check=True)
