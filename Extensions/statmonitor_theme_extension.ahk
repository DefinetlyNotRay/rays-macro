#Requires AutoHotkey v2.0
; Made by @definetlynotray on discord

aq_StatMonitorThemeEditorGUI(*) {
	editorPath := A_WorkingDir "\submacros\StatMonitorThemeEditor.ahk"
	if !FileExist(editorPath) {
		MsgBox("StatMonitorThemeEditor.ahk was not found in submacros.", "StatMonitor Theme Editor", 0x30)
		return
	}

	if WinExist("StatMonitor Theme Editor ahk_class AutoHotkey") {
		WinActivate()
		return
	}

	try Run('"' A_AhkPath '" /script "' editorPath '"', A_WorkingDir)
	catch as e
		MsgBox("Failed to open the StatMonitor theme editor.`n`n" e.Message, "StatMonitor Theme Editor", 0x10)
}
