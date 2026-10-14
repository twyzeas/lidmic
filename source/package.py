#!/usr/bin/env python3
"""Build a self-contained shortcut; no network access and no recipient toolchain."""
import base64, gzip, hashlib, pathlib, plistlib, shlex
root = pathlib.Path(__file__).resolve().parent
binary = (root / 'build/lid-microphone').read_bytes()
payload = base64.b64encode(gzip.compress(binary, mtime=0)).decode()
digest = hashlib.sha256(binary).hexdigest()
shell = f'''set -eu
umask 077
stage=$(/usr/bin/mktemp -d "${{TMPDIR:-/tmp/}}lid-microphone.XXXXXXXX")
trap '/bin/rm -rf "$stage"' EXIT HUP INT TERM
/usr/bin/printf %s {shlex.quote(payload)} | /usr/bin/base64 -D | /usr/bin/gzip -dc > "$stage/helper"
actual=$(/usr/bin/shasum -a 256 "$stage/helper")
[ "${{actual%% *}}" = {shlex.quote(digest)} ] || exit 1
/bin/chmod 700 "$stage/helper"
/usr/bin/codesign --verify --strict "$stage/helper"
"$stage/helper" --'''
def apple_string(s): return '"' + s.replace('\\','\\\\').replace('"','\\"').replace('\n','\\n') + '"'
script = '''on run {input, parameters}
set selection to choose from list {"Status", "Enable", "Disable", "Uninstall"} with title "LidMic" with prompt "Bluetooth first. Otherwise: lid closed → iPhone; lid open → built-in microphone." default items {"Enable"}
if selection is false then return
set operation to item 1 of selection
if operation is "Uninstall" then
    display dialog "Remove the background helper and its settings?" buttons {"Cancel", "Uninstall"} default button "Cancel" with title "LidMic"
end if
if operation is "Status" then set operation to "status"
if operation is "Enable" then set operation to "enable"
if operation is "Disable" then set operation to "disable"
if operation is "Uninstall" then set operation to "uninstall"
try
    set resultText to do shell script (''' + apple_string(shell) + ''' & operation)
    display dialog resultText buttons {"OK"} default button "OK" with title "LidMic"
on error errorText number errorNumber
    if errorNumber is not -128 then display dialog errorText buttons {"OK"} default button "OK" with title "LidMic — needs attention"
end try
end run
'''
(root / 'build/shortcut.applescript').write_text(script)
shortcut = {'WFWorkflowClientVersion':'2600','WFWorkflowMinimumClientVersion':900,'WFWorkflowName':'LidMic','WFWorkflowIcon':{'WFWorkflowIconStartColor':4282601983,'WFWorkflowIconGlyphNumber':61440},'WFWorkflowTypes':['MenuBar'],'WFWorkflowInputContentItemClasses':[], 'WFWorkflowActions':[{'WFWorkflowActionIdentifier':'is.workflow.actions.runapplescript','WFWorkflowActionParameters':{'Script':script}}]}
(root / '../LidMic.unsigned.shortcut').write_bytes(plistlib.dumps(shortcut))
(root / 'build/payload.sha256').write_text(digest+'\n')
print('Built self-contained shortcut; embedded universal helper SHA-256:', digest)
