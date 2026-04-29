nm_includePresets() {
	global presetList
	if !isSet(presetList)
		presetList := []
	if !DirExist(".\settings\presets")
		return
	Loop Files ".\settings\presets\*.ini", "R" {
		SplitPath(A_LoopFileFullPath,,,,&name )
		if !ObjHasValue(presetList, name) {
			presetList.push(name)
			if IsSet(presetGui) && IsObject(presetGui)
				for , v in ["SelectPreset", "PresetTimed1", "PresetTimed2"]
					presetGui[v].Add([name])
		}
	}
}
hideTimed(ctrl,*) {
	global
	For , v in ["PresetInterval", "PresetTimed2", "PresetRepeat", "PresetIntervalEdit"]
		PresetGui[v].enabled:=ctrl.Value
	if PresetRepeat
		PresetGui["PresetTimed1"].Enabled:=ctrl.Value
}
FileNameCleanup(*) {
	global PresetGui
    userInput := PresetGui["SetPresetName"].Value
   	if (RegExMatch(userInput, "[\\/:\*\?<>\|]|[\s.]|^\.+$")) {
    	cleanedFileName := RegExReplace(userInput, "[\\/:\*\?<>\|]|[\s.]|^\.+$", "")
        PresetGui["SetPresetName"].Value := cleanedFileName
        Send "{End}" ;otherwise it sets cursor to the beginning of the text
    }
}
ConfirmWebBot(*) {
    global PresetGui
    if (PresetGui["PresetWebBot"].Value = 1)
        if (MsgBox("Are you sure you would like to enable save Bot token and Webhook? This is very dangerous if shared and could allow people with it to control your computer.`nThis also includes all channel IDs and the user ID for discord.", "Webhook and Token Confirmation", 4)="no")
            PresetGui["PresetWebBot"].Value := 0
}
hideTimer(ctrl,*) =>
      PresetGui[ctrl.name "Timers"].Enabled := ctrl.Value
    . PresetGui[ctrl.name "Timers"].Value := 0
nm_CopyFileToClipboard(filePath) {
	static CF_HDROP := 15
	static GMEM_MOVEABLE := 0x0002
	static GMEM_ZEROINIT := 0x0040
	dropSize := 20
	fileLen := StrPut(filePath, "UTF-16")
	totalSize := dropSize + (fileLen * 2)
	hMem := DllCall("GlobalAlloc", "UInt", GMEM_MOVEABLE | GMEM_ZEROINIT, "UPtr", totalSize, "Ptr")
	if !hMem
		return 0
	pMem := DllCall("GlobalLock", "Ptr", hMem, "Ptr")
	if !pMem {
		DllCall("GlobalFree", "Ptr", hMem)
		return 0
	}
	NumPut("UInt", dropSize, pMem, 0)
	NumPut("Int", 0, pMem, 4)
	NumPut("Int", 0, pMem, 8)
	NumPut("Int", 0, pMem, 12)
	NumPut("Int", 1, pMem, 16)
	StrPut(filePath, pMem + dropSize, "UTF-16")
	DllCall("GlobalUnlock", "Ptr", hMem)
	if !DllCall("OpenClipboard", "Ptr", A_ScriptHwnd) {
		DllCall("GlobalFree", "Ptr", hMem)
		return 0
	}
	DllCall("EmptyClipboard")
	if !DllCall("SetClipboardData", "UInt", CF_HDROP, "Ptr", hMem) {
		DllCall("CloseClipboard")
		DllCall("GlobalFree", "Ptr", hMem)
		return 0
	}
	DllCall("CloseClipboard")
	return 1
}
nm_GetClipboardFilePath() {
	static CF_HDROP := 15
	if !DllCall("OpenClipboard", "Ptr", A_ScriptHwnd)
		return ""
	hDrop := DllCall("GetClipboardData", "UInt", CF_HDROP, "Ptr")
	if !hDrop {
		DllCall("CloseClipboard")
		return ""
	}
	fileCount := DllCall("shell32\DragQueryFileW", "Ptr", hDrop, "UInt", 0xFFFFFFFF, "Ptr", 0, "UInt", 0)
	if (fileCount < 1) {
		DllCall("CloseClipboard")
		return ""
	}
	len := DllCall("shell32\DragQueryFileW", "Ptr", hDrop, "UInt", 0, "Ptr", 0, "UInt", 0)
	buf := Buffer((len + 1) * 2, 0)
	DllCall("shell32\DragQueryFileW", "Ptr", hDrop, "UInt", 0, "Ptr", buf.Ptr, "UInt", len + 1)
	DllCall("CloseClipboard")
	return StrGet(buf, "UTF-16")
}
nm_createPresetFiles(presetName, targetDir := ".\settings\presets", *) {
	static KillSettings := [
		"TunnelBearCheck", "TunnelBearBabyCheck", "StumpSnailCheck",
		"StingerSpiderCheck", "StingerRoseCheck", "StingerPepperCheck",
		"StingerMountainTopCheck", "StingerDailyBonusCheck", "StingerCloverCheck",
		"StingerCheck", "StingerCactusCheck", "SnailTime", "ShellAmuletMode",
		"MonsterRespawnTime", "MondoLootDirection", "KingBeetleCheck",
		"KingBeetleBabyCheck", "KingBeetleAmuletMode", "InputSnailHealth",
		"InputChickHealth", "CommandoCheck", "CocoCrabCheck",
		"ChickTime", "ChickLevel", "BugrunWerewolfLoot", "BugrunWerewolfCheck",
		"BugrunSpiderLoot", "BugrunSpiderCheck", "BugrunScorpionsLoot",
		"BugrunScorpionsCheck", "BugrunRhinoBeetlesLoot", "BugrunRhinoBeetlesCheck",
		"BugrunMantisLoot", "BugrunMantisCheck", "BugrunLadybugsLoot",
		"BugrunLadybugsCheck", "BugrunInterruptCheck"
	]
	, KillTimers := [
		"VBLastKilled", "LastBugrunLadybugs", "LastBugrunMantis",
		"LastBugrunRhinoBeetles", "LastBugrunScorpions", "LastBugrunSpider",
		"LastBugrunWerewolf", "LastCommando", "LastKingBeetle",
		"LastStumpSnail", "LastTunnelBear", "NightLastDetected",
		"LastCocoCrab"
	]
	, MiscSettings := [
		"TimersHotkey", "StopHotkey", "StartHotkey",
		"PauseHotkey", "AutoClickerHotkey", "ClickCount",
		"ClickDelay", "ClickDuration", "ClickMode",
	]
	, PrivateServerSettings := [
		"FallbackServer1", "FallbackServer2", "FallbackServer3",
		"PrivServer"
	]
	, CollectTimers := [
		"LastAntPass", "LastBlueBoost",
		"LastBugrunLadybugs", "LastCandles", "LastCocoCrab",
		"LastCommando", "LastExtremeMemoryMatch", "LastFeast",
		"LastGingerbread", "LastGlueDis", "LastGummyBeacon",
		"LastHoneyDis", "LastHoneystorm", "LastKingBeetle",
		"LastLidArt", "LastMegaMemoryMatch", "LastMeteorShower",
		"LastMondoBuff", "LastMountainBoost", "LastNightMemoryMatch",
		"LastRBPDelevel", "LastRedBoost", "LastRoboPass",
		"LastRoyalJellyDis", "LastSamovar", "LastSnowMachine",
		"LastStickerPrinter", "LastStockings", "LastStrawberryDis",
		"LastTreatDis", "LastTunnelBear", "LastWreath"
	]
	, BoostTimers := ["AFBdiceUsed", "AFBglitterUsed", "FieldLastBoosted",
		"FieldLastBoostedBy", "FieldNextBoostedBy", "LastEnzymes",
		"LastGlitter", "LastGuid", "LastHotkey2",
		"LastHotkey3", "LastHotkey4", "LastHotkey5",
		"LastHotkey6", "LastHotkey7", "LastMicroConverter",
		"LastStickerStack", "LastWhirligig"
	]
	, WebBotSettings := [
		"BotToken", "Webhook", "MainChannelID",
		"ReportChannelID", "discordUID", "commandPrefix",
		"WebhookEasterEgg", "DiscordCheck", "DiscordMode",
		"NightAnnouncementCheck", "NightAnnouncementName",
		"NightAnnouncementPingID", "NightAnnouncementWebhook"
	]
	, GatherSettings := [
		"FieldName1", "FieldName2", "FieldName3",
		"FieldDriftCheck1", "FieldDriftCheck2", "FieldDriftCheck3",
		"FieldPattern1", "FieldPattern2", "FieldPattern3",
		"FieldPatternSize1", "FieldPatternSize2", "FieldPatternSize3",
		"FieldPatternReps1", "FieldPatternReps2", "FieldPatternReps3",
		"FieldPatternShift1", "FieldPatternShift2", "FieldPatternShift3",
		"FieldPatternInvertFB1", "FieldPatternInvertFB2", "FieldPatternInvertFB3",
		"FieldPatternInvertLR1", "FieldPatternInvertLR2", "FieldPatternInvertLR3",
		"FieldRotateDirection1", "FieldRotateDirection2", "FieldRotateDirection3",
		"FieldRotateTimes1", "FieldRotateTimes2", "FieldRotateTimes3",
		"FieldUntilMins1", "FieldUntilMins2", "FieldUntilMins3",
		"FieldUntilPack1", "FieldUntilPack2", "FieldUntilPack3",
		"FieldReturnType1", "FieldReturnType2", "FieldReturnType3",
		"FieldSprinklerLoc1", "FieldSprinklerLoc2", "FieldSprinklerLoc3",
		"FieldSprinklerDist1", "FieldSprinklerDist2", "FieldSprinklerDist3",
		"CurrentFieldNum"
	]
	, QuestSettings := [
		"BlackQuestCheck", "BlackQuestProgress", "BrownQuestCheck",
		"BrownQuestProgress", "BuckoQuestCheck", "BuckoQuestGatherInterruptCheck",
		"BuckoQuestProgress", "HoneyQuestCheck", "HoneyQuestProgress",
		"LastBlackQuest", "LastBrownQuest", "PolarQuestCheck",
		"PolarQuestGatherInterruptCheck", "PolarQuestProgress", "QuestBoostCheck",
		"QuestGatherMins", "QuestGatherReturnBy", "RileyQuestCheck",
		"RileyQuestGatherInterruptCheck", "RileyQuestProgress"
	]
	, SettingsSettings := [
		"AlwaysOnTop", "AnnounceGuidingStar",
		"BuffDetectReset", "ConvertBalloon",
		"ConvertDelay", "ConvertMins", "DisableToolUse",
		"FDCWarn", "GatherDoubleReset", "GuiTheme",
		"GuiTransparency", "GuiX", "GuiY",
		"HiveBees", "HiveSlot", "IgnoreUpdateVersion",
		"KeyDelay", "LastConvertBalloon", "MoveMethod",
		"MoveSpeedNum", "MultiReset", "NewWalk",
		"PublicFallback", "ReconnectHour", "ReconnectInterval",
		"ReconnectMessage", "ReconnectMethod", "ReconnectMin",
		"ShowOnPause", "SprinklerType", "PriorityListNumeric"
	]
	, ExtensionsSettings := [
		"FollowingLeader", "FollowingField", "FollowingStartTime",
		"LastAnnouncedField", "FieldFollowingCheck", "FieldFollowingFollowMode",
		"FieldFollowingMaxTime", "FieldFollowingChannelID", "PFieldBoosted",
		"EnzymesBoostedOnly", "PreGlitterCheck", "MondoInterruptCheck",
		"ReconnectSyncCheck", "ReconnectSyncMode", "ReconnectSyncChannelID"
	]
	, DiscordSettings := [
		"AmuletSSCheck", "BalloonSSCheck", "CriticalErrorPingCheck",
		"CriticalSSCheck", "DeathSSCheck", "DisconnectPingCheck",
		"DiscordCheck", "EmergencyBalloonPingCheck", "GameFrozenPingCheck",
		"HoneySSCheck", "HoneyUpdateSSCheck", "MachineSSCheck",
		"PhantomPingCheck", "PlanterSSCheck", "UnexpectedDeathPingCheck",
		"ViciousSSCheck", "criticalCheck", "ssCheck",
		"ssDebugging"
	]
	, BoostSettings := [
		"AFBDiceEnable", "AFBDiceHotbar", "AFBDiceLimit",
		"AFBDiceLimitEnable", "AFBFieldEnable", "AFBGlitterEnable",
		"AFBGlitterHotbar", "AFBGlitterLimit", "AFBGlitterLimitEnable",
		"AFBHoursLimit", "AFBHoursLimitEnable", "AFBdiceUsed",
		"AFBglitterUsed", "AutoFieldBoostActive", "AutoFieldBoostRefresh",
		"BambooBoosterCheck", "BlueFlowerBoosterCheck", "BoostChaserCheck",
		"CactusBoosterCheck", "CloverBoosterCheck", "CoconutBoosterCheck",
		"DandelionBoosterCheck", "FieldBoostStacks", "FieldBooster1",
		"FieldBooster2", "FieldBooster3", "FieldBoosterMins", "HotbarMax2",
		"HotbarMax3", "HotbarMax4", "HotbarMax5", "HotbarMax6",
		"HotbarMax7", "HotbarTime2", "HotbarTime3", "HotbarTime4",
		"HotbarTime5", "HotbarTime6", "HotbarTime7", "HotbarWhile2",
		"HotbarWhile3", "HotbarWhile4", "HotbarWhile5", "HotbarWhile6",
		"HotbarWhile7", "MushroomBoosterCheck", "PineTreeBoosterCheck",
		"PineappleBoosterCheck", "PumpkinBoosterCheck", "RoseBoosterCheck",
		"SpiderBoosterCheck", "StickerStackCheck", "StickerStackCub",
		"StickerStackHive", "StickerStackItem", "StickerStackMode",
		"StickerStackTimer", "StrawberryBoosterCheck", "SunflowerBoosterCheck"
	]
	, CollectSettings := [
		"AntPassAction", "AntPassBuyCheck", "BeesmasGatherInterruptCheck",
		"BlueExtractMatchIgnore", "BlueberryDisCheck", "CandlesCheck",
		"ClockCheck", "CloudVialMatchIgnore",
		"CoconutDisCheck", "CyanTrimMatchIgnore", "DiamondEggMatchIgnore",
		"EnzymeMatchIgnore", "ExtremeMemoryMatchCheck", "FeastCheck",
		"FieldDiceMatchIgnore", "GingerbreadCheck", "GlitterMatchIgnore",
		"GlueDisCheck", "GoldEggMatchIgnore", "GumdropMatchIgnore",
		"HardWaxMatchIgnore", "HoneyDisCheck", "HoneystormCheck",
		"JellyBeanMatchIgnore",
		"LidArtCheck", "MagicBeanMatchIgnore", "MegaMemoryMatchCheck",
		"MeteorShowerCheck", "MicroConverterMatchIgnore", "MondoAction",
		"MondoSecs", "MoonCharmMatchIgnore", "NeonberryMatchIgnore",
		"NightBellMatchIgnore", "NightLastDetected", "NightMemoryMatchCheck",
		"NormalMemoryMatchCheck", "OilMatchIgnore", "PineappleMatchIgnore",
		"RBPDelevelCheck", "RedExtractMatchIgnore", "RoboPassCheck",
		"RoyalJellyDisCheck", "RoyalJellyMatchIgnore", "SamovarCheck",
		"SilverEggMatchIgnore", "SmoothDiceMatchIgnore", "SoftWaxMatchIgnore",
		"StarJellyMatchIgnore",
		"StingerMatchIgnore", "StockingsCheck", "StrawberryDisCheck",
		"StrawberryMatchIgnore", "SunflowerSeedMatchIgnore",
		"SuperSmoothieMatchIgnore", "SwirledWaxMatchIgnore", "TicketMatchIgnore",
		"TreatDisCheck", "TreatMatchIgnore", "TropicalDrinkMatchIgnore",
		"WinterMemoryMatchCheck", "WreathCheck", "PrinterItem1", "PrinterItem2",
		"PrinterAmount1","PrinterAmount2", "PrinterTimer1", "PrinterTimer2"
	]
	, PresetSettingsCtrls := [
		"Gather", "Quest", "Settings",
		"Extensions", "Discord", "Misc", "PrivateServer",
		"WebBot", "Boost", "BoostTimers",
		"Collect", "CollectTimers", "Kill",
		"KillTimers", "Planters", "PlantersTimers"
	]
	, PlantersSettings := [
		"AutomaticHarvestInterval", "ConvertFullBagHarvest", "GatherFieldSipping",
		"GatherPlanterLoot", "HarvestFullGrown", "HarvestInterval",
		"MaxAllowedPlanters", "PlanterMode", "TimerGuiTransparency",
		"TimerX", "TimerY", "n1minPercent",
		"n1priority", "n2minPercent", "n2priority",
		"n3minPercent", "n3priority", "n4minPercent",
		"n4priority", "n5minPercent", "n5priority",
		"nPreset", "GotoPlanterField", "TimersOpen",
		"MConvertFullBagHarvest", "MPlanterGather1", "MPlanterGather2",
		"MPlanterGather3", "MPlanterGatherA", "MPuffMode1",
		"MPuffMode2", "MPuffMode3", "MPuffModeA",
		"PlanterGlitter1", "PlanterGlitter2", "PlanterGlitter3",
		"PlanterGlitterC1", "PlanterGlitterC2", "PlanterGlitterC3",
		"PlanterHarvestFull1", "PlanterHarvestFull2", "PlanterHarvestFull3",
		"PlanterManualCycle1", "PlanterManualCycle2", "PlanterManualCycle3",
		"BambooFieldCheck", "BlueFlowerFieldCheck", "CactusFieldCheck",
		"CloverFieldCheck", "CoconutFieldCheck", "DandelionFieldCheck",
		"MountainTopFieldCheck", "MushroomFieldCheck", "PepperFieldCheck",
		"PineTreeFieldCheck", "PineappleFieldCheck", "PumpkinFieldCheck",
		"RoseFieldCheck", "SpiderFieldCheck", "StrawberryFieldCheck",
		"StumpFieldCheck", "SunflowerFieldCheck",
		"BlueClayPlanterCheck", "CandyPlanterCheck", "HeatTreatedPlanterCheck",
		"HydroponicPlanterCheck", "PaperPlanterCheck", "PesticidePlanterCheck",
		"PetalPlanterCheck", "PlanterOfPlentyCheck", "PlasticPlanterCheck",
		"RedClayPlanterCheck", "TackyPlanterCheck", "TicketPlanterCheck"
	]
	, PlantersTimers := [
		"LastComfortingField", "LastInvigoratingField", "LastMotivatingField",
		"LastRefreshingField", "LastSatisfyingField", "LastPlanterGatherSlot",
		"MPlanterHold1", "MPlanterHold2", "MPlanterHold3",
		"MPlanterSmoking1", "MPlanterSmoking2", "MPlanterSmoking3",
		"PlanterEstPercent1", "PlanterEstPercent2", "PlanterEstPercent3",
		"PlanterField1", "PlanterField2", "PlanterField3",
		"PlanterHarvestFull1", "PlanterHarvestFull2", "PlanterHarvestFull3",
		"PlanterHarvestNow1", "PlanterHarvestNow2", "PlanterHarvestNow3",
		"PlanterHarvestTime1", "PlanterHarvestTime2", "PlanterHarvestTime3",
		"PlanterName1", "PlanterName2", "PlanterName3",
		"PlanterNectar1", "PlanterNectar2", "PlanterNectar3",
		"PlanterSS1", "PlanterSS2", "PlanterSS3",
		"dayOrNight"
	]
	f := FileOpen('./settings/nm_config.ini', 'r'), config := f.Read(), f.Close()
	configObj := configToObject(config)
	(presetObj := Map()).CaseSense := 0
	for k in PresetSettingsCtrls {
		if !PresetGui["Preset" k].value
			continue
		section := (k = "Gather" ? k
			: k = "Quest" ? "Quests"
			: k = "Settings" ? k
			: k = "Extensions" ? k
			: k = "Discord" ? "Status"
			: k = "Misc" ? "Settings"
			: k = "PrivateServer" ? "Settings"
			: k = "WebBot" ? "Status"
			: k = "Boost" ? k
			: k = "BoostTimers" ? "Boost"
			: k = "Collect" ? k
			: k = "CollectTimers" ? "Collect"
			: k = "Kill" ? "Collect"
			: k = "KillTimers" ? "Collect"
			: k = "Planters" ? k
			: k = "PlantersTimers" ? "Planters"
			: unset)
		if !configObj.Has(section)
			continue
		if !presetObj.Has(section)
		(presetObj[section] := Map()).CaseSense := 0
		if k = "KillTimers" or k = "PlantersTimers" or k = "BoostTimers" or k = "CollectTimers" {
			for v in %k% {
				if !configObj.Has(section) || !configObj[section].Has(v)
					continue
				presetObj[section][v] := configObj[section][v]
			}
		}
		else {
			for v in %k%Settings {
				if !configObj.Has(section) || !configObj[section].Has(v)
					continue
				presetObj[section][v] := configObj[section][v]
			}
		}
	}
	if presetGui["presetPlanters"].value {
		f := FileOpen("./settings/manual_planters.ini", "r"), planter := configToObject(f.Read()), f.Close()

		for k, v in planter
			presetObj.Set(k, v)
	}
	if presetGui["presetFDefaults"].value {
		f := FileOpen("./settings/Field_config.ini", "r"), fields := configToObject(f.Read()), f.Close()
		for k, v in fields
			presetObj.Set(k, v)

	}
	if !DirExist(targetDir)
		DirCreate(targetDir)
	f := FileOpen(targetDir "\" presetName ".ini", "w"), f.Write(objectToIni(presetObj)), f.Close()
	return targetDir "\" presetName ".ini"
}
configToObject(iniStr) {
	returnObj := Map()
	loop parse iniStr, "`n", "`r" {
		if !A_LoopField || SubStr(A_LoopField, 1, 1) = ";"
			continue
		if SubStr(A_LoopField, 1, 1) = "[" {
			section := SubStr(A_LoopField, 2, -1), (returnObj[section] := Map()).CaseSense := 0
			continue
		}
		eqPos := InStr(A_LoopField, "=")
		returnObj[section][SubStr(A_LoopField, 1, eqPos - 1)] := SubStr(A_LoopField, eqPos + 1)
	}
	return returnObj
}

objectToIni(object) {
	static crlf := "`r`n"
	for k,v in object {
		iniStr .= "[" k "]" crlf
		for i,j in v
			iniStr .= i "=" j crlf
	}
	return iniStr
}

nm_ShowPresetDialog(mode, initialDir, title, defaultName := "") {
	static OFN_EXPLORER := 0x00080000
	static OFN_FILEMUSTEXIST := 0x00001000
	static OFN_PATHMUSTEXIST := 0x00000800
	static OFN_OVERWRITEPROMPT := 0x00000002
	static OFN_NOCHANGEDIR := 0x00000008

	filter := "INI Files (*.ini)" Chr(0) "*.ini" Chr(0) "All Files (*.*)" Chr(0) "*.*" Chr(0) Chr(0)
	filterBuf := Buffer(StrPut(filter, "UTF-16") * 2, 0)
	StrPut(filter, filterBuf, "UTF-16")

	fileBuf := Buffer(4096 * 2, 0)
	if (mode = "save" && defaultName != "")
		StrPut(defaultName, fileBuf, "UTF-16")

	flags := OFN_EXPLORER | OFN_PATHMUSTEXIST | OFN_NOCHANGEDIR
	if (mode = "save")
		flags |= OFN_OVERWRITEPROMPT
	else
		flags |= OFN_FILEMUSTEXIST

	ownerHwnd := (IsSet(PresetGui) && IsObject(PresetGui)) ? PresetGui.Hwnd : 0
	ofnSize := (A_PtrSize = 8) ? 152 : 88
	ofn := Buffer(ofnSize, 0)

	if (A_PtrSize = 8) {
		NumPut("UInt", ofnSize, ofn, 0)
		NumPut("Ptr", ownerHwnd, ofn, 8)
		NumPut("Ptr", 0, ofn, 16)
		NumPut("Ptr", filterBuf.Ptr, ofn, 24)
		NumPut("Ptr", 0, ofn, 32)
		NumPut("UInt", 0, ofn, 40)
		NumPut("UInt", 1, ofn, 44)
		NumPut("Ptr", fileBuf.Ptr, ofn, 48)
		NumPut("UInt", fileBuf.Size // 2, ofn, 56)
		NumPut("Ptr", 0, ofn, 64)
		NumPut("UInt", 0, ofn, 72)
		NumPut("Ptr", StrPtr(initialDir), ofn, 80)
		NumPut("Ptr", StrPtr(title), ofn, 88)
		NumPut("UInt", flags, ofn, 96)
		NumPut("UShort", 0, ofn, 100)
		NumPut("UShort", 0, ofn, 102)
		NumPut("Ptr", 0, ofn, 104)
		NumPut("Ptr", 0, ofn, 112)
		NumPut("Ptr", 0, ofn, 120)
		NumPut("Ptr", 0, ofn, 128)
		NumPut("Ptr", 0, ofn, 136)
		NumPut("UInt", 0, ofn, 144)
		NumPut("UInt", 0, ofn, 148)
	} else {
		NumPut("UInt", ofnSize, ofn, 0)
		NumPut("Ptr", ownerHwnd, ofn, 4)
		NumPut("Ptr", 0, ofn, 8)
		NumPut("Ptr", filterBuf.Ptr, ofn, 12)
		NumPut("Ptr", 0, ofn, 16)
		NumPut("UInt", 0, ofn, 20)
		NumPut("UInt", 1, ofn, 24)
		NumPut("Ptr", fileBuf.Ptr, ofn, 28)
		NumPut("UInt", fileBuf.Size // 2, ofn, 32)
		NumPut("Ptr", 0, ofn, 36)
		NumPut("UInt", 0, ofn, 40)
		NumPut("Ptr", StrPtr(initialDir), ofn, 44)
		NumPut("Ptr", StrPtr(title), ofn, 48)
		NumPut("UInt", flags, ofn, 52)
		NumPut("UShort", 0, ofn, 56)
		NumPut("UShort", 0, ofn, 58)
		NumPut("Ptr", 0, ofn, 60)
		NumPut("Ptr", 0, ofn, 64)
		NumPut("Ptr", 0, ofn, 68)
		NumPut("Ptr", 0, ofn, 72)
		NumPut("Ptr", 0, ofn, 76)
		NumPut("UInt", 0, ofn, 80)
		NumPut("UInt", 0, ofn, 84)
	}

	ok := (mode = "save")
		? DllCall("comdlg32\GetSaveFileNameW", "ptr", ofn.Ptr, "int")
		: DllCall("comdlg32\GetOpenFileNameW", "ptr", ofn.Ptr, "int")
	return ok ? StrGet(fileBuf, "UTF-16") : ""
}

nm_CreatePreset(*) {
	global PresetGui, SelectPreset
	PresetName := PresetGui["SetPresetName"].Value
	PresetPath := '.\settings\presets\' PresetName '.ini'
	if (!PresetName)
		return MsgBox("No preset name given.",, "0x1010 T5")
	if (FileExist(".\settings\presets\" PresetName ".ini")) {
		if (MsgBox("Preset " PresetName " already exists. Do you want to overwrite " PresetName "?",, "0x1034") = "no")
			return
		FileDelete(PresetPath)
	}
	nm_createPresetFiles(PresetName)
	nm_includePresets()
	PresetGui["SetPresetName"].Value := ""
	if PresetGui["SelectPreset"].Enabled := !!presetList.length
		PresetGui["SelectPreset"].Text := PresetName
		, SelectPreset := PresetName
		, IniWrite(PresetName, ".\settings\nm_config.ini", "Settings", "SelectPreset")
		, PresetGui["OverwritePreset"].Enabled := 1
		, PresetGui["DeletePreset"].Enabled := 1
		, PresetGui["CopyPreset"].Enabled := 1
		, PresetGui["LoadPreset"].Enabled := 1
		, PresetGui["RenamePreset"].Enabled := 1
		, PresetGui["PresetTimedEnable"].Enabled := 1
	else
		PresetGui["OverwritePreset"].Enabled := 0
		, PresetGui["DeletePreset"].Enabled := 0
		, PresetGui["CopyPreset"].Enabled := 0
		, PresetGui["LoadPreset"].Enabled := 0
		, PresetGui["RenamePreset"].Enabled := 0
		, PresetGui["PresetTimed1"].Enabled := 0
		, PresetGui["PresetTimed2"].Enabled := 0
		, PresetGui["PresetInterval"].Enabled := 0
		, PresetGui["PresetIntervalEdit"].Enabled := 0
		, PresetGui["PresetRepeat"].Enabled := 0
		, PresetGui["PresetTimedEnable"].Enabled := 0
		, PresetGui["PresetTimedEnable"].Value := 0
}

nm_ManagePreset(ctrl,* ) {
	global PresetGui, SelectPreset, PresetTimed1, PresetTimed2
	PresetName := PresetGui["SelectPreset"].Text
	PresetPath := '.\settings\presets\' PresetName '.ini'
	if (!FileExist(PresetPath))
		return MsgBox("Preset '" PresetName "' does not exist.",, "0x1010 T5")
	Switch ctrl.name, 0 {
		case "CopyPreset":
			sourcePath := A_WorkingDir "\settings\presets\" PresetName ".ini"
			if !nm_CopyFileToClipboard(sourcePath)
				return MsgBox("Failed to copy preset file to clipboard.", "Preset", 0x1010)
			MsgBox("Preset " PresetName " copied to clipboard as a file.", "Preset", 0x1040)
		case "RenamePreset":
			NewName := PresetGui["SetPresetName"].Value
			if (!NewName)
				return MsgBox("No preset name given.",, "0x1010 T5")
			FileMove(PresetPath, '.\settings\presets\' NewName '.ini', 1)
			presetList[PresetGui["SelectPreset"].Value] := NewName
			for , v in ["PresetTimed1", "PresetTimed2", "SelectPreset"]
				PresetGui[v].delete(PresetGui["SelectPreset"].value), presetGui[v].Add([NewName])
			PresetGui["SelectPreset"].Text := NewName, SelectPreset := NewName
			IniWrite(NewName, ".\settings\nm_config.ini", "Settings", "SelectPreset")
		case "DeletePreset":
			if (MsgBox("Are you sure you want to delete " PresetName "?",, "0x1034") = "no")
				return
			FileDelete(PresetPath)
			presetList.RemoveAt(PresetGui["SelectPreset"].Value)
			for , v in ["PresetTimed1", "PresetTimed2", "SelectPreset"]
				PresetGui[v].delete(PresetGui["SelectPreset"].Value)
			if (PresetGui["SelectPreset"].enabled := presetList.length)
				PresetGui["SelectPreset"].Value := 1
			else PresetGui["OverwritePreset"].Enabled := 0, PresetGui["DeletePreset"].Enabled := 0, PresetGui["CopyPreset"].Enabled := 0, PresetGui["LoadPreset"].Enabled := 0, PresetGui["RenamePreset"].Enabled := 0, PresetGui["PresetTimed1"].Enabled := 0, PresetGui["PresetTimed2"].Enabled := 0, PresetGui["PresetInterval"].Enabled := 0, PresetGui["PresetIntervalEdit"].Enabled := 0, PresetGui["PresetRepeat"].Enabled := 0, PresetGui["PresetTimedEnable"].Enabled := 0, PresetGui["PresetTimedEnable"].Value := 0
			if PresetTimed1 = SelectPreset
				PresetTimed1 := "", IniWrite(PresetTimed1, ".\settings\nm_config.ini", "Settings", "PresetTimed1")
			if PresetTimed2 = SelectPreset
				PresetTimed2 := "", IniWrite(PresetTimed2, ".\settings\nm_config.ini", "Settings", "PresetTimed2")
			SelectPreset := PresetGui["SelectPreset"].Text
			IniWrite(SelectPreset, ".\settings\nm_config.ini", "Settings", "SelectPreset")
		case "OverwritePreset":
			if Msgbox(
				(
					'Are you sure you want to overwrite ' PresetName '?
					Current settings will be lost.'
				),,0x1034 ) = "no"
					return
			FileDelete(PresetPath)
			nm_createPresetFiles(PresetName)
		case "LoadPreset":
			if Msgbox(
			(
				'Are you sure you want to load ' PresetName '?
				Current settings will be lost.'
			),,0x1034 ) = "no"
				return
			nm_LockTabs()
			PresetGui.Destroy()
			nm_LoadPreset(PresetName)
			nm_LockTabs(0)
	}
}

nm_loadPreset(presetName, * ) {
	global
	local f, preset, config, planters, fields, k,v, i, j
	if !FileExist('.\settings\presets\' presetName '.ini')
		return !MsgBox("Preset appears to be missing: " presetName,"ERROR","0x1010 T10")
	hCursor := DllCall("LoadCursor", "ptr", 0, "int", 0x7F02, "Ptr")
	DllCall("SetCursor", "Ptr", hCursor)
	f := FileOpen('.\settings\presets\' presetName '.ini', "r"), preset := configToObject(f.Read()), f.Close()
	f := FileOpen('.\settings\nm_config.ini', "r"), config := configToObject(f.Read()), f.Close()
	preset.has('General') && (f := FileOpen('.\settings\manual_planters.ini', "r")) && (planters := configToObject(f.Read())) && f.Close()
	preset.Has('Bamboo') &&	(f := FileOpen('.\settings\Field_Config.ini', "r")) && (fields := configToObject(f.Read())) && f.Close()
	for k,v in preset {
		switch k,0 {
			case "Gather", "Boost", "Quests", "Collect", "Planters", "Status", "Settings":
				for i,j in v {
					config[k][i] := j
					%i% := j
					try nm_updateGuiVar(i)
				}
			case "Extensions":
				for i,j in v {
					config[k][i] := j
					%i% := j
					try nm_updateGuiVar(i)
				}
			case "general", "Slot 1", "Slot 2", "Slot 3":
				for i,j in v
					planters[k][i] := j
			default:
				for i,j in v
					fields[k][i] := j
		}
	}
	f := FileOpen('.\settings\nm_config.ini', "w"), f.Write(objectToIni(config)), f.Close()
	preset.Has('General') && (f := FileOpen('.\settings\manual_planters.ini', "w")) && f.Write(objectToIni(planters)) && f.Close()
	preset.Has('Bamboo') && (f := FileOpen('.\settings\Field_Config.ini', "w")) && f.Write(objectToIni(fields)) && f.Close()
	return 1
}

nm_ImportPreset(*) {
	presetFile := nm_GetClipboardFilePath()
	if (presetFile = "")
		return MsgBox("Clipboard does not contain a preset file.",,0x1010)
	SplitPath(presetFile, &fileName, , &ext, &fileNameNoExt)
	if (ext != "ini")
		return MsgBox("Clipboard does not contain a valid .ini preset file.",,0x1010)
	importDir := A_WorkingDir "\settings\presets"
	if !DirExist(importDir)
		DirCreate(importDir)
	destPath := importDir "\" fileName
	if FileExist(destPath) {
		if (MsgBox("Preset " fileNameNoExt " already exists. Overwrite it?",, "0x1034") = "no")
			return
	}
	FileCopy(presetFile, destPath, 1)
	nm_includePresets()
	nm_PresetGuiSyncLists()
	if PresetGui["SelectPreset"].Enabled := !!presetList.length
		PresetGui["SelectPreset"].Text := fileNameNoExt
		, SelectPreset := fileNameNoExt
		, IniWrite(fileNameNoExt, ".\settings\nm_config.ini", "Settings", "SelectPreset")
		, PresetGui["OverwritePreset"].Enabled := 1
		, PresetGui["DeletePreset"].Enabled := 1
		, PresetGui["CopyPreset"].Enabled := 1
		, PresetGui["LoadPreset"].Enabled := 1
		, PresetGui["RenamePreset"].Enabled := 1
		, PresetGui["PresetTimedEnable"].Enabled := 1
	else
		PresetGui["OverwritePreset"].Enabled := 0
		, PresetGui["DeletePreset"].Enabled := 0
		, PresetGui["CopyPreset"].Enabled := 0
		, PresetGui["LoadPreset"].Enabled := 0
		, PresetGui["RenamePreset"].Enabled := 0
		, PresetGui["PresetTimed1"].Enabled := 0
		, PresetGui["PresetTimed2"].Enabled := 0
		, PresetGui["PresetInterval"].Enabled := 0
		, PresetGui["PresetIntervalEdit"].Enabled := 0
		, PresetGui["PresetRepeat"].Enabled := 0
		, PresetGui["PresetTimedEnable"].Enabled := 0
		, PresetGui["PresetTimedEnable"].Value := 0
	MsgBox("Preset imported:`n" fileNameNoExt)
	return !!presetList.length
}

nm_PresetGUI(*){
	global
	local GuiCtrl
	nm_includePresets()
	if IsSet(PresetGui) && IsObject(PresetGui)
		PresetGui.Destroy()
	MainGui.GetPos(&gx, &gy, &gw, &gh)
	PresetGui:=Gui("-MinimizeBox +Owner" MainGui.Hwnd, "Preset Settings")
	PresetGui.Show("x" gx+80 " y" gy+35 " w306 h244")
	PresetGui.SetFont("s9", "Segoe UI")
	PresetGui.Add("GroupBox", "x4 y2 w100 h120", "Creation")
	(GuiCtrl := PresetGui.Add("Edit", "x9 y20 w90 h21 vSetPresetName Limit15")).OnEvent("Change", FileNameCleanup)
    SendMessage 0x1501, 1, StrPtr("Name"), GuiCtrl ; EM_SETCUEBANNER
	PresetGui.Add("Button", "x9 y45 w90 h21 vCreatePreset", "Create New").OnEvent("Click", nm_CreatePreset)
	PresetGui.Add("Button", "x9 y70 w90 h21 vImportPreset", "Import").OnEvent("Click", nm_ImportPreset)
	PresetGui.Add("Button", "x9 y95 w75 h21 vRenamePreset", "Rename").OnEvent("Click", nm_ManagePreset)
	PresetGui.Add("Button", "x88 y98 w10 h15", "?").OnEvent("Click", (*) => MsgBox("Select a preset under the Manage settings, and fill out a new name in the editbox under Creation settings, Then click Rename and your preset will be re-named.", "Help","0x1040"))
	PresetGui.Add("GroupBox", "x108 y2 w100 h120", "Manage")
	(GuiCtrl := PresetGui.Add("DropDownList", "x113 y20 w90 vSelectPreset", presetlist)).Section := "Settings", GuiCtrl.Text := SelectPreset, GuiCtrl.OnEvent("Change", nm_saveConfig)
	PresetGui.Add("Button", "x113 y45 w45 h20 vOverwritePreset", "Save").OnEvent("Click", nm_ManagePreset)
	PresetGui.Add("Button", "x158 yp w45 hp vDeletePreset", "Delete").OnEvent("Click", nm_ManagePreset)
	PresetGui.Add("Button", "x113 yp+25 w90 hp vCopyPreset", "Export").OnEvent("Click", nm_ManagePreset)
	PresetGui.Add("Button", "x113 yp+25 wp hp vLoadPreset", "Load Preset").OnEvent("Click", nm_ManagePreset)
	PresetGui.Add("GroupBox", "x212 y2 w100 h120", "Timed")
	(GuiCtrl := PresetGui.Add("CheckBox", "x217 y16 w55 h16 vPresetTimedEnable", "Enable")).Section := "Settings", GuiCtrl.Value := PresetTimedEnable, GuiCtrl.OnEvent("Click", nm_saveConfig), GuiCtrl.OnEvent("Click", hideTimed)
	(GuiCtrl := PresetGui.Add("DropDownList", "x217 y33 w90 vPresetTimed1", presetlist)).Section := "Settings", GuiCtrl.Text := PresetTimed1, GuiCtrl.OnEvent("Change", nm_saveConfig)
	PresetGui.Add("Text", "x219 y59", "Hours:")
	if !IsNumber(PresetInterval)
		IniWrite(12, ".\settings\nm_config.ini", "Settings", "PresetInterval")
	PresetGui.Add("Edit", "x258 y58 w49 h18 limit3 Number vPresetIntervalEdit").OnEvent("Change", (*)=>nm_saveConfig(PresetGui["PresetInterval"]))
	(GuiCtrl := PresetGui.Add("UpDown", "vPresetInterval range0-999", ValidateNumber(&PresetInterval, 12))).Section := "Settings", GuiCtrl.OnEvent("Change", nm_saveConfig)
	(GuiCtrl := PresetGui.Add("DropDownList", "x217 y79 w90 vPresetTimed2", presetlist)).Section := "Settings", GuiCtrl.Text := PresetTimed2, GuiCtrl.OnEvent("Change", nm_saveConfig)
	(GuiCtrl := PresetGui.Add("CheckBox", "x218 y103 w55 h16 vPresetRepeat", "Repeat")).Section := "Settings", GuiCtrl.Value := PresetRepeat, GuiCtrl.OnEvent("Click", nm_saveConfig), GuiCtrl.OnEvent("Click", (ctrl, *) => PresetGui["PresetTimed1"].Enabled := ctrl.Value)
	if (presetlist.Length=0) {
		For k, v in ["SelectPreset", "CopyPreset", "DeletePreset", "OverwritePreset", "LoadPreset", "RenamePreset", "PresetTimedEnable"]
			PresetGui[v].enabled:=0
		if PresetTimedEnable
			PresetGui["PresetTimedEnable"].Value := 0, IniWrite(0, ".\settings\nm_config.ini", "Settings", "PresetTimedEnable") PresetTimedEnable := 0
	}
	if (!PresetTimedEnable || presetlist.Length=0)
		For , v in ["PresetTimed1", "PresetInterval", "PresetTimed2", "PresetRepeat", "PresetIntervalEdit"]
			PresetGui[v].enabled:=0
	PresetGui.Add("GroupBox", "x4 y126 w308 h112", "Included Settings")
	PresetGui.Add("Button", "x107 y127 w10 h15", "?").OnEvent("Click", (*) => MsgBox("The Included Settings, each checkbox represents a different tab in natro macro to save.`n`nThere are a few exceptions:`nPS Link is your private server Link, Discord is the discord settings (screenshots, pings), Token/Webhook is your Bot Token and Webhook along with all your channel IDs and UserID, Extensions is the extension settings tab, and Field Defaults is your saved gather settings for each field.", "Help", "0x1040"))
	PresetGui.Add("CheckBox", "x9 yp+18 w60 h16 +Checked vPresetGather", "Gather")
	PresetGui.Add("CheckBox", "x9 yp+18 w55 h16 +Checked vPresetQuest", "Quest")
	PresetGui.Add("CheckBox", "x9 yp+18 w60 h16 +Checked vPresetSettings", "Settings")
	PresetGui.Add("CheckBox", "x9 yp+18 w58 h16 vPresetDiscord", "Discord")
	PresetGui.Add("Text", "x72 y144 w1 h67 0x7")
	PresetGui.Add("CheckBox", "x78 y144 w106 h16 +Checked vPresetFDefaults", "Field Defaults")
	PresetGui.Add("CheckBox", "x78 yp+18 w45 h16 +Checked vPresetMisc", "Misc")
	PresetGui.Add("CheckBox", "x78 yp+18 w110 h16 +Checked vPresetExtensions", "Extensions")
	PresetGui.Add("CheckBox", "x78 yp+18 w60 h16 vPresetPrivateServer", "PS Link")
	PresetGui.Add("CheckBox", "x78 yp+18 w106 h16 vPresetWebBot", "Token/Webhook").OnEvent("Click", ConfirmWebBot)
	PresetGui.Add("Text", "x185 y144 w1 h67 0x7")
	PresetGui.Add("CheckBox", "x192 y144 w48 h16 +Checked vPresetBoost", "Boost").OnEvent("Click", hideTimer)
	PresetGui.Add("CheckBox", "x255 yp w55 h16 vPresetBoostTimers", "Timers")
	PresetGui.Add("CheckBox", "x192 yp+18 w57 h16 +Checked vPresetCollect", "Collect").OnEvent("Click", hideTimer)
	PresetGui.Add("CheckBox", "x255 yp w55 h16 vPresetCollectTimers", "Timers")
	PresetGui.Add("CheckBox", "x192 yp+18 w40 h16 +Checked vPresetKill", "Kill").OnEvent("Click", hideTimer)
	PresetGui.Add("CheckBox", "x255 yp w55 h16 vPresetKillTimers", "Timers")
	PresetGui.Add("CheckBox", "x192 yp+18 w59 h16 +Checked vPresetPlanters", "Planters").OnEvent("Click", hideTimer)
	PresetGui.Add("CheckBox", "x255 yp w55 h16 vPresetPlantersTimers", "Timers")
}

nm_preset() {
	global
	local preset
	if (lastPresetChange=0)
		lastPresetChange:=nowUnix(),IniWrite(lastPresetChange, ".\settings\nm_config.ini", "Settings", "lastPresetChange")
	if !PresetTimedEnable || (!PresetRepeat && LastPreset = 1)
		return
	preset := (LastPreset) ? PresetTimed1 : PresetTimed2
	if (nowUnix() - lastPresetChange > (presetInterval || 12) * 3600000) {
		if (preset!="" && (PresetTimed1!=PresetTimed2 && LastPreset))
			nm_loadPreset(preset), nm_setStatus("Preset", "Loaded preset '" preset "'. Changed from preset '" (LastPreset ? PresetTimed2 : PresetTimed1) "'. " presetInterval " hours remaining.")
		else
			nm_setStatus("Preset", "Failed to change presets. " (PresetTimed1=PresetTimed2 ? "Both slots have the same preset." : "No preset given for slot " (LastPreset ? "1" : "2")) ". Skipping preset change." presetInterval " hours remaining.")
		lastPresetChange := nowUnix()
		LastPreset := PresetRepeat * !LastPreset || 1
		IniWrite(LastPreset, ".\settings\nm_config.ini", "Settings", "LastPreset")
		IniWrite(lastPresetChange, ".\settings\nm_config.ini", "Settings", "lastPresetChange")
	}
}

