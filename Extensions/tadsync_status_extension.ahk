/*
TadSync Status Extension for Natro Macro
Handles Discord field following communication

This file contains Status.ahk TadSync functionality.
Include this in Status.ahk via the patch script.

Original TadSync by aquaticcreeper
Patch/custom work Made by @definetlynotray on discord
*/

; ===== FIELD MAPS FOR TADSYNC (STATUS) =====
; Made by @definetlynotray on discord

tadsync_status_InitFieldMaps() {
	global index_field_map, field_index_map
	
	; Check if already initialized
	if IsSet(index_field_map) && index_field_map.Count > 0
		return
	
	index_field_map := Map()
	index_field_map[1] := "Bamboo"
	index_field_map[2] := "Blue Flower"
	index_field_map[3] := "Cactus"
	index_field_map[4] := "Clover"
	index_field_map[5] := "Coconut"
	index_field_map[6] := "Dandelion"
	index_field_map[7] := "Mountain Top"
	index_field_map[8] := "Mushroom"
	index_field_map[9] := "Pepper"
	index_field_map[10] := "Pineapple"
	index_field_map[11] := "Pine Tree"
	index_field_map[12] := "Pumpkin"
	index_field_map[13] := "Rose"
	index_field_map[14] := "Spider"
	index_field_map[15] := "Strawberry"
	index_field_map[16] := "Stump"
	index_field_map[17] := "Sunflower"

	field_index_map := Map(), field_index_map.CaseSense := 0
	field_index_map["bamboo"] := 1
	field_index_map["blueflower"] := 2
	field_index_map["cactus"] := 3
	field_index_map["clover"] := 4
	field_index_map["coconut"] := 5
	field_index_map["dandelion"] := 6
	field_index_map["mountaintop"] := 7
	field_index_map["mushroom"] := 8
	field_index_map["pepper"] := 9
	field_index_map["pineapple"] := 10
	field_index_map["pinetree"] := 11
	field_index_map["pumpkin"] := 12
	field_index_map["rose"] := 13
	field_index_map["spider"] := 14
	field_index_map["strawberry"] := 15
	field_index_map["stump"] := 16
	field_index_map["sunflower"] := 17
}

; Initialize on load
tadsync_status_InitFieldMaps()

; Read TadSync settings from INI file (since they may not be passed as args)
tadsync_InitSettings() {
	global FieldFollowingCheck, FieldFollowingFollowMode, FieldFollowingMaxTime, FieldFollowingChannelID
	static iniPath := A_ScriptDir "\..\settings\nm_config.ini"
	
	; Only init if not already set via args
	if !IsSet(FieldFollowingCheck) || FieldFollowingCheck = ""
		FieldFollowingCheck := IniRead(iniPath, "Extensions", "FieldFollowingCheck", 0)
	if !IsSet(FieldFollowingFollowMode) || FieldFollowingFollowMode = ""
		FieldFollowingFollowMode := IniRead(iniPath, "Extensions", "FieldFollowingFollowMode", "Follower")
	if !IsSet(FieldFollowingMaxTime) || FieldFollowingMaxTime = ""
		FieldFollowingMaxTime := IniRead(iniPath, "Extensions", "FieldFollowingMaxTime", 600)
	if !IsSet(FieldFollowingChannelID) || FieldFollowingChannelID = ""
		FieldFollowingChannelID := IniRead(iniPath, "Extensions", "FieldFollowingChannelID", "")
}
tadsync_InitSettings()

tadsync_status_ShouldReadFollowCommands() {
	global FieldFollowingFollowMode

	return (FieldFollowingFollowMode = "Follower" || FieldFollowingFollowMode = "Guiding")
}

tadsync_status_ResolveFollowTarget(field) {
	; Made by @definetlynotray on discord - guiding remap behavior
	global FieldFollowingFollowMode, field_index_map

	field_lower := StrLower(Trim(field))
	if (field_lower = "")
		return ""

	if (FieldFollowingFollowMode = "Guiding") {
		if (field_lower = "bamboo")
			return "pineapple"
		if (field_lower = "pinetree")
			return "rose"
		if (field_lower = "blueflower")
			return "mushroom"
		return ""
	}

	if (field_lower = "hive")
		return "hive"

	return field_index_map.Has(field_lower) ? field_lower : ""
}

; ===== GET FOLLOWING FIELD FROM DISCORD =====
; Called periodically in main loop when FieldFollowingCheck is enabled
; Made by @definetlynotray on discord

aq_getFollowingField()
{
	global FieldFollowingFollowMode, FieldFollowingChannelID, MacroState, field_index_map
	static last_message_id := ""
	static initialized := false
	static debugLog := A_ScriptDir "\tadsync_debug.txt"

	; Skip if no channel configured
	if (!FieldFollowingChannelID)
		return

	messages := discord.GetRecentMessages(FieldFollowingChannelID)
	
	if (!messages || !IsObject(messages) || messages.Length = 0) {
		FileAppend(A_Now " - No messages or empty response`n", debugLog)
		return
	}

	; Prime the last message ID on first run so we only follow NEW messages
	if (!initialized) {
		; Get the most recent message ID to establish baseline
		last_message_id := messages[1]["id"]
		initialized := true
		FileAppend(A_Now " - Initialized with msg ID: " last_message_id "`n", debugLog)
		return
	}

	; Check if there are new messages
	newest_id := messages[1]["id"]
	if (newest_id = last_message_id) {
		; No new messages - no need to log every time
		return
	}
	
	FileAppend(A_Now " - Checking new messages. Newest: " newest_id " Last: " last_message_id "`n", debugLog)

	; Process messages from newest to oldest, looking for new ones
	for message in messages {
		msg_id := message["id"]
		msg_content := message["content"]
		
		FileAppend(A_Now " - Checking msg " msg_id ": " msg_content "`n", debugLog)
		
		; Stop when we reach a message we've already seen
		if (msg_id = last_message_id) {
			FileAppend(A_Now " - Reached last seen message, stopping`n", debugLog)
			break
		}
		
		; Check for FollowTo command
		if (tadsync_status_ShouldReadFollowCommands() && InStr(msg_content, "FollowTo")) {
			parts := StrSplit(msg_content, " ")
			field := (parts.Length >= 2) ? parts[2] : ""
			field_lower := StrLower(field)
			target_field := tadsync_status_ResolveFollowTarget(field)
			FileAppend(A_Now " - Found FollowTo! Field: " field " Lower: " field_lower " Target: " target_field " Mode: " FieldFollowingFollowMode " MacroState: " MacroState "`n", debugLog)
			
			if (field && target_field != "" && MacroState > 0) {
				DetectHiddenWindows 1
				if WinExist("natro_macro ahk_class AutoHotkey") {
					if (target_field = "hive") {
						PostMessage 0x555B, 1
						FileAppend(A_Now " - Sent hive standby directive to natro_macro`n", debugLog)
					} else {
						field_idx := field_index_map[target_field]
						FileAppend(A_Now " - Sending field index " field_idx " to natro_macro (target: " target_field ")`n", debugLog)
						PostMessage 0x555A, field_idx
						FileAppend(A_Now " - PostMessage sent!`n", debugLog)
					}
				} else {
					FileAppend(A_Now " - natro_macro window NOT FOUND`n", debugLog)
				}
				DetectHiddenWindows 0

				if (target_field != "") {
					; Update last seen ID to newest message
					last_message_id := messages[1]["id"]
					return
				}
			}
		}
	}
	
	; Update last seen ID even if no FollowTo found (to avoid reprocessing)
	last_message_id := messages[1]["id"]
}

; ===== ANNOUNCE FIELD TO DISCORD =====
; Called via OnMessage 0x5561 when leader announces field change

aq_announce(wParam, *)
{
	global FieldFollowingChannelID, index_field_map
	fieldarg := StrReplace(index_field_map[wParam], " ")

	payload_json := '{"content": "FollowTo ' fieldarg '"}'
	discord.SendMessageAPI(payload_json, "application/json", FieldFollowingChannelID)
}

aq_announceHiveStandby(wParam, *)
{
	global FieldFollowingChannelID

	payload_json := '{"content": "FollowTo Hive"}'
	discord.SendMessageAPI(payload_json, "application/json", FieldFollowingChannelID)
}
