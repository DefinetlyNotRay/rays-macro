#Requires AutoHotkey v2.0
#SingleInstance Force
SetWorkingDir A_ScriptDir
; Made by @definetlynotray on discord

JoinLines(lines*) {
    out := ""
    for i, line in lines
        out .= (i = 1 ? "" : "`r`n") line
    return out
}

ReorderExtensionsTabs(listText) {
    parts := StrSplit(listText, ",")
    cleaned := []
    hasExtensions := false
    for _, part in parts {
        item := Trim(part)
        if (item = '"Extensions"') {
            hasExtensions := true
            continue
        }
        cleaned.Push(item)
    }
    if hasExtensions
        cleaned.Push('"Extensions"')
    return StrJoin(cleaned, ", ")
}

StrJoin(items, sep := ", ") {
    out := ""
    for i, item in items
        out .= (i = 1 ? "" : sep) item
    return out
}

ReadPatchBlock(path) {
    ; Made by @definetlynotray on discord - patch template loader
    if !FileExist(path)
        return ""
    text := FileRead(path, "UTF-8")
    text := StrReplace(text, "`r`n", "`n")
    text := StrReplace(text, "`r", "`n")
    text := RTrim(text, "`n")
    return StrReplace(text, "`n", "`r`n")
}

SyncBlockFromSource(targetText, sourceText, startMarker, endMarker, &changed := false) {
    ; Made by @definetlynotray on discord - managed block sync
    changed := false
    targetStart := InStr(targetText, startMarker)
    sourceStart := InStr(sourceText, startMarker)
    if !(targetStart && sourceStart)
        return targetText

    targetEnd := InStr(targetText, endMarker, , targetStart)
    sourceEnd := InStr(sourceText, endMarker, , sourceStart)
    if !(targetEnd && sourceEnd)
        return targetText

    targetBlock := SubStr(targetText, targetStart, targetEnd - targetStart)
    sourceBlock := SubStr(sourceText, sourceStart, sourceEnd - sourceStart)
    if (targetBlock = sourceBlock)
        return targetText

    changed := true
    return SubStr(targetText, 1, targetStart - 1) sourceBlock SubStr(targetText, targetEnd)
}

EnsureIniKey(text, sectionName, keyName, defaultValue, &changed := false) {
    ; Made by @definetlynotray on discord
    changed := false
    sectionPos := InStr(text, "[" sectionName "]")
    if !sectionPos
        return text

    nextSectionPos := RegExMatch(text, "m)^\[.+\]$", &sectionMatch, sectionPos + 1) ? sectionMatch.Pos : 0
    sectionText := nextSectionPos ? SubStr(text, sectionPos, nextSectionPos - sectionPos) : SubStr(text, sectionPos)
    if InStr(sectionText, keyName "=")
        return text

    insertText := keyName "=" defaultValue "`r`n"
    changed := true
    if nextSectionPos
        return SubStr(text, 1, nextSectionPos - 1) insertText SubStr(text, nextSectionPos)

    return RTrim(text, "`r`n") "`r`n" insertText
}

EnsureIniSectionKey(text, sectionName, keyName, defaultValue, &changed := false) {
    changed := false
    if !InStr(text, "[" sectionName "]") {
        base := RTrim(text, "`r`n")
        changed := true
        return ((base = "") ? "" : base "`r`n`r`n") "[" sectionName "]`r`n" keyName "=" defaultValue "`r`n"
    }

    return EnsureIniKey(text, sectionName, keyName, defaultValue, &changed)
}

ShowPatchSelectionGui() {
    result := Map()
    selectionGui := Gui("+AlwaysOnTop", "Apply Patch Modules")
    selectionGui.SetFont("s9", "Segoe UI")
    selectionGui.Add("Text", "xm w560", "Select which patch groups to apply.")
    selectionGui.Add("Text", "xm y+6 w560", "Fresh recommended: TadSync Core, Glitter Extend, Enzyme Balloon Convert, BFB Interrupt, Sticker Stack Interrupt.")
    selectionGui.Add("Text", "xm y+4 w560", "Low risk on modified installs: Force Hourly Report, StatMonitor Theme Tools, Auto Jelly, Auto Bitter.")

    selectionGui.Add("CheckBox", "xm y+14 vPatchTadSyncCore Checked", "TadSync Core (Fresh recommended)")
    selectionGui.Add("CheckBox", "xm y+4 vPatchGlitterExtend Checked", "Glitter Extend (Fresh recommended)")
    selectionGui.Add("CheckBox", "xm y+4 vPatchEnzymeBalloon Checked", "Enzyme Balloon Convert (Fresh recommended)")
    selectionGui.Add("CheckBox", "xm y+4 vPatchBfb Checked", "BFB Interrupt (Fresh recommended)")
    selectionGui.Add("CheckBox", "xm y+4 vPatchStickerStack Checked", "Sticker Stack Interrupt (Fresh recommended)")
    selectionGui.Add("CheckBox", "xm y+4 vPatchForceHourly Checked", "Force Hourly Report (Safe on modified installs)")
    selectionGui.Add("CheckBox", "xm y+4 vPatchStatMonitorTheme Checked", "StatMonitor Theme Tools (Safe on modified installs)")
    selectionGui.Add("CheckBox", "xm y+4 vPatchAutoJelly Checked", "Auto Jelly (Safe on modified installs)")
    selectionGui.Add("CheckBox", "xm y+4 vPatchAutoBitter Checked", "Auto Bitter (Safe on modified installs)")

    dependencyText := selectionGui.Add("Text", "xm y+10 w560 c666666", "Dependencies: Glitter Extend will auto-enable TadSync Core.")
    dependencyText.GetPos(,, &depW, &depH)

    patchClicked := false

    patchButton := selectionGui.Add("Button", "xm y+14 w130 Default", "Patch Selected")
    cancelButton := selectionGui.Add("Button", "x+10 w130", "Cancel")

    patchButton.OnEvent("Click", SubmitSelection)
    cancelButton.OnEvent("Click", (*) => ExitApp())
    selectionGui.OnEvent("Close", (*) => ExitApp())
    selectionGui.Show("AutoSize")

    while !patchClicked
        Sleep(50)
    return result

    SubmitSelection(*) {
        saved := selectionGui.Submit()
        result["PatchTadSyncCore"] := !!saved.PatchTadSyncCore
        result["PatchGlitterExtend"] := !!saved.PatchGlitterExtend
        result["PatchEnzymeBalloon"] := !!saved.PatchEnzymeBalloon
        result["PatchMondoHop"] := false
        result["PatchBfb"] := !!saved.PatchBfb
        result["PatchStickerStack"] := !!saved.PatchStickerStack
        result["PatchForceHourly"] := !!saved.PatchForceHourly
        result["PatchStatMonitorTheme"] := !!saved.PatchStatMonitorTheme
        result["PatchAutoJelly"] := !!saved.PatchAutoJelly
        result["PatchAutoBitter"] := !!saved.PatchAutoBitter

        if (result["PatchGlitterExtend"])
            result["PatchTadSyncCore"] := true

        anySelected := false
        for _, enabled in result {
            if enabled {
                anySelected := true
                break
            }
        }
        if !anySelected {
            MsgBox("Select at least one patch module.", "Apply Patch", 0x30)
            return
        }

        patchClicked := true
        selectionGui.Destroy()
    }
}

; Log file for debugging
logFile := A_ScriptDir "\patch_log.txt"
try FileDelete(logFile)
FileAppend("TadSync Patch Log " A_Now "`n-------------------`n", logFile)

; File paths
workDir := A_ScriptDir
assetsDir := workDir "\Assets"
patchTemplateDir := workDir "\patch_templates"
pineaFbAssetDir := assetsDir "\pine_afb"
natroPath := workDir "\submacros\natro_macro.ahk"
origNatPath := workDir "\submacros\natro_macro(Original Clean).ahk"
statusPath := workDir "\submacros\Status.ahk"
enumIntPath := workDir "\lib\enum\EnumInt.ahk"
enumStrPath := workDir "\lib\enum\EnumStr.ahk"
statMonitorPath := workDir "\submacros\StatMonitor.ahk"
    extraStatMonitorBitmapsPath := workDir "\nm_image_assets\statmonitor\extra_bitmaps.ahk"
statMonitorThemeRuntimePath := workDir "\submacros\StatMonitorThemeRuntime.ahk"
statMonitorThemeEditorPath := workDir "\submacros\StatMonitorThemeEditor.ahk"
statMonitorThemeMainTemplatePath := patchTemplateDir "\statmonitor_theme_main_patch.ahk"
statMonitorThemeRuntimeTemplatePath := patchTemplateDir "\statmonitor_theme_runtime_patch.ahk"
statMonitorThemeEditorTemplatePath := patchTemplateDir "\statmonitor_theme_editor_patch.ahk"
statMonitorInfoSectionTemplatePath := patchTemplateDir "\statmonitor_info_section_patch.txt"
configPath := workDir "\settings\nm_config.ini"
statMonitorThemeConfigPath := workDir "\settings\statmonitor_theme.ini"

; Initialize report
msg := "TadSync Patch Report:`n`n"
enableRiskyCoreHooks := false
selectedModules := ShowPatchSelectionGui()
patchTadSyncCore := selectedModules["PatchTadSyncCore"]
patchGlitterExtend := selectedModules["PatchGlitterExtend"]
patchEnzymeBalloon := selectedModules["PatchEnzymeBalloon"]
patchMondoHop := selectedModules["PatchMondoHop"]
patchBfb := selectedModules["PatchBfb"]
patchStickerStack := selectedModules["PatchStickerStack"]
patchForceHourly := selectedModules["PatchForceHourly"]
patchStatMonitorTheme := selectedModules["PatchStatMonitorTheme"]
patchAutoJelly := selectedModules["PatchAutoJelly"]
patchAutoBitter := selectedModules["PatchAutoBitter"]
enableRiskyCoreHooks := patchMondoHop

DirCreate(assetsDir)
DirCreate(pineaFbAssetDir)
FileAppend("✓ Ensured Assets folder exists`n", logFile)
for _, pineFallbackAsset in ["pine trees 1.png", "pine trees 2.png", "pine trees 3.png"] {
    sourceAsset := pineaFbAssetDir "\" pineFallbackAsset
    targetAsset := workDir "\nm_image_assets\" pineFallbackAsset
    if FileExist(sourceAsset) {
        DirCreate(workDir "\nm_image_assets")
        FileCopy(sourceAsset, targetAsset, 1)
        FileAppend("✓ Copied Pine AFB fallback asset " pineFallbackAsset "`n", logFile)
    }
}

msg .= "Selected Modules:`n"
msg .= " - TadSync Core: " (patchTadSyncCore ? "ON" : "OFF") "`n"
msg .= " - Glitter Extend: " (patchGlitterExtend ? "ON" : "OFF") "`n"
msg .= " - Enzyme Balloon Convert: " (patchEnzymeBalloon ? "ON" : "OFF") "`n"
msg .= " - BFB Interrupt: " (patchBfb ? "ON" : "OFF") "`n"
msg .= " - Sticker Stack Interrupt: " (patchStickerStack ? "ON" : "OFF") "`n"
msg .= " - Force Hourly Report: " (patchForceHourly ? "ON" : "OFF") "`n"
msg .= " - StatMonitor Theme Tools: " (patchStatMonitorTheme ? "ON" : "OFF") "`n"
msg .= " - Auto Jelly: " (patchAutoJelly ? "ON" : "OFF") "`n"
msg .= " - Auto Bitter: " (patchAutoBitter ? "ON" : "OFF") "`n`n"

; 1. PATCH NATRO_MACRO.AHK
if FileExist(natroPath) {
    c := FileRead(natroPath, "UTF-8")
    orig := c

    if (patchTadSyncCore) {
        ; 1a. Restore Beesmas checkbox states when Beesmas controls are enabled
        beesmasEnableOld := JoinLines(
            '		for ctrl in ["BeesmasGatherInterruptCheck","StockingsCheck","WreathCheck","FeastCheck","RBPDelevelCheck","GingerbreadCheck","SnowMachineCheck","CandlesCheck","WinterMemoryMatchCheck","SamovarCheck","LidArtCheck","GummyBeaconCheck"]'
            , '			MainGui[ctrl].Enabled := 1, MainGui[ctrl].Value := %ctrl%'
        )
        beesmasEnablePatched := JoinLines(
            '		for ctrl in ["BeesmasGatherInterruptCheck","StockingsCheck","WreathCheck","FeastCheck","RBPDelevelCheck","GingerbreadCheck","SnowMachineCheck","CandlesCheck","WinterMemoryMatchCheck","SamovarCheck","LidArtCheck","GummyBeaconCheck"]'
            , '			MainGui[ctrl].Enabled := 1'
        )
        beesmasEnableCanonical := JoinLines(
            '		for ctrl in ["BeesmasGatherInterruptCheck","StockingsCheck","WreathCheck","FeastCheck","RBPDelevelCheck","GingerbreadCheck","SnowMachineCheck","CandlesCheck","WinterMemoryMatchCheck","SamovarCheck","LidArtCheck","GummyBeaconCheck"]'
            , '		{'
            , '			MainGui[ctrl].Enabled := 1'
            , '			try MainGui[ctrl].Value := %ctrl%'
            , '		}'
        )
        beesmasBefore := c
        c := StrReplace(c, beesmasEnableOld, beesmasEnableCanonical)
        c := StrReplace(c, beesmasEnablePatched, beesmasEnableCanonical)
        if (c != beesmasBefore)
            FileAppend("✓ Restored Beesmas checkbox state rehydration`n", logFile)
        
        ; 1a0. Clean up old submacros/ includes (migrate to Extensions/ path)
        c := RegExReplace(c, 'm)#Include "%A_ScriptDir%\\tadsync_(\w+)\.ahk"', '#Include "%A_ScriptDir%\..\Extensions\tadsync_$1.ahk"')

        ; 1a. Dynamic includes from Extensions/ folder
        extDir := workDir "\Extensions"
        if DirExist(extDir) {
            loop files extDir "\*.ahk" {
                extFile := A_LoopFileName
                includeStr := '#Include "%A_ScriptDir%\..\Extensions\' extFile '"`r`n'
                if !InStr(c, extFile) {
                    if (pos := InStr(c, "#Warn")) {
                        c := SubStr(c, 1, pos-1) includeStr SubStr(c, pos)
                        FileAppend("âœ“ Auto-included Extensions\\" extFile "`n", logFile)
                    }
                }
            }
        }

        ; tadsync_extension.ahk and tadsync_althop_extension.ahk self-initialize.
        ; Do not inject extra init calls into natro_macro.ahk using brittle version anchors.

        ; Clean up older malformed boost trace injections from a prior patch build.
        c := StrReplace(c, 'adsync_LogBoostScan("gather-scan-start", CurrentField, RecentFBoost)', 'tadsync_LogBoostScan("gather-scan-start", CurrentField, RecentFBoost)')
        c := StrReplace(c, 'adsync_LogBoostScan("gather-scan-none", CurrentField, RecentFBoost)', 'tadsync_LogBoostScan("gather-scan-none", CurrentField, RecentFBoost)')
        c := StrReplace(c, 'adsync_LogBoostScan("gather-scan-picked", CurrentField, RecentFBoost, BoostChaserField)', 'tadsync_LogBoostScan("gather-scan-picked", CurrentField, RecentFBoost, BoostChaserField)')
        c := StrReplace(c, 'ttttttttttadsync_LogBoostScan("gather-scan-none", CurrentField, RecentFBoost)', 'tadsync_LogBoostScan("gather-scan-none", CurrentField, RecentFBoost)')
        c := StrReplace(c, 'ttttttttttadsync_LogBoostScan("gather-scan-picked", CurrentField, RecentFBoost, BoostChaserField)', 'tadsync_LogBoostScan("gather-scan-picked", CurrentField, RecentFBoost, BoostChaserField)')
        c := RegExReplace(c
            , 'loop 1 \{\s*for i, location in \["blue", "mountain", "red", "coconut"\] \{'
            , 'loop 1 {`r`n`t`t`t`tfor i, location in ["blue", "mountain", "red", "coconut"] {'
        )
        c := StrReplace(c, 'ttadsync_LogBoostScan("gather-scan-none", CurrentField, RecentFBoost)', 'tadsync_LogBoostScan("gather-scan-none", CurrentField, RecentFBoost)')
        c := StrReplace(c, 'ttadsync_LogBoostScan("gather-scan-picked", CurrentField, RecentFBoost, BoostChaserField)', 'tadsync_LogBoostScan("gather-scan-picked", CurrentField, RecentFBoost, BoostChaserField)')
        c := StrReplace(c, 'ttttttttttttttttttttadsync_LogBoostScan("gather-scan-start", CurrentField, RecentFBoost)', 'tadsync_LogBoostScan("gather-scan-start", CurrentField, RecentFBoost)')
        goGatherHeaderPattern := '(?ms)^(\s*\}\r?\n\s*\}\r?\n)\{\r?\n(\s*global youDied\b)'
        cNew := RegExReplace(c, goGatherHeaderPattern, '$1nm_GoGather(){`r`n$2', &goGatherHeaderCount, 1)
        if (goGatherHeaderCount > 0 && cNew != c) {
            c := cNew
            FileAppend("✓ Repaired stripped nm_GoGather() function header from older patch run`n", logFile)
        }
        if !InStr(c, 'nm_GoGather(){') {
            goGatherFallbackPattern := '(?ms)(\}\r?\n\}\r?\n)(\s*global youDied\b)'
            cNew := RegExReplace(c, goGatherFallbackPattern, '$1nm_GoGather(){`r`n$2', &goGatherFallbackCount, 1)
            if (goGatherFallbackCount > 0 && cNew != c) {
                c := cNew
                FileAppend("✓ Reinserted nm_GoGather() header before global block`n", logFile)
            }
        }

        ; TadSync core should always normalize and ensure the Hive standby request hook,
        ; even when BFB patching is not selected.
        cNew := RegExReplace(c, '(?<!\w)(?:adsync_RequestHiveStandby\(\)|t{2,}adsync_RequestHiveStandby\(\)|[A-Za-z_][A-Za-z0-9_]*adsync_RequestHiveStandby\(\))', 'tadsync_RequestHiveStandby()', &count)
        if (count > 0) {
            c := cNew
            FileAppend("✓ TadSync Core fixed malformed hive-standby hook in nm_toBooster()`n", logFile)
        }
        if !InStr(c, 'tadsync_RequestHiveStandby()') {
            pattern := '(nm_toBooster\(location\)\{\r?\n\s*global [^\r\n]*\r?\n\s*static [^\r\n]*\r?\n)'
            cNew := RegExReplace(c, pattern, '$1`tadsync_RequestHiveStandby()`r`n', &count, 1)
            if (count > 0) {
                c := cNew
                FileAppend("✓ TadSync Core added hive-standby request before booster travel`n", logFile)
            }
        }

        canonicalBoostBlock :=
        (
        '`t`t;boosted field override`r`n'
        '`t`tif(BoostChaserCheck){`r`n'
        '`t`t`t`ttadsync_LogBoostScan("gather-scan-start", CurrentField, RecentFBoost)`r`n'
        '`r`n'
        '`t`t`tBoostChaserField:="None"`r`n'
        '`t`t`tStoredField := IniRead("settings\nm_config.ini", "Boost", "LastBoostedField", "None")`r`n'
        '`t`t`tStoredTime := IniRead("settings\nm_config.ini", "Boost", "LastBoostedTime", 0)`r`n'
        '`t`t`tStoredGlitter := IniRead("settings\nm_config.ini", "Boost", "LastGlitter", 0)`r`n'
        '`t`t`tstoredBoostEnabled := nm_isBoostChaserFieldEnabled(StoredField)`r`n'
        '`t`t`tif (StoredField != "None" && storedBoostEnabled && ((nowUnix() - StoredTime < 900) || (nowUnix() - StoredGlitter < 900))) {`r`n'
        '`t`t`t`tBoostChaserField := StoredField`r`n'
        '`t`t`t`tGatherFieldBoostedStart := StoredTime`r`n'
        '`t`t`t`tfieldOverrideReason := "Boost"`r`n'
        '`t`t`t}`r`n'
        '`r`n'
        '`t`t`tblueBoosterFields		:=Map("Pine Tree", PineTreeBoosterCheck, "Bamboo", BambooBoosterCheck, "Blue Flower", BlueFlowerBoosterCheck, "Stump", StumpBoosterCheck)`r`n'
        '`t`t`tredBoosterFields		:=Map("Rose", RoseBoosterCheck, "Strawberry", StrawberryBoosterCheck, "Mushroom", MushroomBoosterCheck, "Pepper", PepperBoosterCheck)`r`n'
        '`t`t`tmountainBoosterFields	:=Map("Cactus", CactusBoosterCheck, "Pumpkin", PumpkinBoosterCheck, "Pineapple", PineappleBoosterCheck, "Spider", SpiderBoosterCheck, "Clover", CloverBoosterCheck, "Dandelion", DandelionBoosterCheck, "Sunflower", SunflowerBoosterCheck)`r`n'
        '`t`t`tcoconutBoosterFields	:=Map("Coconut", CoconutBoosterCheck)`r`n'
        '`t`t`totherFields				:=["Mountain Top"]`r`n'
        '`t`t`tboosterFieldGroups		:=Map("blue", blueBoosterFields, "mountain", mountainBoosterFields, "red", redBoosterFields, "coconut", coconutBoosterFields)`r`n'
        '`r`n'
        '`t`t`trecentBoostEnabled := 0`r`n'
        '`t`t`tif (RecentFBoost = "Pine Tree")`r`n'
        '`t`t`t`trecentBoostEnabled := PineTreeBoosterCheck`r`n'
        '`t`t`telse if (RecentFBoost = "Bamboo")`r`n'
        '`t`t`t`trecentBoostEnabled := BambooBoosterCheck`r`n'
        '`t`t`telse if (RecentFBoost = "Blue Flower")`r`n'
        '`t`t`t`trecentBoostEnabled := BlueFlowerBoosterCheck`r`n'
        '`t`t`telse if (RecentFBoost = "Stump")`r`n'
        '`t`t`t`trecentBoostEnabled := StumpBoosterCheck`r`n'
        '`t`t`telse if (RecentFBoost = "Rose")`r`n'
        '`t`t`t`trecentBoostEnabled := RoseBoosterCheck`r`n'
        '`t`t`telse if (RecentFBoost = "Strawberry")`r`n'
        '`t`t`t`trecentBoostEnabled := StrawberryBoosterCheck`r`n'
        '`t`t`telse if (RecentFBoost = "Mushroom")`r`n'
        '`t`t`t`trecentBoostEnabled := MushroomBoosterCheck`r`n'
        '`t`t`telse if (RecentFBoost = "Pepper")`r`n'
        '`t`t`t`trecentBoostEnabled := PepperBoosterCheck`r`n'
        '`t`t`telse if (RecentFBoost = "Cactus")`r`n'
        '`t`t`t`trecentBoostEnabled := CactusBoosterCheck`r`n'
        '`t`t`telse if (RecentFBoost = "Pumpkin")`r`n'
        '`t`t`t`trecentBoostEnabled := PumpkinBoosterCheck`r`n'
        '`t`t`telse if (RecentFBoost = "Pineapple")`r`n'
        '`t`t`t`trecentBoostEnabled := PineappleBoosterCheck`r`n'
        '`t`t`telse if (RecentFBoost = "Spider")`r`n'
        '`t`t`t`trecentBoostEnabled := SpiderBoosterCheck`r`n'
        '`t`t`telse if (RecentFBoost = "Clover")`r`n'
        '`t`t`t`trecentBoostEnabled := CloverBoosterCheck`r`n'
        '`t`t`telse if (RecentFBoost = "Dandelion")`r`n'
        '`t`t`t`trecentBoostEnabled := DandelionBoosterCheck`r`n'
        '`t`t`telse if (RecentFBoost = "Sunflower")`r`n'
        '`t`t`t`trecentBoostEnabled := SunflowerBoosterCheck`r`n'
        '`t`t`telse if (RecentFBoost = "Coconut")`r`n'
        '`t`t`t`trecentBoostEnabled := CoconutBoosterCheck`r`n'
        '`t`t`telse if (RecentFBoost = "Mountain Top")`r`n'
        '`t`t`t`trecentBoostEnabled := 1`r`n'
        '`t`t`tboostExtendActive := PFieldBoostExtend && ((nowUnix()-GatherFieldBoostedStart) < 1800) && ((nowUnix()-LastGlitter) < 900)`r`n'
        '`r`n'
        '`t`t`tif (BoostChaserField == "None") {`r`n'
        '`t`t`t`tloop 1 {`r`n'
        '`t`t`t`t`tif (RecentFBoost != "None" && recentBoostEnabled && (((nowUnix()-GatherFieldBoostedStart) < 900) || boostExtendActive)) {`r`n'
        '`t`t`t`t`t`tBoostChaserField:=RecentFBoost`r`n'
        '`t`t`t`t`t`tbreak`r`n'
        '`t`t`t`t`t}`r`n'
        '`t`t`t`t`tfor i, location in ["blue", "mountain", "red", "coconut"] {`r`n'
        '`t`t`t`t`t`tfor v, enabled in boosterFieldGroups[location] {`r`n'
        '`t`t`t`t`t`t`tif((nm_fieldBoostCheck(v, 1)) && enabled) {`r`n'
        '`t`t`t`t`t`t`t`tBoostChaserField:=v`r`n'
        '`t`t`t`t`t`t`t`tGatherFieldBoostedStart:=nowUnix()`r`n'
        '`t`t`t`t`t`t`t`tIniWrite(v, "settings\nm_config.ini", "Boost", "LastBoostedField")`r`n'
        '`t`t`t`t`t`t`t`tIniWrite(GatherFieldBoostedStart, "settings\nm_config.ini", "Boost", "LastBoostedTime")`r`n'
        '`t`t`t`t`t`t`t`tbreak`r`n'
        '`t`t`t`t`t`t`t}`r`n'
        '`t`t`t`t`t`t}`r`n'
        '`t`t`t`t`t}`r`n'
        '`t`t`t`t`tif(BoostChaserField!="none")`r`n'
        '`t`t`t`t`t`tbreak`r`n'
        '`t`t`t`t`t;other`r`n'
        '`t`t`t`t`tfor key, value in otherFields {`r`n'
        '`t`t`t`t`t`tif(nm_fieldBoostCheck(value, 1)) {`r`n'
        '`t`t`t`t`t`t`tBoostChaserField:=value`r`n'
        '`t`t`t`t`t`t`tGatherFieldBoostedStart:=nowUnix()`r`n'
        '`t`t`t`t`t`t`tIniWrite(value, "settings\nm_config.ini", "Boost", "LastBoostedField")`r`n'
        '`t`t`t`t`t`t`tIniWrite(GatherFieldBoostedStart, "settings\nm_config.ini", "Boost", "LastBoostedTime")`r`n'
        '`t`t`t`t`t`t`tbreak`r`n'
        '`t`t`t`t`t`t}`r`n'
        '`t`t`t`t`t}`r`n'
        '`t`t`t`t}`r`n'
        '`t`t`t}`r`n'
        '`t`t`tif(BoostChaserField="none")`r`n'
        '`t`t`t`ttadsync_LogBoostScan("gather-scan-none", CurrentField, RecentFBoost)`r`n'
        '`t`t`t;set field override`r`n'
        '`t`t`tif(BoostChaserField!="none") {`r`n'
        '`t`t`t`ttadsync_LogBoostScan("gather-scan-picked", CurrentField, RecentFBoost, BoostChaserField)`r`n'
        '`t`t`t`tfieldOverrideReason:="Boost"`r`n'
        '`t`t`t`tFieldName:=BoostChaserField`r`n'
        '`t`t`t`tFieldPattern:=FieldDefault[BoostChaserField]["pattern"]`r`n'
        '`t`t`t`tFieldPatternSize:=FieldDefault[BoostChaserField]["size"]`r`n'
        '`t`t`t`tFieldPatternReps:=FieldDefault[BoostChaserField]["width"]`r`n'
        '`t`t`t`tFieldPatternShift:=FieldDefault[BoostChaserField]["shiftlock"]`r`n'
        '`t`t`t`tFieldPatternInvertFB:=FieldDefault[BoostChaserField]["invertFB"]`r`n'
        '`t`t`t`tFieldPatternInvertLR:=FieldDefault[BoostChaserField]["invertLR"]`r`n'
        '`t`t`t`tFieldUntilMins:=FieldDefault[BoostChaserField]["gathertime"]`r`n'
        '`t`t`t`tFieldUntilPack:=FieldDefault[BoostChaserField]["percent"]`r`n'
        '`t`t`t`tFieldReturnType:=FieldDefault[BoostChaserField]["convert"]`r`n'
        '`t`t`t`tFieldSprinklerLoc:=FieldDefault[BoostChaserField]["sprinkler"]`r`n'
        '`t`t`t`tFieldSprinklerDist:=FieldDefault[BoostChaserField]["distance"]`r`n'
        '`t`t`t`tFieldRotateDirection:=FieldDefault[BoostChaserField]["camera"]`r`n'
        '`t`t`t`tFieldRotateTimes:=FieldDefault[BoostChaserField]["turns"]`r`n'
        '`t`t`t`tFieldDriftCheck:=FieldDefault[BoostChaserField]["drift"]`r`n'
        '`t`t`t`t;start boosted timer here`r`n'
        '`t`t`t`tif ((nowUnix()-GatherFieldBoostedStart>900) && (nowUnix()-LastGlitter>900)) {`r`n'
        '`t`t`t`t`tGatherFieldBoostedStart:=nowUnix()`r`n'
        '`t`t`t`t}`r`n'
        '`t`t`t`tIniWrite(BoostChaserField, "settings\nm_config.ini", "Boost", "LastBoostedField")`r`n'
        '`t`t`t`tIniWrite(GatherFieldBoostedStart, "settings\nm_config.ini", "Boost", "LastBoostedTime")`r`n'
        '`t`t`t`tbreak`r`n'
        '`t`t`t}`r`n'
        '`t`t}`r`n'
    )
    boostBlockPattern := '(?ms)^\t\t;boosted field override\r?\n\t\tif\(BoostChaserCheck\)\{.*?(?=^\t\t;questing override)'
    cNew := RegExReplace(c, boostBlockPattern, canonicalBoostBlock, &boostBlockCount, 1)
    if (boostBlockCount > 0 && cNew != c) {
        c := cNew
        FileAppend("✓ Replaced boosted-field override block with canonical patch-safe version`n", logFile)
    }
    }

    ; 1c. HotbarWhileList
    if (patchGlitterExtend) {
        hotbarListHasGlitter := false
        if RegExMatch(c, 'm)^hotbarwhilelist\s*:=\s*\[(?<list>[^\]]*)\]', &hotbarMatch)
            hotbarListHasGlitter := InStr(hotbarMatch["list"], '"Glitter"') > 0
        if !hotbarListHasGlitter {
            cNew := c
            cNew := RegExReplace(cNew, 'm)^(hotbarwhilelist\s*:=\s*\[[^\]]*"Snowflake")(\s*[,\]])', '$1,"Glitter"$2', , 1)
            if (cNew != c) {
                c := cNew
                FileAppend("âœ“ Added Glitter to hotbarwhilelist`n", logFile)
            }
        }
    }


    ; 1c. Extensions Config
    if (patchTadSyncCore || patchMondoHop) && !InStr(c, 'config["Extensions"]') {
        if (pos := InStr(c, 'config["Status"] := Map(')) {
            configCode := 'config["Extensions"] := Map("FollowingLeader", 0, "FollowingField", "", "FollowingStartTime", 0, "LastAnnouncedField", "", "FieldFollowingCheck", 0, "FieldFollowingFollowMode", "Follower", "FieldFollowingMaxTime", 900, "FieldFollowingChannelID", "", "PFieldBoosted", 0, "PreGlitterCheck", 0'
            if patchMondoHop
                configCode .= ', "AltHopMondoEnabled", 0, "AltHopMondoLeadTime", 1.5, "AltHopMondoState", 0, "AltHopMondoLastTime", 0, "MondoHopLootTime", 45'
            configCode .= ')`r`n'
            c := SubStr(c, 1, pos-1) configCode SubStr(c, pos)
            FileAppend("âœ“ Added config['Extensions'] with Mondo settings`n", logFile)
        }
    } else if patchMondoHop && !InStr(c, '"AltHopMondoEnabled"') {
        ; Append our keys to existing map
        pattern := '(config\["Extensions"\]\s*:=\s*Map\(.*?)(\))'
        c := RegExReplace(c, pattern, '$1, "AltHopMondoEnabled", 0, "AltHopMondoLeadTime", 1.5, "AltHopMondoState", 0, "AltHopMondoLastTime", 0, "MondoHopLootTime", 45$2')
            FileAppend("âœ“ Appended Mondo settings to existing Extensions map`n", logFile)
    }
    if (patchTadSyncCore || patchMondoHop) && !InStr(c, '"PreGlitterCheck"') && InStr(c, 'config["Extensions"] := Map(') {
        c := RegExReplace(c, '(config\["Extensions"\]\s*:=\s*Map\(.*?"PFieldBoosted", 0)(.*?\))', '$1, "PreGlitterCheck", 0$2', , 1)
    }

    ; 1c4. BFB interrupt config defaults
    if (patchBfb) {
    if !InStr(c, '"BlueBoosterInterruptCheck"') {
        configPattern := 'm)^(\s*, "CoconutBoosterCheck", [^\r\n]+)$'
        configReplacement := '$1`r`n`t`t, "BlueBoosterInterruptCheck", 1`r`n`t`t, "LastBlueBoostUse", 1'
        cNew := RegExReplace(c, configPattern, configReplacement, &bfbConfigCount, 1)
        if (bfbConfigCount > 0 && cNew != c) {
            c := cNew
            FileAppend("✓ Added BFB interrupt config defaults to natro_macro.ahk`n", logFile)
        }
    }
    }
    if (patchStickerStack) {
    if !InStr(c, '"StickerStackInterruptCheck"') {
        stickerConfigPattern := 'm)^(\s*, "StickerStackVoucher", [^\r\n]+)(\))$'
        stickerConfigReplacement := '$1`r`n`t`t, "StickerStackInterruptCheck", 1`r`n`t`t, "LastStickerStackUse", 1$2'
        cNew := RegExReplace(c, stickerConfigPattern, stickerConfigReplacement, &stickerConfigCount, 1)
        if (stickerConfigCount > 0 && cNew != c) {
            c := cNew
            FileAppend("✓ Added Sticker Stack interrupt config defaults to natro_macro.ahk`n", logFile)
        }
    }
    }
    if (patchEnzymeBalloon) && !InStr(c, '"EnzymesBoostedOnly"') {
        enzymeConfigPattern := 'm)^(\s*, "LastHotkey7", [^\r\n]+)$'
        enzymeConfigReplacement := '$1`r`n`t`t, "EnzymesBoostedOnly", 1'
        cNew := RegExReplace(c, enzymeConfigPattern, enzymeConfigReplacement, &enzymeConfigCount, 1)
        if (enzymeConfigCount > 0 && cNew != c) {
            c := cNew
            FileAppend("✓ Added EnzymesBoostedOnly config default to natro_macro.ahk`n", logFile)
        }
    }

    ; 1c5. Interrupt toggle handlers
    if (patchBfb) {
    if !InStr(c, 'nm_BlueBoosterToggle(*)') {
        blueBoosterToggleNeedle := 'nm_BoostedFieldSelectButton(*){'
        blueBoosterToggleInsert := JoinLines(
            'nm_BlueBoosterToggle(*){',
            '`tglobal BlueBoosterInterruptCheck, MainGui',
            '`tBlueBoosterInterruptCheck := MainGui["BlueBoosterInterruptCheck"].Value',
            '`tIniWrite BlueBoosterInterruptCheck, "settings\nm_config.ini", "Boost", "BlueBoosterInterruptCheck"',
            '}',
            '',
            blueBoosterToggleNeedle
        )
        cNew := StrReplace(c, blueBoosterToggleNeedle, blueBoosterToggleInsert)
        if (cNew != c) {
            c := cNew
            FileAppend("✓ Added BFB toggle handler`n", logFile)
        }
    }
    }

    if (patchStickerStack) {
    if !InStr(c, 'nm_StickerStackToggle(*)') {
        stickerToggleNeedle := 'nm_BlueBoosterToggle(*){'
        stickerToggleInsert := JoinLines(
            'nm_StickerStackToggle(*){',
            '`tglobal StickerStackInterruptCheck, MainGui',
            '`tStickerStackInterruptCheck := MainGui["StickerStackInterruptCheck"].Value',
            '`tIniWrite StickerStackInterruptCheck, "settings\nm_config.ini", "Boost", "StickerStackInterruptCheck"',
            '}',
            '',
            stickerToggleNeedle
        )
        cNew := StrReplace(c, stickerToggleNeedle, stickerToggleInsert)
        if (cNew != c) {
            c := cNew
            FileAppend("✓ Added Sticker Stack interrupt toggle handler`n", logFile)
        }
    }
    }

    ; 1c8. Sticker Stack interrupt functions
    if (patchStickerStack) {
    if !InStr(c, 'OnMessage(0x5564, nm_ForceStickerStack, 255)') && InStr(c, 'OnMessage(0x5560, nm_copyDebugLog)') {
        cNew := StrReplace(c, 'OnMessage(0x5560, nm_copyDebugLog)', 'OnMessage(0x5560, nm_copyDebugLog)`r`nOnMessage(0x5564, nm_ForceStickerStack, 255)')
        if (cNew != c) {
            c := cNew
            FileAppend("✓ Added Force Sticker Stack message hook to natro_macro.ahk`n", logFile)
        }
    }
    if !InStr(c, 'nm_ForceStickerStack(wParam := 1, *){') && InStr(c, 'nm_ForceReconnect(wParam, *){') {
        forceStickerHandler := JoinLines(
            'nm_ForceStickerStack(wParam := 1, *){',
            '`tCritical',
            '`tglobal ForceStickerStackInterrupt, LastStickerStackUse, StickerStackCheck, MainGui',
            '`tinterruptEnabled := (IsSet(MainGui) && IsObject(MainGui)) ? MainGui["StickerStackInterruptCheck"].Value : 0',
            '`tForceStickerStackInterrupt := ((wParam != 0) && (StickerStackCheck = 1) && (interruptEnabled = 1))',
            '`tif (ForceStickerStackInterrupt)',
            '`t`tLastStickerStackUse := 1',
            '`treturn 0',
            '}',
            '',
            'nm_ForceReconnect(wParam, *){'
        )
        cNew := StrReplace(c, 'nm_ForceReconnect(wParam, *){', forceStickerHandler)
        if (cNew != c) {
            c := cNew
            FileAppend("✓ Added Force Sticker Stack handler to natro_macro.ahk`n", logFile)
        }
    }
    if (patchBfb) {
    if !InStr(c, 'OnMessage(0x5565, nm_ForceBlueBooster, 255)') {
        cNew := c
        if InStr(cNew, 'OnMessage(0x5564, nm_ForceStickerStack, 255)')
            cNew := StrReplace(cNew, 'OnMessage(0x5564, nm_ForceStickerStack, 255)', 'OnMessage(0x5564, nm_ForceStickerStack, 255)`r`nOnMessage(0x5565, nm_ForceBlueBooster, 255)')
        else if InStr(cNew, 'OnMessage(0x5560, nm_copyDebugLog)')
            cNew := StrReplace(cNew, 'OnMessage(0x5560, nm_copyDebugLog)', 'OnMessage(0x5560, nm_copyDebugLog)`r`nOnMessage(0x5565, nm_ForceBlueBooster, 255)')
        if (cNew != c) {
            c := cNew
            FileAppend("✓ Added Force Blue Field Booster message hook to natro_macro.ahk`n", logFile)
        }
    }
    if !InStr(c, 'nm_ForceBlueBooster(wParam := 1, *){') && InStr(c, 'nm_ForceReconnect(wParam, *){') {
        forceBfbHandler := JoinLines(
            'nm_ForceBlueBooster(wParam := 1, *){',
            '`tCritical',
            '`tglobal ForceBlueBoosterInterrupt',
            '`tForceBlueBoosterInterrupt := (wParam != 0)',
            '`treturn 0',
            '}',
            '',
            'nm_ForceReconnect(wParam, *){'
        )
        cNew := StrReplace(c, 'nm_ForceReconnect(wParam, *){', forceBfbHandler)
        if (cNew != c) {
            c := cNew
            FileAppend("✓ Added Force Blue Field Booster handler to natro_macro.ahk`n", logFile)
        }
    }
    cNew := c
    cNew := StrReplace(cNew, 'global BlueBoosterInterruptCheck, LastBlueBoostUse', 'global BlueBoosterInterruptCheck, LastBlueBoostUse, ForceBlueBoosterInterrupt')
    cNew := StrReplace(cNew, 'if (!BlueBoosterInterruptCheck)`r`n`t`treturn 0', 'if (ForceBlueBoosterInterrupt)`r`n`t`treturn 1`r`n`tif (!BlueBoosterInterruptCheck)`r`n`t`treturn 0')
    if (cNew != c) {
        c := cNew
        FileAppend("✓ Updated nm_BlueBoosterInterrupt() to support forced trigger`n", logFile)
    }
    cNew := c
    cNew := StrReplace(cNew, 'global LastBlueBoost, LastRedBoost, LastMountainBoost, LastCoconutDis, RecentFBoost, LastBlueBoostUse', 'global LastBlueBoost, LastRedBoost, LastMountainBoost, LastCoconutDis, RecentFBoost, LastBlueBoostUse, ForceBlueBoosterInterrupt')
    cNew := StrReplace(cNew, 'tadsync_RequestHiveStandby()`r`n', 'tadsync_RequestHiveStandby()`r`n`tif (location = "blue")`r`n`t`tForceBlueBoosterInterrupt := 0`r`n')
    if (cNew != c) {
        c := cNew
        FileAppend("✓ Wired forced Blue Field Booster flag reset into nm_toBooster()`n", logFile)
    }
    cNew := RegExReplace(c, 'global LastBlueBoost, LastRedBoost, LastMountainBoost, LastCoconutDis, RecentFBoost, LastBlueBoostUse(?:, ForceBlueBoosterInterrupt)+', 'global LastBlueBoost, LastRedBoost, LastMountainBoost, LastCoconutDis, RecentFBoost, LastBlueBoostUse, ForceBlueBoosterInterrupt')
    cNew := RegExReplace(cNew, '(?ms)(\ttadsync_RequestHiveStandby\(\)\r?\n)(?:\tif \(location = "blue"\)\r?\n\t\tForceBlueBoosterInterrupt := 0\r?\n)+', '$1`tif (location = "blue")`r`n`t`tForceBlueBoosterInterrupt := 0`r`n')
    if (cNew != c) {
        c := cNew
        FileAppend("✓ Normalized forced Blue Field Booster wiring in nm_toBooster()`n", logFile)
    }
    }
    if !InStr(c, 'nm_StickerStackInterrupt() {') {
        stickerInterruptFuncNeedle := InStr(c, 'nm_BlueBoosterInterrupt() {') ? 'nm_BlueBoosterInterrupt() {' : ';stats/status'
        stickerInterruptFuncInsert := JoinLines(
            'nm_StickerStackInterrupt() {',
            '`tglobal MainGui, LastStickerStack, LastStickerStackUse, StickerStackTimer, StickerStackCheck, ForceStickerStackInterrupt',
            '`tinterruptEnabled := (IsSet(MainGui) && IsObject(MainGui)) ? MainGui["StickerStackInterruptCheck"].Value : "?"',
            '`tforceAllowed := ForceStickerStackInterrupt && (StickerStackCheck = 1) && (interruptEnabled = 1)',
            '`tif (ForceStickerStackInterrupt) {',
            '`t`tToolTip "Sticker Stack: FORCED", 0, 0, 2',
            '`t`tif (!forceAllowed)',
            '`t`t`treturn 0',
            '`t`treturn 1',
            '`t}',
            '`tif (LastStickerStack = 0) {',
            '`t`tToolTip "Sticker Stack: READY", 0, 0, 2',
            '`t} else {',
            '`t`tstackTimeLeft := StickerStackTimer - (nowUnix() - LastStickerStack)',
            '`t`tif (stackTimeLeft > 0) {',
            '`t`t`tToolTip "Sticker Stack: " Floor(stackTimeLeft/60) "m " Mod(stackTimeLeft,60) "s", 0, 0, 2',
            '`t`t`treturn 0',
            '`t`t}',
            '`t`tToolTip "Sticker Stack: READY", 0, 0, 2',
            '`t}',
            '`tif (!StickerStackCheck || !MainGui["StickerStackInterruptCheck"].Value)',
            '`t`treturn 0',
            '`tif ((nowUnix() - LastStickerStackUse) < 60)',
            '`t`treturn 0',
            '`treturn 1',
            '}',
            '',
            'nm_HandleStickerStackInterrupt(convertAfter := 1, allowEmergencyGlitter := 0, resetBeforeStack := 1) {',
            '`tglobal LastStickerStackUse, LastGlitter, GatherFieldBoostedStart, GlitterKey, fieldOverrideReason, PFieldBoosted, ForceStickerStackInterrupt, HiveConfirmed, bitmaps, state, objective',
            '`tstatic handling := 0',
            '`tif (handling || !nm_StickerStackInterrupt())',
            '`t`treturn 0',
            '`tprevState := state',
            '`tprevObjective := objective',
            '`texpectedConvert := (prevState = "Converting" && InStr(prevObjective, "Balloon")) ? "Balloon"',
            '`t`t: (prevState = "Converting" && InStr(prevObjective, "Backpack")) ? "Backpack" : ""',
            '`thandling := 1',
            '`tif (allowEmergencyGlitter && PFieldBoosted && fieldOverrideReason = "Boost" && GlitterKey != "none") {',
            '`t`tcurGlit := IniRead("settings\nm_config.ini", "Boost", "LastGlitter", LastGlitter)',
            '`t`tcurTime := IniRead("settings\nm_config.ini", "Boost", "LastBoostedTime", GatherFieldBoostedStart)',
            '`t`tactiveStart := (curGlit > curTime) ? curGlit : curTime',
            '`t`tleaseRem := 900 - (nowUnix() - activeStart)',
            '`t`ttimeSinceLastGlitter := nowUnix() - curGlit',
            '`t`tif (leaseRem < 180 && leaseRem > 0 && timeSinceLastGlitter > 960) {',
            '`t`t`tnm_setStatus("Interrupt", "Sticker Stack: Emergency Glitter")',
            '`t`t`tSend "{" GlitterKey "}"',
            '`t`t`tLastGlitter := nowUnix()',
            '`t`t`tIniWrite LastGlitter, "settings\nm_config.ini", "Boost", "LastGlitter"',
            '`t`t`tSleep 1000',
            '`t`t}',
            '`t}',
            '`tLastStickerStackUse := nowUnix()',
            '`tIniWrite LastStickerStackUse, "settings\nm_config.ini", "Boost", "LastStickerStackUse"',
            '`tnm_setStatus("Emergency", "Sticker Stack Ready")',
            '`tnm_StickerStack(resetBeforeStack)',
            '`tForceStickerStackInterrupt := 0',
            '`tnm_setStatus("Traveling", "Returning to Hive post-Stack")',
            '`tnm_Reset(2, 2000, 0)',
            '`tGetRobloxClientPos(hwnd := GetRobloxHWND())',
            '`tpBMScreen := Gdip_BitmapFromScreen(windowX + windowWidth // 2 - 150 "|" windowY + GetYOffset(hwnd) + 40 "|350|60")',
            '`tHiveConfirmed := (Gdip_ImageSearch(pBMScreen, bitmaps["colhey"],,,,,,5) = 1)',
            '`tGdip_DisposeImage(pBMScreen)',
            '`tif (convertAfter) {',
            '`t`tnm_setStatus("Priority", "Resuming Conversion after Stack")',
            '`t`tresumedConvert := 0',
            '`t`tloop 4 {',
            '`t`t`tnm_convert(1)',
            '`t`t`tif (expectedConvert = "" || (state = "Converting" && InStr(objective, expectedConvert))) {',
            '`t`t`t`tresumedConvert := 1',
            '`t`t`t`tbreak',
            '`t`t`t}',
            '`t`t`tif (A_Index < 4) {',
            '`t`t`t`tnm_setStatus("Priority", "Retrying " (expectedConvert ? expectedConvert : "Previous") " Conversion after Stack")',
            '`t`t`t`tnm_Reset(2, 2000, 0)',
            '`t`t`t`tGetRobloxClientPos(hwnd := GetRobloxHWND())',
            '`t`t`t`tpBMScreen := Gdip_BitmapFromScreen(windowX + windowWidth // 2 - 150 "|" windowY + GetYOffset(hwnd) + 40 "|350|60")',
            '`t`t`t`tHiveConfirmed := (Gdip_ImageSearch(pBMScreen, bitmaps["colhey"],,,,,,5) = 1)',
            '`t`t`t`tGdip_DisposeImage(pBMScreen)',
            '`t`t`t`tSleep 1000',
            '`t`t`t}',
            '`t`t}',
            '`t`tif (!resumedConvert && expectedConvert != "") {',
            '`t`t`tnm_setStatus("Failed", "Could not resume " expectedConvert " Conversion after Stack")',
            '`t`t}',
            '`t}',
            '`thandling := 0',
            '`treturn 1',
            '}',
            '',
            stickerInterruptFuncNeedle
        )
        cNew := StrReplace(c, stickerInterruptFuncNeedle, stickerInterruptFuncInsert)
        if (cNew != c) {
            c := cNew
            FileAppend("✓ Added Sticker Stack interrupt helper functions`n", logFile)
        }
    }
    if !InStr(c, 'ToolTip "Sticker Stack: FORCED", 0, 0, 2') && InStr(c, '`tglobal MainGui, LastStickerStack, LastStickerStackUse, StickerStackTimer, StickerStackCheck') {
        cNew := StrReplace(c, '`tglobal MainGui, LastStickerStack, LastStickerStackUse, StickerStackTimer, StickerStackCheck', '`tglobal MainGui, LastStickerStack, LastStickerStackUse, StickerStackTimer, StickerStackCheck, ForceStickerStackInterrupt')
        if (cNew != c) {
            c := cNew
            FileAppend("✓ Added Force Sticker Stack global to nm_StickerStackInterrupt()`n", logFile)
        }
        cNew := StrReplace(c, 'nm_StickerStackInterrupt() {`r`n`tglobal MainGui, LastStickerStack, LastStickerStackUse, StickerStackTimer, StickerStackCheck, ForceStickerStackInterrupt`r`n`tif (LastStickerStack = 0) {', 'nm_StickerStackInterrupt() {`r`n`tglobal MainGui, LastStickerStack, LastStickerStackUse, StickerStackTimer, StickerStackCheck, ForceStickerStackInterrupt`r`n`tif (ForceStickerStackInterrupt) {`r`n`t`tToolTip "Sticker Stack: FORCED", 0, 0, 2`r`n`t`tif (!StickerStackCheck || !MainGui["StickerStackInterruptCheck"].Value)`r`n`t`t`treturn 0`r`n`t`treturn 1`r`n`t}`r`n`tif (LastStickerStack = 0) {')
        if (cNew != c) {
            c := cNew
            FileAppend("✓ Added forced Sticker Stack test branch to nm_StickerStackInterrupt()`n", logFile)
        }
    }
    if !InStr(c, 'ForceStickerStackInterrupt := 0') && InStr(c, '`tglobal LastStickerStackUse, LastGlitter, GatherFieldBoostedStart, GlitterKey, fieldOverrideReason, PFieldBoosted') {
        cNew := StrReplace(c, '`tglobal LastStickerStackUse, LastGlitter, GatherFieldBoostedStart, GlitterKey, fieldOverrideReason, PFieldBoosted', '`tglobal LastStickerStackUse, LastGlitter, GatherFieldBoostedStart, GlitterKey, fieldOverrideReason, PFieldBoosted, ForceStickerStackInterrupt')
        if (cNew != c) {
            c := cNew
            FileAppend("✓ Added Force Sticker Stack global to handler`n", logFile)
        }
        cNew := StrReplace(c, '`tnm_StickerStack(resetBeforeStack)`r`n`tnm_setStatus("Traveling", "Returning to Hive post-Stack")', '`tnm_StickerStack(resetBeforeStack)`r`n`tForceStickerStackInterrupt := 0`r`n`tnm_setStatus("Traveling", "Returning to Hive post-Stack")')
        if (cNew != c) {
            c := cNew
            FileAppend("✓ Moved Force Sticker Stack reset to after stack attempt`n", logFile)
        }
    }
    oldStackResumeBlock :=
    (
    '`tif (convertAfter) {`r`n'
    . '`t`tnm_setStatus("Priority", "Resuming Conversion after Stack")`r`n'
    . '`t`tloop 2 {`r`n'
    . '`t`t`tnm_convert(1)`r`n'
    . '`t`t`tif (expectedConvert = "" || (state = "Converting" && InStr(objective, expectedConvert)))`r`n'
    . '`t`t`t`tbreak`r`n'
    . '`t`t`tif (A_Index = 1) {`r`n'
    . '`t`t`t`tnm_setStatus("Priority", "Retrying " expectedConvert " Conversion after Stack")`r`n'
    . '`t`t`t`tSleep 1000`r`n'
    . '`t`t`t}`r`n'
    . '`t`t}`r`n'
    . '`t}'
    )
    newStackResumeBlock :=
    (
    '`tif (convertAfter) {`r`n'
    . '`t`tnm_setStatus("Priority", "Resuming Conversion after Stack")`r`n'
    . '`t`tresumedConvert := 0`r`n'
    . '`t`tloop 4 {`r`n'
    . '`t`t`tnm_convert(1)`r`n'
    . '`t`t`tif (expectedConvert = "" || (state = "Converting" && InStr(objective, expectedConvert))) {`r`n'
    . '`t`t`t`tresumedConvert := 1`r`n'
    . '`t`t`t`tbreak`r`n'
    . '`t`t`t}`r`n'
    . '`t`t`tif (A_Index < 4) {`r`n'
    . '`t`t`t`tnm_setStatus("Priority", "Retrying " (expectedConvert ? expectedConvert : "Previous") " Conversion after Stack")`r`n'
    . '`t`t`t`tnm_Reset(2, 2000, 0)`r`n'
    . '`t`t`t`tGetRobloxClientPos(hwnd := GetRobloxHWND())`r`n'
    . '`t`t`t`tpBMScreen := Gdip_BitmapFromScreen(windowX + windowWidth // 2 - 150 "|" windowY + GetYOffset(hwnd) + 40 "|350|60")`r`n'
    . '`t`t`t`tHiveConfirmed := (Gdip_ImageSearch(pBMScreen, bitmaps["colhey"],,,,,,5) = 1)`r`n'
    . '`t`t`t`tGdip_DisposeImage(pBMScreen)`r`n'
    . '`t`t`t`tSleep 1000`r`n'
    . '`t`t`t}`r`n'
    . '`t`t}`r`n'
    . '`t`tif (!resumedConvert && expectedConvert != "") {`r`n'
    . '`t`t`tnm_setStatus("Failed", "Could not resume " expectedConvert " Conversion after Stack")`r`n'
    . '`t`t}`r`n'
    . '`t}'
    )
    brokenStackResumeBlock :=
    (
    '`tif (convertAfter) {`r`n'
    . '`t`tnm_setStatus("Priority", "Resuming Conversion after Stack")`r`n'
    . '`t`tresumedConvert := 0`r`n'
    . '`t`tloop 4 {`r`n'
    . '`t`t`tnm_convert(1)`r`n'
    . '`t`t`tif (expectedConvert = "" || (state = "Converting" && InStr(objective, expectedConvert))) {`r`n'
    . '`t`t`t`tresumedConvert := 1`r`n'
    . '`t`t`t`tbreak`r`n'
    . '`t`t`t}`r`n'
    . '`t`t`tif (A_Index < 4) {`r`n'
    . '`t`t`t\tnm_setStatus("Priority", "Retrying " (expectedConvert ? expectedConvert : "Previous") " Conversion after Stack")`r`n'
    . '`t`t`t\tnm_Reset(2, 2000, 0)`r`n'
    . '`t`t`t\tGetRobloxClientPos(hwnd := GetRobloxHWND())`r`n'
    . '`t`t`t\tpBMScreen := Gdip_BitmapFromScreen(windowX + windowWidth // 2 - 150 "|" windowY + GetYOffset(hwnd) + 40 "|350|60")`r`n'
    . '`t`t`t\tHiveConfirmed := (Gdip_ImageSearch(pBMScreen, bitmaps["colhey"],,,,,,5) = 1)`r`n'
    . '`t`t`t\tGdip_DisposeImage(pBMScreen)`r`n'
    . '`t`t`t\tSleep 1000`r`n'
    . '`t`t`t}`r`n'
    . '`t`t}`r`n'
    . '`t`tif (!resumedConvert && expectedConvert != "") {`r`n'
    . '`t`t\tnm_setStatus("Failed", "Could not resume " expectedConvert " Conversion after Stack")`r`n'
    . '`t`t}`r`n'
    . '`t}'
    )
    cNew := StrReplace(c, oldStackResumeBlock, newStackResumeBlock)
    cNew := StrReplace(cNew, brokenStackResumeBlock, newStackResumeBlock)
    if (cNew != c) {
        c := cNew
        FileAppend("✓ Upgraded existing Sticker Stack resume block in-place`n", logFile)
    }
    canonicalStickerHandler := JoinLines(
        'nm_HandleStickerStackInterrupt(convertAfter := 1, allowEmergencyGlitter := 0, resetBeforeStack := 1) {',
        '`tglobal LastStickerStackUse, LastGlitter, GatherFieldBoostedStart, GlitterKey, fieldOverrideReason, PFieldBoosted, ForceStickerStackInterrupt, HiveConfirmed, bitmaps, state, objective, ConvertGatherFlag, SkipBoostStickerStackUntil, AFBuseGlitter',
        '`tstatic handling := 0',
        '`tif (handling || !nm_StickerStackInterrupt())',
        '`t`treturn 0',
        '`tprevState := state',
        '`tprevObjective := objective',
        '`tresumeBalloonConvert := (prevState = "Converting") && InStr(prevObjective, "Balloon")',
        '`thandling := 1',
        '`tif (AFBuseGlitter) {',
        '`t`tnm_setStatus("Priority", "Boosting Field: Glitter")',
        '`t`tnm_fieldBoostGlitter()',
        '`t}',
        '`tif (allowEmergencyGlitter && PFieldBoosted && fieldOverrideReason = "Boost" && GlitterKey != "none") {',
        '`t`tcurGlit := IniRead("settings\nm_config.ini", "Boost", "LastGlitter", LastGlitter)',
        '`t`tcurTime := IniRead("settings\nm_config.ini", "Boost", "LastBoostedTime", GatherFieldBoostedStart)',
        '`t`tactiveStart := (curGlit > curTime) ? curGlit : curTime',
        '`t`tleaseRem := 900 - (nowUnix() - activeStart)',
        '`t`ttimeSinceLastGlitter := nowUnix() - curGlit',
        '`t`tif (leaseRem < 180 && leaseRem > 0 && timeSinceLastGlitter > 960) {',
        '`t`t`tnm_setStatus("Interrupt", "Sticker Stack: Emergency Glitter")',
        '`t`t`tSend "{" GlitterKey "}"',
        '`t`t`tLastGlitter := nowUnix()',
        '`t`t`tIniWrite LastGlitter, "settings\nm_config.ini", "Boost", "LastGlitter"',
        '`t`t`tSleep 1000',
        '`t`t}',
        '`t}',
        '`tLastStickerStackUse := nowUnix()',
        '`tIniWrite LastStickerStackUse, "settings\nm_config.ini", "Boost", "LastStickerStackUse"',
        '`tnm_setStatus("Emergency", "Sticker Stack Ready")',
        '`tstackSucceeded := nm_StickerStack(resetBeforeStack)',
        '`tForceStickerStackInterrupt := 0',
        '`tif (stackSucceeded)',
        '`t`tSkipBoostStickerStackUntil := nowUnix() + 180',
        '`tif (convertAfter) {',
        '`t`tnm_setStatus("Priority", "Resetting to Hive for Convert after Stack")',
        '`t`tnm_Reset(2, 2000, 0, 1)',
        '`t`tif (resumeBalloonConvert)',
        '`t`t`tConvertGatherFlag := 1',
        '`t`tif !nm_findHiveSlot(1, resumeBalloonConvert)',
        '`t`t`tnm_setStatus("Failed", resumeBalloonConvert ? "Could not resume Balloon Convert after Stack" : "Could not confirm hive after Stack")',
        '`t} else {',
        '`t`tnm_setStatus("Traveling", "Returning to Hive post-Stack")',
        '`t`tnm_Reset(2, 2000, 0, 1)',
        '`t}',
        '`thandling := 0',
        '`treturn 1',
        '}'
    )
    if RegExMatch(c, '(?ms)^nm_HandleStickerStackInterrupt\(convertAfter := 1, allowEmergencyGlitter := 0, resetBeforeStack := 1\) \{.*?^\}\r?\n(?:\r?\n)?(?=nm_BlueBoosterInterrupt\(\) \{)', &stickerHandleMatch) {
        desiredStickerHandler := canonicalStickerHandler "`r`n`r`n"
        if (stickerHandleMatch[0] != desiredStickerHandler) {
            c := StrReplace(c, stickerHandleMatch[0], desiredStickerHandler)
            FileAppend("✓ Normalized Sticker Stack handler to reset-findhive-convert flow`n", logFile)
        }
    }
    if (handlerStart := InStr(c, 'nm_HandleStickerStackInterrupt(convertAfter := 1, allowEmergencyGlitter := 0, resetBeforeStack := 1) {')) {
        handlerEnd := 0
        handlerSkip := 0
        for _, marker in [['`r`nnm_BlueBoosterInterrupt() {', 2], ['`r`n;stats/status', 2], ['`nnm_BlueBoosterInterrupt() {', 1], ['`n;stats/status', 1]] {
            pos := InStr(c, marker[1], false, handlerStart)
            if (pos && (!handlerEnd || pos < handlerEnd)) {
                handlerEnd := pos
                handlerSkip := marker[2]
            }
        }
        if (handlerEnd) {
            existingHandler := SubStr(c, handlerStart, handlerEnd - handlerStart)
            desiredHandler := canonicalStickerHandler "`r`n`r`n"
            if (existingHandler != desiredHandler) {
                c := SubStr(c, 1, handlerStart - 1) desiredHandler SubStr(c, handlerEnd + handlerSkip)
                FileAppend("✓ Force-normalized Sticker Stack handler block`n", logFile)
            }
        }
    }
    }

    ; 1c9. BFB interrupt function
    if (patchBfb) {
    if !InStr(c, 'nm_BlueBoosterInterrupt() {') {
        blueBoosterInterruptNeedle := ';stats/status'
        blueBoosterInterruptInsert := JoinLines(
            'nm_BlueBoosterInterrupt() {',
            '`tglobal BlueBoosterInterruptCheck, LastBlueBoostUse',
            '`tif (!BlueBoosterInterruptCheck)',
            '`t`treturn 0',
            '',
            '`tlastUse := (LastBlueBoostUse = "" ? 0 : LastBlueBoostUse)',
            '`ttimeSince := nowUnix() - lastUse',
            '',
            '`tToolTip "BFB: " timeSince " / 2700", 0, 15',
            '',
            '`tif (timeSince >= 2660)',
            '`t`treturn 1',
            '',
            '`treturn 0',
            '}',
            '',
            blueBoosterInterruptNeedle
        )
        cNew := StrReplace(c, blueBoosterInterruptNeedle, blueBoosterInterruptInsert)
        if (cNew != c) {
            c := cNew
            FileAppend("✓ Added nm_BlueBoosterInterrupt() function`n", logFile)
        }
    }

    ; 1c10. BFB timer wiring in nm_toBooster()
    if !InStr(c, 'RecentFBoost, LastBlueBoostUse') {
        cNew := StrReplace(c
            , 'global LastBlueBoost, LastRedBoost, LastMountainBoost, LastCoconutDis, RecentFBoost'
            , 'global LastBlueBoost, LastRedBoost, LastMountainBoost, LastCoconutDis, RecentFBoost, LastBlueBoostUse'
        )
        if (cNew != c) {
            c := cNew
            FileAppend("✓ Added LastBlueBoostUse global to nm_toBooster()`n", logFile)
        }
    }
    if !InStr(c, 'LastBlueBoostUse := nowUnix()') {
        boosterSuccessNeedle := '			Last%location%Boost:=nowUnix(), IniWrite(Last%location%Boost, "settings\nm_config.ini", "Collect", "Last" location "Boost")'
        boosterSuccessInsert := JoinLines(
            '			Last%location%Boost:=nowUnix(), IniWrite(Last%location%Boost, "settings\nm_config.ini", "Collect", "Last" location "Boost")',
            '			if (location = "blue") {',
            '				LastBlueBoostUse := nowUnix()',
            '				IniWrite LastBlueBoostUse, "settings\nm_config.ini", "Boost", "LastBlueBoostUse"',
            '			}'
        )
        cNew := StrReplace(c, boosterSuccessNeedle, boosterSuccessInsert)
        if (cNew != c) {
            c := cNew
            FileAppend("✓ Added BFB success timer update in nm_toBooster()`n", logFile)
        }
    }
    if !InStr(c, 'LastBlueBoostUse := nowUnix() - 2700') {
        boosterFailureNeedle := JoinLines(
            '				Last%location%Boost:=nowUnix()-1500',
            '				IniWrite Last%location%Boost, "settings\nm_config.ini", "Collect", "Last" location "Boost"'
        )
        boosterFailureInsert := JoinLines(
            '				Last%location%Boost := (location = "blue") ? nowUnix() - 900 : nowUnix() - 3600',
            '				IniWrite Last%location%Boost, "settings\nm_config.ini", "Collect", "Last" location "Boost"',
            '				if (location = "blue") {',
            '					LastBlueBoostUse := nowUnix() - 2700',
            '					IniWrite LastBlueBoostUse, "settings\nm_config.ini", "Boost", "LastBlueBoostUse"',
            '				}'
        )
        cNew := StrReplace(c, boosterFailureNeedle, boosterFailureInsert)
        if (cNew != c) {
            c := cNew
            FileAppend("✓ Added BFB cooldown repair in nm_toBooster()`n", logFile)
        }
    }
    cNew := RegExReplace(c, 'Last%location%Boost\s*:=\s*\(location = "blue"\) \? nowUnix\(\) - 900 : nowUnix\(\) - 1500', 'Last%location%Boost := (location = "blue") ? nowUnix() - 900 : nowUnix() - 3600')
    if (cNew != c) {
        c := cNew
        FileAppend("✓ Restored non-blue booster cooldown backdate to Baspas timing`n", logFile)
    }
    cNew := RegExReplace(c, '(?<!\w)(?:adsync_RequestHiveStandby\(\)|t{2,}adsync_RequestHiveStandby\(\)|[A-Za-z_][A-Za-z0-9_]*adsync_RequestHiveStandby\(\))', 'tadsync_RequestHiveStandby()', &count)
    if (count > 0) {
        c := cNew
        FileAppend("✓ Fixed malformed TadSync hive-standby hook in nm_toBooster()`n", logFile)
    }
    if !InStr(c, 'tadsync_RequestHiveStandby()') {
        pattern := '(nm_toBooster\(location\)\{\r?\n\s*global [^\r\n]*\r?\n\s*static [^\r\n]*\r?\n)'
        cNew := RegExReplace(c, pattern, '$1`tadsync_RequestHiveStandby()`r`n', &count, 1)
        if (count > 0) {
            c := cNew
            FileAppend("✓ Added TadSync hive-standby request before booster travel`n", logFile)
        }
    }
    }

    ; 1c11. Sticker Stack reset behavior should depend on call site
    if (patchStickerStack) {
    if !InStr(c, 'nm_StickerStack(resetBeforeTravel := 1){') && InStr(c, 'nm_StickerStack(){') {
        cNew := StrReplace(c, 'nm_StickerStack(){', 'nm_StickerStack(resetBeforeTravel := 1){')
        if (cNew != c) {
            c := cNew
            FileAppend("✓ Added resetBeforeTravel parameter to nm_StickerStack()`n", logFile)
        }
    }
    if !InStr(c, 'ForceStickerStackInterrupt') && InStr(c, 'global StickerStackCheck, LastStickerStack, StickerStackItem, StickerStackMode, StickerStackTimer, StickerStackHive, StickerStackCub, StickerStackVoucher, SC_E, bitmaps') {
        cNew := StrReplace(c, 'global StickerStackCheck, LastStickerStack, StickerStackItem, StickerStackMode, StickerStackTimer, StickerStackHive, StickerStackCub, StickerStackVoucher, SC_E, bitmaps', 'global StickerStackCheck, LastStickerStack, StickerStackItem, StickerStackMode, StickerStackTimer, StickerStackHive, StickerStackCub, StickerStackVoucher, ForceStickerStackInterrupt, SC_E, bitmaps')
        if (cNew != c) {
            c := cNew
            FileAppend("✓ Added Force Sticker Stack global in nm_StickerStack()`n", logFile)
        }
    }
    if !InStr(c, 'forceAllowed := ForceStickerStackInterrupt && (StickerStackCheck = 1)') {
        cNew := StrReplace(c, 'if (StickerStackCheck && (nowUnix()-LastStickerStack)>StickerStackTimer) {', 'forceAllowed := ForceStickerStackInterrupt && (StickerStackCheck = 1) && (IsSet(MainGui) && IsObject(MainGui) ? (MainGui["StickerStackInterruptCheck"].Value = 1) : 0)`r`n`tif ((forceAllowed || StickerStackCheck) && (forceAllowed || (nowUnix()-LastStickerStack)>StickerStackTimer)) {')
        if (cNew != c) {
            c := cNew
            FileAppend("✓ Hardened forced Sticker Stack travel gate to respect both toggles`n", logFile)
        }
    }
    if !InStr(c, 'if (resetBeforeTravel)') && InStr(c, 'nm_StickerStack(resetBeforeTravel := 1){') {
        stickerResetPattern := '(?ms)(nm_StickerStack\(resetBeforeTravel := 1\)\{\r?\n.*?loop \d+ \{\r?\n)(\s*)nm_Reset\(1, 2000, 0\)'
        stickerResetReplace := '$1$2if (resetBeforeTravel)`r`n$2`tnm_Reset(1, 2000, 0)'
        cNew := RegExReplace(c, stickerResetPattern, stickerResetReplace, &stickerResetCount, 1)
        if (stickerResetCount > 0 && cNew != c) {
            c := cNew
            FileAppend("✓ Made nm_StickerStack() reset conditional on call site`n", logFile)
        }
    }
    if !InStr(c, 'global SkipBoostStickerStackUntil:=0') && InStr(c, 'global ConvertGatherFlag:=0') {
        cNew := StrReplace(c, 'global ConvertGatherFlag:=0', 'global ConvertGatherFlag:=0`r`n`tglobal SkipBoostStickerStackUntil:=0')
        if (cNew != c) {
            c := cNew
            FileAppend("✓ Added post-interrupt Sticker Stack boost suppression timer`n", logFile)
        }
    }
    canonicalStickerBoost := JoinLines(
        'nm_Boost(){',
        '`tglobal SkipBoostStickerStackUntil, StickerStackInterruptCheck, StickerStackCheck',
        '`tif(nm_NightInterrupt() || nm_MondoInterrupt())',
        '`t`treturn',
        '',
        '`tif (StickerStackCheck && !StickerStackInterruptCheck)',
        '`t`tnm_StickerStack()',
        '',
        '`tif ((QuestBoostCheck = 0) && QuestGatherField && (QuestGatherField != "None"))',
        '`t`treturn',
        '`ttry',
        '`t`tif (nm_PBoost() = 1)',
        '`t`t`treturn',
        '`tnm_shrine()',
        '`tnm_toAnyBooster()',
        '}'
    )
    if RegExMatch(c, '(?ms)^nm_Boost\(\)\{.*?^\}\r?\n(?=nm_StickerStack\(resetBeforeTravel := 1\)\{)', &stickerBoostMatch) {
        desiredStickerBoost := canonicalStickerBoost "`r`n"
        if (stickerBoostMatch[0] != desiredStickerBoost) {
            c := StrReplace(c, stickerBoostMatch[0], desiredStickerBoost)
            FileAppend("✓ Normalized nm_Boost() Sticker Stack suppression flow`n", logFile)
        }
    }
    canonicalStickerStack := ReadPatchBlock(patchTemplateDir "\stickerstack_full_patch.txt")
    if (canonicalStickerStack = "") {
        FileAppend("⚠ Skipped Sticker Stack sync because patch_templates\\stickerstack_full_patch.txt is missing`n", logFile)
    } else if RegExMatch(c, '(?ms)^nm_StickerStack\(resetBeforeTravel := 1\)\{.*?^\}\r?\n(?=nm_shrine\(\)\{)', &stickerStackMatch) {
        desiredStickerStack := canonicalStickerStack "`r`n"
        if (stickerStackMatch[0] != desiredStickerStack) {
            c := StrReplace(c, stickerStackMatch[0], desiredStickerStack)
            FileAppend("✓ Normalized nm_StickerStack() to stack-first retry flow`n", logFile)
        }
    }

    ; 1c12. Route reset-time conversion through the Sticker Stack helper first
    if !InStr(c, 'if !nm_HandleStickerStackInterrupt(1, 0, 0)') {
        resetConvertPattern := 'm)^(\s*)\(convert=1\)\s*&&\s*nm_convert\(\)\s*$'
        resetConvertReplace := '$1if (convert=1) {`r`n$1`tif !nm_HandleStickerStackInterrupt(1, 0, 0)`r`n$1`t`tnm_convert()`r`n$1}'
        cNew := RegExReplace(c, resetConvertPattern, resetConvertReplace, &resetConvertCount, 1)
        if (resetConvertCount > 0 && cNew != c) {
            c := cNew
            FileAppend("✓ Routed nm_Reset() conversion through Sticker Stack helper`n", logFile)
        }
    }
    }

    ; 1d. Global Variables
    if (patchTadSyncCore) {
    if (pos := InStr(c, 'nm_GoGather(){')) {
        ; Find the global block within this function
        if (globalPos := InStr(c, "global ", , pos)) {
            ; Only insert if not already present in the vicinity of nm_GoGather
            if !InStr(SubStr(c, pos, 1000), 'AltHopMondoEnabled') {
                if (endPos := InStr(c, "`n", , globalPos)) {
                    insertVars := '`r`n`t`t, FollowingField, FollowingLeader, FollowingStartTime, FieldFollowingMaxTime, FieldFollowingCheck, FieldFollowingFollowMode, LastAnnouncedField, AltHopMondoEnabled, AltHopMondoLeadTime, AltHopMondoState, AltHopMondoLastTime'
                    c := SubStr(c, 1, endPos-1) insertVars SubStr(c, endPos)
                    FileAppend("âœ“ Added global variables in nm_GoGather`n", logFile)
                }
            }
        }
    }
    }

    ; 1d2. BFB globals and gather hooks
    if (patchBfb || patchStickerStack) {
    if (goGatherPos := InStr(c, 'nm_GoGather(){')) {
        goGatherHead := SubStr(c, goGatherPos, 2000)
        if !InStr(goGatherHead, 'BlueBoosterInterruptCheck') {
            goGatherGlobalsPattern := '(\s*, BoostChaserCheck, LastBlueBoost, LastRedBoost, LastMountainBoost, FieldBooster3, FieldBooster2, FieldBooster1, FieldDefault)(, LastMicroConverter, HiveConfirmed)'
            cNew := RegExReplace(c, goGatherGlobalsPattern, '$1, BlueBoosterInterruptCheck, LastBlueBoostUse$2', &goGatherGlobalsCount, 1)
            if (goGatherGlobalsCount > 0 && cNew != c) {
                c := cNew
                FileAppend("✓ Added BFB globals in nm_GoGather()`n", logFile)
            }
        }
        if !InStr(goGatherHead, 'StickerStackInterruptCheck') {
            stickerGoGatherGlobalsPattern := '(\s*, BoostChaserCheck, LastBlueBoost, LastRedBoost, LastMountainBoost, FieldBooster3, FieldBooster2, FieldBooster1, FieldDefault(?:, BlueBoosterInterruptCheck, LastBlueBoostUse)?)(, LastMicroConverter, HiveConfirmed)'
            cNew := RegExReplace(c, stickerGoGatherGlobalsPattern, '$1, LastStickerStackUse, StickerStackTimer, StickerStackCheck, StickerStackInterruptCheck$2', &stickerGoGatherGlobalsCount, 1)
            if (stickerGoGatherGlobalsCount > 0 && cNew != c) {
                c := cNew
                FileAppend("✓ Added Sticker Stack globals in nm_GoGather()`n", logFile)
            }
        }
    }
    if (goGatherPos := InStr(c, 'nm_GoGather(){')) {
        goGatherHead := SubStr(c, goGatherPos, 800)
        if !InStr(goGatherHead, 'nm_HandleStickerStackInterrupt(1, 0, 1)') {
            preStackPattern := '(?m)(^\tif nm_MondoInterrupt\(\)\r?\n^\t\treturn\r?\n)(?!^\tif nm_HandleStickerStackInterrupt\(1, 0, 1\)\r?\n^\t\treturn)'
            preStackInsert := '$1`tif nm_HandleStickerStackInterrupt(1, 0, 1)`r`n`t`treturn`r`n'
            cNew := RegExReplace(c, preStackPattern, preStackInsert, &preStackCount, 1)
            if (preStackCount > 0 && cNew != c) {
                c := cNew
                FileAppend("✓ Added immediate Sticker Stack handling in nm_GoGather()`n", logFile)
            }
        }
    }
    if !InStr(c, 'nm_toBooster("blue")`r`n`t`treturn') {
        preBfbPattern := '(?m)(^\tif nm_MondoInterrupt\(\)\r?\n^\t\treturn\r?\n)(?!^\tif nm_BlueBoosterInterrupt\(\) \{)'
        preBfbInsert := '$1`tif nm_BlueBoosterInterrupt() {`r`n`t`tnm_toBooster("blue")`r`n`t`treturn`r`n`t}`r`n'
        cNew := RegExReplace(c, preBfbPattern, preBfbInsert, &preBfbCount, 1)
        if (preBfbCount > 0 && cNew != c) {
            c := cNew
            FileAppend("✓ Added immediate BFB jump in nm_GoGather()`n", logFile)
        }
    }
    goGatherImmediateBad := JoinLines(
        '	if nm_BlueBoosterInterrupt() {',
        '		nm_toBooster("blue")',
        '		return',
        '	}',
        '	if nm_HandleStickerStackInterrupt(1, 0, 1)',
        '		return'
    )
    goGatherImmediateGood := JoinLines(
        '	if nm_HandleStickerStackInterrupt(1, 0, 1)',
        '		return',
        '	if nm_BlueBoosterInterrupt() {',
        '		nm_toBooster("blue")',
        '		return',
        '	}'
    )
    cNew := StrReplace(c, goGatherImmediateBad, goGatherImmediateGood)
    if (cNew != c) {
        c := cNew
        FileAppend("✓ Normalized Sticker Stack before BFB in nm_GoGather()`n", logFile)
    }
    if !InStr(c, 'if nm_BlueBoosterInterrupt() {`r`n					interruptReason := "Blue Booster Ready"`r`n					break`r`n				}`r`n				if DisconnectCheck() {') {
        highBfbNeedle := '				if DisconnectCheck() {'
        highBfbInsert := JoinLines(
            '				if nm_BlueBoosterInterrupt() {',
            '					interruptReason := "Blue Booster Ready"',
            '					break',
            '				}',
            highBfbNeedle
        )
        cNew := StrReplace(c, highBfbNeedle, highBfbInsert)
        if (cNew != c) {
            c := cNew
            FileAppend("✓ Added high-priority BFB gather interrupt`n", logFile)
        }
    }
    stackGatherOld := JoinLines(
        '				if nm_StickerStackInterrupt() {',
        '					interruptReason := "Sticker Stack Ready"',
        '					break',
        '				}'
    )
    stackGatherNew := JoinLines(
        '				if nm_StickerStackInterrupt() {',
        '					Click "Up"',
        '					nm_endWalk()',
        '					nm_setShiftLock(0)',
        '					nm_HandleStickerStackInterrupt(1, 1, 1)',
        '					return',
        '				}'
    )
    cNew := StrReplace(c, stackGatherOld, stackGatherNew)
    if (cNew != c) {
        c := cNew
        FileAppend("✓ Upgraded gather Sticker Stack interrupt to immediate reset handling`n", logFile)
    }
    if !InStr(c, stackGatherNew) {
        stackHighNeedle := '				if DisconnectCheck() {'
        stackHighInsert := JoinLines(
            stackGatherNew,
            stackHighNeedle
        )
        cNew := StrReplace(c, stackHighNeedle, stackHighInsert)
        if (cNew != c) {
            c := cNew
            FileAppend("✓ Added high-priority Sticker Stack gather reset path`n", logFile)
        }
    }
    gatherHighBad := JoinLines(
        '				if nm_BlueBoosterInterrupt() {',
        '					interruptReason := "Blue Booster Ready"',
        '					break',
        '				}',
        '				if nm_StickerStackInterrupt() {',
        '					Click "Up"',
        '					nm_endWalk()',
        '					nm_setShiftLock(0)',
        '					nm_HandleStickerStackInterrupt(1, 1, 1)',
        '					return',
        '				}'
    )
    gatherHighGood := JoinLines(
        '				if nm_StickerStackInterrupt() {',
        '					Click "Up"',
        '					nm_endWalk()',
        '					nm_setShiftLock(0)',
        '					nm_HandleStickerStackInterrupt(1, 1, 1)',
        '					return',
        '				}',
        '				if nm_BlueBoosterInterrupt() {',
        '					interruptReason := "Blue Booster Ready"',
        '					break',
        '				}'
    )
    cNew := StrReplace(c, gatherHighBad, gatherHighGood)
    if (cNew != c) {
        c := cNew
        FileAppend("✓ Normalized Sticker Stack before BFB in gather interrupts`n", logFile)
    }
    lowBfbPattern := '(?ms)(^\s*if nm_GatherBoostInterrupt\(\)\r?\n\s*continue\r?\n)(?!\s*if nm_BlueBoosterInterrupt\(\) \{\r?\n\s*interruptReason := "Blue Booster Ready")'
    lowBfbInsert := '$1				if nm_BlueBoosterInterrupt() {`r`n					interruptReason := "Blue Booster Ready"`r`n					break`r`n				}`r`n'
    cNew := RegExReplace(c, lowBfbPattern, lowBfbInsert, &lowBfbCount, 1)
    if (lowBfbCount > 0 && cNew != c) {
        c := cNew
        FileAppend("✓ Added low-priority BFB gather interrupt`n", logFile)
    }
    if !InStr(c, 'if (interruptReason = "Sticker Stack Ready") {') {
        stackSpecialPattern := '(?m)^(\t\s*nm_endWalk\(\)\r?\n)'
        stackSpecialInsert :=
        (
            '$1'
            '`r`n`tif (interruptReason = "Sticker Stack Ready") {'
            '`r`n`t`tif(GatherStartTime) {'
            '`r`n`t`t`tTotalGatherTime:=TotalGatherTime+(nowUnix()-GatherStartTime)'
            '`r`n`t`t`tSessionGatherTime:=SessionGatherTime+(nowUnix()-GatherStartTime)'
            '`r`n`t`t}'
            '`r`n`t`tGatherStartTime:=0'
            '`r`n`t`tnm_setShiftLock(0)'
            '`r`n`t`tnm_HandleStickerStackInterrupt(1, 1, 1)'
            '`r`n`t`treturn'
            '`r`n`t}'
            '`r`n'
        )
        cNew := RegExReplace(c, stackSpecialPattern, stackSpecialInsert, &stackSpecialCount, 1)
        if (stackSpecialCount > 0 && cNew != c) {
            c := cNew
            FileAppend("✓ Added Sticker Stack post-gather handling path`n", logFile)
        }
    }
    cNew := StrReplace(c, 'nm_findHiveSlot(){', 'nm_findHiveSlot(convertAfter := 1, forceBalloonConvert := 0){')
    if (cNew != c) {
        c := cNew
        FileAppend("✓ Updated nm_findHiveSlot() signature for post-stack resume`n", logFile)
    }

    findHiveConvertNeedle := JoinLines(
        '			if nm_ConfirmAtHive() {',
        '				nm_convert()',
        '				break',
        '			}'
    )
    findHiveConvertInsert := JoinLines(
        '			if nm_ConfirmAtHive() {',
        '				if (convertAfter)',
        '					nm_convert(0, forceBalloonConvert)',
        '				break',
        '			}'
    )
    cNew := StrReplace(c, findHiveConvertNeedle, findHiveConvertInsert)
    if (cNew != c) {
        c := cNew
        FileAppend("✓ Routed nm_findHiveSlot() convert through post-stack resume flags`n", logFile)
    }

    cNew := StrReplace(c, 'nm_convert(){', 'nm_convert(ignoreActiveConvertState := 0, forceBalloonConvert := 0){')
    if (cNew != c) {
        c := cNew
        FileAppend("✓ Updated nm_convert() signature for resume-after-stack`n", logFile)
    }

    cNew := StrReplace(c, 'nm_convert(ignoreActiveConvertState := 0){', 'nm_convert(ignoreActiveConvertState := 0, forceBalloonConvert := 0){')
    if (cNew != c) {
        c := cNew
        FileAppend("✓ Added forceBalloonConvert parameter to nm_convert()`n", logFile)
    }

    cNew := StrReplace(c, 'if ((HiveConfirmed = 0) || (state = "Converting") || (Gdip_ImageSearch(pBMScreen, bitmaps["e_button"], , , , , , 2, , 6) = 0)) {', 'if ((HiveConfirmed = 0) || (!ignoreActiveConvertState && state = "Converting") || (Gdip_ImageSearch(pBMScreen, bitmaps["e_button"], , , , , , 2, , 6) = 0)) {')
    if (cNew != c) {
        c := cNew
        FileAppend("✓ Updated nm_convert() active-convert guard for resume-after-stack`n", logFile)
    }

    cNew := StrReplace(c
        , 'if((ConvertBalloon="always") || (ConvertBalloon="Every" && (nowUnix() - LastConvertBalloon)>(ConvertMins*60)) || (ConvertBalloon="Gather" && (ConvertGatherFlag=1 || (nowUnix() - LastConvertBalloon)>2700))) {'
        , 'if(forceBalloonConvert || (ConvertBalloon="always") || (ConvertBalloon="Every" && (nowUnix() - LastConvertBalloon)>(ConvertMins*60)) || (ConvertBalloon="Gather" && (ConvertGatherFlag=1 || (nowUnix() - LastConvertBalloon)>2700))) {'
    )
    if (cNew != c) {
        c := cNew
        FileAppend("✓ Added forceBalloonConvert gate to balloon conversion branch`n", logFile)
    }

    if (convertPos := InStr(c, 'nm_convert(ignoreActiveConvertState := 0, forceBalloonConvert := 0){')) {
        convertHead := SubStr(c, convertPos, 1200)
        if !InStr(convertHead, 'LastStickerStackUse') {
            convertGlobalsPattern := '(\s*, GameFrozenCounter, LastConvertBalloon, ConvertBalloon, ConvertMins, HiveBees, ConvertGatherFlag)(\r?\n)'
            cNew := RegExReplace(c, convertGlobalsPattern, '$1, LastStickerStackUse, LastStickerStack, StickerStackCheck, StickerStackTimer$2', &convertGlobalsCount, 1)
            if (convertGlobalsCount > 0 && cNew != c) {
                c := cNew
                FileAppend("✓ Added Sticker Stack globals in nm_convert()`n", logFile)
            }
        }
        if !InStr(convertHead, 'EnzymesBoostedOnly') {
            enzymeConvertGlobalsPattern := '(\s*, GameFrozenCounter, LastConvertBalloon, ConvertBalloon, ConvertMins, HiveBees, ConvertGatherFlag(?:, LastStickerStackUse, LastStickerStack, StickerStackCheck, StickerStackTimer)?)(\r?\n)'
            cNew := RegExReplace(c, enzymeConvertGlobalsPattern, '$1, EnzymesBoostedOnly$2', &enzymeConvertGlobalsCount, 1)
            if (enzymeConvertGlobalsCount > 0 && cNew != c) {
                c := cNew
                FileAppend("✓ Added EnzymesBoostedOnly global in nm_convert()`n", logFile)
            }
        }
    }
    if (convertPos := InStr(c, 'nm_convert(ignoreActiveConvertState := 0, forceBalloonConvert := 0){')) {
        convertHead := SubStr(c, convertPos, 400)
        if !InStr(convertHead, 'nm_HandleStickerStackInterrupt(1, 0, 0)') {
            convertStartPattern := '(?m)(^\tif \(nm_NightInterrupt\(\) \|\| nm_MondoInterrupt\(\)\)\r?\n^\t\treturn\r?\n)'
            convertStartInsert := '$1`tif nm_HandleStickerStackInterrupt(1, 0, 0)`r`n`t`treturn`r`n'
            cNew := RegExReplace(c, convertStartPattern, convertStartInsert, &convertStartCount, 1)
            if (convertStartCount > 0 && cNew != c) {
                c := cNew
                FileAppend("✓ Added Sticker Stack check at start of nm_convert()`n", logFile)
            }
        }
    }
    convertStartNormalizePattern := '(?m)(^\tif \(nm_NightInterrupt\(\) \|\| nm_MondoInterrupt\(\)\)\r?\n^\t\treturn\r?\n)(?:^\tif nm_HandleStickerStackInterrupt\(1, 0, 0\)\r?\n^\t\treturn\r?\n)+(\r?\n^\thwnd := GetRobloxHWND\(\))'
    convertStartNormalizeReplace := '$1`tif nm_HandleStickerStackInterrupt(1, 0, 0)`r`n`t`treturn$2'
    cNew := RegExReplace(c, convertStartNormalizePattern, convertStartNormalizeReplace, &convertStartNormalizeCount, 1)
    if (convertStartNormalizeCount > 0 && cNew != c) {
        c := cNew
        FileAppend("✓ Normalized nm_convert() startup Sticker Stack checks to working layout`n", logFile)
    }
    if (convertPos := InStr(c, 'nm_convert(ignoreActiveConvertState := 0, forceBalloonConvert := 0){')) {
        convertDisconnectPattern := '(?m)(^([ \t]*)if \(disconnectcheck\(\)\) \{\r?\n^\2[ \t]*return\r?\n^\2\})(?!\r?\n^\2if nm_HandleStickerStackInterrupt\(1, 0, 0\)\r?\n^\2[ \t]*return)(\r?\n^\2if \((?:\(PFieldBoosted = 1\)|PFieldBoosted) [^\r\n]*)'
        convertDisconnectInsert := '$1`r`n$2if nm_HandleStickerStackInterrupt(1, 0, 0)`r`n$2`treturn$3'
        cNew := RegExReplace(c, convertDisconnectPattern, convertDisconnectInsert, &convertLoopCount)
        if (convertLoopCount > 0 && cNew != c) {
            c := cNew
            FileAppend("✓ Added Sticker Stack checks inside nm_convert() loops`n", logFile)
        }
    }
    backpackStackNeedle := JoinLines(
        '			if (disconnectcheck()) {',
        '				return',
        '			}',
        '			if nm_HandleStickerStackInterrupt(1, 0, 0)',
        '				return',
        '			if (PFieldBoosted && (nowUnix()-GatherFieldBoostedStart)>780 && (nowUnix()-GatherFieldBoostedStart)<900 && (nowUnix()-LastGlitter)>900 && GlitterKey!="none") {'
    )
    backpackStackReplace := JoinLines(
        '			if (disconnectcheck()) {',
        '				return',
        '			}',
        '			if (PFieldBoosted && (nowUnix()-GatherFieldBoostedStart)>780 && (nowUnix()-GatherFieldBoostedStart)<900 && (nowUnix()-LastGlitter)>900 && GlitterKey!="none") {'
    )
    cNew := StrReplace(c, backpackStackNeedle, backpackStackReplace)
    if (cNew != c) {
        c := cNew
        FileAppend("✓ Removed repeated Sticker Stack checks from backpack convert loop`n", logFile)
    }
    balloonAfbNeedle := JoinLines(
        '				if(AFBuseGlitter || AFBuseBooster) {',
        '					nm_setStatus("Interrupted", "AFB")',
        '					return',
        '				}',
        '				inactiveHoney := (nm_activeHoney() = 0) ? inactiveHoney + 1 : 0'
    )
    balloonAfbReplace := JoinLines(
        '				if(AFBuseGlitter || AFBuseBooster) {',
        '					nm_setStatus("Interrupted", "AFB")',
        '					return',
        '				}',
        '				if nm_HandleStickerStackInterrupt(1, 0, 0)',
        '					return',
        '				inactiveHoney := (nm_activeHoney() = 0) ? inactiveHoney + 1 : 0'
    )
    cNew := StrReplace(c, balloonAfbNeedle, balloonAfbReplace)
    if (cNew != c) {
        c := cNew
        FileAppend("✓ Prioritized Sticker Stack checks earlier in balloon convert loop`n", logFile)
    }
    balloonPreRefreshNeedle := JoinLines(
        '				nm_setStatus("Converting", "Balloon Refreshed")',
        '				IniWrite LastConvertBalloon:=nowUnix(), "settings\nm_config.ini", "Settings", "LastConvertBalloon"',
        '				PostSubmacroMessage("background", 0x5554, 6, LastConvertBalloon)',
        '				strikes := 10'
    )
    balloonPreRefreshReplace := JoinLines(
        '				nm_setStatus("Converting", "Balloon Refreshed")',
        '				IniWrite LastConvertBalloon:=nowUnix(), "settings\nm_config.ini", "Settings", "LastConvertBalloon"',
        '				PostSubmacroMessage("background", 0x5554, 6, LastConvertBalloon)',
        '				if nm_HandleStickerStackInterrupt(1, 0, 0)',
        '					return',
        '				strikes := 10'
    )
    cNew := StrReplace(c, balloonPreRefreshNeedle, balloonPreRefreshReplace)
    if (cNew != c) {
        c := cNew
        FileAppend("✓ Added immediate Sticker Stack check after balloon refresh detection`n", logFile)
    }
    balloonBreakNeedle := JoinLines(
        '					Gdip_DisposeImage(pBMScreen)',
        '					ballooncomplete:=1',
        '					break'
    )
    balloonBreakReplace := JoinLines(
        '					Gdip_DisposeImage(pBMScreen)',
        '					ballooncomplete:=1',
        '					if nm_HandleStickerStackInterrupt(1, 0, 0)',
        '						return',
        '					break'
    )
    cNew := StrReplace(c, balloonBreakNeedle, balloonBreakReplace)
    if (cNew != c) {
        c := cNew
        FileAppend("✓ Added last-moment Sticker Stack check before balloon convert completes`n", logFile)
    }
    balloonSleepNeedle := JoinLines(
        '				Gdip_DisposeImage(pBMScreen)',
        '				Sleep 1000',
        '			}',
        '			if(ballooncomplete){'
    )
    balloonSleepReplace := JoinLines(
        '				Gdip_DisposeImage(pBMScreen)',
        '				Loop 10 {',
        '					Sleep 100',
        '					if nm_HandleStickerStackInterrupt(1, 0, 0)',
        '						return',
        '				}',
        '			}',
        '			if(ballooncomplete){'
    )
    cNew := StrReplace(c, balloonSleepNeedle, balloonSleepReplace)
    if (cNew != c) {
        c := cNew
        FileAppend("✓ Increased Sticker Stack polling frequency during balloon convert`n", logFile)
    }
    balloonFinalRefreshNeedle := JoinLines(
        '				nm_setStatus("Converting", "Balloon Refreshed`nTime: " duration)',
        '				IniWrite LastConvertBalloon:=nowUnix(), "settings\nm_config.ini", "Settings", "LastConvertBalloon"',
        '				PostSubmacroMessage("background", 0x5554, 6, LastConvertBalloon)'
    )
    balloonFinalRefreshReplace := JoinLines(
        '				nm_setStatus("Converting", "Balloon Refreshed`nTime: " duration)',
        '				IniWrite LastConvertBalloon:=nowUnix(), "settings\nm_config.ini", "Settings", "LastConvertBalloon"',
        '				PostSubmacroMessage("background", 0x5554, 6, LastConvertBalloon)',
        '				if nm_HandleStickerStackInterrupt(1, 0, 0)',
        '					return'
    )
    cNew := StrReplace(c, balloonFinalRefreshNeedle, balloonFinalRefreshReplace)
    if (cNew != c) {
        c := cNew
        FileAppend("✓ Jumped to Sticker Stack immediately after balloon refresh bookkeeping`n", logFile)
    }
    }

    if InStr(c, 'MainGui["HBText" i].Text := PFieldBoosted ? "@ Boosted" : "@ Converting Balloon"') {
        c := StrReplace(c, 'MainGui["HBText" i].Text := PFieldBoosted ? "@ Boosted" : "@ Converting Balloon"', 'MainGui["HBText" i].Text := "@ Balloon Convert"')
        FileAppend("✓ Updated enzyme hotbar label to balloon convert only`n", logFile)
    }

    if InStr(c, 'if(((EnzymesKey!="none") && (!PFieldBoosted || (PFieldBoosted && GatherFieldBoosted))) && (nowUnix()-LastEnzymes)>600 && (inactiveHoney = 0)) {') {
        c := StrReplace(c
            , 'if(((EnzymesKey!="none") && (!PFieldBoosted || (PFieldBoosted && GatherFieldBoosted))) && (nowUnix()-LastEnzymes)>600 && (inactiveHoney = 0)) {'
            , 'if ((EnzymesKey != "none")`r`n`t`t`t`t`t&& (!EnzymesBoostedOnly || nm_GatherBoostInterrupt())`r`n`t`t`t`t`t&& (nowUnix() - LastEnzymes) > 600`r`n`t`t`t`t`t&& (inactiveHoney = 0)) {`r`n`t`t`t`t`tnm_setStatus("Converting", "Balloon``nUsed Enzyme")'
        )
        FileAppend("✓ Updated enzyme balloon-convert condition to use boost timing`n", logFile)
    }

    if InStr(c, '&& (!EnzymesBoostedOnly || (PFieldBoosted && GatherFieldBoosted))') {
        c := StrReplace(c
            , '&& (!EnzymesBoostedOnly || (PFieldBoosted && GatherFieldBoosted))'
            , '&& (!EnzymesBoostedOnly || nm_GatherBoostInterrupt())'
        )
        FileAppend("✓ Switched enzyme boosted-only check to nm_GatherBoostInterrupt()`n", logFile)
    }


    ; 1e. Override Logic
    if (patchTadSyncCore) {
    if !InStr(c, "tadsync_ApplyFollowingOverride") {
        if (pos := InStr(c, ";FIELD OVERRIDES")) {
            if (loopPos := InStr(c, "loop 1 {", , pos)) {
                if (endLoopPos := InStr(c, "`n", , loopPos)) {
                    overrideCode := '`t`tif (tadsync_ApplyFollowingOverride(&FieldName, &FieldPattern, &FieldPatternSize, &FieldPatternReps, &FieldPatternShift, &FieldPatternInvertFB, &FieldPatternInvertLR, &FieldUntilMins, &FieldUntilPack, &FieldReturnType, &FieldSprinklerLoc, &FieldSprinklerDist, &FieldRotateDirection, &FieldRotateTimes, &FieldDriftCheck, &fieldOverrideReason))`r`n`t`t`tbreak`r`n'
                    c := SubStr(c, 1, endLoopPos) overrideCode SubStr(c, endLoopPos+1)
                    FileAppend("âœ“ Added Override logic to nm_GoGather`n", logFile)
                }
            }
        }
    }

    ; 1e1. Boosted-field trace logging
    if !InStr(c, 'tadsync_LogBoostScan("gather-scan-start"') {
        scanStartNeedle := '`t`tif(BoostChaserCheck){'
        scanStartInsert := '`r`n`t`t`t`ttadsync_LogBoostScan("gather-scan-start", CurrentField, RecentFBoost)'
        c := StrReplace(c, scanStartNeedle, scanStartNeedle scanStartInsert)
        if (c != orig)
            FileAppend("✓ Added boosted-field scan-start trace`n", logFile)
    }
    if !InStr(c, 'tadsync_LogBoostScan("gather-scan-picked"') {
        pickNeedle := '`t`t`tif(BoostChaserField!="none") {'
        pickInsert := '`r`n`t`t`t`t`ttadsync_LogBoostScan("gather-scan-picked", CurrentField, RecentFBoost, BoostChaserField)'
        c := StrReplace(c, pickNeedle, pickNeedle pickInsert)
        if (c != orig)
            FileAppend("✓ Added boosted-field picked trace`n", logFile)
    }
    if !InStr(c, 'tadsync_LogBoostScan("gather-scan-none"') {
        noneNeedle := '`t`t`t;set field override'
        noneInsert := '`t`t`tif(BoostChaserField="none")`r`n`t`t`t`ttadsync_LogBoostScan("gather-scan-none", CurrentField, RecentFBoost)`r`n'
        c := StrReplace(c, noneNeedle, noneInsert noneNeedle)
        if (c != orig)
            FileAppend("✓ Added boosted-field none trace`n", logFile)
    }

    ; 1e2. Prefer the most recently detected boosted field before falling back to fixed scan order.
    cleanupPattern := '\r?\n\s*(?:boostExtendActive := .*?\r?\n\s*)?if \(RecentFBoost != "None" && recentBoostEnabled && (?:nm_fieldBoostCheck\(RecentFBoost, 1\)|\(\(nowUnix\(\)-GatherFieldBoostedStart\) < 900\)|\(\(\(nowUnix\(\)-GatherFieldBoostedStart\) < 900\) \|\| boostExtendActive\))\) \{\r?\n\s*BoostChaserField:=RecentFBoost\r?\n\s*break\r?\n\s*\}'
    c := RegExReplace(c, cleanupPattern, '')
    if !InStr(c, 'BoostChaserField:=RecentFBoost') {
        pattern := '(BoostChaserField:="None"\r?\n\s*blueBoosterFields[^\r\n]*\r?\n\s*redBoosterFields[^\r\n]*\r?\n\s*mountainBoosterfields[^\r\n]*\r?\n\s*coconutBoosterfields[^\r\n]*\r?\n\s*otherFields[^\r\n]*)(\r?\n\s*loop 1 \{\r?\n)'
        replacement :=
        (
            '$1'
            '`r`n`r`n`t`t`trecentBoostEnabled := 0'
            '`r`n`t`t`tif (RecentFBoost = "Pine Tree")'
            '`r`n`t`t`t`trecentBoostEnabled := PineTreeBoosterCheck'
            '`r`n`t`t`telse if (RecentFBoost = "Bamboo")'
            '`r`n`t`t`t`trecentBoostEnabled := BambooBoosterCheck'
            '`r`n`t`t`telse if (RecentFBoost = "Blue Flower")'
            '`r`n`t`t`t`trecentBoostEnabled := BlueFlowerBoosterCheck'
            '`r`n`t`t`telse if (RecentFBoost = "Stump")'
            '`r`n`t`t`t`trecentBoostEnabled := StumpBoosterCheck'
            '`r`n`t`t`telse if (RecentFBoost = "Rose")'
            '`r`n`t`t`t`trecentBoostEnabled := RoseBoosterCheck'
            '`r`n`t`t`telse if (RecentFBoost = "Strawberry")'
            '`r`n`t`t`t`trecentBoostEnabled := StrawberryBoosterCheck'
            '`r`n`t`t`telse if (RecentFBoost = "Mushroom")'
            '`r`n`t`t`t`trecentBoostEnabled := MushroomBoosterCheck'
            '`r`n`t`t`telse if (RecentFBoost = "Pepper")'
            '`r`n`t`t`t`trecentBoostEnabled := PepperBoosterCheck'
            '`r`n`t`t`telse if (RecentFBoost = "Cactus")'
            '`r`n`t`t`t`trecentBoostEnabled := CactusBoosterCheck'
            '`r`n`t`t`telse if (RecentFBoost = "Pumpkin")'
            '`r`n`t`t`t`trecentBoostEnabled := PumpkinBoosterCheck'
            '`r`n`t`t`telse if (RecentFBoost = "Pineapple")'
            '`r`n`t`t`t`trecentBoostEnabled := PineappleBoosterCheck'
            '`r`n`t`t`telse if (RecentFBoost = "Spider")'
            '`r`n`t`t`t`trecentBoostEnabled := SpiderBoosterCheck'
            '`r`n`t`t`telse if (RecentFBoost = "Clover")'
            '`r`n`t`t`t`trecentBoostEnabled := CloverBoosterCheck'
            '`r`n`t`t`telse if (RecentFBoost = "Dandelion")'
            '`r`n`t`t`t`trecentBoostEnabled := DandelionBoosterCheck'
            '`r`n`t`t`telse if (RecentFBoost = "Sunflower")'
            '`r`n`t`t`t`trecentBoostEnabled := SunflowerBoosterCheck'
            '`r`n`t`t`telse if (RecentFBoost = "Coconut")'
            '`r`n`t`t`t`trecentBoostEnabled := CoconutBoosterCheck'
            '`r`n`t`t`telse if (RecentFBoost = "Mountain Top")'
            '`r`n`t`t`t`trecentBoostEnabled := 1'
            '`r`n`t`t`tboostExtendActive := PFieldBoostExtend && ((nowUnix()-GatherFieldBoostedStart) < 1800) && ((nowUnix()-LastGlitter) < 900)'
            '$2'
            '`t`t`t`tif (RecentFBoost != "None" && recentBoostEnabled && (((nowUnix()-GatherFieldBoostedStart) < 900) || boostExtendActive)) {'
            '`r`n`t`t`t`t`tBoostChaserField:=RecentFBoost'
            '`r`n`t`t`t`t`tbreak'
            '`r`n`t`t`t`t}'
        )
        cNew := RegExReplace(c, pattern, replacement, &count, 1)
        if (count > 0) {
            c := cNew
            FileAppend("✓ Added RecentFBoost preference to boosted-field scan`n", logFile)
        }
    }
    if !InStr(c, 'tadsync_LogBoosterDetected(location, v)') {
        boostDetectNeedle := 'nm_setStatus("Boosted", v), RecentFBoost := v'
        boostDetectReplace := 'nm_setStatus("Boosted", v), RecentFBoost := v, tadsync_LogBoosterDetected(location, v)'
        c := StrReplace(c, boostDetectNeedle, boostDetectReplace)
        if (c != orig)
            FileAppend("✓ Added booster-detected trace`n", logFile)
    }
    boosterPersistPattern := '(?ms)if nm_fieldBoostCheck\(v, [01]\)\s*\{\s*nm_setStatus\("Boosted", v\), RecentFBoost := v(?:, tadsync_LogBoosterDetected\(location, v\))?\s*break 2\s*\}'
    ; Keep variant 0 here so winds do not masquerade as a fresh booster icon.
    boosterPersistReplacement :=
    (
        '`t`t`t`tif nm_fieldBoostCheck(v, 0)`r`n'
        . '`t`t`t`t{`r`n'
        . '`t`t`t`t`tnm_setStatus("Boosted", v), RecentFBoost := v, tadsync_LogBoosterDetected(location, v)`r`n'
        . '`t`t`t`t`tboostDetectedAt := nowUnix()`r`n'
        . '`t`t`t`t`tIniWrite(v, "settings\nm_config.ini", "Boost", "LastBoostedField")`r`n'
        . '`t`t`t`t`tIniWrite(boostDetectedAt, "settings\nm_config.ini", "Boost", "LastBoostedTime")`r`n'
        . '`t`t`t`t`tbreak 2`r`n'
        . '`t`t`t`t}'
    )
    cNew := RegExReplace(c, boosterPersistPattern, boosterPersistReplacement, &boosterPersistCount, 1)
    if (boosterPersistCount > 0 && cNew != c) {
        c := cNew
        FileAppend("✓ Persisted booster-detected field immediately in nm_toBooster()`n", logFile)
    }

    ; 1f. Leader Announcement
    if !InStr(c, "tadsync_CheckAnnounceField") {
        if (pos := InStr(c, 'nm_updateAction("Gather")')) {
            announceCode := '`t;announce field change if leader mode (TadSync)`r`n`tif (FieldFollowingCheck && FieldFollowingFollowMode="Leader" && LastAnnouncedField!=FieldName)`r`n`t`ttadsync_CheckAnnounceField(FieldName)`r`n`r`n`t'
            c := SubStr(c, 1, pos-1) announceCode SubStr(c, pos)
            FileAppend("âœ“ Added Announcement logic`n", logFile)
        }
    }
    if !InStr(c, 'tadsync_HandleHiveStandby()') {
        cNew := StrReplace(c, '`t;FIELD OVERRIDES', '`tif tadsync_HandleHiveStandby()`r`n`t`treturn`r`n`t;FIELD OVERRIDES')
        if (cNew != c) {
            c := cNew
            FileAppend("✓ Added TadSync hive-standby handling to nm_GoGather`n", logFile)
        }
    }

    ; 1k. Interrupt Logic
    oldFollowInterrupt := '`r`n`t`t`t`tif (FollowingLeader && (FieldName != FollowingField)) {`r`n`t`t`t`t`tinterruptReason := "Following"`r`n`t`t`t`t`tbreak`r`n`t`t`t`t}'
    newFollowInterrupt := '`r`n`t`t`t`tif tadsync_ShouldInterruptFollowing(FieldName) {`r`n`t`t`t`t`tinterruptReason := "Following"`r`n`t`t`t`t`tbreak`r`n`t`t`t`t}'
    if InStr(c, oldFollowInterrupt) {
        c := StrReplace(c, oldFollowInterrupt, newFollowInterrupt)
        FileAppend("✓ Updated TadSync follow interrupt to helper-based logic`n", logFile)
    }
    if !InStr(c, 'tadsync_ShouldInterruptFollowing(FieldName)') {
        if (pos := InStr(c, ";high priority interrupts")) {
            if (ifPos := InStr(c, "if (Mod(A_Index, 5) = 1) {", , pos)) {
                if (endIfPos := InStr(c, "{", , ifPos)) {
                    interruptCode := newFollowInterrupt
                    c := SubStr(c, 1, endIfPos) interruptCode SubStr(c, endIfPos+1)
                    FileAppend("âœ“ Added Interrupt logic to Gathering loop`n", logFile)
                }
            }
        }
    }

    ; 1g. Extensions tab registration
    if InStr(c, '"TadSync"') {
        c := StrReplace(c, '"TadSync"', '"Extensions"')
        FileAppend("✓ Renamed TadSync tab to Extensions`n", logFile)
    }
    if (tabArrPos := InStr(c, 'TabArr := ')) {
        tabArrBlock := SubStr(c, tabArrPos, 250)
        if InStr(tabArrBlock, '"Extensions"') {
            c := RegExReplace(c, '(TabArr\s*:=\s*\[)(.*?)(\])', '$1' ReorderExtensionsTabs('$2') '$3', , 1)
            FileAppend("✓ Normalized Extensions position in TabArr`n", logFile)
        } else {
            pattern := '(TabArr\s*:=\s*\[)(.*?)(\])'
            c := RegExReplace(c, pattern, '$1$2, "Extensions"$3', , 1)
            FileAppend("✓ Added Extensions to TabArr`n", logFile)
        }
    }

    ; 1h. Extensions tab content
    oldMondoButton := 'MainGui.Add("Button", "x170 y40 w150 h20 vMondoHopGUI Disabled", "Mondo Hop").OnEvent("Click", aq_MondoHopGUI)'
    oldBoostGroup := 'MainGui.Add("GroupBox", "x15 y65 w470 h55", "TadSync Boosted")'
    oldBoostedTabLine := 'MainGui.Add("CheckBox", "x25 y80 +center vPFieldBoosted Checked" PFieldBoosted, "Boosted Field``nBuffs").OnEvent("Click", aq_togglePFieldBoosted)'
    oldGlitterBoostLine1 := 'MainGui.Add("CheckBox", "x205 y106 w85 h30 +Center vPFieldBoosted Checked" PFieldBoosted, "Glitter``nExtend").OnEvent("Click", aq_togglePFieldBoosted)'
    oldGlitterBoostLine2 := 'MainGui.Add("CheckBox", "x198 y79 w95 h16 vPFieldBoosted Checked" PFieldBoosted, "Glitter Extend").OnEvent("Click", aq_togglePFieldBoosted)'
    oldGlitterBoostLine3 := 'MainGui.Add("CheckBox", "x198 y100 w95 h16 vPFieldBoosted Checked" PFieldBoosted, "Glitter Extend").OnEvent("Click", aq_togglePFieldBoosted)'
    oldBfbBoostLine1 := 'MainGui.Add("CheckBox", "x205 y110 w85 h30 +Center vBlueBoosterInterruptCheck Checked" BlueBoosterInterruptCheck, "BFB``nInterrupt").OnEvent("Click", nm_BlueBoosterToggle)'
    oldBfbBoostLine2 := 'MainGui.Add("CheckBox", "x205 y125 w85 h30 +Center vBlueBoosterInterruptCheck Checked" BlueBoosterInterruptCheck, "BFB``nInterrupt").OnEvent("Click", nm_BlueBoosterToggle)'
    oldBfbBoostLine3 := 'MainGui.Add("CheckBox", "x205 y136 w85 h30 +Center vBlueBoosterInterruptCheck Checked" BlueBoosterInterruptCheck, "BFB``nInterrupt").OnEvent("Click", nm_BlueBoosterToggle)'
    oldStickerBoostLine1 := 'MainGui.Add("CheckBox", "x205 y145 w85 h30 +Center vStickerStackInterruptCheck" . (StickerStackInterruptCheck ? " Checked" : ""), "Sticker Stack``nInterrupt").OnEvent("Click", nm_StickerStackToggle)'
    oldStickerBoostLine2 := 'MainGui.Add("CheckBox", "x205 y160 w85 h30 +Center vStickerStackInterruptCheck" . (StickerStackInterruptCheck ? " Checked" : ""), "Sticker Stack``nInterrupt").OnEvent("Click", nm_StickerStackToggle)'
    oldStickerBoostLine3 := 'MainGui.Add("CheckBox", "x205 y171 w85 h30 +Center vStickerStackInterruptCheck" . (StickerStackInterruptCheck ? " Checked" : ""), "Sticker Stack``nInterrupt").OnEvent("Click", nm_StickerStackToggle)'
    oldEnzymeBoostLine1 := '(GuiCtrl := MainGui.Add("CheckBox", "x205 y180 w85 h32 +Center vEnzymesBoostedOnly" . (EnzymesBoostedOnly ? " Checked" : ""), "Boosted``nEnzyme Only")).Section := "Boost", GuiCtrl.OnEvent("Click", nm_saveConfig)'
    oldEnzymeBoostLine2 := '(GuiCtrl := MainGui.Add("CheckBox", "x205 y195 w85 h32 +Center vEnzymesBoostedOnly" . (EnzymesBoostedOnly ? " Checked" : ""), "Boosted``nEnzyme Only")).Section := "Boost", GuiCtrl.OnEvent("Click", nm_saveConfig)'
    oldEnzymeBoostLine3 := '(GuiCtrl := MainGui.Add("CheckBox", "x205 y206 w85 h32 +Center vEnzymesBoostedOnly" . (EnzymesBoostedOnly ? " Checked" : ""), "Boosted``nEnzyme Only")).Section := "Boost", GuiCtrl.OnEvent("Click", nm_saveConfig)'
    newExtensionsLayout := JoinLines(
        'MainGui.Add("GroupBox", "x5 y23 w165 h80", "Extensions")',
        'MainGui.Add("GroupBox", "x175 y23 w155 h80", "Interupts")',
        'MainGui.Add("GroupBox", "x335 y23 w155 h105", "Extras")',
        '',
        'MainGui.SetFont("s8 cDefault Norm", "Tahoma")',
        '',
        'MainGui.Add("Button", "x15 y45 w150 h20 vFieldFollowingGUI Disabled", "Field Following").OnEvent("Click", aq_FieldFollowingGUI)',
        'MainGui.Add("Button", "x15 y70 w150 h20 vStatMonitorEditorGUI Disabled", "StatMonitor Editor").OnEvent("Click", aq_StatMonitorThemeEditorGUI)',
        'MainGui.Add("CheckBox", "x185 y45 w135 h18 vBlueBoosterInterruptCheck Checked" BlueBoosterInterruptCheck, "Blue Booster Interrupt").OnEvent("Click", nm_BlueBoosterToggle)',
        'MainGui.Add("CheckBox", "x185 y70 w140 h18 vStickerStackInterruptCheck" . (StickerStackInterruptCheck ? " Checked" : ""), "Sticker Stack Interrupt").OnEvent("Click", nm_StickerStackToggle)',
        'MainGui.Add("CheckBox", "x345 y45 w135 h18 vPFieldBoosted Checked" PFieldBoosted, "Glitter Extend").OnEvent("Click", aq_togglePFieldBoosted)',
        '(GuiCtrl := MainGui.Add("CheckBox", "x345 y70 w135 h18 vPreGlitterCheck" . (PreGlitterCheck ? " Checked" : ""), "Pre-Glitter")).Section := "Extensions", GuiCtrl.OnEvent("Click", nm_saveConfig)',
        '(GuiCtrl := MainGui.Add("CheckBox", "x345 y95 w140 h18 vEnzymesBoostedOnly" . (EnzymesBoostedOnly ? " Checked" : ""), "Boosted Enzyme Only")).Section := "Boost", GuiCtrl.OnEvent("Click", nm_saveConfig)',
        'MainGui.Add("Text", "x12 y134 w476 Center c666666", "Made by: @definetlynotray")',
        'MainGui.Add("Text", "x12 y146 w476 Center c666666", "Inspired by @baspas")'
    )
    if InStr(c, oldMondoButton) {
        c := StrReplace(c, oldMondoButton "`r`n", "")
        FileAppend("✓ Removed public Mondo Hop button from the Extensions tab`n", logFile)
    }

    oldVersionFooter := '(GuiCtrl := MainGui.Add("Text", "x435 y264 vVersionText", "v" versionID)).OnEvent("Click", nm_showAdvancedSettings), GuiCtrl.Move(494 - (VersionWidth := TextExtent("v" VersionID, GuiCtrl)))'
    newVersionFooter := '(GuiCtrl := MainGui.Add("Text", "x435 y264 vVersionText", "Rays.v" versionID)).OnEvent("Click", nm_showAdvancedSettings), GuiCtrl.Move(494 - (VersionWidth := TextExtent("Rays.v" VersionID, GuiCtrl)))'
    c := StrReplace(c, oldVersionFooter, newVersionFooter)
    c := StrReplace(c, '(GuiCtrl := MainGui.Add("Text", "x435 y264 vVersionText", "Rays.v" versionID)).OnEvent("Click", nm_showAdvancedSettings), GuiCtrl.Move(494 - (VersionWidth := TextExtent("v" VersionID, GuiCtrl)))', newVersionFooter)
    if InStr(c, oldBoostGroup) {
        c := StrReplace(c, oldBoostGroup "`r`n`r`n", "")
        FileAppend("✓ Removed old TadSync boosted group from the Extensions tab`n", logFile)
    }
    if InStr(c, oldBoostedTabLine)
        c := StrReplace(c, oldBoostedTabLine "`r`n", "")
    c := StrReplace(c, '; TADSYNC TAB', '; EXTENSIONS TAB')
    c := StrReplace(c, 'TabCtrl.UseTab("TadSync")', 'TabCtrl.UseTab("Extensions")')
    c := StrReplace(c, 'MainGui.Add("GroupBox", "x5 y23 w490 h210", "TadSync Settings")`r`n`r`nMainGui.SetFont("s8 cDefault Norm", "Tahoma")`r`n`r`nMainGui.Add("Button", "x15 y40 w150 h20 vFieldFollowingGUI Disabled", "Field Following").OnEvent("Click", aq_FieldFollowingGUI)', newExtensionsLayout)
    c := StrReplace(c, 'MainGui.Add("GroupBox", "x5 y23 w490 h80", "Extensions")`r`n`r`nMainGui.SetFont("s8 cDefault Norm", "Tahoma")`r`n`r`nMainGui.Add("Button", "x15 y45 w150 h20 vFieldFollowingGUI Disabled", "Field Following").OnEvent("Click", aq_FieldFollowingGUI)', newExtensionsLayout)
    c := StrReplace(c, oldGlitterBoostLine1 "`r`n", "")
    c := StrReplace(c, oldGlitterBoostLine2 "`r`n", "")
    c := StrReplace(c, oldGlitterBoostLine3 "`r`n", "")
    c := StrReplace(c, oldBfbBoostLine1 "`r`n", "")
    c := StrReplace(c, oldBfbBoostLine2 "`r`n", "")
    c := StrReplace(c, oldBfbBoostLine3 "`r`n", "")
    c := StrReplace(c, oldStickerBoostLine1 "`r`n", "")
    c := StrReplace(c, oldStickerBoostLine2 "`r`n", "")
    c := StrReplace(c, oldStickerBoostLine3 "`r`n", "")
    c := StrReplace(c, oldEnzymeBoostLine1 "`r`n", "")
    c := StrReplace(c, oldEnzymeBoostLine2 "`r`n", "")
    c := StrReplace(c, oldEnzymeBoostLine3 "`r`n", "")
    c := StrReplace(c, 'MainGui.Add("GroupBox", "x175 y23 w315 h80", "Interupts & Extras")', 'MainGui.Add("GroupBox", "x175 y23 w155 h80", "Interupts")`r`nMainGui.Add("GroupBox", "x335 y23 w155 h105", "Extras")')
    c := StrReplace(c, 'MainGui.Add("CheckBox", "x185 y45 w135 h18 vPFieldBoosted Checked" PFieldBoosted, "Glitter Extend").OnEvent("Click", aq_togglePFieldBoosted)', 'MainGui.Add("CheckBox", "x345 y45 w135 h18 vPFieldBoosted Checked" PFieldBoosted, "Glitter Extend").OnEvent("Click", aq_togglePFieldBoosted)')
    c := StrReplace(c, 'MainGui.Add("CheckBox", "x335 y45 w145 h18 vBlueBoosterInterruptCheck Checked" BlueBoosterInterruptCheck, "BFB Interrupt").OnEvent("Click", nm_BlueBoosterToggle)', 'MainGui.Add("CheckBox", "x185 y45 w135 h18 vBlueBoosterInterruptCheck Checked" BlueBoosterInterruptCheck, "BFB Interrupt").OnEvent("Click", nm_BlueBoosterToggle)')
    c := StrReplace(c, 'MainGui.Add("CheckBox", "x185 y70 w145 h18 vStickerStackInterruptCheck" . (StickerStackInterruptCheck ? " Checked" : ""), "Sticker Stack Interrupt").OnEvent("Click", nm_StickerStackToggle)', 'MainGui.Add("CheckBox", "x185 y70 w140 h18 vStickerStackInterruptCheck" . (StickerStackInterruptCheck ? " Checked" : ""), "Sticker Stack Interrupt").OnEvent("Click", nm_StickerStackToggle)')
    c := StrReplace(c, '(GuiCtrl := MainGui.Add("CheckBox", "x335 y70 w145 h18 vEnzymesBoostedOnly" . (EnzymesBoostedOnly ? " Checked" : ""), "Boosted Enzyme Only")).Section := "Boost", GuiCtrl.OnEvent("Click", nm_saveConfig)', '(GuiCtrl := MainGui.Add("CheckBox", "x345 y70 w135 h18 vPreGlitterCheck" . (PreGlitterCheck ? " Checked" : ""), "Pre-Glitter")).Section := "Extensions", GuiCtrl.OnEvent("Click", nm_saveConfig)`r`n(GuiCtrl := MainGui.Add("CheckBox", "x345 y95 w140 h18 vEnzymesBoostedOnly" . (EnzymesBoostedOnly ? " Checked" : ""), "Boosted Enzyme Only")).Section := "Boost", GuiCtrl.OnEvent("Click", nm_saveConfig)')
    c := StrReplace(c, '(GuiCtrl := MainGui.Add("CheckBox", "x345 y70 w140 h18 vEnzymesBoostedOnly" . (EnzymesBoostedOnly ? " Checked" : ""), "Boosted Enzyme Only")).Section := "Boost", GuiCtrl.OnEvent("Click", nm_saveConfig)', '(GuiCtrl := MainGui.Add("CheckBox", "x345 y70 w135 h18 vPreGlitterCheck" . (PreGlitterCheck ? " Checked" : ""), "Pre-Glitter")).Section := "Extensions", GuiCtrl.OnEvent("Click", nm_saveConfig)`r`n(GuiCtrl := MainGui.Add("CheckBox", "x345 y95 w140 h18 vEnzymesBoostedOnly" . (EnzymesBoostedOnly ? " Checked" : ""), "Boosted Enzyme Only")).Section := "Boost", GuiCtrl.OnEvent("Click", nm_saveConfig)')
    c := StrReplace(c, 'MainGui.Add("GroupBox", "x335 y23 w155 h80", "Extras")', 'MainGui.Add("GroupBox", "x335 y23 w155 h105", "Extras")')
    c := StrReplace(c, 'MainGui.Add("Text", "x12 y109 w476 Center c666666", "Made by: @definetlynotray")`r`nMainGui.Add("Text", "x12 y121 w476 Center c666666", "Inspired by @baspas")', 'MainGui.Add("Text", "x12 y134 w476 Center c666666", "Made by: @definetlynotray")`r`nMainGui.Add("Text", "x12 y146 w476 Center c666666", "Inspired by @baspas")')
    if !InStr(c, 'MainGui.Add("GroupBox", "x175 y23 w155 h80", "Interupts")') && InStr(c, 'MainGui.Add("GroupBox", "x5 y23 w490 h80", "Extensions")') {
        c := StrReplace(c, 'MainGui.Add("GroupBox", "x5 y23 w490 h80", "Extensions")`r`n`r`nMainGui.SetFont("s8 cDefault Norm", "Tahoma")`r`n`r`nMainGui.Add("Button", "x15 y45 w150 h20 vFieldFollowingGUI Disabled", "Field Following").OnEvent("Click", aq_FieldFollowingGUI)', newExtensionsLayout)
        FileAppend("✓ Split Extensions controls into Interupts and Extras sections`n", logFile)
    }
    if InStr(c, 'MainGui.Add("GroupBox", "x175 y23 w155 h80", "Interupts")') && !InStr(c, 'MainGui.Add("Text", "x12 y134 w476 Center c666666", "Made by: @definetlynotray")') {
        creditsNeedle := '(GuiCtrl := MainGui.Add("CheckBox", "x345 y95 w140 h18 vEnzymesBoostedOnly" . (EnzymesBoostedOnly ? " Checked" : ""), "Boosted Enzyme Only")).Section := "Boost", GuiCtrl.OnEvent("Click", nm_saveConfig)'
        creditsInsert := creditsNeedle '`r`nMainGui.Add("Text", "x12 y134 w476 Center c666666", "Made by: @definetlynotray")`r`nMainGui.Add("Text", "x12 y146 w476 Center c666666", "Inspired by @baspas")'
        if InStr(c, creditsNeedle) {
            c := StrReplace(c, creditsNeedle, creditsInsert)
            FileAppend("✓ Added Extensions credits footer`n", logFile)
        }
    }
    if !InStr(c, 'TabCtrl.UseTab("Extensions")') {
        pattern := 'is)(SetLoadingProgress\(99\))'
        if RegExMatch(c, pattern, &match) {
            tabContent := JoinLines(
                '`r`n; EXTENSIONS TAB',
                '; ------------------------',
                '`r`nTabCtrl.UseTab("Extensions")',
                '`r`nMainGui.SetFont("w700")',
                '`r`n' newExtensionsLayout,
                '`r`nTabCtrl.UseTab()',
                ''
            )
            c := RegExReplace(c, pattern, tabContent match[1])
            FileAppend("✓ Added Extensions tab with Interupts and Extras controls`n", logFile)
        }
    }

    ; 1i. nm_LockTabs tab list registration
    if InStr(c, "nm_LockTabs") {
        lockTabsPos := InStr(c, "nm_LockTabs")
        lockTabsBlock := SubStr(c, lockTabsPos, 250)
        if InStr(lockTabsBlock, '"Extensions"') {
            c := RegExReplace(c, '(static tabs\s*:=\s*\[)(.*?)(\])', '$1' ReorderExtensionsTabs('$2') '$3', , 1)
            FileAppend("✓ Normalized Extensions position in LockTabs tab list`n", logFile)
        } else {
            pattern := '(static tabs\s*:=\s*\[)(.*?)(\])'
            c := RegExReplace(c, pattern, '$1$2, "Extensions"$3', , 1)
            FileAppend("✓ Added Extensions to LockTabs tab list`n", logFile)
        }
    }

    ; 1j. nm_TabExtensionsLock/UnLock functions
    oldFuncs := '`r`nnm_TabTadSyncLock(){`r`n`tMainGui["FieldFollowingGUI"].Enabled := 0`r`n`tMainGui["MondoHopGUI"].Enabled := 0`r`n}`r`nnm_TabTadSyncUnLock(){`r`n`tMainGui["FieldFollowingGUI"].Enabled := 1`r`n`tMainGui["MondoHopGUI"].Enabled := 1`r`n}'
    newFuncs := '`r`nnm_TabExtensionsLock(){`r`n`tMainGui["FieldFollowingGUI"].Enabled := 0`r`n`tMainGui["StatMonitorEditorGUI"].Enabled := 0`r`n`tMainGui["PFieldBoosted"].Enabled := 0`r`n`tMainGui["PreGlitterCheck"].Enabled := 0`r`n`tMainGui["BlueBoosterInterruptCheck"].Enabled := 0`r`n`tMainGui["StickerStackInterruptCheck"].Enabled := 0`r`n`tMainGui["EnzymesBoostedOnly"].Enabled := 0`r`n}`r`nnm_TabExtensionsUnLock(){`r`n`tMainGui["FieldFollowingGUI"].Enabled := 1`r`n`tMainGui["StatMonitorEditorGUI"].Enabled := 1`r`n`tMainGui["PFieldBoosted"].Enabled := 1`r`n`tMainGui["PreGlitterCheck"].Enabled := 1`r`n`tMainGui["BlueBoosterInterruptCheck"].Enabled := 1`r`n`tMainGui["StickerStackInterruptCheck"].Enabled := 1`r`n`tMainGui["EnzymesBoostedOnly"].Enabled := 1`r`n}`r`nnm_TabTadSyncLock(){`r`n`tnm_TabExtensionsLock()`r`n}`r`nnm_TabTadSyncUnLock(){`r`n`tnm_TabExtensionsUnLock()`r`n}'
    cNew := StrReplace(c, oldFuncs, newFuncs)
    if (cNew != c) {
        c := cNew
        FileAppend("✓ Replaced TadSync tab lock functions with Extensions variants`n", logFile)
    } else if InStr(c, 'nm_TabExtensionsLock(){`r`n`tMainGui["FieldFollowingGUI"].Enabled := 0`r`n}`r`nnm_TabExtensionsUnLock(){`r`n`tMainGui["FieldFollowingGUI"].Enabled := 1`r`n}') {
        c := StrReplace(c, 'nm_TabExtensionsLock(){`r`n`tMainGui["FieldFollowingGUI"].Enabled := 0`r`n}`r`nnm_TabExtensionsUnLock(){`r`n`tMainGui["FieldFollowingGUI"].Enabled := 1`r`n}', 'nm_TabExtensionsLock(){`r`n`tMainGui["FieldFollowingGUI"].Enabled := 0`r`n`tMainGui["StatMonitorEditorGUI"].Enabled := 0`r`n`tMainGui["PFieldBoosted"].Enabled := 0`r`n`tMainGui["PreGlitterCheck"].Enabled := 0`r`n`tMainGui["BlueBoosterInterruptCheck"].Enabled := 0`r`n`tMainGui["StickerStackInterruptCheck"].Enabled := 0`r`n`tMainGui["EnzymesBoostedOnly"].Enabled := 0`r`n}`r`nnm_TabExtensionsUnLock(){`r`n`tMainGui["FieldFollowingGUI"].Enabled := 1`r`n`tMainGui["StatMonitorEditorGUI"].Enabled := 1`r`n`tMainGui["PFieldBoosted"].Enabled := 1`r`n`tMainGui["PreGlitterCheck"].Enabled := 1`r`n`tMainGui["BlueBoosterInterruptCheck"].Enabled := 1`r`n`tMainGui["StickerStackInterruptCheck"].Enabled := 1`r`n`tMainGui["EnzymesBoostedOnly"].Enabled := 1`r`n}')
        FileAppend("✓ Expanded Extensions tab lock functions for Interupts and Extras`n", logFile)
    } else if !InStr(c, "nm_TabExtensionsLock") {
        c .= newFuncs
        FileAppend("✓ Added Extensions tab lock functions`n", logFile)
    }

    ; 1l. TadSync Interrupt Function
    if InStr(c, 'nm_TadsyncInterrupt() => (FollowingLeader = 1 && (FieldName != FollowingField))') {
        c := StrReplace(c, 'nm_TadsyncInterrupt() => (FollowingLeader = 1 && (FieldName != FollowingField))', 'nm_TadsyncInterrupt() => tadsync_ShouldInterruptFollowing(FieldName)')
        FileAppend("✓ Updated nm_TadsyncInterrupt to helper-based logic`n", logFile)
    } else if !InStr(c, "nm_TadsyncInterrupt") {
        c .= '`r`nnm_TadsyncInterrupt() => tadsync_ShouldInterruptFollowing(FieldName)`r`n'
        FileAppend("âœ“ Added nm_TadsyncInterrupt function`n", logFile)
    }
    }

    ; 1l2. Inject field_type determination before FDC switch (for per-booster glitter timing)
    if (patchGlitterExtend) {
    if !InStr(c, 'field_type := "None"') {
        pattern := ';set FDC switch'
        fieldTypeCode := '`t;set field colour (for per-booster glitter timing)`r`n`tfield_type := "None"`r`n`tif (FieldName="Pine Tree" || FieldName="Bamboo" || FieldName="Blue Flower" || FieldName="Stump")`r`n`t`tfield_type := "Blue"`r`n`tif (FieldName="Rose" || FieldName="Strawberry" || FieldName="Mushroom" || FieldName="Pepper")`r`n`t`tfield_type := "Red"`r`n`tif (FieldName="Sunflower" || FieldName="Dandelion" || FieldName="Clover" || FieldName="Spider" || FieldName="Cactus" || FieldName="Pumpkin" || FieldName="Pineapple")`r`n`t`tfield_type := "Mountain"`r`n`r`n`t;set FDC switch'
        c := StrReplace(c, pattern, fieldTypeCode)
        FileAppend("âœ“ Injected field_type determination logic`n", logFile)
    }

    ; 1l2b. Make GatherBoostInterrupt read persisted boost timestamps like Baspas.
    gatherBoostInterruptOld := 'nm_GatherBoostInterrupt() => (now := nowUnix(), ((now-GatherFieldBoostedStart<900) || (now-LastGlitter<900) || nm_boostBypassCheck()))'
    gatherBoostInterruptNew := 'nm_GatherBoostInterrupt() => (now := nowUnix(), (now - IniRead("settings\nm_config.ini", "Boost", "LastBoostedTime", 0) < 900) || (now - IniRead("settings\nm_config.ini", "Boost", "LastGlitter", 0) < 900) || nm_boostBypassCheck())'
    cNew := StrReplace(c, gatherBoostInterruptOld, gatherBoostInterruptNew)
    if (cNew != c) {
        c := cNew
        FileAppend("✓ Restored GatherBoostInterrupt to Baspas persisted timer logic`n", logFile)
    }

    pinePreGlitterNeedle := JoinLines(
        '`tLastBoosterCheck() => ((nowUnix()-max(LastBlueBoost, LastRedBoost, LastMountainBoost, (BoostChaserCheck && CoconutBoosterCheck && CoconutDisCheck) ? LastCoconutDis : 1))>(FieldBoosterMins*60))',
        '`tBoosterCooldown(booster) => (booster = "coconut" ? ((nowUnix()-LastCoconutDis)>14400) : (nowUnix()-Last%booster%Boost)>2700)',
        '}'
    )
    pinePreGlitterInsert := JoinLines(
        '`tLastBoosterCheck() => ((nowUnix()-max(LastBlueBoost, LastRedBoost, LastMountainBoost, (BoostChaserCheck && CoconutBoosterCheck && CoconutDisCheck) ? LastCoconutDis : 1))>(FieldBoosterMins*60))',
        '`tBoosterCooldown(booster) => (booster = "coconut" ? ((nowUnix()-LastCoconutDis)>14400) : (nowUnix()-Last%booster%Boost)>2700)',
        '}',
        'nm_ShouldUsePinePreGlitter(fieldName, field_type){',
        '`tglobal PreGlitterCheck, GlitterKey, LastGlitter, LastBlueBoostUse',
        '',
        '`tif (!PreGlitterCheck || GlitterKey = "none" || fieldName != "Pine Tree" || field_type != "Blue")',
        '`t`treturn 0',
        '',
        '`tlastUse := (LastBlueBoostUse = "" ? 0 : LastBlueBoostUse)',
        '`tif (lastUse <= 0 || (nowUnix() - LastGlitter) <= 900)',
        '`t`treturn 0',
        '',
        '`ttimeUntilBlueReady := 2700 - (nowUnix() - lastUse)',
        '`treturn (timeUntilBlueReady <= 780 && timeUntilBlueReady > 720)',
        '}',
        'nm_HandlePinePreGlitter(fieldName, field_type){',
        '`tglobal GlitterKey, LastGlitter, GatherFieldBoostedStart, fieldOverrideReason',
        '',
        '`tif !nm_ShouldUsePinePreGlitter(fieldName, field_type)',
        '`t`treturn 0',
        '',
        '`tSend "{" GlitterKey "}"',
        '`tLastGlitter := nowUnix()',
        '`tGatherFieldBoostedStart := LastGlitter',
        '`tfieldOverrideReason := "Boost"',
        '`tIniWrite LastGlitter, "settings\nm_config.ini", "Boost", "LastGlitter"',
        '`tIniWrite fieldName, "settings\nm_config.ini", "Boost", "LastBoostedField"',
        '`tIniWrite GatherFieldBoostedStart, "settings\nm_config.ini", "Boost", "LastBoostedTime"',
        '`tnm_setStatus("Boosted", "Pre-Glitter: Pine Tree")',
        '`treturn 1',
        '}'
    )
    if InStr(c, pinePreGlitterNeedle) && !InStr(c, 'nm_HandlePinePreGlitter(fieldName, field_type)') {
        c := StrReplace(c, pinePreGlitterNeedle, pinePreGlitterInsert)
        FileAppend("✓ Added Pine pre-glitter helper functions`n", logFile)
    }

    canonicalFieldBoostCheck :=
    (
        'nm_fieldBoostCheck(fieldName, variant:=0){`r`n'
        . '`tglobal AutoFieldBoostActive`r`n'
        . '`r`n'
        . '`tGetRobloxClientPos(hwnd:=GetRobloxHWND())`r`n'
        . '`tpBMScreen:=Gdip_BitmapFromScreen(windowX "|" windowY + GetYOffset(hwnd) + 36 "|" windowWidth "|" 38)`r`n'
        . '`tloop Floor(windowWidth/38) ; flooring because you will not have half of an icon`r`n'
        . '`t{ `r`n'
        . '`t`tico:=(A_Index-1)*38`r`n'
        . '`t`tif (Gdip_ImageSearch(pBMScreen, bitmaps["boost"][StrReplace(fieldName, " ") variant],,ico,,ico+38,,(variant=1 || variant=0) ? 35 : 50)) ; testing tighter variation`r`n'
        . '`t`t{ ; check with original 30 not 35`r`n'
        . '`t`t`tp:=PixelGetColor(ico+windowX, windowY+GetYOffset(hwnd)+73)`r`n'
        . '`t`t`tif ((p & 0xFF0000 >= 0xa60000) && (p & 0xFF0000 <= 0xcf0000)) ; a6b2b8-blackBG|cfdbe1-whiteBG`r`n'
        . '`t`t`t&& ((p & 0x00FF00 >= 0x00b200) && (p & 0x00FF00 <= 0x00db00))`r`n'
        . '`t`t`t&& ((p & 0x0000FF >= 0x0000b8) && (p & 0x0000FF <= 0x0000e1))`r`n'
        . '`t`t`t`tcontinue ; winds: keep searching, winds and booster may both have boosted the field`r`n'
        . '`t`t`telse if ((p & 0xFF0000 >= 0xb80000) && (p & 0xFF0000 <= 0xe10000)) ; b8a43a-blackBG|e1cd63-whiteBG`r`n'
        . '`t`t`t`t&& ((p & 0x00FF00 >= 0x00a400) && (p & 0x00FF00 <= 0x00cd00))`r`n'
        . '`t`t`t`t&& ((p & 0x0000FF >= 0x00003a) && (p & 0x0000FF <= 0x000063))`r`n'
        . '`t`t`t`t{`r`n'
        . '`t`t`t`t`tGdip_DisposeImage(pBMScreen)`r`n'
        . '`t`t`t`t`treturn 1 ; booster`r`n'
        . '`t`t`t`t}`r`n'
        . '`t`t}`r`n'
        . '`t}`r`n'
        . '`tGdip_DisposeImage(pBMScreen)`r`n'
        . '`tif (AutoFieldBoostActive && fieldName = "Pine Tree") {`r`n'
        . '`t`tfor _, pineFallbackName in ["pine trees 1.png", "pine trees 2.png", "pine trees 3.png"] {`r`n'
        . '`t`t`tif FileExist(A_WorkingDir "\nm_image_assets\" pineFallbackName) && (nm_imgSearch(pineFallbackName, (variant=1) ? 30 : 50, "low")[1] = 0)`r`n'
        . '`t`t`t`treturn 1`r`n'
        . '`t`t}`r`n'
        . '`t}`r`n'
        . '`treturn 0`r`n'
        . '}`r`n'
        . 'nm_isBoostChaserFieldEnabled(fieldName){`r`n'
        . '`tglobal PineTreeBoosterCheck, BambooBoosterCheck, BlueFlowerBoosterCheck, StumpBoosterCheck`r`n'
        . '`tglobal RoseBoosterCheck, StrawberryBoosterCheck, MushroomBoosterCheck, PepperBoosterCheck`r`n'
        . '`tglobal CactusBoosterCheck, PumpkinBoosterCheck, PineappleBoosterCheck, SpiderBoosterCheck, CloverBoosterCheck, DandelionBoosterCheck, SunflowerBoosterCheck`r`n'
        . '`tglobal CoconutBoosterCheck`r`n'
        . '`r`n'
        . '`treturn (fieldName = "Pine Tree") ? PineTreeBoosterCheck`r`n'
        . '`t`t: (fieldName = "Bamboo") ? BambooBoosterCheck`r`n'
        . '`t`t: (fieldName = "Blue Flower") ? BlueFlowerBoosterCheck`r`n'
        . '`t`t: (fieldName = "Stump") ? StumpBoosterCheck`r`n'
        . '`t`t: (fieldName = "Rose") ? RoseBoosterCheck`r`n'
        . '`t`t: (fieldName = "Strawberry") ? StrawberryBoosterCheck`r`n'
        . '`t`t: (fieldName = "Mushroom") ? MushroomBoosterCheck`r`n'
        . '`t`t: (fieldName = "Pepper") ? PepperBoosterCheck`r`n'
        . '`t`t: (fieldName = "Cactus") ? CactusBoosterCheck`r`n'
        . '`t`t: (fieldName = "Pumpkin") ? PumpkinBoosterCheck`r`n'
        . '`t`t: (fieldName = "Pineapple") ? PineappleBoosterCheck`r`n'
        . '`t`t: (fieldName = "Spider") ? SpiderBoosterCheck`r`n'
        . '`t`t: (fieldName = "Clover") ? CloverBoosterCheck`r`n'
        . '`t`t: (fieldName = "Dandelion") ? DandelionBoosterCheck`r`n'
        . '`t`t: (fieldName = "Sunflower") ? SunflowerBoosterCheck`r`n'
        . '`t`t: (fieldName = "Coconut") ? CoconutBoosterCheck`r`n'
        . '`t`t: (fieldName = "Mountain Top") ? 1`r`n'
        . '`t`t: 0`r`n'
        . '}'
    )
    cNew := RegExReplace(c, '(?ms)^nm_fieldBoostCheck\(fieldName, variant:=0\)\{.*?^\}\r?\n(?=nm_fieldBoostBooster\(\)\{)', canonicalFieldBoostCheck "`r`n", &fieldBoostCheckCount, 1)
    if (fieldBoostCheckCount > 0 && cNew != c) {
        c := cNew
        FileAppend("✓ Added Pine Tree anti-drop fallback to nm_fieldBoostCheck()`n", logFile)
    }

    oldBoostConfirmBlock := JoinLines(
        '`t`tblueBoosterFields:=["Pine Tree", "Bamboo", "Blue Flower", "Stump"]',
        '`t`tredBoosterFields:=["Rose", "Strawberry", "Mushroom", "Pepper"]',
        '`t`tmountainBoosterfields:=["Cactus", "Pumpkin", "Pineapple", "Spider", "Clover", "Dandelion", "Sunflower"]',
        '`t`totherFields:=["Coconut", "Mountain Top"]'
    )
    newBoostConfirmBlock := JoinLines(
        '`t`tblueBoosterFields:=Map("Pine Tree", PineTreeBoosterCheck, "Bamboo", BambooBoosterCheck, "Blue Flower", BlueFlowerBoosterCheck, "Stump", StumpBoosterCheck)',
        '`t`tredBoosterFields:=Map("Rose", RoseBoosterCheck, "Strawberry", StrawberryBoosterCheck, "Mushroom", MushroomBoosterCheck, "Pepper", PepperBoosterCheck)',
        '`t`tmountainBoosterfields:=Map("Cactus", CactusBoosterCheck, "Pumpkin", PumpkinBoosterCheck, "Pineapple", PineappleBoosterCheck, "Spider", SpiderBoosterCheck, "Clover", CloverBoosterCheck, "Dandelion", DandelionBoosterCheck, "Sunflower", SunflowerBoosterCheck)',
        '`t`totherFields:=Map("Coconut", CoconutBoosterCheck, "Mountain Top", 1)'
    )
    if InStr(c, oldBoostConfirmBlock) {
        c := StrReplace(c, oldBoostConfirmBlock, newBoostConfirmBlock)
        FileAppend("✓ Made boosted gather confirmation respect per-field toggles`n", logFile)
    }

    c := StrReplace(c, JoinLines('`t`t`tfor key, value in blueBoosterFields {', '`t`t`t`tif(nm_fieldBoostCheck(value, 3) && FieldName=value) {'), JoinLines('`t`t`tfor value, enabled in blueBoosterFields {', '`t`t`t`tif(enabled && nm_fieldBoostCheck(value, 3) && FieldName=value) {'))
    c := StrReplace(c, JoinLines('`t`t`tfor key, value in mountainBoosterFields {', '`t`t`t`tif(nm_fieldBoostCheck(value, 3) && FieldName=value) {'), JoinLines('`t`t`tfor value, enabled in mountainBoosterFields {', '`t`t`t`tif(enabled && nm_fieldBoostCheck(value, 3) && FieldName=value) {'))
    c := StrReplace(c, JoinLines('`t`t`tfor key, value in redBoosterFields {', '`t`t`t`tif(nm_fieldBoostCheck(value, 3) && FieldName=value) {'), JoinLines('`t`t`tfor value, enabled in redBoosterFields {', '`t`t`t`tif(enabled && nm_fieldBoostCheck(value, 3) && FieldName=value) {'))
    c := StrReplace(c, JoinLines('`t`t`tfor key, value in otherFields {', '`t`t`t`tif(nm_fieldBoostCheck(value, 1) && FieldName=value) {'), JoinLines('`t`t`tfor value, enabled in otherFields {', '`t`t`t`tif(enabled && nm_fieldBoostCheck(value, 1) && FieldName=value) {'))

    ; 1l3. Use Baspas-style glitter timing based on per-colour boost clocks.
    firstGlitterCondition := 'if(PFieldBoosted && field_type!="None" && (nowUnix()-Last%field_type%Boost)>840 && (nowUnix()-Last%field_type%Boost)<900 && (nowUnix()-LastGlitter)>900 && GlitterKey!="none")'
    firstGlitterCurrent1 := 'if(PFieldBoosted && (nowUnix()-GatherFieldBoostedStart)>525 && (nowUnix()-GatherFieldBoostedStart)<900 && (nowUnix()-LastGlitter)>900 && GlitterKey!="none" && (fieldOverrideReason="None" || fieldOverrideReason="Boost"))'
    firstGlitterCurrent2 := 'if(PFieldBoosted && (nowUnix()-GatherFieldBoostedStart)>840 && (nowUnix()-GatherFieldBoostedStart)<900 && (nowUnix()-LastGlitter)>900 && GlitterKey!="none" && (fieldOverrideReason="None" || fieldOverrideReason="Boost"))'
    cNew := StrReplace(c, firstGlitterCurrent1, firstGlitterCondition)
    cNew := StrReplace(cNew, firstGlitterCurrent2, firstGlitterCondition)
    if (cNew != c) {
        c := cNew
        FileAppend("✓ Restored first glitter check to Baspas per-colour timing`n", logFile)
    }

    ; 1l4. Replace the first glitter action with the Baspas direct glitter send.
    firstGlitterActionPattern := 'is)if\(PFieldBoosted && field_type!="None" && \(nowUnix\(\)-Last%field_type%Boost\)>840 && \(nowUnix\(\)-Last%field_type%Boost\)<900 && \(nowUnix\(\)-LastGlitter\)>900 && GlitterKey!="none"\) \{.*?\}'
    firstGlitterActionReplacement :=
    (
        'if(PFieldBoosted && field_type!="None" && (nowUnix()-Last%field_type%Boost)>840 && (nowUnix()-Last%field_type%Boost)<900 && (nowUnix()-LastGlitter)>900 && GlitterKey!="none") {`r`n'
        '`t`t`t`t`tSend "{" GlitterKey "}"`r`n'
        '`t`t`t`t`tLastGlitter := nowUnix()`r`n'
        '`t`t`t`t`tIniWrite(LastGlitter, "settings\nm_config.ini", "Boost", "LastGlitter")`r`n'
        '`t`t`t`t`tnm_setStatus("Gathering", "Glitter Used - Boost Renewed 15m")`r`n'
        '`t`t`t`t}'
    )
    cNew := RegExReplace(c, firstGlitterActionPattern, firstGlitterActionReplacement, &firstActionCount, 1)
    if (firstActionCount > 0 && cNew != c) {
        c := cNew
        FileAppend("✓ Restored first glitter action to direct Baspas-style send`n", logFile)
    }

    ; Clean up older malformed first-glitter blocks from bad replacements by rewriting the full 1-second glitter section.
    badFirstGlitterPattern :=
    (
        "(?s)\t\t\tif \(Mod\(A_Index, 20\) = 1\) \{ ; every 1s\r?\n.*?\t\t\t\tnm_fieldBoostGlitter\(\)\r?\n\t\t\t\}"
    )
    badFirstGlitterReplacement :=
    (
        '`t`t`tif (Mod(A_Index, 20) = 1) { ; every 1s`r`n'
        '`t`t`t`tnm_HandlePinePreGlitter(FieldName, field_type)`r`n'
        '`t`t`t`tif(PFieldBoosted && field_type!="None" && (nowUnix()-Last%field_type%Boost)>840 && (nowUnix()-Last%field_type%Boost)<900 && (nowUnix()-LastGlitter)>900 && GlitterKey!="none") {`r`n'
        '`t`t`t`t`tSend "{" GlitterKey "}"`r`n'
        '`t`t`t`t`tLastGlitter := nowUnix()`r`n'
        '`t`t`t`t`tIniWrite(LastGlitter, "settings\nm_config.ini", "Boost", "LastGlitter")`r`n'
        '`t`t`t`t`tnm_setStatus("Gathering", "Glitter Used - Boost Renewed 15m")`r`n'
        '`t`t`t`t}`r`n'
        '`t`t`t`tnm_autoFieldBoost(FieldName)`r`n'
        '`t`t`t`tnm_fieldBoostGlitter()`r`n'
        '`t`t`t}'
    )
    cNew := RegExReplace(c, badFirstGlitterPattern, badFirstGlitterReplacement, &badFirstCount, 1)
    if (badFirstCount > 0 && cNew != c) {
        c := cNew
        FileAppend("✓ Repaired malformed first glitter block from older patch run`n", logFile)
    }

    ; 1l5. Same for the early/full-pack glitter check.
    earlyGlitterCondition := 'if(PFieldBoosted && field_type!="None" && (nowUnix()-Last%field_type%Boost)>660 && (nowUnix()-Last%field_type%Boost)<900 && (nowUnix()-LastGlitter)>900 && GlitterKey!="none" && (fieldOverrideReason="None" || fieldOverrideReason="Boost"))'
    earlyGlitterCurrent1 := 'if(PFieldBoosted && (nowUnix()-GatherFieldBoostedStart)>600 && (nowUnix()-GatherFieldBoostedStart)<900 && (nowUnix()-LastGlitter)>900 && GlitterKey!="none" && (fieldOverrideReason="None" || fieldOverrideReason="Boost"))'
    earlyGlitterCurrent2 := 'if(PFieldBoosted && (nowUnix()-GatherFieldBoostedStart)>840 && (nowUnix()-GatherFieldBoostedStart)<900 && (nowUnix()-LastGlitter)>900 && GlitterKey!="none" && (fieldOverrideReason="None" || fieldOverrideReason="Boost"))'
    cNew := StrReplace(c, earlyGlitterCurrent1, earlyGlitterCondition)
    cNew := StrReplace(cNew, earlyGlitterCurrent2, earlyGlitterCondition)
    if (cNew != c) {
        c := cNew
        FileAppend("✓ Restored early glitter check to Baspas per-colour timing`n", logFile)
    }

    earlyGlitterBlockPattern :=
    (
        "(?s)[ \t]*;use glitter early if boosted and close to glitter time\r?\n.*?[ \t]*break\r?\n[ \t]*\}"
    )
    earlyGlitterBlockReplacement :=
    (
        '`t`t`t`t`t;use glitter early if boosted and close to glitter time`r`n'
        '`t`t`t`t`tif(PFieldBoosted && field_type!="None" && (nowUnix()-Last%field_type%Boost)>660 && (nowUnix()-Last%field_type%Boost)<900 && (nowUnix()-LastGlitter)>900 && GlitterKey!="none" && (fieldOverrideReason="None" || fieldOverrideReason="Boost")) { ;between 11 and 15 mins`r`n'
        '`t`t`t`t`t`tSend "{" GlitterKey "}"`r`n'
        '`t`t`t`t`t`tLastGlitter := nowUnix()`r`n'
        '`t`t`t`t`t`tLast%field_type%Boost := nowUnix()`r`n'
        '`t`t`t`t`t`tIniWrite LastGlitter, "settings\nm_config.ini", "Boost", "LastGlitter"`r`n'
        '`t`t`t`t`t}`r`n'
        '`t`t`t`t`tbreak`r`n'
        '`t`t`t`t}'
    )
    cNew := RegExReplace(c, earlyGlitterBlockPattern, earlyGlitterBlockReplacement, &earlyBlockCount, 1)
    if (earlyBlockCount > 0 && cNew != c) {
        c := cNew
        FileAppend("✓ Normalized early glitter block to canonical Baspas-style section`n", logFile)
    }

    boostExpiryPattern := '(?ms)\t\t\t\t;boost is over\r?\n\t\t\t\tif \(fieldOverrideReason="Boost" && \(nowUnix\(\)-GatherFieldBoostedStart>900\) && \(nowUnix\(\)-LastGlitter>900\)\) \{\r?\n\t\t\t\t\tinterruptReason := "Boost Over"\r?\n\t\t\t\t\tbreak\r?\n\t\t\t\t\}'
    boostExpiryReplacement := JoinLines(
        '`t`t`t`t;boost is over',
        '`t`t`t`tif (fieldOverrideReason="Boost" && (nowUnix()-GatherFieldBoostedStart>900) && (nowUnix()-LastGlitter>900)) {',
        '`t`t`t`t`tif (FieldName != "Pine Tree") {',
        '`t`t`t`t`t`tIniWrite("None", "settings\nm_config.ini", "Boost", "LastBoostedField")',
        '`t`t`t`t`t`tIniWrite(0, "settings\nm_config.ini", "Boost", "LastBoostedTime")',
        '`t`t`t`t`t}',
        '`t`t`t`t`tinterruptReason := "Boost Over"',
        '`t`t`t`t`tbreak',
        '`t`t`t`t}'
    )
    cNew := RegExReplace(c, boostExpiryPattern, boostExpiryReplacement, &boostExpiryCount, 1)
    if (boostExpiryCount > 0 && cNew != c) {
        c := cNew
        FileAppend("✓ Clear stored boosted field when boost expires outside Pine Tree`n", logFile)
    }
    }

    ; 1l6. Bitterberry feeder: replace the full function with the synced mutation-aware version
    if (patchAutoBitter) {
    if (bbStart := InStr(c, 'nm_BitterberryFeeder(*)')) && (bbEnd := InStr(c, 'nm_BasicEggHatcher(*)', , bbStart)) {
        bb := SubStr(c, bbStart, bbEnd - bbStart)
        bbPatched := ReadPatchBlock(patchTemplateDir "\bitterberry_full_patch.txt")
        if (bbPatched = "") {
            FileAppend("⚠ Skipped Bitterberry sync because patch_templates\\bitterberry_full_patch.txt is missing`n", logFile)
        } else if (bb != bbPatched) {
            c := SubStr(c, 1, bbStart-1) bbPatched SubStr(c, bbEnd)
            FileAppend("âœ“ Synced full Bitterberry feeder mutation patch`n", logFile)
        }
    }
    }

    ; 1l7. Auto-Jelly: replace only the Auto-Jelly block.
    ; In clean Natro, unrelated Credits/Status functions live between blc_mutations(*) and
    ; nm_RoyalJellyDis(), so using nm_RoyalJellyDis() as the end anchor corrupts later code.
    if (patchAutoJelly) {
    if (ajStart := InStr(c, 'blc_mutations(*) {')) && (ajEnd := InStr(c, '; CREDITS TAB', , ajStart)) {
        aj := SubStr(c, ajStart, ajEnd - ajStart)
        ajPatched := ReadPatchBlock(patchTemplateDir "\autojelly_full_patch.txt")
        if (ajPatched = "") {
            FileAppend("⚠ Skipped Auto-Jelly sync because patch_templates\\autojelly_full_patch.txt is missing`n", logFile)
        } else if !RegExMatch(ajPatched, 's)(?=\s*nm_RoyalJellyDis\(\)\{)', &templateEnd)
            templateEnd := 0
        else
            templateEnd := templateEnd.Pos
        if templateEnd
            ajPatched := RTrim(SubStr(ajPatched, 1, templateEnd - 1), "`r`n")
        if (ajPatched != "" && aj != ajPatched) {
            c := SubStr(c, 1, ajStart-1) ajPatched "`r`n`r`n" SubStr(c, ajEnd)
            FileAppend("âœ“ Synced full Auto-Jelly mutation patch`n", logFile)
        }
    } else if (InStr(c, 'blc_mutations(*) {')) {
            FileAppend("âš  Skipped Auto-Jelly sync because the end anchor '; CREDITS TAB' was not found after blc_mutations(*)`n", logFile)
    }
    }

    ; Do not cross-sync whole runtime functions from a local clean source.
    ; That is too brittle across Natro versions and can corrupt later function boundaries.
    ; Keep runtime patching anchor-based instead.
    ; 1i. (Removed) TadSync args are no longer passed via Run command
    ; They are read directly from nm_config.ini by tadsync_InitSettings() in tadsync_status_extension.ahk
    ; This makes the patch immune to Natro adding/removing args in the future
    
    if enableRiskyCoreHooks {
    ; 1m. Inject Mondo Alt Hop Check into MondoInterrupt
    if !InStr(c, 'tadsync_AltHopCheck()') {
        pattern := '(nm_MondoInterrupt\(\)\s*=>\s*)\('
        c := RegExReplace(c, pattern, '$1(tadsync_AltHopCheck()) || (')
        FileAppend("âœ“ Injected tadsync_AltHopCheck into nm_MondoInterrupt`n", logFile)
    }

    ; 1m2. Ensure nm_Mondo has Alt Hop globals available
    if (pos := InStr(c, 'nm_Mondo(){')) {
        mondoBlock := SubStr(c, pos, 600)
        if !InStr(mondoBlock, 'AltHopMondoEnabled') {
            pattern := '(nm_Mondo\(\)\{\r?\n\s*global [^\r\n]*LastGlitter)'
            c := RegExReplace(c, pattern, '$1, AltHopMondoEnabled, AltHopMondoState')
            FileAppend("Ã¢Å“â€œ Added Alt Hop globals to nm_Mondo`n", logFile)
        } else if !InStr(mondoBlock, 'AltHopMondoState') {
            pattern := '(nm_Mondo\(\)\{\r?\n\s*global [^\r\n]*AltHopMondoEnabled)'
            c := RegExReplace(c, pattern, '$1, AltHopMondoState')
            FileAppend("Ã¢Å“â€œ Added AltHopMondoState global to nm_Mondo`n", logFile)
        }
    }

    ; 1n. Inject Mondo Sniper into DisconnectCheck
    if !InStr(c, "tadsync_MondoSniper()") {
        pattern := '(DisconnectCheck\(testCheck := 0\)\s*\{)'
        c := RegExReplace(c, pattern, '$1`r`n`ttadsync_MondoSniper()')
        FileAppend("âœ“ Injected Mondo Sniper into DisconnectCheck`n", logFile)
    }
    
    ; 1o. Inject Mondo Dodge into nm_Mondo
    if !InStr(c, 'tadsync_StartMondoDodge()') {
        ; Start dodging at the beginning of the Kill loop
        pattern := 'm)(\} else if\(MondoAction="Kill"\)\{)'
        replacement := '$1`r`n`t`t`t`t`ttadsync_StartMondoDodge()'
        c := RegExReplace(c, pattern, replacement)
        
        ; Stop dodging on interrupt
        pattern := 'm)(if\(VBState=1 \|\| AFBrollingDice \|\| AFBuseGlitter \|\| AFBuseBooster\) \{)(\r?\n\s+)(return)'
        replacement := '$1$2nm_endWalk()$2$3'
        c := RegExReplace(c, pattern, replacement)
        
        ; Stop dodging on timeout
        pattern := 'm)(if\(A_Index=3600\) \{)(\r?\n\s+)(repeat:=0)'
        replacement := '$1$2nm_endWalk()$2$3'
        c := RegExReplace(c, pattern, replacement)
        
        FileAppend("âœ“ Injected Mondo pattern dodge logic`n", logFile)
    }
    
    ; Fix syntax error if comma operator was used with return (AHK v2 restriction)
    if InStr(c, "nm_endWalk(), return") {
        c := StrReplace(c, "nm_endWalk(), return", "nm_endWalk()`r`n`t`t`t`t`treturn")
        FileAppend("âœ“ Fixed Mondo dodge syntax error (comma return)`n", logFile)
    }
    if InStr(c, "nm_endWalk(), repeat:=0") {
        c := StrReplace(c, "nm_endWalk(), repeat:=0", "nm_endWalk()`r`n`t`t`t`t`trepeat:=0")
        FileAppend("âœ“ Fixed Mondo dodge syntax error (comma repeat)`n", logFile)
    }

    ; 1w. Give Mondo first priority in main loop (run before all other tasks)
    if !InStr(c, '; MONDO FIRST PRIORITY') {
        pattern := '(nm_Start\(\)\{[\s\S]*?)(Loop\s*\r?\n\s+for i in priorityList)'
        replacement := '$1; MONDO FIRST PRIORITY`r`n`tnm_Mondo()`r`n`t$2'
        c := RegExReplace(c, pattern, replacement)
        FileAppend("âœ“ Injected Mondo first priority in nm_Start`n", logFile)
    }

    ; 1p. Prevent Mondo early exit during Alt Hop (Buff bypass)
    if !InStr(c, '&& !AltHopMondoState') {
        pattern := 's)(mondobuff := nm_imgSearch\("mondobuff\.png",50,"buff"\)\r?\n\s+If \(mondobuff\[1\] = 0\)) (\{)'
        c := RegExReplace(c, pattern, '$1 && !AltHopMondoState $2')
        FileAppend("âœ“ Patched Mondo buff exit bypass`n", logFile)
    }

    ; 1p2. Keep nm_Mondo alive through night while Alt Hop is active
    if !InStr(c, 'AltHopMondoEnabled && tadsync_isMondoTime()') {
        pattern := 'm)^(\s*)if\s*\(\s*nm_NightInterrupt\(\)\s*\)\s*\r?\n\1\t?return'
        replacement := '$1if (nm_NightInterrupt() && !(AltHopMondoEnabled && tadsync_isMondoTime()))`r`n$1`treturn'
        cNew := RegExReplace(c, pattern, replacement, &count, 1)
        if (count > 0) {
            c := cNew
            FileAppend("Ã¢Å“â€œ Patched nm_Mondo early night exit for Alt Hop`n", logFile)
        }
    }

    ; 1p3. Prevent the kill loop from aborting during an active Alt Hop run
    if !InStr(c, 'if(!AltHopMondoState && (nm_NightInterrupt() || AFBrollingDice || AFBuseGlitter || AFBuseBooster))') {
        pattern := 'm)if\s*\(\s*nm_NightInterrupt\(\)\s*\|\|\s*AFBrollingDice\s*\|\|\s*AFBuseGlitter\s*\|\|\s*AFBuseBooster\s*\)\s*\{'
        replacement := 'if(!AltHopMondoState && (nm_NightInterrupt() || AFBrollingDice || AFBuseGlitter || AFBuseBooster)) {'
        cNew := RegExReplace(c, pattern, replacement, &count, 1)
        if (count > 0) {
            c := cNew
            FileAppend("Ã¢Å“â€œ Patched nm_Mondo kill-loop interrupt guard for Alt Hop`n", logFile)
        }
    }

    ; 1q. Replace loot guard with tadsync_CollectMondoLoot branching
    ; First: remove old '&& !AltHopMondoState' guard if it exists from a previous patch
    if InStr(c, '&& !AltHopMondoState {') {
        c := StrReplace(c, '!(MondoLootDirection = "Ignore") && !AltHopMondoState {', '!(MondoLootDirection = "Ignore") {')
        FileAppend("âœ“ Removed old AltHopMondoState loot guard`n", logFile)
    }
    ; Then: remove old inline 'if(AltHopMondoState) LastMondoBuff:=nowUnix()' if it exists
    if InStr(c, 'if(AltHopMondoState) LastMondoBuff:=nowUnix()') {
        c := StrReplace(c, "`t`t`t`t`t`tif(AltHopMondoState) LastMondoBuff:=nowUnix()`r`n", "")
        FileAppend("âœ“ Removed old AltHopMondoState inline LastMondoBuff`n", logFile)
    }
    ; Now inject tadsync_CollectMondoLoot branching
    if !InStr(c, 'tadsync_CollectMondoLoot()') {
        pattern := 'm)(\s+if !\(MondoLootDirection = "Ignore"\) \{\r?\n\s+;loot mondo after death\r?\n)(\s+if)'
        replacement := '$1`t`t`t`t`t`t`t`tif (AltHopMondoState) {`r`n`t`t`t`t`t`t`t`t`ttadsync_CollectMondoLoot()`r`n`t`t`t`t`t`t`t`t} else {`r`n$2'
        c := RegExReplace(c, pattern, replacement)
        ; Close the else block after click "up"
        pattern := 'm)(\s+click "up"\r?\n)(\s+\}\r?\n\s+\})'
        replacement := '$1`t`t`t`t`t`t`t`t}`r`n$2'
        c := RegExReplace(c, pattern, replacement)
        FileAppend("âœ“ Injected tadsync_CollectMondoLoot branching`n", logFile)
    }

    ; 1q2. Inject state transition signal after loot section
    if !InStr(c, 'AltHopMondoState := 1') {
        pattern := 'm)(\s+click "up"\r?\n\s+\}\r?\n)(\s+\}\r?\n\s+\}\r?\n\s+\}\r?\n\s+\}\r?\n\s+\}\r?\n\s+else)'
        replacement := '$1`t`t`t`t`t`t`t; Signal extension: kill+loot done, ready to hop`r`n`t`t`t`t`t`t`tif (AltHopMondoState) {`r`n`t`t`t`t`t`t`t`tAltHopMondoState := 1`r`n`t`t`t`t`t`t`t`tIniWrite AltHopMondoState, "settings\nm_config.ini", "Extensions", "AltHopMondoState"`r`n`t`t`t`t`t`t`t}`r`n$2'
        c := RegExReplace(c, pattern, replacement)
        FileAppend("âœ“ Injected AltHopMondoState transition signal`n", logFile)
    }

    ; 1q3. Clean up legacy hop signal and hand off post-Mondo flow to the extension
    legacyPattern := 'ms)\r?\n\s*; Signal extension: kill\+loot done, ready to hop\r?\n\s*if \(AltHopMondoState\) \{\r?\n\s*AltHopMondoState := 1\r?\n\s*IniWrite AltHopMondoState, "settings\\nm_config\.ini", "Extensions", "AltHopMondoState"\r?\n\s*\}\r?\n'
    if RegExMatch(c, legacyPattern) {
        c := RegExReplace(c, legacyPattern, "`r`n")
        FileAppend("Ã¢Å“â€œ Removed legacy AltHopMondoState transition signal`n", logFile)
    }
    if !InStr(c, 'tadsync_AfterMondoAttempt()') {
        pattern := 'm)^(\s*)LastMondoBuff:=nowUnix\(\)\r?\n\1IniWrite LastMondoBuff, "settings\\nm_config\.ini", "Collect", "LastMondoBuff"\r?\n'
        replacement := '$0$1if (AltHopMondoState = 1 || AltHopMondoState = 3) {`r`n$1`tadsync_AfterMondoAttempt()`r`n$1`treturn`r`n$1}`r`n'
        cNew := RegExReplace(c, pattern, replacement, &count, 1)
        if (count > 0) {
            c := cNew
            FileAppend("Ã¢Å“â€œ Injected tadsync_AfterMondoAttempt hook`n", logFile)
        }
    }
    afterMondoNormalizePattern := '(?m)^(\s*)LastMondoBuff:=nowUnix\(\)\r?\n^\1IniWrite LastMondoBuff, "settings\\nm_config\.ini", "Collect", "LastMondoBuff"\r?\n(?:^\1if \(AltHopMondoState = 1 \|\| AltHopMondoState = 3\) \{\r?\n^\1\tadsync_AfterMondoAttempt\(\)\r?\n^\1\treturn\r?\n^\1\}\r?\n)+^\1return\r?\n'
    afterMondoNormalizeReplace := '$1LastMondoBuff:=nowUnix()`r`n$1IniWrite LastMondoBuff, "settings\nm_config.ini", "Collect", "LastMondoBuff"`r`n$1if (AltHopMondoState = 1 || AltHopMondoState = 3) {`r`n$1`tadsync_AfterMondoAttempt()`r`n$1`treturn`r`n$1}`r`n$1return`r`n'
    cNew := RegExReplace(c, afterMondoNormalizePattern, afterMondoNormalizeReplace, &afterMondoNormalizeCount, 1)
    if (afterMondoNormalizeCount > 0 && cNew != c) {
        c := cNew
        FileAppend("✓ Normalized post-Mondo AltHop handoff block to working layout`n", logFile)
    }

    ; 1r. Bypass Mondo travel/reset during Alt Hop
    if !InStr(c, 'if(AltHopMondoState) {') && InStr(c, 'nm_gotoPlanter("mountain top")') {
        if !InStr(c, 'AltHopMondoState')
            c := RegExReplace(c, 'm)^(\s+global VBState)', '$1, AltHopMondoState')
        if !InStr(c, 'if(!AltHopMondoState)')
            c := RegExReplace(c, 'm)^(\s+)(nm_Reset\(0, 2000, 0\))', '$1if(!AltHopMondoState)`r`n$1`t$2')
        if !InStr(c, 'if(AltHopMondoState) {') {
            pattern := 'm)^(\s+)(nm_gotoPlanter\("mountain top"\))'
            replacement := '$1if(AltHopMondoState) {`r`n$1`tnm_gotoField("Mountain Top")`r`n$1} else {`r`n$1`t$2`r`n$1}'
            c := RegExReplace(c, pattern, replacement)
        }
        FileAppend("âœ“ Patched Mondo travel/reset bypass`n", logFile)
    }

    ; 1t. Improve Mondo discovery timeout for Alt Hop
    if !InStr(c, 'loop (AltHopMondoState ? 480 : 20)') {
        pattern := 'loop 20\s*\{\s*mChick:= nm_HealthDetection\(\)'
        replacement := 'loop (AltHopMondoState ? 480 : 20)`r`n`t`t`t{`r`n`t`t`t`tmChick:= nm_HealthDetection()'
        c := RegExReplace(c, pattern, replacement)
        FileAppend("âœ“ Patched Mondo discovery timeout`n", logFile)
    }

    ; 1u. Simplify LastMondoBuff update (remove old conditional wrapper if present)
    if InStr(c, 'if (!AltHopMondoState || repeat = 0) {') {
        c := StrReplace(c, "`t`tif (!AltHopMondoState || repeat = 0) {`r`n`t`t`tLastMondoBuff:=nowUnix()", "`t`tLastMondoBuff:=nowUnix()")
        c := StrReplace(c, "`t`tIniWrite LastMondoBuff, `"settings\nm_config.ini`", `"Collect`", `"LastMondoBuff`"`r`n`t`t}", "`t`tIniWrite LastMondoBuff, `"settings\nm_config.ini`", `"Collect`", `"LastMondoBuff`"")
        FileAppend("âœ“ Simplified LastMondoBuff update`n", logFile)
    }

    ; 1u2. Allow the extension to force public/private reconnect targets during Mondo Hop
    if !InStr(c, 'overrideServer := tadsync_GetReconnectOverride(PossibleServers)') {
        pattern := 'm)^(\s*;Decide Server\r?\n)(\s*)server := (.*)$'
        replacement := '$1$2overrideServer := tadsync_GetReconnectOverride(PossibleServers)`r`n$2server := (overrideServer >= 0) ? overrideServer : $3'
        cNew := RegExReplace(c, pattern, replacement, &count, 1)
        if (count > 0) {
            c := cNew
            FileAppend("Ã¢Å“â€œ Injected reconnect override hook`n", logFile)
        }
    }

    ; 1u3. Notify the extension when reconnect succeeds so it can advance hop state
    if !InStr(c, 'tadsync_OnReconnectSuccess(server)') {
        pattern := 'm)^(\s*)if \(testCheck \|\| \(nm_claimHiveSlot\(\) = 1\)\)$'
        replacement := '$1tadsync_OnReconnectSuccess(server)`r`n$1if (testCheck || (nm_claimHiveSlot() = 1))'
        cNew := RegExReplace(c, pattern, replacement, &count, 1)
        if (count > 0) {
            c := cNew
            FileAppend("Ã¢Å“â€œ Injected reconnect success hook`n", logFile)
        }
    }
    }

    ; 1v. Rename GUI to "Mondo Hop" and add loot time edit
    if InStr(c, '"Mondo Alt Hop"') {
        c := StrReplace(c, '"Mondo Alt Hop"', '"Mondo Hop"')
        FileAppend("âœ“ Renamed group box to Mondo Hop`n", logFile)
    }
    if InStr(c, '"Alt Hop: ON"') {
        c := StrReplace(c, '"Alt Hop: ON"', '"Mondo Hop: ON"')
        c := StrReplace(c, '"Alt Hop: OFF"', '"Mondo Hop: OFF"')
        FileAppend("âœ“ Renamed toggle to Mondo Hop`n", logFile)
    }
    if !InStr(c, 'vMondoHopLootTimeEdit') {
        pattern := '(MainGui\.Add\("Button", "x310 y81 w80 h22 vAltHopMondoTest", "Test Mondo"\)\.OnEvent\("Click", tadsync_AltHop_TestMondo\))'
        replacement := '$1`r`nMainGui.Add("Text", "x400 y84", "Loot Time (s):")`r`nMainGui.Add("Edit", "x460 y81 w25 h22 Number vMondoHopLootTimeEdit", MondoHopLootTime).OnEvent("Change", aq_MondoHopSaveLootTime)'
        c := RegExReplace(c, pattern, replacement)
        FileAppend("âœ“ Added Loot Time edit to GUI`n", logFile)
    }

    if InStr(c, 'tadsync_AltHop_SaveLootTime') {
        c := StrReplace(c, 'tadsync_AltHop_SaveLootTime', 'aq_MondoHopSaveLootTime')
        FileAppend("Ã¢Å“â€œ Updated Loot Time callback to aq_MondoHopSaveLootTime`n", logFile)
    }

    ; Final hotbarwhilelist safety pass in case a later replacement restored the old list.
    if (patchGlitterExtend) {
        hotbarListHasGlitter := false
        if RegExMatch(c, 'm)^hotbarwhilelist\s*:=\s*\[(?<list>[^\]]*)\]', &hotbarMatch)
            hotbarListHasGlitter := InStr(hotbarMatch["list"], '"Glitter"') > 0
        if !hotbarListHasGlitter {
            cNew := RegExReplace(c, 'm)^(hotbarwhilelist\s*:=\s*\[[^\]]*"Snowflake")(\s*[,\]])', '$1,"Glitter"$2', , 1)
            if (cNew != c) {
                c := cNew
                FileAppend("✓ Re-applied Glitter to hotbarwhilelist after later patch steps`n", logFile)
            }
        }
    }

    if (c != orig) {
        try {
            ; Ensure we don't overwrite PFieldBoosted INI value by removing it from
            ; the startup initialization list if present.
            c := RegExReplace(c, 'm)for k,v in \["PMondoGuid","PMondoGuidComplete",\s*"PFieldBoosted",', 'for k,v in ["PMondoGuid","PMondoGuidComplete",')
            ; Final Sticker Stack safety pass so older partial transforms cannot leave
            ; nm_StickerStack() on the old 2-attempt implementation.
            canonicalStickerStack := ReadPatchBlock(patchTemplateDir "\stickerstack_full_patch.txt")
            if (canonicalStickerStack != "") {
                c := RegExReplace(c, '(?ms)^nm_StickerStack\(resetBeforeTravel := 1\)\{.*?^\}\r?\n(?=nm_shrine\(\)\{)', canonicalStickerStack "`r`n", , 1)
            }
            ; Final AltHop safety pass so repeated patch runs do not keep adding
            ; more AfterMondoAttempt handoff blocks.
            canonicalAfterMondoBlock :=
            (
            '			LastMondoBuff:=nowUnix()`r`n'
            . '			IniWrite LastMondoBuff, "settings\nm_config.ini", "Collect", "LastMondoBuff"`r`n'
            . '			if (AltHopMondoState = 1 || AltHopMondoState = 3) {`r`n'
            . '				adsync_AfterMondoAttempt()`r`n'
            . '				return`r`n'
            . '			}`r`n'
            . '			return`r`n'
            )
            c := RegExReplace(
                c,
                '(?ms)^\t\t\tLastMondoBuff:=nowUnix\(\)\r?\n^\t\t\tIniWrite LastMondoBuff, "settings\\nm_config\.ini", "Collect", "LastMondoBuff"\r?\n(?:^\t\t\tif \(AltHopMondoState = 1 \|\| AltHopMondoState = 3\) \{\r?\n^\t\t\t\tadsync_AfterMondoAttempt\(\)\r?\n^\t\t\t\treturn\r?\n^\t\t\t\}\r?\n)+^\t\t\treturn\r?\n',
                canonicalAfterMondoBlock,
                ,
                1
            )
            ; Final convert-start safety pass so repeated patch runs do not keep
            ; adding more Sticker Stack checks before hwnd initialization.
            canonicalConvertStart :=
            (
            '	if (nm_NightInterrupt() || nm_MondoInterrupt())`r`n'
            . '		return`r`n'
            . '	if nm_HandleStickerStackInterrupt(1, 0, 0)`r`n'
            . '		return`r`n'
            . '	hwnd := GetRobloxHWND()'
            )
            c := RegExReplace(
                c,
                '(?ms)^\tif \(nm_NightInterrupt\(\) \|\| nm_MondoInterrupt\(\)\)\r?\n^\t\treturn\r?\n(?:^\tif nm_HandleStickerStackInterrupt\(1, 0, 0\)\r?\n^\t\treturn\r?\n)+^\thwnd := GetRobloxHWND\(\)',
                canonicalConvertStart,
                ,
                1
            )

            tempNat := natroPath ".tmp"

            ; Attempt to write temp file with retries, then fallback to no-encoding append
            writeTempOk := false
            tempAttempts := 0
            lastError := ""
            FileAppend("Temp file path: " tempNat "`n", logFile)
            while (tempAttempts < 6) {
                try {
                    if FileExist(tempNat)
                        FileDelete(tempNat)
                    FileAppend(c, tempNat, "UTF-8")
                    writeTempOk := true
                    break
                } catch as e {
                    lastError := e.Message
                    tempAttempts += 1
                    Sleep(300)
                }
            }

            if (!writeTempOk) {
                try {
                    if FileExist(tempNat)
                        FileDelete(tempNat)
                    FileAppend(c, tempNat)
                    writeTempOk := true
                } catch as e {
                    lastError := e.Message
                    try {
                        FileAppend("âš  FAILED to write temp natro file after retries: " lastError "`n", logFile)
                    } catch {
                    }
                }
            }

            if (writeTempOk) {
                moved := false
                attempts := 0
                while (attempts < 6) {
                    try {
                        FileDelete(natroPath)
                        FileMove(tempNat, natroPath, 1)
                        moved := true
                        break
                    } catch {
                        attempts += 1
                        Sleep(500)
                    }
                }

                if (moved) {
                    msg .= "âœ“ natro_macro.ahk patched and sanitized`n"
                    ; resilient log write
                    logAttempts := 0
                    while (logAttempts < 6) {
                        try {
                            FileAppend("âœ“ Patched Run arguments and GUI in natro_macro.ahk`n", logFile)
                            break
                        } catch {
                            logAttempts += 1
                            Sleep(200)
                        }
                    }
                } else {
                    msg .= "âš  FAILED to move patched file into place (file locked)\n"
                    try {
                        FileAppend("âš  FAILED to move patched natro_macro.ahk into place`n", logFile)
                    } catch {
                    }
                }
            } else {
                msg .= "âš  FAILED to write patched natro_macro temp file; skipping natro write`n"
            }
        } catch {
            msg .= "âš  FAILED to write natro_macro.ahk`n"
        }
    } else {
        msg .= "Â· natro_macro.ahk no changes needed`n"
    }


}

; 2. PATCH STATUS.AHK
if FileExist(statusPath) {
    c := FileRead(statusPath, "UTF-8")
    orig := c

    if (patchTadSyncCore) {
    ; 2a0. Clean up old submacros/ includes (migrate to Extensions/ path)
    c := RegExReplace(c, 'm)#Include "%A_ScriptDir%\\tadsync_(\w+)\.ahk"', '#Include "%A_ScriptDir%\..\Extensions\tadsync_$1.ahk"')

    ; 2a. Dynamic includes from Extensions/ folder for Status.ahk
    extDir := workDir "\Extensions"
    if DirExist(extDir) {
        loop files extDir "\*status*.ahk" {
            extFile := A_LoopFileName
            includeStr := '#Include "%A_ScriptDir%\..\Extensions\' extFile '"`r`n'
            if !InStr(c, extFile) {
                if (pos := InStr(c, "SetWorkingDir")) {
                    if (endPos := InStr(c, "`n", , pos)) {
                        c := SubStr(c, 1, endPos) includeStr SubStr(c, endPos+1)
                        FileAppend("âœ“ Auto-included Extensions\\" extFile " in Status.ahk`n", logFile)
                    }
                }
            }
        }
    }

    ; 2b. Field Announcement Hook
    if !InStr(c, "0x5561") {
        if (pos := InStr(c, "OnMessage(0x5556, nm_sendHeartbeat)")) {
            if (endPos := InStr(c, "`n", , pos)) {
                c := SubStr(c, 1, endPos) "OnMessage(0x5561, aq_announce)`r`n" SubStr(c, endPos+1)
                FileAppend("âœ“ Added Field Announcement hook (0x5561) to Status.ahk`n", logFile)
            }
        }
    }
    if !InStr(c, "0x5562") {
        cNew := StrReplace(c, "OnMessage(0x5561, aq_announce)`r`n", "OnMessage(0x5561, aq_announce)`r`nOnMessage(0x5562, aq_announceHiveStandby)`r`n")
        if (cNew != c) {
            c := cNew
            FileAppend("✓ Added Hive standby announcement hook (0x5562) to Status.ahk`n", logFile)
        }
    }

    ; 2c. Main loop call
    if !InStr(c, "aq_getFollowingField") {
        if (pos := InStr(c, "discord.GetCommands(MainChannelID)")) {
            if (endPos := InStr(c, "`n", , pos)) {
                c := SubStr(c, 1, endPos) "`t(Mod(A_Index, 5) = 0 && FieldFollowingCheck) && aq_getFollowingField()`r`n" SubStr(c, endPos+1)
                FileAppend("âœ“ Added aq_getFollowingField call to Status.ahk`n", logFile)
            }
        }
    }

    ; 2c. (Removed) TadSync A_Args are no longer injected into Status.ahk
    ; tadsync_InitSettings() in tadsync_status_extension.ahk reads them from nm_config.ini directly

    ; Guard startup embed so submacro restarts do not spam Discord when integration is disabled.
    if InStr(c, 'discord.SendEmbed("Connected to Discord!", 5066239)') && !InStr(c, 'if (discordCheck = 1)') {
        c := StrReplace(c, 'discord.SendEmbed("Connected to Discord!", 5066239)', 'if (discordCheck = 1)`r`n`tdiscord.SendEmbed("Connected to Discord!", 5066239)')
        FileAppend("âœ“ Guarded Discord startup embed behind discordCheck`n", logFile)
    }
    }

    if (patchForceHourly) {
    if !InStr(c, 'Forces an immediate generation of the Hourly Report') {
        helpPattern := 's)(\{\R\s*"value": "Sets the command prefix, e\.g\. .*?",\R\s*"inline": true\R\s*\})'
        helpReplacement := '$1,`r`n`t`t`t`t`t{`r`n`t`t`t`t`t`t"name": "' "' commandPrefix 'hourlyreport" '",`r`n`t`t`t`t`t`t"value": "Forces an immediate generation of the Hourly Report",`r`n`t`t`t`t`t`t"inline": true`r`n`t`t`t`t`t}'
        cNew := RegExReplace(c, helpPattern, helpReplacement, &hourlyHelpCount, 1)
        if (hourlyHelpCount > 0) {
            c := cNew
            FileAppend("✓ Added hourlyreport help entry to Status.ahk`n", logFile)
        }
    }
    }

    if (patchStickerStack) {
    if !InStr(c, 'Forces the Sticker Stack interrupt path to trigger on the next check') {
        helpPattern := InStr(c, 'Forces an immediate generation of the Hourly Report')
            ? 's)(\{\R\s*"name": "' "' commandPrefix 'hourlyreport" '",\R\s*"value": "Forces an immediate generation of the Hourly Report",\R\s*"inline": true\R\s*\})'
            : 's)(\{\R\s*"value": "Sets the command prefix, e\.g\. .*?",\R\s*"inline": true\R\s*\})'
        helpReplacement := '$1,`r`n`t`t`t`t`t{`r`n`t`t`t`t`t`t"name": "' "' commandPrefix 'stickerstack" '",`r`n`t`t`t`t`t`t"value": "Forces the Sticker Stack interrupt path to trigger on the next check",`r`n`t`t`t`t`t`t"inline": true`r`n`t`t`t`t`t}'
        cNew := RegExReplace(c, helpPattern, helpReplacement, &stickerHelpCount, 1)
        if (stickerHelpCount > 0) {
            c := cNew
            FileAppend("✓ Added stickerstack help entry to Status.ahk`n", logFile)
        }
    }
    }

    if (patchBfb) {
    if !InStr(c, 'Forces the Blue Field Booster interrupt path to trigger on the next check') {
        helpPattern := InStr(c, 'Forces the Sticker Stack interrupt path to trigger on the next check')
            ? 's)(\{\R\s*"name": "' "' commandPrefix 'stickerstack" '",\R\s*"value": "Forces the Sticker Stack interrupt path to trigger on the next check",\R\s*"inline": true\R\s*\})'
            : InStr(c, 'Forces an immediate generation of the Hourly Report')
                ? 's)(\{\R\s*"name": "' "' commandPrefix 'hourlyreport" '",\R\s*"value": "Forces an immediate generation of the Hourly Report",\R\s*"inline": true\R\s*\})'
                : 's)(\{\R\s*"value": "Sets the command prefix, e\.g\. .*?",\R\s*"inline": true\R\s*\})'
        helpReplacement := '$1,`r`n`t`t`t`t`t{`r`n`t`t`t`t`t`t"name": "' "' commandPrefix 'fb" '",`r`n`t`t`t`t`t`t"value": "Forces the Blue Field Booster interrupt path to trigger on the next check",`r`n`t`t`t`t`t`t"inline": true`r`n`t`t`t`t`t}'
        cNew := RegExReplace(c, helpPattern, helpReplacement, &fbHelpCount, 1)
        if (fbHelpCount > 0) {
            c := cNew
            FileAppend("✓ Added fb help entry to Status.ahk`n", logFile)
        }
    }
    }

    if (patchAutoJelly) {
    if !InStr(c, 'Clicks Yes on the active Auto-Jelly prompt') {
        helpPattern := InStr(c, 'Forces the Sticker Stack interrupt path to trigger on the next check')
            ? 's)(\{\R\s*"name": "' "' commandPrefix 'stickerstack" '",\R\s*"value": "Forces the Sticker Stack interrupt path to trigger on the next check",\R\s*"inline": true\R\s*\})'
            : InStr(c, 'Forces an immediate generation of the Hourly Report')
                ? 's)(\{\R\s*"name": "' "' commandPrefix 'hourlyreport" '",\R\s*"value": "Forces an immediate generation of the Hourly Report",\R\s*"inline": true\R\s*\})'
                : 's)(\{\R\s*"value": "Sets the command prefix, e\.g\. .*?",\R\s*"inline": true\R\s*\})'
        helpReplacement := '$1,`r`n`t`t`t`t`t{`r`n`t`t`t`t`t`t"name": "' "' commandPrefix 'yes" '",`r`n`t`t`t`t`t`t"value": "Clicks Yes on the active Auto-Jelly prompt",`r`n`t`t`t`t`t`t"inline": true`r`n`t`t`t`t`t},`r`n`t`t`t`t`t{`r`n`t`t`t`t`t`t"name": "' "' commandPrefix 'no" '",`r`n`t`t`t`t`t`t"value": "Clicks No on the active Auto-Jelly prompt",`r`n`t`t`t`t`t`t"inline": true`r`n`t`t`t`t`t}'
        cNew := RegExReplace(c, helpPattern, helpReplacement, &autojellyHelpCount, 1)
        if (autojellyHelpCount > 0) {
            c := cNew
            FileAppend("✓ Added Auto-Jelly yes/no help entries to Status.ahk`n", logFile)
        }
    }
    c := StrReplace(c, '"Keeps/replaces an amulet if prompt is on screen"', '"Keeps/replaces an amulet prompt if it is on screen"')
    }

    if (patchForceHourly) {
    if !InStr(c, 'case "hourlyreport", "hr":') {
        commandNeedle := '`t`tcase "close":'
        commandInsert := JoinLines(
            '',
            '',
            '`t`tcase "hourlyreport", "hr":',
            '`t`t{',
            '`t`t`tSetTitleMatchMode 2',
            '`t`t`tDetectHiddenWindows 1',
            '`t`t`tif (hwnd := WinExist("StatMonitor"))',
            '`t`t`t{',
            '`t`t`t`tPostMessage 0x5563, 1, 0,, "ahk_id " hwnd',
            '`t`t`t`tdiscord.SendEmbed("Requested Hourly Report generation.", 5066239, , , , id)',
            '`t`t`t}',
            '`t`t`telse',
            '`t`t`t{',
            '`t`t`t`tdiscord.SendEmbed("Error: StatMonitor script not found! Make sure it is open.", 16711731, , , , id)',
            '`t`t`t}',
            '`t`t}',
            '',
            '',
            commandNeedle
        )
        cNew := StrReplace(c, commandNeedle, commandInsert)
        if (cNew != c) {
            c := cNew
            FileAppend("✓ Added hourlyreport command to Status.ahk`n", logFile)
        }
    }
    }

    if (patchStickerStack) {
    if !InStr(c, 'case "stickerstack", "stacktest", "ssforce":') {
        commandNeedle := '`t`tcase "close":'
        commandInsert := JoinLines(
            '',
            '',
            '`t`tcase "stickerstack", "stacktest", "ssforce":',
            '`t`t{',
            '`t`t`tDetectHiddenWindows 1',
            '`t`t`tif (hwnd := WinExist("natro_macro ahk_class AutoHotkey"))',
            '`t`t`t{',
            '`t`t`t`tPostMessage 0x5564, 1, 0,, "ahk_id " hwnd',
            '`t`t`t`tdiscord.SendEmbed("Forced Sticker Stack interrupt armed. It will trigger on the next interrupt check.", 5066239, , , , id)',
            '`t`t`t}',
            '`t`t`telse',
            '`t`t`t{',
            '`t`t`t`tdiscord.SendEmbed("Error: Macro not found!", 16711731, , , , id)',
            '`t`t`t}',
            '`t`t}',
            '',
            '',
            commandNeedle
        )
        cNew := StrReplace(c, commandNeedle, commandInsert)
        if (cNew != c) {
            c := cNew
            FileAppend("✓ Added stickerstack force-test command to Status.ahk`n", logFile)
        }
    }
    }

    if (patchBfb) {
    if !InStr(c, 'case "fb", "fieldbooster", "bluebooster":') {
        commandNeedle := '`t`tcase "close":'
        commandInsert := JoinLines(
            '',
            '',
            '`t`tcase "fb", "fieldbooster", "bluebooster":',
            '`t`t{',
            '`t`t`tDetectHiddenWindows 1',
            '`t`t`tif (hwnd := WinExist("natro_macro ahk_class AutoHotkey"))',
            '`t`t`t{',
            '`t`t`t`tPostMessage 0x5565, 1, 0,, "ahk_id " hwnd',
            '`t`t`t`tdiscord.SendEmbed("Forced Blue Field Booster interrupt armed. It will trigger on the next interrupt check.", 5066239, , , , id)',
            '`t`t`t}',
            '`t`t`telse',
            '`t`t`t{',
            '`t`t`t`tdiscord.SendEmbed("Error: Macro not found!", 16711731, , , , id)',
            '`t`t`t}',
            '`t`t}',
            '',
            '',
            commandNeedle
        )
        cNew := StrReplace(c, commandNeedle, commandInsert)
        if (cNew != c) {
            c := cNew
            FileAppend("✓ Added fb force-test command to Status.ahk`n", logFile)
        }
    }
    }

    if (patchAutoJelly) {
    c := StrReplace(c, 'case "yes", "keep":', 'case "yes":')
    c := StrReplace(c, 'case "no", "replace":', 'case "no":')
    if !InStr(c, 'case "yes":') {
        commandNeedle := '`t`tcase "close":'
        commandInsert := JoinLines(
            '',
            '',
            '`t`tcase "yes":',
            '`t`t{',
            '`t`t`tDetectHiddenWindows 1',
            '`t`t`tSetTitleMatchMode 3',
            '`t`t`tif (hwnd := WinExist("Auto-Jelly! ahk_class #32770"))',
            '`t`t`t{',
            '`t`t`t`tControlClick "Button1", "ahk_id " hwnd',
            '`t`t`t`tdiscord.SendEmbed("Clicked Yes on the active Auto-Jelly prompt.", 5066239, , , , id)',
            '`t`t`t}',
            '`t`t`telse',
            '`t`t`t{',
            '`t`t`t`tdiscord.SendEmbed("Error: No active Auto-Jelly prompt found.", 16711731, , , , id)',
            '`t`t`t}',
            '`t`t}',
            '',
            '',
            '`t`tcase "no":',
            '`t`t{',
            '`t`t`tDetectHiddenWindows 1',
            '`t`t`tSetTitleMatchMode 3',
            '`t`t`tif (hwnd := WinExist("Auto-Jelly! ahk_class #32770"))',
            '`t`t`t{',
            '`t`t`t`tControlClick "Button2", "ahk_id " hwnd',
            '`t`t`t`tdiscord.SendEmbed("Clicked No on the active Auto-Jelly prompt.", 5066239, , , , id)',
            '`t`t`t}',
            '`t`t`telse',
            '`t`t`t{',
            '`t`t`t`tdiscord.SendEmbed("Error: No active Auto-Jelly prompt found.", 16711731, , , , id)',
            '`t`t`t}',
            '`t`t}',
            '',
            '',
            commandNeedle
        )
        cNew := StrReplace(c, commandNeedle, commandInsert)
        if (cNew != c) {
            c := cNew
            FileAppend("✓ Added Auto-Jelly yes/no commands to Status.ahk`n", logFile)
        }
    }
    }

    if (patchAutoJelly) {
    if InStr(c, 'content := ((criticalCheck = 1) && discordUID')
    && !InStr(c, 'autoJellyPing := discordUID && InStr(stateString, "Auto-Jelly")') {
        c := StrReplace(c
            , 'content := ((criticalCheck = 1) && discordUID'
            , 'autoJellyPing := discordUID`r`n`t`t`t&& (InStr(stateString, "Auto-Jelly") || InStr(stateString, "Bitterberry Auto-Feeder"))`r`n`t`t`t&& ((state = "Error") || (state = "Failed") || (state = "Warning") || (state = "Detected"))`r`n`t`tcontent := ((((criticalCheck = 1) && discordUID'
        )
        c := StrReplace(
            c
            , '|| ((state = "Obtained") && InStr(stateString, "Amulet"))))'
            , '|| ((state = "Obtained") && InStr(stateString, "Amulet")))))`r`n`t`t`t|| autoJellyPing)'
        )
        FileAppend("✓ Added Auto-Jelly failure ping routing to Status.ahk`n", logFile)
    }
    if InStr(c, '|| ((BalloonSSCheck = 1) && (stateString = "Converting: Balloon"))')
    && !InStr(c, '|| (((state = "Detected") || (state = "Keeping")) && (InStr(stateString, "Auto-Jelly") || InStr(stateString, "Bitterberry Auto-Feeder")))') {
        c := StrReplace(c
            , '|| ((BalloonSSCheck = 1) && (stateString = "Converting: Balloon"))'
            , '|| ((BalloonSSCheck = 1) && (stateString = "Converting: Balloon"))`r`n`t`t`t|| (((state = "Detected") || (state = "Keeping")) && (InStr(stateString, "Auto-Jelly") || InStr(stateString, "Bitterberry Auto-Feeder")))'
        )
        FileAppend("✓ Added Auto-Jelly success screenshot routing to Status.ahk`n", logFile)
    }
    }

    if (c != orig) {
        try {
            FileDelete(statusPath)
            FileAppend(c, statusPath, "UTF-8")
            msg .= "âœ“ Status.ahk patched`n"
        } catch {
            msg .= "âš  FAILED to write Status.ahk`n"
        }
    }
}

; 2b. PATCH STATMONITOR.AHK
if (patchForceHourly || patchStatMonitorTheme) && FileExist(statMonitorPath) {
    if patchForceHourly {
        extraStatMonitorBitmapsText := ReadPatchBlock(patchTemplateDir "\statmonitor_extra_bitmaps_patch.txt")
    if (extraStatMonitorBitmapsText = "" && FileExist(workDir "\nm_image_assets\statmonitor\extra_bitmaps.ahk"))
        extraStatMonitorBitmapsText := ReadPatchBlock(workDir "\nm_image_assets\statmonitor\extra_bitmaps.ahk")
        if (extraStatMonitorBitmapsText != "") {
            DirCreate(workDir "\nm_image_assets\statmonitor")
            if !FileExist(extraStatMonitorBitmapsPath) || (FileRead(extraStatMonitorBitmapsPath, "UTF-8") != extraStatMonitorBitmapsText) {
                try FileDelete(extraStatMonitorBitmapsPath)
                FileAppend(extraStatMonitorBitmapsText, extraStatMonitorBitmapsPath, "UTF-8")
                FileAppend("✓ Synced separate Baspas StatMonitor extra bitmap file`n", logFile)
            }
        } else {
            FileAppend("! Missing StatMonitor extra bitmap template; continuing without extra bitmap file sync`n", logFile)
        }
    }

    if patchStatMonitorTheme {
        mainThemeText := ReadPatchBlock(statMonitorThemeMainTemplatePath)
        if (mainThemeText != "") {
            if !FileExist(statMonitorPath) || (FileRead(statMonitorPath, "UTF-8") != mainThemeText) {
                try FileDelete(statMonitorPath)
                FileAppend(mainThemeText, statMonitorPath, "UTF-8")
                FileAppend("✓ Synced StatMonitor theme-aware base file`n", logFile)
            }
        } else {
            FileAppend("! Missing StatMonitor theme main template; continuing without base file sync`n", logFile)
        }

        runtimeText := ReadPatchBlock(statMonitorThemeRuntimeTemplatePath)
        if (runtimeText != "") {
            if !FileExist(statMonitorThemeRuntimePath) || (FileRead(statMonitorThemeRuntimePath, "UTF-8") != runtimeText) {
                try FileDelete(statMonitorThemeRuntimePath)
                FileAppend(runtimeText, statMonitorThemeRuntimePath, "UTF-8")
                FileAppend("✓ Synced StatMonitor theme runtime file`n", logFile)
            }
        } else {
            FileAppend("! Missing StatMonitor theme runtime template; continuing without runtime file sync`n", logFile)
        }

        editorText := ReadPatchBlock(statMonitorThemeEditorTemplatePath)
        if (editorText != "") {
            if !FileExist(statMonitorThemeEditorPath) || (FileRead(statMonitorThemeEditorPath, "UTF-8") != editorText) {
                try FileDelete(statMonitorThemeEditorPath)
                FileAppend(editorText, statMonitorThemeEditorPath, "UTF-8")
                FileAppend("✓ Synced StatMonitor theme editor file`n", logFile)
            }
        } else {
            FileAppend("! Missing StatMonitor theme editor template; continuing without editor file sync`n", logFile)
        }
    }

    c := FileRead(statMonitorPath, "UTF-8")
    orig := c

    if patchStatMonitorTheme {
        themeInclude := '#Include "%A_ScriptDir%\StatMonitorThemeRuntime.ahk"'
        legacyThemeInclude := '#Include "StatMonitorThemeRuntime.ahk"'
        if InStr(c, legacyThemeInclude) && !InStr(c, themeInclude) {
            c := StrReplace(c, legacyThemeInclude, themeInclude)
            FileAppend("✓ Replaced legacy relative StatMonitor theme runtime include`n", logFile)
        } else if !InStr(c, themeInclude) {
            assetNeedle := '#Include "%A_ScriptDir%\..\nm_image_assets\statmonitor\bitmaps.ahk"'
            assetInsert := assetNeedle '`r`n' themeInclude
            cNew := StrReplace(c, assetNeedle, assetInsert)
            if (cNew != c) {
                c := cNew
                FileAppend("✓ Added StatMonitor theme runtime include`n", logFile)
            }
        }

        if InStr(c, 'pBrush := Gdip_BrushCreateSolid(0xff121212), Gdip_FillRoundedRectangle(G, pBrush, -1, -1, w+1, h+1, 60), Gdip_DeleteBrush(pBrush)') {
            c := StrReplace(c
                , 'pBrush := Gdip_BrushCreateSolid(0xff121212), Gdip_FillRoundedRectangle(G, pBrush, -1, -1, w+1, h+1, 60), Gdip_DeleteBrush(pBrush)'
                , 'StatMonitorTheme_DrawBackground(G, w, h)'
            )
            FileAppend("✓ Replaced StatMonitor base background with theme hook`n", logFile)
        }

        oldRegionBlock := JoinLines(
            'for k,v in regions',
            '{',
            '	pPen := Gdip_CreatePen(0xff282628, 10), Gdip_DrawRoundedRectangle(G, pPen, v[1], v[2], v[3], v[4], 20), Gdip_DeletePen(pPen)',
            '	pBrush := Gdip_BrushCreateSolid(0xff201e20), Gdip_FillRoundedRectangle(G, pBrush, v[1], v[2], v[3], v[4], 20), Gdip_DeleteBrush(pBrush)',
            '}',
            'for k,v in stat_regions',
            '{',
            '	pPen := Gdip_CreatePen(0xff353335, 10), Gdip_DrawRoundedRectangle(G, pPen, v[1], v[2], v[3], v[4], 20), Gdip_DeletePen(pPen)',
            '	pBrush := Gdip_BrushCreateSolid(0xff2c2a2c), Gdip_FillRoundedRectangle(G, pBrush, v[1], v[2], v[3], v[4], 20), Gdip_DeleteBrush(pBrush)',
            '}'
        )
        if InStr(c, oldRegionBlock) {
            c := StrReplace(c, oldRegionBlock, 'StatMonitorTheme_DrawRegionPanels(G, regions, stat_regions)')
            FileAppend("✓ Replaced StatMonitor panel colors with theme hook`n", logFile)
        }

        if InStr(c, 'pBrush := Gdip_BrushCreateSolid(0x80141414)') {
            c := StrReplace(c, 'pBrush := Gdip_BrushCreateSolid(0x80141414)', 'pBrush := StatMonitorTheme_CreateGraphBackgroundBrush()')
            FileAppend("✓ Replaced StatMonitor graph background brush with theme hook`n", logFile)
        }

        overlayNeedle := JoinLines(
            '	}',
            '',
            '	Gdip_DeleteGraphics(G)',
            '',
            '	webhook := IniRead("settings\nm_config.ini", "Status", "webhook")'
        )
        overlayInsert := JoinLines(
            '	}',
            '',
            '	StatMonitorTheme_DrawOverlay(G, w, h, regions, stat_regions)',
            '	Gdip_DeleteGraphics(G)',
            '',
            '	webhook := IniRead("settings\nm_config.ini", "Status", "webhook")'
        )
        if InStr(c, 'StatMonitorTheme_DrawOverlay(G, w, h)') && !InStr(c, 'StatMonitorTheme_DrawOverlay(G, w, h, regions, stat_regions)') {
            c := StrReplace(c, 'StatMonitorTheme_DrawOverlay(G, w, h)', 'StatMonitorTheme_DrawOverlay(G, w, h, regions, stat_regions)')
            FileAppend("✓ Updated StatMonitor overlay hook to localized signature`n", logFile)
        }
        if !InStr(c, 'StatMonitorTheme_DrawOverlay(G, w, h, regions, stat_regions)') {
            cNew := StrReplace(c, overlayNeedle, overlayInsert)
            if (cNew != c) {
                c := cNew
                FileAppend("✓ Added StatMonitor overlay theme hook`n", logFile)
            }
        }

        infoBlockPattern := '(?ms)^\t; section 6: info\r?\n.*?(?=^\tStatMonitorTheme_DrawOverlay\(G, w, h, regions, stat_regions\)|^\tGdip_DeleteGraphics\(G\))'
        newInfoBlock := ReadPatchBlock(statMonitorInfoSectionTemplatePath)
        if (newInfoBlock != "") {
            if !InStr(c, 'StatMonitorTheme_GetInfoImageMode()') {
                cNew := RegExReplace(c, infoBlockPattern, newInfoBlock, &infoBlockCount, 1)
                if (infoBlockCount > 0 && cNew != c) {
                    c := cNew
                    FileAppend("✓ Added StatMonitor info image theme hook`n", logFile)
                }
            }
        } else {
            FileAppend("! Missing StatMonitor info section template; continuing without info image hook`n", logFile)
        }
    }

    if patchForceHourly && !InStr(c, "OnMessage(0x5563, ForceReport") {
        msgNeedle := 'OnMessage(0x5557, SetBackpack, 255)'
        msgInsert := msgNeedle '`r`nOnMessage(0x5563, ForceReport, 255)'
        cNew := StrReplace(c, msgNeedle, msgInsert)
        if (cNew != c) {
            c := cNew
            FileAppend("✓ Added ForceReport message hook to StatMonitor.ahk`n", logFile)
        }
    }

    if patchForceHourly && !InStr(c, 'ForceReport(*)') {
        handlerNeedle := 'OnMessage(0x5563, ForceReport, 255)'
        handlerInsert := handlerNeedle '`r`n`r`nForceReport(*) {`r`n`tSendHourlyReport()`r`n}'
        cNew := StrReplace(c, handlerNeedle, handlerInsert)
        if (cNew != c) {
            c := cNew
            FileAppend("✓ Added ForceReport handler to StatMonitor.ahk`n", logFile)
        }
    }

    if patchForceHourly {
        legacyExtraBitmapBlockPattern := '(?ms)\Rif !buff_bitmaps\.Has\("pBMpinetreefieldboost"\)\R\{.*?\R\}'
        cNew := RegExReplace(c, legacyExtraBitmapBlockPattern, "", &legacyExtraBitmapBlockCount, 1)
        if (legacyExtraBitmapBlockCount > 0 && cNew != c) {
            c := cNew
            FileAppend("✓ Removed legacy inline StatMonitor extra bitmap fallback block`n", logFile)
        }

        extraBitmapInclude := '#Include "%A_ScriptDir%\..\nm_image_assets\statmonitor\extra_bitmaps.ahk"'
        if !InStr(c, extraBitmapInclude) {
            assetNeedle := '#Include "%A_ScriptDir%\..\nm_image_assets\statmonitor\bitmaps.ahk"'
            assetInsert := assetNeedle '`r`n' extraBitmapInclude
            cNew := StrReplace(c, assetNeedle, assetInsert)
            if (cNew != c) {
                c := cNew
                FileAppend("✓ Added separate StatMonitor extra bitmap include`n", logFile)
            }
        }

        if InStr(c, 'w := 6000, h := 5800') && !InStr(c, 'w := 6000, h := 6740') {
            c := StrReplace(c, 'w := 6000, h := 5800', 'w := 6000, h := 6740')
            FileAppend("✓ Expanded StatMonitor canvas for extra boost rows`n", logFile)
        }

        oldBuffList := 'for v in ["haste","melody","redboost","blueboost","whiteboost","focus","bombcombo","balloonaura","clock","jbshare","babylove","inspire","bear","pollenmark","honeymark","festivemark","popstar","comforting","motivating","satisfying","refreshing","invigorating","blessing","bloat","guiding","mondo","reindeerfetch","tideblessing"]'
        newBuffList := 'for v in ["haste","melody","redboost","blueboost","whiteboost","focus","bombcombo","balloonaura","clock","jbshare","babylove","inspire","bear","pollenmark","honeymark","festivemark","popstar","comforting","motivating","satisfying","refreshing","invigorating","blessing","bloat","guiding","mondo","reindeerfetch","tideblessing","beesmascheer","pinetreefieldboost","blueflowerfieldboost","bamboofieldboost","snowflakebuff","cloudbuff"]'
        if InStr(c, oldBuffList) {
            c := StrReplace(c, oldBuffList, newBuffList)
            FileAppend("✓ Added Baspas extra StatMonitor buff slots`n", logFile)
        }
        c := StrReplace(c, ',"festiveblessing","beesmascheer"', ',"beesmascheer"')

    oldStatRegions := JoinLines(
        '	, "stats", [regions["stats"][1]+100,regions["stats"][2]+4220,regions["stats"][3]-200,620]',
        '	, "info", [regions["stats"][1]+100,regions["stats"][2]+4940,regions["stats"][3]-200,regions["stats"][4]-4940-100])'
    )
    newStatRegions := JoinLines(
        '	, "stats", [regions["stats"][1]+100,regions["stats"][2]+4220,regions["stats"][3]-200,875]',
        '	, "info", [regions["stats"][1]+100,regions["stats"][2]+5200,regions["stats"][3]-200,regions["stats"][4]-5200-100])'
    )
    if InStr(c, oldStatRegions) {
        c := StrReplace(c, oldStatRegions, newStatRegions)
        FileAppend("✓ Resized StatMonitor stats/info panels for extra rows`n", logFile)
    }

    graphNeedle := JoinLines(
        '	, "guiding", [regions["buffs"][1]+320,regions["buffs"][2]+3305,3600,110]',
        '	, "honey", [stat_regions["lasthour"][1]+200,stat_regions["lasthour"][2]+650,1080,480]'
    )
    graphInsert := JoinLines(
        '	, "guiding", [regions["buffs"][1]+320,regions["buffs"][2]+3305,3600,110]',
        '	, "beesmascheer", [regions["buffs"][1]+320,regions["buffs"][2]+3435,3600,110]',
        '	, "pinetreefieldboost", [regions["buffs"][1]+320,regions["buffs"][2]+3565,3600,110]',
        '	, "bamboofieldboost", [regions["buffs"][1]+320,regions["buffs"][2]+3695,3600,110]',
        '	, "blueflowerfieldboost", [regions["buffs"][1]+320,regions["buffs"][2]+3825,3600,110]',
        '	, "snowflakebuff", [regions["buffs"][1]+320,regions["buffs"][2]+3955,3600,110]',
        '	, "cloudbuff", [regions["buffs"][1]+320,regions["buffs"][2]+4085,3600,110]',
        '	, "honey", [stat_regions["lasthour"][1]+200,stat_regions["lasthour"][2]+650,1080,480]'
    )
    if InStr(c, graphNeedle) && !InStr(c, '	, "cloudbuff", [regions["buffs"][1]+320,regions["buffs"][2]+4085,3600,110]') {
        c := StrReplace(c, graphNeedle, graphInsert)
        FileAppend("✓ Added extra StatMonitor boost graph rows`n", logFile)
    }
    c := StrReplace(c, '	, "festiveblessing", [regions["buffs"][1]+320,regions["buffs"][2]+3435,3600,110]`r`n', '')
    c := StrReplace(c, '	, "beesmascheer", [regions["buffs"][1]+320,regions["buffs"][2]+3565,3600,110]', '	, "beesmascheer", [regions["buffs"][1]+320,regions["buffs"][2]+3435,3600,110]')
    c := StrReplace(c, '	, "pinetreefieldboost", [regions["buffs"][1]+320,regions["buffs"][2]+3695,3600,110]', '	, "pinetreefieldboost", [regions["buffs"][1]+320,regions["buffs"][2]+3565,3600,110]')
    c := StrReplace(c, '	, "bamboofieldboost", [regions["buffs"][1]+320,regions["buffs"][2]+3825,3600,110]', '	, "bamboofieldboost", [regions["buffs"][1]+320,regions["buffs"][2]+3695,3600,110]')
    c := StrReplace(c, '	, "blueflowerfieldboost", [regions["buffs"][1]+320,regions["buffs"][2]+3955,3600,110]', '	, "blueflowerfieldboost", [regions["buffs"][1]+320,regions["buffs"][2]+3825,3600,110]')
    c := StrReplace(c, '	, "snowflakebuff", [regions["buffs"][1]+320,regions["buffs"][2]+4085,3600,110]', '	, "snowflakebuff", [regions["buffs"][1]+320,regions["buffs"][2]+3955,3600,110]')
    c := StrReplace(c, '	, "cloudbuff", [regions["buffs"][1]+320,regions["buffs"][2]+4215,3600,110]', '	, "cloudbuff", [regions["buffs"][1]+320,regions["buffs"][2]+4085,3600,110]')

    oldBasicLoop := '	for v in ["jbshare","babylove","festivemark","guiding"]'
    newBasicLoop := '	for v in ["jbshare","babylove","festivemark","guiding","pinetreefieldboost","bamboofieldboost","blueflowerfieldboost","snowflakebuff","cloudbuff","beesmascheer"]'
    oldBasicAssign := '		buff_values[v][i] := (Gdip_ImageSearch(pBMArea, buff_bitmaps["pBM" v], , , 30, , , InStr(v, "mark") ? 6 : (v = "guiding") ? 10 : 0, , 7) = 1)'
    newBasicAssign := '		buff_values[v][i] := (Gdip_ImageSearch(pBMArea, buff_bitmaps["pBM" v], , , 30, , , InStr(v, "mark") ? 6 : (v = "guiding" || v = "pinetreefieldboost" || v = "bamboofieldboost" || v = "blueflowerfieldboost" || v = "beesmascheer") ? 10 : 0, , 7) = 1)'
    if InStr(c, oldBasicLoop) || InStr(c, oldBasicAssign) {
        c := StrReplace(c, oldBasicLoop, newBasicLoop)
        c := StrReplace(c, oldBasicAssign, newBasicAssign)
        FileAppend("✓ Added extra StatMonitor boost detections`n", logFile)
    }
    c := StrReplace(c, ',"snowflakebuff","cloudbuff","festiveblessing","beesmascheer"', ',"snowflakebuff","cloudbuff","beesmascheer"')
    c := StrReplace(c, '|| v = "blueflowerfieldboost" || v = "festiveblessing" || v = "beesmascheer"', '|| v = "blueflowerfieldboost" || v = "beesmascheer"')

    specialBasicNeedle := ""
    specialBasicNeedle .= '`t; basic on/off`r`n'
    specialBasicNeedle .= '`tfor v in ["jbshare","babylove","festivemark","guiding","pinetreefieldboost","bamboofieldboost","blueflowerfieldboost","beesmascheer"]`r`n'
    specialBasicNeedle .= '`t`tbuff_values[v][i] := (Gdip_ImageSearch(pBMArea, buff_bitmaps["pBM" v], , , 30, , , (v ~= "babylove" || v ~= "jbshare") ? 0 : 10, , 7) = 1)`r`n`r`n'
    specialBasicNeedle .= '`t; bear morphs'

    specialBasicInsert := ""
    specialBasicInsert .= '`t; basic on/off`r`n'
    specialBasicInsert .= '`tfor v in ["jbshare","babylove","festivemark","guiding","pinetreefieldboost","bamboofieldboost","blueflowerfieldboost","snowflakebuff","cloudbuff","beesmascheer"]`r`n'
    specialBasicInsert .= '`t`tbuff_values[v][i] := (Gdip_ImageSearch(pBMArea, buff_bitmaps["pBM" v], , , 30, , , InStr(v, "mark") ? 6 : (v = "guiding" || v = "pinetreefieldboost" || v = "bamboofieldboost" || v = "blueflowerfieldboost" || v = "beesmascheer") ? 10 : 0, , 7) = 1)`r`n`r`n'
    specialBasicInsert .= '`t; bear morphs'
    if InStr(c, specialBasicNeedle) && !InStr(c, 'for v in ["jbshare","babylove","festivemark","guiding","pinetreefieldboost","bamboofieldboost","blueflowerfieldboost","snowflakebuff","cloudbuff","beesmascheer"]') {
        c := StrReplace(c, specialBasicNeedle, specialBasicInsert)
        FileAppend("✓ Switched snowflake to strip detection`n", logFile)
    }
    c := StrReplace(c, ',"snowflakebuff","cloudbuff","festiveblessing","beesmascheer"', ',"snowflakebuff","cloudbuff","beesmascheer"')
    c := StrReplace(c, ',"blueflowerfieldboost","festiveblessing","beesmascheer"]', ',"blueflowerfieldboost","beesmascheer"]')

    oldBuffIconBlock := JoinLines(
        '	if bitmaps.Has("pBM" k)',
        '	{',
        '		Gdip_DrawImage(G, bitmaps["pBM" k], regions["buffs"][1]+75, v[2]+v[4]//2-55, 110, 110)',
        '		Gdip_DrawLine(G, pPen, v[1]-60, v[2]+v[4]+10, v[1]+v[3]+60, v[2]+v[4]+10)',
        '	}'
    )
    newBuffIconBlock := JoinLines(
        '	if bitmaps.Has("pBM" k)',
        '	{',
        '		if (k = "cloudbuff")',
        '			pCloudBrush := Gdip_BrushCreateSolid(0xff9fb1c5), Gdip_FillRectangle(G, pCloudBrush, regions["buffs"][1]+75, v[2]+v[4]//2-55, 110, 110), Gdip_DeleteBrush(pCloudBrush)',
        '		Gdip_DrawImage(G, bitmaps["pBM" k], regions["buffs"][1]+75, v[2]+v[4]//2-55, 110, 110)',
        '	}',
        '	else',
        '	{',
        '		label := (k = "pinetreefieldboost") ? "Pine"',
        '			: (k = "bamboofieldboost") ? "Bamboo"',
        '			: (k = "blueflowerfieldboost") ? "Blue"',
        '			: (k = "snowflakebuff") ? "Snow"',
        '			: (k = "cloudbuff") ? "Cloud"',
        '			: (k = "beesmascheer") ? "Cheer"',
        '			: ""',
        '		(label != "") && Gdip_TextToGraphics(G, label, "s26 Center Bold cffffffff x" regions["buffs"][1]+28 " y" v[2]+v[4]//2-18 " w205", "Segoe UI")',
        '	}',
        '	Gdip_DrawLine(G, pPen, v[1]-60, v[2]+v[4]+10, v[1]+v[3]+60, v[2]+v[4]+10)'
    )
    if InStr(c, oldBuffIconBlock) {
        c := StrReplace(c, oldBuffIconBlock, newBuffIconBlock)
        FileAppend("✓ Added StatMonitor text fallback for missing boost icons`n", logFile)
    }
    c := StrReplace(c, '`t`t`t: (k = "festiveblessing") ? "Fest"`r`n', '')

    disposedBitmapDraw := 'Gdip_DrawImage(G, bitmaps["pBM" k], regions["buffs"][1]+75, v[2]+v[4]//2-55, 110, 110), Gdip_DisposeImage(bitmaps["pBM" k])'
    keptBitmapDraw := 'Gdip_DrawImage(G, bitmaps["pBM" k], regions["buffs"][1]+75, v[2]+v[4]//2-55, 110, 110)'
    if InStr(c, disposedBitmapDraw) {
        c := StrReplace(c, disposedBitmapDraw, keptBitmapDraw)
        FileAppend("✓ Preserved shared StatMonitor graph bitmap handles`n", logFile)
    }

    disposedStaticBitmapDraw := 'Gdip_DrawImage(G, bitmaps["pBM" v], stat_regions["buffs"][1]+48+(A_Index-1)*(stat_regions["buffs"][3]-96-220)/4, stat_regions["buffs"][2]+124, 220, 220), Gdip_DisposeImage(bitmaps["pBM" v])'
    keptStaticBitmapDraw := 'Gdip_DrawImage(G, bitmaps["pBM" v], stat_regions["buffs"][1]+48+(A_Index-1)*(stat_regions["buffs"][3]-96-220)/4, stat_regions["buffs"][2]+124, 220, 220)'
    if InStr(c, disposedStaticBitmapDraw) {
        c := StrReplace(c, disposedStaticBitmapDraw, keptStaticBitmapDraw)
        FileAppend("✓ Preserved shared StatMonitor static bitmap handles`n", logFile)
    }

    oldBuffCase := JoinLines(
        '			case "festivemark","popstar","melody","bear","babylove","jbshare","guiding":',
        '			color := (k = "festivemark") ? 0xffc84335',
        '				: (k = "popstar") ? 0xff0096ff',
        '				: (k = "melody") ? 0xfff0f0f0',
        '				: (k = "bear") ? 0xffb26f3e',
        '				: (k = "babylove") ? 0xff8de4f3',
        '				: (k = "jbshare") ? 0xfff9ccff',
        '				: 0xffffef8e'
    )
    newBuffCase := JoinLines(
        '			case "festivemark","popstar","melody","bear","babylove","jbshare","guiding","beesmascheer","pinetreefieldboost","bamboofieldboost","blueflowerfieldboost","snowflakebuff","cloudbuff":',
        '			color := (k = "festivemark") ? 0xffc84335',
        '				: (k = "popstar") ? 0xff0096ff',
        '				: (k = "melody") ? 0xfff0f0f0',
        '				: (k = "bear") ? 0xffb26f3e',
        '				: (k = "babylove") ? 0xff8de4f3',
        '				: (k = "jbshare") ? 0xfff9ccff',
        '				: (k = "guiding") ? 0xffffef8e',
        '				: (k = "beesmascheer") ? 0xff00ff00',
        '				: (k = "pinetreefieldboost") ? 0xff00e027',
        '				: (k = "bamboofieldboost") ? 0xff00e027',
        '				: (k = "blueflowerfieldboost") ? 0xff00e027',
        '				: (k = "cloudbuff") ? 0xffd8e1ea',
        '				: 0xfffcfcfc'
    )
    if InStr(c, oldBuffCase) {
        c := StrReplace(c, oldBuffCase, newBuffCase)
        FileAppend("✓ Added extra StatMonitor boost row colors`n", logFile)
    }
    c := StrReplace(c, '"guiding","festiveblessing","beesmascheer"', '"guiding","beesmascheer"')
    c := StrReplace(c, '`t`t`t`t: (k = "festiveblessing") ? 0xff00ff00`r`n', '')

    oldIncrementStat := 'IncrementStat(wParam, lParam, *){`r`n`tstats[wParam][2] += lParam`r`n`treturn 0`r`n}'
    newIncrementStat := 'IncrementStat(wParam, lParam, *){`r`n`tif !IsInteger(wParam)`r`n`t`treturn 0`r`n`tif (wParam < 1 || wParam > stats.Length)`r`n`t`treturn 0`r`n`tif !IsObject(stats[wParam]) || (stats[wParam].Length < 2)`r`n`t`treturn 0`r`n`tstats[wParam][2] += lParam`r`n`treturn 0`r`n}'
    if InStr(c, oldIncrementStat) {
        c := StrReplace(c, oldIncrementStat, newIncrementStat)
        FileAppend("✓ Hardened IncrementStat in StatMonitor.ahk`n", logFile)
    }

    oldMinMax := JoinLines(
        'minX(List)',
        '{',
        '`tif !IsObject(List)',
        '`t`treturn IsNumber(List) ? List : 0',
        '`tX := ""',
        '`ttry',
        '`t{',
        '`t`tfor element in List',
        '`t`t{',
        '`t`t`tif !IsNumber(element)',
        '`t`t`t`tcontinue',
        '`t`t`tif (X = "" || element < X)',
        '`t`t`t`tX := element',
        '`t`t}',
        '`t}',
        '`tcatch',
        '`t{',
        '`t`treturn 0',
        '`t}',
        '`treturn (X = "") ? 0 : X',
        '}',
        'maxX(List)',
        '{',
        '`tif !IsObject(List)',
        '`t`treturn IsNumber(List) ? List : 0',
        '`tX := ""',
        '`ttry',
        '`t{',
        '`t`tfor element in List',
        '`t`t{',
        '`t`t`tif !IsNumber(element)',
        '`t`t`t`tcontinue',
        '`t`t`tif (X = "" || element > X)',
        '`t`t`t`tX := element',
        '`t`t}',
        '`t}',
        '`tcatch',
        '`t{',
        '`t`treturn 0',
        '`t}',
        '`treturn (X = "") ? 0 : X',
        '}'
    )
    newMinMax := JoinLines(
        'minX(List)',
        '{',
        '`tList.__Enum().Call(, &X)',
        '`tfor key, element in List',
        '`t`tif (IsNumber(element) && (element < X))',
        '`t`t`tX := element',
        '`treturn X',
        '}',
        'maxX(List)',
        '{',
        '`tList.__Enum().Call(, &X)',
        '`tfor key, element in List',
        '`t`tif (IsNumber(element) && (element > X))',
        '`t`t`tX := element',
        '`treturn X',
        '}'
    )
    if InStr(c, oldMinMax) {
        c := StrReplace(c, oldMinMax, newMinMax)
        FileAppend("✓ Restored StatMonitor minX/maxX map handling`n", logFile)
    }

    oldHoneyGraph := '			points := []`r`n			honey_12h.__Enum().Call(&x), points.Push([4+v[3]*x/180, 4+v[4]])`r`n			for x,y in honey_12h`r`n				(y != "") && points.Push([4+v[3]*(max_x := x)/180, 4+v[4]-((y-min_12h)/range_12h)*v[4]])`r`n			points.Push([4+v[3]*max_x/180, 4+v[4]])`r`n			color := 0xff0e8bf0`r`n`r`n			pBrush := Gdip_BrushCreateSolid(color - 0x80000000)`r`n			Gdip_FillPolygon(G_Graph, pBrush, points)`r`n			Gdip_DeleteBrush(pBrush)`r`n`r`n			points.RemoveAt(1), points.Pop()`r`n			pPen := Gdip_CreatePen(color, 6)`r`n			Gdip_DrawLines(G_Graph, pPen, points)`r`n			Gdip_DeletePen(pPen)'
    newHoneyGraph := '			points := []`r`n			if (honey_12h.Count > 0)`r`n			{`r`n				enum := honey_12h.__Enum(1)`r`n				enum.Call(&x)`r`n				points.Push([4+v[3]*x/180, 4+v[4]])`r`n				for x,y in honey_12h`r`n					(y != "") && points.Push([4+v[3]*(max_x := x)/180, 4+v[4]-((y-min_12h)/range_12h)*v[4]])`r`n				points.Push([4+v[3]*max_x/180, 4+v[4]])`r`n			}`r`n			color := 0xff0e8bf0`r`n`r`n			if (points.Length > 2)`r`n			{`r`n				pBrush := Gdip_BrushCreateSolid(color - 0x80000000)`r`n				Gdip_FillPolygon(G_Graph, pBrush, points)`r`n				Gdip_DeleteBrush(pBrush)`r`n`r`n				points.RemoveAt(1), points.Pop()`r`n				pPen := Gdip_CreatePen(color, 6)`r`n				Gdip_DrawLines(G_Graph, pPen, points)`r`n				Gdip_DeletePen(pPen)`r`n			}'
    if InStr(c, oldHoneyGraph) {
        c := StrReplace(c, oldHoneyGraph, newHoneyGraph)
        FileAppend("✓ Hardened honey12h graph path in StatMonitor.ahk`n", logFile)
    }

    oldBackpackGraph := '			points := []`r`n			backpack_values.__Enum().Call(&x), points.Push([4+x*v[3]/3600, 4+v[4]])`r`n			for x,y in backpack_values`r`n				(y != "") && points.Push([4+(max_x := x)*v[3]/3600, 4+v[4]-(y/100)*v[4]])`r`n			points.Push([4+max_x*v[3]/3600, 4+v[4]])`r`n`r`n			pBrush := Gdip_CreateLinearGrBrushFromRect(4, 4, v[3], v[4], 0x00000000, 0x00000000)`r`n			Gdip_SetLinearGrBrushPresetBlend(pBrush, [0.0, 0.2, 0.8], [0xffff0000, 0xffff8000, 0xff41ff80])`r`n			pPen := Gdip_CreatePenFromBrush(pBrush, 6)`r`n			Gdip_SetLinearGrBrushPresetBlend(pBrush, [0.0, 0.2, 0.8], [0x80ff0000, 0x80ff8000, 0x8041ff80])`r`n			Gdip_FillPolygon(G_Graph, pBrush, points)`r`n			points.RemoveAt(1), points.Pop()`r`n			Gdip_DrawLines(G_Graph, pPen, points)`r`n			Gdip_DeletePen(pPen), Gdip_DeleteBrush(pBrush)'
    newBackpackGraph := '			points := []`r`n			if (backpack_values.Count > 0)`r`n			{`r`n				enum := backpack_values.__Enum(1)`r`n				enum.Call(&x)`r`n				points.Push([4+x*v[3]/3600, 4+v[4]])`r`n				for x,y in backpack_values`r`n					(y != "") && points.Push([4+(max_x := x)*v[3]/3600, 4+v[4]-(y/100)*v[4]])`r`n				points.Push([4+max_x*v[3]/3600, 4+v[4]])`r`n			}`r`n`r`n			if (points.Length > 2)`r`n			{`r`n				pBrush := Gdip_CreateLinearGrBrushFromRect(4, 4, v[3], v[4], 0x00000000, 0x00000000)`r`n				Gdip_SetLinearGrBrushPresetBlend(pBrush, [0.0, 0.2, 0.8], [0xffff0000, 0xffff8000, 0xff41ff80])`r`n				pPen := Gdip_CreatePenFromBrush(pBrush, 6)`r`n				Gdip_SetLinearGrBrushPresetBlend(pBrush, [0.0, 0.2, 0.8], [0x80ff0000, 0x80ff8000, 0x8041ff80])`r`n				Gdip_FillPolygon(G_Graph, pBrush, points)`r`n				points.RemoveAt(1), points.Pop()`r`n				Gdip_DrawLines(G_Graph, pPen, points)`r`n				Gdip_DeletePen(pPen), Gdip_DeleteBrush(pBrush)`r`n			}'
    if InStr(c, oldBackpackGraph) {
        c := StrReplace(c, oldBackpackGraph, newBackpackGraph)
        FileAppend("✓ Hardened backpack graph path in StatMonitor.ahk`n", logFile)
    }

    oldBoostGraph := '				points := []`r`n`r`n				buff_values[i].__Enum().Call(&x), points.Push([4+v[3]*x/600, 4+v[4]])`r`n				for x,y in buff_values[i]`r`n					points.Push([4+v[3]*(max_x := x)/600, 4+v[4]-((y <= 10) ? (y/10)*(v[4]) : 10)])`r`n				points.Push([4+v[3]*max_x/600, 4+v[4]])'
    newBoostGraph := '				points := []`r`n				if (buff_values[i].Count > 0)`r`n				{`r`n					enum := buff_values[i].__Enum(1)`r`n					enum.Call(&x)`r`n					points.Push([4+v[3]*x/600, 4+v[4]])`r`n					for x,y in buff_values[i]`r`n						points.Push([4+v[3]*(max_x := x)/600, 4+v[4]-((y <= 10) ? (y/10)*(v[4]) : 10)])`r`n					points.Push([4+v[3]*max_x/600, 4+v[4]])`r`n				}'
    if InStr(c, oldBoostGraph) {
        c := StrReplace(c, oldBoostGraph, newBoostGraph)
        FileAppend("✓ Hardened boost graph path in StatMonitor.ahk`n", logFile)
    }

    oldDefaultBuffGraph := '			points := []`r`n`r`n			buff_values[k].__Enum().Call(&x), points.Push([4+v[3]*x/600, 4+v[4]])`r`n			for x,y in buff_values[k]`r`n				points.Push([4+v[3]*(max_x := x)/600, 4+v[4]-(y/max_buff)*(v[4])])`r`n			points.Push([4+v[3]*max_x/600, 4+v[4]])'
    newDefaultBuffGraph := '			points := []`r`n			if (buff_values[k].Count > 0)`r`n			{`r`n				enum := buff_values[k].__Enum(1)`r`n				enum.Call(&x)`r`n				points.Push([4+v[3]*x/600, 4+v[4]])`r`n				for x,y in buff_values[k]`r`n					points.Push([4+v[3]*(max_x := x)/600, 4+v[4]-(y/max_buff)*(v[4])])`r`n				points.Push([4+v[3]*max_x/600, 4+v[4]])`r`n			}'
    if InStr(c, oldDefaultBuffGraph) {
        c := StrReplace(c, oldDefaultBuffGraph, newDefaultBuffGraph)
        FileAppend("✓ Hardened buff graph path in StatMonitor.ahk`n", logFile)
    }

    if InStr(c, 'DllCall("shlwapi\IStream_Size", "Ptr", pFileStream, "UInt64P", &size:=0, "UInt")') && !InStr(c, 'pngSize := size') {
        c := StrReplace(c, 'DllCall("shlwapi\IStream_Size", "Ptr", pFileStream, "UInt64P", &size:=0, "UInt")', 'DllCall("shlwapi\IStream_Size", "Ptr", pFileStream, "UInt64P", &size:=0, "UInt")`r`n`t`tpngSize := size')
        FileAppend("✓ Added StatMonitor PNG size capture for hourly uploads`n", logFile)
    }

    attachmentPrepAnchor := JoinLines(
        '		hData := DllCall("GlobalAlloc", "UInt", 0x2, "UPtr", 0, "Ptr")',
        '		DllCall("ole32\CreateStreamOnHGlobal", "Ptr", hData, "Int", 0, "PtrP", &pStream:=0, "UInt")',
        '',
        '		str :='
    )
    attachmentPrepBlock := JoinLines(
        '		hData := DllCall("GlobalAlloc", "UInt", 0x2, "UPtr", 0, "Ptr")',
        '		DllCall("ole32\CreateStreamOnHGlobal", "Ptr", hData, "Int", 0, "PtrP", &pStream:=0, "UInt")',
        '',
        '		attachmentName := "", attachmentContentType := "", attachmentSize := 0',
        '		pFileStream := StatMonitor_CreateHourlyAttachmentStream(pBMReport, &attachmentName, &attachmentContentType, &attachmentSize, &pngSize)',
        '',
        '		str :='
    )
    if InStr(c, attachmentPrepAnchor) && !InStr(c, attachmentPrepBlock) {
        c := StrReplace(c, attachmentPrepAnchor, attachmentPrepBlock)
        FileAppend("✓ Moved StatMonitor attachment selection before multipart header build`n", logFile)
    }

    oldAttachmentStreamBlock := JoinLines(
        '		pFileStream := Gdip_SaveBitmapToStream(pBMReport)',
        '		DllCall("shlwapi\IStream_Size", "Ptr", pFileStream, "UInt64P", &size:=0, "UInt")',
        '		pngSize := size',
        '		DllCall("shlwapi\IStream_Reset", "Ptr", pFileStream, "UInt")',
        '		DllCall("shlwapi\IStream_Copy", "Ptr", pFileStream, "Ptr", pStream, "UInt", size, "UInt")'
    )
    oldAttachmentStreamBlockNoPng := JoinLines(
        '		pFileStream := Gdip_SaveBitmapToStream(pBMReport)',
        '		DllCall("shlwapi\IStream_Size", "Ptr", pFileStream, "UInt64P", &size:=0, "UInt")',
        '		DllCall("shlwapi\IStream_Reset", "Ptr", pFileStream, "UInt")',
        '		DllCall("shlwapi\IStream_Copy", "Ptr", pFileStream, "Ptr", pStream, "UInt", size, "UInt")'
    )
    brokenAttachmentStreamBlock := JoinLines(
        '		attachmentName := "", attachmentContentType := ""',
        '		pFileStream := StatMonitor_CreateHourlyAttachmentStream(pBMReport, &attachmentName, &attachmentContentType, &attachmentSize, &pngSize)',
        '		DllCall("shlwapi\IStream_Reset", "Ptr", pFileStream, "UInt")',
        '		DllCall("shlwapi\IStream_Copy", "Ptr", pFileStream, "Ptr", pStream, "UInt", attachmentSize, "UInt")'
    )
    newAttachmentStreamBlock := JoinLines(
        '		DllCall("shlwapi\IStream_Reset", "Ptr", pFileStream, "UInt")',
        '		DllCall("shlwapi\IStream_Copy", "Ptr", pFileStream, "Ptr", pStream, "UInt", attachmentSize, "UInt")'
    )
    if InStr(c, oldAttachmentStreamBlock) || InStr(c, oldAttachmentStreamBlockNoPng) || InStr(c, brokenAttachmentStreamBlock) {
        cNew := StrReplace(c, oldAttachmentStreamBlock, newAttachmentStreamBlock)
        cNew := StrReplace(cNew, oldAttachmentStreamBlockNoPng, newAttachmentStreamBlock)
        cNew := StrReplace(cNew, brokenAttachmentStreamBlock, newAttachmentStreamBlock)
        c := cNew
        FileAppend("✓ Added StatMonitor automatic PNG/JPG attachment fallback`n", logFile)
    }

    oldAttachmentUrl := '"image": {"url": "attachment://file.png"}'
    newAttachmentUrl := Chr(34) "image" Chr(34) ": {" Chr(34) "url" Chr(34) ": " Chr(34) "attachment://" Chr(39) " attachmentName " Chr(39) Chr(34) "}"
    brokenAttachmentUrl := Chr(34) "image" Chr(34) ": {" Chr(34) "url" Chr(34) ": " Chr(34) "attachment://" Chr(39) Chr(39) " attachmentName " Chr(39) Chr(39) Chr(34) "}"
    if InStr(c, oldAttachmentUrl) || InStr(c, brokenAttachmentUrl) {
        cNew := StrReplace(c, oldAttachmentUrl, newAttachmentUrl)
        cNew := StrReplace(cNew, brokenAttachmentUrl, newAttachmentUrl)
        c := cNew
        FileAppend("✓ Made StatMonitor attachment URL dynamic`n", logFile)
    }
    oldAttachmentFilename := 'Content-Disposition: form-data; name="files[0]"; filename="file.png"'
    newAttachmentFilename := "Content-Disposition: form-data; name=" Chr(34) "files[0]" Chr(34) "; filename=" Chr(34) Chr(39) " attachmentName " Chr(39) Chr(34)
    brokenAttachmentFilename := "Content-Disposition: form-data; name=" Chr(34) "files[0]" Chr(34) "; filename=" Chr(34) Chr(39) Chr(39) " attachmentName " Chr(39) Chr(39) Chr(34)
    if InStr(c, oldAttachmentFilename) || InStr(c, brokenAttachmentFilename) {
        cNew := StrReplace(c, oldAttachmentFilename, newAttachmentFilename)
        cNew := StrReplace(cNew, brokenAttachmentFilename, newAttachmentFilename)
        c := cNew
        FileAppend("✓ Made StatMonitor attachment filename dynamic`n", logFile)
    }
    oldAttachmentContentType := 'Content-Type: image/png'
    newAttachmentContentType := "Content-Type: " Chr(39) " attachmentContentType " Chr(39)
    brokenAttachmentContentType := "Content-Type: " Chr(39) Chr(39) " attachmentContentType " Chr(39) Chr(39)
    if ((InStr(c, oldAttachmentContentType) || InStr(c, brokenAttachmentContentType)) && (InStr(c, oldAttachmentFilename) || InStr(c, newAttachmentFilename) || InStr(c, brokenAttachmentFilename))) {
        cNew := StrReplace(c, oldAttachmentContentType, newAttachmentContentType)
        cNew := StrReplace(cNew, brokenAttachmentContentType, newAttachmentContentType)
        c := cNew
        FileAppend("✓ Made StatMonitor attachment content type dynamic`n", logFile)
    }

    oldDiagLine := '			try FileAppend("[" A_Now "] Hourly upload failed | status=" status " | pngBytes=" pngSize " | multipartBytes=" size " | response=" responseText . Chr(10), A_ScriptDir "\tadsync_debug.txt", "UTF-8")'
    newDiagLine := '			try FileAppend("[" A_Now "] Hourly upload failed | status=" status " | attachment=" attachmentName " | attachmentBytes=" attachmentSize " | pngBytes=" pngSize " | multipartBytes=" size " | response=" responseText . Chr(10), A_ScriptDir "\tadsync_debug.txt", "UTF-8")'
    if InStr(c, oldDiagLine) {
        c := StrReplace(c, oldDiagLine, newDiagLine)
        FileAppend("✓ Expanded StatMonitor upload diagnostics with attachment details`n", logFile)
    }

    helperText := JoinLines(
        'StatMonitor_CreateHourlyAttachmentStream(pBitmap, &attachmentName, &attachmentContentType, &attachmentSize, &pngSize) {',
        '	static sizeLimit := 7900000',
        '',
        '	attachmentName := "file.png"',
        '	attachmentContentType := "image/png"',
        '	pFileStream := Gdip_SaveBitmapToStream(pBitmap, "PNG")',
        '	DllCall("shlwapi\IStream_Size", "Ptr", pFileStream, "UInt64P", &pngSize:=0, "UInt")',
        '	attachmentSize := pngSize',
        '	if (pngSize <= sizeLimit)',
        '		return pFileStream',
        '',
        '	ObjRelease(pFileStream)',
        '	attachmentName := "file.jpg"',
        '	attachmentContentType := "image/jpeg"',
        '	for quality in [85, 75, 65, 55, 45, 35]',
        '	{',
        '		pFileStream := Gdip_SaveBitmapToStream(pBitmap, "JPG", quality)',
        '		DllCall("shlwapi\IStream_Size", "Ptr", pFileStream, "UInt64P", &attachmentSize:=0, "UInt")',
        '		if (attachmentSize <= sizeLimit)',
        '			return pFileStream',
        '		ObjRelease(pFileStream)',
        '	}',
        '',
        '	pFileStream := Gdip_SaveBitmapToStream(pBitmap, "JPG", 25)',
        '	DllCall("shlwapi\IStream_Size", "Ptr", pFileStream, "UInt64P", &attachmentSize:=0, "UInt")',
        '	return pFileStream',
        '}'
    )
    helperSignature := 'StatMonitor_CreateHourlyAttachmentStream(pBitmap, &attachmentName, &attachmentContentType, &attachmentSize, &pngSize) {'
    if !InStr(c, helperSignature) && InStr(c, 'FormatNumber(n)') {
        c := StrReplace(c, 'FormatNumber(n)', helperText '`r`n`r`nFormatNumber(n)')
        FileAppend("✓ Added StatMonitor attachment compression helper`n", logFile)
    }

    oldHourlySend := JoinLines(
        '		wr.SetRequestHeader("Content-Type", contentType)',
        '		wr.SetTimeouts(0, 60000, 120000, 30000)',
        '		wr.Send(retData)'
    )
    newHourlySend := JoinLines(
        '		wr.SetRequestHeader("Content-Type", contentType)',
        '		wr.SetTimeouts(0, 60000, 120000, 30000)',
        '		wr.Send(retData)',
        '		status := wr.Status',
        '		if (status != 200 && status != 204)',
        '		{',
        '			responseText := ""',
        '			try responseText := wr.ResponseText',
        '			responseText := StrReplace(StrReplace(responseText, Chr(34), Chr(39)), Chr(13) Chr(10), " ")',
        '			responseText := StrReplace(responseText, Chr(10), " ")',
        '			if (StrLen(responseText) > 700)',
        '				responseText := SubStr(responseText, 1, 700) "..."',
        '',
        '			try FileAppend("[" A_Now "] Hourly upload failed | status=" status " | pngBytes=" pngSize " | multipartBytes=" size " | response=" responseText . Chr(10), A_ScriptDir "\tadsync_debug.txt", "UTF-8")',
        '		}'
    )
    if InStr(c, oldHourlySend) && !InStr(c, 'Hourly upload failed | status=') {
        c := StrReplace(c, oldHourlySend, newHourlySend)
        FileAppend("✓ Added StatMonitor hourly HTTP status diagnostics`n", logFile)
    }
    }

    if (c != orig) {
        try {
            FileDelete(statMonitorPath)
            FileAppend(c, statMonitorPath, "UTF-8")
            msg .= "âœ“ StatMonitor.ahk patched`n"
        } catch {
            msg .= "âš  FAILED to write StatMonitor.ahk`n"
        }
    }

}

; 2c. PATCH NM_CONFIG.INI
if FileExist(configPath) {
    c := FileRead(configPath, "UTF-8")
    orig := c

    if patchBfb {
        c := EnsureIniKey(c, "Boost", "BlueBoosterInterruptCheck", 1, &cfgChanged)
        c := EnsureIniKey(c, "Boost", "LastBlueBoostUse", 1, &cfgChanged)
    }
    if patchStickerStack {
        c := EnsureIniKey(c, "Boost", "StickerStackInterruptCheck", 1, &cfgChanged)
        c := EnsureIniKey(c, "Boost", "LastStickerStackUse", 1, &cfgChanged)
    }
    if patchTadSyncCore {
        c := EnsureIniKey(c, "Extensions", "PreGlitterCheck", 0, &cfgChanged)
    }
    if patchStatMonitorTheme {
        c := EnsureIniSectionKey(c, "StatMonitorTheme", "BackgroundMode", "Default", &cfgChanged)
        c := EnsureIniSectionKey(c, "StatMonitorTheme", "BackgroundFlat", "FF121212", &cfgChanged)
        c := EnsureIniSectionKey(c, "StatMonitorTheme", "BackgroundGradientTop", "FF121212", &cfgChanged)
        c := EnsureIniSectionKey(c, "StatMonitorTheme", "BackgroundGradientBottom", "FF1C1A1C", &cfgChanged)
        c := EnsureIniSectionKey(c, "StatMonitorTheme", "RegionBorder", "FF282628", &cfgChanged)
        c := EnsureIniSectionKey(c, "StatMonitorTheme", "RegionFill", "FF201E20", &cfgChanged)
        c := EnsureIniSectionKey(c, "StatMonitorTheme", "StatRegionBorder", "FF353335", &cfgChanged)
        c := EnsureIniSectionKey(c, "StatMonitorTheme", "StatRegionFill", "FF2C2A2C", &cfgChanged)
        c := EnsureIniSectionKey(c, "StatMonitorTheme", "GraphFill", "80141414", &cfgChanged)
        c := EnsureIniSectionKey(c, "StatMonitorTheme", "ImagePath", "", &cfgChanged)
        c := EnsureIniSectionKey(c, "StatMonitorTheme", "ImageLayer", "Background", &cfgChanged)
        c := EnsureIniSectionKey(c, "StatMonitorTheme", "ImageOpacity", 55, &cfgChanged)
        c := EnsureIniSectionKey(c, "StatMonitorTheme", "ImageFit", "Contain", &cfgChanged)
        c := EnsureIniSectionKey(c, "StatMonitorTheme", "ImageScale", 100, &cfgChanged)
        c := EnsureIniSectionKey(c, "StatMonitorTheme", "ImageOffsetX", 0, &cfgChanged)
        c := EnsureIniSectionKey(c, "StatMonitorTheme", "ImageOffsetY", 0, &cfgChanged)
        c := EnsureIniSectionKey(c, "StatMonitorTheme", "InfoImagePath", "", &cfgChanged)
        c := EnsureIniSectionKey(c, "StatMonitorTheme", "InfoImageMode", "Off", &cfgChanged)
        c := EnsureIniSectionKey(c, "StatMonitorTheme", "InfoImageOpacity", 100, &cfgChanged)
        c := EnsureIniSectionKey(c, "StatMonitorTheme", "InfoImageFit", "Contain", &cfgChanged)
    }

    if (c != orig) {
        try {
            FileDelete(configPath)
            FileAppend(c, configPath, "UTF-8")
            msg .= "âœ“ nm_config.ini patched`n"
        } catch {
            msg .= "âš  FAILED to write nm_config.ini`n"
        }
    }
}

; 2d. PATCH STATMONITOR_THEME.INI
if patchStatMonitorTheme {
    c := FileExist(statMonitorThemeConfigPath) ? FileRead(statMonitorThemeConfigPath, "UTF-8") : ""
    orig := c

    c := EnsureIniSectionKey(c, "StatMonitorTheme", "BackgroundMode", "Default", &cfgChanged)
    c := EnsureIniSectionKey(c, "StatMonitorTheme", "BackgroundFlat", "FF121212", &cfgChanged)
    c := EnsureIniSectionKey(c, "StatMonitorTheme", "BackgroundGradientTop", "FF121212", &cfgChanged)
    c := EnsureIniSectionKey(c, "StatMonitorTheme", "BackgroundGradientBottom", "FF1C1A1C", &cfgChanged)
    c := EnsureIniSectionKey(c, "StatMonitorTheme", "RegionBorder", "FF282628", &cfgChanged)
    c := EnsureIniSectionKey(c, "StatMonitorTheme", "RegionFill", "FF201E20", &cfgChanged)
    c := EnsureIniSectionKey(c, "StatMonitorTheme", "StatRegionBorder", "FF353335", &cfgChanged)
    c := EnsureIniSectionKey(c, "StatMonitorTheme", "StatRegionFill", "FF2C2A2C", &cfgChanged)
    c := EnsureIniSectionKey(c, "StatMonitorTheme", "GraphFill", "80141414", &cfgChanged)
    c := EnsureIniSectionKey(c, "StatMonitorTheme", "ImagePath", "", &cfgChanged)
    c := EnsureIniSectionKey(c, "StatMonitorTheme", "ImageLayer", "Background", &cfgChanged)
    c := EnsureIniSectionKey(c, "StatMonitorTheme", "ImageOpacity", 55, &cfgChanged)
    c := EnsureIniSectionKey(c, "StatMonitorTheme", "ImageFit", "Contain", &cfgChanged)
    c := EnsureIniSectionKey(c, "StatMonitorTheme", "ImageScale", 100, &cfgChanged)
    c := EnsureIniSectionKey(c, "StatMonitorTheme", "ImageOffsetX", 0, &cfgChanged)
    c := EnsureIniSectionKey(c, "StatMonitorTheme", "ImageOffsetY", 0, &cfgChanged)
    c := EnsureIniSectionKey(c, "StatMonitorTheme", "InfoImagePath", "", &cfgChanged)
    c := EnsureIniSectionKey(c, "StatMonitorTheme", "InfoImageMode", "Off", &cfgChanged)
    c := EnsureIniSectionKey(c, "StatMonitorTheme", "InfoImageOpacity", 100, &cfgChanged)
    c := EnsureIniSectionKey(c, "StatMonitorTheme", "InfoImageFit", "Contain", &cfgChanged)

    if (c != orig) {
        try {
            DirCreate(workDir "\settings")
            FileDelete(statMonitorThemeConfigPath)
        }
        catch
        {
        }

        try {
            FileAppend(c, statMonitorThemeConfigPath, "UTF-8")
            msg .= "âœ“ statmonitor_theme.ini patched`n"
        } catch {
            msg .= "âš  FAILED to write statmonitor_theme.ini`n"
        }
    }
}

; 3. PATCH ENUMS
if (patchTadSyncCore) {
try {
    if FileExist(enumIntPath) {
        c := FileRead(enumIntPath, "UTF-8")
        orig := c
        vars := ["FieldFollowingCheck", "VicHopCheck", "AltHopMondoEnabled"]
        for v in vars {
            if !InStr(c, '"' v '"') {
                c := RegExReplace(c, "(\s*\])", '`r`n`t, "' v '"$1')
            }
        }
        if (c != orig) {
            FileDelete(enumIntPath)
            FileAppend(c, enumIntPath, "UTF-8")
            msg .= "âœ“ EnumInt.ahk registered`n"
            FileAppend("âœ“ Registered TadSync/VicHop in EnumInt.ahk`n", logFile)
        }
    }
} catch {
    msg .= "âš  FAILED to patch EnumInt.ahk`n"
}

try {
    if FileExist(enumStrPath) {
        c := FileRead(enumStrPath, "UTF-8")
        orig := c
        vars := ["FieldFollowingFollowMode", "FieldFollowingMaxTime", "FieldFollowingChannelID", "VicHopMode", "VicHopMaxQueueTime", "VicHopChannelID", "AltHopMondoLeadTime"]
        for v in vars {
            if !InStr(c, '"' v '"') {
                c := RegExReplace(c, "(\s*\])", '`r`n`t, "' v '"$1')
            }
        }
        if (c != orig) {
            FileDelete(enumStrPath)
            FileAppend(c, enumStrPath, "UTF-8")
            msg .= "âœ“ EnumStr.ahk registered`n"
            FileAppend("âœ“ Registered TadSync/VicHop in EnumStr.ahk`n", logFile)
        }
    }
} catch {
    msg .= "âš  FAILED to patch EnumStr.ahk`n"
}
}

msg .= "`nPatching complete! Restart Natro Macro."
finalAttempts := 0
while (finalAttempts < 6) {
    try {
        FileAppend("--- End of Log ---`n", logFile)
        break
    } catch {
        finalAttempts += 1
        Sleep(200)
    }
}
MsgBox(msg, "TadSync Patch", 0x40)


