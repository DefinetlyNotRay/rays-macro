/*
Reconnect Sync Extension for Natro Macro
Handles Discord-based reconnect synchronization between a main and alt account.
*/

reconnectsync_InitGUISettings() {
	global ReconnectSyncCheck, ReconnectSyncMode, ReconnectSyncChannelID
	static iniPath := A_ScriptDir "\..\settings\nm_config.ini"

	if !IsSet(ReconnectSyncCheck) || ReconnectSyncCheck = ""
		ReconnectSyncCheck := IniRead(iniPath, "Extensions", "ReconnectSyncCheck", 0)
	if !IsSet(ReconnectSyncMode) || ReconnectSyncMode = ""
		ReconnectSyncMode := IniRead(iniPath, "Extensions", "ReconnectSyncMode", "Main")
	if !IsSet(ReconnectSyncChannelID) || ReconnectSyncChannelID = ""
		ReconnectSyncChannelID := IniRead(iniPath, "Extensions", "ReconnectSyncChannelID", "")
	if !(ReconnectSyncMode ~= "i)^(Main|Alt)$")
		ReconnectSyncMode := "Main"
}
reconnectsync_InitGUISettings()
OnExit((*) => reconnectsync_SaveSettings(), -1)

recon_ReconnectSyncGUI(*) {
	global ReconnectSyncCheck, ReconnectSyncMode, ReconnectSyncChannelID
	global ReconnectSyncGUI, ReconnectSyncModeCtrl, ReconnectSyncChannelCtrl

	GuiClose(*) {
		reconnectsync_SaveSettings()
		if (IsSet(ReconnectSyncGUI) && IsObject(ReconnectSyncGUI))
			ReconnectSyncGUI.Destroy(), ReconnectSyncGUI := ""
	}

	GuiClose()
	ReconnectSyncGUI := Gui("+AlwaysOnTop +Border", "Reconnect Sync")
	ReconnectSyncGUI.OnEvent("Close", GuiClose)
	ReconnectSyncGUI.SetFont("s8 cDefault Bold", "Tahoma")
	ReconnectSyncGUI.Add("GroupBox", "x5 y2 w290 h55", "Settings")
	ReconnectSyncGUI.Add("CheckBox", "x73 y2 vReconnectSyncCheck Checked" ReconnectSyncCheck, "Enabled").OnEvent("Click", recon_ReconnectSyncCheck)
	ReconnectSyncGUI.SetFont("Norm")
	ReconnectSyncGUI.Add("Button", "x150 y1 w135 h16", "What does this do?").OnEvent("Click", recon_ReconnectSyncHelp)
	ReconnectSyncGUI.Add("Text", "x15 y23", "Role:")
	ReconnectSyncModeCtrl := ReconnectSyncGUI.Add("DropDownList", "x55 y19 w75 vReconnectSyncMode", ["Main", "Alt"])
	ReconnectSyncModeCtrl.Text := ReconnectSyncMode
	ReconnectSyncModeCtrl.OnEvent("Change", recon_ReconnectSyncModeSelect)
	ReconnectSyncGUI.Add("Text", "x135 y23", "Channel ID:")
	ReconnectSyncChannelCtrl := ReconnectSyncGUI.Add("Edit", "x205 y21 w75 h18 vReconnectSyncChannelID", ReconnectSyncChannelID)
	ReconnectSyncChannelCtrl.OnEvent("Change", recon_saveReconnectSyncChannelID)
	reconnectsync_UpdateControls()

	ReconnectSyncGUI.Show("w300 h58")
}

recon_ReconnectSyncCheck(GuiCtrl, *) {
	global ReconnectSyncCheck
	static iniPath := A_ScriptDir "\..\settings\nm_config.ini"
	ReconnectSyncCheck := GuiCtrl.Value
	IniWrite ReconnectSyncCheck, iniPath, "Extensions", "ReconnectSyncCheck"
	reconnectsync_UpdateControls(ReconnectSyncCheck)
}

reconnectsync_UpdateControls(enabled := "") {
	global ReconnectSyncCheck, ReconnectSyncGUI, ReconnectSyncModeCtrl, ReconnectSyncChannelCtrl
	if (enabled = "")
		enabled := (IsSet(ReconnectSyncGUI) && IsObject(ReconnectSyncGUI)) ? ReconnectSyncGUI["ReconnectSyncCheck"].Value : ReconnectSyncCheck
	if IsSet(ReconnectSyncModeCtrl)
		ReconnectSyncModeCtrl.Enabled := enabled
	if IsSet(ReconnectSyncChannelCtrl)
		ReconnectSyncChannelCtrl.Enabled := enabled
}

recon_ReconnectSyncHelp(*) {
	MsgBox "
	(
	DESCRIPTION:
	When this option is enabled, the macro can sync daily reconnects through a Discord channel.

	MODE:
	Main: Sends a disconnect message to the configured channel when the scheduled daily reconnect actually disconnects.
	Alt: Listens for that message and queues a reconnect after the message is seen.

	NOTE:
	This feature requires Discord bot mode and a valid Channel ID.
	)", "Reconnect Sync", 0x40000
}

recon_ReconnectSyncModeSelect(GuiCtrl?, *) {
	global ReconnectSyncMode, ReconnectSyncGUI
	static iniPath := A_ScriptDir "\..\settings\nm_config.ini"
	if IsSet(GuiCtrl) {
		ReconnectSyncMode := ReconnectSyncGUI["ReconnectSyncMode"].Text
		IniWrite ReconnectSyncMode, iniPath, "Extensions", "ReconnectSyncMode"
	}
}

recon_saveReconnectSyncChannelID(GuiCtrl, *) {
	global ReconnectSyncChannelID
	static iniPath := A_ScriptDir "\..\settings\nm_config.ini"
	p := EditGetCurrentCol(GuiCtrl)
	NewReconnectSyncChannelID := GuiCtrl.Value

	if (NewReconnectSyncChannelID ~= "^\d*$") {
		ReconnectSyncChannelID := NewReconnectSyncChannelID
		IniWrite ReconnectSyncChannelID, iniPath, "Extensions", "ReconnectSyncChannelID"
	} else {
		GuiCtrl.Value := ReconnectSyncChannelID
		SendMessage 0xB1, p-2, p-2, GuiCtrl
		nm_ShowErrorBalloonTip(GuiCtrl, "Invalid Discord Channel ID!", "Make sure it is a valid Channel ID.")
	}
}

reconnectsync_SaveSettings() {
	global ReconnectSyncCheck, ReconnectSyncMode, ReconnectSyncChannelID, ReconnectSyncGUI
	static iniPath := A_ScriptDir "\..\settings\nm_config.ini"
	if (IsSet(ReconnectSyncGUI) && IsObject(ReconnectSyncGUI)) {
		ReconnectSyncCheck := ReconnectSyncGUI["ReconnectSyncCheck"].Value
		ReconnectSyncMode := ReconnectSyncGUI["ReconnectSyncMode"].Text
		ReconnectSyncChannelID := ReconnectSyncGUI["ReconnectSyncChannelID"].Value
	}
	IniWrite ReconnectSyncCheck, iniPath, "Extensions", "ReconnectSyncCheck"
	IniWrite ReconnectSyncMode, iniPath, "Extensions", "ReconnectSyncMode"
	IniWrite ReconnectSyncChannelID, iniPath, "Extensions", "ReconnectSyncChannelID"
}

recon_NotifyReconnectSyncDisconnect(reason := "Daily Disconnect") {
	global ReconnectSyncCheck, ReconnectSyncMode, ReconnectSyncChannelID, discordMode

	if !(ReconnectSyncCheck && (ReconnectSyncMode = "Main") && (ReconnectSyncChannelID != "") && (discordMode = 1)) {
		return false
	}

	try {
		PostSubmacroMessage("Status", 0x5566, 1)
	}
	catch as err {
		return false
	}
	return true
}
