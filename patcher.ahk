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
    return '"Gather","Collect/Kill","Boost","Quests","Planters","Status","Settings","Misc","Credits", "Extensions"'
}

ReorderExtensionsLockTabs(listText) {
    return '"Gather","Collect","Boost","Quests","Planters","Status","Settings","Misc", "Extensions", "Extensions", "Extensions", "Extensions", "Extensions", "Extensions"'
}

NormalizeExtensionsConfigPlacement(text) {
    pattern := '(?ms)^[ \t]*config\["Extensions"\]\s*:=\s*Map\(.*?\)\R*'
    if !RegExMatch(text, pattern, &match)
        return text

    extensionsBlock := RTrim(match[0], "`r`n")
    textWithoutBlock := RegExReplace(text, pattern, "", , 1)
    if !(statusPos := InStr(textWithoutBlock, 'config["Status"] := Map('))
        return text

    return SubStr(textWithoutBlock, 1, statusPos - 1) extensionsBlock "`r`n" SubStr(textWithoutBlock, statusPos)
}

StrJoin(items, sep := ", ") {
    out := ""
    for i, item in items
        out .= (i = 1 ? "" : sep) item
    return out
}

ReplaceFirst(text, oldText, newText) {
    pos := InStr(text, oldText)
    if !pos
        return text
    return SubStr(text, 1, pos - 1) newText SubStr(text, pos + StrLen(oldText))
}

EnsureExtensionsEnzymeControl(text) {
    enzymeLine := '(GuiCtrl := MainGui.Add("CheckBox", "x345 y95 w140 h18 vEnzymesBoostedOnly" . (EnzymesBoostedOnly ? " Checked" : ""), "Boosted Enzyme Only")).Section := "Extensions", GuiCtrl.OnEvent("Click", nm_saveConfig)'
    if InStr(text, enzymeLine)
        return text

    preGlitterLine := '(GuiCtrl := MainGui.Add("CheckBox", "x345 y70 w135 h18 vPreGlitterCheck" . (PreGlitterCheck ? " Checked" : ""), "Pre-Glitter")).Section := "Extensions", GuiCtrl.OnEvent("Click", nm_saveConfig)'
    if InStr(text, preGlitterLine)
        return ReplaceFirst(text, preGlitterLine, preGlitterLine "`r`n" enzymeLine)

    glitterLine := 'MainGui.Add("CheckBox", "x345 y45 w135 h18 vPFieldBoosted Checked" PFieldBoosted, "Glitter Extend").OnEvent("Click", aq_togglePFieldBoosted)'
    if InStr(text, glitterLine)
        return ReplaceFirst(
            text,
            glitterLine,
            glitterLine . '`r`n(GuiCtrl := MainGui.Add("CheckBox", "x345 y70 w135 h18 vPreGlitterCheck" . (PreGlitterCheck ? " Checked" : ""), "Pre-Glitter")).Section := "Extensions", GuiCtrl.OnEvent("Click", nm_saveConfig)`r`n' . enzymeLine
        )

    return text
}

InsertAfterOnce(text, needle, insertion, marker := "") {
    if (marker != "" && InStr(text, marker))
        return text
    pos := InStr(text, needle)
    if !pos
        return text
    insertPos := pos + StrLen(needle)
    return SubStr(text, 1, insertPos) insertion SubStr(text, insertPos + 1)
}

InsertAfterOnceAfter(text, afterMarker, needle, insertion, marker := "") {
    if (marker != "" && InStr(text, marker))
        return text
    startPos := InStr(text, afterMarker)
    if !startPos
        return text
    pos := InStr(text, needle, , startPos)
    if !pos
        return text
    insertPos := pos + StrLen(needle)
    return SubStr(text, 1, insertPos) insertion SubStr(text, insertPos + 1)
}

LocateFunctionBlock(text, functionName, &blockStart := 0, &blockEnd := 0, fromPos := 1) {
    blockStart := 0
    blockEnd := 0
    pattern := 'm)^[ \t]*' functionName '\([^\r\n]*\)\s*\{'
    if !RegExMatch(text, pattern, &match, fromPos)
        return false

    blockStart := match.Pos(0)
    bracePos := InStr(text, "{", , blockStart)
    if !bracePos
        return false

    depth := 0
    inString := false
    inLineComment := false
    inBlockComment := false
    textLen := StrLen(text)
    i := bracePos
    while (i <= textLen) {
        ch := SubStr(text, i, 1)
        nextCh := (i < textLen) ? SubStr(text, i + 1, 1) : ""

        if (inString) {
            if (ch = '"') {
                if (nextCh = '"') {
                    i += 2
                    continue
                }
                inString := false
            }
        } else if (inLineComment) {
            if (ch = "`r" || ch = "`n")
                inLineComment := false
        } else if (inBlockComment) {
            if (ch = "*" && nextCh = "/") {
                inBlockComment := false
                i += 2
                continue
            }
        } else {
            if (ch = '"') {
                inString := true
            } else if (ch = ";" ) {
                inLineComment := true
            } else if (ch = "/" && nextCh = "*") {
                inBlockComment := true
                i += 2
                continue
            } else if (ch = "{") {
                depth += 1
            } else if (ch = "}") {
                depth -= 1
                if (depth = 0) {
                    blockEnd := i
                    return true
                }
            }
        }

        i += 1
    }

    return false
}

ReplaceFunctionBlock(text, functionName, replacement, &changed := false) {
    changed := false
    if !LocateFunctionBlock(text, functionName, &blockStart, &blockEnd)
        return text

    oldBlock := SubStr(text, blockStart, blockEnd - blockStart + 1)
    if (oldBlock = replacement)
        return text

    changed := true
    return SubStr(text, 1, blockStart - 1) replacement SubStr(text, blockEnd + 1)
}

NormalizeDelimitedBlock(text, pattern, transformMode, &changed := false) {
    changed := false
    fullPattern := '(?ms)' pattern
    if !RegExMatch(text, fullPattern, &match)
        return text

    if (transformMode = "tabs")
        newInner := ReorderExtensionsTabs(match[2])
    else if (transformMode = "locktabs")
        newInner := ReorderExtensionsLockTabs(match[2])
    else
        return text

    replacement := match[1] newInner match[3]
    if (replacement = match[0])
        return text

    changed := true
    return ReplaceFirst(text, match[0], replacement)
}

NormalizeForceMessageHooks(text) {
    text := StrReplace(text, "`r`nOnMessage(0x5564, nm_ForceStickerStack, 255)", "")
    text := StrReplace(text, "`nOnMessage(0x5564, nm_ForceStickerStack, 255)", "")
    text := StrReplace(text, "`r`nOnMessage(0x5565, nm_ForceBlueBooster, 255)", "")
    text := StrReplace(text, "`nOnMessage(0x5565, nm_ForceBlueBooster, 255)", "")
    if InStr(text, 'OnMessage(0x5560, nm_copyDebugLog)') {
        text := ReplaceFirst(text
            , 'OnMessage(0x5560, nm_copyDebugLog)'
            , 'OnMessage(0x5560, nm_copyDebugLog)`r`nOnMessage(0x5564, nm_ForceStickerStack, 255)`r`nOnMessage(0x5565, nm_ForceBlueBooster, 255)'
        )
    }
    return text
}

NormalizeRepeatedBlock(text, startMarker, endMarker, anchorLine := "") {
    startPos := InStr(text, startMarker)
    if !startPos
        return text

    endPos := InStr(text, endMarker, , startPos)
    if !endPos
        return text

    block := SubStr(text, startPos, endPos - startPos + StrLen(endMarker))
    nextPos := InStr(text, block, , startPos + StrLen(block))
    if !nextPos
        return text

    ; Keep the first block and remove later exact duplicates.
    while (nextPos := InStr(text, block, , startPos + StrLen(block))) {
        text := ReplaceFirst(text, block, "")
    }
    return text
}

NormalizeDuplicateFunction(text, functionName) {
    matches := []
    startAt := 1
    while LocateFunctionBlock(text, functionName, &blockStart, &blockEnd, startAt) {
        matches.Push({pos: blockStart, len: blockEnd - blockStart + 1})
        startAt := blockEnd + 1
    }
    if (matches.Length <= 1)
        return text

    Loop matches.Length - 1 {
        item := matches[matches.Length - A_Index + 1]
        text := SubStr(text, 1, item.pos - 1) SubStr(text, item.pos + item.len)
    }
    return text
}

RemoveFunctionBlocks(text, functionName) {
    matches := []
    startAt := 1
    while LocateFunctionBlock(text, functionName, &blockStart, &blockEnd, startAt) {
        matches.Push({pos: blockStart, len: blockEnd - blockStart + 1})
        startAt := blockEnd + 1
    }
    if (matches.Length = 0)
        return text

    Loop matches.Length {
        item := matches[matches.Length - A_Index + 1]
        text := SubStr(text, 1, item.pos - 1) SubStr(text, item.pos + item.len)
    }
    return text
}

RemoveRepeatedExactBlock(text, exactBlock) {
    firstPos := InStr(text, exactBlock)
    if !firstPos
        return text

    firstEnd := firstPos + StrLen(exactBlock) - 1
    searchPos := firstEnd + 1
    while (dupPos := InStr(text, exactBlock, , searchPos)) {
        text := SubStr(text, 1, dupPos - 1) SubStr(text, dupPos + StrLen(exactBlock))
        searchPos := firstEnd + 1
    }
    return text
}

NormalizeGoGatherMondoBlocks(text) {
    if !LocateFunctionBlock(text, "nm_GoGather", &blockStart, &blockEnd)
        return text

    block := SubStr(text, blockStart, blockEnd - blockStart + 1)
    originalBlock := block

    goGatherStartMondo := JoinLines(
        "`t;MONDO",
        "`tif mondointerrupt_ShouldTrigger() {",
        "`t`tmondointerrupt_Handle()",
        "`t`treturn",
        "`t}"
    )
    block := RemoveRepeatedExactBlock(block, goGatherStartMondo)

    goGatherHighMondo := JoinLines(
        "`t`t`t`t`tif mondointerrupt_ShouldTrigger() {",
        "`t`t`t`t`t`tClick " Chr(34) "Up" Chr(34),
        "`t`t`t`t`t`tnm_endWalk()",
        "`t`t`t`t`t`tnm_setShiftLock(0)",
        "`t`t`t`t`t`tif (PMondoGuidComplete)",
        "`t`t`t`t`t`t`tPMondoGuidComplete:=0",
        "`t`t`t`t`t`tmondointerrupt_Handle()",
        "`t`t`t`t`t`treturn",
        "`t`t`t`t`t}"
    )
    block := RemoveRepeatedExactBlock(block, goGatherHighMondo)

    if (block = originalBlock)
        return text

    return SubStr(text, 1, blockStart - 1) block SubStr(text, blockEnd + 1)
}

ValidateAutoHotkeyFile(exePath, filePath, &errorText := "") {
    errorText := ""
    if !FileExist(exePath)
        return false

    shell := ComObject("WScript.Shell")
    exec := shell.Exec('"' exePath '" /ErrorStdOut /Validate "' filePath '"')
    while (exec.Status = 0)
        Sleep(50)

    try errorText := exec.StdOut.ReadAll()
    catch {
    }
    try errorText .= exec.StdErr.ReadAll()
    catch {
    }
    return (exec.ExitCode = 0)
}

NormalizeExtensionsConfig(text) {
    pattern := '(?ms)^[ \t]*config\["Extensions"\]\s*:=\s*Map\(.+?\)\R*'
    matches := []
    startAt := 1
    while RegExMatch(text, pattern, &match, startAt) {
        matches.Push({start: match.Pos(0), len: StrLen(match[0]), text: RTrim(match[0], "`r`n")})
        startAt := match.Pos(0) + StrLen(match[0])
    }
    if (matches.Length = 0)
        return text

    canonical := matches[1].text
    canonical := RegExReplace(canonical, ',\s*"MondoInterruptCheck"\s*,\s*[01]', ', "MondoInterruptCheck", 1')
    canonical := RegExReplace(
        canonical,
        ',\s*"PFieldBoosted"\s*,\s*0(?:\s*,\s*"EnzymesBoostedOnly"\s*,\s*1)?',
        ', "PFieldBoosted", 0, "EnzymesBoostedOnly", 1',
        ,
        1
    )
    canonical := RegExReplace(canonical, ',\s*"ReconnectSyncCheck"\s*,\s*[01]', ', "ReconnectSyncCheck", 1')
    canonical := RegExReplace(canonical, ',\s*"ReconnectSyncMode"\s*,\s*"(Main|Alt)"', ', "ReconnectSyncMode", "Main"')
    canonical := RegExReplace(canonical, ',\s*"ReconnectSyncChannelID"\s*,\s*"?([^",)]*)"?', ', "ReconnectSyncChannelID", ""')
    if (matches.Length > 1) {
        for i, item in matches {
            if (i = 1)
                continue
            text := ReplaceFirst(text, item.text, "")
        }
    }
    text := ReplaceFirst(text, matches[1].text, canonical)
    if !(statusPos := InStr(text, 'config["Status"] := Map('))
        return text

    configPos := InStr(text, canonical)
    if !configPos
        return text

    if (configPos > statusPos) {
        text := ReplaceFirst(text, canonical, "")
        text := SubStr(text, 1, statusPos - 1) canonical "`r`n" SubStr(text, statusPos)
    }
    return text
}

StripReconnectSyncDebugLogging(text) {
    ; Remove noisy reconnect-sync trace spam while preserving reconnect behavior.
    text := RegExReplace(text, 'm)^[ \t]*FileAppend\(A_Now " - ReconnectSync [^\r\n]*\R?', '')
    return text
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

SetIniSectionKey(text, sectionName, keyName, value, &changed := false) {
    ; Made by @definetlynotray on discord
    changed := false
    sectionHeader := "[" sectionName "]"
    sectionPos := InStr(text, sectionHeader)
    if !sectionPos {
        base := RTrim(text, "`r`n")
        changed := true
        return ((base = "") ? "" : base "`r`n`r`n") sectionHeader "`r`n" keyName "=" value "`r`n"
    }

    nextSectionPos := RegExMatch(text, "m)^\[.+\]$", &sectionMatch, sectionPos + StrLen(sectionHeader)) ? sectionMatch.Pos : 0
    sectionText := nextSectionPos ? SubStr(text, sectionPos, nextSectionPos - sectionPos) : SubStr(text, sectionPos)
    linePattern := "m)^" keyName "=[^\r\n]*$"
    newLine := keyName "=" value

    if RegExMatch(sectionText, linePattern) {
        updatedSection := RegExReplace(sectionText, linePattern, newLine, &replaceCount, 1)
        if (updatedSection = sectionText)
            return text
        changed := true
        return nextSectionPos ? (SubStr(text, 1, sectionPos - 1) updatedSection SubStr(text, nextSectionPos)) : (SubStr(text, 1, sectionPos - 1) updatedSection)
    }

    changed := true
    insertText := newLine "`r`n"
    if nextSectionPos
        return SubStr(text, 1, nextSectionPos - 1) insertText SubStr(text, nextSectionPos)

    return RTrim(text, "`r`n") "`r`n" insertText
}

EnsureConfigMapEntry(text, mapName, keyName, defaultValue, &changed := false) {
    ; Made by @definetlynotray on discord
    changed := false
    mapPattern := '(?s)(config\["' mapName '"\]\s*:=\s*Map\()(.*?)(\))'
    if !RegExMatch(text, mapPattern, &match)
        return text

    if InStr(match[2], '"' keyName '"')
        return text

    changed := true
    return RegExReplace(text, mapPattern, '$1$2, "' keyName '", ' defaultValue '$3', , 1)
}

ShowPatchSelectionGui() {
    result := Map()
    selectionGui := Gui("+AlwaysOnTop", "Apply Patch Modules")
    selectionGui.SetFont("s9", "Segoe UI")
    selectionGui.Add("Text", "xm w560", "Select which patch groups to apply.")
    selectionGui.Add("Text", "xm y+6 w560", "Fresh recommended: TadSync Core, Glitter Extend, Enzyme Balloon Convert, BFB Interrupt, Sticker Stack Interrupt, Mondo Interrupt.")
    selectionGui.Add("Text", "xm y+4 w560", "Low risk on modified installs: Force Hourly Report, StatMonitor Theme Tools, Auto Jelly, Auto Bitter.")

    selectionGui.Add("CheckBox", "xm y+14 vPatchTadSyncCore Checked", "TadSync Core (Fresh recommended)")
    selectionGui.Add("CheckBox", "xm y+4 vPatchGlitterExtend Checked", "Glitter Extend (Fresh recommended)")
    selectionGui.Add("CheckBox", "xm y+4 vPatchEnzymeBalloon Checked", "Enzyme Balloon Convert (Fresh recommended)")
    selectionGui.Add("CheckBox", "xm y+4 vPatchBfb Checked", "BFB Interrupt (Fresh recommended)")
    selectionGui.Add("CheckBox", "xm y+4 vPatchStickerStack Checked", "Sticker Stack Interrupt (Fresh recommended)")
    selectionGui.Add("CheckBox", "xm y+4 vPatchMondoInterrupt Checked", "Mondo Interrupt (Fresh recommended)")
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
        result["PatchMondoInterrupt"] := !!saved.PatchMondoInterrupt
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
statMonitorAssetDir := assetsDir "\statmonitor"
    natroPath := workDir "\submacros\natro_macro.ahk"
    origNatPath := workDir "\submacros\natro_macro(Original Clean).ahk"
    backgroundPath := workDir "\submacros\background.ahk"
    statusPath := workDir "\submacros\Status.ahk"
    reconnectSyncPath := workDir "\Extensions\reconnectsync_status_extension.ahk"
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
blueBoosterStatCountersTemplatePath := patchTemplateDir "\blue_booster_stat_counters_patch.txt"
glitterExtendHelpersTemplatePath := patchTemplateDir "\glitter_extend_helpers_patch.txt"
glitterExtendGatherTemplatePath := patchTemplateDir "\glitter_extend_gather_patch.txt"
glitterExtendConvertTemplatePath := patchTemplateDir "\glitter_extend_convert_patch.txt"
glitterExtendStickerTemplatePath := patchTemplateDir "\glitter_extend_sticker_patch.txt"
stickerStackInterruptTemplatePath := patchTemplateDir "\stickerstack_interrupt_patch.txt"
nmConvertTemplatePath := patchTemplateDir "\nm_convert_patch.txt"
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
patchMondoInterrupt := selectedModules["PatchMondoInterrupt"]
patchForceHourly := selectedModules["PatchForceHourly"]
patchStatMonitorTheme := selectedModules["PatchStatMonitorTheme"]
patchAutoJelly := selectedModules["PatchAutoJelly"]
patchAutoBitter := selectedModules["PatchAutoBitter"]
enableRiskyCoreHooks := patchMondoHop

DirCreate(assetsDir)
DirCreate(pineaFbAssetDir)
DirCreate(statMonitorAssetDir)
FileAppend("? Ensured Assets folder exists`n", logFile)
for _, pineFallbackAsset in ["pine trees 1.png", "pine trees 2.png", "pine trees 3.png"] {
    sourceAsset := pineaFbAssetDir "\" pineFallbackAsset
    targetAsset := workDir "\nm_image_assets\" pineFallbackAsset
    if FileExist(sourceAsset) {
        DirCreate(workDir "\nm_image_assets")
        FileCopy(sourceAsset, targetAsset, 1)
        FileAppend("? Copied Pine AFB fallback asset " pineFallbackAsset "`n", logFile)
    }
}

stickerStackSourceAsset := statMonitorAssetDir "\StickerStack.png"
stickerStackTargetAsset := workDir "\nm_image_assets\statmonitor\StickerStack.png"
if FileExist(stickerStackSourceAsset) {
    DirCreate(workDir "\nm_image_assets\statmonitor")
    FileCopy(stickerStackSourceAsset, stickerStackTargetAsset, 1)
    FileAppend("? Copied StatMonitor StickerStack asset`n", logFile)
} else {
    FileAppend("! Missing Assets\\statmonitor\\StickerStack.png; continuing without Sticker Stack asset sync`n", logFile)
}

msg .= "Selected Modules:`n"
msg .= " - TadSync Core: " (patchTadSyncCore ? "ON" : "OFF") "`n"
msg .= " - Glitter Extend: " (patchGlitterExtend ? "ON" : "OFF") "`n"
msg .= " - Enzyme Balloon Convert: " (patchEnzymeBalloon ? "ON" : "OFF") "`n"
msg .= " - BFB Interrupt: " (patchBfb ? "ON" : "OFF") "`n"
msg .= " - Sticker Stack Interrupt: " (patchStickerStack ? "ON" : "OFF") "`n"
msg .= " - Mondo Interrupt: " (patchMondoInterrupt ? "ON" : "OFF") "`n"
msg .= " - Force Hourly Report: " (patchForceHourly ? "ON" : "OFF") "`n"
msg .= " - StatMonitor Theme Tools: " (patchStatMonitorTheme ? "ON" : "OFF") "`n"
msg .= " - Auto Jelly: " (patchAutoJelly ? "ON" : "OFF") "`n"
msg .= " - Auto Bitter: " (patchAutoBitter ? "ON" : "OFF") "`n`n"

; 1. PATCH NATRO_MACRO.AHK
if FileExist(natroPath) {
    c := FileRead(natroPath, "UTF-8")
    orig := c

    ; 0. Double Enter on reset for reliability
    if !InStr(c, 'SC_Esc "}{" SC_R "}{" SC_Enter "}{" SC_Enter ') {
        c := StrReplace(c, 'send "{" SC_Esc "}{" SC_R "}{" SC_Enter "}', 'send "{" SC_Esc "}{" SC_R "}{" SC_Enter "}{" SC_Enter "}')
        FileAppend("? Added double Enter press on reset`n", logFile)
    }

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
            FileAppend("? Restored Beesmas checkbox state rehydration`n", logFile)
        
        ; 1a0. Clean up old submacros/ includes (migrate to Extensions/ path)
        c := RegExReplace(c, 'm)#Include "%A_ScriptDir%\\tadsync_(\w+)\.ahk"', '#Include "%A_ScriptDir%\..\Extensions\tadsync_$1.ahk"')

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
            FileAppend("? Repaired stripped nm_GoGather() function header from older patch run`n", logFile)
        }
        if !InStr(c, 'nm_GoGather(){') {
            goGatherFallbackPattern := '(?ms)(\}\r?\n\}\r?\n)(\s*global youDied\b)'
            cNew := RegExReplace(c, goGatherFallbackPattern, '$1nm_GoGather(){`r`n$2', &goGatherFallbackCount, 1)
            if (goGatherFallbackCount > 0 && cNew != c) {
                c := cNew
                FileAppend("? Reinserted nm_GoGather() header before global block`n", logFile)
            }
        }

        ; TadSync core should always normalize and ensure the Hive standby request hook,
        ; even when BFB patching is not selected.
        cNew := RegExReplace(c, '(?<!\w)(?:adsync_RequestHiveStandby\(\)|t{2,}adsync_RequestHiveStandby\(\)|[A-Za-z_][A-Za-z0-9_]*adsync_RequestHiveStandby\(\))', 'tadsync_RequestHiveStandby()', &count)
        if (count > 0) {
            c := cNew
            FileAppend("? TadSync Core fixed malformed hive-standby hook in nm_toBooster()`n", logFile)
        }
        if (boosterPos := InStr(c, 'nm_toBooster(location){')) {
            boosterHead := SubStr(c, boosterPos, 600)
            if !InStr(boosterHead, 'tadsync_RequestHiveStandby()') {
                pattern := '(nm_toBooster\(location\)\{\r?\n\s*global [^\r\n]*\r?\n\s*static [^\r\n]*\r\n)'
                cNew := RegExReplace(c, pattern, '$1`tadsync_RequestHiveStandby()`r`n', &count, 1)
                if (count > 0) {
                    c := cNew
                    FileAppend("? TadSync Core added hive-standby request before booster travel`n", logFile)
                }
            }
            if !InStr(boosterHead, 'ForceBlueBoosterInterrupt := 0') && InStr(boosterHead, 'tadsync_RequestHiveStandby()') {
                cNew := StrReplace(c, 'tadsync_RequestHiveStandby()`r`n', 'tadsync_RequestHiveStandby()`r`n`tif (location = "blue")`r`n`t`tForceBlueBoosterInterrupt := 0`r`n')
                if (cNew != c) {
                    c := cNew
                    FileAppend("? Added blue BFB reset to nm_toBooster()`n", logFile)
                }
            }
        }
        introPattern := '(?ms)(nm_toBooster\(location\)\{\r?\n\s*global [^\r\n]*\r?\n\s*static [^\r\n]*\r?\n)(?:\s*tadsync_RequestHiveStandby\(\)\r?\n(?:\s*if \(location = "blue"\)\r?\n\s*ForceBlueBoosterInterrupt := 0\r?\n)?)?\s*Loop 2 \{'
        introReplace := '$1`tadsync_RequestHiveStandby()`r`n`tif (location = "blue")`r`n`t`tForceBlueBoosterInterrupt := 0`r`n`r`n`tLoop 2 {'
        cNew := RegExReplace(c, introPattern, introReplace, &count, 1)
        if (count > 0 && cNew != c) {
            c := cNew
            FileAppend("? Canonicalized nm_toBooster() intro block`n", logFile)
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
        '`t`t`tboostChaseActive := (nowUnix() < nm_GetBoostChaseDeadline())`r`n'
        '`t`t`tstoredBoostEnabled := nm_isBoostChaserFieldEnabled(StoredField)`r`n'
        '`t`t`tstoredBoostStart := (StoredTime > 0) ? StoredTime : 0`r`n'
        '`t`t`tstoredBoostRemaining := nm_GetBoostChaseRemainingSeconds(storedBoostStart)`r`n'
        '`t`t`tboostTotalDuration := nm_GetBoostTotalDuration()`r`n'
        '`t`t`tboostReturnStart := nm_GetBoostChaseStart(GatherFieldBoostedStart)`r`n'
        '`t`t`tboostReturnRemaining := nm_GetBoostChaseRemainingSeconds(GatherFieldBoostedStart)`r`n'
        '`t`t`tboostReturnAllowed := (boostReturnRemaining > 0)`r`n'
        '`t`t`tif (StoredField != "None" && storedBoostEnabled && boostChaseActive && (storedBoostRemaining > 0)) {`r`n'
        '`t`t`t`tBoostChaserField := StoredField`r`n'
        '`t`t`t`tGatherFieldBoostedStart := storedBoostStart`r`n'
        '`t`t`t`tfieldOverrideReason := "Boost"`r`n'
        '`t`t`t`ttadsync_LogBoostScan("gather-scan-stored-hit", CurrentField, RecentFBoost, StoredField)`r`n'
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
        '`t`t`tboostExtendActive := PFieldBoosted && ((nowUnix()-GatherFieldBoostedStart) < boostTotalDuration) && ((nowUnix()-LastGlitter) < 900)`r`n'
        '`t`t`tboostReturnStart := nm_GetBoostChaseStart(GatherFieldBoostedStart)`r`n'
        '`t`t`tboostReturnRemaining := nm_GetBoostChaseRemainingSeconds(GatherFieldBoostedStart)`r`n'
        '`t`t`tboostReturnAllowed := (boostReturnRemaining > 0)`r`n'
        '`r`n'
        '`t`t`tif (BoostChaserField == "None" && boostChaseActive && nm_GatherBoostInterrupt()) {`r`n'
        '`t`t`t`tloop 1 {`r`n'
        '`t`t`t`t`tif (RecentFBoost != "None" && recentBoostEnabled && boostChaseActive) {`r`n'
            '`t`t`t`t`t`tBoostChaserField:=RecentFBoost`r`n'
            '                        tadsync_LogBoostScan("gather-scan-recent-hit", CurrentField, RecentFBoost, BoostChaserField)`r`n'
            '`t`t`t`t`t`tbreak`r`n'
            '`t`t`t`t`t}`r`n'
        '                    tadsync_LogBoostScan("gather-scan-scan-fallback", CurrentField, RecentFBoost)`r`n'
        '`t`t`t`t`tfor i, location in ["blue", "mountain", "red", "coconut"] {`r`n'
        '`t`t`t`t`t`tfor v, enabled in boosterFieldGroups[location] {`r`n'
        '`t`t`t`t`t`t`tif(boostChaseActive && (nm_fieldBoostCheck(v, 1)) && enabled) {`r`n'
        '`t`t`t`t`t`t`t`tBoostDetectedAt := IniRead("settings\nm_config.ini", "Boost", "LastBoostedTime", 0)`r`n'
        '`t`t`t`t`t`t`t`tif (BoostDetectedAt <= 0 && location = "blue")`r`n'
        '`t`t`t`t`t`t`t`t`tBoostDetectedAt := IniRead("settings\nm_config.ini", "Boost", "LastBlueBoostUse", 0)`r`n'
        '`t`t`t`t`t`t`t`tif (BoostDetectedAt <= 0)`r`n'
        '`t`t`t`t`t`t`t`t`tBoostDetectedAt := nowUnix()`r`n'
        '`t`t`t`t`t`t`t`tif (nm_GetBoostChaseRemainingSeconds(BoostDetectedAt) <= 0)`r`n'
        '`t`t`t`t`t`t`t`t`tcontinue`r`n'
        '`t`t`t`t`t`t`t`tBoostChaserField:=v`r`n'
        '`t`t`t`t`t`t`t`tGatherFieldBoostedStart:=BoostDetectedAt`r`n'
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
        '`t`t`t`t`t`tif(boostChaseActive && nm_fieldBoostCheck(value, 1)) {`r`n'
        '`t`t`t`t`t`t`tBoostDetectedAt := IniRead("settings\nm_config.ini", "Boost", "LastBoostedTime", 0)`r`n'
        '`t`t`t`t`t`t`tif (BoostDetectedAt <= 0 && location = "blue")`r`n'
        '`t`t`t`t`t`t`t`tBoostDetectedAt := IniRead("settings\nm_config.ini", "Boost", "LastBlueBoostUse", 0)`r`n'
        '`t`t`t`t`t`t`tif (BoostDetectedAt <= 0)`r`n'
        '`t`t`t`t`t`t`t`tBoostDetectedAt := nowUnix()`r`n'
        '`t`t`t`t`t`t`tif (nm_GetBoostChaseRemainingSeconds(BoostDetectedAt) <= 0)`r`n'
        '`t`t`t`t`t`t`t`tcontinue`r`n'
        '`t`t`t`t`t`t`tBoostChaserField:=value`r`n'
        '`t`t`t`t`t`t`tGatherFieldBoostedStart:=BoostDetectedAt`r`n'
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
        FileAppend("? Replaced boosted-field override block with canonical patch-safe version`n", logFile)
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
                FileAppend("✓ Added Glitter to hotbarwhilelist`n", logFile)
            }
        }
    }


    ; 1c. Extensions Config
    if (patchTadSyncCore || patchMondoHop || patchMondoInterrupt || patchGlitterExtend || patchEnzymeBalloon) && !InStr(c, 'config["Extensions"]') {
        if (pos := InStr(c, 'config["Status"] := Map(')) {
            configCode := 'config["Extensions"] := Map("FollowingLeader", 0, "FollowingField", "", "FollowingStartTime", 0, "LastAnnouncedField", "", "FieldFollowingCheck", 0, "FieldFollowingFollowMode", "Follower", "FieldFollowingMaxTime", 900, "FieldFollowingChannelID", "", "FieldFollowingHiveRedirect", "Blue Flower", "PFieldBoosted", 0, "PreGlitterCheck", 0, "MondoInterruptCheck", 1, "EnzymesBoostedOnly", 1, "ReconnectSyncCheck", 1, "ReconnectSyncMode", "Main", "ReconnectSyncChannelID", ""'
            if patchMondoHop
                configCode .= ', "AltHopMondoEnabled", 0, "AltHopMondoLeadTime", 1.5, "AltHopMondoState", 0, "AltHopMondoLastTime", 0, "MondoHopLootTime", 45'
            configCode .= ')`r`n'
            c := SubStr(c, 1, pos-1) configCode SubStr(c, pos)
            FileAppend("✓ Added config['Extensions'] with Mondo settings`n", logFile)
        }
    } else if InStr(c, 'config["Extensions"] := Map(') {
        ; Append our keys to existing map
        pattern := '(config\["Extensions"\]\s*:=\s*Map\(.*?)(\))'
        appendBits := ''
        if !InStr(c, '"PreGlitterCheck"')
            appendBits .= ', "PreGlitterCheck", 0'
        if !InStr(c, '"MondoInterruptCheck"')
            appendBits .= ', "MondoInterruptCheck", 1'
        if !InStr(c, '"EnzymesBoostedOnly"')
            appendBits .= ', "EnzymesBoostedOnly", 1'
        if !InStr(c, '"ReconnectSyncCheck"')
            appendBits .= ', "ReconnectSyncCheck", 1'
        if !InStr(c, '"ReconnectSyncMode"')
            appendBits .= ', "ReconnectSyncMode", "Main"'
        if !InStr(c, '"ReconnectSyncChannelID"')
            appendBits .= ', "ReconnectSyncChannelID", ""'
        if (patchMondoHop && !InStr(c, '"AltHopMondoEnabled"'))
            appendBits .= ', "AltHopMondoEnabled", 0, "AltHopMondoLeadTime", 1.5, "AltHopMondoState", 0, "AltHopMondoLastTime", 0, "MondoHopLootTime", 45'
        if (appendBits != "") {
            c := RegExReplace(c, pattern, '$1' appendBits '$2')
        }
    }
    c := NormalizeExtensionsConfig(c)
    ; 1c2. Preset feature patch
    if (InStr(c, 'config["Settings"] := Map(') && !InStr(c, '"PresetTimed1"') && !InStr(c, '"PresetTimedEnable"')) {
        settingsNeedle := JoinLines(
            '		, "ShowOnPause", 0',
            '		, "IgnoreUpdateVersion", ""'
        )
        settingsInsert := JoinLines(
            '		, "ShowOnPause", 0',
            '		, "PresetTimed1", ""',
            '		, "PresetTimed2", ""',
            '		, "PresetInterval", 12',
            '		, "SelectPreset", ""',
            '		, "LastPreset", 0',
            '		, "PresetRepeat", 0',
            '		, "PresetTimedEnable", 0',
            '		, "lastPresetChange", 0',
            '		, "IgnoreUpdateVersion", ""'
        )
        cNew := StrReplace(c, settingsNeedle, settingsInsert)
        if (cNew != c) {
            c := cNew
            FileAppend("? Added preset defaults to config['Settings']`n", logFile)
        } else {
            FileAppend("! Preset defaults skipped; settings anchor not found`n", logFile)
        }
    } else if InStr(c, '"PresetTimedEnable"') {
        FileAppend("? Preset defaults already present`n", logFile)
    }
    presetLauncherOld := 'MainGui.Add("Button", "x145 y260 w65 h20 -Wrap Disabled vStopButton", " Stop (" StopHotkey ")").OnEvent("Click", nm_StopButton)'
    presetLauncherNew := JoinLines(
        presetLauncherOld,
        'MainGui.Add("Button", "x215 y260 w65 h20 -Wrap Disabled vPresetGUI", " Preset").OnEvent("Click", nm_PresetGUI)'
    )
    if InStr(c, 'x215 y260 w65 h20 -Wrap Disabled vPresetGUI') {
        FileAppend("? Preset launcher already present`n", logFile)
    } else if InStr(c, presetLauncherOld) {
        c := StrReplace(c, presetLauncherOld, presetLauncherNew)
        FileAppend("? Added preset launcher button`n", logFile)
    } else {
        FileAppend("! Preset launcher skipped; stop button anchor not found`n", logFile)
    }
    if InStr(c, 'nm_PresetGUI(*){') && InStr(c, 'PresetGui.Add("GroupBox", "x4 y126 w308 h112", "Included Settings")') {
        includeOld := JoinLines(
            '	PresetGui.Add("GroupBox", "x4 y126 w308 h112", "Included Settings")',
            '	PresetGui.Add("Button", "x107 y127 w10 h15", "?").OnEvent("Click", (*) => MsgBox("The Included Settings, each checkbox represents a different tab in natro macro to save.`n`nThere are a few exceptions:`nPS Link is your private server Link, Discord is the discord settings (screenshots, pings), Token/Webhook is your Bot Token and Webhook along with all your channel IDs and UserID, and Field Defaults is your saved gather settings for each field.", "Help", "0x1040"))',
            '	PresetGui.Add("CheckBox", "x9 yp+18 w60 h16 +Checked vPresetGather", "Gather")',
            '	PresetGui.Add("CheckBox", "x9 yp+18 w55 h16 +Checked vPresetQuest", "Quest")',
            '	PresetGui.Add("CheckBox", "x9 yp+18 w60 h16 +Checked vPresetSettings", "Settings")',
            '	PresetGui.Add("CheckBox", "x9 yp+18 w58 h16 vPresetDiscord", "Discord")',
            '	PresetGui.Add("Text", "x72 y144 w1 h67 0x7")',
            '	PresetGui.Add("CheckBox", "x78 y144 w106 h16 +Checked vPresetFDefaults", "Field Defaults")',
            '	PresetGui.Add("CheckBox", "x78 yp+18 w45 h16 +Checked vPresetMisc", "Misc")',
            '	PresetGui.Add("CheckBox", "x78 yp+18 w60 h16 vPresetPrivateServer", "PS Link")',
            '	PresetGui.Add("CheckBox", "x78 yp+18 w106 h16 vPresetWebBot", "Token/Webhook").OnEvent("Click", ConfirmWebBot)',
            '	PresetGui.Add("Text", "x185 y144 w1 h67 0x7")',
            '	PresetGui.Add("CheckBox", "x192 y144 w48 h16 +Checked vPresetBoost", "Boost").OnEvent("Click", hideTimer)',
            '	PresetGui.Add("CheckBox", "x255 yp w55 h16 vPresetBoostTimers", "Timers")',
            '	PresetGui.Add("CheckBox", "x192 yp+18 w57 h16 +Checked vPresetCollect", "Collect").OnEvent("Click", hideTimer)',
            '	PresetGui.Add("CheckBox", "x255 yp w55 h16 vPresetCollectTimers", "Timers")',
            '	PresetGui.Add("CheckBox", "x192 yp+18 w40 h16 +Checked vPresetKill", "Kill").OnEvent("Click", hideTimer)',
            '	PresetGui.Add("CheckBox", "x255 yp w55 h16 vPresetKillTimers", "Timers")',
            '	PresetGui.Add("CheckBox", "x192 yp+18 w59 h16 +Checked vPresetPlanters", "Planters").OnEvent("Click", hideTimer)',
            '	PresetGui.Add("CheckBox", "x255 yp w55 h16 vPresetPlantersTimers", "Timers")'
        )
        includeNew := JoinLines(
            '	PresetGui.Add("GroupBox", "x4 y2 w308 h112", "Include")',
            '	(GuiCtrl := PresetGui.Add("Button", "x107 y3 w10 h15", "?")).OnEvent("Click", (*) => MsgBox("The Include section controls which tabs are saved into a preset.``n``nThere are a few exceptions:``nPS Link is your private server Link, Discord is the discord settings (screenshots, pings), Token/Webhook is your Bot Token and Webhook along with all your channel IDs and UserID, Extensions is the extension settings tab, and Field Defaults is your saved gather settings for each field.", "Help", "0x1040"))',
            '	PresetGui.Add("CheckBox", "x9 y20 w60 h16 +Checked vPresetGather", "Gather")',
            '	PresetGui.Add("CheckBox", "x9 yp+18 w55 h16 +Checked vPresetQuest", "Quest")',
            '	PresetGui.Add("CheckBox", "x9 yp+18 w60 h16 +Checked vPresetSettings", "Settings")',
            '	PresetGui.Add("CheckBox", "x9 yp+18 w58 h16 vPresetDiscord", "Discord")',
            '	PresetGui.Add("Text", "x72 y20 w1 h67 0x7")',
            '	PresetGui.Add("CheckBox", "x78 y20 w106 h16 +Checked vPresetFDefaults", "Field Defaults")',
            '	PresetGui.Add("CheckBox", "x78 yp+18 w45 h16 +Checked vPresetMisc", "Misc")',
            '	PresetGui.Add("CheckBox", "x78 yp+18 w110 h16 +Checked vPresetExtensions", "Extensions")',
            '	PresetGui.Add("CheckBox", "x78 yp+18 w60 h16 vPresetPrivateServer", "PS Link")',
            '	PresetGui.Add("CheckBox", "x78 yp+18 w106 h16 vPresetWebBot", "Token/Webhook").OnEvent("Click", ConfirmWebBot)',
            '	PresetGui.Add("Text", "x185 y20 w1 h67 0x7")',
            '	PresetGui.Add("CheckBox", "x192 y20 w48 h16 +Checked vPresetBoost", "Boost").OnEvent("Click", hideTimer)',
            '	PresetGui.Add("CheckBox", "x255 yp w55 h16 vPresetBoostTimers", "Timers")',
            '	PresetGui.Add("CheckBox", "x192 yp+18 w57 h16 +Checked vPresetCollect", "Collect").OnEvent("Click", hideTimer)',
            '	PresetGui.Add("CheckBox", "x255 yp w55 h16 vPresetCollectTimers", "Timers")',
            '	PresetGui.Add("CheckBox", "x192 yp+18 w40 h16 +Checked vPresetKill", "Kill").OnEvent("Click", hideTimer)',
            '	PresetGui.Add("CheckBox", "x255 yp w55 h16 vPresetKillTimers", "Timers")',
            '	PresetGui.Add("CheckBox", "x192 yp+18 w59 h16 +Checked vPresetPlanters", "Planters").OnEvent("Click", hideTimer)',
            '	PresetGui.Add("CheckBox", "x255 yp w55 h16 vPresetPlantersTimers", "Timers")',
        )
        cNew := StrReplace(c, includeOld, includeNew)
        if (cNew != c) {
            c := cNew
            c := StrReplace(c, 'PresetGui.Show("x" gx+80 " y" gy+35 " w306 h212")', 'PresetGui.Show("x" gx+80 " y" gy+35 " w306 h244")')
            c := StrReplace(c, 'PresetGui.Add("GroupBox", "x4 y2 w100 h120", "Creation")', 'PresetGui.Add("GroupBox", "x4 y98 w100 h120", "Create")')
            c := StrReplace(c, 'PresetGui.Add("Button", "x9 y45 w90 h21 vCreatePreset", "Create New")', 'PresetGui.Add("Button", "x9 y141 w90 h21 vCreatePreset", "Create")')
            c := StrReplace(c, 'PresetGui.Add("Button", "x9 y70 w90 h21 vImportPreset", "Import")', 'PresetGui.Add("Button", "x9 y166 w90 h21 vImportPreset", "Import")')
            c := StrReplace(c, 'PresetGui.Add("Button", "x9 y95 w75 h21 vRenamePreset", "Rename")', 'PresetGui.Add("Button", "x9 y191 w75 h21 vRenamePreset", "Rename")')
            c := StrReplace(c, 'Select a preset under the Manage settings, and fill out a new name in the editbox under Creation settings, Then click Rename and your preset will be re-named.', 'Select a preset under Manage, then fill out a new name in the Create box and click Rename.')
            c := StrReplace(c, 'PresetGui.Add("GroupBox", "x108 y2 w100 h120", "Manage")', 'PresetGui.Add("GroupBox", "x108 y98 w100 h120", "Manage")')
            c := StrReplace(c, 'PresetGui.Add("Button", "x113 y45 w45 h20 vOverwritePreset", "Save")', 'PresetGui.Add("Button", "x113 y141 w45 h20 vOverwritePreset", "Save")')
            c := StrReplace(c, 'PresetGui.Add("Button", "x113 yp+25 wp hp vLoadPreset", "Load Preset")', 'PresetGui.Add("Button", "x113 yp+25 wp hp vLoadPreset", "Load")')
            c := StrReplace(c, 'PresetGui.Add("GroupBox", "x212 y2 w100 h120", "Timed")', 'PresetGui.Add("GroupBox", "x212 y98 w100 h120", "Timed")')
            c := StrReplace(c, 'PresetGui.Add("CheckBox", "x217 y16 w55 h16 vPresetTimedEnable", "Enable")', 'PresetGui.Add("CheckBox", "x217 y112 w55 h16 vPresetTimedEnable", "Enable")')
            c := StrReplace(c, 'PresetGui.Add("DropDownList", "x217 y33 w90 vPresetTimed1", presetlist)', 'PresetGui.Add("DropDownList", "x217 y129 w90 vPresetTimed1", presetlist)')
            c := StrReplace(c, 'PresetGui.Add("Text", "x219 y59", "Hours:")', 'PresetGui.Add("Text", "x219 y155", "Hours:")')
            c := StrReplace(c, 'PresetGui.Add("Edit", "x258 y58 w49 h18 limit3 Number vPresetIntervalEdit")', 'PresetGui.Add("Edit", "x258 y154 w49 h18 limit3 Number vPresetIntervalEdit")')
            c := StrReplace(c, 'PresetGui.Add("DropDownList", "x217 y79 w90 vPresetTimed2", presetlist)', 'PresetGui.Add("DropDownList", "x217 y175 w90 vPresetTimed2", presetlist)')
            c := StrReplace(c, 'PresetGui.Add("CheckBox", "x218 y103 w55 h16 vPresetRepeat", "Repeat")', 'PresetGui.Add("CheckBox", "x218 y199 w55 h16 vPresetRepeat", "Repeat")')
            FileAppend("? Updated preset dialog labels and layout`n", logFile)
        }
    }
    ; Preset cycle defaults removed to keep source preset behavior unchanged.
    ; 1c3. Preset launcher beside Stop
    presetCycleLauncherOld := 'MainGui.Add("Button", "x145 y260 w65 h20 -Wrap Disabled vStopButton", " Stop (" StopHotkey ")").OnEvent("Click", nm_StopButton)'
    presetCycleLauncherNew := JoinLines(
        presetCycleLauncherOld,
            'MainGui.Add("Button", "x215 y260 w65 h20 -Wrap Disabled vPresetGUI", " Preset").OnEvent("Click", nm_PresetGUI)'
    )
    if InStr(c, presetCycleLauncherOld) {
        c := StrReplace(c, presetCycleLauncherOld, presetCycleLauncherNew)
        FileAppend("? Added preset launcher beside Stop button`n", logFile)
    } else if InStr(c, 'x215 y260 w65 h20 -Wrap Disabled vPresetGUI') {
        FileAppend("? Preset launcher already present`n", logFile)
    } else {
        FileAppend("! Preset launcher skipped; stop button anchor not found`n", logFile)
    }
    if !InStr(c, 'MainGui["PresetGUI"].Enabled := 1') && InStr(c, 'MainGui["StopButton"].Enabled := 1') {
        startupEnableNeedle := JoinLines(
            'MainGui["StartButton"].Enabled := 1',
            'MainGui["PauseButton"].Enabled := 1',
            'MainGui["StopButton"].Enabled := 1'
        )
        startupEnableInsert := JoinLines(
            'MainGui["StartButton"].Enabled := 1',
            'MainGui["PauseButton"].Enabled := 1',
            'MainGui["StopButton"].Enabled := 1',
            'MainGui["PresetGUI"].Enabled := 1'
        )
        cNew := StrReplace(c, startupEnableNeedle, startupEnableInsert)
        if (cNew != c) {
            c := cNew
            FileAppend("? Enabled preset launcher with the main controls`n", logFile)
        }
    }
    if InStr(c, 'nm_AutoStartManager(*){') {
        presetTemplatePath := workDir "\patch_templates\preset_gui_copy.ahk"
        if FileExist(presetTemplatePath) {
            try {
                presetHelperBlock := FileRead(presetTemplatePath, "UTF-8")
            } catch as e {
                FileAppend("! Failed to read preset template from patch_templates: " e.Message "`n", logFile)
            }
        }
        if !IsSet(presetHelperBlock)
        presetHelperBlock := JoinLines(
            'nm_includePresets(*){',
            '	global presetList, PresetGui',
            '	if !IsSet(presetList)',
            '		presetList := []',
            '	Loop Files ".\settings\presets\*.ini"',
            '	{',
            '		name := StrReplace(A_LoopFileName, ".ini")',
            '		if !ObjHasValue(presetList, name) {',
            '			presetList.Push(name)',
            '			if IsSet(PresetGui) && IsObject(PresetGui)',
            '				for , v in ["SelectPreset", "PresetTimed1", "PresetTimed2"]',
            '					PresetGui[v].Add([name])',
            '		}',
            '	}',
            '}',
            'nm_PresetGuiSyncLists(*){',
            '	global PresetGui, presetList',
            '	if !(IsSet(PresetGui) && IsObject(PresetGui))',
            '		return',
            '	for , ctrlName in ["SelectPreset", "PresetTimed1", "PresetTimed2"] {',
            '		ctrl := PresetGui[ctrlName]',
            '		try count := ctrl.GetCount()',
            '		catch',
            '			count := 0',
            '		while (count > 0) {',
            '			try ctrl.Delete(1)',
            '			count -= 1',
            '		}',
            '		for , name in presetList',
            '			ctrl.Add([name])',
            '	}',
            '}',
            'hideTimed(ctrl,*){',
            '	global PresetGui',
            '	for , v in ["PresetInterval", "PresetTimed2", "PresetRepeat", "PresetIntervalEdit"]',
            '		PresetGui[v].Enabled := ctrl.Value',
            '	PresetGui["PresetTimed1"].Enabled := ctrl.Value',
            '}',
            'FileNameCleanup(*){',
            '	global PresetGui',
            '	userInput := PresetGui["SetPresetName"].Value',
            '	cleanedFileName := RegExReplace(userInput, "[\\/:*?" Chr(34) "<>|]")',
            '	if (cleanedFileName != userInput)',
            '		PresetGui["SetPresetName"].Value := cleanedFileName',
            '}',
            'ConfirmWebBot(*){',
            '	global PresetGui',
            '	if (PresetGui["PresetWebBot"].Value = 1)',
            '		if (MsgBox("Token/Webhook contains sensitive information. Continue?", "Help", 0x1034) = "no")',
            '			PresetGui["PresetWebBot"].Value := 0',
            '}',
            'hideTimer(ctrl,*){',
            '	global PresetGui',
            '	PresetGui[ctrl.Name "Timers"].Enabled := ctrl.Value',
            '	PresetGui[ctrl.Name "Timers"].Value := 0',
            '}',
            'nm_CreatePresetFiles(presetName, targetDir := ".\settings\presets", *){',
            '	global',
            '	if !presetName',
            '		return',
            '	if !DirExist(targetDir)',
            '		DirCreate(targetDir)',
            '	f := FileOpen(targetDir "\" presetName ".ini", "w")',
            '	f.Write(objectToIni(presetObj))',
            '	f.Close()',
            '	return targetDir "\" presetName ".ini"',
            '}',
            'nm_CreatePreset(*){',
            '	global PresetGui, presetList',
            '	PresetName := PresetGui["SetPresetName"].Value',
            '	if !PresetName',
            '		return MsgBox("No preset name given.",, "0x1010 T5")',
            '	nm_CreatePresetFiles(PresetName)',
            '	PresetGui["SetPresetName"].Value := ""',
            '	presetList := []',
            '	nm_includePresets()',
            '	nm_PresetGuiSyncLists()',
            '	if PresetGui["SelectPreset"].Enabled := !!presetList.Length',
            '		PresetGui["SelectPreset"].Text := PresetName',
            '		, SelectPreset := PresetName',
            '		, IniWrite(PresetName, ".\settings\nm_config.ini", "Settings", "SelectPreset")',
            '		, PresetGui["OverwritePreset"].Enabled := 1',
            '		, PresetGui["DeletePreset"].Enabled := 1',
            '		, PresetGui["CopyPreset"].Enabled := 1',
            '		, PresetGui["LoadPreset"].Enabled := 1',
            '		, PresetGui["RenamePreset"].Enabled := 1',
            '		, PresetGui["PresetTimedEnable"].Enabled := 1',
            '	else',
            '		PresetGui["OverwritePreset"].Enabled := 0',
            '		, PresetGui["DeletePreset"].Enabled := 0',
            '		, PresetGui["CopyPreset"].Enabled := 0',
            '		, PresetGui["LoadPreset"].Enabled := 0',
            '		, PresetGui["RenamePreset"].Enabled := 0',
            '		, PresetGui["PresetTimed1"].Enabled := 0',
            '		, PresetGui["PresetTimed2"].Enabled := 0',
            '		, PresetGui["PresetInterval"].Enabled := 0',
            '		, PresetGui["PresetIntervalEdit"].Enabled := 0',
            '		, PresetGui["PresetRepeat"].Enabled := 0',
            '		, PresetGui["PresetTimedEnable"].Enabled := 0',
            '		, PresetGui["PresetTimedEnable"].Value := 0',
            '}',
            'nm_ManagePreset(ctrl,*){',
            '	global PresetGui, presetList',
            '	PresetName := PresetGui["SelectPreset"].Text',
            '	if !PresetName',
            '		return MsgBox("No preset selected.",, "0x1010 T5")',
            '	switch ctrl.Name, 0 {',
            '		case "LoadPreset":',
            '			nm_LockTabs()',
            '			PresetGui.Destroy()',
            '			nm_loadPreset(PresetName)',
            '			nm_LockTabs(0)',
            '		case "OverwritePreset":',
            '			nm_CreatePresetFiles(PresetName)',
            '			nm_PresetGuiSyncLists()',
            '		case "DeletePreset":',
            '			FileDelete(".\settings\presets\" PresetName ".ini")',
            '			presetList := []',
            '			nm_includePresets()',
            '			nm_PresetGuiSyncLists()',
            '			if PresetGui["SelectPreset"].Enabled := !!presetList.Length',
            '				PresetGui["SelectPreset"].Text := presetList[1]',
            '				, SelectPreset := presetList[1]',
            '				, IniWrite(SelectPreset, ".\settings\nm_config.ini", "Settings", "SelectPreset")',
            '			else',
            '				PresetGui["OverwritePreset"].Enabled := 0',
            '				, PresetGui["DeletePreset"].Enabled := 0',
            '				, PresetGui["CopyPreset"].Enabled := 0',
            '				, PresetGui["LoadPreset"].Enabled := 0',
            '				, PresetGui["RenamePreset"].Enabled := 0',
            '				, PresetGui["PresetTimed1"].Enabled := 0',
            '				, PresetGui["PresetTimed2"].Enabled := 0',
            '				, PresetGui["PresetInterval"].Enabled := 0',
            '				, PresetGui["PresetIntervalEdit"].Enabled := 0',
            '				, PresetGui["PresetRepeat"].Enabled := 0',
            '				, PresetGui["PresetTimedEnable"].Enabled := 0',
            '				, PresetGui["PresetTimedEnable"].Value := 0',
            '		case "RenamePreset":',
            '			NewName := PresetGui["SetPresetName"].Value',
            '			if !NewName',
            '				return MsgBox("No preset name given.",, "0x1010 T5")',
            '			if FileExist(".\settings\presets\" PresetName ".ini")',
            '				FileMove(".\settings\presets\" PresetName ".ini", ".\settings\presets\" NewName ".ini", 1)',
            '			presetList := []',
            '			nm_includePresets()',
            '			nm_PresetGuiSyncLists()',
            '			PresetGui["SelectPreset"].Text := NewName',
            '			SelectPreset := NewName',
            '			IniWrite(NewName, ".\settings\nm_config.ini", "Settings", "SelectPreset")',
            '		case "CopyPreset":',
            '			sourcePath := A_WorkingDir "\settings\presets\" PresetName ".ini"',
            '			if !nm_CopyFileToClipboard(sourcePath)',
            '				return MsgBox("Failed to copy preset file to clipboard.", "Preset", 0x1010)',
            '			MsgBox("Preset " PresetName " copied to clipboard as a file.", "Preset", 0x1040)',
            '	}',
            '}',
            'nm_ImportPreset(*) {',
            '	presetFile := nm_GetClipboardFilePath()',
            '	if (presetFile = "")',
            '		return MsgBox("Clipboard does not contain a preset file.",,0x1010)',
            '	SplitPath(presetFile, &fileName, , &ext, &fileNameNoExt)',
            '	if (ext != "ini")',
            '		return MsgBox("Clipboard does not contain a valid .ini preset file.",,0x1010)',
            '	importDir := A_WorkingDir "\settings\presets"',
            '	if !DirExist(importDir)',
            '		DirCreate(importDir)',
            '	destPath := importDir "\" fileName',
            '	if FileExist(destPath) {',
            '		if (MsgBox("Preset " fileNameNoExt " already exists. Overwrite it?",, "0x1034") = "no")',
            '			return',
            '	}',
            '	FileCopy(presetFile, destPath, 1)',
            '	nm_includePresets()',
            '	nm_PresetGuiSyncLists()',
            '	if PresetGui["SelectPreset"].Enabled := !!presetList.length',
            '		PresetGui["SelectPreset"].Text := fileNameNoExt',
            '		, SelectPreset := fileNameNoExt',
            '		, IniWrite(fileNameNoExt, ".\settings\nm_config.ini", "Settings", "SelectPreset")',
            '		, PresetGui["OverwritePreset"].Enabled := 1',
            '		, PresetGui["DeletePreset"].Enabled := 1',
            '		, PresetGui["CopyPreset"].Enabled := 1',
            '		, PresetGui["LoadPreset"].Enabled := 1',
            '		, PresetGui["RenamePreset"].Enabled := 1',
            '		, PresetGui["PresetTimedEnable"].Enabled := 1',
            '	else',
            '		PresetGui["OverwritePreset"].Enabled := 0',
            '		, PresetGui["DeletePreset"].Enabled := 0',
            '		, PresetGui["CopyPreset"].Enabled := 0',
            '		, PresetGui["LoadPreset"].Enabled := 0',
            '		, PresetGui["RenamePreset"].Enabled := 0',
            '		, PresetGui["PresetTimed1"].Enabled := 0',
            '		, PresetGui["PresetTimed2"].Enabled := 0',
            '		, PresetGui["PresetInterval"].Enabled := 0',
            '		, PresetGui["PresetIntervalEdit"].Enabled := 0',
            '		, PresetGui["PresetRepeat"].Enabled := 0',
            '		, PresetGui["PresetTimedEnable"].Enabled := 0',
            '		, PresetGui["PresetTimedEnable"].Value := 0',
            '	MsgBox("Preset imported:`n" fileNameNoExt)',
            '	return !!presetList.length',
            '}',
            'nm_loadPreset(presetName, *){',
            '	global',
            '	local presetPath := ".\settings\presets\" presetName ".ini"',
            '	local f, preset, config, k, v, i, j',
            '	if !FileExist(presetPath)',
            '		return MsgBox("Preset appears to be missing: " presetName, "ERROR", "0x1010 T10")',
            '	f := FileOpen(presetPath, "r")',
            '	preset := configToObject(f.Read())',
            '	f.Close()',
            '	f := FileOpen(".\settings\nm_config.ini", "r")',
            '	config := configToObject(f.Read())',
            '	f.Close()',
            '	for k, v in preset {',
            '		switch k, 0 {',
            '			case "Gather", "Boost", "Quests", "Collect", "Planters", "Status", "Settings":',
            '				for i, j in v {',
            '					config[k][i] := j',
            '					%i% := j',
            '					try nm_updateGuiVar(i)',
            '				}',
            '		}',
            '	}',
            '	f := FileOpen(".\settings\nm_config.ini", "w")',
            '	f.Write(objectToIni(config))',
            '	f.Close()',
            '}',
            'nm_preset(){',
            '	global',
            '	if (lastPresetChange = 0)',
            '		lastPresetChange := nowUnix(), IniWrite(lastPresetChange, ".\settings\nm_config.ini", "Settings", "lastPresetChange")',
            '	if !PresetTimedEnable || (!PresetRepeat && LastPreset = 1)',
            '		return',
            '	preset := (LastPreset) ? PresetTimed1 : PresetTimed2',
            '	if (nowUnix() - lastPresetChange > (PresetInterval || 12) * 3600000) {',
            '		if (preset != "" && (PresetTimed1 != PresetTimed2 && LastPreset))',
            '			nm_loadPreset(preset), nm_setStatus("Preset", "Loaded preset " Chr(39) preset Chr(39) ". Changed from preset " Chr(39) (LastPreset ? PresetTimed2 : PresetTimed1) Chr(39) ". " PresetInterval " hours remaining.")',
            '		else',
            '			nm_setStatus("Preset", "Failed to change presets. " (PresetTimed1 = PresetTimed2 ? "Both slots have the same preset." : "No preset given for slot " (LastPreset ? "1" : "2")) ". Skipping preset change. " PresetInterval " hours remaining.")',
            '		lastPresetChange := nowUnix()',
            '		LastPreset := PresetRepeat * !LastPreset || 1',
            '		IniWrite(LastPreset, ".\settings\nm_config.ini", "Settings", "LastPreset")',
            '		IniWrite(lastPresetChange, ".\settings\nm_config.ini", "Settings", "lastPresetChange")',
            '	}',
            '}',
            'nm_PresetCycleTick(*) => nm_preset()',
            'nm_PresetCycleUpdateStateText(*) {',
            '}',
            'nm_PresetGuiClose(*) {',
            '	global PresetGui, PresetGuiX, PresetGuiY',
            '	if IsSet(PresetGui) && IsObject(PresetGui) {',
            '		try PresetGui.GetPos(&PresetGuiX, &PresetGuiY)',
            '		try IniWrite(PresetGuiX, ".\settings\nm_config.ini", "Settings", "PresetGuiX")',
            '		try IniWrite(PresetGuiY, ".\settings\nm_config.ini", "Settings", "PresetGuiY")',
            '		PresetGui := ""',
            '	}',
            '}',
            'nm_PresetGUI(ctrl, *) {',
            '	global MainGui, PresetGui, SelectPreset, PresetTimed1, PresetTimed2, PresetTimedEnable, PresetRepeat, PresetInterval, presetList, PresetGuiX, PresetGuiY',
            '	if IsSet(PresetGui) && IsObject(PresetGui)',
            '		PresetGui.Destroy()',
            '	if !IsSet(presetList)',
            '		nm_includePresets()',
            '	bx := 0, by := 0, bw := 65, bh := 20',
            '	try ctrl.GetPos(&bx, &by, &bw, &bh)',
            '	if IsSet(PresetGuiX) && IsSet(PresetGuiY) {',
            '		xPos := PresetGuiX',
            '		yPos := PresetGuiY',
            '	} else {',
            '		xPos := bx + (bw // 2) - 153',
            '		yPos := by + bh + 4',
            '	}',
            '	PresetGui := Gui("-MinimizeBox +Owner" MainGui.Hwnd, "Preset Settings")',
            '	PresetGui.OnEvent("Close", nm_PresetGuiClose)',
            '	PresetGui.SetFont("s9", "Segoe UI")',
            '	PresetGui.Show("x" xPos " y" yPos " w306 h244")',
            '	PresetGui.Add("GroupBox", "x4 y2 w308 h112", "Include")',
            '	(GuiCtrl := PresetGui.Add("Button", "x107 y3 w10 h15", "?")).OnEvent("Click", (*) => MsgBox("The Include section controls which tabs are saved into a preset.``n``nThere are a few exceptions:``nPS Link is your private server Link, Discord is the discord settings (screenshots, pings), Token/Webhook is your Bot Token and Webhook along with all your channel IDs and UserID, and Field Defaults is your saved gather settings for each field.", "Help", "0x1040"))',
            '	PresetGui.Add("CheckBox", "x9 y20 w60 h16 +Checked vPresetGather", "Gather")',
            '	PresetGui.Add("CheckBox", "x9 yp+18 w55 h16 +Checked vPresetQuest", "Quest")',
            '	PresetGui.Add("CheckBox", "x9 yp+18 w60 h16 +Checked vPresetSettings", "Settings")',
            '	PresetGui.Add("CheckBox", "x9 yp+18 w58 h16 vPresetDiscord", "Discord")',
            '	PresetGui.Add("Text", "x72 y20 w1 h67 0x7")',
            '	PresetGui.Add("CheckBox", "x78 y20 w106 h16 +Checked vPresetFDefaults", "Field Defaults")',
            '	PresetGui.Add("CheckBox", "x78 yp+18 w45 h16 +Checked vPresetMisc", "Misc")',
            '	PresetGui.Add("CheckBox", "x78 yp+18 w60 h16 vPresetPrivateServer", "PS Link")',
            '	PresetGui.Add("CheckBox", "x78 yp+18 w106 h16 vPresetWebBot", "Token/Webhook").OnEvent("Click", ConfirmWebBot)',
            '	PresetGui.Add("Text", "x185 y20 w1 h67 0x7")',
            '	PresetGui.Add("CheckBox", "x192 y20 w48 h16 +Checked vPresetBoost", "Boost").OnEvent("Click", hideTimer)',
            '	PresetGui.Add("CheckBox", "x255 yp w55 h16 vPresetBoostTimers", "Timers")',
            '	PresetGui.Add("CheckBox", "x192 yp+18 w57 h16 +Checked vPresetCollect", "Collect").OnEvent("Click", hideTimer)',
            '	PresetGui.Add("CheckBox", "x255 yp w55 h16 vPresetCollectTimers", "Timers")',
            '	PresetGui.Add("CheckBox", "x192 yp+18 w40 h16 +Checked vPresetKill", "Kill").OnEvent("Click", hideTimer)',
            '	PresetGui.Add("CheckBox", "x255 yp w55 h16 vPresetKillTimers", "Timers")',
            '	PresetGui.Add("CheckBox", "x192 yp+18 w59 h16 +Checked vPresetPlanters", "Planters").OnEvent("Click", hideTimer)',
            '	PresetGui.Add("CheckBox", "x255 yp w55 h16 vPresetPlantersTimers", "Timers")',
            '	PresetGui.Add("GroupBox", "x4 y98 w100 h120", "Create")',
            '	(GuiCtrl := PresetGui.Add("Edit", "x9 y116 w90 h21 vSetPresetName Limit15")).OnEvent("Change", FileNameCleanup)',
            '	PresetGui.Add("Button", "x9 y141 w90 h21 vCreatePreset", "Create").OnEvent("Click", nm_CreatePreset)',
            '	PresetGui.Add("Button", "x9 y166 w90 h21 vImportPreset", "Import").OnEvent("Click", nm_ImportPreset)',
            '	PresetGui.Add("Button", "x9 y191 w75 h21 vRenamePreset", "Rename").OnEvent("Click", nm_ManagePreset)',
            '	PresetGui.Add("Button", "x88 y194 w10 h15", "?").OnEvent("Click", (*) => MsgBox("Select a preset under Manage, then fill out a new name in the Create box and click Rename.", "Help", "0x1040"))',
            '	PresetGui.Add("GroupBox", "x108 y98 w100 h120", "Manage")',
            '	(GuiCtrl := PresetGui.Add("DropDownList", "x113 y116 w90 vSelectPreset", presetlist)).Section := "Settings", GuiCtrl.Text := SelectPreset, GuiCtrl.OnEvent("Change", nm_saveConfig)',
            '	PresetGui.Add("Button", "x113 y141 w45 h20 vOverwritePreset", "Save").OnEvent("Click", nm_ManagePreset)',
            '	PresetGui.Add("Button", "x158 yp w45 hp vDeletePreset", "Delete").OnEvent("Click", nm_ManagePreset)',
            '	PresetGui.Add("Button", "x113 yp+25 w90 hp vCopyPreset", "Export").OnEvent("Click", nm_ManagePreset)',
            '	PresetGui.Add("Button", "x113 yp+25 wp hp vLoadPreset", "Load").OnEvent("Click", nm_ManagePreset)',
            '	PresetGui.Add("GroupBox", "x212 y98 w100 h120", "Timed")',
            '	(GuiCtrl := PresetGui.Add("CheckBox", "x217 y112 w55 h16 vPresetTimedEnable", "Enable")).Section := "Settings", GuiCtrl.Value := PresetTimedEnable, GuiCtrl.OnEvent("Click", nm_saveConfig), GuiCtrl.OnEvent("Click", hideTimed)',
            '	(GuiCtrl := PresetGui.Add("DropDownList", "x217 y129 w90 vPresetTimed1", presetlist)).Section := "Settings", GuiCtrl.Text := PresetTimed1, GuiCtrl.OnEvent("Change", nm_saveConfig)',
            '	PresetGui.Add("Text", "x219 y155", "Hours:")',
            '	PresetGui.Add("Edit", "x258 y154 w49 h18 limit3 Number vPresetIntervalEdit").OnEvent("Change", (*) => nm_saveConfig(PresetGui["PresetInterval"]))',
            '	(GuiCtrl := PresetGui.Add("UpDown", "vPresetInterval range0-999", ValidateNumber(&PresetInterval, 12))).Section := "Settings", GuiCtrl.OnEvent("Change", nm_saveConfig)',
            '	(GuiCtrl := PresetGui.Add("DropDownList", "x217 y175 w90 vPresetTimed2", presetlist)).Section := "Settings", GuiCtrl.Text := PresetTimed2, GuiCtrl.OnEvent("Change", nm_saveConfig)',
            '	(GuiCtrl := PresetGui.Add("CheckBox", "x218 y199 w55 h16 vPresetRepeat", "Repeat")).Section := "Settings", GuiCtrl.Value := PresetRepeat, GuiCtrl.OnEvent("Click", nm_saveConfig), GuiCtrl.OnEvent("Click", (ctrl, *) => PresetGui["PresetTimed1"].Enabled := ctrl.Value)',
            '	if (presetList.Length = 0) {',
            '		for k, v in ["SelectPreset", "CopyPreset", "DeletePreset", "OverwritePreset", "LoadPreset", "RenamePreset", "PresetTimedEnable"]',
            '			PresetGui[v].Enabled := 0',
            '		if PresetTimedEnable',
            '			PresetGui["PresetTimedEnable"].Value := 0, IniWrite(0, ".\settings\nm_config.ini", "Settings", "PresetTimedEnable"), PresetTimedEnable := 0',
            '	}',
            '	if (!PresetTimedEnable || presetList.Length = 0)',
            '		for , v in ["PresetTimed1", "PresetInterval", "PresetTimed2", "PresetRepeat", "PresetIntervalEdit"]',
            '			PresetGui[v].Enabled := 0',
            '}'
        )
        helperStart := InStr(c, 'nm_includePresets()')
        if (helperStart > 0) {
            helperEnd := InStr(c, 'nm_AutoStartManager(*){', 1, helperStart)
        } else {
            helperEnd := 0
        }
        if (helperStart && helperEnd && helperEnd > helperStart) {
            currentPresetHelperBlock := SubStr(c, helperStart, helperEnd - helperStart)
            if (currentPresetHelperBlock != presetHelperBlock) {
                c := SubStr(c, 1, helperStart - 1) presetHelperBlock SubStr(c, helperEnd)
                FileAppend("? Replaced preset helper dialog/functions`n", logFile)
            } else {
                FileAppend("? Preset helper dialog/functions already present`n", logFile)
            }
        } else {
            cNew := StrReplace(c, 'nm_AutoStartManager(*){', presetHelperBlock "`r`n`r`nnm_AutoStartManager(*){")
            if (cNew != c) {
                c := cNew
                FileAppend("? Added preset helper dialog/functions`n", logFile)
            } else {
                FileAppend("! Preset helper dialog/functions skipped; insertion anchor not found`n", logFile)
            }
        }
    }
    ; 1c4. Preset cycle dialog and helper functions
    if false && !InStr(c, 'nm_PresetCycleApplyNow(*) {') && InStr(c, 'nm_PresetCycleGUI(*){}') {
        presetCycleDialogBlock := JoinLines(
            'nm_PresetCycleGUI(*) {',
            '	global MainGui, PresetCycleGui, PresetCycleEnabled, PresetCycleSlotA, PresetCycleSlotB, PresetCycleIntervalHours, PresetCycleRepeat, PresetCycleActiveSlot, PresetCycleLastSwitch',
            '	local GuiCtrl',
            '',
            '	try {',
            '		if (IsSet(PresetCycleGui) && IsObject(PresetCycleGui)) {',
            '			try PresetCycleGui.Destroy()',
            '			PresetCycleGui := ""',
            '		}',
            '		PresetCycleGui := Gui("+AlwaysOnTop -MinimizeBox +Owner" MainGui.Hwnd, "Preset Cycle")',
            '		PresetCycleGui.OnEvent("Close", nm_PresetCycleGuiClose)',
            '		PresetCycleGui.SetFont("s8 cDefault Norm", "Tahoma")',
            '		PresetCycleGui.Add("GroupBox", "x8 y8 w370 h191", "Preset Cycle Scheduler")',
            '',
            '		(GuiCtrl := PresetCycleGui.Add("CheckBox", "x18 y24 vPresetCycleEnabled Checked" PresetCycleEnabled, "Enable preset cycle")).Section := "Settings"',
            '		GuiCtrl.OnEvent("Click", nm_PresetCycleSave)',
            '',
            '		PresetCycleGui.Add("Text", "x18 y51 w45 +BackgroundTrans", "Slot A:")',
            '		(GuiCtrl := PresetCycleGui.Add("Edit", "x70 y47 w205 h20 vPresetCycleSlotA", PresetCycleSlotA)).Section := "Settings"',
            '		GuiCtrl.OnEvent("Change", nm_PresetCycleSave)',
            '		PresetCycleGui.Add("Button", "x280 y47 w40 h20 vPresetCycleBrowseA", "Browse").OnEvent("Click", nm_PresetCycleBrowse)',
            '		PresetCycleGui.Add("Button", "x325 y47 w45 h20 vPresetCycleClearA", "Clear").OnEvent("Click", nm_PresetCycleClear)',
            '',
            '		PresetCycleGui.Add("Text", "x18 y78 w45 +BackgroundTrans", "Slot B:")',
            '		(GuiCtrl := PresetCycleGui.Add("Edit", "x70 y74 w205 h20 vPresetCycleSlotB", PresetCycleSlotB)).Section := "Settings"',
            '		GuiCtrl.OnEvent("Change", nm_PresetCycleSave)',
            '		PresetCycleGui.Add("Button", "x280 y74 w40 h20 vPresetCycleBrowseB", "Browse").OnEvent("Click", nm_PresetCycleBrowse)',
            '		PresetCycleGui.Add("Button", "x325 y74 w45 h20 vPresetCycleClearB", "Clear").OnEvent("Click", nm_PresetCycleClear)',
            '',
            '		PresetCycleGui.Add("Text", "x18 y104 w96 +BackgroundTrans", "Interval (hours):")',
            '		(GuiCtrl := PresetCycleGui.Add("Edit", "x120 y100 w50 h20 limit4 number vPresetCycleIntervalHours", ValidateNumber(&PresetCycleIntervalHours, 1))).Section := "Settings"',
            '		GuiCtrl.OnEvent("Change", nm_PresetCycleSave)',
            '		(GuiCtrl := PresetCycleGui.Add("CheckBox", "x190 y101 vPresetCycleRepeat Checked" PresetCycleRepeat, "Repeat")).Section := "Settings"',
            '		GuiCtrl.OnEvent("Click", nm_PresetCycleSave)',
            '',
            '		PresetCycleGui.Add("Text", "x18 y130 w334 h32 vPresetCycleState +BackgroundTrans", "")',
            '		PresetCycleGui.Add("Button", "x18 y167 w95 h22 vPresetCycleSave", "Save / Apply").OnEvent("Click", nm_PresetCycleSave)',
            '		PresetCycleGui.Add("Button", "x120 y167 w85 h22 vPresetCycleApplyNow", "Apply Now").OnEvent("Click", nm_PresetCycleApplyNow)',
            '',
            '		PresetCycleGui.Show("w388 h198")',
            '		nm_PresetCycleSyncGui()',
            '	} catch as err {',
            '		PresetCycleGui := ""',
            '		nm_setStatus("Preset Cycle", "Open failed")',
            '		MsgBox("Preset Cycle dialog failed to open.`n`n" err.Message, "Preset Cycle", 0x10)',
            '	}',
            '}',
            'nm_PresetCycleLaunch(*) {',
            '	MsgBox("Preset Cycle launcher clicked", "Preset Cycle", 0x40)',
            '	nm_PresetCycleGUI()',
            '}',
            'nm_PresetCycleGuiClose(*) {',
            '	global PresetCycleGui',
            '	if (IsSet(PresetCycleGui) && IsObject(PresetCycleGui)) {',
            '		try PresetCycleGui.Destroy()',
            '		PresetCycleGui := ""',
            '	}',
            '}',
            'nm_PresetCycleSyncGui(*) {',
            '	global PresetCycleGui, PresetCycleEnabled, PresetCycleSlotA, PresetCycleSlotB, PresetCycleIntervalHours, PresetCycleRepeat, PresetCycleActiveSlot, PresetCycleLastSwitch',
            '	if !(IsSet(PresetCycleGui) && IsObject(PresetCycleGui))',
            '		return',
            '	try {',
            '		PresetCycleGui["PresetCycleEnabled"].Value := !!PresetCycleEnabled',
            '		PresetCycleGui["PresetCycleSlotA"].Text := nm_PresetCycleNormalizePresetId(PresetCycleSlotA)',
            '		PresetCycleGui["PresetCycleSlotB"].Text := nm_PresetCycleNormalizePresetId(PresetCycleSlotB)',
            '		PresetCycleGui["PresetCycleIntervalHours"].Value := ValidateNumber(&PresetCycleIntervalHours, 1)',
            '		PresetCycleGui["PresetCycleRepeat"].Value := !!PresetCycleRepeat',
            '		nm_PresetCycleUpdateStateText()',
            '	}',
            '}',
            'nm_PresetCycleUpdateStateText(*) {',
            '	global PresetCycleGui, PresetCycleEnabled, PresetCycleSlotA, PresetCycleSlotB, PresetCycleIntervalHours, PresetCycleRepeat, PresetCycleActiveSlot, PresetCycleLastSwitch',
            '		, MacroState',
            '	if !(IsSet(PresetCycleGui) && IsObject(PresetCycleGui))',
            '		return',
            '	slotA := nm_PresetCycleNormalizePresetId(PresetCycleSlotA), slotB := nm_PresetCycleNormalizePresetId(PresetCycleSlotB)',
            '	activeSlot := nm_PresetCycleNormalizeActiveSlot(PresetCycleActiveSlot)',
            '	activeText := activeSlot ? activeSlot : "None"',
            '	if (SubStr(Trim(PresetCycleActiveSlot), -1) = "!")',
            '		activeText .= " (done)"',
            '	interval := ValidateNumber(&PresetCycleIntervalHours, 1)',
            '	stateText := (PresetCycleEnabled ? "Enabled" : "Disabled")',
            '	stateText .= " | Interval: " interval "h"',
            '	stateText .= " | Repeat: " (PresetCycleRepeat ? "On" : "Off")',
            '	stateText .= " | Slot A: " (slotA ? slotA : "Empty")',
            '	stateText .= " | Slot B: " (slotB ? slotB : "Empty")',
            '	stateText .= " | Active: " activeText',
            '	stateText .= " | Last: " (PresetCycleLastSwitch ? PresetCycleLastSwitch : "0")',
            '	stateText .= " | Macro: " ((MacroState = 2) ? "Running" : (MacroState = 1) ? "Paused" : "Stopped")',
            '	stateText .= " | Stop keeps slots/state"',
            '	try PresetCycleGui["PresetCycleState"].Text := stateText',
            '}',
            'nm_PresetCycleSave(GuiCtrl?, *) {',
            '	global PresetCycleGui, PresetCycleEnabled, PresetCycleSlotA, PresetCycleSlotB, PresetCycleIntervalHours, PresetCycleRepeat, PresetCycleActiveSlot, PresetCycleLastSwitch',
            '	if !(IsSet(PresetCycleGui) && IsObject(PresetCycleGui))',
            '		return',
            '	PresetCycleEnabled := PresetCycleGui["PresetCycleEnabled"].Value ? 1 : 0',
            '	PresetCycleSlotA := nm_PresetCycleNormalizePresetId(PresetCycleGui["PresetCycleSlotA"].Text)',
            '	PresetCycleSlotB := nm_PresetCycleNormalizePresetId(PresetCycleGui["PresetCycleSlotB"].Text)',
            '	PresetCycleIntervalHours := PresetCycleGui["PresetCycleIntervalHours"].Text',
            '	ValidateNumber(&PresetCycleIntervalHours, 1)',
            '	if (PresetCycleIntervalHours < 1)',
            '		PresetCycleIntervalHours := 1',
            '	PresetCycleRepeat := PresetCycleGui["PresetCycleRepeat"].Value ? 1 : 0',
            '	PresetCycleActiveSlot := Trim(PresetCycleActiveSlot)',
            '	PresetCycleLastSwitch := ValidateNumber(&PresetCycleLastSwitch, 0)',
            '	try PresetCycleGui["PresetCycleIntervalHours"].Value := PresetCycleIntervalHours',
            '	try PresetCycleGui["PresetCycleSlotA"].Text := PresetCycleSlotA',
            '	try PresetCycleGui["PresetCycleSlotB"].Text := PresetCycleSlotB',
            '	IniWrite PresetCycleEnabled, "settings\nm_config.ini", "Settings", "PresetCycleEnabled"',
            '	IniWrite PresetCycleSlotA, "settings\nm_config.ini", "Settings", "PresetCycleSlotA"',
            '	IniWrite PresetCycleSlotB, "settings\nm_config.ini", "Settings", "PresetCycleSlotB"',
            '	IniWrite PresetCycleIntervalHours, "settings\nm_config.ini", "Settings", "PresetCycleIntervalHours"',
            '	IniWrite PresetCycleRepeat, "settings\nm_config.ini", "Settings", "PresetCycleRepeat"',
            '	IniWrite PresetCycleActiveSlot, "settings\nm_config.ini", "Settings", "PresetCycleActiveSlot"',
            '	IniWrite PresetCycleLastSwitch, "settings\nm_config.ini", "Settings", "PresetCycleLastSwitch"',
            '	nm_PresetCycleUpdateStateText()',
            '}',
            'nm_PresetCycleBrowse(GuiCtrl, *) {',
            '	global PresetCycleGui',
            '	if !(IsSet(PresetCycleGui) && IsObject(PresetCycleGui))',
            '		return',
            '	slot := (GuiCtrl.Name = "PresetCycleBrowseA") ? "A" : "B"',
            '	path := FileSelect(1, A_WorkingDir "\patterns", "Select Pattern File", "AHK Files (*.ahk)")',
            '	if (path = "")',
            '		return',
            '	try PresetCycleGui["PresetCycleSlot" slot].Text := nm_PresetCycleNormalizePresetId(path)',
            '	nm_PresetCycleSave()',
            '}',
            'nm_PresetCycleClear(GuiCtrl, *) {',
            '	global PresetCycleGui',
            '	if !(IsSet(PresetCycleGui) && IsObject(PresetCycleGui))',
            '		return',
            '	slot := (GuiCtrl.Name = "PresetCycleClearA") ? "A" : "B"',
            '	try PresetCycleGui["PresetCycleSlot" slot].Text := ""',
            '	nm_PresetCycleSave()',
            '}',
            'nm_PresetCycleApplyNow(*) {',
            '	nm_PresetCycleSave()',
            '	nm_PresetCycleTick(1)',
            '}',
            'nm_PresetCycleNormalizePresetId(value) {',
            '	value := Trim(value)',
            '	if (value = "")',
            '		return ""',
            '	SplitPath value, , , , &nameNoExt',
            '	return nameNoExt ? nameNoExt : value',
            '}',
            'nm_PresetCycleNormalizeActiveSlot(value) {',
            '	value := Trim(value)',
            '	if (value = "")',
            '		return ""',
            '	if (SubStr(value, -1) = "!")',
            '		value := SubStr(value, 1, -1)',
            '	value := StrUpper(value)',
            '	return ((value = "A") || (value = "B")) ? value : ""',
            '}',
            'nm_PresetCycleApplyPreset(presetId) {',
            '	global patterns, FieldDefault, FieldName, FieldPattern, CurrentField, CurrentFieldNum, MainGui',
            '	if !patterns.Has(presetId)',
            '		return 0',
            '	FieldPattern := presetId',
            '	if (FieldName && FieldDefault.Has(FieldName))',
            '		FieldDefault[FieldName]["pattern"] := presetId',
            '	if (CurrentField && FieldDefault.Has(CurrentField))',
            '		FieldDefault[CurrentField]["pattern"] := presetId',
            '	if (CurrentFieldNum >= 1 && CurrentFieldNum <= 3) {',
            '		try MainGui["FieldPattern" CurrentFieldNum].Text := presetId',
            '		try MainGui["FieldPattern" CurrentFieldNum].Redraw()',
            '	}',
            '	return 1',
            '}',
            'nm_PresetCycleTick(force := 0) {',
            '	global patterns, MacroState, PresetCycleEnabled, PresetCycleSlotA, PresetCycleSlotB',
            '		, PresetCycleIntervalHours, PresetCycleRepeat, PresetCycleActiveSlot, PresetCycleLastSwitch',
            '	static lastNotice := ""',
            '',
            '	if (!PresetCycleEnabled) {',
            '		notice := "Scheduler disabled"',
            '		if (notice != lastNotice) {',
            '			nm_setStatus("Preset Cycle", notice)',
            '			lastNotice := notice',
            '		}',
            '		return 0',
            '	}',
            '	if (!force && ((MacroState != 2) || A_IsPaused))',
            '		return 0',
            '',
            '	slotA := nm_PresetCycleNormalizePresetId(PresetCycleSlotA)',
            '	slotB := nm_PresetCycleNormalizePresetId(PresetCycleSlotB)',
            '	activeSlot := nm_PresetCycleNormalizeActiveSlot(PresetCycleActiveSlot)',
            '	intervalHours := ValidateNumber(&PresetCycleIntervalHours, 1)',
            '	if (intervalHours < 1)',
            '		intervalHours := 1',
            '',
            '	if (!slotA || !slotB) {',
            '		notice := (!slotA && !slotB) ? "Slot A and B are empty" : (!slotA ? "Slot A is empty" : "Slot B is empty")',
            '		if (notice != lastNotice) {',
            '			nm_setStatus("Preset Cycle", notice)',
            '			lastNotice := notice',
            '		}',
            '		return 0',
            '	}',
            '',
            '	if (slotA = slotB) {',
            '		notice := "Slots use the same preset"',
            '		if (notice != lastNotice) {',
            '			nm_setStatus("Preset Cycle", notice)',
            '			lastNotice := notice',
            '		}',
            '		return 0',
            '	}',
            '',
            '	if (activeSlot && !PresetCycleRepeat) {',
            '		notice := "Repeat completed"',
            '		if (notice != lastNotice) {',
            '			nm_setStatus("Preset Cycle", notice)',
            '			lastNotice := notice',
            '		}',
            '		return 0',
            '	}',
            '',
            '	now := nowUnix()',
            '	if !PresetCycleLastSwitch {',
            '		PresetCycleLastSwitch := now',
            '		try IniWrite PresetCycleLastSwitch, "settings\nm_config.ini", "Settings", "PresetCycleLastSwitch"',
            '		if (!force) {',
            '			nm_PresetCycleUpdateStateText()',
            '			return 0',
            '		}',
            '	} else {',
            '		PresetCycleLastSwitch := ValidateNumber(&PresetCycleLastSwitch, now)',
            '	}',
            '',
            '	if (!force && ((now - PresetCycleLastSwitch) < (intervalHours * 3600)))',
            '		return 0',
            '',
            '	nextSlot := (activeSlot = "A") ? "B" : "A"',
            '	presetId := (nextSlot = "A") ? slotA : slotB',
            '	if !patterns.Has(presetId) {',
            '		notice := "Invalid preset target"',
            '		if (notice != lastNotice) {',
            '			nm_setStatus("Preset Cycle", notice)',
            '			lastNotice := notice',
            '		}',
            '		return 0',
            '	}',
            '',
            '	if !nm_PresetCycleApplyPreset(presetId) {',
            '		notice := "Invalid preset target"',
            '		if (notice != lastNotice) {',
            '			nm_setStatus("Preset Cycle", notice)',
            '			lastNotice := notice',
            '		}',
            '		return 0',
            '	}',
            '',
            '	PresetCycleLastSwitch := now',
            '	PresetCycleActiveSlot := nextSlot',
            '	if !PresetCycleRepeat',
            '		PresetCycleActiveSlot .= "!"',
            '	try IniWrite PresetCycleActiveSlot, "settings\nm_config.ini", "Settings", "PresetCycleActiveSlot"',
            '	try IniWrite PresetCycleLastSwitch, "settings\nm_config.ini", "Settings", "PresetCycleLastSwitch"',
            '	nm_PresetCycleUpdateStateText()',
            '	nm_setStatus("Preset Cycle", "Switched to " presetId)',
            '	lastNotice := ""',
            '	return 1',
            '}'
        )
        cNew := StrReplace(c, 'nm_PresetCycleGUI(*){}', presetCycleDialogBlock)
        if (cNew != c) {
            c := cNew
            FileAppend("? Added preset cycle dialog and helper functions`n", logFile)
        } else {
            FileAppend("! Preset cycle dialog insertion skipped; stub anchor not found`n", logFile)
        }
    } else if InStr(c, 'nm_PresetCycleApplyNow(*) {') {
        FileAppend("? Preset cycle dialog and helper functions already present`n", logFile)
    }
    ; 1c4a. Preset cycle runtime hook
    if !InStr(c, 'nm_PresetCycleTick()') && InStr(c, 'Background(){') && InStr(c, 'nm_setStats()') {
        backgroundNeedle := "`t;stats`r`n`tnm_setStats()"
        backgroundInsert := "`t;stats`r`n`tnm_setStats()`r`n`tnm_PresetCycleTick()"
        cNew := StrReplace(c, backgroundNeedle, backgroundInsert)
        if (cNew != c) {
            c := cNew
            FileAppend("? Added preset cycle runtime hook to Background()`n", logFile)
        } else {
            FileAppend("! Preset cycle runtime hook skipped; background anchor not found`n", logFile)
        }
    } else if InStr(c, 'nm_PresetCycleTick()') {
        FileAppend("? Preset cycle runtime hook already present`n", logFile)
    }
    ; 1c4b. Preset cycle state refresh on macro transitions
    startStateNeedle := JoinLines(
        '	DetectHiddenWindows 1',
        '	MacroState:=2',
        '	if WinExist("Status.ahk ahk_class AutoHotkey")'
    )
    startStateInsert := JoinLines(
        '	DetectHiddenWindows 1',
        '	MacroState:=2',
        '	nm_PresetCycleUpdateStateText()',
        '	if WinExist("Status.ahk ahk_class AutoHotkey")'
    )
    if !InStr(c, 'MacroState:=2`r`n	nm_PresetCycleUpdateStateText()') && InStr(c, startStateNeedle) {
        cNew := StrReplace(c, startStateNeedle, startStateInsert)
        if (cNew != c) {
            c := cNew
            FileAppend("? Added preset cycle state refresh on macro start`n", logFile)
        }
    } else if InStr(c, 'MacroState:=2`r`n	nm_PresetCycleUpdateStateText()') {
        FileAppend("? Preset cycle state refresh on macro start already present`n", logFile)
    }
    pauseStateNeedle := JoinLines(
        '		MacroState:=1',
        '		if WinExist("Status.ahk ahk_class AutoHotkey")'
    )
    pauseStateInsert := JoinLines(
        '		MacroState:=1',
        '		nm_PresetCycleUpdateStateText()',
        '		if WinExist("Status.ahk ahk_class AutoHotkey")'
    )
    if !InStr(c, 'MacroState:=1`r`n		nm_PresetCycleUpdateStateText()') && InStr(c, pauseStateNeedle) {
        cNew := StrReplace(c, pauseStateNeedle, pauseStateInsert)
        if (cNew != c) {
            c := cNew
            FileAppend("? Added preset cycle state refresh on macro pause`n", logFile)
        }
    } else if InStr(c, 'MacroState:=1`r`n		nm_PresetCycleUpdateStateText()') {
        FileAppend("? Preset cycle state refresh on macro pause already present`n", logFile)
    }
    stopStateNeedle := JoinLines(
        '	DetectHiddenWindows 1',
        '	MacroState:=0',
        '	Reload'
    )
    stopStateInsert := JoinLines(
        '	DetectHiddenWindows 1',
        '	MacroState:=0',
        '	nm_PresetCycleUpdateStateText()',
        '	Reload'
    )
    if !InStr(c, 'MacroState:=0`r`n	nm_PresetCycleUpdateStateText()') && InStr(c, stopStateNeedle) {
        cNew := StrReplace(c, stopStateNeedle, stopStateInsert)
        if (cNew != c) {
            c := cNew
            FileAppend("? Added preset cycle state refresh on macro stop`n", logFile)
        }
    } else if InStr(c, 'MacroState:=0`r`n	nm_PresetCycleUpdateStateText()') {
        FileAppend("? Preset cycle state refresh on macro stop already present`n", logFile)
    }
    ; 1c5. StatMonitor booster stats bundle
    if (patchForceHourly || patchStatMonitorTheme) {
        if !InStr(c, '"TotalPineTree"') && InStr(c, 'config["Status"] := Map(') {
            statusNeedle := JoinLines(
                '		, "TotalDisconnects", 0',
                '		, "SessionDisconnects", 0',
                '		, "DiscordMode", 0'
            )
            statusInsert := JoinLines(
                '		, "TotalDisconnects", 0',
                '		, "SessionDisconnects", 0',
                '		, "TotalPineTree", 0',
                '		, "SessionPineTree", 0',
                '		, "TotalBlueFlower", 0',
                '		, "SessionBlueFlower", 0',
                '		, "TotalBamboo", 0',
                '		, "SessionBamboo", 0',
                '		, "DiscordMode", 0'
            )
            cNew := StrReplace(c, statusNeedle, statusInsert)
            if (cNew != c) {
                c := cNew
                FileAppend("? Added booster stat defaults to config['Status']`n", logFile)
            }
        }
            resetNeedle := JoinLines(
                '	IniWrite TotalDisconnects:=0, "settings\nm_config.ini", "Status", "TotalDisconnects"',
                '	nm_setStats()'
            )
            resetInsert := JoinLines(
                '	IniWrite TotalDisconnects:=0, "settings\nm_config.ini", "Status", "TotalDisconnects"',
                '	IniWrite TotalPineTree:=0, "settings\nm_config.ini", "Status", "TotalPineTree"',
                '	IniWrite TotalBlueFlower:=0, "settings\nm_config.ini", "Status", "TotalBlueFlower"',
                '	IniWrite TotalBamboo:=0, "settings\nm_config.ini", "Status", "TotalBamboo"',
                '	nm_setStats()'
            )
            cNew := StrReplace(c, resetNeedle, resetInsert)
            if (cNew != c) {
                c := cNew
                FileAppend("? Added booster stat reset defaults to nm_ResetTotalStats()`n", logFile)
            }

            sessionResetNeedle := JoinLines(
                '	IniWrite SessionDisconnects:=0, "settings\nm_config.ini", "Status", "SessionDisconnects"',
                '	nm_setStats()'
            )
            sessionResetInsert := JoinLines(
                '	IniWrite SessionDisconnects:=0, "settings\nm_config.ini", "Status", "SessionDisconnects"',
                '	IniWrite SessionPineTree:=0, "settings\nm_config.ini", "Status", "SessionPineTree"',
                '	IniWrite SessionBlueFlower:=0, "settings\nm_config.ini", "Status", "SessionBlueFlower"',
                '	IniWrite SessionBamboo:=0, "settings\nm_config.ini", "Status", "SessionBamboo"',
                '	nm_setStats()'
            )
            cNew := StrReplace(c, sessionResetNeedle, sessionResetInsert)
            if (cNew != c) {
                c := cNew
                FileAppend("? Added booster stat reset defaults to nm_ResetSessionStats()`n", logFile)
            }

            statNeedle := JoinLines(
                '		PlantersCollected=" TotalPlantersCollected "',
                '		QuestsComplete=" TotalQuestsComplete "',
                '		Disconnects=" TotalDisconnects'
            )
            statInsert := JoinLines(
                '		PlantersCollected=" TotalPlantersCollected "',
                '		QuestsComplete=" TotalQuestsComplete "',
                '		Disconnects=" TotalDisconnects "',
                '		PineTree=" TotalPineTree "',
                '		BlueFlower=" TotalBlueFlower "',
                '		Bamboo=" TotalBamboo'
            )
            cNew := StrReplace(c, statNeedle, statInsert)
            if (cNew != c) {
                c := cNew
                FileAppend("? Added booster stats to TotalStatsString`n", logFile)
            }

            sessionStatNeedle := JoinLines(
                '		PlantersCollected=" SessionPlantersCollected "',
                '		QuestsComplete=" SessionQuestsComplete "',
                '		Disconnects=" SessionDisconnects'
            )
            sessionStatInsert := JoinLines(
                '		PlantersCollected=" SessionPlantersCollected "',
                '		QuestsComplete=" SessionQuestsComplete "',
                '		Disconnects=" SessionDisconnects "',
                '		PineTree=" SessionPineTree "',
                '		BlueFlower=" SessionBlueFlower "',
                '		Bamboo=" SessionBamboo'
            )
            cNew := StrReplace(c, sessionStatNeedle, sessionStatInsert)
            if (cNew != c) {
                c := cNew
                FileAppend("? Added booster stats to SessionStatsString`n", logFile)
            }

            incrementNeedle := JoinLines(
                '`t, TotalDisconnects, SessionDisconnects',
                '`tStatEnum := Map("BossKills",1',
                '`t	,"ViciousKills",2',
                '`t	,"BugKills",3',
                '`t	,"Planters",4',
                '`t	,"QuestsDone",5',
                '`t	,"Disconnects",6'
            )
            incrementInsert := JoinLines(
                '`t, TotalDisconnects, SessionDisconnects',
                '`t, TotalPineTree, SessionPineTree',
                '`t, TotalBlueFlower, SessionBlueFlower',
                '`t, TotalBamboo, SessionBamboo',
                '`tStatEnum := Map("BossKills",1',
                '`t	,"ViciousKills",2',
                '`t	,"BugKills",3',
                '`t	,"Planters",4',
                '`t	,"QuestsDone",5',
                '`t	,"Disconnects",6',
                '`t	,"PineTree",7',
                '`t	,"BlueFlower",8',
                '`t	,"Bamboo",9'
            )
            cNew := StrReplace(c, incrementNeedle, incrementInsert)
            if (cNew != c) {
                c := cNew
                FileAppend("? Added booster stat globals and enum entries to nm_IncrementStat()`n", logFile)
            }
        }
    ; 1c4. BFB interrupt config defaults
    if (patchBfb) {
    if !InStr(c, '"BlueBoosterInterruptCheck"') {
        configPattern := 'm)^(\s*, "CoconutBoosterCheck", [^\r\n]+)$'
        configReplacement := '$1`r`n`t`t, "BlueBoosterInterruptCheck", 1`r`n`t`t, "LastBlueBoostUse", 1`r`n`t`t, "BlueBoostCheck", 1'
        cNew := RegExReplace(c, configPattern, configReplacement, &bfbConfigCount, 1)
        if (bfbConfigCount > 0 && cNew != c) {
            c := cNew
            FileAppend("? Added BFB interrupt config defaults to natro_macro.ahk`n", logFile)
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
            FileAppend("? Added Sticker Stack interrupt config defaults to natro_macro.ahk`n", logFile)
        }
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
            FileAppend("? Added BFB toggle handler`n", logFile)
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
            FileAppend("? Added Sticker Stack interrupt toggle handler`n", logFile)
        }
    }
    }

    ; 1c8. Sticker Stack interrupt functions
    if (patchStickerStack) {
    if !InStr(c, 'OnMessage(0x5564, nm_ForceStickerStack, 255)') && InStr(c, 'OnMessage(0x5560, nm_copyDebugLog)') {
        cNew := StrReplace(c, 'OnMessage(0x5560, nm_copyDebugLog)', 'OnMessage(0x5560, nm_copyDebugLog)`r`nOnMessage(0x5564, nm_ForceStickerStack, 255)')
        if (cNew != c) {
            c := cNew
            FileAppend("? Added Force Sticker Stack message hook to natro_macro.ahk`n", logFile)
        }
    }
    if !InStr(c, 'nm_ForceStickerStack(wParam := 1, *){') && InStr(c, 'nm_ForceReconnect(wParam, lParam := 0, *){') {
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
            'nm_ForceReconnect(wParam, lParam := 0, *){'
        )
        cNew := StrReplace(c, 'nm_ForceReconnect(wParam, lParam := 0, *){', forceStickerHandler)
        if (cNew != c) {
            c := cNew
            FileAppend("? Added Force Sticker Stack handler to natro_macro.ahk`n", logFile)
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
            FileAppend("? Added Force Blue Field Booster message hook to natro_macro.ahk`n", logFile)
        }
    }
    if !InStr(c, 'nm_ForceBlueBooster(wParam := 1, *){') && InStr(c, 'nm_ForceReconnect(wParam, lParam := 0, *){') {
        forceBfbHandler := JoinLines(
            'nm_ForceBlueBooster(wParam := 1, *){',
            '`tCritical',
            '`tglobal ForceBlueBoosterInterrupt',
            '`tForceBlueBoosterInterrupt := (wParam != 0)',
            '`treturn 0',
            '}',
            '',
            'nm_ForceReconnect(wParam, lParam := 0, *){'
        )
        cNew := StrReplace(c, 'nm_ForceReconnect(wParam, lParam := 0, *){', forceBfbHandler)
        if (cNew != c) {
            c := cNew
            FileAppend("? Added Force Blue Field Booster handler to natro_macro.ahk`n", logFile)
        }
    }
    cNew := c
    cNew := StrReplace(cNew, 'global BlueBoosterInterruptCheck, LastBlueBoostUse', 'global BlueBoosterInterruptCheck, LastBlueBoostUse, ForceBlueBoosterInterrupt')
    cNew := StrReplace(cNew, 'if (!BlueBoosterInterruptCheck)`r`n`t`treturn 0', 'if (ForceBlueBoosterInterrupt)`r`n`t`treturn 1`r`n`tif (!BlueBoosterInterruptCheck)`r`n`t`treturn 0')
    if (cNew != c) {
        c := cNew
        FileAppend("? Updated nm_BlueBoosterInterrupt() to support forced trigger`n", logFile)
    }
    }
    if !InStr(c, 'nm_StickerStackInterrupt() {') {
        stickerInterruptFuncNeedle := InStr(c, 'nm_BlueBoosterInterrupt() {') ? 'nm_BlueBoosterInterrupt() {' : ';stats/status'
        stickerInterruptFuncInsert := ReadPatchBlock(patchTemplateDir "\\stickerstack_interrupt_patch.txt")
        cNew := StrReplace(c, stickerInterruptFuncNeedle, stickerInterruptFuncInsert)
        if (cNew != c) {
            c := cNew
            FileAppend("? Added Sticker Stack interrupt helper functions`n", logFile)
        }
    }
    if !InStr(c, 'ToolTip "Sticker Stack: FORCED", 0, 0, 2') && InStr(c, '`tglobal MainGui, LastStickerStack, LastStickerStackUse, StickerStackTimer, StickerStackCheck') {
        cNew := StrReplace(c, '`tglobal MainGui, LastStickerStack, LastStickerStackUse, StickerStackTimer, StickerStackCheck', '`tglobal MainGui, LastStickerStack, LastStickerStackUse, StickerStackTimer, StickerStackCheck, ForceStickerStackInterrupt')
        if (cNew != c) {
            c := cNew
            FileAppend("? Added Force Sticker Stack global to nm_StickerStackInterrupt()`n", logFile)
        }
        cNew := StrReplace(c, 'nm_StickerStackInterrupt() {`r`n`tglobal MainGui, LastStickerStack, LastStickerStackUse, StickerStackTimer, StickerStackCheck, ForceStickerStackInterrupt`r`n`tif (LastStickerStack = 0) {', 'nm_StickerStackInterrupt() {`r`n`tglobal MainGui, LastStickerStack, LastStickerStackUse, StickerStackTimer, StickerStackCheck, ForceStickerStackInterrupt`r`n`tif (ForceStickerStackInterrupt) {`r`n`t`tToolTip "Sticker Stack: FORCED", 0, 0, 2`r`n`t`tif (!StickerStackCheck || !MainGui["StickerStackInterruptCheck"].Value)`r`n`t`t`treturn 0`r`n`t`treturn 1`r`n`t}`r`n`tif (LastStickerStack = 0) {')
        if (cNew != c) {
            c := cNew
            FileAppend("? Added forced Sticker Stack test branch to nm_StickerStackInterrupt()`n", logFile)
        }
    }
    if !InStr(c, 'ForceStickerStackInterrupt := 0') && InStr(c, '`tglobal LastStickerStackUse, LastGlitter, GatherFieldBoostedStart, GlitterKey, fieldOverrideReason, PFieldBoosted') {
        cNew := StrReplace(c, '`tglobal LastStickerStackUse, LastGlitter, GatherFieldBoostedStart, GlitterKey, fieldOverrideReason, PFieldBoosted', '`tglobal LastStickerStackUse, LastGlitter, GatherFieldBoostedStart, GlitterKey, fieldOverrideReason, PFieldBoosted, ForceStickerStackInterrupt')
        if (cNew != c) {
            c := cNew
            FileAppend("? Added Force Sticker Stack global to handler`n", logFile)
        }
        cNew := StrReplace(c, '`tnm_StickerStack(resetBeforeStack)`r`n`tnm_setStatus("Traveling", "Returning to Hive post-Stack")', '`tnm_StickerStack(resetBeforeStack)`r`n`tForceStickerStackInterrupt := 0`r`n`tnm_setStatus("Traveling", "Returning to Hive post-Stack")')
        if (cNew != c) {
            c := cNew
            FileAppend("? Moved Force Sticker Stack reset to after stack attempt`n", logFile)
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
        FileAppend("? Upgraded existing Sticker Stack resume block in-place`n", logFile)
    }
    canonicalStickerHandler := ReadPatchBlock(patchTemplateDir "\\stickerstack_interrupt_patch.txt")
    if RegExMatch(c, '(?ms)^nm_HandleStickerStackInterrupt\(convertAfter := 1, allowEmergencyGlitter := 0, resetBeforeStack := 1(?:, requireInterruptToggle := 1)?\) \{.*?^\}\r?\n(?:\r?\n)?(?=nm_BlueBoosterInterrupt\(\) \{)', &stickerHandleMatch) {
        desiredStickerHandler := canonicalStickerHandler "`r`n`r`n"
        if (stickerHandleMatch[0] != desiredStickerHandler) {
            c := StrReplace(c, stickerHandleMatch[0], desiredStickerHandler)
            FileAppend("? Normalized Sticker Stack handler to reset-findhive-convert flow`n", logFile)
        }
    }
    handlerStart := InStr(c, 'nm_HandleStickerStackInterrupt(convertAfter := 1, allowEmergencyGlitter := 0, resetBeforeStack := 1, requireInterruptToggle := 1) {')
    if (!handlerStart)
        handlerStart := InStr(c, 'nm_HandleStickerStackInterrupt(convertAfter := 1, allowEmergencyGlitter := 0, resetBeforeStack := 1) {')
    if (handlerStart) {
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
                FileAppend("? Force-normalized Sticker Stack handler block`n", logFile)
            }
        }
    }
    }

    ; 1c9. BFB interrupt function
    if (patchBfb) {
        canonicalBlueBoosterInterrupt := JoinLines(
            'nm_BlueBoosterInterrupt() {',
            '`tglobal BlueBoosterInterruptCheck, LastBlueBoostUse, ForceBlueBoosterInterrupt',
            '`tif (ForceBlueBoosterInterrupt) {',
            '`t`tToolTip "BFB: FORCED", 0, 15',
            '`t`tif (!BlueBoosterInterruptCheck)',
            '`t`t`treturn 0',
            '`t`treturn 1',
            '`t}',
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
            '}'
        )
        canonicalBlueBoosterInterruptWithGap := canonicalBlueBoosterInterrupt "`r`n`r`n"
        if RegExMatch(c, '(?ms)^nm_BlueBoosterInterrupt\(\) \{.*?^\}\r?\n(?:\r?\n)?', &bfbMatch) {
            if (bfbMatch[0] != canonicalBlueBoosterInterruptWithGap) {
                c := StrReplace(c, bfbMatch[0], canonicalBlueBoosterInterruptWithGap)
                FileAppend("? Normalized nm_BlueBoosterInterrupt() helper block`n", logFile)
            }
        } else {
            cNew := c
            for _, anchor in ['nm_StickerStackInterruptEnabled() {', '; BOOST LEASE HELPERS START', 'nm_ShouldUsePinePreGlitter(fieldName, field_type){', ';stats/status', 'nm_ForceBlueBooster(wParam := 1, *){', 'nm_ForceReconnect(wParam, lParam := 0, *){'] {
                if InStr(c, anchor) {
                    cNew := StrReplace(c, anchor, canonicalBlueBoosterInterruptWithGap anchor)
                    break
                }
            }
            if (cNew != c) {
                c := cNew
                FileAppend("? Added nm_BlueBoosterInterrupt() function`n", logFile)
            }
        }
    }

    ; 1c10. BFB timer wiring in nm_toBooster()
    cNew := RegExReplace(c
        , '(?m)^\tglobal LastBlueBoost, LastRedBoost, LastMountainBoost, LastCoconutDis, RecentFBoost(?:, LastBlueBoostUse)?(?:, ForceBlueBoosterInterrupt)?(?:, GatherFieldBoostedStart)?(?:, CurrentField)?(?:, LastBlueBoostUse)?(?:, ForceBlueBoosterInterrupt)?(?:, GatherFieldBoostedStart)?(?:, CurrentField)?(?:, LastBlueBoostUse)?(?:, ForceBlueBoosterInterrupt)?(?:, GatherFieldBoostedStart)?(?:, CurrentField)?$'
        , '`tglobal LastBlueBoost, LastRedBoost, LastMountainBoost, LastCoconutDis, RecentFBoost, LastBlueBoostUse, ForceBlueBoosterInterrupt, GatherFieldBoostedStart, CurrentField'
        , &count
        , 1
    )
    if (count > 0 && cNew != c) {
        c := cNew
        FileAppend("? Normalized nm_toBooster() globals for BFB timer wiring`n", logFile)
    }
    if !InStr(c, 'LastBlueBoostUse := nowUnix()') {
        boosterSuccessNeedle := '			Last%location%Boost:=nowUnix(), IniWrite(Last%location%Boost, "settings\nm_config.ini", "Collect", "Last" location "Boost")'
        boosterSuccessInsert := JoinLines(
            '			Last%location%Boost:=nowUnix(), IniWrite(Last%location%Boost, "settings\nm_config.ini", "Collect", "Last" location "Boost")',
            '			if (location = "blue") {',
            '				LastBlueBoostUse := nowUnix()',
            '				IniWrite LastBlueBoostUse, "settings\nm_config.ini", "Boost", "LastBlueBoostUse"',
            '				GatherFieldBoostedStart := LastBlueBoostUse',
            '				IniWrite CurrentField, "settings\nm_config.ini", "Boost", "LastBoostedField"',
            '				IniWrite GatherFieldBoostedStart, "settings\nm_config.ini", "Boost", "LastBoostedTime"',
            '			}'
        )
        cNew := StrReplace(c, boosterSuccessNeedle, boosterSuccessInsert)
        if (cNew != c) {
            c := cNew
            FileAppend("? Added BFB success timer update in nm_toBooster()`n", logFile)
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
            FileAppend("? Added BFB cooldown repair in nm_toBooster()`n", logFile)
        }
    }
    cNew := RegExReplace(c, 'Last%location%Boost\s*:=\s*\(location = "blue"\) \? nowUnix\(\) - 900 : nowUnix\(\) - 1500', 'Last%location%Boost := (location = "blue") ? nowUnix() - 900 : nowUnix() - 3600')
    if (cNew != c) {
        c := cNew
        FileAppend("? Restored non-blue booster cooldown backdate to Baspas timing`n", logFile)
    }
    cNew := RegExReplace(c, '(?<!\w)(?:adsync_RequestHiveStandby\(\)|t{2,}adsync_RequestHiveStandby\(\)|[A-Za-z_][A-Za-z0-9_]*adsync_RequestHiveStandby\(\))', 'tadsync_RequestHiveStandby()', &count)
    if (count > 0) {
        c := cNew
        FileAppend("? Fixed malformed TadSync hive-standby hook in nm_toBooster()`n", logFile)
    }
    if (boosterPos := InStr(c, 'nm_toBooster(location){')) {
        boosterHead := SubStr(c, boosterPos, 600)
        if !InStr(boosterHead, 'tadsync_RequestHiveStandby()') {
            pattern := '(nm_toBooster\(location\)\{\r?\n\s*global [^\r\n]*\r?\n\s*static [^\r\n]*\r?\n)'
            cNew := RegExReplace(c, pattern, '$1`tadsync_RequestHiveStandby()`r`n', &count, 1)
            if (count > 0) {
                c := cNew
                FileAppend("? Added TadSync hive-standby request before booster travel`n", logFile)
            }
        }
        if !InStr(boosterHead, 'ForceBlueBoosterInterrupt := 0') && InStr(boosterHead, 'tadsync_RequestHiveStandby()') {
            cNew := StrReplace(c, 'tadsync_RequestHiveStandby()`r`n', 'tadsync_RequestHiveStandby()`r`n`tif (location = "blue")`r`n`t`tForceBlueBoosterInterrupt := 0`r`n')
            if (cNew != c) {
                c := cNew
                FileAppend("? Added blue BFB reset to nm_toBooster()`n", logFile)
            }
        }
    }
    introPattern := '(?ms)(nm_toBooster\(location\)\{\r?\n\s*global [^\r\n]*\r?\n\s*static [^\r\n]*\r?\n)(?:\s*tadsync_RequestHiveStandby\(\)\r?\n(?:\s*if \(location = "blue"\)\r?\n\s*ForceBlueBoosterInterrupt := 0\r?\n)?)?\s*Loop 2 \{'
    introReplace := '$1`tadsync_RequestHiveStandby()`r`n`tif (location = "blue")`r`n`t`tForceBlueBoosterInterrupt := 0`r`n`r`n`tLoop 2 {'
    cNew := RegExReplace(c, introPattern, introReplace, &count, 1)
    if (count > 0 && cNew != c) {
        c := cNew
        FileAppend("? Canonicalized nm_toBooster() intro block`n", logFile)
    }
    boosterIntroPattern := '(?ms)^nm_toBooster\(location\)\{\r?\n.*?^\tLoop 2 \{'
    boosterIntroReplacement := JoinLines(
        'nm_toBooster(location){',
        '`tglobal LastBlueBoost, LastRedBoost, LastMountainBoost, LastCoconutDis, RecentFBoost, LastBlueBoostUse, ForceBlueBoosterInterrupt, GatherFieldBoostedStart, CurrentField',
        '`tstatic blueBoosterFields:=["Pine Tree", "Bamboo", "Blue Flower", "Stump"], redBoosterFields:=["Rose", "Strawberry", "Mushroom", "Pepper"], mountainBoosterfields:=["Cactus", "Pumpkin", "Pineapple", "Spider", "Clover", "Dandelion", "Sunflower"], coconutBoosterfields:=["Coconut"]',
        '`ttadsync_RequestHiveStandby()',
        '`tif (location = "blue")',
        '`t`tForceBlueBoosterInterrupt := 0',
        '',
        '`tLoop 2 {'
    )
    cNew := RegExReplace(c, boosterIntroPattern, boosterIntroReplacement, &count, 1)
    if (count > 0 && cNew != c) {
        c := cNew
        FileAppend("? Rebuilt canonical nm_toBooster() intro block`n", logFile)
    }
    boosterIntroNeedle := JoinLines(
        'nm_toBooster(location){',
        '`tglobal LastBlueBoost, LastRedBoost, LastMountainBoost, LastCoconutDis, RecentFBoost',
        '`tstatic blueBoosterFields:=["Pine Tree", "Bamboo", "Blue Flower", "Stump"], redBoosterFields:=["Rose", "Strawberry", "Mushroom", "Pepper"], mountainBoosterfields:=["Cactus", "Pumpkin", "Pineapple", "Spider", "Clover", "Dandelion", "Sunflower"], coconutBoosterfields:=["Coconut"]',
        '',
        '`tLoop 2 {'
    )
    boosterIntroReplace := JoinLines(
        'nm_toBooster(location){',
        '`tglobal LastBlueBoost, LastRedBoost, LastMountainBoost, LastCoconutDis, RecentFBoost, LastBlueBoostUse, ForceBlueBoosterInterrupt, GatherFieldBoostedStart, CurrentField',
        '`tstatic blueBoosterFields:=["Pine Tree", "Bamboo", "Blue Flower", "Stump"], redBoosterFields:=["Rose", "Strawberry", "Mushroom", "Pepper"], mountainBoosterfields:=["Cactus", "Pumpkin", "Pineapple", "Spider", "Clover", "Dandelion", "Sunflower"], coconutBoosterfields:=["Coconut"]',
        '`ttadsync_RequestHiveStandby()',
        '`tif (location = "blue")',
        '`t`tForceBlueBoosterInterrupt := 0',
        '',
        '`tLoop 2 {'
    )
    cNew := StrReplace(c, boosterIntroNeedle, boosterIntroReplace)
    if (cNew != c) {
        c := cNew
        FileAppend("? Rewrote nm_toBooster() intro via literal block replace`n", logFile)
    }
    }

    ; 1c11. Sticker Stack reset behavior should depend on call site
    if (patchStickerStack) {
    if !InStr(c, 'nm_StickerStack(resetBeforeTravel := 1){') && InStr(c, 'nm_StickerStack(){') {
        cNew := StrReplace(c, 'nm_StickerStack(){', 'nm_StickerStack(resetBeforeTravel := 1){')
        if (cNew != c) {
            c := cNew
            FileAppend("? Added resetBeforeTravel parameter to nm_StickerStack()`n", logFile)
        }
    }
    if !InStr(c, 'ForceStickerStackInterrupt') && InStr(c, 'global StickerStackCheck, LastStickerStack, StickerStackItem, StickerStackMode, StickerStackTimer, StickerStackHive, StickerStackCub, StickerStackVoucher, SC_E, bitmaps') {
        cNew := StrReplace(c, 'global StickerStackCheck, LastStickerStack, StickerStackItem, StickerStackMode, StickerStackTimer, StickerStackHive, StickerStackCub, StickerStackVoucher, SC_E, bitmaps', 'global StickerStackCheck, LastStickerStack, StickerStackItem, StickerStackMode, StickerStackTimer, StickerStackHive, StickerStackCub, StickerStackVoucher, ForceStickerStackInterrupt, SC_E, bitmaps')
        if (cNew != c) {
            c := cNew
            FileAppend("? Added Force Sticker Stack global in nm_StickerStack()`n", logFile)
        }
    }
    if !InStr(c, 'forceAllowed := ForceStickerStackInterrupt && (StickerStackCheck = 1)') {
        cNew := StrReplace(c, 'if (StickerStackCheck && (nowUnix()-LastStickerStack)>StickerStackTimer) {', 'forceAllowed := ForceStickerStackInterrupt && (StickerStackCheck = 1) && (IsSet(MainGui) && IsObject(MainGui) ? (MainGui["StickerStackInterruptCheck"].Value = 1) : 0)`r`n`tif ((forceAllowed || StickerStackCheck) && (forceAllowed || (nowUnix()-LastStickerStack)>StickerStackTimer)) {')
        if (cNew != c) {
            c := cNew
            FileAppend("? Hardened forced Sticker Stack travel gate to respect both toggles`n", logFile)
        }
    }
    if !InStr(c, 'if (resetBeforeTravel)') && InStr(c, 'nm_StickerStack(resetBeforeTravel := 1){') {
        stickerResetPattern := '(?ms)(nm_StickerStack\(resetBeforeTravel := 1\)\{\r?\n.*?loop \d+ \{\r?\n)(\s*)nm_Reset\(1, 2000, 0\)'
        stickerResetReplace := '$1$2if (resetBeforeTravel)`r`n$2`tnm_Reset(1, 2000, 0)'
        cNew := RegExReplace(c, stickerResetPattern, stickerResetReplace, &stickerResetCount, 1)
        if (stickerResetCount > 0 && cNew != c) {
            c := cNew
            FileAppend("? Made nm_StickerStack() reset conditional on call site`n", logFile)
        }
    }
    if !InStr(c, 'global SkipBoostStickerStackUntil:=0') && InStr(c, 'global ConvertGatherFlag:=0') {
        cNew := StrReplace(c, 'global ConvertGatherFlag:=0', 'global ConvertGatherFlag:=0`r`n`tglobal SkipBoostStickerStackUntil:=0')
        if (cNew != c) {
            c := cNew
            FileAppend("? Added post-interrupt Sticker Stack boost suppression timer`n", logFile)
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
            FileAppend("? Normalized nm_Boost() Sticker Stack suppression flow`n", logFile)
        }
    }
    canonicalStickerStack := ReadPatchBlock(patchTemplateDir "\stickerstack_full_patch.txt")
    if (canonicalStickerStack = "") {
        FileAppend("? Skipped Sticker Stack sync because patch_templates\\stickerstack_full_patch.txt is missing`n", logFile)
    } else if RegExMatch(c, '(?ms)^nm_StickerStack\(resetBeforeTravel := 1\)\{.*?^\}\r?\n(?=nm_shrine\(\)\{)', &stickerStackMatch) {
        desiredStickerStack := canonicalStickerStack "`r`n"
        if (stickerStackMatch[0] != desiredStickerStack) {
            c := StrReplace(c, stickerStackMatch[0], desiredStickerStack)
            FileAppend("? Normalized nm_StickerStack() to stack-first retry flow`n", logFile)
        }
    }

    ; 1c12. Route reset-time conversion through the Sticker Stack helper first
    if !InStr(c, 'if !nm_HandleStickerStackInterrupt(1, 0, 0)') {
        resetConvertPattern := 'm)^(\s*)\(convert=1\)\s*&&\s*nm_convert\(\)\s*$'
        resetConvertReplace := '$1if (convert=1) {`r`n$1`tif !nm_HandleStickerStackInterrupt(1, 0, 0)`r`n$1`t`tnm_convert()`r`n$1}'
        cNew := RegExReplace(c, resetConvertPattern, resetConvertReplace, &resetConvertCount, 1)
        if (resetConvertCount > 0 && cNew != c) {
            c := cNew
            FileAppend("? Routed nm_Reset() conversion through Sticker Stack helper`n", logFile)
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
                    FileAppend("✓ Added global variables in nm_GoGather`n", logFile)
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
goGatherGlobalsPattern := '(\s*, BoostChaserCheck, LastBlueBoost, LastRedBoost, LastMountainBoost, FieldBooster3, FieldBooster2, FieldBooster1, FieldDefault(?:, BlueBoosterInterruptCheck, LastBlueBoostUse)?)(, LastMicroConverter, HiveConfirmed)'
            cNew := RegExReplace(c, goGatherGlobalsPattern, '$1, BlueBoosterInterruptCheck, LastBlueBoostUse$2', &goGatherGlobalsCount, 1)
            if (goGatherGlobalsCount > 0 && cNew != c) {
                c := cNew
                FileAppend("? Added BFB globals in nm_GoGather()`n", logFile)
            }
        }
        if !InStr(goGatherHead, 'StickerStackInterruptCheck') {
stickerGoGatherGlobalsPattern := '(\s*, BoostChaserCheck, LastBlueBoost, LastRedBoost, LastMountainBoost, FieldBooster3, FieldBooster2, FieldBooster1, FieldDefault(?:, BlueBoosterInterruptCheck, LastBlueBoostUse)?)(, LastMicroConverter, HiveConfirmed)'
            cNew := RegExReplace(c, stickerGoGatherGlobalsPattern, '$1, LastStickerStackUse, StickerStackTimer, StickerStackCheck, StickerStackInterruptCheck$2', &stickerGoGatherGlobalsCount, 1)
            if (stickerGoGatherGlobalsCount > 0 && cNew != c) {
                c := cNew
                FileAppend("? Added Sticker Stack globals in nm_GoGather()`n", logFile)
            }
        }
    }
    }
    if (goGatherPos := InStr(c, 'nm_GoGather(){')) {
        goGatherHead := SubStr(c, goGatherPos, 800)
        if !InStr(goGatherHead, 'nm_HandleStickerStackInterrupt(1, 0, 1)') {
            preStackPattern := '(?m)(^\tif nm_MondoInterrupt\(\)\r?\n^\t\treturn\r?\n)(?!^\tif nm_HandleStickerStackInterrupt\(1, 0, 1\)\r?\n^\t\treturn)'
            preStackInsert := '$1`tif mondointerrupt_ShouldTrigger() {`r`n`t`tmondointerrupt_Handle()`r`n`t`treturn`r`n`t}`r`n`tif nm_HandleStickerStackInterrupt(1, 0, 1)`r`n`t`treturn`r`n'
            cNew := RegExReplace(c, preStackPattern, preStackInsert, &preStackCount, 1)
            if (preStackCount > 0 && cNew != c) {
                c := cNew
                FileAppend("? Added immediate Mondo then Sticker Stack handling in nm_GoGather()`n", logFile)
            }
        }
    }
    malformedGoGatherMondoStack := JoinLines(
        '	if mondointerrupt_ShouldTrigger() {',
        '		mondointerrupt_Handle()',
        '		return',
        '	if nm_HandleStickerStackInterrupt(1, 0, 1)',
        '		return'
    )
    fixedGoGatherMondoStack := JoinLines(
        '	if mondointerrupt_ShouldTrigger() {',
        '		mondointerrupt_Handle()',
        '		return',
        '	}',
        '	if nm_HandleStickerStackInterrupt(1, 0, 1)',
        '		return'
    )
    cNew := StrReplace(c, malformedGoGatherMondoStack, fixedGoGatherMondoStack)
    if (cNew != c) {
        c := cNew
        FileAppend("? Repaired malformed Mondo/Sticker Stack guard in nm_GoGather()`n", logFile)
    }
    if !InStr(c, 'nm_toBooster("blue")`r`n`t`treturn') {
        preBfbPattern := '(?m)(^\tif nm_MondoInterrupt\(\)\r?\n^\t\treturn\r?\n)(?!^\tif nm_BlueBoosterInterrupt\(\) \{)'
        preBfbInsert := '$1`tif mondointerrupt_ShouldTrigger() {`r`n`t`tmondointerrupt_Handle()`r`n`t`treturn`r`n`t}`r`n`tif nm_BlueBoosterInterrupt() {`r`n`t`tnm_toBooster("blue")`r`n`t`treturn`r`n`t}`r`n'
        cNew := RegExReplace(c, preBfbPattern, preBfbInsert, &preBfbCount, 1)
        if (preBfbCount > 0 && cNew != c) {
            c := cNew
            FileAppend("? Added immediate Mondo then BFB jump in nm_GoGather()`n", logFile)
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
        '	if mondointerrupt_ShouldTrigger() {',
        '		mondointerrupt_Handle()',
        '		return',
        '	}',
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
        FileAppend("? Normalized Sticker Stack before BFB in nm_GoGather()`n", logFile)
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
            FileAppend("? Added high-priority BFB gather interrupt`n", logFile)
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
        '					nm_HandleStickerStackInterrupt(1, 1, 1)',
        '					return',
        '				}'
    )
    cNew := StrReplace(c, stackGatherOld, stackGatherNew)
    if (cNew != c) {
        c := cNew
        FileAppend("? Upgraded gather Sticker Stack interrupt to immediate reset handling`n", logFile)
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
            FileAppend("? Added high-priority Sticker Stack gather reset path`n", logFile)
        }
    }
    gatherHighBad := JoinLines(
        '				if nm_BlueBoosterInterrupt() {',
        '					interruptReason := "Blue Booster Ready"',
        '					break',
        '				}',
        '				if nm_StickerStackInterrupt() {',
        '					nm_HandleStickerStackInterrupt(1, 1, 1)',
        '					return',
        '				}'
    )
    gatherHighGood := JoinLines(
        '				if mondointerrupt_ShouldTrigger() {',
        '					nm_MondoGatherInterruptCleanup()',
        '					mondointerrupt_Handle()',
        '					return',
        '				}',
        '				if nm_StickerStackInterrupt() {',
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
        FileAppend("? Normalized Sticker Stack before BFB in gather interrupts`n", logFile)
    }
    mondoGatherOld := JoinLines(
        "`t`t`t`t;mondo",
        "`t`t`t`tif nm_MondoInterrupt(){",
        "`t`t`t`t`tinterruptReason := " Chr(34) "Mondo" Chr(34),
        "`t`t`t`t`tif (PMondoGuidComplete)",
        "`t`t`t`t`t`tPMondoGuidComplete:=0",
        "`t`t`t`t`tbreak",
        "`t`t`t`t}"
    )
    mondoGatherNew := JoinLines(
        "`t`t`t`t;mondo",
        "`t`t`t`tif nm_MondoInterrupt(){",
        "`t`t`t`t`tnm_MondoGatherInterruptCleanup()",
        "`t`t`t`t`tmondointerrupt_Handle()",
        "`t`t`t`t`treturn",
        "`t`t`t`t}"
    )
    cNew := StrReplace(c, mondoGatherOld, mondoGatherNew)
    if (cNew != c) {
        c := cNew
        FileAppend("? Normalized gather-loop Mondo interrupt cleanup`n", logFile)
    }
    lowBfbPattern := '(?ms)(^\s*if nm_GatherBoostInterrupt\(\)\r?\n\s*continue\r?\n)(?!\s*if nm_BlueBoosterInterrupt\(\) \{\r?\n\s*interruptReason := "Blue Booster Ready")'
    lowBfbInsert := '$1				if nm_BlueBoosterInterrupt() {`r`n					interruptReason := "Blue Booster Ready"`r`n					break`r`n				}`r`n'
    cNew := RegExReplace(c, lowBfbPattern, lowBfbInsert, &lowBfbCount, 1)
    if (lowBfbCount > 0 && cNew != c) {
        c := cNew
        FileAppend("? Added low-priority BFB gather interrupt`n", logFile)
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
            '`r`n`t`tnm_HandleStickerStackInterrupt(1, 1, 1)'
            '`r`n`t`treturn'
            '`r`n`t}'
            '`r`n'
        )
        cNew := RegExReplace(c, stackSpecialPattern, stackSpecialInsert, &stackSpecialCount, 1)
        if (stackSpecialCount > 0 && cNew != c) {
            c := cNew
            FileAppend("? Added Sticker Stack post-gather handling path`n", logFile)
        }
    }
    cNew := StrReplace(c, 'nm_findHiveSlot(){', 'nm_findHiveSlot(convertAfter := 1, forceBalloonConvert := 0){')
    if (cNew != c) {
        c := cNew
        FileAppend("? Updated nm_findHiveSlot() signature for post-stack resume`n", logFile)
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
        FileAppend("? Routed nm_findHiveSlot() convert through post-stack resume flags`n", logFile)
    }

    if InStr(c, 'MainGui["HBText" i].Text := PFieldBoosted ? "@ Boosted" : "@ Converting Balloon"') {
        c := StrReplace(c, 'MainGui["HBText" i].Text := PFieldBoosted ? "@ Boosted" : "@ Converting Balloon"', 'MainGui["HBText" i].Text := "@ Balloon Convert"')
        FileAppend("? Updated enzyme hotbar label to balloon convert only`n", logFile)
    }

    if InStr(c, 'if(((EnzymesKey!="none") && (!PFieldBoosted || (PFieldBoosted && GatherFieldBoosted))) && (nowUnix()-LastEnzymes)>600 && (inactiveHoney = 0)) {') {
        c := StrReplace(c
            , 'if(((EnzymesKey!="none") && (!PFieldBoosted || (PFieldBoosted && GatherFieldBoosted))) && (nowUnix()-LastEnzymes)>600 && (inactiveHoney = 0)) {'
            , 'if ((EnzymesKey != "none")`r`n`t`t`t`t`t&& (!EnzymesBoostedOnly || nm_GatherBoostInterrupt())`r`n`t`t`t`t`t&& (nowUnix() - LastEnzymes) > 600`r`n`t`t`t`t`t&& (inactiveHoney = 0)) {`r`n`t`t`t`t`tnm_setStatus("Converting", "Balloon``nUsed Enzyme")'
        )
        FileAppend("? Updated enzyme balloon-convert condition to use boost timing`n", logFile)
    }

    if InStr(c, '&& (!EnzymesBoostedOnly || (PFieldBoosted && GatherFieldBoosted))') {
        c := StrReplace(c
            , '&& (!EnzymesBoostedOnly || (PFieldBoosted && GatherFieldBoosted))'
            , '&& (!EnzymesBoostedOnly || nm_GatherBoostInterrupt())'
        )
        FileAppend("? Switched enzyme boosted-only check to nm_GatherBoostInterrupt()`n", logFile)
    }

    ; Convert trace logging: mirror the debug timing breadcrumbs used by the patched copy.
    if !InStr(c, 'nm_ConvertTrace(label, startTick := 0){') {
        convertTraceHelper := JoinLines(
            'nm_ConvertTrace(label, startTick := 0){',
            '`tif (startTick > 0)',
            '`t`tFileAppend(A_Now " [" (A_TickCount - startTick) "ms] " label "``r``n", "settings\debug_log.txt", "UTF-8")',
            '`telse',
            '`t`tFileAppend(A_Now " [" A_TickCount "ms] " label "``r``n", "settings\debug_log.txt", "UTF-8")',
            '}',
            ''
        )
        c := ReplaceFirst(c, 'nm_setSprinkler(field, loc, dist){', convertTraceHelper 'nm_setSprinkler(field, loc, dist){')
    }

    ; 1d3. Mid-convert glitter renewal: travel to field, glitter, walk back
    if !RegExMatch(c, '(?m)^nm_ConvertRenewGlitter\(fieldName\)\s*\{') {
        crf := []
        crf.Push('nm_ConvertRenewGlitter(fieldName) {')
        crf.Push('	global GlitterKey, LastGlitter, GatherFieldBoostedStart, PFieldBoostExtend, fieldOverrideReason, BoostLeaseNearDiscordNotice')
        crf.Push('	if (GlitterKey = "none" || fieldName = "None")')
        crf.Push('		return 0')
        crf.Push('	nm_setStatus("Traveling", "Glitter Renewal -> " fieldName)')
        crf.Push('	nm_gotoField(fieldName)')
        crf.Push('	Sleep 1000')
        crf.Push('	PFieldBoostExtend := 1')
        crf.Push('	LastGlitter := nowUnix()')
        crf.Push('	IniWrite LastGlitter, "settings\nm_config.ini", "Boost", "LastGlitter"')
        crf.Push('	nm_SpamGlitterKey()')
        crf.Push('	nm_DebugGlitterPress("Convert Renewal", fieldName)')
        crf.Push('	nm_RunPendingStickerStackAfterExtend()')
        crf.Push('	Sleep 500')
        crf.Push('	fieldOverrideReason := "Boost"')
        crf.Push('	BoostLeaseNearDiscordNotice := 0')
        crf.Push('	IniWrite fieldName, "settings\nm_config.ini", "Boost", "LastBoostedField"')
        crf.Push('	nm_setStatus("Boosted", "Glitter Renewed - Returning to Convert")')
        crf.Push('	nm_walkFrom(fieldName)')
        crf.Push('	nm_findHiveSlot()')
        crf.Push('	return 1')
        crf.Push('}')
        convertRenewFunc := JoinLines(crf*)
        ; Insert before nm_convert
        convertNeedle := 'nm_convert(ignoreActiveConvertState := 0, forceBalloonConvert := 0){'
        cNew := StrReplace(c, convertNeedle, convertRenewFunc "`r`n`r`n" convertNeedle)
        if (cNew != c) {
            c := cNew
            FileAppend("? Added nm_ConvertRenewGlitter() function`n", logFile)
        }

        ; Replace backpack and balloon convert "Field Boosted" interrupts with the
        ; canonical boost-lease renewal block from the template.
        leaseConvertText := ReadPatchBlock(glitterExtendConvertTemplatePath)
        if (leaseConvertText != "") {
            oldBackpackBoost := JoinLines(
                '			if (PFieldBoosted && (nowUnix()-GatherFieldBoostedStart)>780 && (nowUnix()-GatherFieldBoostedStart)<900 && (nowUnix()-LastGlitter)>900 && GlitterKey!="none") {',
                '				nm_setStatus("Interrupted", "Field Boosted")',
                '				return',
                '			}'
            )
            cNew := StrReplace(c, oldBackpackBoost, leaseConvertText)
            if (cNew != c) {
                c := cNew
                FileAppend("? Replaced backpack convert boost interrupt with glitter renewal`n", logFile)
            }

            oldBalloonBoost := JoinLines(
                '				if ((PFieldBoosted = 1) && (nowUnix()-GatherFieldBoostedStart)>780 && (nowUnix()-GatherFieldBoostedStart)<900 && (nowUnix()-LastGlitter)>900 && GlitterKey!="none") {',
                '					nm_setStatus("Interrupted", "Field Boosted")',
                '					return',
                '				}'
            )
            cNew := StrReplace(c, oldBalloonBoost, leaseConvertText)
            if (cNew != c) {
                c := cNew
                FileAppend("? Replaced balloon convert boost interrupt with glitter renewal`n", logFile)
            }
        }
    }

    ; 1d4. Remove PFieldBoosted 30-min extension from gather loop
    if InStr(c, 'PFieldBoosted && (nowUnix()-GatherFieldBoostedStart)<1800 && (nowUnix()-LastGlitter)<900') {
        cNew := StrReplace(c
            , '|| (PFieldBoosted && (nowUnix()-GatherFieldBoostedStart)<1800 && (nowUnix()-LastGlitter)<900)'
            , ''
        )
        if (cNew != c) {
            c := cNew
            FileAppend("? Removed PFieldBoosted 30-min gather extension`n", logFile)
        }
    }

    ; Keep the gather loop on the field timer, while leaving boost chase state
    ; available for the next rotation instead of extending one session.
    gatherLoopOld := 'while(((nowUnix()-gatherStart)<(FieldUntilMins*60)) || (PFieldBoosted && (nowUnix()-GatherFieldBoostedStart)<840) || (PFieldBoostExtend && (nowUnix()-GatherFieldBoostedStart)<1800 && (nowUnix()-LastGlitter)<900) || (PFieldGuidExtend && FieldGuidDetected && (nowUnix()-gatherStart)<(FieldUntilMins*60+PFieldGuidExtend*60) && (nowUnix()-GatherFieldBoostedStart)>900 && (nowUnix()-LastGlitter)>900) || (PPopStarExtend && HasPopStar && PopStarActive)){'
    gatherLoopNew := 'boostTotalDuration := nm_GetBoostTotalDuration()`r`n	while(((nowUnix()-gatherStart)<(FieldUntilMins*60)) || (PFieldGuidExtend && FieldGuidDetected && (nowUnix()-gatherStart)<(FieldUntilMins*60+PFieldGuidExtend*60) && (nowUnix()-GatherFieldBoostedStart)>boostTotalDuration && (nowUnix()-LastGlitter)>boostTotalDuration) || (PPopStarExtend && HasPopStar && PopStarActive)){'
    cNew := StrReplace(c, gatherLoopOld, gatherLoopNew)
    if (cNew != c) {
        c := cNew
        FileAppend("? Normalized gather loop boost timing to shared duration`n", logFile)
    }

    boostExpiryOld := JoinLines(
        '`t`t`t`t;boost is over',
        '`t`t`t`tif (fieldOverrideReason="Boost" && (nowUnix()-GatherFieldBoostedStart>900) && (nowUnix()-LastGlitter>900)) {',
        '`t`t`t`t`tinterruptReason := "Boost Over"',
        '`t`t`t`t`tbreak',
        '`t`t`t`t}'
    )
    boostExpiryNew := JoinLines(
        '`t`t`t`t;boost is over',
        '`t`t`t`tif (fieldOverrideReason="Boost" && (nowUnix() >= nm_GetBoostChaseDeadline())) {',
        '`t`t`t`t`tnm_ClearBoostLeaseState(1)',
        '`t`t`t`t`tinterruptReason := "Boost Over"',
        '`t`t`t`t`tbreak',
        '`t`t`t`t}'
    )
    cNew := StrReplace(c, boostExpiryOld, boostExpiryNew)
    if (cNew != c) {
        c := cNew
        FileAppend("? Normalized boost expiry to true boost-end timing`n", logFile)
    }

    ; 1e. Override Logic
    if (patchTadSyncCore) {
    if !InStr(c, "tadsync_ApplyFollowingOverride") {
        if (pos := InStr(c, ";FIELD OVERRIDES")) {
            if (loopPos := InStr(c, "loop 1 {", , pos)) {
                if (endLoopPos := InStr(c, "`n", , loopPos)) {
                    overrideCode := '`t`tif (tadsync_ApplyFollowingOverride(&FieldName, &FieldPattern, &FieldPatternSize, &FieldPatternReps, &FieldPatternShift, &FieldPatternInvertFB, &FieldPatternInvertLR, &FieldUntilMins, &FieldUntilPack, &FieldReturnType, &FieldSprinklerLoc, &FieldSprinklerDist, &FieldRotateDirection, &FieldRotateTimes, &FieldDriftCheck, &fieldOverrideReason))`r`n`t`t`tbreak`r`n'
                    c := SubStr(c, 1, endLoopPos) overrideCode SubStr(c, endLoopPos+1)
                    FileAppend("✓ Added Override logic to nm_GoGather`n", logFile)
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
            FileAppend("? Added boosted-field scan-start trace`n", logFile)
    }
    if !InStr(c, 'tadsync_LogBoostScan("gather-scan-picked"') {
        pickNeedle := '`t`t`tif(BoostChaserField!="none") {'
        pickInsert := '`r`n`t`t`t`t`ttadsync_LogBoostScan("gather-scan-picked", CurrentField, RecentFBoost, BoostChaserField)'
        c := StrReplace(c, pickNeedle, pickNeedle pickInsert)
        if (c != orig)
            FileAppend("? Added boosted-field picked trace`n", logFile)
    }
    if !InStr(c, 'tadsync_LogBoostScan("gather-scan-none"') {
        noneNeedle := '`t`t`t;set field override'
        noneInsert := '`t`t`tif(BoostChaserField="none")`r`n`t`t`t`ttadsync_LogBoostScan("gather-scan-none", CurrentField, RecentFBoost)`r`n'
        c := StrReplace(c, noneNeedle, noneInsert noneNeedle)
        if (c != orig)
            FileAppend("? Added boosted-field none trace`n", logFile)
    }
    c := InsertAfterOnceAfter(c, 'tadsync_LogBoostScan("gather-scan-start"', '`t`t`t`ttadsync_LogBoostScan("gather-scan-start", CurrentField, RecentFBoost)', '`r`n`t`t`t`tboostTraceStart := A_TickCount', 'boostTraceStart := A_TickCount')
    c := InsertAfterOnceAfter(c, 'tadsync_LogBoostScan("gather-scan-picked"', '`t`t`t`ttadsync_LogBoostScan("gather-scan-picked", CurrentField, RecentFBoost, BoostChaserField)', '`r`n`t`t`t`tnm_ConvertTrace("Boost chase: picked " BoostChaserField, boostTraceStart)', 'nm_ConvertTrace("Boost chase: picked " BoostChaserField')
    c := InsertAfterOnceAfter(c, 'if(fieldOverrideReason="None" || fieldOverrideReason="Boost") {', '`tif(fieldOverrideReason="None" || fieldOverrideReason="Boost") {', '`r`n`t`tboostResetStart := A_TickCount`r`n`t`tnm_ConvertTrace("Boost chase: nm_Reset(2) start", boostResetStart)', 'nm_ConvertTrace("Boost chase: nm_Reset(2) start"')
    c := InsertAfterOnceAfter(c, 'nm_ConvertTrace("Boost chase: nm_Reset(2) start"', '`t`tnm_Reset(2)', '`r`n`t`tnm_ConvertTrace("Boost chase: nm_Reset(2) complete", boostResetStart)', 'nm_ConvertTrace("Boost chase: nm_Reset(2) complete"')
    c := RegExReplace(c, '(?ms)(\ttadsync_LogBoostScan\("gather-scan-start", CurrentField, RecentFBoost\)\r?\n)(?:\t+boostTraceStart := A_TickCount\r?\n)+', '$1`tboostTraceStart := A_TickCount`r`n')
    c := RegExReplace(c, '(?ms)(\tnm_ConvertTrace\("Boost chase: picked " BoostChaserField, boostTraceStart\)\r?\n)(?:\t+nm_ConvertTrace\("Boost chase: picked " BoostChaserField, boostTraceStart\)\r?\n)+', '$1')
    c := RegExReplace(c, '(?ms)(\t+boostResetStart := A_TickCount\r?\n\t+nm_ConvertTrace\("Boost chase: nm_Reset\(2\) start", boostResetStart\)\r?\n\t+nm_Reset\(2\)\r?\n\t+nm_ConvertTrace\("Boost chase: nm_Reset\(2\) complete", boostResetStart\)\r?\n)(?:\t+boostResetStart := A_TickCount\r?\n\t+nm_ConvertTrace\("Boost chase: nm_Reset\(2\) start", boostResetStart\)\r?\n\t+nm_Reset\(2\)\r?\n\t+nm_ConvertTrace\("Boost chase: nm_Reset\(2\) complete", boostResetStart\)\r?\n)+', '$1')

    ; 1e2. Prefer the most recently detected boosted field before falling back to fixed scan order.
    cleanupPattern := '\r?\n\s*(?:boostExtendActive := .*?\r?\n\s*)?if \(RecentFBoost != "None" && recentBoostEnabled && (?:nm_fieldBoostCheck\(RecentFBoost, 1\)|\(\(nowUnix\(\)-GatherFieldBoostedStart\) < 900\)|\(\(\(nowUnix\(\)-GatherFieldBoostedStart\) < 900\) \|\| boostExtendActive\)|boostReturnAllowed|boostTotalDuration|nm_GetBoostChaseRemainingSeconds\(GatherFieldBoostedStart\))\) \{\r?\n\s*BoostChaserField:=RecentFBoost\r?\n\s*break\r?\n\s*\}'
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
            '`r`n`t`t`tboostExtendActive := PFieldBoosted && ((nowUnix()-GatherFieldBoostedStart) < boostTotalDuration) && ((nowUnix()-LastGlitter) < 900)'
            '`r`n`t`t`tboostReturnStart := nm_GetBoostChaseStart(GatherFieldBoostedStart)'
            '`r`n`t`t`tboostReturnRemaining := nm_GetBoostChaseRemainingSeconds(GatherFieldBoostedStart)'
            '`r`n`t`t`tboostReturnAllowed := (boostReturnRemaining > 0)'
            '$2'
            '`t`t`t`tif (RecentFBoost != "None" && recentBoostEnabled && boostReturnAllowed) {'
            '`r`n`t`t`t`t`tBoostChaserField:=RecentFBoost'
            '`r`n`t`t`t`t`tbreak'
            '`r`n`t`t`t`t}'
        )
        cNew := RegExReplace(c, pattern, replacement, &count, 1)
        if (count > 0) {
            c := cNew
            FileAppend("? Added RecentFBoost preference to boosted-field scan`n", logFile)
        }
    }
    if (patchForceHourly || patchStatMonitorTheme) {
        if !InStr(c, 'tadsync_LogBoosterDetected(location, v)') {
            boostDetectNeedle := 'nm_setStatus("Boosted", v), RecentFBoost := v'
            boostDetectReplace := 'nm_setStatus("Boosted", v), RecentFBoost := v, tadsync_LogBoosterDetected(location, v)'
            c := StrReplace(c, boostDetectNeedle, boostDetectReplace)
            if (c != orig)
                FileAppend("? Added booster-detected trace`n", logFile)
        }
        if !InStr(c, 'nm_IncrementStat(StrReplace(v, " "))') {
            boosterPersistPattern := '(?ms)if nm_fieldBoostCheck\(v, [01]\)\s*\{\s*nm_setStatus\("Boosted", v\), RecentFBoost := v(?:, tadsync_LogBoosterDetected\(location, v\))?\s*break 2\s*\}'
            ; Keep variant 0 here so winds do not masquerade as a fresh booster icon.
            blueBoosterStatCountersText := ReadPatchBlock(blueBoosterStatCountersTemplatePath)
            boosterPersistReplacement :=
            (
                '`t`t`t`tif nm_fieldBoostCheck(v, 0)`r`n'
                . '`t`t`t`t{`r`n'
                . '`t`t`t`t`tnm_setStatus("Boosted", v), RecentFBoost := v, tadsync_LogBoosterDetected(location, v)`r`n'
                . '`t`t`t`t`tboostDetectedAt := nowUnix()`r`n'
                . '`t`t`t`t`tGatherFieldBoostedStart := boostDetectedAt`r`n'
                . '`t`t`t`t`tIniWrite(v, "settings\nm_config.ini", "Boost", "LastBoostedField")`r`n'
                . '`t`t`t`t`tIniWrite(boostDetectedAt, "settings\nm_config.ini", "Boost", "LastBoostedTime")`r`n'
                . (blueBoosterStatCountersText != "" ? blueBoosterStatCountersText "`r`n" : '')
                . '`t`t`t`t`tbreak 2`r`n'
                . '`t`t`t`t}'
            )
            cNew := RegExReplace(c, boosterPersistPattern, boosterPersistReplacement, &boosterPersistCount, 1)
            if (boosterPersistCount > 0 && cNew != c) {
                c := cNew
                FileAppend("? Persisted booster-detected field immediately in nm_toBooster()`n", logFile)
            }
        }
    }

    ; 1f. Leader Announcement
    if !InStr(c, "tadsync_CheckAnnounceField") {
        if (pos := InStr(c, 'nm_updateAction("Gather")')) {
            announceCode := '`t;announce field change if leader mode (TadSync)`r`n`tif (FieldFollowingCheck && FieldFollowingFollowMode="Leader" && LastAnnouncedField!=FieldName)`r`n`t`ttadsync_CheckAnnounceField(FieldName)`r`n`r`n`t'
            c := SubStr(c, 1, pos-1) announceCode SubStr(c, pos)
            FileAppend("✓ Added Announcement logic`n", logFile)
        }
    }
    if !InStr(c, 'tadsync_HandleHiveStandby()') {
        cNew := StrReplace(c, '`t;FIELD OVERRIDES', '`tif tadsync_HandleHiveStandby()`r`n`t`treturn`r`n`t;FIELD OVERRIDES')
        if (cNew != c) {
            c := cNew
            FileAppend("? Added TadSync hive-standby handling to nm_GoGather`n", logFile)
        }
    }

    ; 1k. Interrupt Logic
    oldFollowInterrupt := '`r`n`t`t`t`tif (FollowingLeader && (FieldName != FollowingField)) {`r`n`t`t`t`t`tinterruptReason := "Following"`r`n`t`t`t`t`tbreak`r`n`t`t`t`t}'
    newFollowInterrupt := '`r`n`t`t`t`tif tadsync_ShouldInterruptFollowing(FieldName) {`r`n`t`t`t`t`tinterruptReason := "Following"`r`n`t`t`t`t`tbreak`r`n`t`t`t`t}'
    if InStr(c, oldFollowInterrupt) {
        c := StrReplace(c, oldFollowInterrupt, newFollowInterrupt)
        FileAppend("? Updated TadSync follow interrupt to helper-based logic`n", logFile)
    }
    if !InStr(c, 'tadsync_ShouldInterruptFollowing(FieldName)') {
        if (pos := InStr(c, ";high priority interrupts")) {
            if (ifPos := InStr(c, "if (Mod(A_Index, 5) = 1) {", , pos)) {
                if (endIfPos := InStr(c, "{", , ifPos)) {
                    interruptCode := '`r`n`t`t`t`tnm_CheckBoostLeaseWarning()' newFollowInterrupt
                    c := SubStr(c, 1, endIfPos) interruptCode SubStr(c, endIfPos+1)
                    FileAppend("✓ Added Interrupt logic to Gathering loop`n", logFile)
                }
            }
        }
    }
    }

    ; 1g. Extensions tab registration
    if InStr(c, '"TadSync"') {
        c := StrReplace(c, '"TadSync"', '"Extensions"')
        FileAppend("? Renamed TadSync tab to Extensions`n", logFile)
    }
    if (tabArrPos := InStr(c, 'TabArr := ')) {
        tabArrBlock := SubStr(c, tabArrPos, 250)
        c := NormalizeDelimitedBlock(c, '(TabArr\s*:=\s*\[)(.*?)(\])', "tabs", &tabArrChanged)
        if tabArrChanged
            FileAppend("? Normalized Extensions position in TabArr`n", logFile)
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
        'MainGui.Add("GroupBox", "x5 y23 w165 h105", "Extensions")',
        'MainGui.Add("GroupBox", "x175 y23 w155 h105", "Interupts")',
        'MainGui.Add("GroupBox", "x335 y23 w155 h105", "Extras")',
        '',
        'MainGui.SetFont("s8 cDefault Norm", "Tahoma")',
        '',
        'MainGui.Add("Button", "x15 y45 w150 h20 vFieldFollowingGUI Disabled", "Field Following").OnEvent("Click", aq_FieldFollowingGUI)',
        'MainGui.Add("Button", "x15 y70 w150 h20 vStatMonitorEditorGUI Disabled", "StatMonitor Editor").OnEvent("Click", aq_StatMonitorThemeEditorGUI)',
        'MainGui.Add("Button", "x15 y95 w150 h20 vReconnectSyncGUI Disabled", "Reconnect Sync").OnEvent("Click", recon_ReconnectSyncGUI)',
        'MainGui.Add("CheckBox", "x185 y45 w135 h18 vBlueBoosterInterruptCheck Checked" BlueBoosterInterruptCheck, "Blue Booster Interrupt").OnEvent("Click", nm_BlueBoosterToggle)',
        'MainGui.Add("CheckBox", "x185 y70 w140 h18 vStickerStackInterruptCheck" . (StickerStackInterruptCheck ? " Checked" : ""), "Sticker Stack Interrupt").OnEvent("Click", nm_StickerStackToggle)',
        '(GuiCtrl := MainGui.Add("CheckBox", "x185 y95 w135 h18 vMondoInterruptCheck" . (MondoInterruptCheck ? " Checked" : ""), "Mondo Interrupt")).Section := "Extensions", GuiCtrl.OnEvent("Click", nm_saveConfig)',
        'MainGui.Add("CheckBox", "x345 y45 w135 h18 vPFieldBoosted Checked" PFieldBoosted, "Glitter Extend").OnEvent("Click", aq_togglePFieldBoosted)',
        '(GuiCtrl := MainGui.Add("CheckBox", "x345 y70 w135 h18 vPreGlitterCheck" . (PreGlitterCheck ? " Checked" : ""), "Pre-Glitter")).Section := "Extensions", GuiCtrl.OnEvent("Click", nm_saveConfig)',
        '(GuiCtrl := MainGui.Add("CheckBox", "x345 y95 w140 h18 vEnzymesBoostedOnly" . (EnzymesBoostedOnly ? " Checked" : ""), "Boosted Enzyme Only")).Section := "Extensions", GuiCtrl.OnEvent("Click", nm_saveConfig)',
        'MainGui.Add("Text", "x12 y134 w476 Center c666666", "Made by: @definetlynotray")',
        'MainGui.Add("Text", "x12 y146 w476 Center c666666", "Inspired by @baspas")'
    )
    if InStr(c, oldMondoButton) {
        c := StrReplace(c, oldMondoButton "`r`n", "")
        FileAppend("? Removed public Mondo Hop button from the Extensions tab`n", logFile)
    }

    oldVersionFooter := '(GuiCtrl := MainGui.Add("Text", "x435 y264 vVersionText", "v" versionID)).OnEvent("Click", nm_showAdvancedSettings), GuiCtrl.Move(494 - (VersionWidth := TextExtent("v" VersionID, GuiCtrl)))'
    newVersionFooter := '(GuiCtrl := MainGui.Add("Text", "x435 y264 vVersionText", "Rays.v" versionID)).OnEvent("Click", nm_showAdvancedSettings), GuiCtrl.Move(494 - (VersionWidth := TextExtent("Rays.v" VersionID, GuiCtrl)))'
    c := StrReplace(c, oldVersionFooter, newVersionFooter)
    c := StrReplace(c, '(GuiCtrl := MainGui.Add("Text", "x435 y264 vVersionText", "Rays.v" versionID)).OnEvent("Click", nm_showAdvancedSettings), GuiCtrl.Move(494 - (VersionWidth := TextExtent("v" VersionID, GuiCtrl)))', newVersionFooter)
    if InStr(c, oldBoostGroup) {
        c := StrReplace(c, oldBoostGroup "`r`n`r`n", "")
        FileAppend("? Removed old TadSync boosted group from the Extensions tab`n", logFile)
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
    c := StrReplace(c, 'MainGui.Add("GroupBox", "x175 y23 w315 h80", "Interupts & Extras")', 'MainGui.Add("GroupBox", "x175 y23 w155 h105", "Interupts")`r`nMainGui.Add("GroupBox", "x335 y23 w155 h105", "Extras")')
    c := StrReplace(c, 'MainGui.Add("GroupBox", "x175 y23 w155 h80", "Interupts")', 'MainGui.Add("GroupBox", "x175 y23 w155 h105", "Interupts")')
    c := StrReplace(c, 'MainGui.Add("CheckBox", "x185 y45 w135 h18 vPFieldBoosted Checked" PFieldBoosted, "Glitter Extend").OnEvent("Click", aq_togglePFieldBoosted)', 'MainGui.Add("CheckBox", "x345 y45 w135 h18 vPFieldBoosted Checked" PFieldBoosted, "Glitter Extend").OnEvent("Click", aq_togglePFieldBoosted)')
    c := StrReplace(c, 'MainGui.Add("CheckBox", "x335 y45 w145 h18 vBlueBoosterInterruptCheck Checked" BlueBoosterInterruptCheck, "BFB Interrupt").OnEvent("Click", nm_BlueBoosterToggle)', 'MainGui.Add("CheckBox", "x185 y45 w135 h18 vBlueBoosterInterruptCheck Checked" BlueBoosterInterruptCheck, "BFB Interrupt").OnEvent("Click", nm_BlueBoosterToggle)')
    c := StrReplace(c, 'MainGui.Add("CheckBox", "x185 y70 w145 h18 vStickerStackInterruptCheck" . (StickerStackInterruptCheck ? " Checked" : ""), "Sticker Stack Interrupt").OnEvent("Click", nm_StickerStackToggle)', 'MainGui.Add("CheckBox", "x185 y70 w140 h18 vStickerStackInterruptCheck" . (StickerStackInterruptCheck ? " Checked" : ""), "Sticker Stack Interrupt").OnEvent("Click", nm_StickerStackToggle)')
    c := StrReplace(c, 'MainGui.Add("CheckBox", "x185 y70 w140 h18 vStickerStackInterruptCheck" . (StickerStackInterruptCheck ? " Checked" : ""), "Sticker Stack Interrupt").OnEvent("Click", nm_StickerStackToggle)`r`nMainGui.Add("CheckBox", "x345 y45 w135 h18 vPFieldBoosted Checked" PFieldBoosted, "Glitter Extend").OnEvent("Click", aq_togglePFieldBoosted)', 'MainGui.Add("CheckBox", "x185 y70 w140 h18 vStickerStackInterruptCheck" . (StickerStackInterruptCheck ? " Checked" : ""), "Sticker Stack Interrupt").OnEvent("Click", nm_StickerStackToggle)`r`n(GuiCtrl := MainGui.Add("CheckBox", "x185 y95 w135 h18 vMondoInterruptCheck" . (MondoInterruptCheck ? " Checked" : ""), "Mondo Interrupt")).Section := "Extensions", GuiCtrl.OnEvent("Click", nm_saveConfig)`r`nMainGui.Add("CheckBox", "x345 y45 w135 h18 vPFieldBoosted Checked" PFieldBoosted, "Glitter Extend").OnEvent("Click", aq_togglePFieldBoosted)')
    c := StrReplace(c, 'MainGui.Add("CheckBox", "x185 y70 w140 h18 vStickerStackInterruptCheck Disabled", "Sticker Stack Interrupt")`r`nMainGui.Add("CheckBox", "x345 y45 w135 h18 vPFieldBoosted Disabled", "Glitter Extend")', 'MainGui.Add("CheckBox", "x185 y70 w140 h18 vStickerStackInterruptCheck Disabled", "Sticker Stack Interrupt")`r`n(GuiCtrl := MainGui.Add("CheckBox", "x185 y95 w135 h18 vMondoInterruptCheck Disabled", "Mondo Interrupt")).Section := "Extensions"`r`nMainGui.Add("CheckBox", "x345 y45 w135 h18 vPFieldBoosted Disabled", "Glitter Extend")')
    c := StrReplace(c, '(GuiCtrl := MainGui.Add("CheckBox", "x335 y70 w145 h18 vEnzymesBoostedOnly" . (EnzymesBoostedOnly ? " Checked" : ""), "Boosted Enzyme Only")).Section := "Boost", GuiCtrl.OnEvent("Click", nm_saveConfig)', '(GuiCtrl := MainGui.Add("CheckBox", "x345 y70 w135 h18 vPreGlitterCheck" . (PreGlitterCheck ? " Checked" : ""), "Pre-Glitter")).Section := "Extensions", GuiCtrl.OnEvent("Click", nm_saveConfig)`r`n(GuiCtrl := MainGui.Add("CheckBox", "x345 y95 w140 h18 vEnzymesBoostedOnly" . (EnzymesBoostedOnly ? " Checked" : ""), "Boosted Enzyme Only")).Section := "Extensions", GuiCtrl.OnEvent("Click", nm_saveConfig)')
    c := StrReplace(c, '(GuiCtrl := MainGui.Add("CheckBox", "x345 y70 w140 h18 vEnzymesBoostedOnly" . (EnzymesBoostedOnly ? " Checked" : ""), "Boosted Enzyme Only")).Section := "Boost", GuiCtrl.OnEvent("Click", nm_saveConfig)', '(GuiCtrl := MainGui.Add("CheckBox", "x345 y70 w135 h18 vPreGlitterCheck" . (PreGlitterCheck ? " Checked" : ""), "Pre-Glitter")).Section := "Extensions", GuiCtrl.OnEvent("Click", nm_saveConfig)`r`n(GuiCtrl := MainGui.Add("CheckBox", "x345 y95 w140 h18 vEnzymesBoostedOnly" . (EnzymesBoostedOnly ? " Checked" : ""), "Boosted Enzyme Only")).Section := "Extensions", GuiCtrl.OnEvent("Click", nm_saveConfig)')
    c := StrReplace(c, 'MainGui.Add("GroupBox", "x335 y23 w155 h80", "Extras")', 'MainGui.Add("GroupBox", "x335 y23 w155 h105", "Extras")')
    if !InStr(c, 'vEnzymesBoostedOnly') {
        c := StrReplace(c, '(GuiCtrl := MainGui.Add("CheckBox", "x345 y70 w135 h18 vPreGlitterCheck" . (PreGlitterCheck ? " Checked" : ""), "Pre-Glitter")).Section := "Extensions", GuiCtrl.OnEvent("Click", nm_saveConfig)', '(GuiCtrl := MainGui.Add("CheckBox", "x345 y70 w135 h18 vPreGlitterCheck" . (PreGlitterCheck ? " Checked" : ""), "Pre-Glitter")).Section := "Extensions", GuiCtrl.OnEvent("Click", nm_saveConfig)`r`n(GuiCtrl := MainGui.Add("CheckBox", "x345 y95 w140 h18 vEnzymesBoostedOnly" . (EnzymesBoostedOnly ? " Checked" : ""), "Boosted Enzyme Only")).Section := "Extensions", GuiCtrl.OnEvent("Click", nm_saveConfig)')
        c := StrReplace(c, '(GuiCtrl := MainGui.Add("CheckBox", "x345 y70 w135 h18 vPreGlitterCheck Disabled", "Pre-Glitter")).Section := "Extensions"', '(GuiCtrl := MainGui.Add("CheckBox", "x345 y70 w135 h18 vPreGlitterCheck Disabled", "Pre-Glitter")).Section := "Extensions"`r`n(GuiCtrl := MainGui.Add("CheckBox", "x345 y95 w140 h18 vEnzymesBoostedOnly Disabled", "Boosted Enzyme Only")).Section := "Extensions"')
    }
    c := StrReplace(c, 'MainGui.Add("Text", "x12 y109 w476 Center c666666", "Made by: @definetlynotray")`r`nMainGui.Add("Text", "x12 y121 w476 Center c666666", "Inspired by @baspas")', 'MainGui.Add("Text", "x12 y134 w476 Center c666666", "Made by: @definetlynotray")`r`nMainGui.Add("Text", "x12 y146 w476 Center c666666", "Inspired by @baspas")')
    if !InStr(c, 'MainGui.Add("GroupBox", "x175 y23 w155 h105", "Interupts")') && InStr(c, 'MainGui.Add("GroupBox", "x5 y23 w490 h80", "Extensions")') {
        c := StrReplace(c, 'MainGui.Add("GroupBox", "x5 y23 w490 h80", "Extensions")`r`n`r`nMainGui.SetFont("s8 cDefault Norm", "Tahoma")`r`n`r`nMainGui.Add("Button", "x15 y45 w150 h20 vFieldFollowingGUI Disabled", "Field Following").OnEvent("Click", aq_FieldFollowingGUI)', newExtensionsLayout)
        FileAppend("? Split Extensions controls into Interupts and Extras sections`n", logFile)
    }
    if InStr(c, 'MainGui.Add("GroupBox", "x175 y23 w155 h105", "Interupts")') && !InStr(c, 'MainGui.Add("Text", "x12 y134 w476 Center c666666", "Made by: @definetlynotray")') {
        creditsNeedle := '(GuiCtrl := MainGui.Add("CheckBox", "x345 y95 w140 h18 vEnzymesBoostedOnly" . (EnzymesBoostedOnly ? " Checked" : ""), "Boosted Enzyme Only")).Section := "Extensions", GuiCtrl.OnEvent("Click", nm_saveConfig)'
        creditsInsert := creditsNeedle '`r`nMainGui.Add("Text", "x12 y134 w476 Center c666666", "Made by: @definetlynotray")`r`nMainGui.Add("Text", "x12 y146 w476 Center c666666", "Inspired by @baspas")'
        if InStr(c, creditsNeedle) {
            c := StrReplace(c, creditsNeedle, creditsInsert)
            FileAppend("? Added Extensions credits footer`n", logFile)
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
            FileAppend("? Added Extensions tab with Interupts and Extras controls`n", logFile)
        }
    }
    c := EnsureExtensionsEnzymeControl(c)
    ; 1i. nm_LockTabs tab list registration
    if InStr(c, "nm_LockTabs") {
        lockTabsPos := InStr(c, "nm_LockTabs")
        lockTabsBlock := SubStr(c, lockTabsPos, 250)
        c := NormalizeDelimitedBlock(c, '(static tabs\s*:=\s*\[)(.*?)(\])', "locktabs", &lockTabsChanged)
        if lockTabsChanged
            FileAppend("? Normalized Extensions position in LockTabs tab list`n", logFile)
    }

    ; 1j. nm_TabExtensionsLock/UnLock functions
    oldFuncs := '`r`nnm_TabTadSyncLock(){`r`n`tMainGui["FieldFollowingGUI"].Enabled := 0`r`n`tMainGui["MondoHopGUI"].Enabled := 0`r`n}`r`nnm_TabTadSyncUnLock(){`r`n`tMainGui["FieldFollowingGUI"].Enabled := 1`r`n`tMainGui["MondoHopGUI"].Enabled := 1`r`n}'
    newFuncs := '`r`nnm_TabExtensionsLock(){`r`n`tMainGui["FieldFollowingGUI"].Enabled := 0`r`n`tMainGui["StatMonitorEditorGUI"].Enabled := 0`r`n`tMainGui["ReconnectSyncGUI"].Enabled := 0`r`n`tMainGui["PFieldBoosted"].Enabled := 0`r`n`tMainGui["PreGlitterCheck"].Enabled := 0`r`n`tMainGui["BlueBoosterInterruptCheck"].Enabled := 0`r`n`tMainGui["StickerStackInterruptCheck"].Enabled := 0`r`n`tMainGui["MondoInterruptCheck"].Enabled := 0`r`n`tMainGui["EnzymesBoostedOnly"].Enabled := 0`r`n}`r`nnm_TabExtensionsUnLock(){`r`n`tMainGui["FieldFollowingGUI"].Enabled := 1`r`n`tMainGui["StatMonitorEditorGUI"].Enabled := 1`r`n`tMainGui["ReconnectSyncGUI"].Enabled := 1`r`n`tMainGui["PFieldBoosted"].Enabled := 1`r`n`tMainGui["PreGlitterCheck"].Enabled := 1`r`n`tMainGui["BlueBoosterInterruptCheck"].Enabled := 1`r`n`tMainGui["StickerStackInterruptCheck"].Enabled := 1`r`n`tMainGui["MondoInterruptCheck"].Enabled := 1`r`n`tMainGui["EnzymesBoostedOnly"].Enabled := 1`r`n}`r`nnm_TabTadSyncLock(){`r`n`tnm_TabExtensionsLock()`r`n}`r`nnm_TabTadSyncUnLock(){`r`n`tnm_TabExtensionsUnLock()`r`n}'
    cNew := StrReplace(c, oldFuncs, newFuncs)
    if (cNew != c) {
        c := cNew
        FileAppend("? Replaced TadSync tab lock functions with Extensions variants`n", logFile)
    } else if InStr(c, 'nm_TabExtensionsLock(){`r`n`tMainGui["FieldFollowingGUI"].Enabled := 0`r`n}`r`nnm_TabExtensionsUnLock(){`r`n`tMainGui["FieldFollowingGUI"].Enabled := 1`r`n}') {
        c := StrReplace(c, 'nm_TabExtensionsLock(){`r`n`tMainGui["FieldFollowingGUI"].Enabled := 0`r`n}`r`nnm_TabExtensionsUnLock(){`r`n`tMainGui["FieldFollowingGUI"].Enabled := 1`r`n}', 'nm_TabExtensionsLock(){`r`n`tMainGui["FieldFollowingGUI"].Enabled := 0`r`n`tMainGui["StatMonitorEditorGUI"].Enabled := 0`r`n`tMainGui["ReconnectSyncGUI"].Enabled := 0`r`n`tMainGui["PFieldBoosted"].Enabled := 0`r`n`tMainGui["PreGlitterCheck"].Enabled := 0`r`n`tMainGui["BlueBoosterInterruptCheck"].Enabled := 0`r`n`tMainGui["StickerStackInterruptCheck"].Enabled := 0`r`n`tMainGui["EnzymesBoostedOnly"].Enabled := 0`r`n}`r`nnm_TabExtensionsUnLock(){`r`n`tMainGui["FieldFollowingGUI"].Enabled := 1`r`n`tMainGui["StatMonitorEditorGUI"].Enabled := 1`r`n`tMainGui["ReconnectSyncGUI"].Enabled := 1`r`n`tMainGui["PFieldBoosted"].Enabled := 1`r`n`tMainGui["PreGlitterCheck"].Enabled := 1`r`n`tMainGui["BlueBoosterInterruptCheck"].Enabled := 1`r`n`tMainGui["StickerStackInterruptCheck"].Enabled := 1`r`n`tMainGui["EnzymesBoostedOnly"].Enabled := 1`r`n}')
        FileAppend("? Expanded Extensions tab lock functions for Interupts and Extras`n", logFile)
    } else if !InStr(c, "nm_TabExtensionsLock") {
        c .= newFuncs
        FileAppend("? Added Extensions tab lock functions`n", logFile)
    }

    ; 1l. TadSync Interrupt Function
    if InStr(c, 'nm_TadsyncInterrupt() => (FollowingLeader = 1 && (FieldName != FollowingField))') {
        c := StrReplace(c, 'nm_TadsyncInterrupt() => (FollowingLeader = 1 && (FieldName != FollowingField))', 'nm_TadsyncInterrupt() => tadsync_ShouldInterruptFollowing(FieldName)')
        FileAppend("? Updated nm_TadsyncInterrupt to helper-based logic`n", logFile)
    } else if !InStr(c, "nm_TadsyncInterrupt") {
        c .= '`r`nnm_TadsyncInterrupt() => tadsync_ShouldInterruptFollowing(FieldName)`r`n'
        FileAppend("✓ Added nm_TadsyncInterrupt function`n", logFile)
    }

    ; 1a0b. Include extension handlers required by selected modules.
    if patchTadSyncCore {
        extDir := workDir "\Extensions"
        if DirExist(extDir) {
            loop files extDir "\*.ahk" {
                extFile := A_LoopFileName
                shouldInclude := (extFile != "statmonitor_theme_extension.ahk")
                if !shouldInclude
                    continue

                includeStr := '#Include "%A_ScriptDir%\..\Extensions\' extFile '"`r`n'
                if !InStr(c, extFile) {
                    if (pos := InStr(c, "#Warn")) {
                        c := SubStr(c, 1, pos-1) includeStr SubStr(c, pos)
                        FileAppend("? Auto-included Extensions\\" extFile "`n", logFile)
    }
    ; BFB retry: make nm_toBooster return success/failure and add retry loop for blue booster
    if !InStr(c, 'nm_toBooster("blue", 3)') && !InStr(c, 'bfbRetryMax') {
        ; Step 1: Make nm_toBooster return 1 on success, 0 on failure
        cNew := StrReplace(c
            , '				If A_Index = 10 ' "`r`n" '					nm_setStatus("Failed", "Could not find field boost!")'
            , '				If A_Index = 10 {`r`n					nm_setStatus("Failed", "Could not find field boost!")`r`n					return 0`r`n				}'
        )
        if (cNew != c) {
            c := cNew
            FileAppend("? Added return 0 on boost detection failure in nm_toBooster()`n", logFile)
        }
        cNew := StrReplace(c
            , '			break`r`n		}`r`n		else if (A_Index = 2)'
            , '			return 1`r`n		}`r`n		else if (A_Index = 2)'
        )
        if (cNew != c) {
            c := cNew
            FileAppend("? Added return 1 on boost success in nm_toBooster()`n", logFile)
        }
        cNew := StrReplace(c
            , '	}`r`n}`r`n`r`n;;;;;;;;; START AFB'
            , '	}`r`n	return 0`r`n}`r`n`r`n;;;;;;;;; START AFB'
        )
        if (cNew != c) {
            c := cNew
            FileAppend("? Added fallback return 0 at end of nm_toBooster()`n", logFile)
        }
    }
    ; BFB retry: wrap blue booster calls in retry loop
    if !InStr(c, 'bfbRetryMax') {
        ; High-priority BFB in nm_GoGather (immediate)
        oldGoGatherBfb := JoinLines(
            '	if nm_BlueBoosterInterrupt() {',
            '		nm_toBooster("blue")',
            '		return',
            '	}'
        )
        newGoGatherBfb := JoinLines(
            '	if nm_BlueBoosterInterrupt() {',
            '		bfbRetryMax := 3, bfbRetry := 0',
            '		while (bfbRetry < bfbRetryMax) {',
            '			bfbRetry++',
            '			if nm_toBooster("blue")',
            '				break',
            '			nm_setStatus("Retrying", "BFB attempt " bfbRetry "/" bfbRetryMax)',
            '		}',
            '		return',
            '	}'
        )
        cNew := StrReplace(c, oldGoGatherBfb, newGoGatherBfb)
        if (cNew != c) {
            c := cNew
            FileAppend("? Added BFB retry loop in nm_GoGather()`n", logFile)
        }
        ; High-priority gather interrupt BFB
        oldHighBfb := JoinLines(
            '				if nm_BlueBoosterInterrupt() {',
            '					interruptReason := "Blue Booster Ready"',
            '					break',
            '				}'
        )
        newHighBfb := JoinLines(
            '				if nm_BlueBoosterInterrupt() {',
            '					interruptReason := "Blue Booster Ready"',
            '					break',
            '				}'
        )
        cNew := StrReplace(c, oldHighBfb, newHighBfb)
        if (cNew != c) {
            c := cNew
            FileAppend("? Verified BFB high-priority gather interrupt (no in-loop retry)`n", logFile)
        }
        ; Low-priority gather interrupt BFB (uses break too)
        oldLowBfb := JoinLines(
            '				if nm_BlueBoosterInterrupt() {',
            '					interruptReason := "Blue Booster Ready"',
            '					break',
            '				}'
        )
        newLowBfb := JoinLines(
            '				if nm_BlueBoosterInterrupt() {',
            '					interruptReason := "Blue Booster Ready"',
            '					break',
            '				}'
        )
        cNew := StrReplace(c, oldLowBfb, newLowBfb)
        if (cNew != c) {
            c := cNew
            FileAppend("? Verified BFB low-priority gather interrupt (no in-loop retry)`n", logFile)
        }
    }
    }
            }
        }
    }
    if patchStatMonitorTheme {
        statMonitorInclude := '#Include "%A_ScriptDir%\..\Extensions\statmonitor_theme_extension.ahk"`r`n'
        if !InStr(c, 'statmonitor_theme_extension.ahk') {
            if (pos := InStr(c, "#Warn")) {
                c := SubStr(c, 1, pos - 1) statMonitorInclude SubStr(c, pos)
                FileAppend("? Auto-included Extensions\\statmonitor_theme_extension.ahk`n", logFile)
            }
        }
    }
    if patchMondoInterrupt {
        mondoInterruptInclude := '#Include "%A_ScriptDir%\..\Extensions\mondo_interrupt_extension.ahk"`r`n'
        if !InStr(c, 'mondo_interrupt_extension.ahk') {
            if (pos := InStr(c, "#Warn")) {
                c := SubStr(c, 1, pos - 1) mondoInterruptInclude SubStr(c, pos)
                FileAppend("? Auto-included Extensions\\mondo_interrupt_extension.ahk`n", logFile)
            }
        }
    }

    ; 1k. Extensions shell should always exist, even when feature modules stay unpatched.
    fieldFollowingButtonLine := patchTadSyncCore
        ? 'MainGui.Add("Button", "x15 y45 w150 h20 vFieldFollowingGUI", "Field Following").OnEvent("Click", aq_FieldFollowingGUI)'
        : 'MainGui.Add("Button", "x15 y45 w150 h20 vFieldFollowingGUI Disabled", "Field Following")'
    statMonitorButtonLine := patchStatMonitorTheme
        ? 'MainGui.Add("Button", "x15 y70 w150 h20 vStatMonitorEditorGUI", "StatMonitor Editor").OnEvent("Click", aq_StatMonitorThemeEditorGUI)'
        : 'MainGui.Add("Button", "x15 y70 w150 h20 vStatMonitorEditorGUI Disabled", "StatMonitor Editor")'
    blueBoosterLine := patchBfb
        ? 'MainGui.Add("CheckBox", "x185 y45 w135 h18 vBlueBoosterInterruptCheck" . (BlueBoosterInterruptCheck ? " Checked" : ""), "Blue Booster Interrupt").OnEvent("Click", nm_BlueBoosterToggle)'
        : 'MainGui.Add("CheckBox", "x185 y45 w135 h18 vBlueBoosterInterruptCheck Disabled", "Blue Booster Interrupt")'
    stickerStackLine := patchStickerStack
        ? 'MainGui.Add("CheckBox", "x185 y70 w140 h18 vStickerStackInterruptCheck" . (StickerStackInterruptCheck ? " Checked" : ""), "Sticker Stack Interrupt").OnEvent("Click", nm_StickerStackToggle)'
        : 'MainGui.Add("CheckBox", "x185 y70 w140 h18 vStickerStackInterruptCheck Disabled", "Sticker Stack Interrupt")'
    mondoInterruptLine := patchMondoInterrupt
        ? '(GuiCtrl := MainGui.Add("CheckBox", "x185 y95 w135 h18 vMondoInterruptCheck" . (MondoInterruptCheck ? " Checked" : ""), "Mondo Interrupt")).Section := "Extensions", GuiCtrl.OnEvent("Click", nm_saveConfig)'
        : '(GuiCtrl := MainGui.Add("CheckBox", "x185 y95 w135 h18 vMondoInterruptCheck Disabled", "Mondo Interrupt")).Section := "Extensions"'
    glitterExtendLine := patchGlitterExtend
        ? 'MainGui.Add("CheckBox", "x345 y45 w135 h18 vPFieldBoosted" . (PFieldBoosted ? " Checked" : ""), "Glitter Extend").OnEvent("Click", aq_togglePFieldBoosted)'
        : 'MainGui.Add("CheckBox", "x345 y45 w135 h18 vPFieldBoosted Disabled", "Glitter Extend")'
    preGlitterLine := patchGlitterExtend
        ? '(GuiCtrl := MainGui.Add("CheckBox", "x345 y70 w135 h18 vPreGlitterCheck" . (PreGlitterCheck ? " Checked" : ""), "Pre-Glitter")).Section := "Extensions", GuiCtrl.OnEvent("Click", nm_saveConfig)'
        : '(GuiCtrl := MainGui.Add("CheckBox", "x345 y70 w135 h18 vPreGlitterCheck Disabled", "Pre-Glitter")).Section := "Extensions"'
    enzymeLine := '(GuiCtrl := MainGui.Add("CheckBox", "x345 y95 w140 h18 vEnzymesBoostedOnly" . (EnzymesBoostedOnly ? " Checked" : ""), "Boosted Enzyme Only")).Section := "Extensions", GuiCtrl.OnEvent("Click", nm_saveConfig)'
    extensionsUnlockExtras := ""

    if !InStr(c, 'config["Extensions"]') {
        if (pos := InStr(c, 'config["Status"] := Map(')) {
            configCode := 'config["Extensions"] := Map("FollowingLeader", 0, "FollowingField", "", "FollowingStartTime", 0, "LastAnnouncedField", "", "FieldFollowingCheck", 0, "FieldFollowingFollowMode", "Follower", "FieldFollowingMaxTime", 900, "FieldFollowingChannelID", "", "FieldFollowingHiveRedirect", "Blue Flower", "PFieldBoosted", 0, "PreGlitterCheck", 0, "MondoInterruptCheck", 1, "EnzymesBoostedOnly", 1, "ReconnectSyncCheck", 1, "ReconnectSyncMode", "Main", "ReconnectSyncChannelID", ""'
            if patchMondoHop
                configCode .= ', "AltHopMondoEnabled", 0, "AltHopMondoLeadTime", 1.5, "AltHopMondoState", 0, "AltHopMondoLastTime", 0, "MondoHopLootTime", 45'
            configCode .= ')`r`n'
            c := SubStr(c, 1, pos-1) configCode SubStr(c, pos)
            FileAppend("? Added config['Extensions'] shell`n", logFile)
        }
    }
    c := EnsureConfigMapEntry(c, "Extensions", "FollowingLeader", 0, &mapChanged)
    c := EnsureConfigMapEntry(c, "Extensions", "FollowingField", '""', &mapChanged)
    c := EnsureConfigMapEntry(c, "Extensions", "FollowingStartTime", 0, &mapChanged)
    c := EnsureConfigMapEntry(c, "Extensions", "LastAnnouncedField", '""', &mapChanged)
    c := EnsureConfigMapEntry(c, "Extensions", "FieldFollowingCheck", 0, &mapChanged)
    c := EnsureConfigMapEntry(c, "Extensions", "FieldFollowingFollowMode", '"Follower"', &mapChanged)
    c := EnsureConfigMapEntry(c, "Extensions", "FieldFollowingMaxTime", 900, &mapChanged)
    c := EnsureConfigMapEntry(c, "Extensions", "FieldFollowingChannelID", '""', &mapChanged)
    c := EnsureConfigMapEntry(c, "Extensions", "FieldFollowingHiveRedirect", '"Blue Flower"', &mapChanged)
    c := EnsureConfigMapEntry(c, "Extensions", "PFieldBoosted", 0, &mapChanged)
    c := EnsureConfigMapEntry(c, "Extensions", "PreGlitterCheck", 0, &mapChanged)
    if patchMondoHop {
        c := EnsureConfigMapEntry(c, "Extensions", "AltHopMondoEnabled", 0, &mapChanged)
        c := EnsureConfigMapEntry(c, "Extensions", "AltHopMondoLeadTime", 1.5, &mapChanged)
        c := EnsureConfigMapEntry(c, "Extensions", "AltHopMondoState", 0, &mapChanged)
        c := EnsureConfigMapEntry(c, "Extensions", "AltHopMondoLastTime", 0, &mapChanged)
        c := EnsureConfigMapEntry(c, "Extensions", "MondoHopLootTime", 45, &mapChanged)
    }
    c := EnsureConfigMapEntry(c, "Boost", "BlueBoosterInterruptCheck", patchBfb ? 1 : 0, &mapChanged)
    c := EnsureConfigMapEntry(c, "Boost", "LastBlueBoostUse", 1, &mapChanged)
    c := EnsureConfigMapEntry(c, "Boost", "StickerStackInterruptCheck", patchStickerStack ? 1 : 0, &mapChanged)
    c := EnsureConfigMapEntry(c, "Boost", "LastStickerStackUse", 1, &mapChanged)
    c := EnsureConfigMapEntry(c, "Extensions", "MondoInterruptCheck", 1, &mapChanged)
    c := EnsureConfigMapEntry(c, "Extensions", "EnzymesBoostedOnly", 1, &mapChanged)
    c := EnsureConfigMapEntry(c, "Extensions", "ReconnectSyncCheck", 1, &mapChanged)
    c := EnsureConfigMapEntry(c, "Extensions", "ReconnectSyncMode", '"Main"', &mapChanged)
    c := EnsureConfigMapEntry(c, "Extensions", "ReconnectSyncChannelID", '""', &mapChanged)
    c := NormalizeExtensionsConfig(c)
    if InStr(c, 'config["Settings"]') {
        cNew := RegExReplace(c, 'm)\R\s*, "EnzymesBoostedOnly", [^\r\n]+', '', &removedLegacyEnzymeConfigCount, 1)
        if (removedLegacyEnzymeConfigCount > 0 && cNew != c) {
            c := cNew
            FileAppend("? Removed legacy Settings EnzymesBoostedOnly config entry`n", logFile)
        }
    }

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
        'MainGui.Add("GroupBox", "x5 y23 w165 h105", "Extensions")',
        'MainGui.Add("GroupBox", "x175 y23 w155 h105", "Interupts")',
        'MainGui.Add("GroupBox", "x335 y23 w155 h105", "Extras")',
        '',
        'MainGui.SetFont("s8 cDefault Norm", "Tahoma")',
        '',
        fieldFollowingButtonLine,
        statMonitorButtonLine,
        blueBoosterLine,
        stickerStackLine,
        mondoInterruptLine,
        glitterExtendLine,
        preGlitterLine,
        enzymeLine,
        'MainGui.Add("Text", "x12 y134 w476 Center c666666", "Made by: @definetlynotray")',
        'MainGui.Add("Text", "x12 y146 w476 Center c666666", "Inspired by @baspas")'
    )

    if InStr(c, '"TadSync"')
        c := StrReplace(c, '"TadSync"', '"Extensions"')
    if (tabArrPos := InStr(c, 'TabArr := ')) {
        tabArrBlock := SubStr(c, tabArrPos, 250)
        if InStr(tabArrBlock, '"Extensions"')
            c := NormalizeDelimitedBlock(c, '(TabArr\s*:=\s*\[)(.*?)(\])', "tabs", &tabArrChanged)
        else
            c := RegExReplace(c, '(TabArr\s*:=\s*\[)(.*?)(\])', '$1$2, "Extensions"$3', , 1)
    }
    if InStr(c, oldMondoButton)
        c := StrReplace(c, oldMondoButton "`r`n", "")
    if InStr(c, oldBoostGroup)
        c := StrReplace(c, oldBoostGroup "`r`n`r`n", "")
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
    c := RegExReplace(
        c,
        'MainGui\.Add\("Button", "x15 y70 w150 h20 vStatMonitorEditorGUI(?: Disabled)?", "StatMonitor Editor"\)(?:\.OnEvent\("Click", aq_StatMonitorThemeEditorGUI\))?',
        statMonitorButtonLine,
        ,
        1
    )
    c := StrReplace(c, 'MainGui.Add("GroupBox", "x175 y23 w315 h80", "Interupts & Extras")', 'MainGui.Add("GroupBox", "x175 y23 w155 h105", "Interupts")`r`nMainGui.Add("GroupBox", "x335 y23 w155 h105", "Extras")')
    c := StrReplace(c, 'MainGui.Add("Text", "x12 y109 w476 Center c666666", "Made by: @definetlynotray")`r`nMainGui.Add("Text", "x12 y121 w476 Center c666666", "Inspired by @baspas")', 'MainGui.Add("Text", "x12 y134 w476 Center c666666", "Made by: @definetlynotray")`r`nMainGui.Add("Text", "x12 y146 w476 Center c666666", "Inspired by @baspas")')
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
        }
    }
    c := EnsureExtensionsEnzymeControl(c)
    if InStr(c, "nm_LockTabs") {
        lockTabsPos := InStr(c, "nm_LockTabs")
        lockTabsBlock := SubStr(c, lockTabsPos, 250)
        if InStr(lockTabsBlock, '"Extensions"')
            c := NormalizeDelimitedBlock(c, '(static tabs\s*:=\s*\[)(.*?)(\])', "locktabs", &lockTabsChanged)
        else
            c := RegExReplace(c, '(static tabs\s*:=\s*\[)(.*?)(\])', '$1$2, "Extensions", "Extensions", "Extensions", "Extensions", "Extensions", "Extensions"$3', , 1)
    }

    newFuncs := '`r`nnm_TabExtensionsLock(){`r`n'
        . '`tMainGui["FieldFollowingGUI"].Enabled := 0`r`n'
        . '`tMainGui["StatMonitorEditorGUI"].Enabled := 0`r`n'
        . '`tMainGui["ReconnectSyncGUI"].Enabled := 0`r`n'
        . '`tMainGui["PFieldBoosted"].Enabled := 0`r`n'
        . '`tMainGui["PreGlitterCheck"].Enabled := 0`r`n'
        . '`tMainGui["BlueBoosterInterruptCheck"].Enabled := 0`r`n'
        . '`tMainGui["StickerStackInterruptCheck"].Enabled := 0`r`n'
        . '`tMainGui["MondoInterruptCheck"].Enabled := 0`r`n'
        . '`tMainGui["EnzymesBoostedOnly"].Enabled := 0`r`n'
        . '}`r`nnm_TabExtensionsUnLock(){`r`n'
        . extensionsUnlockExtras
        . '`tMainGui["FieldFollowingGUI"].Enabled := 1`r`n'
        . '`tMainGui["StatMonitorEditorGUI"].Enabled := 1`r`n'
        . '`tMainGui["ReconnectSyncGUI"].Enabled := 1`r`n'
        . '`tMainGui["PFieldBoosted"].Enabled := 1`r`n'
        . '`tMainGui["PreGlitterCheck"].Enabled := 1`r`n'
        . '`tMainGui["BlueBoosterInterruptCheck"].Enabled := 1`r`n'
        . '`tMainGui["StickerStackInterruptCheck"].Enabled := 1`r`n'
        . '`tMainGui["MondoInterruptCheck"].Enabled := 1`r`n'
        . '`tMainGui["EnzymesBoostedOnly"].Enabled := 1`r`n'
        . '}`r`nnm_TabTadSyncLock(){`r`n`tnm_TabExtensionsLock()`r`n}`r`nnm_TabTadSyncUnLock(){`r`n`tnm_TabExtensionsUnLock()`r`n}'
    oldFuncs := '`r`nnm_TabTadSyncLock(){`r`n`tMainGui["FieldFollowingGUI"].Enabled := 0`r`n`tMainGui["MondoHopGUI"].Enabled := 0`r`n}`r`nnm_TabTadSyncUnLock(){`r`n`tMainGui["FieldFollowingGUI"].Enabled := 1`r`n`tMainGui["MondoHopGUI"].Enabled := 1`r`n}'
    cNew := StrReplace(c, oldFuncs, newFuncs)
    if (cNew != c)
        c := cNew
    else if InStr(c, "nm_TabExtensionsLock") {
        c := RegExReplace(c, '(?s)`r`nnm_TabExtensionsLock\(\)\{.*?\}`r`nnm_TabExtensionsUnLock\(\)\{.*?\}(?:`r`nnm_TabTadSyncLock\(\)\{.*?\}`r`nnm_TabTadSyncUnLock\(\)\{.*?\})?', newFuncs, , 1)
    } else
        c .= newFuncs

    if patchMondoInterrupt {
        cNew := StrReplace(c, ', "LastMondoBuff", 1`r`n`t`t, "MondoInterruptCheck", 1', ', "LastMondoBuff", 1')
        if (cNew != c) {
            c := cNew
            FileAppend("? Removed legacy Collect config copy of Mondo Interrupt`n", logFile)
        }

        cNew := StrReplace(c, '(GuiCtrl := MainGui.Add("CheckBox", "x+8 yp-2 vMondoInterruptCheck Disabled Hidden Checked" MondoInterruptCheck, "Int")).Section := "Collect", GuiCtrl.OnEvent("Click", nm_saveConfig)`r`n', "")
        cNew := StrReplace(cNew, 'MainGui["MondoBuffCheck"].Enabled := 0`r`n`tMainGui["MondoSecs"].Enabled := 0`r`n`tMainGui["MondoInterruptCheck"].Enabled := 0', 'MainGui["MondoBuffCheck"].Enabled := 0`r`n`tMainGui["MondoSecs"].Enabled := 0')
        cNew := StrReplace(cNew, 'MainGui["MondoBuffCheck"].Enabled := 1`r`n`tMainGui["MondoSecs"].Enabled := 1`r`n`tMainGui["MondoInterruptCheck"].Enabled := 1', 'MainGui["MondoBuffCheck"].Enabled := 1`r`n`tMainGui["MondoSecs"].Enabled := 1')
        cNew := StrReplace(cNew, '"ClockCheck","MondoBuffCheck","MondoAction","MondoInterruptCheck","AntPassCheck"', '"ClockCheck","MondoBuffCheck","MondoAction","AntPassCheck"')
        cNew := StrReplace(cNew, 'MondoBuffControls := ["MondoSecs", "MondoSecsText", "MondoInterruptCheck"]', 'MondoBuffControls := ["MondoSecs", "MondoSecsText"]')
        if (cNew != c) {
            c := cNew
            FileAppend("? Removed legacy Collect-tab Mondo Interrupt wiring`n", logFile)
        }

        mondoInterruptOld := JoinLines(
            'nm_MondoInterrupt() => (mondointerrupt_ShouldTrigger() || (utc_min := FormatTime(A_NowUTC, "m"), now := nowUnix(),',
            '`t((MondoBuffCheck = 1) && ((utc_min<14 && (now-LastMondoBuff)>960 && MondoAction="Kill")',
            '`t`t|| (!nm_GatherBoostInterrupt()',
            '`t`t`t&& (((MondoInterruptCheck != 1) && utc_min<14 && (now-LastMondoBuff)>960 && MondoAction="Buff")',
            '`t`t`t|| (utc_min<12 && (now-LastGuid)<60 && PMondoGuid && MondoAction="Guid")',
            '`t`t`t|| (utc_min<=8 && (now-LastMondoBuff)>960 && PMondoGuid && MondoAction="Tag")))',
            '`t`t)',
            '`t)',
            '))'
        )
        mondoInterruptNew := JoinLines(
            'nm_MondoInterrupt(){',
            '`tglobal FieldName, state',
            '`tmondoTriggered := mondointerrupt_ShouldTrigger() || (utc_min := FormatTime(A_NowUTC, "m"), now := nowUnix(),',
            '`t`t((MondoBuffCheck = 1) && ((utc_min<14 && (now-LastMondoBuff)>960 && MondoAction="Kill")',
            '`t`t`t|| (!nm_GatherBoostInterrupt()',
            '`t`t`t`t&& (((MondoInterruptCheck != 1) && utc_min<14 && (now-LastMondoBuff)>960 && MondoAction="Buff")',
            '`t`t`t`t|| (utc_min<12 && (now-LastGuid)<60 && PMondoGuid && MondoAction="Guid")',
            '`t`t`t`t|| (utc_min<=8 && (now-LastMondoBuff)>960 && PMondoGuid && MondoAction="Tag")))',
            '`t`t)',
            '`t)',
            '`tif (!mondoTriggered)',
            '`t`treturn 0',
            '`tif (nm_IsBoostLeaseNearWindow()) {',
            '`t`tif (state = "Converting")',
            '`t`t`tnm_ConvertRenewGlitter(FieldName)',
            '`t`telse',
            '`t`t`tnm_DebugGlitterPress("Mondo Interrupt (Warning Window)", FieldName)',
            '`t`treturn 0',
            '`t}',
            '`treturn 1',
            '}'
        )
        cNew := StrReplace(c, mondoInterruptOld, mondoInterruptNew)
        if (cNew != c) {
            c := cNew
            FileAppend("? Extended nm_MondoInterrupt() with standalone Mondo Interrupt trigger`n", logFile)
        }

        mondoPlanterIgnoreBlock := JoinLines(
            'nm_MondoPlanterIgnore() => (',
            '`tutc_min := FormatTime(A_NowUTC, "m"),',
            '`t(utc_min>=55 || utc_min=0)',
            ')'
        )
        mondoGatherCleanupBlock := JoinLines(
            'nm_MondoGatherInterruptCleanup() {',
            '`tglobal PMondoGuidComplete',
            '`tClick "Up"',
            '`tnm_endWalk()',
            '`tnm_setShiftLock(0)',
            '`tif (PMondoGuidComplete)',
            '`t`tPMondoGuidComplete := 0',
            '}'
        )
        if !(InStr(c, 'nm_MondoPlanterIgnore() => (') || InStr(c, 'nm_MondoPlanterIgnore() {')) {
            cNew := RegExReplace(c, 'm)^nm_BeesmasInterrupt\(\) \{', mondoPlanterIgnoreBlock "`r`n`r`nnm_BeesmasInterrupt() {", , 1)
            if (cNew = c)
                cNew := StrReplace(c, mondoInterruptNew, mondoInterruptNew "`r`n`r`n" mondoPlanterIgnoreBlock)
            if (cNew != c) {
                c := cNew
                FileAppend("? Added Mondo planter ignore window helper`n", logFile)
            } else {
                FileAppend("! Failed to insert Mondo planter ignore window helper`n", logFile)
            }
        }
        if !(InStr(c, 'nm_MondoGatherInterruptCleanup() {') || InStr(c, 'nm_MondoGatherInterruptCleanup() => (')) {
            if InStr(c, 'nm_MondoPlanterIgnore() => (')
                cNew := StrReplace(c, mondoPlanterIgnoreBlock, mondoPlanterIgnoreBlock "`r`n`r`n" mondoGatherCleanupBlock)
            else
                cNew := StrReplace(c, mondoInterruptNew, mondoInterruptNew "`r`n`r`n" mondoPlanterIgnoreBlock "`r`n`r`n" mondoGatherCleanupBlock)
            if (cNew != c) {
                c := cNew
                FileAppend("? Added shared Mondo gather cleanup helper`n", logFile)
            } else {
                FileAppend("! Failed to insert shared Mondo gather cleanup helper`n", logFile)
            }
        }

        mondoHandleNeedle := JoinLines(
            '	global MondoBuffCheck, PMondoGuid, LastGuid, MondoAction, LastMondoBuff, PMondoGuidComplete, GatherFieldBoostedStart, LastGlitter',
            '	if nm_NightInterrupt()',
            '		return',
            '	if nm_MondoInterrupt(){'
        )
        mondoHandleInsert := JoinLines(
            '	global MondoBuffCheck, PMondoGuid, LastGuid, MondoAction, LastMondoBuff, PMondoGuidComplete, GatherFieldBoostedStart, LastGlitter',
            '	if nm_NightInterrupt()',
            '		return',
            '	if mondointerrupt_Handle()',
            '		return',
            '	if (MondoInterruptCheck = 1 && MondoBuffCheck = 1 && MondoAction = "Buff")',
            '		return',
            '	if nm_MondoInterrupt(){'
        )
        cNew := StrReplace(c, mondoHandleNeedle, mondoHandleInsert)
        if (cNew != c) {
            c := cNew
            FileAppend("? Added standalone Mondo Interrupt handler entry to nm_Mondo()`n", logFile)
        }

        planterMondoGuardOld := 'if (nm_NightInterrupt() || nm_MondoInterrupt() || nm_GatherBoostInterrupt())'
        planterMondoGuardNew := 'if (nm_NightInterrupt() || nm_MondoInterrupt() || nm_GatherBoostInterrupt() || nm_MondoPlanterIgnore())'
        cNew := StrReplace(c, planterMondoGuardOld, planterMondoGuardNew)
        if (cNew != c) {
            c := cNew
            FileAppend("? Added Mondo planter guard to planter loops`n", logFile)
        }
    }

    ; 1l2. Inject field_type determination before FDC switch (for per-booster glitter timing)
    if (patchGlitterExtend) {
    if !InStr(c, 'field_type := "None"') {
        pattern := ';set FDC switch'
        fieldTypeCode := '`t;set field colour (for per-booster glitter timing)`r`n`tfield_type := "None"`r`n`tif (FieldName="Pine Tree" || FieldName="Bamboo" || FieldName="Blue Flower" || FieldName="Stump")`r`n`t`tfield_type := "Blue"`r`n`tif (FieldName="Rose" || FieldName="Strawberry" || FieldName="Mushroom" || FieldName="Pepper")`r`n`t`tfield_type := "Red"`r`n`tif (FieldName="Sunflower" || FieldName="Dandelion" || FieldName="Clover" || FieldName="Spider" || FieldName="Cactus" || FieldName="Pumpkin" || FieldName="Pineapple")`r`n`t`tfield_type := "Mountain"`r`n`r`n`t;set FDC switch'
        c := StrReplace(c, pattern, fieldTypeCode)
        FileAppend("✓ Injected field_type determination logic`n", logFile)
    }

    ; 1l2b. Keep boost expiry on one shared deadline so Glitter Extend only
    ; updates the end time, not the timer source used by every check.
    gatherBoostInterruptOld := 'nm_GatherBoostInterrupt() => (now := nowUnix(), ((now-GatherFieldBoostedStart<900) || (now-LastGlitter<900) || nm_boostBypassCheck()))'
    gatherBoostInterruptNew := JoinLines(
        'nm_GetBoostChaseDeadline() {',
        '	global GatherFieldBoostedStart, LastGlitter',
        '	boostDeadline := GatherFieldBoostedStart + 900',
        '	if (LastGlitter > GatherFieldBoostedStart)',
        '		boostDeadline := LastGlitter + 900',
        '	return boostDeadline',
        '}',
        '',
        'nm_GatherBoostInterrupt() {',
        '	nm_ExpireBoostLeaseIfOver()',
        '	now := nowUnix()',
        '	return (now < nm_GetBoostChaseDeadline()) || nm_boostBypassCheck()',
        '}'
    )
    cNew := StrReplace(c, gatherBoostInterruptOld, gatherBoostInterruptNew)
    if (cNew != c) {
        c := cNew
        FileAppend("? Restored GatherBoostInterrupt to shared deadline logic`n", logFile)
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
        '`tglobal PreGlitterCheck, GlitterKey, LastGlitter, LastBlueBoostUse, BoostLeaseNearDiscordNotice, PendingStickerStackAfterExtend',
        '',
        '`tif (!PreGlitterCheck || GlitterKey = "none" || fieldName != "Pine Tree" || field_type != "Blue")',
        '`t`treturn 0',
        '',
        '`tlastUse := (LastBlueBoostUse = "" ? 0 : LastBlueBoostUse)',
        '`tif (lastUse <= 0 || (nowUnix() - LastGlitter) <= 900)',
        '`t`treturn 0',
        '',
        '`ttimeUntilBlueReady := 2700 - (nowUnix() - lastUse)',
        '`treturn (timeUntilBlueReady <= 660 && timeUntilBlueReady > 600)',
        '}',
        'nm_HandlePinePreGlitter(fieldName, field_type){',
        '`tglobal GlitterKey, LastGlitter, GatherFieldBoostedStart, fieldOverrideReason, BoostLeaseNearDiscordNotice, PendingStickerStackAfterExtend',
        '',
        '`tif !nm_ShouldUsePinePreGlitter(fieldName, field_type)',
        '`t`treturn 0',
        '',
        '`tnm_SpamGlitterKey()',
        '`tnm_DebugGlitterPress("Pine pre-glitter", fieldName)',
        '`tLastGlitter := nowUnix()',
        '`tfieldOverrideReason := "Boost"',
        '`tBoostLeaseNearDiscordNotice := 0',
        '`tif (PendingStickerStackAfterExtend)',
        '`t`t`tnm_RunPendingStickerStackAfterExtend()',
        '`tIniWrite LastGlitter, "settings\nm_config.ini", "Boost", "LastGlitter"',
        '`tIniWrite fieldName, "settings\nm_config.ini", "Boost", "LastBoostedField"',
        '`tnm_setStatus("Boosted", "Pre-Glitter: Pine Tree")',
        '`treturn 1',
        '}',
        'nm_DiscordEscapeContent(text){',
        '`ttext := StrReplace(text, Chr(92), Chr(92) Chr(92))',
        '`ttext := StrReplace(text, Chr(34), Chr(92) Chr(34))',
        '`ttext := StrReplace(text, "``r``n", "\n")',
        '`ttext := StrReplace(text, "``n", "\n")',
        '`ttext := StrReplace(text, "``r", "\n")',
        '`treturn text',
        '}',
        'nm_ResolveBoostLeaseDiscordChannel(){',
        '`tglobal discordMode, ReportChannelCheck, ReportChannelID, MainChannelCheck, MainChannelID',
        '',
        '`tif (discordMode = 0)',
        '`t`treturn ""',
        '`tif (ReportChannelCheck && ReportChannelID)',
        '`t`treturn ReportChannelID',
        '`tif (MainChannelCheck && MainChannelID)',
        '`t`treturn MainChannelID',
        '`treturn ""',
        '}',
        'nm_NotifyBoostLeaseDiscord(eventText, reason := "", fieldName := ""){',
        '`tglobal discordMode, webhook',
        '`tmessage := eventText',
        '`tif (reason != "")',
        '`t`tmessage .= " | Reason: " reason',
        '`tif (fieldName != "")',
        '`t`tmessage .= " | Field: " fieldName',
        '`tpayload := "{" Chr(34) "content" Chr(34) ":" Chr(34) nm_DiscordEscapeContent(message) Chr(34) "}"',
        '`tif (discordMode = 0) {',
        '`t`tif (webhook = "")',
        '`t`t`treturn 0',
        '`t`ttry discord.SendMessageAPI(payload)',
        '`t`treturn 1',
        '`t}',
        '`tchannel := nm_ResolveBoostLeaseDiscordChannel()',
        '`tif (channel = "")',
        '`t`treturn 0',
        '`ttry discord.SendMessageAPI(payload, "application/json", channel)',
        '`treturn 1',
        '}',
        'nm_DebugGlitterPress(sourceLabel := "", fieldName := ""){',
        '`treturn nm_NotifyBoostLeaseDiscord("Glitter Key Pressed", sourceLabel, fieldName)',
        '}'
    )
    if InStr(c, pinePreGlitterNeedle) && !InStr(c, 'nm_HandlePinePreGlitter(fieldName, field_type)') {
        c := StrReplace(c, pinePreGlitterNeedle, pinePreGlitterInsert)
        FileAppend("? Added Pine pre-glitter helper functions`n", logFile)
    }

    canonicalFieldBoostCheck :=
    (
        'nm_fieldBoostCheck(fieldName, variant:=0, timeLeft?){`r`n'
        . '`tglobal AutoFieldBoostActive`r`n'
        . '`tstatic isWind(c) => ((((c) & 0x00FF0000 >= 0x00a60000) && ((c) & 0x00FF0000 <= 0x00cf0000))`r`n'
        . '`t`t`t`t&& (((c) & 0x0000FF00 >= 0x0000b200) && ((c) & 0x0000FF00 <= 0x0000db00))`r`n'
        . '`t`t`t`t&& (((c) & 0x000000FF >= 0x000000b8) && ((c) & 0x000000FF <= 0x000000e1)))`r`n'
        . '`tstatic isBooster(c) => ((((c) & 0x00FF0000 >= 0x00b80000) && ((c) & 0x00FF0000 <= 0x00e10000))`r`n'
        . '`t`t`t`t&& (((c) & 0x0000FF00 >= 0x0000a400) && ((c) & 0x0000FF00 <= 0x0000cd00))`r`n'
        . '`t`t`t`t&& (((c) & 0x000000FF >= 0x0000003a) && ((c) & 0x000000FF <= 0x00000063)))`r`n'
        . '`r`n'
        . '`tGetRobloxClientPos(hwnd:=GetRobloxHWND())`r`n'
        . '`toffsetY := GetYOffset(hwnd)`r`n'
        . '`tretryAttempts := 20`r`n'
        . '`twhile (retryAttempts--) {`r`n'
        . '`t`tpBMScreen := Gdip_BitmapFromScreen(windowX "|" windowY + offsetY + 36 "|" windowWidth "|" 38)`r`n'
        . '`t`tloop Floor(windowWidth/38) {`r`n'
        . '`t`t`tico := (A_Index - 1) * 38`r`n'
        . '`t`t`tif !(Gdip_ImageSearch(pBMScreen, bitmaps["boost"][StrReplace(fieldName, " ") variant],,ico,,ico+38,,(variant=1 || variant=0) ? 35 : 50))`r`n'
        . '`t`t`t`tcontinue`r`n'
        . '`t`t`tp := Gdip_GetPixel(pBMScreen, ico, 37)`r`n'
        . '`t`t`tif isWind(p)`r`n'
        . '`t`t`t`tcontinue`r`n'
        . '`t`t`telse if !isBooster(p) {`r`n'
        . '`t`t`t`tGdip_DisposeImage(pBMScreen)`r`n'
        . '`t`t`t`treturn 0`r`n'
        . '`t`t`t}`r`n'
        . '`t`t`tif !IsSet(timeLeft) {`r`n'
        . '`t`t`t`tGdip_DisposeImage(pBMScreen)`r`n'
        . '`t`t`t`treturn 1`r`n'
        . '`t`t`t}`r`n'
        . '`t`t`tif !isBooster(Gdip_GetPixel(pBMScreen, ico, 37)) {`r`n'
        . '`t`t`t`tSleep 15`r`n'
        . '`t`t`t`tbreak`r`n'
        . '`t`t`t}`r`n'
        . '`t`t`tbottomY := high := 37, low := 0`r`n'
        . '`t`t`twhile (low < high) {`r`n'
        . '`t`t`t`tmid := Floor((low + high) / 2)`r`n'
        . '`t`t`t`tif isBooster(Gdip_GetPixel(pBMScreen, ico, mid))`r`n'
        . '`t`t`t`t`thigh := mid`r`n'
        . '`t`t`t`telse`r`n'
        . '`t`t`t`t`tlow := mid + 1`r`n'
        . '`t`t`t}`r`n'
        . '`t`t`tGdip_DisposeImage(pBMScreen)`r`n'
        . '`t`t`treturn Round((bottomY - low) / 38, 2)`r`n'
        . '`t`t}`r`n'
        . '`t`tGdip_DisposeImage(pBMScreen)`r`n'
        . '`t}`r`n'
        . '`tif (AutoFieldBoostActive && fieldName = "Pine Tree") {`r`n'
        . '`t`tfor _, pineFallbackName in ["pine trees 1.png", "pine trees 2.png", "pine trees 3.png"] {`r`n'
        . '`t`t`tif FileExist(A_WorkingDir "\nm_image_assets\" pineFallbackName) && (nm_imgSearch(pineFallbackName, (variant=1) ? 30 : 50, "low")[1] = 0)`r`n'
        . '`t`t`treturn IsSet(timeLeft) ? 1 : 1`r`n'
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
    cNew := RegExReplace(c, '(?ms)^nm_fieldBoostCheck\(fieldName, variant:=0(?:, timeLeft\?)?\)\{.*?^\}\r?\n(?=nm_fieldBoostBooster\(\)\{)', canonicalFieldBoostCheck "`r`n", &fieldBoostCheckCount, 1)
    if (fieldBoostCheckCount > 0 && cNew != c) {
        c := cNew
        FileAppend("? Added Pine Tree anti-drop fallback to nm_fieldBoostCheck()`n", logFile)
    }

    cNew := RegExReplace(c, '(?m)^(\t*)FieldLastBoosted:=nowUnix\(\)\r?\n(?!\1nm_ArmBoostLease\(CurrentField\))', '$1FieldLastBoosted:=nowUnix()`r`n$1nm_ArmBoostLease(CurrentField)`r`n', &armLeaseCount)
    if (armLeaseCount > 0 && cNew != c) {
        c := cNew
        FileAppend("? Armed boost lease when field boost was confirmed`n", logFile)
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
        FileAppend("? Made boosted gather confirmation respect per-field toggles`n", logFile)
    }

    c := StrReplace(c, JoinLines('`t`t`tfor key, value in blueBoosterFields {', '`t`t`t`tif(nm_fieldBoostCheck(value, 3) && FieldName=value) {'), JoinLines('`t`t`tfor value, enabled in blueBoosterFields {', '`t`t`t`tif(enabled && nm_fieldBoostCheck(value, 3) && FieldName=value) {'))
    c := StrReplace(c, JoinLines('`t`t`tfor key, value in mountainBoosterFields {', '`t`t`t`tif(nm_fieldBoostCheck(value, 3) && FieldName=value) {'), JoinLines('`t`t`tfor value, enabled in mountainBoosterFields {', '`t`t`t`tif(enabled && nm_fieldBoostCheck(value, 3) && FieldName=value) {'))
    c := StrReplace(c, JoinLines('`t`t`tfor key, value in redBoosterFields {', '`t`t`t`tif(nm_fieldBoostCheck(value, 3) && FieldName=value) {'), JoinLines('`t`t`tfor value, enabled in redBoosterFields {', '`t`t`t`tif(enabled && nm_fieldBoostCheck(value, 3) && FieldName=value) {'))
        c := ReplaceFirst(c, JoinLines('`t`t`tfor key, value in otherFields {', '`t`t`t`tif(nm_fieldBoostCheck(value, 1) && FieldName=value) {'), JoinLines('`t`t`tfor value, enabled in otherFields {', '`t`t`t`tif(enabled && nm_fieldBoostCheck(value, 1) && FieldName=value) {'))

    ; Normalize the Glitter Extend early gather branches so the only active
    ; Glitter press window stays in the late lease range.
    oldGlitterGather525 := 'if(PFieldBoosted && '
        . '(nowUnix()-GatherFieldBoostedStart)>525 && '
        . '(nowUnix()-GatherFieldBoostedStart)<900 && '
        . '(nowUnix()-LastGlitter)>900 && '
        . 'GlitterKey!="none" && fieldOverrideReason="None") { '
        . ';between 9 and 15 mins (-minus an extra 15 seconds)'
    newGlitterGather525 := 'if(PFieldBoosted && '
        . '(nowUnix()-GatherFieldBoostedStart)>870 && '
        . '(nowUnix()-GatherFieldBoostedStart)<900 && '
        . '(nowUnix()-LastGlitter)>900 && '
        . 'GlitterKey!="none" && fieldOverrideReason="None") { '
        . ';between 14.5 and 15 mins'
    c := StrReplace(c, oldGlitterGather525, newGlitterGather525)
    c := StrReplace(c,
        '`t`t`t`t`t`tSend "{" GlitterKey "}"',
        '`t`t`t`t`t`tnm_SpamGlitterKey()')
    c := StrReplace(c,
        '`t`t`t`t`tSend "{" GlitterKey "}"',
        '`t`t`t`t`tnm_SpamGlitterKey()')
    c := StrReplace(c,
        '`t`t`t`tSend "{" GlitterKey "}"',
        '`t`t`t`tnm_SpamGlitterKey()')
    oldGlitterGather600 := 'if(PFieldBoosted && '
        . '(nowUnix()-GatherFieldBoostedStart)>600 && '
        . '(nowUnix()-GatherFieldBoostedStart)<900 && '
        . '(nowUnix()-LastGlitter)>900 && '
        . 'GlitterKey!="none" && (fieldOverrideReason="None" || fieldOverrideReason="Boost")){ '
        . ';between 10 and 15 mins'
    newGlitterGather600 := 'if(PFieldBoosted && '
        . '(nowUnix()-GatherFieldBoostedStart)>830 && '
        . '(nowUnix()-GatherFieldBoostedStart)<900 && '
        . '(nowUnix()-LastGlitter)>900 && '
        . 'GlitterKey!="none" && (fieldOverrideReason="None" || fieldOverrideReason="Boost")){ '
        . ';between 13.8 and 15 mins'
    c := StrReplace(c, oldGlitterGather600, newGlitterGather600)
    c := StrReplace(c,
        '`t`t`t`t`t`t`tSend "{" GlitterKey "}"',
        '`t`t`t`t`t`t`tnm_SpamGlitterKey()')
    c := StrReplace(c,
        '`t`t`t`t`t`tSend "{" GlitterKey "}"',
        '`t`t`t`t`t`tnm_SpamGlitterKey()')

    gatherGlitterOld := JoinLines(
        '`t`t`t`t' newGlitterGather525,
        '`t`t`t`t`tnm_SpamGlitterKey()',
        '`t`t`t`t`tLastGlitter:=nowUnix()',
        '`t`t`t`t`tIniWrite LastGlitter, "settings\nm_config.ini", "Boost", "LastGlitter"',
        '`t`t`t`t}'
    )
    gatherGlitterNew := JoinLines(
        '`t`t`t`t' newGlitterGather525,
        '`t`t`t`t`tnm_SpamGlitterKey()',
        '`t`t`t`t`tLastGlitter:=nowUnix()',
        '`t`t`t`t`tIniWrite LastGlitter, "settings\nm_config.ini", "Boost", "LastGlitter"',
        '`t`t`t`t`tnm_DebugGlitterPress("Gather", FieldName)',
        '`t`t`t`t`tnm_setStatus("Boosted", "Glitter: Gather")',
        '`t`t`t`t}'
    )
    cNew := StrReplace(c, gatherGlitterOld, gatherGlitterNew)
    if (cNew != c) {
        c := cNew
        FileAppend("? Added Glitter gather status label`n", logFile)
    }

    backpackGlitterOld := JoinLines(
        '`t`t`t`t`t`t' newGlitterGather600,
        '`t`t`t`t`t`t`tnm_SpamGlitterKey()',
        '`t`t`t`t`t`t`tLastGlitter:=nowUnix()',
        '`t`t`t`t`t`t`tIniWrite LastGlitter, "settings\nm_config.ini", "Boost", "LastGlitter"',
        '`t`t`t`t`t`t}'
    )
    backpackGlitterNew := JoinLines(
        '`t`t`t`t`t`t' newGlitterGather600,
        '`t`t`t`t`t`t`tnm_SpamGlitterKey()',
        '`t`t`t`t`t`t`tLastGlitter:=nowUnix()',
        '`t`t`t`t`t`t`tIniWrite LastGlitter, "settings\nm_config.ini", "Boost", "LastGlitter"',
        '`t`t`t`t`t`t`tnm_DebugGlitterPress("Backpack", FieldName)',
        '`t`t`t`t`t`t`tnm_setStatus("Boosted", "Glitter: Backpack")',
        '`t`t`t`t`t`t}'
    )
    cNew := StrReplace(c, backpackGlitterOld, backpackGlitterNew)
    if (cNew != c) {
        c := cNew
        FileAppend("? Added Glitter backpack status label`n", logFile)
    }

    ; Glitter Extend now uses managed boost-lease templates later in the patch flow.
    ; The older direct early-glitter gather rewrites are intentionally skipped here so
    ; there is only one canonical source of truth for gather and convert timing.

    }

    ; 1l6. Bitterberry feeder: replace the full function with the synced mutation-aware version
    if (patchAutoBitter) {
    if (bbStart := InStr(c, 'nm_BitterberryFeeder(*)')) && (bbEnd := InStr(c, 'nm_BasicEggHatcher(*)', , bbStart)) {
        bb := SubStr(c, bbStart, bbEnd - bbStart)
        bbPatched := ReadPatchBlock(patchTemplateDir "\bitterberry_full_patch.txt")
        if (bbPatched = "") {
            FileAppend("? Skipped Bitterberry sync because patch_templates\\bitterberry_full_patch.txt is missing`n", logFile)
        } else if (bb != bbPatched) {
            c := SubStr(c, 1, bbStart-1) bbPatched SubStr(c, bbEnd)
            FileAppend("✓ Synced full Bitterberry feeder mutation patch`n", logFile)
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
            FileAppend("? Skipped Auto-Jelly sync because patch_templates\\autojelly_full_patch.txt is missing`n", logFile)
        } else if !RegExMatch(ajPatched, 's)(?=\s*nm_RoyalJellyDis\(\)\{)', &templateEnd)
            templateEnd := 0
        else
            templateEnd := templateEnd.Pos
        if templateEnd
            ajPatched := RTrim(SubStr(ajPatched, 1, templateEnd - 1), "`r`n")
        if (ajPatched != "" && aj != ajPatched) {
            c := SubStr(c, 1, ajStart-1) ajPatched "`r`n`r`n" SubStr(c, ajEnd)
            FileAppend("✓ Synced full Auto-Jelly mutation patch`n", logFile)
        }
    } else if (InStr(c, 'blc_mutations(*) {')) {
            FileAppend("⚠ Skipped Auto-Jelly sync because the end anchor '; CREDITS TAB' was not found after blc_mutations(*)`n", logFile)
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
        FileAppend("✓ Injected tadsync_AltHopCheck into nm_MondoInterrupt`n", logFile)
    }

    ; 1m2. Ensure nm_Mondo has Alt Hop globals available
    if (pos := InStr(c, 'nm_Mondo(){')) {
        mondoBlock := SubStr(c, pos, 600)
        if !InStr(mondoBlock, 'AltHopMondoEnabled') {
            pattern := '(nm_Mondo\(\)\{\r?\n\s*global [^\r\n]*LastGlitter)'
            c := RegExReplace(c, pattern, '$1, AltHopMondoEnabled, AltHopMondoState')
            FileAppend("âœ“ Added Alt Hop globals to nm_Mondo`n", logFile)
        } else if !InStr(mondoBlock, 'AltHopMondoState') {
            pattern := '(nm_Mondo\(\)\{\r?\n\s*global [^\r\n]*AltHopMondoEnabled)'
            c := RegExReplace(c, pattern, '$1, AltHopMondoState')
            FileAppend("âœ“ Added AltHopMondoState global to nm_Mondo`n", logFile)
        }
    }

    ; 1n. Inject Mondo Sniper into DisconnectCheck
    if !InStr(c, "tadsync_MondoSniper()") {
        pattern := '(DisconnectCheck\(testCheck := 0\)\s*\{)'
        c := RegExReplace(c, pattern, '$1`r`n`ttadsync_MondoSniper()')
        FileAppend("✓ Injected Mondo Sniper into DisconnectCheck`n", logFile)
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
        
        FileAppend("✓ Injected Mondo pattern dodge logic`n", logFile)
    }
    
    ; Fix syntax error if comma operator was used with return (AHK v2 restriction)
    if InStr(c, "nm_endWalk(), return") {
        c := StrReplace(c, "nm_endWalk(), return", "nm_endWalk()`r`n`t`t`t`t`treturn")
        FileAppend("✓ Fixed Mondo dodge syntax error (comma return)`n", logFile)
    }
    if InStr(c, "nm_endWalk(), repeat:=0") {
        c := StrReplace(c, "nm_endWalk(), repeat:=0", "nm_endWalk()`r`n`t`t`t`t`trepeat:=0")
        FileAppend("✓ Fixed Mondo dodge syntax error (comma repeat)`n", logFile)
    }

    ; 1w. Give Mondo first priority in main loop (run before all other tasks)
    if !InStr(c, '; MONDO FIRST PRIORITY') {
        pattern := '(nm_Start\(\)\{[\s\S]*?)(Loop\s*\r?\n\s+for i in priorityList)'
        replacement := '$1; MONDO FIRST PRIORITY`r`n`tnm_Mondo()`r`n`t$2'
        c := RegExReplace(c, pattern, replacement)
        FileAppend("✓ Injected Mondo first priority in nm_Start`n", logFile)
    }

    ; 1p. Prevent Mondo early exit during Alt Hop (Buff bypass)
    if !InStr(c, '&& !AltHopMondoState') {
        pattern := 's)(mondobuff := nm_imgSearch\("mondobuff\.png",50,"buff"\)\r?\n\s+If \(mondobuff\[1\] = 0\)) (\{)'
        c := RegExReplace(c, pattern, '$1 && !AltHopMondoState $2')
        FileAppend("✓ Patched Mondo buff exit bypass`n", logFile)
    }

    ; 1p2. Keep nm_Mondo alive through night while Alt Hop is active
    if !InStr(c, 'AltHopMondoEnabled && tadsync_isMondoTime()') {
        pattern := 'm)^(\s*)if\s*\(\s*nm_NightInterrupt\(\)\s*\)\s*\r?\n\1\t?return'
        replacement := '$1if (nm_NightInterrupt() && !(AltHopMondoEnabled && tadsync_isMondoTime()))`r`n$1`treturn'
        cNew := RegExReplace(c, pattern, replacement, &count, 1)
        if (count > 0) {
            c := cNew
            FileAppend("âœ“ Patched nm_Mondo early night exit for Alt Hop`n", logFile)
        }
    }

    ; 1p3. Prevent the kill loop from aborting during an active Alt Hop run
    if !InStr(c, 'if(!AltHopMondoState && (nm_NightInterrupt() || AFBrollingDice || AFBuseGlitter || AFBuseBooster))') {
        pattern := 'm)if\s*\(\s*nm_NightInterrupt\(\)\s*\|\|\s*AFBrollingDice\s*\|\|\s*AFBuseGlitter\s*\|\|\s*AFBuseBooster\s*\)\s*\{'
        replacement := 'if(!AltHopMondoState && (nm_NightInterrupt() || AFBrollingDice || AFBuseGlitter || AFBuseBooster)) {'
        cNew := RegExReplace(c, pattern, replacement, &count, 1)
        if (count > 0) {
            c := cNew
            FileAppend("âœ“ Patched nm_Mondo kill-loop interrupt guard for Alt Hop`n", logFile)
        }
    }

    ; 1q. Replace loot guard with tadsync_CollectMondoLoot branching
    ; First: remove old '&& !AltHopMondoState' guard if it exists from a previous patch
    if InStr(c, '&& !AltHopMondoState {') {
        c := StrReplace(c, '!(MondoLootDirection = "Ignore") && !AltHopMondoState {', '!(MondoLootDirection = "Ignore") {')
        FileAppend("✓ Removed old AltHopMondoState loot guard`n", logFile)
    }
    ; Then: remove old inline 'if(AltHopMondoState) LastMondoBuff:=nowUnix()' if it exists
    if InStr(c, 'if(AltHopMondoState) LastMondoBuff:=nowUnix()') {
        c := StrReplace(c, "`t`t`t`t`t`tif(AltHopMondoState) LastMondoBuff:=nowUnix()`r`n", "")
        FileAppend("✓ Removed old AltHopMondoState inline LastMondoBuff`n", logFile)
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
        FileAppend("✓ Injected tadsync_CollectMondoLoot branching`n", logFile)
    }

    ; 1q2. Inject state transition signal after loot section
    if !InStr(c, 'AltHopMondoState := 1') {
        pattern := 'm)(\s+click "up"\r?\n\s+\}\r?\n)(\s+\}\r?\n\s+\}\r?\n\s+\}\r?\n\s+\}\r?\n\s+\}\r?\n\s+else)'
        replacement := '$1`t`t`t`t`t`t`t; Signal extension: kill+loot done, ready to hop`r`n`t`t`t`t`t`t`tif (AltHopMondoState) {`r`n`t`t`t`t`t`t`t`tAltHopMondoState := 1`r`n`t`t`t`t`t`t`t`tIniWrite AltHopMondoState, "settings\nm_config.ini", "Extensions", "AltHopMondoState"`r`n`t`t`t`t`t`t`t}`r`n$2'
        c := RegExReplace(c, pattern, replacement)
        FileAppend("✓ Injected AltHopMondoState transition signal`n", logFile)
    }

    ; 1q3. Clean up legacy hop signal and hand off post-Mondo flow to the extension
    legacyPattern := 'ms)\r?\n\s*; Signal extension: kill\+loot done, ready to hop\r?\n\s*if \(AltHopMondoState\) \{\r?\n\s*AltHopMondoState := 1\r?\n\s*IniWrite AltHopMondoState, "settings\\nm_config\.ini", "Extensions", "AltHopMondoState"\r?\n\s*\}\r?\n'
    if RegExMatch(c, legacyPattern) {
        c := RegExReplace(c, legacyPattern, "`r`n")
        FileAppend("âœ“ Removed legacy AltHopMondoState transition signal`n", logFile)
    }
    if !InStr(c, 'tadsync_AfterMondoAttempt()') {
        pattern := 'm)^(\s*)LastMondoBuff:=nowUnix\(\)\r?\n\1IniWrite LastMondoBuff, "settings\\nm_config\.ini", "Collect", "LastMondoBuff"\r?\n'
        replacement := '$0$1if (AltHopMondoState = 1 || AltHopMondoState = 3) {`r`n$1`tadsync_AfterMondoAttempt()`r`n$1`treturn`r`n$1}`r`n'
        cNew := RegExReplace(c, pattern, replacement, &count, 1)
        if (count > 0) {
            c := cNew
            FileAppend("âœ“ Injected tadsync_AfterMondoAttempt hook`n", logFile)
        }
    }
    afterMondoNormalizePattern := '(?m)^(\s*)LastMondoBuff:=nowUnix\(\)\r?\n^\1IniWrite LastMondoBuff, "settings\\nm_config\.ini", "Collect", "LastMondoBuff"\r?\n(?:^\1if \(AltHopMondoState = 1 \|\| AltHopMondoState = 3\) \{\r?\n^\1\tadsync_AfterMondoAttempt\(\)\r?\n^\1\treturn\r?\n^\1\}\r?\n)+^\1return\r?\n'
    afterMondoNormalizeReplace := '$1LastMondoBuff:=nowUnix()`r`n$1IniWrite LastMondoBuff, "settings\nm_config.ini", "Collect", "LastMondoBuff"`r`n$1if (AltHopMondoState = 1 || AltHopMondoState = 3) {`r`n$1`tadsync_AfterMondoAttempt()`r`n$1`treturn`r`n$1}`r`n$1return`r`n'
    cNew := RegExReplace(c, afterMondoNormalizePattern, afterMondoNormalizeReplace, &afterMondoNormalizeCount, 1)
    if (afterMondoNormalizeCount > 0 && cNew != c) {
        c := cNew
        FileAppend("? Normalized post-Mondo AltHop handoff block to working layout`n", logFile)
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
        FileAppend("✓ Patched Mondo travel/reset bypass`n", logFile)
    }

    ; 1t. Improve Mondo discovery timeout for Alt Hop
    if !InStr(c, 'loop (AltHopMondoState ? 480 : 20)') {
        pattern := 'loop 20\s*\{\s*mChick:= nm_HealthDetection\(\)'
        replacement := 'loop (AltHopMondoState ? 480 : 20)`r`n`t`t`t{`r`n`t`t`t`tmChick:= nm_HealthDetection()'
        c := RegExReplace(c, pattern, replacement)
        FileAppend("✓ Patched Mondo discovery timeout`n", logFile)
    }

    ; 1u. Simplify LastMondoBuff update (remove old conditional wrapper if present)
    if InStr(c, 'if (!AltHopMondoState || repeat = 0) {') {
        c := StrReplace(c, "`t`tif (!AltHopMondoState || repeat = 0) {`r`n`t`t`tLastMondoBuff:=nowUnix()", "`t`tLastMondoBuff:=nowUnix()")
        c := StrReplace(c, "`t`tIniWrite LastMondoBuff, `"settings\nm_config.ini`", `"Collect`", `"LastMondoBuff`"`r`n`t`t}", "`t`tIniWrite LastMondoBuff, `"settings\nm_config.ini`", `"Collect`", `"LastMondoBuff`"")
        FileAppend("✓ Simplified LastMondoBuff update`n", logFile)
    }

    ; 1u2. Allow the extension to force public/private reconnect targets during Mondo Hop
    if !InStr(c, 'overrideServer := tadsync_GetReconnectOverride(PossibleServers)') {
        pattern := 'm)^(\s*;Decide Server\r?\n)(\s*)server := (.*)$'
        replacement := '$1$2overrideServer := tadsync_GetReconnectOverride(PossibleServers)`r`n$2server := (overrideServer >= 0) ? overrideServer : $3'
        cNew := RegExReplace(c, pattern, replacement, &count, 1)
        if (count > 0) {
            c := cNew
            FileAppend("âœ“ Injected reconnect override hook`n", logFile)
        }
    }

    ; 1u3. Notify the extension when reconnect succeeds so it can advance hop state
    if !InStr(c, 'tadsync_OnReconnectSuccess(server)') {
        pattern := 'm)^(\s*)if \(testCheck \|\| \(nm_claimHiveSlot\(\) = 1\)\)$'
        replacement := '$1tadsync_OnReconnectSuccess(server)`r`n$1if (testCheck || (nm_claimHiveSlot() = 1))'
        cNew := RegExReplace(c, pattern, replacement, &count, 1)
        if (count > 0) {
            c := cNew
            FileAppend("âœ“ Injected reconnect success hook`n", logFile)
        }
    }
    }

    ; 1v. Rename GUI to "Mondo Hop" and add loot time edit
    if InStr(c, '"Mondo Alt Hop"') {
        c := StrReplace(c, '"Mondo Alt Hop"', '"Mondo Hop"')
        FileAppend("✓ Renamed group box to Mondo Hop`n", logFile)
    }
    if InStr(c, '"Alt Hop: ON"') {
        c := StrReplace(c, '"Alt Hop: ON"', '"Mondo Hop: ON"')
        c := StrReplace(c, '"Alt Hop: OFF"', '"Mondo Hop: OFF"')
        FileAppend("✓ Renamed toggle to Mondo Hop`n", logFile)
    }
    if !InStr(c, 'vMondoHopLootTimeEdit') {
        pattern := '(MainGui\.Add\("Button", "x310 y81 w80 h22 vAltHopMondoTest", "Test Mondo"\)\.OnEvent\("Click", tadsync_AltHop_TestMondo\))'
        replacement := '$1`r`nMainGui.Add("Text", "x400 y84", "Loot Time (s):")`r`nMainGui.Add("Edit", "x460 y81 w25 h22 Number vMondoHopLootTimeEdit", MondoHopLootTime).OnEvent("Change", aq_MondoHopSaveLootTime)'
        c := RegExReplace(c, pattern, replacement)
        FileAppend("✓ Added Loot Time edit to GUI`n", logFile)
    }

    if InStr(c, 'tadsync_AltHop_SaveLootTime') {
        c := StrReplace(c, 'tadsync_AltHop_SaveLootTime', 'aq_MondoHopSaveLootTime')
        FileAppend("âœ“ Updated Loot Time callback to aq_MondoHopSaveLootTime`n", logFile)
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
                FileAppend("? Re-applied Glitter to hotbarwhilelist after later patch steps`n", logFile)
            }
        }
    }

    if (c != orig) {
        try {
            ; Ensure we don't overwrite PFieldBoosted INI value by removing it from
            ; the startup initialization list if present.
            c := RegExReplace(c, 'm)for k,v in \["PMondoGuid","PMondoGuidComplete",\s*"PFieldBoosted",', 'for k,v in ["PMondoGuid","PMondoGuidComplete",')
            try {
                ; Final Sticker Stack interrupt safety pass so helper split stays in sync.
                stickerInterruptBlock := ReadPatchBlock(stickerStackInterruptTemplatePath)
                if (stickerInterruptBlock != "") {
                    if RegExMatch(c, '(?ms)^nm_StickerStackEnabled\(\)\{.*?^\}\r?\n(?:\r?\n)?(?=nm_BlueBoosterInterrupt\(\) \{)', &stickerInterruptMatch) {
                        desiredStickerInterrupt := stickerInterruptBlock "`r`n`r`n"
                        if (stickerInterruptMatch[0] != desiredStickerInterrupt) {
                            c := StrReplace(c, stickerInterruptMatch[0], desiredStickerInterrupt)
                            FileAppend("? Normalized Sticker Stack interrupt helper block in-place`n", logFile)
                        }
                    } else if RegExMatch(c, '(?ms)^nm_StickerStackInterrupt\(\) \{.*?^\}\r?\n(?:\r?\n)?(?=nm_BlueBoosterInterrupt\(\) \{)', &legacyStickerInterruptMatch) {
                        desiredStickerInterrupt := stickerInterruptBlock "`r`n`r`n"
                        if (legacyStickerInterruptMatch[0] != desiredStickerInterrupt) {
                            c := StrReplace(c, legacyStickerInterruptMatch[0], desiredStickerInterrupt)
                            FileAppend("? Replaced legacy Sticker Stack interrupt block with helper split`n", logFile)
                        }
                    } else if InStr(c, 'nm_BlueBoosterInterrupt() {') && !InStr(c, 'nm_StickerStackEnabled() {') {
                        c := StrReplace(c, 'nm_BlueBoosterInterrupt() {', stickerInterruptBlock "`r`n`r`nnm_BlueBoosterInterrupt() {")
                        FileAppend("? Inserted Sticker Stack interrupt helper block from patch template`n", logFile)
                    }
                }
                ; Final Sticker Stack safety pass so older partial transforms cannot leave
                ; nm_StickerStack() on an older signature or retry flow.
                canonicalStickerStack := ReadPatchBlock(patchTemplateDir "\stickerstack_full_patch.txt")
                if (canonicalStickerStack != "") {
                    c := RegExReplace(c, '(?ms)^nm_StickerStack\(.*\)\{.*?^\}\r?\n(?=nm_shrine\(\)\{)', canonicalStickerStack "`r`n", , 1)
                }
            } catch as e {
                FileAppend("! Sticker Stack final sync failed: " e.Message "`n", logFile)
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
            if (patchGlitterExtend) {
                if !InStr(c, 'global LastStickerStackUse, LastGlitter, GatherFieldBoostedStart, GlitterKey, fieldOverrideReason, PFieldBoosted, ForceStickerStackInterrupt, HiveConfirmed, bitmaps, state, objective, ConvertGatherFlag, SkipBoostStickerStackUntil, AFBuseGlitter, PendingStickerStackAfterExtend')
                    c := StrReplace(c, 'global LastStickerStackUse, LastGlitter, GatherFieldBoostedStart, GlitterKey, fieldOverrideReason, PFieldBoosted, ForceStickerStackInterrupt, HiveConfirmed, bitmaps, state, objective, ConvertGatherFlag, SkipBoostStickerStackUntil, AFBuseGlitter', 'global LastStickerStackUse, LastGlitter, GatherFieldBoostedStart, GlitterKey, fieldOverrideReason, PFieldBoosted, ForceStickerStackInterrupt, HiveConfirmed, bitmaps, state, objective, ConvertGatherFlag, SkipBoostStickerStackUntil, AFBuseGlitter, PendingStickerStackAfterExtend')
                c := StrReplace(c, 'LastStickerStackUse := nowUnix()`r`n`tIniWrite LastStickerStackUse, "settings\nm_config.ini", "Boost", "LastStickerStackUse"', 'LastStickerStackUse := nowUnix()`r`n`tPendingStickerStackAfterExtend := 0`r`n`tIniWrite LastStickerStackUse, "settings\nm_config.ini", "Boost", "LastStickerStackUse"')

                leaseHelpersText := ReadPatchBlock(glitterExtendHelpersTemplatePath)
                spamGlitterNeedle := JoinLines(
                    'nm_DebugGlitterPress(sourceLabel := "", fieldName := ""){',
                    '`treturn nm_NotifyBoostLeaseDiscord("Glitter Key Pressed", sourceLabel, fieldName)',
                    '}'
                )
                spamGlitterInsert := JoinLines(
                    'nm_DebugGlitterPress(sourceLabel := "", fieldName := ""){',
                    '`treturn nm_NotifyBoostLeaseDiscord("Glitter Key Pressed", sourceLabel, fieldName)',
                    '}',
                    '',
                    'nm_SpamGlitterKey(durationMs := 5000, intervalMs := 100){',
                    '`tglobal GlitterKey',
                    '',
                    '`tif (GlitterKey = "none" || durationMs <= 0)',
                    '`t`treturn 0',
                    '`tintervalMs := (intervalMs > 0 ? intervalMs : 1)',
                    '`tstartTick := A_TickCount',
                    '`tSendInput "{" GlitterKey "}"',
                    '`tSleep intervalMs',
                    '`twhile ((A_TickCount - startTick) < durationMs) {',
                    '`t`tSendInput "{" GlitterKey "}"',
                    '`t`tSleep intervalMs',
                    '`t}',
                    '`treturn 1',
                    '}'
                )
                if (!InStr(c, 'nm_SpamGlitterKey(durationMs := 5000, intervalMs := 100){'))
                    c := StrReplace(c, spamGlitterNeedle, spamGlitterInsert)
                leaseHelpersCoreText := RegExReplace(leaseHelpersText, '(?ms)^.*?; BOOST LEASE HELPERS START\r?\n', '')
                leaseHelperNames := [
                    'nm_HandlePinePreGlitter',
                    'nm_DiscordEscapeContent',
                    'nm_ResolveBoostLeaseDiscordChannel',
                    'nm_NotifyBoostLeaseDiscord',
                    'nm_DebugGlitterPress',
                    'nm_SpamGlitterKey',
                    'nm_RunPendingStickerStackAfterExtend',
                    'nm_ClearBoostLeaseState',
                    'nm_ArmBoostLease',
                    'nm_GetBoostTotalDuration',
                    'nm_GetBoostRemainingSeconds',
                    'nm_GetBoostChaseStart',
                    'nm_GetBoostChaseRemainingSeconds',
                    'nm_ExpireBoostLeaseIfOver',
                    'nm_IsBoostLeaseExtendWindow',
                    'nm_IsBoostLeaseGatherWindow',
                    'nm_IsBoostLeaseNearWindow',
                    'nm_CheckBoostLeaseWarning',
                    'nm_GetBoostLeaseAction',
                    'nm_GetBoostLeaseGatherAction',
                    'nm_ShouldUseBoostLeaseForMondo',
                    'nm_HandleBoostLeaseGlitter'
                ]
                if (leaseHelpersText != "") {
                    for _, helperName in leaseHelperNames
                        c := RemoveFunctionBlocks(c, helperName)
                }
                secondPineHelperPos := InStr(c, 'nm_HandlePinePreGlitter(fieldName, field_type){', false, InStr(c, 'nm_HandlePinePreGlitter(fieldName, field_type){') + 1)
                if (secondPineHelperPos) {
                    cTail := SubStr(c, secondPineHelperPos)
                    cTailClean := RegExReplace(cTail, '(?ms)^nm_HandlePinePreGlitter\(fieldName, field_type\)\{\r?\n.*?^\}\r?\n(?=; BOOST LEASE HELPERS START)', '', &pineDupCount, 1)
                    if (pineDupCount > 0 && cTailClean != cTail)
                        c := SubStr(c, 1, secondPineHelperPos - 1) . cTailClean
                }
                if (leaseHelpersText != "") {
                    if InStr(c, '; BOOST LEASE HELPERS START') {
                        c := SyncBlockFromSource(c, leaseHelpersCoreText, '; BOOST LEASE HELPERS START', '; BOOST LEASE HELPERS END', &leaseHelpersChanged)
                    } else {
                        c := RegExReplace(c, '(?ms)^nm_toBooster\(location\)\{', leaseHelpersText "`r`n`r`n$0", , 1)
                        leaseHelpersChanged := true
                    }
                    if leaseHelpersChanged
                        FileAppend("? Synced boost lease helper block from patch template`n", logFile)
                }

                leaseGatherText := ReadPatchBlock(glitterExtendGatherTemplatePath)
                if (leaseGatherText != "") {
                    leaseGatherNeedle := JoinLines(
                        '				if nm_GetBoostLeaseGatherAction() {',
                        '					nm_HandleBoostLeaseGlitter(FieldName, "Gather Lease")',
                        '					return',
                        '				}'
                    )
                    leaseGatherReplacement := JoinLines(
                        '				if nm_GetBoostLeaseGatherAction() {',
                        '					nm_HandleBoostLeaseGlitter(FieldName, "Gather Lease")',
                        '				}'
                    )
                    leaseGatherText := StrReplace(leaseGatherText, leaseGatherNeedle, leaseGatherReplacement)
                    cNew := RegExReplace(c, '(?ms)^(\t\t\t\tnm_HandlePinePreGlitter\(FieldName, field_type\)\r?\n).*?(^\t\t\t\tnm_autoFieldBoost\(FieldName\))', '$1' leaseGatherText "`r`n" '$2', &leaseGatherCount, 1)
                    if (leaseGatherCount > 0 && cNew != c) {
                        c := cNew
                        FileAppend("? Synced gather extend block from patch template`n", logFile)
                    }
                }
                gatherLeaseReturnPattern := '(?ms)^(\t\t\t\tif nm_GetBoostLeaseGatherAction\(\) \{\r?\n\t\t\t\t\tnm_HandleBoostLeaseGlitter\(FieldName, "Gather Lease"\)\r?\n)\t\t\t\t\treturn\r?\n(\t\t\t\t\})'
                cNew := RegExReplace(c, gatherLeaseReturnPattern, '$1$2', &gatherLeaseReturnCount)
                if (gatherLeaseReturnCount > 0 && cNew != c) {
                    c := cNew
                    FileAppend("? Normalized gather lease to keep gathering after Glitter`n", logFile)
                }
                gatherLeaseExactNeedle := JoinLines(
                    '				if nm_GetBoostLeaseGatherAction() {',
                    '					nm_HandleBoostLeaseGlitter(FieldName, "Gather Lease")',
                    '					return',
                    '				}'
                )
                gatherLeaseExactReplace := JoinLines(
                    '				if nm_GetBoostLeaseGatherAction() {',
                    '					nm_HandleBoostLeaseGlitter(FieldName, "Gather Lease")',
                    '				}'
                )
                cNew := StrReplace(c, gatherLeaseExactNeedle, gatherLeaseExactReplace)
                if (cNew != c) {
                    c := cNew
                    FileAppend("? Force-removed gather lease return after Glitter`n", logFile)
                }

                leaseStickerText := ReadPatchBlock(glitterExtendStickerTemplatePath)
                if (leaseStickerText != "") {
                    cNew := RegExReplace(c, '(?ms)^\t\t\t\tif nm_StickerStackInterrupt\(\) \{.*?^\t\t\t\t\}\r?\n(?=^\t\t\t\tif nm_BlueBoosterInterrupt\(\))', leaseStickerText "`r`n", &leaseStickerCount, 1)
                    if (leaseStickerCount > 0 && cNew != c) {
                        c := cNew
                        c := RemoveRepeatedExactBlock(c, leaseStickerText)
                        FileAppend("? Synced sticker-stack near-window handoff block`n", logFile)
                    }
                }

                leaseConvertText := ReadPatchBlock(glitterExtendConvertTemplatePath)
                if (leaseConvertText != "") {
                    c := RegExReplace(c, '(?ms)^\t\t\tif \(PFieldBoosted && \(nowUnix\(\)-GatherFieldBoostedStart\)>750 && \(nowUnix\(\)-GatherFieldBoostedStart\)<840 && \(nowUnix\(\)-LastGlitter\)>900 && GlitterKey!="none"\) \{\r?\n^\t\t\t\tnm_ConvertRenewGlitter\(FieldName\)\r?\n^\t\t\t\}', leaseConvertText, &leaseConvertLegacyCount)
                    cNew := RegExReplace(c, '(?ms)^\t\t\t; BOOST LEASE CONVERT START\r?\n^\t\t\tif nm_GetBoostLeaseAction\(\) \{\r?\n^\t\t\t\tnm_ConvertRenewGlitter\(FieldName\)\r?\n^\t\t\t\}\r?\n^\t\t\t; BOOST LEASE CONVERT END', leaseConvertText, &leaseConvertManagedCount)
                    if ((leaseConvertLegacyCount > 0 || leaseConvertManagedCount > 0) && cNew != c) {
                        c := cNew
                        FileAppend("? Synced convert renewal block from patch template`n", logFile)
                    }
                }

                c := RegExReplace(c, '(?m)^\s*if\(not nm_fieldBoostCheck\(CurrentField\)\)\s*\{', 'if(nm_fieldBoostCheck(CurrentField, 1, 1) < 0.8) {')
                c := RegExReplace(c, '(?m)^\s*if\(nm_fieldBoostCheck\(CurrentField\)\)\s*\{', 'if(nm_fieldBoostCheck(CurrentField, 1, 1) > 0.8) {')
                c := StrReplace(c, '`t`t, PFieldBoosted, GatherFieldBoosted, GatherFieldBoostedStart, LastGlitter, GlitterKey', '`t`t, PFieldBoosted, PFieldBoostExtend, GatherFieldBoosted, GatherFieldBoostedStart, LastGlitter, GlitterKey')

                ; Final guard: some gather-sync variants can reintroduce the old
                ; return even after the template replacement above, so strip it
                ; again at the end of the Glitter-extend pass.
                finalGatherLeaseNeedle := JoinLines(
                    '				if nm_GetBoostLeaseGatherAction() {',
                    '					nm_HandleBoostLeaseGlitter(FieldName, "Gather Lease")',
                    '					return',
                    '				}'
                )
                finalGatherLeaseReplace := JoinLines(
                    '				if nm_GetBoostLeaseGatherAction() {',
                    '					nm_HandleBoostLeaseGlitter(FieldName, "Gather Lease")',
                    '				}'
                )
                cNew := StrReplace(c, finalGatherLeaseNeedle, finalGatherLeaseReplace)
                if (cNew != c) {
                    c := cNew
                    FileAppend("? Finalized gather lease to continue gathering after Glitter`n", logFile)
                }

                gatherLeaseDuplicatePattern := '(?ms)^\t\t\t\t; BOOST LEASE GATHER START\r?\n\t\t\t\tif nm_GetBoostLeaseGatherAction\(\) \{\r?\n\t\t\t\t\tnm_HandleBoostLeaseGlitter\(FieldName, "Gather Lease"\)\r?\n\t\t\t\t\}\r?\n\t\t\t\t; BOOST LEASE GATHER END\r?\n(?:\t\t\t\t; BOOST LEASE STICKER START\r?\n\t\t\t\t; BOOST LEASE GATHER START\r?\n\t\t\t\tif nm_GetBoostLeaseGatherAction\(\) \{\r?\n\t\t\t\t\tnm_HandleBoostLeaseGlitter\(FieldName, "Gather Lease"\)\r?\n\t\t\t\t\}\r?\n\t\t\t\t; BOOST LEASE GATHER END\r?\n)+\t\t\t\t; BOOST LEASE STICKER START'
                gatherLeaseDuplicateReplacement := JoinLines(
                    '`t`t`t`t; BOOST LEASE GATHER START',
                    '`t`t`t`tif nm_GetBoostLeaseGatherAction() {',
                    '`t`t`t`t`tnm_HandleBoostLeaseGlitter(FieldName, "Gather Lease")',
                    '`t`t`t`t}',
                    '`t`t`t`t; BOOST LEASE GATHER END',
                    '`t`t`t`t; BOOST LEASE STICKER START'
                )
                cNew := RegExReplace(c, gatherLeaseDuplicatePattern, gatherLeaseDuplicateReplacement, &gatherLeaseDuplicateCount)
                if (gatherLeaseDuplicateCount > 0 && cNew != c) {
                    c := cNew
                    FileAppend("? Collapsed repeated gather lease blocks to one message`n", logFile)
                }

            }

            ; Daily reconnect queue: preserve the post-convert handoff.
            bt := Chr(96)
            if (InStr(c, 'global ReconnectDelay := wParam') && !InStr(c, 'DailyReconnectPending := 1')) {
                cNew := StrReplace(c
                    , 'global ReconnectDelay := wParam`r`n	nm_endWalk()`r`n	CloseRoblox()`r`n	return 0'
                    , 'global ReconnectDelay := wParam, DailyReconnectPending := 0, ReconnectSyncBroadcastPending := 0, ReconnectSyncMode`r`n	FileAppend(A_Now " - DailyReconnect request received: " wParam " / " lParam "' . bt . 'r' . bt . 'n", "settings\debug_log.txt", "UTF-8")`r`n	if (ReconnectSyncMode = "Alt") {`r`n		nm_endWalk()`r`n		nm_setStatus("Closing", "Roblox, Reconnect Sync")`r`n		CloseRoblox()`r`n		DisconnectCheck()`r`n		return 0`r`n	}`r`n	DailyReconnectPending := 1`r`n	ReconnectSyncBroadcastPending := (lParam = 1)`r`n	if (wParam = 60 && lParam = 1)`r`n		FileAppend(A_Now " - DailyReconnect test queued' . bt . 'r' . bt . 'n", "settings\debug_log.txt", "UTF-8")`r`n	nm_endWalk()`r`n	return 0'
                )
                if (cNew != c) {
                    c := cNew
                    FileAppend("? Patched reconnect request to wait until after convert`n", logFile)
                }
                c := RegExReplace(c, 'nm_ForceReconnect\(wParam, \*\)\{', 'nm_ForceReconnect(wParam, lParam := 0, *){')
                c := RegExReplace(c, 'FileAppend\(A_Now " - DailyReconnect request received: " wParam " / " lParam \r?\n", "settings\\debug_log\.txt", "UTF-8"\)', 'FileAppend(A_Now " - DailyReconnect request received: " wParam " / " lParam "' . bt . 'r' . bt . 'n", "settings\debug_log.txt", "UTF-8")')
                c := RegExReplace(c, 'FileAppend\(A_Now " - DailyReconnect test queued\r?\n", "settings\\debug_log\.txt", "UTF-8"\)', 'FileAppend(A_Now " - DailyReconnect test queued' . bt . 'r' . bt . 'n", "settings\debug_log.txt", "UTF-8")')
            }
            reconnectWaitOld := JoinLines(
                '`tif (ReconnectDelay) {',
                '`t`tnm_setStatus("Waiting", ReconnectDelay " seconds before Reconnect")',
                '`t`tSleep 1000*ReconnectDelay',
                '`t`tReconnectDelay := 0',
                '`t}',
                '`telse if (MacroState = 2) {'
            )
            reconnectWaitNew := JoinLines(
                '`tCritical 0',
                '`tif (ReconnectDelay) {',
                '`t`twaitReconnectUntil := nowUnix() + ReconnectDelay',
                '`t`tnm_setStatus("Waiting", ReconnectDelay " seconds before Reconnect")',
                '`t`twhile (nowUnix() < waitReconnectUntil) {',
                '`t`t`tif (MacroState = 0) {',
                '`t`t`t`tReconnectDelay := 0',
                '`t`t`t`treturn 0',
                '`t`t`t}',
                '`t`t`tSleep 250',
                '`t`t}',
                '`t`tReconnectDelay := 0',
                '`t}',
                '`telse if (MacroState = 2) {'
            )
            cNew := StrReplace(c, reconnectWaitOld, reconnectWaitNew)
            if (cNew != c) {
                c := cNew
                FileAppend("? Patched reconnect wait to be stop-interruptible`n", logFile)
            }
            ; Canonicalize nm_convert() as a targeted block patch. This keeps the
            ; patcher incremental while avoiding fragile trace-line splicing.
            convertPatchText := ReadPatchBlock(nmConvertTemplatePath)
            if (convertPatchText != "") {
                convertReconnectOld := JoinLines(
                    '`tif ((boostReconnectStart > 0) && ((900 - (nowUnix() - boostReconnectStart)) >= 60)) {',
                    '`t`tnm_ConvertTrace("Convert: reconnect waiting on boost", convertTraceStart)',
                    '`t`tFileAppend(A_Now " - DailyReconnect waiting on boost window`r`n", "settings\debug_log.txt", "UTF-8")',
                    '`t\tnm_setStatus("Waiting", "Boost before Reconnect")',
                    '`t\treturn',
                    '`t}'
                )
                convertReconnectNew := JoinLines(
                    '`tif (nm_GatherBoostInterrupt()) {',
                    '`t`tnm_ConvertTrace("Convert: reconnect waiting on boost", convertTraceStart)',
                    '`t`tFileAppend(A_Now " - DailyReconnect waiting on boost window`r`n", "settings\debug_log.txt", "UTF-8")',
                    '`t\tnm_setStatus("Waiting", "Boost before Reconnect")',
                    '`t\treturn',
                    '`t}'
                )
                convertPatchText := StrReplace(convertPatchText, convertReconnectOld, convertReconnectNew)
                cNew := ReplaceFunctionBlock(c, "nm_convert", convertPatchText "`r`n", &convertPatchCount)
                if (convertPatchCount > 0 && cNew != c) {
                    c := cNew
                    FileAppend("? Replaced nm_convert() with targeted patched block`n", logFile)
                } else if (convertPatchCount = 0) {
                    FileAppend("! Could not find nm_convert() block for targeted patch`n", logFile)
                }
            }

            convertRenewNeedle := 'nm_convert(ignoreActiveConvertState := 0, forceBalloonConvert := 0){'
            convertRenewFunc := JoinLines(
                'nm_ConvertRenewGlitter(fieldName) {',
                '`tglobal GlitterKey, LastGlitter, GatherFieldBoostedStart, PFieldBoostExtend, fieldOverrideReason, BoostLeaseNearDiscordNotice',
                '`tif (GlitterKey = "none" || fieldName = "None")',
                '`t`treturn 0',
                '`tnm_setStatus("Traveling", "Glitter Renewal -> " fieldName)',
                '`tnm_gotoField(fieldName)',
                '`tSleep 1000',
                '`tPFieldBoostExtend := 1',
                '`tLastGlitter := nowUnix()',
                '`tIniWrite LastGlitter, "settings\nm_config.ini", "Boost", "LastGlitter"',
                '`tnm_SpamGlitterKey()',
                '`tnm_DebugGlitterPress("Convert Renewal", fieldName)',
                '`tnm_RunPendingStickerStackAfterExtend()',
                '`tSleep 500',
                '`tfieldOverrideReason := "Boost"',
                '`tBoostLeaseNearDiscordNotice := 0',
                '`tIniWrite fieldName, "settings\nm_config.ini", "Boost", "LastBoostedField"',
                '`tnm_setStatus("Boosted", "Glitter Renewed - Returning to Convert")',
                '`tnm_walkFrom(fieldName)',
                '`tnm_findHiveSlot()',
                '`treturn 1',
                '}'
            )
            c := RemoveFunctionBlocks(c, "nm_ConvertRenewGlitter")
            cNew := StrReplace(c, convertRenewNeedle, convertRenewFunc "`r`n`r`n" convertRenewNeedle)
            if (cNew != c) {
                c := cNew
                FileAppend("? Inserted nm_ConvertRenewGlitter() before nm_convert()`n", logFile)
            }
            c := RemoveFunctionBlocks(c, "nm_ConvertTrace")
            convertTraceHelper := JoinLines(
                'nm_ConvertTrace(label, startTick := 0){',
                '`tif (startTick > 0)',
                '`t`tFileAppend(A_Now " [" (A_TickCount - startTick) "ms] " label "``r``n", "settings\debug_log.txt", "UTF-8")',
                '`telse',
                '`t`tFileAppend(A_Now " [" A_TickCount "ms] " label "``r``n", "settings\debug_log.txt", "UTF-8")',
                '}',
                ''
            )
            cNew := StrReplace(c, 'nm_setSprinkler(field, loc, dist){', convertTraceHelper 'nm_setSprinkler(field, loc, dist){')
            if (cNew != c) {
                c := cNew
                FileAppend("? Inserted nm_ConvertTrace() before nm_setSprinkler()`n", logFile)
            }

            goGatherIntroPattern := '(?ms)^\t;VICIOUS BEE\r?\n.*?^\tif\s*!\s*\(\s*nm_GatherBoostInterrupt\(\)\s*\)\s*\{'
            goGatherIntroReplacement := JoinLines(
                '`t;VICIOUS BEE',
                '`tif nm_NightInterrupt()',
                '`t`treturn',
                '`t;MONDO',
                '`tif mondointerrupt_ShouldTrigger() {',
                '`t`tmondointerrupt_Handle()',
                '`t`treturn',
                '`t}',
                '`tif nm_MondoInterrupt() && !(MondoInterruptCheck = 1 && MondoBuffCheck = 1 && MondoAction = "Buff")',
                '`t`treturn',
                '`tif nm_HandleStickerStackInterrupt(1, 0, 1)',
                '`t`treturn',
                '`tif nm_BlueBoosterInterrupt() {',
                '`t`tnm_toBooster("blue")',
                '`t`treturn',
                '`t}',
                '`tif !(nm_GatherBoostInterrupt()){'
            )
            cNew := RegExReplace(c, goGatherIntroPattern, goGatherIntroReplacement, &goGatherIntroCount, 1)
            if (goGatherIntroCount > 0 && cNew != c) {
                c := cNew
                FileAppend("? Normalized nm_GoGather() opening interrupt order`n", logFile)
            }

            c := RegExReplace(c, '(?m)^(\t+tadsync_LogBoostScan\("gather-scan-start", CurrentField, RecentFBoost\)\r?\n)', '$1`tboostTraceStart := A_TickCount`r`n')
            c := RegExReplace(c, '(?m)^(\t+tadsync_LogBoostScan\("gather-scan-picked", CurrentField, RecentFBoost, BoostChaserField\)\r?\n)', '$1`tnm_ConvertTrace("Boost chase: picked " BoostChaserField, boostTraceStart)`r`n')
            c := RegExReplace(c, '(?ms)(if\(fieldOverrideReason="None" \|\| fieldOverrideReason="Boost"\) \{\r?\n)(?:\t\tboostResetStart := A_TickCount\r?\n\t\tnm_ConvertTrace\("Boost chase: nm_Reset\(2\) start", boostResetStart\)\r?\n)?\t\tnm_Reset\(2\)\r?\n(?:\t\tnm_ConvertTrace\("Boost chase: nm_Reset\(2\) complete", boostResetStart\)\r?\n)?', '$1`t`tboostResetStart := A_TickCount`r`n`t`tnm_ConvertTrace("Boost chase: nm_Reset(2) start", boostResetStart)`r`n`t`tnm_Reset(2)`r`n`t`tnm_ConvertTrace("Boost chase: nm_Reset(2) complete", boostResetStart)`r`n')

            cNew := NormalizeGoGatherMondoBlocks(c)
            if (cNew != c) {
                c := cNew
                FileAppend("? Collapsed duplicate Mondo gather blocks in nm_GoGather()`n", logFile)
            }

            c := NormalizeDelimitedBlock(c, '(TabArr\s*:=\s*\[)(.*?)(\])', "tabs", &tabArrChanged)
            c := NormalizeDelimitedBlock(c, '(static tabs\s*:=\s*\[)(.*?)(\])', "locktabs", &lockTabsChanged)
            c := NormalizeForceMessageHooks(c)
            c := StripReconnectSyncDebugLogging(c)
            c := NormalizeDuplicateFunction(c, "nm_ForceStickerStack")
            c := NormalizeDuplicateFunction(c, "nm_ForceBlueBooster")

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
                        FileAppend("⚠ FAILED to write temp natro file after retries: " lastError "`n", logFile)
                    } catch {
                    }
                }
            }

    if (writeTempOk) {
        validationOk := true
        validationError := ""
        validateExePath := workDir "\submacros\AutoHotkey64.exe"
        if FileExist(validateExePath) {
            try {
                validationOk := ValidateAutoHotkeyFile(validateExePath, tempNat, &validationError)
            } catch as e {
                validationOk := false
                validationError := e.Message
            }
            if (!validationOk) {
                try {
                    FileAppend("! Temp natro validation failed: " validationError "`n", logFile)
                } catch {
                }
                msg .= "âš  FAILED to validate patched natro temp file; skipping natro write`n"
            }
        } else {
            try {
                FileAppend("! AutoHotkey validator missing; skipping temp validation`n", logFile)
            } catch {
            }
        }

        if (!validationOk) {
            writeTempOk := false
        }
    }

    if (writeTempOk) {
                moved := false
                attempts := 0
                lastMoveError := ""
                while (attempts < 6) {
                    try {
                        FileMove(tempNat, natroPath, 1)
                        moved := true
                        break
                    } catch as e {
                        lastMoveError := e.Message
                        attempts += 1
                        Sleep(500)
                    }
                }

                if (!moved) {
                    attempts := 0
                    while (attempts < 3) {
                        try {
                            FileCopy(tempNat, natroPath, 1)
                            moved := true
                            break
                        } catch as e {
                            lastMoveError := e.Message
                            attempts += 1
                            Sleep(500)
                        }
                    }
                }

                if (!moved) {
                    attempts := 0
                    while (attempts < 3) {
                        try {
                            fh := FileOpen(natroPath, "w", "UTF-8")
                            if !fh
                                throw Error("FileOpen returned no handle")
                            fh.Write(c)
                            fh.Close()
                            moved := true
                            break
                        } catch as e {
                            lastMoveError := e.Message
                            attempts += 1
                            Sleep(500)
                        }
                    }
                }

                if (moved) {
                    try if FileExist(tempNat)
                        FileDelete(tempNat)
                    catch {
                    }
                    msg .= "✓ natro_macro.ahk patched and sanitized`n"
                    ; resilient log write
                    logAttempts := 0
                    while (logAttempts < 6) {
                        try {
                            FileAppend("✓ Patched Run arguments and GUI in natro_macro.ahk`n", logFile)
                            break
                        } catch {
                            logAttempts += 1
                            Sleep(200)
                        }
                    }
                } else {
                    msg .= "⚠ FAILED to move patched file into place" (lastMoveError != "" ? ": " lastMoveError : " (file locked)") "`n"
                    try {
                        FileAppend("⚠ FAILED to move patched natro_macro.ahk into place" (lastMoveError != "" ? ": " lastMoveError : "") "`n", logFile)
                    } catch {
                    }
                }
            } else {
                msg .= "⚠ FAILED to write patched natro_macro temp file; skipping natro write`n"
            }
    } catch as e {
        msg .= "⚠ FAILED to write natro_macro.ahk: " e.Message "`n"
        try {
            FileAppend("⚠ FAILED to write natro_macro.ahk: " e.Message "`n", logFile)
        } catch {
        }
    }
} else {
    msg .= "· natro_macro.ahk no changes needed`n"
}

; 1a0c. Keep boost trace logging cheap: log the gather-scan phase only.
tadsyncExtensionPath := workDir "\Extensions\rays_tadsync_extension.ahk"
    if FileExist(tadsyncExtensionPath) {
    try {
        extText := FileRead(tadsyncExtensionPath, "UTF-8")
        ; Keep the boost trace logger minimal: only phase/state, no per-field detection.
        cheapBoostLogger := JoinLines(
            'tadsync_LogBoostScan(phase, currentField := "", recentBoost := "", selectedField := "") {',
            '	global BoostChaserCheck',
            '	msg := "boost-scan phase=" phase " boostChaser=" BoostChaserCheck " current=" currentField " recent=" recentBoost " selected=" selectedField',
            '	tadsync_BoostTrace(msg)',
            '}'
        )
        extTextNew := ReplaceFunctionBlock(extText, "tadsync_LogBoostScan", cheapBoostLogger, &boostTraceChanged)
        if (boostTraceChanged) {
            fh := FileOpen(tadsyncExtensionPath, "w", "UTF-8")
            if !fh
                throw Error("FileOpen returned no handle")
            fh.Write(extTextNew)
            fh.Close()
            FileAppend("? Simplified rays_tadsync boost trace logger`n", logFile)
        }
    } catch as e {
        msg .= "âš  FAILED to simplify rays_tadsync boost trace logger: " e.Message "`n"
        try FileAppend("âš  FAILED to simplify rays_tadsync boost trace logger: " e.Message "`n", logFile)
    }
}

; 1b. PATCH BACKGROUND.AHK
if FileExist(backgroundPath) {
    c := FileRead(backgroundPath, "UTF-8")
    orig := c

    newReconnectInsert := JoinLines(
        'nm_dailyReconnect(){',
        '`tstatic LastDailyReconnect := 0',
        '`tif ((ReconnectHour = "") || (ReconnectMin = "") || (ReconnectInterval = "") || (nowUnix() - LastDailyReconnect < 60))',
        '`t`treturn',
        '`tRChourUTC := Number(FormatTime(A_NowUTC, "HH"))',
        '`tRCminUTC := Number(FormatTime(A_NowUTC, "mm"))',
        '`tHourReady:=0',
        '`tLoop 24//ReconnectInterval',
        '`t{',
        '`t`tif (Mod(ReconnectHour+ReconnectInterval*(A_Index-1), 24)=RChourUTC)',
        '`t`t{',
        '`t`t`tHourReady:=1',
        '`t`t`tbreak',
        '`t`t}',
        '`t}',
        '`tif((Number(ReconnectMin)=RCminUTC) && HourReady && (MacroState = 2)) {',
          '`t`tLastDailyReconnect := nowUnix()',
        '`t`tif (hwnd := WinExist("natro_macro ahk_class AutoHotkey")) {',
        '`t`t`tSend_WM_COPYDATA("Closing: Roblox, Daily Reconnect", "ahk_id " hwnd)',
        '`t`t`tPostMessage 0x5557, 60, 1,, "ahk_id " hwnd',
        '`t`t}',
        '`t}',
        '}'
    )
    cNew := RegExReplace(c, '(?ms)^nm_dailyReconnect\(\)\{\r?\n.*?(?=^nm_EmergencyBalloon\(\)\{)', newReconnectInsert "`r`n`r`n", &reconnectSyncCount, 1)
    if (reconnectSyncCount > 0 && cNew != c)
        c := cNew

    if (c != orig) {
        try {
            FileDelete(backgroundPath)
            FileAppend(c, backgroundPath, "UTF-8")
            msg .= "✓ background.ahk patched`n"
        } catch {
            msg .= "⚠ FAILED to write background.ahk`n"
        }
    }
}

; 2. PATCH STATUS.AHK
if FileExist(statusPath) {
    c := FileRead(statusPath, "UTF-8")
    orig := c

    if true {
        statusSettingsNeedle := 'settings["PriorityListNumeric"] := {enum: 366, type: "int", section: "Settings", regex: "i)^[1-8]{8}$"}'
        statusSettingsInsert := JoinLines(
            'settings["PriorityListNumeric"] := {enum: 366, type: "int", section: "Settings", regex: "i)^[1-8]{8}$"}',
            'settings["FieldFollowingCheck"] := {enum: ResolveEnumInt("FieldFollowingCheck", 367), type: "int", section: "Extensions", regex: "i)^(0|1)$"}',
            'settings["BlueBoosterInterruptCheck"] := {enum: ResolveEnumInt("BlueBoosterInterruptCheck", 370), type: "int", section: "Boost", regex: "i)^(0|1)$"}',
            'settings["StickerStackInterruptCheck"] := {enum: ResolveEnumInt("StickerStackInterruptCheck", 371), type: "int", section: "Boost", regex: "i)^(0|1)$"}',
            'settings["PFieldBoosted"] := {enum: ResolveEnumInt("PFieldBoosted", 372), type: "int", section: "Extensions", regex: "i)^(0|1)$"}',
            'settings["PreGlitterCheck"] := {enum: ResolveEnumInt("PreGlitterCheck", 373), type: "int", section: "Extensions", regex: "i)^(0|1)$"}',
            'settings["EnzymesBoostedOnly"] := {enum: ResolveEnumInt("EnzymesBoostedOnly", 374), type: "int", section: "Extensions", regex: "i)^(0|1)$"}',
            'settings["MondoInterruptCheck"] := {enum: ResolveEnumInt("MondoInterruptCheck", 375), type: "int", section: "Extensions", regex: "i)^(0|1)$"}',
            'settings["ReconnectSyncCheck"] := {enum: ResolveEnumInt("ReconnectSyncCheck", 376), type: "int", section: "Extensions", regex: "i)^(0|1)$"}',
            'settings["ReconnectSyncMode"] := {enum: ResolveEnumInt("ReconnectSyncMode", 377), type: "str", section: "Extensions", regex: "i)^(Main|Alt)$"}',
            'settings["ReconnectSyncChannelID"] := {enum: ResolveEnumInt("ReconnectSyncChannelID", 378), type: "str", section: "Extensions", regex: "i)^\d{0,20}$"}'
        )
        c := StrReplace(c, statusSettingsNeedle, statusSettingsInsert)

        c := StrReplace(c, 'sections := Map("Boost", "**__Boost__**"`r`n				,"Collect", "**__Collect__**"', 'sections := Map("Boost", "**__Boost__**"`r`n				,"Collect", "**__Collect__**"`r`n				,"Extensions", "**__Extensions__**"')

        if !InStr(c, 'ResolveEnumInt(name, fallback := 0)') {
            aliasNeedle := 'nowUnix() => DateDiff(A_NowUTC, "19700101000000", "Seconds")'
            aliasInsert := JoinLines(
                'nowUnix() => DateDiff(A_NowUTC, "19700101000000", "Seconds")',
                '',
                'ResolveEnumInt(name, fallback := 0)',
                '{',
                '`tstatic enumMap := ""',
                '`tif !IsObject(enumMap) {',
                '`t`tenumMap := Map()',
                '`t`tenumPath := A_ScriptDir "\..\lib\enum\EnumInt.ahk"',
                '`t`ttry text := FileRead(enumPath, "UTF-8")',
                '`t`tcatch',
                '`t`t`treturn fallback',
                '`t`tindex := 0',
                '`t`tfor line in StrSplit(text, Chr(10), Chr(13))',
                '`t`t{',
                '`t`t`tline := Trim(line)',
                '`t`t`tif (SubStr(line, 1, 1) != Chr(34))',
                '`t`t`t`tcontinue',
                '`t`t`tendQuote := InStr(line, Chr(34), , 2)',
                '`t`t`tif !endQuote',
                '`t`t`t`tcontinue',
                '`t`t`tindex += 1',
                '`t`t`tenumName := SubStr(line, 2, endQuote - 2)',
                '`t`t`tenumMap[StrLower(enumName)] := index',
                '`t`t}',
                '`t}',
                '`tkey := StrLower(Trim(name))',
                '`treturn enumMap.Has(key) ? enumMap[key] : fallback',
                '}',
                '',
                'ResolveModuleSetting(name, &displayName := "")',
                '{',
                '`tstatic moduleAliases := Map(',
                '`t`t"fieldfollowingcheck", "FieldFollowingCheck",',
                '`t`t"fieldfollowing", "FieldFollowingCheck",',
                '`t`t"blueboosterinterruptcheck", "BlueBoosterInterruptCheck",',
                '`t`t"bfbinterrupt", "BlueBoosterInterruptCheck",',
                '`t`t"bfbinterupt", "BlueBoosterInterruptCheck",',
                '`t`t"stickerstackinterruptcheck", "StickerStackInterruptCheck",',
                '`t`t"stickerstackinterrupt", "StickerStackInterruptCheck",',
                '`t`t"glitterextend", "PFieldBoosted",',
                '`t`t"pfieldboosted", "PFieldBoosted",',
                '`t`t"preglittercheck", "PreGlitterCheck",',
                '`t`t"preglitter", "PreGlitterCheck",',
                '`t`t"enzymesboostedonly", "EnzymesBoostedOnly",',
                '`t`t"mondointerruptcheck", "MondoInterruptCheck",',
                '`t`t"mondointerrupt", "MondoInterruptCheck",',
                '`t`t"mondointeruptcheck", "MondoInterruptCheck",',
                '`t`t"mondointerupt", "MondoInterruptCheck"',
                '`t)',
                '`tstatic displayAliases := Map(',
                '`t`t"PFieldBoosted", "GlitterExtend"',
                '`t)',
                '`tkey := Trim(name)',
                '`tif !StrLen(key)',
                '`t`treturn ""',
                '`tif !moduleAliases.Has(StrLower(key))',
                '`t`treturn ""',
                '`tmoduleName := moduleAliases[StrLower(key)]',
                '`tdisplayName := displayAliases.Has(moduleName) ? displayAliases[moduleName] : moduleName',
                '`treturn moduleName',
                '}'
            )
            c := StrReplace(c, aliasNeedle, aliasInsert)
        }

        c := StrReplace(c, '					sections[v.section] .= "`n" k', '					sections[v.section] .= "`n" ((k = "PFieldBoosted") ? "GlitterExtend" : k)')
    }

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
                        FileAppend("✓ Auto-included Extensions\\" extFile " in Status.ahk`n", logFile)
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
                FileAppend("✓ Added Field Announcement hook (0x5561) to Status.ahk`n", logFile)
            }
        }
    }
    if !InStr(c, "0x5562") {
        cNew := StrReplace(c, "OnMessage(0x5561, aq_announce)`r`n", "OnMessage(0x5561, aq_announce)`r`nOnMessage(0x5562, aq_announceHiveStandby)`r`n")
        if (cNew != c) {
            c := cNew
            FileAppend("? Added Hive standby announcement hook (0x5562) to Status.ahk`n", logFile)
        }
    }
    if !InStr(c, "0x5566") {
        cNew := StrReplace(c, "OnMessage(0x5562, aq_announceHiveStandby)`r`n", "OnMessage(0x5562, aq_announceHiveStandby)`r`nOnMessage(0x5566, recon_SendReconnectSyncBroadcast)`r`n")
        if (cNew != c) {
            c := cNew
            FileAppend("? Added reconnect sync broadcast hook (0x5566) to Status.ahk`n", logFile)
        }
    }

    ; 2c. Main loop call
    if !InStr(c, "aq_getFollowingField") {
        if (pos := InStr(c, "discord.GetCommands(MainChannelID)")) {
            if (endPos := InStr(c, "`n", , pos)) {
                c := SubStr(c, 1, endPos) "`t(Mod(A_Index, 5) = 0) && reconnectsync_PollAlt()`r`n" "`t(Mod(A_Index, 5) = 0 && FieldFollowingCheck) && aq_getFollowingField()`r`n" SubStr(c, endPos+1)
                FileAppend("✓ Added reconnect sync poll call to Status.ahk`n", logFile)
            }
        }
    }

    ; 2c. (Removed) TadSync A_Args are no longer injected into Status.ahk
    ; tadsync_InitSettings() in tadsync_status_extension.ahk reads them from nm_config.ini directly

    ; Guard startup embed so submacro restarts do not spam Discord when integration is disabled.
    if InStr(c, 'discord.SendEmbed("Connected to Discord!", 5066239)') && !InStr(c, 'if (discordCheck = 1)') {
        c := StrReplace(c, 'discord.SendEmbed("Connected to Discord!", 5066239)', 'if (discordCheck = 1)`r`n`tdiscord.SendEmbed("Connected to Discord!", 5066239)')
        FileAppend("✓ Guarded Discord startup embed behind discordCheck`n", logFile)
    }
    }

    if (patchForceHourly) {
    if !InStr(c, 'Forces an immediate generation of the Hourly Report') {
        helpPattern := 's)(\{\R\s*"value": "Sets the command prefix, e\.g\. .*?",\R\s*"inline": true\R\s*\})'
        helpReplacement := '$1,`r`n`t`t`t`t`t{`r`n`t`t`t`t`t`t"name": "' "' commandPrefix 'hourlyreport" '",`r`n`t`t`t`t`t`t"value": "Forces an immediate generation of the Hourly Report",`r`n`t`t`t`t`t`t"inline": true`r`n`t`t`t`t`t}'
        cNew := RegExReplace(c, helpPattern, helpReplacement, &hourlyHelpCount, 1)
        if (hourlyHelpCount > 0) {
            c := cNew
            FileAppend("? Added hourlyreport help entry to Status.ahk`n", logFile)
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
            FileAppend("? Added stickerstack help entry to Status.ahk`n", logFile)
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
            FileAppend("? Added fb help entry to Status.ahk`n", logFile)
        }
    }
    }

    if true {
    if !InStr(c, '"name": "' "' commandPrefix 'modset [module] [0/1]" '",') {
        advancedNeedle := JoinLines(
            '`t`t`t`t`t{',
            '`t`t`t`t`t`t"name": "' "' commandPrefix 'get [setting]" '",',
            '`t`t`t`t`t`t"value": "Gets the current value of a setting in the macro",',
            '`t`t`t`t`t`t"inline": true',
            '`t`t`t`t`t},'
        )
        advancedInsert := JoinLines(
            '`t`t`t`t`t{',
            '`t`t`t`t`t`t"name": "' "' commandPrefix 'get [setting]" '",',
            '`t`t`t`t`t`t"value": "Gets the current value of a setting in the macro",',
            '`t`t`t`t`t`t"inline": true',
            '`t`t`t`t`t},',
            '`t`t`t`t`t{',
            '`t`t`t`t`t`t"name": "' "' commandPrefix 'modset [module] [0/1]" '",',
            '`t`t`t`t`t`t"value": "Sets a patched module toggle like ``GlitterExtend`` or ``MondoInterruptCheck``",',
            '`t`t`t`t`t`t"inline": true',
            '`t`t`t`t`t},'
        )
        cNew := StrReplace(c, advancedNeedle, advancedInsert)
        if (cNew != c) {
            c := cNew
            FileAppend("? Added modset help entry to Status.ahk`n", logFile)
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
            FileAppend("? Added Auto-Jelly yes/no help entries to Status.ahk`n", logFile)
        }
    }
    c := StrReplace(c, '"Keeps/replaces an amulet if prompt is on screen"', '"Keeps/replaces an amulet prompt if it is on screen"')
    }

    if true {
    if !InStr(c, 'Queues the daily reconnect handoff immediately for testing') {
        reconnectTestHelpNeedle := JoinLines(
            '`t`t`t`t`t{',
            '`t`t`t`t`t`t"name": "' "' commandPrefix 'rejoin (delay)" '",',
            '`t`t`t`t`t`t"value": "Closes Roblox and rejoins after an optional ``delay``",',
            '`t`t`t`t`t`t"inline": true',
            '`t`t`t`t`t},'
        )
        reconnectTestHelpInsert := JoinLines(
            '`t`t`t`t`t{',
            '`t`t`t`t`t`t"name": "' "' commandPrefix 'rejoin (delay)" '",',
            '`t`t`t`t`t`t"value": "Closes Roblox and rejoins after an optional ``delay``",',
            '`t`t`t`t`t`t"inline": true',
            '`t`t`t`t`t},',
            '`t`t`t`t`t{',
            '`t`t`t`t`t`t"name": "' "' commandPrefix 'reconnecttest" '",',
            '`t`t`t`t`t`t"value": "Queues the daily reconnect handoff immediately for testing",',
            '`t`t`t`t`t`t"inline": true',
            '`t`t`t`t`t},'
        )
        cNew := StrReplace(c, reconnectTestHelpNeedle, reconnectTestHelpInsert)
        if (cNew != c) {
            c := cNew
            FileAppend("? Added reconnecttest help entry to Status.ahk`n", logFile)
        }
    }
    if !InStr(c, 'case "reconnecttest","dailyreconnecttest":') {
        bt := Chr(96)
        reconnectTestInsert := JoinLines(
            '`t`tcase "reconnecttest","dailyreconnecttest":',
            '`t`tDetectHiddenWindows 1',
            '`t`tif (hwnd := WinExist("natro_macro ahk_class AutoHotkey"))',
            '`t`t{',
            '`t`t`tPostMessage 0x5557, 60, 1,, "ahk_id " hwnd',
            '`t`t`tFileAppend(A_Now " - Queued Daily Reconnect test via Discord' . bt . 'r' . bt . 'n", "settings\debug_log.txt", "UTF-8")',
            '`t`t`tdiscord.SendEmbed("Queued Daily Reconnect test. It will leave after convert once the boost window is safe.", 5066239, , , , id)',
            '`t`t}',
            '`t`telse',
            '`t`t`tdiscord.SendEmbed("Error: Macro not found!", 16711731, , , , id)',
            '',
            '',
            '`t`tcase "log":'
        )
        cNew := StrReplace(c, '`t`tcase "log":', reconnectTestInsert)
        if (cNew != c) {
            c := cNew
            FileAppend("? Added reconnecttest command to Status.ahk`n", logFile)
        }
        c := RegExReplace(c, 'FileAppend\(A_Now " - Queued Daily Reconnect test via Discord\r?\n", "settings\\debug_log\.txt", "UTF-8"\)', 'FileAppend(A_Now " - Queued Daily Reconnect test via Discord' . bt . 'r' . bt . 'n", "settings\debug_log.txt", "UTF-8")')
    }
    modsetCanonical := JoinLines(
        '`t`tcase "modset":',
        '`t`tLoop 1',
        '`t`t{',
        '`t`t`tmoduleName := ResolveModuleSetting(params[2], &displayName)',
        '`t`t`tif !moduleName',
        '`t`t`t{',
        '`t`t`t`tdiscord.SendEmbed(Format("{} is not a valid module toggle! Use ?help advanced for the ?modset format.", (StrLen(params[2]) > 0) ? params[2] : "<blank>"), 16711731, , , , id)',
        '`t`t`t`tbreak',
        '`t`t`t}',
        '',
        '`t`t`tvalue := Trim(SubStr(command.content, InStr(command.content, params[2]) + StrLen(params[2])))',
        '`t`t`tswitch StrLower(value), 0',
        '`t`t`t{',
        '`t`t`t`tcase "on":',
        '`t`t`t`tvalue := 1',
        '`t`t`t`tcase "off":',
        '`t`t`t`tvalue := 0',
        '`t`t`t}',
        '',
        '`t`t`tif !(value ~= "i)^(0|1)$")',
        '`t`t`t{',
        '`t`t`t`tdiscord.SendEmbed(Format("{} is not a valid module toggle value! Use 0/1 or off/on.", (StrLen(value) > 0) ? value : "<blank>"), 16711731, , , , id)',
        '`t`t`t`tbreak',
        '`t`t`t}',
        '',
        '`t`t`tv := settings[moduleName]',
        '`t`t`t(v.type = "str")',
        '`t`t`t`t? UpdateStr(moduleName, (value = "<blank>") ? "" : value, v.section)',
        '`t`t`t`t: UpdateInt(moduleName, value, v.section)',
        '`t`t`tdiscord.SendEmbed(Format("Set module {} to {}!", displayName, value), 5066239, , , , id)',
        '`t`t}'
    )
    if InStr(c, 'case "modset":') {
        c := RegExReplace(c, '(?ms)^\t\tcase "modset":.*?(?=^\t\tcase "hourlyreport", "hr":)', modsetCanonical "`r`n`r`n")
    } else {
        commandNeedle := '`t`tcase "close":'
        commandInsert := JoinLines('', '', modsetCanonical, '', '', commandNeedle)
        cNew := StrReplace(c, commandNeedle, commandInsert)
        if (cNew != c) {
            c := cNew
            FileAppend("? Added modset command to Status.ahk`n", logFile)
        }
    }
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
            FileAppend("? Added hourlyreport command to Status.ahk`n", logFile)
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
            FileAppend("? Added stickerstack force-test command to Status.ahk`n", logFile)
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
            FileAppend("? Added fb force-test command to Status.ahk`n", logFile)
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
            FileAppend("? Added Auto-Jelly yes/no commands to Status.ahk`n", logFile)
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
        FileAppend("? Added Auto-Jelly failure ping routing to Status.ahk`n", logFile)
    }
    if InStr(c, '|| ((BalloonSSCheck = 1) && (stateString = "Converting: Balloon"))')
    && !InStr(c, '|| (((state = "Detected") || (state = "Keeping")) && (InStr(stateString, "Auto-Jelly") || InStr(stateString, "Bitterberry Auto-Feeder")))') {
        c := StrReplace(c
            , '|| ((BalloonSSCheck = 1) && (stateString = "Converting: Balloon"))'
            , '|| ((BalloonSSCheck = 1) && (stateString = "Converting: Balloon"))`r`n`t`t`t|| (((state = "Detected") || (state = "Keeping")) && (InStr(stateString, "Auto-Jelly") || InStr(stateString, "Bitterberry Auto-Feeder")))'
        )
        FileAppend("? Added Auto-Jelly success screenshot routing to Status.ahk`n", logFile)
    }
    }

    if (c != orig) {
        try {
            FileDelete(statusPath)
            FileAppend(c, statusPath, "UTF-8")
            msg .= "✓ Status.ahk patched`n"
        } catch {
            msg .= "⚠ FAILED to write Status.ahk`n"
        }
    }
}

if FileExist(reconnectSyncPath) {
    c := FileRead(reconnectSyncPath, "UTF-8")
    orig := c

    dq := Chr(34), sq := Chr(39)
    oldReconnectPayload := "payload_json := " . sq . "{" . dq . "content" . dq . ":" . dq . "NatroReconnectSync|DailyDisconnect|Daily Disconnect" . dq . "}" . sq
    newReconnectPayload := "payload_json := " . sq . "{" . dq . "content" . dq . ":" . dq . "SyncReconnect" . dq . "}" . sq
    c := StrReplace(c, oldReconnectPayload, newReconnectPayload)
    c := StrReplace(c, 'if InStr(msg_content, "NatroReconnectSync|DailyDisconnect") {', 'if InStr(msg_content, "SyncReconnect") {')

    if (c != orig) {
        try {
            FileDelete(reconnectSyncPath)
            FileAppend(c, reconnectSyncPath, "UTF-8")
            msg .= "âœ“ reconnectsync_status_extension.ahk patched`n"
        } catch {
            msg .= "âš  FAILED to write reconnectsync_status_extension.ahk`n"
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
                FileAppend("? Synced separate Baspas StatMonitor extra bitmap file`n", logFile)
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
                FileAppend("? Synced StatMonitor theme-aware base file`n", logFile)
            }
        } else {
            FileAppend("! Missing StatMonitor theme main template; continuing without base file sync`n", logFile)
        }

        runtimeText := ReadPatchBlock(statMonitorThemeRuntimeTemplatePath)
        if (runtimeText != "") {
            if !FileExist(statMonitorThemeRuntimePath) || (FileRead(statMonitorThemeRuntimePath, "UTF-8") != runtimeText) {
                try FileDelete(statMonitorThemeRuntimePath)
                FileAppend(runtimeText, statMonitorThemeRuntimePath, "UTF-8")
                FileAppend("? Synced StatMonitor theme runtime file`n", logFile)
            }
        } else {
            FileAppend("! Missing StatMonitor theme runtime template; continuing without runtime file sync`n", logFile)
        }

        editorText := ReadPatchBlock(statMonitorThemeEditorTemplatePath)
        if (editorText != "") {
            if !FileExist(statMonitorThemeEditorPath) || (FileRead(statMonitorThemeEditorPath, "UTF-8") != editorText) {
                try FileDelete(statMonitorThemeEditorPath)
                FileAppend(editorText, statMonitorThemeEditorPath, "UTF-8")
                FileAppend("? Synced StatMonitor theme editor file`n", logFile)
            }
        } else {
            FileAppend("! Missing StatMonitor theme editor template; continuing without editor file sync`n", logFile)
        }
    }

    c := FileRead(statMonitorPath, "UTF-8")
    orig := c

    if (patchForceHourly || patchStatMonitorTheme) && !InStr(c, '["Pine Tree",0]') {
        oldStatRows := 'stats := [["Total Boss Kills",0],["Total Vic Kills",0],["Total Bug Kills",0],["Total Planters",0],["Quests Done",0],["Disconnects",0]]'
        newStatRows := 'stats := [["Total Boss Kills",0],["Total Vic Kills",0],["Total Bug Kills",0],["Total Planters",0],["Quests Done",0],["Disconnects",0],["Pine Tree",0],["Blue Flower",0],["Bamboo",0]]'
        cNew := StrReplace(c, oldStatRows, newStatRows)
        if (cNew != c) {
            c := cNew
            FileAppend("? Added booster stats to StatMonitor stats row`n", logFile)
        }

        oldStatsOldRows := 'static honey_average := 0, honey_earned := 0, convert_time := 0, gather_time := 0, other_time := 0, stats_old := [["Total Boss Kills",0],["Total Vic Kills",0],["Total Bug Kills",0],["Total Planters",0],["Quests Done",0],["Disconnects",0]]'
        newStatsOldRows := 'static honey_average := 0, honey_earned := 0, convert_time := 0, gather_time := 0, other_time := 0, stats_old := [["Total Boss Kills",0],["Total Vic Kills",0],["Total Bug Kills",0],["Total Planters",0],["Quests Done",0],["Disconnects",0],["Pine Tree",0],["Blue Flower",0],["Bamboo",0]]'
        cNew := StrReplace(c, oldStatsOldRows, newStatsOldRows)
        if (cNew != c) {
            c := cNew
            FileAppend("? Added booster stats to StatMonitor historical rows`n", logFile)
        }
    }

    if patchStatMonitorTheme {
        themeInclude := '#Include "%A_ScriptDir%\StatMonitorThemeRuntime.ahk"'
        legacyThemeInclude := '#Include "StatMonitorThemeRuntime.ahk"'
        if InStr(c, legacyThemeInclude) && !InStr(c, themeInclude) {
            c := StrReplace(c, legacyThemeInclude, themeInclude)
            FileAppend("? Replaced legacy relative StatMonitor theme runtime include`n", logFile)
        } else if !InStr(c, themeInclude) {
            assetNeedle := '#Include "%A_ScriptDir%\..\nm_image_assets\statmonitor\bitmaps.ahk"'
            assetInsert := assetNeedle '`r`n' themeInclude
            cNew := StrReplace(c, assetNeedle, assetInsert)
            if (cNew != c) {
                c := cNew
                FileAppend("? Added StatMonitor theme runtime include`n", logFile)
            }
        }

        if InStr(c, 'pBrush := Gdip_BrushCreateSolid(0xff121212), Gdip_FillRoundedRectangle(G, pBrush, -1, -1, w+1, h+1, 60), Gdip_DeleteBrush(pBrush)') {
            c := StrReplace(c
                , 'pBrush := Gdip_BrushCreateSolid(0xff121212), Gdip_FillRoundedRectangle(G, pBrush, -1, -1, w+1, h+1, 60), Gdip_DeleteBrush(pBrush)'
                , 'StatMonitorTheme_DrawBackground(G, w, h)'
            )
            FileAppend("? Replaced StatMonitor base background with theme hook`n", logFile)
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
            FileAppend("? Replaced StatMonitor panel colors with theme hook`n", logFile)
        }

        if InStr(c, 'pBrush := Gdip_BrushCreateSolid(0x80141414)') {
            c := StrReplace(c, 'pBrush := Gdip_BrushCreateSolid(0x80141414)', 'pBrush := StatMonitorTheme_CreateGraphBackgroundBrush()')
            FileAppend("? Replaced StatMonitor graph background brush with theme hook`n", logFile)
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
            FileAppend("? Updated StatMonitor overlay hook to localized signature`n", logFile)
        }
        if !InStr(c, 'StatMonitorTheme_DrawOverlay(G, w, h, regions, stat_regions)') {
            cNew := StrReplace(c, overlayNeedle, overlayInsert)
            if (cNew != c) {
                c := cNew
                FileAppend("? Added StatMonitor overlay theme hook`n", logFile)
            }
        }

        infoBlockPattern := '(?ms)^\t; section 6: info\r?\n.*?(?=^\tStatMonitorTheme_DrawOverlay\(G, w, h, regions, stat_regions\)|^\tGdip_DeleteGraphics\(G\))'
        newInfoBlock := ReadPatchBlock(statMonitorInfoSectionTemplatePath)
        if (newInfoBlock != "") {
            if !InStr(c, 'StatMonitorTheme_GetInfoImageMode()') {
                cNew := RegExReplace(c, infoBlockPattern, newInfoBlock, &infoBlockCount, 1)
                if (infoBlockCount > 0 && cNew != c) {
                    c := cNew
                    FileAppend("? Added StatMonitor info image theme hook`n", logFile)
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
            FileAppend("? Added ForceReport message hook to StatMonitor.ahk`n", logFile)
        }
    }

    if patchForceHourly && !InStr(c, 'ForceReport(*)') {
        handlerNeedle := 'OnMessage(0x5563, ForceReport, 255)'
        handlerInsert := handlerNeedle '`r`n`r`nForceReport(*) {`r`n`tSendHourlyReport()`r`n}'
        cNew := StrReplace(c, handlerNeedle, handlerInsert)
        if (cNew != c) {
            c := cNew
            FileAppend("? Added ForceReport handler to StatMonitor.ahk`n", logFile)
        }
    }

    if patchForceHourly {
        legacyExtraBitmapBlockPattern := '(?ms)\Rif !buff_bitmaps\.Has\("pBMpinetreefieldboost"\)\R\{.*?\R\}'
        cNew := RegExReplace(c, legacyExtraBitmapBlockPattern, "", &legacyExtraBitmapBlockCount, 1)
        if (legacyExtraBitmapBlockCount > 0 && cNew != c) {
            c := cNew
            FileAppend("? Removed legacy inline StatMonitor extra bitmap fallback block`n", logFile)
        }

        extraBitmapInclude := '#Include "%A_ScriptDir%\..\nm_image_assets\statmonitor\extra_bitmaps.ahk"'
        if !InStr(c, extraBitmapInclude) {
            assetNeedle := '#Include "%A_ScriptDir%\..\nm_image_assets\statmonitor\bitmaps.ahk"'
            assetInsert := assetNeedle '`r`n' extraBitmapInclude
            cNew := StrReplace(c, assetNeedle, assetInsert)
            if (cNew != c) {
                c := cNew
                FileAppend("? Added separate StatMonitor extra bitmap include`n", logFile)
            }
        }

        if InStr(c, 'w := 6000, h := 5800') && !InStr(c, 'w := 6000, h := 6740') {
            c := StrReplace(c, 'w := 6000, h := 5800', 'w := 6000, h := 6740')
            FileAppend("? Expanded StatMonitor canvas for extra boost rows`n", logFile)
        }

        oldBuffList := 'for v in ["haste","melody","redboost","blueboost","whiteboost","focus","bombcombo","balloonaura","clock","jbshare","babylove","inspire","bear","pollenmark","honeymark","festivemark","popstar","comforting","motivating","satisfying","refreshing","invigorating","blessing","bloat","guiding","mondo","reindeerfetch","tideblessing"]'
        newBuffList := 'for v in ["haste","melody","redboost","blueboost","whiteboost","focus","bombcombo","balloonaura","clock","jbshare","babylove","inspire","bear","pollenmark","honeymark","festivemark","popstar","comforting","motivating","satisfying","refreshing","invigorating","blessing","bloat","guiding","mondo","reindeerfetch","tideblessing","beesmascheer","pinetreefieldboost","blueflowerfieldboost","bamboofieldboost","snowflakebuff","cloudbuff"]'
        if InStr(c, oldBuffList) {
            c := StrReplace(c, oldBuffList, newBuffList)
            FileAppend("? Added Baspas extra StatMonitor buff slots`n", logFile)
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
        FileAppend("? Resized StatMonitor stats/info panels for extra rows`n", logFile)
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
        FileAppend("? Added extra StatMonitor boost graph rows`n", logFile)
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
        FileAppend("? Added extra StatMonitor boost detections`n", logFile)
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
        FileAppend("? Switched snowflake to strip detection`n", logFile)
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
        FileAppend("? Added StatMonitor text fallback for missing boost icons`n", logFile)
    }
    c := StrReplace(c, '`t`t`t: (k = "festiveblessing") ? "Fest"`r`n', '')

    disposedBitmapDraw := 'Gdip_DrawImage(G, bitmaps["pBM" k], regions["buffs"][1]+75, v[2]+v[4]//2-55, 110, 110), Gdip_DisposeImage(bitmaps["pBM" k])'
    keptBitmapDraw := 'Gdip_DrawImage(G, bitmaps["pBM" k], regions["buffs"][1]+75, v[2]+v[4]//2-55, 110, 110)'
    if InStr(c, disposedBitmapDraw) {
        c := StrReplace(c, disposedBitmapDraw, keptBitmapDraw)
        FileAppend("? Preserved shared StatMonitor graph bitmap handles`n", logFile)
    }

    disposedStaticBitmapDraw := 'Gdip_DrawImage(G, bitmaps["pBM" v], stat_regions["buffs"][1]+48+(A_Index-1)*(stat_regions["buffs"][3]-96-220)/4, stat_regions["buffs"][2]+124, 220, 220), Gdip_DisposeImage(bitmaps["pBM" v])'
    keptStaticBitmapDraw := 'Gdip_DrawImage(G, bitmaps["pBM" v], stat_regions["buffs"][1]+48+(A_Index-1)*(stat_regions["buffs"][3]-96-220)/4, stat_regions["buffs"][2]+124, 220, 220)'
    if InStr(c, disposedStaticBitmapDraw) {
        c := StrReplace(c, disposedStaticBitmapDraw, keptStaticBitmapDraw)
        FileAppend("? Preserved shared StatMonitor static bitmap handles`n", logFile)
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
        FileAppend("? Added extra StatMonitor boost row colors`n", logFile)
    }
    c := StrReplace(c, '"guiding","festiveblessing","beesmascheer"', '"guiding","beesmascheer"')
    c := StrReplace(c, '`t`t`t`t: (k = "festiveblessing") ? 0xff00ff00`r`n', '')

    oldIncrementStat := 'IncrementStat(wParam, lParam, *){`r`n`tstats[wParam][2] += lParam`r`n`treturn 0`r`n}'
    newIncrementStat := 'IncrementStat(wParam, lParam, *){`r`n`tif !IsInteger(wParam)`r`n`t`treturn 0`r`n`tif (wParam < 1 || wParam > stats.Length)`r`n`t`treturn 0`r`n`tif !IsObject(stats[wParam]) || (stats[wParam].Length < 2)`r`n`t`treturn 0`r`n`tstats[wParam][2] += lParam`r`n`treturn 0`r`n}'
    if InStr(c, oldIncrementStat) {
        c := StrReplace(c, oldIncrementStat, newIncrementStat)
        FileAppend("? Hardened IncrementStat in StatMonitor.ahk`n", logFile)
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
        FileAppend("? Restored StatMonitor minX/maxX map handling`n", logFile)
    }

    oldHoneyGraph := '			points := []`r`n			honey_12h.__Enum().Call(&x), points.Push([4+v[3]*x/180, 4+v[4]])`r`n			for x,y in honey_12h`r`n				(y != "") && points.Push([4+v[3]*(max_x := x)/180, 4+v[4]-((y-min_12h)/range_12h)*v[4]])`r`n			points.Push([4+v[3]*max_x/180, 4+v[4]])`r`n			color := 0xff0e8bf0`r`n`r`n			pBrush := Gdip_BrushCreateSolid(color - 0x80000000)`r`n			Gdip_FillPolygon(G_Graph, pBrush, points)`r`n			Gdip_DeleteBrush(pBrush)`r`n`r`n			points.RemoveAt(1), points.Pop()`r`n			pPen := Gdip_CreatePen(color, 6)`r`n			Gdip_DrawLines(G_Graph, pPen, points)`r`n			Gdip_DeletePen(pPen)'
    newHoneyGraph := '			points := []`r`n			if (honey_12h.Count > 0)`r`n			{`r`n				enum := honey_12h.__Enum(1)`r`n				enum.Call(&x)`r`n				points.Push([4+v[3]*x/180, 4+v[4]])`r`n				for x,y in honey_12h`r`n					(y != "") && points.Push([4+v[3]*(max_x := x)/180, 4+v[4]-((y-min_12h)/range_12h)*v[4]])`r`n				points.Push([4+v[3]*max_x/180, 4+v[4]])`r`n			}`r`n			color := 0xff0e8bf0`r`n`r`n			if (points.Length > 2)`r`n			{`r`n				pBrush := Gdip_BrushCreateSolid(color - 0x80000000)`r`n				Gdip_FillPolygon(G_Graph, pBrush, points)`r`n				Gdip_DeleteBrush(pBrush)`r`n`r`n				points.RemoveAt(1), points.Pop()`r`n				pPen := Gdip_CreatePen(color, 6)`r`n				Gdip_DrawLines(G_Graph, pPen, points)`r`n				Gdip_DeletePen(pPen)`r`n			}'
    if InStr(c, oldHoneyGraph) {
        c := StrReplace(c, oldHoneyGraph, newHoneyGraph)
        FileAppend("? Hardened honey12h graph path in StatMonitor.ahk`n", logFile)
    }

    oldBackpackGraph := '			points := []`r`n			backpack_values.__Enum().Call(&x), points.Push([4+x*v[3]/3600, 4+v[4]])`r`n			for x,y in backpack_values`r`n				(y != "") && points.Push([4+(max_x := x)*v[3]/3600, 4+v[4]-(y/100)*v[4]])`r`n			points.Push([4+max_x*v[3]/3600, 4+v[4]])`r`n`r`n			pBrush := Gdip_CreateLinearGrBrushFromRect(4, 4, v[3], v[4], 0x00000000, 0x00000000)`r`n			Gdip_SetLinearGrBrushPresetBlend(pBrush, [0.0, 0.2, 0.8], [0xffff0000, 0xffff8000, 0xff41ff80])`r`n			pPen := Gdip_CreatePenFromBrush(pBrush, 6)`r`n			Gdip_SetLinearGrBrushPresetBlend(pBrush, [0.0, 0.2, 0.8], [0x80ff0000, 0x80ff8000, 0x8041ff80])`r`n			Gdip_FillPolygon(G_Graph, pBrush, points)`r`n			points.RemoveAt(1), points.Pop()`r`n			Gdip_DrawLines(G_Graph, pPen, points)`r`n			Gdip_DeletePen(pPen), Gdip_DeleteBrush(pBrush)'
    newBackpackGraph := '			points := []`r`n			if (backpack_values.Count > 0)`r`n			{`r`n				enum := backpack_values.__Enum(1)`r`n				enum.Call(&x)`r`n				points.Push([4+x*v[3]/3600, 4+v[4]])`r`n				for x,y in backpack_values`r`n					(y != "") && points.Push([4+(max_x := x)*v[3]/3600, 4+v[4]-(y/100)*v[4]])`r`n				points.Push([4+max_x*v[3]/3600, 4+v[4]])`r`n			}`r`n`r`n			if (points.Length > 2)`r`n			{`r`n				pBrush := Gdip_CreateLinearGrBrushFromRect(4, 4, v[3], v[4], 0x00000000, 0x00000000)`r`n				Gdip_SetLinearGrBrushPresetBlend(pBrush, [0.0, 0.2, 0.8], [0xffff0000, 0xffff8000, 0xff41ff80])`r`n				pPen := Gdip_CreatePenFromBrush(pBrush, 6)`r`n				Gdip_SetLinearGrBrushPresetBlend(pBrush, [0.0, 0.2, 0.8], [0x80ff0000, 0x80ff8000, 0x8041ff80])`r`n				Gdip_FillPolygon(G_Graph, pBrush, points)`r`n				points.RemoveAt(1), points.Pop()`r`n				Gdip_DrawLines(G_Graph, pPen, points)`r`n				Gdip_DeletePen(pPen), Gdip_DeleteBrush(pBrush)`r`n			}'
    if InStr(c, oldBackpackGraph) {
        c := StrReplace(c, oldBackpackGraph, newBackpackGraph)
        FileAppend("? Hardened backpack graph path in StatMonitor.ahk`n", logFile)
    }

    oldBoostGraph := '				points := []`r`n`r`n				buff_values[i].__Enum().Call(&x), points.Push([4+v[3]*x/600, 4+v[4]])`r`n				for x,y in buff_values[i]`r`n					points.Push([4+v[3]*(max_x := x)/600, 4+v[4]-((y <= 10) ? (y/10)*(v[4]) : 10)])`r`n				points.Push([4+v[3]*max_x/600, 4+v[4]])'
    newBoostGraph := '				points := []`r`n				if (buff_values[i].Count > 0)`r`n				{`r`n					enum := buff_values[i].__Enum(1)`r`n					enum.Call(&x)`r`n					points.Push([4+v[3]*x/600, 4+v[4]])`r`n					for x,y in buff_values[i]`r`n						points.Push([4+v[3]*(max_x := x)/600, 4+v[4]-((y <= 10) ? (y/10)*(v[4]) : 10)])`r`n					points.Push([4+v[3]*max_x/600, 4+v[4]])`r`n				}'
    if InStr(c, oldBoostGraph) {
        c := StrReplace(c, oldBoostGraph, newBoostGraph)
        FileAppend("? Hardened boost graph path in StatMonitor.ahk`n", logFile)
    }

    oldDefaultBuffGraph := '			points := []`r`n`r`n			buff_values[k].__Enum().Call(&x), points.Push([4+v[3]*x/600, 4+v[4]])`r`n			for x,y in buff_values[k]`r`n				points.Push([4+v[3]*(max_x := x)/600, 4+v[4]-(y/max_buff)*(v[4])])`r`n			points.Push([4+v[3]*max_x/600, 4+v[4]])'
    newDefaultBuffGraph := '			points := []`r`n			if (buff_values[k].Count > 0)`r`n			{`r`n				enum := buff_values[k].__Enum(1)`r`n				enum.Call(&x)`r`n				points.Push([4+v[3]*x/600, 4+v[4]])`r`n				for x,y in buff_values[k]`r`n					points.Push([4+v[3]*(max_x := x)/600, 4+v[4]-(y/max_buff)*(v[4])])`r`n				points.Push([4+v[3]*max_x/600, 4+v[4]])`r`n			}'
    if InStr(c, oldDefaultBuffGraph) {
        c := StrReplace(c, oldDefaultBuffGraph, newDefaultBuffGraph)
        FileAppend("? Hardened buff graph path in StatMonitor.ahk`n", logFile)
    }

    if InStr(c, 'DllCall("shlwapi\IStream_Size", "Ptr", pFileStream, "UInt64P", &size:=0, "UInt")') && !InStr(c, 'pngSize := size') {
        c := StrReplace(c, 'DllCall("shlwapi\IStream_Size", "Ptr", pFileStream, "UInt64P", &size:=0, "UInt")', 'DllCall("shlwapi\IStream_Size", "Ptr", pFileStream, "UInt64P", &size:=0, "UInt")`r`n`t`tpngSize := size')
        FileAppend("? Added StatMonitor PNG size capture for hourly uploads`n", logFile)
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
        FileAppend("? Moved StatMonitor attachment selection before multipart header build`n", logFile)
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
        FileAppend("? Added StatMonitor automatic PNG/JPG attachment fallback`n", logFile)
    }

    oldAttachmentUrl := '"image": {"url": "attachment://file.png"}'
    newAttachmentUrl := Chr(34) "image" Chr(34) ": {" Chr(34) "url" Chr(34) ": " Chr(34) "attachment://" Chr(39) " attachmentName " Chr(39) Chr(34) "}"
    brokenAttachmentUrl := Chr(34) "image" Chr(34) ": {" Chr(34) "url" Chr(34) ": " Chr(34) "attachment://" Chr(39) Chr(39) " attachmentName " Chr(39) Chr(39) Chr(34) "}"
    if InStr(c, oldAttachmentUrl) || InStr(c, brokenAttachmentUrl) {
        cNew := StrReplace(c, oldAttachmentUrl, newAttachmentUrl)
        cNew := StrReplace(cNew, brokenAttachmentUrl, newAttachmentUrl)
        c := cNew
        FileAppend("? Made StatMonitor attachment URL dynamic`n", logFile)
    }
    oldAttachmentFilename := 'Content-Disposition: form-data; name="files[0]"; filename="file.png"'
    newAttachmentFilename := "Content-Disposition: form-data; name=" Chr(34) "files[0]" Chr(34) "; filename=" Chr(34) Chr(39) " attachmentName " Chr(39) Chr(34)
    brokenAttachmentFilename := "Content-Disposition: form-data; name=" Chr(34) "files[0]" Chr(34) "; filename=" Chr(34) Chr(39) Chr(39) " attachmentName " Chr(39) Chr(39) Chr(34)
    if InStr(c, oldAttachmentFilename) || InStr(c, brokenAttachmentFilename) {
        cNew := StrReplace(c, oldAttachmentFilename, newAttachmentFilename)
        cNew := StrReplace(cNew, brokenAttachmentFilename, newAttachmentFilename)
        c := cNew
        FileAppend("? Made StatMonitor attachment filename dynamic`n", logFile)
    }
    oldAttachmentContentType := 'Content-Type: image/png'
    newAttachmentContentType := "Content-Type: " Chr(39) " attachmentContentType " Chr(39)
    brokenAttachmentContentType := "Content-Type: " Chr(39) Chr(39) " attachmentContentType " Chr(39) Chr(39)
    if ((InStr(c, oldAttachmentContentType) || InStr(c, brokenAttachmentContentType)) && (InStr(c, oldAttachmentFilename) || InStr(c, newAttachmentFilename) || InStr(c, brokenAttachmentFilename))) {
        cNew := StrReplace(c, oldAttachmentContentType, newAttachmentContentType)
        cNew := StrReplace(cNew, brokenAttachmentContentType, newAttachmentContentType)
        c := cNew
        FileAppend("? Made StatMonitor attachment content type dynamic`n", logFile)
    }

    oldDiagLine := '			try FileAppend("[" A_Now "] Hourly upload failed | status=" status " | pngBytes=" pngSize " | multipartBytes=" size " | response=" responseText . Chr(10), A_ScriptDir "\tadsync_debug.txt", "UTF-8")'
    newDiagLine := '			try FileAppend("[" A_Now "] Hourly upload failed | status=" status " | attachment=" attachmentName " | attachmentBytes=" attachmentSize " | pngBytes=" pngSize " | multipartBytes=" size " | response=" responseText . Chr(10), A_ScriptDir "\tadsync_debug.txt", "UTF-8")'
    if InStr(c, oldDiagLine) {
        c := StrReplace(c, oldDiagLine, newDiagLine)
        FileAppend("? Expanded StatMonitor upload diagnostics with attachment details`n", logFile)
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
        FileAppend("? Added StatMonitor attachment compression helper`n", logFile)
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
        FileAppend("? Added StatMonitor hourly HTTP status diagnostics`n", logFile)
    }
    }

    if (c != orig) {
        try {
            FileDelete(statMonitorPath)
            FileAppend(c, statMonitorPath, "UTF-8")
            msg .= "✓ StatMonitor.ahk patched`n"
        } catch {
            msg .= "⚠ FAILED to write StatMonitor.ahk`n"
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
        c := EnsureIniKey(c, "Collect", "BlueBoostCheck", 1, &cfgChanged)
    } else {
        c := SetIniSectionKey(c, "Boost", "BlueBoosterInterruptCheck", 0, &cfgChanged)
    }
    if patchStickerStack {
        c := EnsureIniKey(c, "Boost", "StickerStackInterruptCheck", 1, &cfgChanged)
        c := EnsureIniKey(c, "Boost", "LastStickerStackUse", 1, &cfgChanged)
    } else {
        c := SetIniSectionKey(c, "Boost", "StickerStackInterruptCheck", 0, &cfgChanged)
    }
    if (patchForceHourly || patchStatMonitorTheme) {
        c := EnsureIniKey(c, "Status", "TotalPineTree", 0, &cfgChanged)
        c := EnsureIniKey(c, "Status", "SessionPineTree", 0, &cfgChanged)
        c := EnsureIniKey(c, "Status", "TotalBlueFlower", 0, &cfgChanged)
        c := EnsureIniKey(c, "Status", "SessionBlueFlower", 0, &cfgChanged)
        c := EnsureIniKey(c, "Status", "TotalBamboo", 0, &cfgChanged)
        c := EnsureIniKey(c, "Status", "SessionBamboo", 0, &cfgChanged)
    }
    c := EnsureIniKey(c, "Extensions", "MondoInterruptCheck", 1, &cfgChanged)
    if patchGlitterExtend {
        c := EnsureIniKey(c, "Extensions", "PFieldBoosted", 0, &cfgChanged)
        c := EnsureIniKey(c, "Extensions", "PreGlitterCheck", 0, &cfgChanged)
    } else {
        c := SetIniSectionKey(c, "Extensions", "PFieldBoosted", 0, &cfgChanged)
        c := SetIniSectionKey(c, "Extensions", "PreGlitterCheck", 0, &cfgChanged)
    }
    if patchTadSyncCore {
        c := EnsureIniKey(c, "Extensions", "FieldFollowingCheck", 0, &cfgChanged)
        c := EnsureIniKey(c, "Extensions", "FieldFollowingHiveRedirect", "Blue Flower", &cfgChanged)
    } else {
        c := SetIniSectionKey(c, "Extensions", "FieldFollowingCheck", 0, &cfgChanged)
        c := SetIniSectionKey(c, "Extensions", "FieldFollowingHiveRedirect", "Blue Flower", &cfgChanged)
    }
    c := EnsureIniKey(c, "Extensions", "EnzymesBoostedOnly", 1, &cfgChanged)
    c := EnsureIniKey(c, "Extensions", "ReconnectSyncCheck", 1, &cfgChanged)
    c := EnsureIniSectionKey(c, "Extensions", "ReconnectSyncMode", "Main", &cfgChanged)
    c := EnsureIniSectionKey(c, "Extensions", "ReconnectSyncChannelID", "", &cfgChanged)
    c := RegExReplace(c, '(?ms)^\[Boost\]\R(.*?\R)EnzymesBoostedOnly=\d+\R', '[Boost]`r`n$1')
    c := RegExReplace(c, '(?ms)^\[Settings\]\R(.*?\R)EnzymesBoostedOnly=\d+\R', '[Settings]`r`n$1')
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
        c := EnsureIniSectionKey(c, "StatMonitorTheme", "HoneyGatherColor", "FFA6FF7C", &cfgChanged)
        c := EnsureIniSectionKey(c, "StatMonitorTheme", "HoneyConvertColor", "FFFECA40", &cfgChanged)
        c := EnsureIniSectionKey(c, "StatMonitorTheme", "HoneyOtherColor", "FF859AAD", &cfgChanged)
        c := EnsureIniSectionKey(c, "StatMonitorTheme", "BackpackColorStart", "FFFF0000", &cfgChanged)
        c := EnsureIniSectionKey(c, "StatMonitorTheme", "BackpackColorMid", "FFFF8000", &cfgChanged)
        c := EnsureIniSectionKey(c, "StatMonitorTheme", "BackpackColorEnd", "FF41FF80", &cfgChanged)
        c := EnsureIniSectionKey(c, "StatMonitorTheme", "PieGatherColor", "FFA6FF7C", &cfgChanged)
        c := EnsureIniSectionKey(c, "StatMonitorTheme", "PieConvertColor", "FFFECA40", &cfgChanged)
        c := EnsureIniSectionKey(c, "StatMonitorTheme", "PieOtherColor", "FF859AAD", &cfgChanged)
    }

    if (c != orig) {
        try {
            FileDelete(configPath)
            FileAppend(c, configPath, "UTF-8")
            msg .= "✓ nm_config.ini patched`n"
        } catch {
            msg .= "⚠ FAILED to write nm_config.ini`n"
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
    c := EnsureIniSectionKey(c, "StatMonitorTheme", "HoneyGatherColor", "FFA6FF7C", &cfgChanged)
    c := EnsureIniSectionKey(c, "StatMonitorTheme", "HoneyConvertColor", "FFFECA40", &cfgChanged)
    c := EnsureIniSectionKey(c, "StatMonitorTheme", "HoneyOtherColor", "FF859AAD", &cfgChanged)
    c := EnsureIniSectionKey(c, "StatMonitorTheme", "BackpackColorStart", "FFFF0000", &cfgChanged)
    c := EnsureIniSectionKey(c, "StatMonitorTheme", "BackpackColorMid", "FFFF8000", &cfgChanged)
    c := EnsureIniSectionKey(c, "StatMonitorTheme", "BackpackColorEnd", "FF41FF80", &cfgChanged)
    c := EnsureIniSectionKey(c, "StatMonitorTheme", "PieGatherColor", "FFA6FF7C", &cfgChanged)
    c := EnsureIniSectionKey(c, "StatMonitorTheme", "PieConvertColor", "FFFECA40", &cfgChanged)
    c := EnsureIniSectionKey(c, "StatMonitorTheme", "PieOtherColor", "FF859AAD", &cfgChanged)

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
            msg .= "✓ statmonitor_theme.ini patched`n"
        } catch {
            msg .= "⚠ FAILED to write statmonitor_theme.ini`n"
        }
    }
}

; 3. PATCH ENUMS
if (patchTadSyncCore || patchGlitterExtend || patchBfb || patchStickerStack || patchEnzymeBalloon || patchMondoInterrupt) {
try {
    if FileExist(enumIntPath) {
        c := FileRead(enumIntPath, "UTF-8")
        orig := c
        vars := ["FieldFollowingCheck", "VicHopCheck", "AltHopMondoEnabled", "BlueBoosterInterruptCheck", "StickerStackInterruptCheck", "PFieldBoosted", "PreGlitterCheck", "EnzymesBoostedOnly", "MondoInterruptCheck", "ReconnectSyncCheck", "ReconnectSyncMode", "ReconnectSyncChannelID"]
        for v in vars {
            if !InStr(c, '"' v '"') {
                c := RegExReplace(c, "(\s*\])", '`r`n`t, "' v '"$1')
            }
        }
        if (c != orig) {
            FileDelete(enumIntPath)
            FileAppend(c, enumIntPath, "UTF-8")
            msg .= "✓ EnumInt.ahk registered`n"
            FileAppend("✓ Registered custom module enums in EnumInt.ahk`n", logFile)
        }
    }
} catch {
    msg .= "⚠ FAILED to patch EnumInt.ahk`n"
}

try {
    if FileExist(enumStrPath) {
        c := FileRead(enumStrPath, "UTF-8")
        orig := c
        vars := ["FieldFollowingFollowMode", "FieldFollowingMaxTime", "FieldFollowingChannelID", "FieldFollowingHiveRedirect", "VicHopMode", "VicHopMaxQueueTime", "VicHopChannelID", "AltHopMondoLeadTime"]
        for v in vars {
            if !InStr(c, '"' v '"') {
                c := RegExReplace(c, "(\s*\])", '`r`n`t, "' v '"$1')
            }
        }
        if (c != orig) {
            FileDelete(enumStrPath)
            FileAppend(c, enumStrPath, "UTF-8")
            msg .= "✓ EnumStr.ahk registered`n"
            FileAppend("✓ Registered custom module strings in EnumStr.ahk`n", logFile)
        }
    }
} catch {
    msg .= "⚠ FAILED to patch EnumStr.ahk`n"
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





