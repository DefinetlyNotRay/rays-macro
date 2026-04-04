/*
TadSync Extension for Natro Macro
Field Following / TadSync Feature

This file contains all TadSync/Field Following functionality.
It is designed to be included in natro_macro.ahk via the patch script.

Original TadSync by aquaticcreeper
Patch/custom work Made by @definetlynotray on discord
*/

; ===== FIELD MAPS FOR TADSYNC =====
; These maps are used to translate between field indices and names for Discord communication
; Made by @definetlynotray on discord

tadsync_InitFieldMaps() {
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

; Initialize field maps and other settings
tadsync_Init() {
	global index_field_map, field_index_map
	tadsync_InitFieldMaps()
	
	; Set OnMessage handler
	OnMessage(0x555A, aq_followToField)
	OnMessage(0x555B, tadsync_QueueHiveStandby)
}
tadsync_Init()

; Initialize GUI settings from INI (needed for Field Following GUI)
tadsync_InitGUISettings() {
	global FieldFollowingCheck, FieldFollowingFollowMode, FieldFollowingMaxTime, FieldFollowingChannelID
	global FollowingLeader, FollowingField, FollowingStartTime, LastAnnouncedField, FollowingDirective, HiveStandbyStatusShown
	
	; Read from INI or use defaults
	if !IsSet(FieldFollowingCheck) || FieldFollowingCheck = ""
		FieldFollowingCheck := IniRead("settings\nm_config.ini", "Extensions", "FieldFollowingCheck", 0)
	if !IsSet(FieldFollowingFollowMode) || FieldFollowingFollowMode = ""
		FieldFollowingFollowMode := IniRead("settings\nm_config.ini", "Extensions", "FieldFollowingFollowMode", "Follower")
	if !IsSet(FieldFollowingMaxTime) || FieldFollowingMaxTime = ""
		FieldFollowingMaxTime := IniRead("settings\nm_config.ini", "Extensions", "FieldFollowingMaxTime", 900)
	if !IsSet(FieldFollowingChannelID) || FieldFollowingChannelID = ""
		FieldFollowingChannelID := IniRead("settings\nm_config.ini", "Extensions", "FieldFollowingChannelID", "")
	
	; Initialize runtime variables
	if !IsSet(FollowingLeader)
		FollowingLeader := 0
	if !IsSet(FollowingField)
		FollowingField := ""
	if !IsSet(FollowingStartTime)
		FollowingStartTime := 0
	if !IsSet(LastAnnouncedField)
		LastAnnouncedField := ""
	if !IsSet(FollowingDirective)
		FollowingDirective := ""
	if !IsSet(HiveStandbyStatusShown)
		HiveStandbyStatusShown := 0
}
tadsync_InitGUISettings()

; Add TadSync button to the Main GUI
tadsync_AddGUI(MainGui) {
	; Made by @definetlynotray on discord - TadSync UI hook
	; Resize Night Detection button first to make room
	; We assume the button is already there or will be added
	; Actually, the patch handles the resize for now or we can do it here if we have the control
	
	MainGui.Add("Button", "x340 y146 w150 h20 vFieldFollowingGUI Disabled", "Field Following").OnEvent("Click", aq_FieldFollowingGUI)
}

; Enable/Disable TadSync buttons
tadsync_Enable(state) {
	try {
		if IsSet(MainGui) && MainGui["FieldFollowingGUI"]
			MainGui["FieldFollowingGUI"].Enabled := state
	}
}

; ===== CORE TADSYNC FUNCTIONS =====
; Made by @definetlynotray on discord

tadsync_ClearFollowState(resetLeader := 1) {
	global FollowingLeader, FollowingField, FollowingStartTime, FollowingDirective, HiveStandbyStatusShown

	if (resetLeader)
		FollowingLeader := 0
	FollowingField := ""
	FollowingStartTime := 0
	FollowingDirective := ""
	HiveStandbyStatusShown := 0
}

tadsync_SetFollowField(newField) {
	global FollowingLeader, FollowingField, FollowingStartTime, FollowingDirective, HiveStandbyStatusShown

	if (FollowingLeader = 1 && FollowingDirective = "" && FollowingField = newField)
		return false

	FollowingLeader := 1
	FollowingStartTime := nowUnix()
	FollowingField := newField
	FollowingDirective := ""
	HiveStandbyStatusShown := 0
	return true
}

tadsync_FollowTimedOut() {
	global FollowingLeader, FollowingStartTime, FieldFollowingMaxTime

	if (FollowingLeader != 1)
		return false
	if !(FieldFollowingMaxTime > 0)
		return false
	if ((nowUnix() - FollowingStartTime) <= FieldFollowingMaxTime)
		return false

	tadsync_ClearFollowState()
	return true
}

; Handler for following to a field (called via OnMessage 0x555A)
aq_followToField(wParam, *){
	global index_field_map, FieldName1
	static debugLog := A_ScriptDir "\tadsync_natro_debug.txt"
	
	FileAppend(A_Now " - aq_followToField called! wParam: " wParam "`n", debugLog)
	
	newField := index_field_map[wParam]
	FileAppend(A_Now " - newField: " newField " FieldName1: " FieldName1 "`n", debugLog)
	
	if !tadsync_SetFollowField(newField) {
		FileAppend(A_Now " - Already following same field, skipping`n", debugLog)
		return
	}
	FileAppend(A_Now " - SET field follow target := " newField "`n", debugLog)
	
	; Trigger interrupt in natro_macro if we are gathering
	global MacroState
	FileAppend(A_Now " - MacroState: " MacroState "`n", debugLog)
}

tadsync_QueueHiveStandby(*) {
	global FollowingLeader, FollowingField, FollowingStartTime, FollowingDirective, HiveStandbyStatusShown
	static debugLog := A_ScriptDir "\tadsync_natro_debug.txt"

	if (FollowingLeader = 1 && FollowingDirective = "HiveStandby")
		return

	FollowingLeader := 1
	FollowingStartTime := nowUnix()
	FollowingField := ""
	FollowingDirective := "HiveStandby"
	HiveStandbyStatusShown := 0
	FileAppend(A_Now " - SET hive standby directive`n", debugLog)
}

tadsync_RequestHiveStandby() {
	global FieldFollowingCheck, FieldFollowingFollowMode, LastAnnouncedField

	if !(FieldFollowingCheck && FieldFollowingFollowMode = "Leader")
		return false

	PostSubmacroMessage("Status", 0x5562, 1)
	LastAnnouncedField := "__HiveStandby__"
	return true
}

tadsync_AbortActiveWalk() {
	global currentWalk
	static lastAbortTick := 0

	if ((A_TickCount - lastAbortTick) < 250)
		return

	lastAbortTick := A_TickCount
	DetectHiddenWindows 1
	try {
		if IsSet(currentWalk) && currentWalk.pid && WinExist("ahk_class AutoHotkey ahk_pid " currentWalk.pid) {
			Click "Up"
			nm_endWalk()
		}
	}
	DetectHiddenWindows 0
}

tadsync_ShouldInterruptFollowing(currentField) {
	global FollowingLeader, FollowingField, FollowingDirective

	if (FollowingLeader != 1)
		return false
	if tadsync_FollowTimedOut()
		return false
	if (FollowingDirective = "HiveStandby") {
		tadsync_AbortActiveWalk()
		return true
	}
	if (FollowingField != "" && currentField != FollowingField) {
		tadsync_AbortActiveWalk()
		return true
	}
	return false
}

tadsync_FindHiveSlotCompat(convertAfter := 1, forceBalloonConvert := 0) {
	; Sticker Stack extends nm_findHiveSlot() with resume parameters.
	; Call the 2-arg version only when that signature is actually present.
	findHiveSlot := Func("nm_findHiveSlot")
	return (findHiveSlot.MaxParams >= 2)
		? findHiveSlot.Call(convertAfter, forceBalloonConvert)
		: findHiveSlot.Call()
}

tadsync_HandleHiveStandby() {
	global FollowingLeader, FollowingDirective, HiveConfirmed, HiveStandbyStatusShown

	if !(FollowingLeader = 1 && FollowingDirective = "HiveStandby")
		return false
	if tadsync_FollowTimedOut() {
		return false
	}

	if (HiveConfirmed != 1) {
		HiveStandbyStatusShown := 0
		nm_setStatus("Traveling", "TadSync Hive Standby")
		nm_Reset(2, 2000, 0, 1)
		tadsync_FindHiveSlotCompat(0, 0)
	}

	if !(FollowingLeader = 1 && FollowingDirective = "HiveStandby") {
		HiveStandbyStatusShown := 0
		return false
	}

	if !HiveStandbyStatusShown {
		nm_setStatus("Waiting", "TadSync Hive Standby")
		HiveStandbyStatusShown := 1
	}

	Sleep 750
	return true
}

; Announce current field to Discord for followers
aq_announceField(field){
	global field_index_map, LastAnnouncedField
	fieldarg := StrReplace(field, " ")
	PostSubmacroMessage("Status", 0x5561, field_index_map[fieldarg])
	LastAnnouncedField := field
}

aq_togglePFieldBoosted(*) {
	global PFieldBoosted
	IniWrite (PFieldBoosted := MainGui["PFieldBoosted"].Value), "settings\nm_config.ini", "Extensions", "PFieldBoosted"
}

; ===== FIELD FOLLOWING GUI =====

aq_FieldFollowingGUI(*){
	global
	global FieldFollowingFollowMode
	GuiClose(*){
		if (IsSet(FieldFollowingGUI) && IsObject(FieldFollowingGUI))
			FieldFollowingGUI.Destroy(), FieldFollowingGUI := ""
	}
	GuiClose()
	FieldFollowingGUI := Gui("+AlwaysOnTop +Border", "Field Following")
	FieldFollowingGUI.OnEvent("Close", GuiClose)
	FieldFollowingGUI.SetFont("s8 cDefault Bold", "Tahoma")
	FieldFollowingGUI.Add("GroupBox", "x5 y2 w290 h65", "Settings")
	FieldFollowingGUI.Add("CheckBox", "x73 y2 vFieldFollowingCheck Checked" FieldFollowingCheck, "Enabled").OnEvent("Click", aq_FieldFollowingCheck)
	FieldFollowingGUI.SetFont("Norm")
	FieldFollowingGUI.Add("Button", "x150 y1 w135 h16", "What does this do?").OnEvent("Click", aq_FieldFollowingHelp)
	FieldFollowingGUI.Add("Text", "x15 y23", "Follow Mode:")
	(GuiCtrl := FieldFollowingGUI.Add("DropDownList", "x80 y19 w75 vFieldFollowingFollowMode Disabled" (FieldFollowingCheck = 0), ["Leader", "Follower", "Guiding"])).Text := FieldFollowingFollowMode, GuiCtrl.OnEvent("Change", aq_FieldFollowingFollowModeSelect)
	FieldFollowingGUI.Add("Text", "x160 y23", "Max Time:")
	FieldFollowingGUI.Add("Edit", "x210 y21 w70 h18 vFieldFollowingMaxTime Disabled" (FieldFollowingCheck = 0), FieldFollowingMaxTime).OnEvent("Change", aq_saveFieldFollowingMaxTime)
	FieldFollowingGUI.Add("Text", "x15 y45", "Channel ID:")
	FieldFollowingGUI.Add("Edit", "x80 y43 w200 h18 vFieldFollowingChannelID Disabled" (FieldFollowingCheck = 0), FieldFollowingChannelID).OnEvent("Change", aq_saveFieldFollowingChannelID)

	FieldFollowingGUI.Show("w290 h62")
}

aq_FieldFollowingCheck(*){
	global FieldFollowingCheck, FieldFollowingGUI
	FieldFollowingCheck := FieldFollowingGUI["FieldFollowingCheck"].Value
	IniWrite FieldFollowingCheck, "settings\nm_config.ini", "Extensions", "FieldFollowingCheck"
	PostSubmacroMessage("Status", 0x5552, 361, FieldFollowingCheck)
	FieldFollowingGUI["FieldFollowingFollowMode"].Enabled := FieldFollowingGUI["FieldFollowingMaxTime"].Enabled := FieldFollowingGUI["FieldFollowingChannelID"].Enabled := FieldFollowingCheck
}

aq_FieldFollowingHelp(*){
	MsgBox "
	(
	DESCRIPTION:
	When this option is enabled, the macro will automatically follow a leader account to whatever field they are gathering in if it is a follower account, or announce field changes to follower accounts if it is a leader account.
	NOTE:
	You must have a Discord bot setup in order for this feature to work properly. It is recommended to not use the same channel ID as the bot for this.

	Follow Mode:
	Leader: This account announces field changes for follower/guiding accounts to react to.
	Follower: This account follows the leader directly to the announced field.
	Guiding: This account only reacts to the guiding field calls.
	Guiding field calls:
	Bamboo -> Pineapple
	PineTree -> Rose
	BlueFlower -> Mushroom

	Max Time:
	This is the maximum amount of time that the macro will follow the leader account before it returns to it's original gather field (in seconds). This is not relevant if the follow mode is Leader.

	Channel ID:
	IF this account is a follower account: This is the channel ID that the account will listen to field changes in, make sure this is the same as the announcement channel of the leader account.
	IF this account is a leader account: This is the channel ID that the account will announce field changes in, make sure this is the same as the listen channel of the follower account.

	)", "Field Following", 0x40000
}

aq_FieldFollowingFollowModeSelect(GuiCtrl?, *){
	global FieldFollowingFollowMode
	if IsSet(GuiCtrl) {
		FieldFollowingFollowMode := FieldFollowingGUI["FieldFollowingFollowMode"].Text
		IniWrite FieldFollowingFollowMode, "settings\nm_config.ini", "Extensions", "FieldFollowingFollowMode"
		PostSubmacroMessage("Status", 0x5553, 80, 10)
	}
}

aq_saveFieldFollowingMaxTime(GuiCtrl, *){
	global FieldFollowingMaxTime
	p := EditGetCurrentCol(GuiCtrl)
	NewFieldFollowingMaxTime := GuiCtrl.Value

	if (NewFieldFollowingMaxTime ~= "^\d*$")
	{
		FieldFollowingMaxTime := NewFieldFollowingMaxTime
		IniWrite FieldFollowingMaxTime, "settings\nm_config.ini", "Extensions", "FieldFollowingMaxTime"
		PostSubmacroMessage("Status", 0x5553, 81, 10)
	}
	else
	{
		GuiCtrl.Value := FieldFollowingMaxTime
		SendMessage 0xB1, p-2, p-2, GuiCtrl
		nm_ShowErrorBalloonTip(GuiCtrl, "Invalid max follow time!", "Make sure it is a valid number (in seconds).")
	}
}

aq_saveFieldFollowingChannelID(GuiCtrl, *){
	global FieldFollowingChannelID
	p := EditGetCurrentCol(GuiCtrl)
	NewFieldFollowingChannelID := GuiCtrl.Value

	if (NewFieldFollowingChannelID ~= "^\d*$")
	{
		FieldFollowingChannelID := NewFieldFollowingChannelID
		IniWrite FieldFollowingChannelID, "settings\nm_config.ini", "Extensions", "FieldFollowingChannelID"
		PostSubmacroMessage("Status", 0x5553, 82, 10)
	}
	else
	{
		GuiCtrl.Value := FieldFollowingChannelID
		SendMessage 0xB1, p-2, p-2, GuiCtrl
		nm_ShowErrorBalloonTip(GuiCtrl, "Invalid Discord Channel ID!", "Make sure it is a valid Channel ID.")
	}
}

; ===== FIELD FOLLOWING OVERRIDE LOGIC =====
; This function applies the "following" field override in nm_GoGather
; Call this in the field override section of nm_GoGather

tadsync_ApplyFollowingOverride(&FieldName, &FieldPattern, &FieldPatternSize, &FieldPatternReps, 
	&FieldPatternShift, &FieldPatternInvertFB, &FieldPatternInvertLR, &FieldUntilMins, 
	&FieldUntilPack, &FieldReturnType, &FieldSprinklerLoc, &FieldSprinklerDist, 
	&FieldRotateDirection, &FieldRotateTimes, &FieldDriftCheck, &fieldOverrideReason) {
	
	global FollowingLeader, FollowingField, FollowingDirective, FieldDefault
	
	if (FollowingLeader = 1) {
		if tadsync_FollowTimedOut()
			return false
		if (FollowingDirective = "HiveStandby")
			return false
		if (FollowingField = "")
			return false
		
		fieldOverrideReason := "Following"
		FieldName := FollowingField
		
		; Ensure field exists in defaults
		if !FieldDefault.Has(FollowingField) {
			tadsync_ClearFollowState()
			return false
		}
		
		FieldPattern := FieldDefault[FollowingField]["pattern"]
		FieldPatternSize := FieldDefault[FollowingField]["size"]
		FieldPatternReps := FieldDefault[FollowingField]["width"]
		FieldPatternShift := FieldDefault[FollowingField]["shiftlock"]
		FieldPatternInvertFB := FieldDefault[FollowingField]["invertFB"]
		FieldPatternInvertLR := FieldDefault[FollowingField]["invertLR"]
		FieldUntilMins := FieldDefault[FollowingField]["gathertime"]
		FieldUntilPack := FieldDefault[FollowingField]["percent"]
		FieldReturnType := FieldDefault[FollowingField]["convert"]
		FieldSprinklerLoc := FieldDefault[FollowingField]["sprinkler"]
		FieldSprinklerDist := FieldDefault[FollowingField]["distance"]
		FieldRotateDirection := FieldDefault[FollowingField]["camera"]
		FieldRotateTimes := FieldDefault[FollowingField]["turns"]
		FieldDriftCheck := FieldDefault[FollowingField]["drift"]
		return true
	}
	return false
}

; ===== LEADER ANNOUNCEMENT CHECK =====
; Call this after field overrides in nm_GoGather to announce field changes

tadsync_CheckAnnounceField(FieldName) {
	global FieldFollowingCheck, FieldFollowingFollowMode, LastAnnouncedField
	
	if (FieldFollowingCheck && FieldFollowingFollowMode = "Leader" && LastAnnouncedField != FieldName)
		aq_announceField(FieldName)
}

; Press all hotbar items marked as "@ Boosted" and update their timers
aq_pressBoostedKeys(field_type) {
	global HotbarWhile2, HotbarWhile3, HotbarWhile4, HotbarWhile5, HotbarWhile6, HotbarWhile7
	global LastGlitter, LastEnzymes, LastMicroConverter, LastWhirligig

	pressed := false
	loop 6 {
		slot := A_Index + 1
		type := HotbarWhile%slot%
		if (type = "Glitter" || type = "Enzymes" || type = "Microconverter" || type = "Whirligig") {
			Send "{sc00" slot+1 "}"
			Sleep 500
			pressed := true
		}
	}

	if (pressed) {
		LastGlitter := LastEnzymes := LastMicroConverter := LastWhirligig := nowUnix()
		IniWrite LastGlitter, "settings\nm_config.ini", "Boost", "LastGlitter"
		IniWrite LastEnzymes, "settings\nm_config.ini", "Boost", "LastEnzymes"
		IniWrite LastMicroConverter, "settings\nm_config.ini", "Boost", "LastMicroConverter"
		IniWrite LastWhirligig, "settings\nm_config.ini", "Boost", "LastWhirligig"
	}
}

; ===== BOOST TRACE LOGGING =====
; Diagnostic-only logging for boosted-field selection behavior.

tadsync_BoostTracePath() {
	return A_ScriptDir "\..\settings\tadsync_boost_trace.log"
}

tadsync_BoostTrace(message) {
	static maxBytes := 1024 * 1024
	logPath := tadsync_BoostTracePath()
	try {
		if FileExist(logPath) && FileGetSize(logPath) > maxBytes
			FileMove(logPath, logPath ".old", 1)
		FileAppend(FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss") " | " message "`n", logPath, "UTF-8")
	}
}

tadsync_LogBoosterDetected(location, detectedField) {
	global RecentFBoost
	tadsync_BoostTrace("booster-detected location=" location " detectedField=" detectedField " recentBefore=" RecentFBoost)
}

tadsync_LogBoostScan(phase, currentField := "", recentBoost := "", selectedField := "") {
	global BoostChaserCheck
	global PineTreeBoosterCheck, BambooBoosterCheck, BlueFlowerBoosterCheck, StumpBoosterCheck
	global CactusBoosterCheck, PumpkinBoosterCheck, PineappleBoosterCheck, SpiderBoosterCheck, CloverBoosterCheck, DandelionBoosterCheck, SunflowerBoosterCheck
	global RoseBoosterCheck, StrawberryBoosterCheck, MushroomBoosterCheck, PepperBoosterCheck
	global CoconutBoosterCheck

	blueBoosterFields := Map("PineTreeBoosterCheck","Pine Tree", "BambooBoosterCheck","Bamboo", "BlueFlowerBoosterCheck","Blue Flower", "StumpBoosterCheck","Stump")
	redBoosterFields := Map("RoseBoosterCheck","Rose", "StrawberryBoosterCheck","Strawberry", "MushroomBoosterCheck","Mushroom", "PepperBoosterCheck","Pepper")
	mountainBoosterFields := Map("CactusBoosterCheck","Cactus", "PumpkinBoosterCheck","Pumpkin", "PineappleBoosterCheck","Pineapple", "SpiderBoosterCheck","Spider", "CloverBoosterCheck","Clover", "DandelionBoosterCheck","Dandelion", "SunflowerBoosterCheck","Sunflower")
	coconutBoosterFields := Map("CoconutBoosterCheck","Coconut")

	msg := "boost-scan phase=" phase " boostChaser=" BoostChaserCheck " current=" currentField " recent=" recentBoost " selected=" selectedField
	for groupName, fieldMap in Map("blue", blueBoosterFields, "mountain", mountainBoosterFields, "red", redBoosterFields, "coconut", coconutBoosterFields) {
		for settingName, fieldName in fieldMap {
			enabled := %settingName%
			detected := 0
			try detected := nm_fieldBoostCheck(fieldName, 1) ? 1 : 0
			msg .= " | " groupName ":" StrReplace(fieldName, " ", "") " enabled=" enabled " detected=" detected
		}
	}
	otherDetected := 0
	try otherDetected := nm_fieldBoostCheck("Mountain Top", 1) ? 1 : 0
	msg .= " | other:MountainTop enabled=1 detected=" otherDetected
	tadsync_BoostTrace(msg)
}
