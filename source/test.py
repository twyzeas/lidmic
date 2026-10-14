#!/usr/bin/env python3
import base64, gzip, hashlib, os, pathlib, plistlib, re, subprocess, tempfile
root=pathlib.Path(__file__).resolve().parent
os.chdir(root)
def run(*args, **kw): return subprocess.check_output(args, text=True, **kw)
# Compile production selection logic with test entry point; no device writes.
with tempfile.TemporaryDirectory() as td:
    t=pathlib.Path(td)
    tests='''import Foundation
import CoreAudio
func readPreferences() -> Preferences { Preferences() }
func device(_ id: UInt32, _ transport: UInt32) -> InputDevice { InputDevice(id: id, name: "Any localized name", uid: String(id), transport: transport) }
let built = device(1, 0x626c746e), phone = device(2, 0x6363776c), wiredPhone = device(3, 0x63637764)
let bt = device(4, 0x626c7565), le = device(5, 0x626c6561), usb = device(6, 0x75736220)
func check(_ devices: [InputDevice], _ lid: Bool?, _ current: UInt32?, _ expected: UInt32?, _ prefs: Preferences = Preferences()) {
    precondition(selectInput(devices, lidClosed: lid, currentID: current, preferences: prefs)?.id == expected)
}
check([built, phone], false, 2, 1)
check([built, phone], true, 1, 2)
check([built, wiredPhone], true, 1, 3)
check([built, phone, bt], false, 1, 4)
check([built, phone, bt], true, 2, 4)
check([bt, le], nil, 5, 5)
check([le, bt], false, nil, 4)
check([built, phone], nil, 1, nil)
check([built], true, 1, nil)
check([usb], false, 6, nil)
check([phone, wiredPhone], true, nil, nil)
check([phone, wiredPhone], true, nil, 3, Preferences(continuityUID: "3"))
check([phone], true, nil, nil, Preferences(continuityUID: "3"))
check([device(7, 0x63636170)], true, nil, 7)
check([], true, nil, nil)
print("15 selection cases passed")
'''
    (t/'main.swift').write_text(tests)
    run('xcrun','swiftc','-module-cache-path',str(root/'build/module-cache'),'Audio.swift',str(t/'main.swift'),'-o',str(t/'selection'))
    print(run(str(t/'selection')).strip())
    run('xcrun','swiftc','-D','TESTING','-module-cache-path',str(root/'build/module-cache'),'Audio.swift','main.swift','-o',str(t/'lifecycle'))
    run('codesign','--force','--sign','-',str(t/'lifecycle'))
    isolated=t/'test home with spaces & accents é'; isolated.mkdir()
    env=dict(os.environ,LID_TEST_HOME=str(isolated))
    for action in ['status','enable','enable','status','disable','disable','status','enable','uninstall','uninstall','status']:
        result=run(str(t/'lifecycle'),'--'+action,env=env)
        agent=isolated/'Library/LaunchAgents/local.lid-microphone.plist'
        base=isolated/'Library/Application Support/Lid Microphone'
        if action=='enable':
            p=plistlib.loads(agent.read_bytes())
            assert pathlib.Path(p['ProgramArguments'][0]).samefile(base/'lid-microphone') and p['ProgramArguments'][1]=='--watch'
            assert (isolated/'loaded').exists()
        if action in ['disable','uninstall']: assert not agent.exists() and not (isolated/'loaded').exists()
        if action=='uninstall': assert not base.exists()
    print('11 isolated lifecycle operations passed (launchctl simulated; real files/signature checks)')
workflow=plistlib.loads((root/'../LidMic.unsigned.shortcut').read_bytes())
script=workflow['WFWorkflowActions'][0]['WFWorkflowActionParameters']['Script']
payload=re.search(r'/usr/bin/printf %s ([A-Za-z0-9+/=]+)',script).group(1)
binary=gzip.decompress(base64.b64decode(payload))
assert binary==(root/'build/lid-microphone').read_bytes()
assert hashlib.sha256(binary).hexdigest() in script
for banned in [b'/Users/', b'twyzeas', 'Péter'.encode(), b'gui/501']:
    assert banned not in binary and banned not in script.encode(), banned
run('osacompile','-o',str(root/'build/checked.scpt'),str(root/'build/shortcut.applescript'))
assert 'arm64' in run('lipo','-archs','build/lid-microphone') and 'x86_64' in run('lipo','-archs','build/lid-microphone')
run('codesign','--verify','--strict','build/lid-microphone')
print('AppleScript syntax, universal architectures, payload integrity, signature, and private metadata checks passed')
