/*
Reconnect Sync Status Extension for Natro Macro
Watches a Discord channel for daily reconnect sync messages and queues reconnects on alt accounts.
*/

reconnectsync_InitSettings(force := false) {
	global ReconnectSyncCheck, ReconnectSyncMode, ReconnectSyncChannelID
	static iniPath := A_ScriptDir "\..\settings\nm_config.ini"

	if force || !IsSet(ReconnectSyncCheck) || ReconnectSyncCheck = ""
	{
		ReconnectSyncCheck := IniRead(iniPath, "Extensions", "ReconnectSyncCheck", 0)
	}
	if force || !IsSet(ReconnectSyncMode) || ReconnectSyncMode = ""
	{
		ReconnectSyncMode := IniRead(iniPath, "Extensions", "ReconnectSyncMode", "Main")
	}
	if force || !IsSet(ReconnectSyncChannelID) || ReconnectSyncChannelID = ""
	{
		ReconnectSyncChannelID := IniRead(iniPath, "Extensions", "ReconnectSyncChannelID", "")
	}
	if !(ReconnectSyncMode ~= "i)^(Main|Alt)$")
		ReconnectSyncMode := "Main"
}
reconnectsync_InitSettings()

recon_SendReconnectSyncBroadcast(wParam := 0, lParam := 0, *) {
	global ReconnectSyncCheck, ReconnectSyncMode, ReconnectSyncChannelID, discordMode

	reconnectsync_InitSettings(true)
	if !(ReconnectSyncCheck && (ReconnectSyncMode = "Main") && (ReconnectSyncChannelID != "") && (discordMode = 1)) {
		return
	}

	payload_json := '{"content":"SyncReconnect"}'
	try {
		resp := discord.SendMessageAPI(payload_json, "application/json", ReconnectSyncChannelID)
	}
	catch as err {
		return
	}
}

reconnectsync_PollAlt() {
	global ReconnectSyncCheck, ReconnectSyncMode, ReconnectSyncChannelID
	static last_message_id := ""
	static initialized := false

	reconnectsync_InitSettings(true)
	if !(ReconnectSyncCheck && (ReconnectSyncMode = "Alt") && (ReconnectSyncChannelID != "")) {
		return
	}

	try messages := discord.GetRecentMessages(ReconnectSyncChannelID)
	catch as err {
		return
	}

	if (!messages || !IsObject(messages) || messages.Length = 0) {
		return
	}

	if (!initialized) {
		last_message_id := messages[1]["id"]
		initialized := true
		return
	}

	newest_id := messages[1]["id"]
	if (newest_id = last_message_id) {
		return
	}

	for message in messages {
		msg_id := message["id"]
		msg_content := message["content"]

		if (msg_id = last_message_id) {
			break
		}

		if InStr(msg_content, "SyncReconnect") {
			DetectHiddenWindows 1
			if (hwnd := WinExist("natro_macro ahk_class AutoHotkey")) {
				PostMessage 0x5557, 60, 1,, "ahk_id " hwnd
			}
			CloseRoblox()
			DetectHiddenWindows 0
			last_message_id := newest_id
			return
		}
	}

	last_message_id := newest_id
}
