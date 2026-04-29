/*
TadSync Mondo Alt Hop Extension
Handles jumping to a private server for Mondo Chick and returning.
Made by @definetlynotray on discord
*/

; Declare globals without initialization - let tadsync_AltHopInit set values from INI
global AltHopMondoEnabled
global AltHopMondoLeadTime
global AltHopMondoState := 0
global AltHopMondoLastTime := 0
global MondoHopLootTime            ; configurable loot timeout in seconds (default 45)
global AltHopOriginalPublicFallback := 1
global AltHopOriginalMondoAction := "Buff"
global AltHopOriginalMondoBuffCheck := 0

; AltHopMondoState values:
; 0 = idle
; 1 = doing current/private server Mondo
; 2 = reconnecting to a public server
; 3 = doing public-server Mondo chain
; 4 = reconnecting back to private/home server

tadsync_SaveOriginalSettings() {
    ; Made by @definetlynotray on discord
    global AltHopOriginalPublicFallback, AltHopOriginalMondoAction, AltHopOriginalMondoBuffCheck
    global PublicFallback, MondoAction, MondoBuffCheck
    
    AltHopOriginalPublicFallback := PublicFallback
    AltHopOriginalMondoAction := MondoAction
    AltHopOriginalMondoBuffCheck := MondoBuffCheck
}

tadsync_RestoreOriginalSettings() {
    ; Made by @definetlynotray on discord
    global AltHopOriginalPublicFallback, AltHopOriginalMondoAction, AltHopOriginalMondoBuffCheck
    global PublicFallback, MondoAction, MondoBuffCheck
    
    PublicFallback := AltHopOriginalPublicFallback
    MondoAction := AltHopOriginalMondoAction
    MondoBuffCheck := AltHopOriginalMondoBuffCheck
}

tadsync_SetState(newState) {
    global AltHopMondoState
    AltHopMondoState := newState
    IniWrite AltHopMondoState, "settings\nm_config.ini", "Extensions", "AltHopMondoState"
}

tadsync_LoadMountainTopFieldSettings() {
    global FieldName, FieldPattern, FieldPatternSize, FieldPatternReps, FieldPatternShift
        , FieldPatternInvertFB, FieldPatternInvertLR, FieldUntilMins, FieldUntilPack
        , FieldReturnType, FieldSprinklerLoc, FieldSprinklerDist, FieldRotateDirection
        , FieldRotateTimes, FieldDriftCheck, FieldDefault

    mtField := "Mountain Top"
    if !(IsSet(FieldDefault) && FieldDefault.Has(mtField))
        return 0

    FieldName := mtField
    FieldPattern := FieldDefault[mtField]["pattern"]
    FieldPatternSize := FieldDefault[mtField]["size"]
    FieldPatternReps := FieldDefault[mtField]["width"]
    FieldPatternShift := FieldDefault[mtField]["shiftlock"]
    FieldPatternInvertFB := FieldDefault[mtField]["invertFB"]
    FieldPatternInvertLR := FieldDefault[mtField]["invertLR"]
    FieldUntilMins := FieldDefault[mtField]["gathertime"]
    FieldUntilPack := FieldDefault[mtField]["percent"]
    FieldReturnType := FieldDefault[mtField]["convert"]
    FieldSprinklerLoc := FieldDefault[mtField]["sprinkler"]
    FieldSprinklerDist := FieldDefault[mtField]["distance"]
    FieldRotateDirection := FieldDefault[mtField]["camera"]
    FieldRotateTimes := FieldDefault[mtField]["turns"]
    FieldDriftCheck := FieldDefault[mtField]["drift"]
    return 1
}

tadsync_StartMondoDodge() {
    global FieldPattern, FieldPatternSize, FieldPatternReps, AltHopMondoState
    if (AltHopMondoState = 0)
        return

    if tadsync_LoadMountainTopFieldSettings()
        nm_gather(FieldPattern, 1, FieldPatternSize, FieldPatternReps, 0)
}

tadsync_AltHopInit() {
    global AltHopMondoEnabled, AltHopMondoLeadTime, AltHopMondoState, AltHopMondoLastTime, MondoHopLootTime
    
    ; Initial load from INI (in case macro config hasn't set them yet)
    AltHopMondoEnabled := IniRead("settings\nm_config.ini", "Extensions", "AltHopMondoEnabled", 0)
    AltHopMondoLeadTime := IniRead("settings\nm_config.ini", "Extensions", "AltHopMondoLeadTime", 1.5)
    AltHopMondoState := IniRead("settings\nm_config.ini", "Extensions", "AltHopMondoState", 0)
    AltHopMondoLastTime := IniRead("settings\nm_config.ini", "Extensions", "AltHopMondoLastTime", 0)
    MondoHopLootTime := IniRead("settings\nm_config.ini", "Extensions", "MondoHopLootTime", 45)
    
    ; Ensure directory exists for other potential writes
    if !DirExist("settings")
        DirCreate("settings")
}
tadsync_AltHopInit()

tadsync_GetReconnectOverride(PossibleServers) {
    global AltHopMondoState

    if (AltHopMondoState = 2)
        return 0

    if (AltHopMondoState = 4) {
        if PossibleServers.Has(1)
            return 1
        return (n := ObjMinIndex(PossibleServers)) ? n : 0
    }

    return -1
}

tadsync_OnReconnectSuccess(server) {
    global AltHopMondoState, AltHopMondoLastTime

    switch AltHopMondoState {
        case 2:
            if (server = 0)
                tadsync_SetState(3)
        case 4:
            AltHopMondoLastTime := nowUnix()
            IniWrite AltHopMondoLastTime, "settings\nm_config.ini", "Extensions", "AltHopMondoLastTime"
            tadsync_SetState(0)
    }
}

tadsync_CollectMondoLoot() {
    global MondoLootDirection, DisableToolUse, FwdKey, RightKey, LeftKey, RotLeft, MondoHopLootTime

    if (MondoLootDirection = "Ignore" || MondoHopLootTime = 0)
        return

    if (MondoLootDirection = "Random")
        dir := Random(0, 1)
    else
        dir := (MondoLootDirection = "Right")

    if (dir = 0)
        tc := "left", afc := "right"
    else
        tc := "right", afc := "left"

    nm_setStatus("Looting", "Mondo")
    movement :=
    (
    "send '{" RotLeft "}'
    " nm_Walk(7.5, FwdKey, RightKey) "
    " nm_Walk(7.5, %tc%Key)
    )
    nm_createWalk(movement)
    KeyWait "F14", "D T5 L"
    KeyWait "F14", "T30 L"
    nm_endWalk()

    if !DisableToolUse
        Click "Down"

    DllCall("GetSystemTimeAsFileTime", "int64p", &s := 0)
    n := s, f := s + (Max(1, MondoHopLootTime) * 10000000)
    while ((n < f) && (A_Index <= 24)) {
        nm_loot(16, 5, Mod(A_Index, 2) = 1 ? afc : tc)
        DllCall("GetSystemTimeAsFileTime", "int64p", &n)
    }
    Click "Up"
}

tadsync_AfterMondoAttempt() {
    global AltHopMondoState

    switch AltHopMondoState {
        case 1:
            nm_setStatus("Alt Hop", "Private Mondo finished. Reconnecting to public server...")
            tadsync_SetState(2)
            CloseRoblox()
            DisconnectCheck()
        case 3:
            if (Integer(FormatTime(A_NowUTC, "m")) < 15) {
                nm_setStatus("Alt Hop", "Public Mondo finished. Reconnecting to another public server...")
                tadsync_SetState(2)
            } else {
                nm_setStatus("Alt Hop", "Mondo window ended. Returning to private server...")
                tadsync_RestoreOriginalSettings()
                tadsync_SetState(4)
            }
            CloseRoblox()
            DisconnectCheck()
    }
}

; ========== POPUP GUI ==========
aq_MondoHopGUI(*) {
    global AltHopMondoEnabled, MondoHopLootTime
    
    GuiClose(*) {
        if (IsSet(MondoHopGUI) && IsObject(MondoHopGUI))
            MondoHopGUI.Destroy(), MondoHopGUI := ""
    }
    GuiClose()
    MondoHopGUI := Gui("+AlwaysOnTop +Border", "Mondo Hop")
    MondoHopGUI.OnEvent("Close", GuiClose)
    MondoHopGUI.SetFont("s8 cDefault Bold", "Tahoma")
    MondoHopGUI.Add("GroupBox", "x5 y2 w290 h50", "Settings")
    MondoHopGUI.Add("CheckBox", "x65 y2 vMondoHopEnabled Checked" AltHopMondoEnabled, "Enabled").OnEvent("Click", aq_MondoHopToggle)
    MondoHopGUI.SetFont("Norm")
    MondoHopGUI.Add("Text", "x15 y23", "Loot Time (s):")
    MondoHopGUI.Add("Edit", "x90 y21 w50 h18 Number vMondoHopLootTimeEdit", MondoHopLootTime).OnEvent("Change", aq_MondoHopSaveLootTime)
    MondoHopGUI.Add("Text", "x150 y23", "(0 = no loot)")
    MondoHopGUI.Show("w300 h50")
}

aq_MondoHopToggle(GuiCtrl, *) {
    global AltHopMondoEnabled
    AltHopMondoEnabled := GuiCtrl.Value
    IniWrite AltHopMondoEnabled, "settings\nm_config.ini", "Extensions", "AltHopMondoEnabled"
}

aq_MondoHopSaveLootTime(GuiCtrl, *) {
    global MondoHopLootTime
    if IsNumber(GuiCtrl.Value) {
        MondoHopLootTime := Integer(GuiCtrl.Value)
        IniWrite MondoHopLootTime, "settings\nm_config.ini", "Extensions", "MondoHopLootTime"
    }
}

tadsync_isMondoTime() {
    global AltHopMondoLeadTime, AltHopMondoIsTesting
    
    ; During a test, it's always "Mondo Time"
    if (IsSet(AltHopMondoIsTesting) && AltHopMondoIsTesting)
        return 1
        
    utc_min := Integer(FormatTime(A_NowUTC, "m"))
    utc_sec := Integer(FormatTime(A_NowUTC, "s"))
    
    totalSecs := (utc_min * 60) + utc_sec
    leadSecs := AltHopMondoLeadTime * 60
    
    ; Mondo Time if:
    ; 1. We are in the lead-up (e.g., 58:30 to 59:59)
    ; 2. Or we are inside the spawn window (00:00 to 14:59)
    return (totalSecs >= (3600 - leadSecs)) || (utc_min < 15)
}

tadsync_IsMondoChainWindow() {
    global AltHopMondoIsTesting

    if (IsSet(AltHopMondoIsTesting) && AltHopMondoIsTesting)
        return 1

    return tadsync_isMondoTime() || (Integer(FormatTime(A_NowUTC, "m")) < 15)
}

tadsync_MondoSniper() {
    global AltHopMondoEnabled, AltHopMondoState, AltHopMondoIsTesting
    
    ; If Alt Hop is OFF and not testing, don't sniper
    if (!AltHopMondoEnabled && !AltHopMondoIsTesting)
        return
        
    ; If Roblox is open, don't sniper (let the normal check handle hopping)
    if WinExist("Roblox ahk_exe RobloxPlayerBeta.exe")
        return
        
    ; If we are already in the middle of a hop, don't sniper
    if (AltHopMondoState > 0)
        return

    ; Sniper Loop: Wait until it's Mondo time
    while (!tadsync_isMondoTime() && (AltHopMondoEnabled || AltHopMondoIsTesting)) {
        nm_setStatus("Waiting", "for Mondo spawn window...")
        Sleep 5000
    }
}

; Test button handler - forces a Mondo hop for testing purposes
global AltHopMondoIsTesting := 0

tadsync_AltHop_TestMondo(GuiCtrl, *){
    global AltHopMondoState, AltHopMondoLastTime, AltHopMondoIsTesting
    global PublicFallback, PrivServer, MacroState, MainGui, MondoAction, MondoBuffCheck
    
    if (PrivServer = "") {
        MsgBox("No Private Server set! Alt Hop requires a Private Server link in Settings tab.", "Mondo Test", 0x30)
        return
    }
    
    if (AltHopMondoState > 0) {
        MsgBox("Already in a Mondo hop sequence. State: " AltHopMondoState, "Mondo Test", 0x30)
        return
    }
    
    ; Save original settings and force "Kill" mode
    tadsync_SaveOriginalSettings()
    
    MondoAction := "Kill"
    MondoBuffCheck := 1
    AltHopMondoIsTesting := 1
    
    nm_setStatus("TEST", "Forcing Mondo hop for testing...")
    CloseRoblox()
    Sleep 1000
    
    tadsync_SetState(1)
    AltHopMondoLastTime := nowUnix() + 30 ; Buffer to prevent immediate "killed" detection
    IniWrite AltHopMondoLastTime, "settings\nm_config.ini", "Extensions", "AltHopMondoLastTime"
    
    ; Use a non-blocking status instead of MsgBox
    nm_setStatus("Mondo Test", "Hopping to Private Server...")
    
    ; Kickstart macro if stopped - Reconnection logic only works when started
    if (IsSet(MacroState) && MacroState = 0) {
        ; Bypass 'Automatic Field Boost' warning for this automated start
        if (!A_Args.Has(1))
            A_Args.Push(1)
        else
            A_Args[1] := 1
        try SetTimer start, -50
    }
}

tadsync_AltHopCheck() {
    global AltHopMondoEnabled, AltHopMondoState, AltHopMondoLastTime, AltHopOriginalPublicFallback, AltHopMondoIsTesting
    global LastMondoBuff, ReconnectDelay, PrivServer, MacroState, MondoAction, MondoBuffCheck
    global FieldName, FieldPattern, FieldPatternSize, FieldPatternReps
    
    ; Skip checks if disabled, UNLESS we are in a test
    if (!AltHopMondoEnabled && !AltHopMondoIsTesting)
        return 0
        
    now := nowUnix()
    utc_min := Integer(FormatTime(A_NowUTC, "m"))

    ; If the macro was stopped mid-hop and restarted after the hop window,
    ; unwind back to the private/home server and resume normal Natro flow.
    if (AltHopMondoState > 0 && !tadsync_IsMondoChainWindow()) {
        tadsync_RestoreOriginalSettings()
        if (PrivServer != "") {
            nm_setStatus("Alt Hop", "Expired Mondo hop detected. Returning to private server and resuming normal flow...")
            if (AltHopMondoState != 4)
                tadsync_SetState(4)
            CloseRoblox()
            DisconnectCheck()
            return 1
        }
        tadsync_SetState(0)
        return 0
    }
    
    ; --- TRIGGER MONDO MODE ---
    if (AltHopMondoState = 0) {
        if (tadsync_isMondoTime() && (now - AltHopMondoLastTime) > 2700 && PrivServer != "") {
            tadsync_SaveOriginalSettings()
            MondoAction := "Kill"
            MondoBuffCheck := 1

            nm_setStatus("Alt Hop", "Mondo spawned. Running Mountain Top kill in current server...")
            tadsync_SetState(1)
            AltHopMondoLastTime := now + 30 ; Buffer to prevent immediate "killed" detection
            IniWrite AltHopMondoLastTime, "settings\nm_config.ini", "Extensions", "AltHopMondoLastTime"
            return 1
        }
    }

    if (AltHopMondoState = 1 || AltHopMondoState = 3) {
        MondoAction := "Kill"
        MondoBuffCheck := 1
        return 1
    }

    return 0
}

