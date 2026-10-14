#!/usr/bin/env python3
"""Run the packaged AppleScript's menu branches with UI and helper calls stubbed.

Uses Shortcuts terminology to catch host dictionary conflicts; never installs,
uninstalls, or changes the user's microphone.
"""
import pathlib, plistlib, subprocess
root = pathlib.Path(__file__).resolve().parent
workflow = plistlib.loads((root / '../LidMic.unsigned.shortcut').read_bytes())
assert workflow['WFWorkflowName'] == 'LidMic — Auto Switch Mic'
source = workflow['WFWorkflowActions'][0]['WFWorkflowActionParameters']['Script']
lines = source.splitlines()
for choice, expected in [('Status','status'), ('Enable','enable'), ('Disable','disable'), ('Uninstall','uninstall'), (None,'')]:
    stubbed = []
    for line in lines:
        if line.startswith('set chosenAction to choose from list '):
            line = 'set chosenAction to my menuChoice()'
        elif line.strip().startswith('display dialog "Uninstall microphone switching?'):
            line = '-- Confirmation accepted in isolated test.'
        elif line.strip().startswith('display dialog resultText'):
            line = 'return resultText'
        elif line.strip().startswith('if errorNumber is not -128 then display dialog'):
            line = 'error errorText number errorNumber'
        line = line.replace('do shell script (', 'my invokeHelper(')
        stubbed.append(line)
    selection = 'false' if choice is None else '{"' + choice + '"}'
    script = '\n'.join(stubbed).replace('on run {input, parameters}', 'on testRun(input, parameters)').replace('end run', 'end testRun') + '''
on menuChoice()
    return ''' + selection + '''
end menuChoice
on invokeHelper(commandText)
    repeat with operationName in {"status", "enable", "disable", "uninstall"}
        if commandText ends with ("--" & operationName) then return contents of operationName
    end repeat
    error "Unexpected helper command"
end invokeHelper
'''
    wrapped = 'using terms from application "Shortcuts"\nscript workflowUnderTest\n' + script + "\nend script\nend using terms from\nreturn workflowUnderTest's testRun(missing value, missing value)\n"
    result = subprocess.run(['osascript','-'],input=wrapped,text=True,capture_output=True)
    assert result.returncode == 0, result.stderr
    assert result.stdout.strip() == expected, (choice, result.stdout, result.stderr)
print('All four menu actions and cancellation passed under Shortcuts terminology (UI/helper calls stubbed)')
