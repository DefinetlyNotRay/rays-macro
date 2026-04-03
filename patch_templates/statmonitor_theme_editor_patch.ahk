#Requires AutoHotkey v2.0
#SingleInstance Force
; Made by @definetlynotray on discord

SetWorkingDir A_ScriptDir "\.."

global SMThemeSettingsDir := A_ScriptDir "\..\settings"
global SMThemeConfigPath := SMThemeSettingsDir "\statmonitor_theme.ini"
global SMThemeLegacyConfigPath := SMThemeSettingsDir "\nm_config.ini"
global SMThemeSection := "StatMonitorTheme"
global SMThemeDefaults := StatMonitorThemeEditor_Defaults()
global SMThemeControls := Map()
global SMThemeMockState := Map("Running", false, "Pid", 0, "TempScriptPath", "")
global SMThemeGui := Gui("+Resize +MinSize620x730", "StatMonitor Theme Editor")
SMThemeGui.Opt("+OwnDialogs")

themeValues := StatMonitorThemeEditor_Load()
StatMonitorThemeEditor_BuildGui(themeValues)
SMThemeGui.OnEvent("Close", (*) => ExitApp())
SMThemeGui.Show("w620 h730")
return

StatMonitorThemeEditor_BuildGui(values) {
	global SMThemeGui
	; Made by @definetlynotray on discord - theme editor surface
	SMThemeGui.SetFont("s9", "Segoe UI")
	SMThemeGui.Add("Text", "x12 y12 w590", "Customize StatMonitor's background image and colors. Saved changes apply the next time StatMonitor starts.")
	tabs := SMThemeGui.Add("Tab3", "x12 y40 w592 h618", ["Style", "Images"])

	tabs.UseTab("Style")
	SMThemeGui.Add("GroupBox", "x24 y78 w568 h132", "Background")
	StatMonitorThemeEditor_AddDropDown(40, 106, "Mode", "BackgroundMode", ["Default", "Flat", "Gradient"], values["BackgroundMode"])
	StatMonitorThemeEditor_AddColorField(320, 106, "Graph Fill", "GraphFill", values["GraphFill"])
	StatMonitorThemeEditor_AddColorField(40, 140, "Flat Color", "BackgroundFlat", values["BackgroundFlat"])
	StatMonitorThemeEditor_AddColorField(320, 140, "Gradient Top", "BackgroundGradientTop", values["BackgroundGradientTop"])
	StatMonitorThemeEditor_AddColorField(40, 174, "Gradient Bottom", "BackgroundGradientBottom", values["BackgroundGradientBottom"])

	SMThemeGui.Add("GroupBox", "x24 y222 w568 h148", "Panels")
	StatMonitorThemeEditor_AddColorField(40, 250, "Region Fill", "RegionFill", values["RegionFill"])
	StatMonitorThemeEditor_AddColorField(320, 250, "Region Border", "RegionBorder", values["RegionBorder"])
	StatMonitorThemeEditor_AddColorField(40, 284, "Stat Fill", "StatRegionFill", values["StatRegionFill"])
	StatMonitorThemeEditor_AddColorField(320, 284, "Stat Border", "StatRegionBorder", values["StatRegionBorder"])
	SMThemeGui.Add("Text", "x40 y316 w88", "Region Opacity")
	SMThemeControls["RegionOpacity"] := SMThemeGui.Add("Edit", "x136 y312 w96 Number Limit3", values["RegionOpacity"])
	SMThemeGui.Add("Text", "x276 y316 w96", "Border Opacity")
	SMThemeControls["RegionBorderOpacity"] := SMThemeGui.Add("Edit", "x380 y312 w96 Number Limit3", values["RegionBorderOpacity"])
	SMThemeGui.Add("Text", "x40 y348 w88", "Stat Opacity")
	SMThemeControls["StatRegionOpacity"] := SMThemeGui.Add("Edit", "x136 y344 w96 Number Limit3", values["StatRegionOpacity"])
	SMThemeGui.Add("Text", "x276 y348 w96", "Stat Border")
	SMThemeControls["StatRegionBorderOpacity"] := SMThemeGui.Add("Edit", "x380 y344 w96 Number Limit3", values["StatRegionBorderOpacity"])

	SMThemeGui.Add("GroupBox", "x24 y402 w568 h170", "Text Colors")
	StatMonitorThemeEditor_AddColorField(40, 436, "Primary", "TextPrimary", values["TextPrimary"])
	StatMonitorThemeEditor_AddColorField(320, 436, "Secondary", "TextSecondary", values["TextSecondary"])
	StatMonitorThemeEditor_AddColorField(40, 470, "Muted", "TextMuted", values["TextMuted"])
	StatMonitorThemeEditor_AddColorField(320, 470, "Accent", "TextAccent", values["TextAccent"])
	StatMonitorThemeEditor_AddColorField(40, 504, "Link", "TextLink", values["TextLink"])
	StatMonitorThemeEditor_AddColorField(320, 504, "Success", "TextPositive", values["TextPositive"])
	StatMonitorThemeEditor_AddColorField(40, 538, "Danger", "TextNegative", values["TextNegative"])
	StatMonitorThemeEditor_AddColorField(320, 538, "Brand", "TextBrand", values["TextBrand"])

	tabs.UseTab("Images")
	SMThemeGui.Add("GroupBox", "x24 y78 w568 h220", "Theme Image")
	SMThemeGui.Add("Text", "x40 y112 w88", "Image Path")
	SMThemeControls["ImagePath"] := SMThemeGui.Add("Edit", "x136 y106 w360 h27 -Multi", values["ImagePath"])
	browseButton := SMThemeGui.Add("Button", "x504 y107 w52", "Browse")
	clearButton := SMThemeGui.Add("Button", "x560 y107 w24", "X")
	browseButton.OnEvent("Click", StatMonitorThemeEditor_BrowseImage)
	clearButton.OnEvent("Click", (*) => SMThemeControls["ImagePath"].Value := "")
	SMThemeGui.Add("Text", "x40 y148 w88", "Layer")
	StatMonitorThemeEditor_AddDropDown(136, 144, "", "ImageLayer", ["Background", "Overlay"], values["ImageLayer"], 92)
	SMThemeGui.Add("Text", "x248 y148 w60", "Opacity")
	SMThemeControls["ImageOpacity"] := SMThemeGui.Add("Edit", "x312 y144 w56 Number Limit3", values["ImageOpacity"])
	SMThemeGui.Add("Text", "x400 y148 w24", "Fit")
	StatMonitorThemeEditor_AddDropDown(428, 144, "", "ImageFit", ["Contain", "Cover", "Stretch", "Original"], values["ImageFit"], 92)
	SMThemeGui.Add("Text", "x40 y184 w88", "Scale %")
	SMThemeControls["ImageScale"] := SMThemeGui.Add("Edit", "x136 y180 w70 Number Limit3", values["ImageScale"])
	SMThemeGui.Add("Text", "x232 y184 w88", "Offset X")
	SMThemeControls["ImageOffsetX"] := SMThemeGui.Add("Edit", "x328 y180 w70", values["ImageOffsetX"])
	SMThemeGui.Add("Text", "x424 y184 w76", "Offset Y")
	SMThemeControls["ImageOffsetY"] := SMThemeGui.Add("Edit", "x504 y180 w70", values["ImageOffsetY"])
	SMThemeGui.Add("Text", "x40 y218 w520 c666666", "Tip: Overlay spans the full StatMonitor canvas. Background keeps the image behind the panels.")

	SMThemeGui.Add("GroupBox", "x24 y310 w568 h138", "Info Image")
	SMThemeGui.Add("Text", "x40 y344 w88", "Image Path")
	SMThemeControls["InfoImagePath"] := SMThemeGui.Add("Edit", "x136 y338 w360 h27 -Multi", values["InfoImagePath"])
	infoBrowseButton := SMThemeGui.Add("Button", "x504 y339 w52", "Browse")
	infoClearButton := SMThemeGui.Add("Button", "x560 y339 w24", "X")
	infoBrowseButton.OnEvent("Click", StatMonitorThemeEditor_BrowseInfoImage)
	infoClearButton.OnEvent("Click", (*) => SMThemeControls["InfoImagePath"].Value := "")
	SMThemeGui.Add("Text", "x40 y380 w88", "Mode")
	StatMonitorThemeEditor_AddDropDown(136, 376, "", "InfoImageMode", ["Off", "Replace Text", "Under Text"], values["InfoImageMode"], 120)
	SMThemeGui.Add("Text", "x280 y380 w60", "Opacity")
	SMThemeControls["InfoImageOpacity"] := SMThemeGui.Add("Edit", "x344 y376 w56 Number Limit3", values["InfoImageOpacity"])
	SMThemeGui.Add("Text", "x432 y380 w24", "Fit")
	StatMonitorThemeEditor_AddDropDown(460, 376, "", "InfoImageFit", ["Contain", "Cover", "Stretch", "Original"], values["InfoImageFit"], 92)
	SMThemeGui.Add("Text", "x40 y408 w520 h32 c666666", "Replace Text fills the whole info panel. Under Text keeps the header lines and uses the empty space below them.")

	SMThemeGui.Add("GroupBox", "x24 y458 w568 h138", "Stats Image")
	SMThemeGui.Add("Text", "x40 y492 w88", "Image Path")
	SMThemeControls["StatsImagePath"] := SMThemeGui.Add("Edit", "x136 y486 w360 h27 -Multi", values["StatsImagePath"])
	statsBrowseButton := SMThemeGui.Add("Button", "x504 y487 w52", "Browse")
	statsClearButton := SMThemeGui.Add("Button", "x560 y487 w24", "X")
	statsBrowseButton.OnEvent("Click", StatMonitorThemeEditor_BrowseStatsImage)
	statsClearButton.OnEvent("Click", (*) => SMThemeControls["StatsImagePath"].Value := "")
	SMThemeGui.Add("Text", "x40 y528 w88", "Mode")
	StatMonitorThemeEditor_AddDropDown(136, 524, "", "StatsImageMode", ["Off", "Replace Panel"], values["StatsImageMode"], 120)
	SMThemeGui.Add("Text", "x280 y528 w60", "Opacity")
	SMThemeControls["StatsImageOpacity"] := SMThemeGui.Add("Edit", "x344 y524 w56 Number Limit3", values["StatsImageOpacity"])
	SMThemeGui.Add("Text", "x432 y528 w24", "Fit")
	StatMonitorThemeEditor_AddDropDown(460, 524, "", "StatsImageFit", ["Contain", "Cover", "Stretch", "Original"], values["StatsImageFit"], 92)
	SMThemeGui.Add("Text", "x40 y556 w520 h32 c666666", "Replace Panel swaps the full stats panel text area for an image, since there is no room below the stats rows.")

	tabs.UseTab()

	saveButton := SMThemeGui.Add("Button", "x12 y670 w88 Default", "Save")
	mockButton := SMThemeGui.Add("Button", "x108 y670 w108 vMockHourlyButton", "Mock Hourly")
	importButton := SMThemeGui.Add("Button", "x224 y670 w88", "Import")
	exportButton := SMThemeGui.Add("Button", "x320 y670 w88", "Export")
	resetButton := SMThemeGui.Add("Button", "x416 y670 w104", "Reset Defaults")
	closeButton := SMThemeGui.Add("Button", "x528 y670 w76", "Close")
	SMThemeControls["MockHourlyButton"] := mockButton
	saveButton.OnEvent("Click", StatMonitorThemeEditor_Save)
	mockButton.OnEvent("Click", StatMonitorThemeEditor_GenerateMock)
	importButton.OnEvent("Click", StatMonitorThemeEditor_Import)
	exportButton.OnEvent("Click", StatMonitorThemeEditor_Export)
	resetButton.OnEvent("Click", StatMonitorThemeEditor_ResetDefaults)
	closeButton.OnEvent("Click", (*) => ExitApp())
}

StatMonitorThemeEditor_AddDropDown(x, y, labelText, key, items, value, width := 120) {
	global SMThemeGui, SMThemeControls
	if (labelText != "")
		SMThemeGui.Add("Text", Format("x{} y{} w88", x, y + 4), labelText)

	controlX := (labelText != "") ? x + 96 : x
	(SMThemeControls[key] := SMThemeGui.Add("DropDownList", Format("x{} y{} w{}", controlX, y, width), items)).Text := value
}

StatMonitorThemeEditor_AddColorField(x, y, labelText, key, value) {
	global SMThemeGui, SMThemeControls
	SMThemeGui.Add("Text", Format("x{} y{} w88", x, y + 4), labelText)
	SMThemeControls[key] := SMThemeGui.Add("Edit", Format("x{} y{} w96 Uppercase", x + 96, y), value)
	pickButton := SMThemeGui.Add("Button", Format("x{} y{} w48", x + 198, y - 1), "Pick")
	pickButton.OnEvent("Click", (*) => StatMonitorThemeEditor_PickColor(key))
}


StatMonitorThemeEditor_BrowseImage(*) {
	global SMThemeControls, SMThemeSettingsDir
	currentPath := Trim(SMThemeControls["ImagePath"].Value, ' "')
	startPath := (currentPath != "" && FileExist(currentPath)) ? currentPath : SMThemeSettingsDir
	path := FileSelect(, startPath, "Select Background Image", "Image Files (*.png; *.jpg; *.jpeg; *.bmp; *.gif; *.webp)")
	if (path != "")
		SMThemeControls["ImagePath"].Value := path
}

StatMonitorThemeEditor_BrowseInfoImage(*) {
	global SMThemeControls, SMThemeSettingsDir
	currentPath := Trim(SMThemeControls["InfoImagePath"].Value, ' "')
	startPath := (currentPath != "" && FileExist(currentPath)) ? currentPath : SMThemeSettingsDir
	path := FileSelect(, startPath, "Select Info Panel Image", "Image Files (*.png; *.jpg; *.jpeg; *.bmp; *.gif; *.webp)")
	if (path != "")
		SMThemeControls["InfoImagePath"].Value := path
}

StatMonitorThemeEditor_BrowseStatsImage(*) {
	global SMThemeControls, SMThemeSettingsDir
	currentPath := Trim(SMThemeControls["StatsImagePath"].Value, ' "')
	startPath := (currentPath != "" && FileExist(currentPath)) ? currentPath : SMThemeSettingsDir
	path := FileSelect(, startPath, "Select Stats Panel Image", "Image Files (*.png; *.jpg; *.jpeg; *.bmp; *.gif; *.webp)")
	if (path != "")
		SMThemeControls["StatsImagePath"].Value := path
}

StatMonitorThemeEditor_PickColor(key) {
	global SMThemeControls, SMThemeDefaults, SMThemeGui
	current := StatMonitorThemeEditor_ParseColor(SMThemeControls[key].Value, StatMonitorThemeEditor_ParseColor(SMThemeDefaults[key], 0xff000000))
	alpha := (current >> 24) & 0xff
	rgb := current & 0xffffff
	picked := StatMonitorThemeEditor_ChooseRgbColor(rgb, SMThemeGui.Hwnd)
	if (picked = "")
		return
	SMThemeControls[key].Value := Format("{:02X}{:06X}", alpha, picked)
}

StatMonitorThemeEditor_Save(*) {
	values := StatMonitorThemeEditor_CollectValues()
	if !IsObject(values)
		return

	StatMonitorThemeEditor_WriteValuesToFile(SMThemeConfigPath, values)

	MsgBox("StatMonitor theme saved.`n`nRestart StatMonitor to apply the new image/colors.", "StatMonitor Theme", 0x40)
}

StatMonitorThemeEditor_GenerateMock(*) {
	global SMThemeConfigPath, SMThemeGui, SMThemeMockState, SMThemeControls
	; Made by @definetlynotray on discord

	values := StatMonitorThemeEditor_CollectValues()
	if !IsObject(values)
		return

	if (SMThemeMockState["Running"])
		return

	StatMonitorThemeEditor_WriteValuesToFile(SMThemeConfigPath, values)

	statMonitorPath := A_WorkingDir "\submacros\StatMonitor.ahk"
	previewScriptPath := A_WorkingDir "\submacros\StatMonitorMockRun.ahk"
	if !FileExist(statMonitorPath) {
		MsgBox("StatMonitor.ahk was not found in submacros.", "StatMonitor Theme", 0x30)
		return
	}

	try FileDelete(previewScriptPath)
	FileCopy(statMonitorPath, previewScriptPath, 1)

	command := '"' A_AhkPath '" /script "' previewScriptPath '" --mock-send'
	try Run(command, A_WorkingDir, "Hide", &mockPid)
	catch as e {
		try FileDelete(previewScriptPath)
		MsgBox("Failed to send the mock hourly report.`n`n" e.Message, "StatMonitor Theme", 0x10)
		return
	}

	SMThemeMockState["Running"] := true
	SMThemeMockState["Pid"] := mockPid
	SMThemeMockState["TempScriptPath"] := previewScriptPath
	SMThemeControls["MockHourlyButton"].Enabled := false
	SMThemeControls["MockHourlyButton"].Text := "Sending..."
	SetTimer(StatMonitorThemeEditor_WatchMockProcess, 250)
}

StatMonitorThemeEditor_BringToFront() {
	global SMThemeGui
	try {
		SMThemeGui.Show()
		WinSetAlwaysOnTop(1, "ahk_id " SMThemeGui.Hwnd)
		WinActivate("ahk_id " SMThemeGui.Hwnd)
		WinWaitActive("ahk_id " SMThemeGui.Hwnd, , 1)
		Sleep(150)
		WinSetAlwaysOnTop(0, "ahk_id " SMThemeGui.Hwnd)
	}
}

StatMonitorThemeEditor_WatchMockProcess() {
	global SMThemeMockState, SMThemeControls

	if !SMThemeMockState["Running"] {
		SetTimer(StatMonitorThemeEditor_WatchMockProcess, 0)
		return
	}

	pid := SMThemeMockState["Pid"]
	if ProcessExist(pid)
		return

	SetTimer(StatMonitorThemeEditor_WatchMockProcess, 0)
	try FileDelete(SMThemeMockState["TempScriptPath"])
	SMThemeMockState["Running"] := false
	SMThemeMockState["Pid"] := 0
	SMThemeMockState["TempScriptPath"] := ""
	SMThemeControls["MockHourlyButton"].Enabled := true
	SMThemeControls["MockHourlyButton"].Text := "Mock Hourly"
	StatMonitorThemeEditor_BringToFront()
	MsgBox("Mock hourly report sent through StatMonitor.", "StatMonitor Theme", 0x40)
}

StatMonitorThemeEditor_Import(*) {
	global SMThemeSettingsDir
	defaultPath := SMThemeSettingsDir "\statmonitor_theme_export.ini"
	path := FileSelect(1, defaultPath, "Import StatMonitor Theme", "INI Files (*.ini)")
	if (path = "")
		return

	values := StatMonitorThemeEditor_LoadFromFile(path)
	if !IsObject(values) {
		MsgBox("That file does not contain a valid [StatMonitorTheme] section.", "StatMonitor Theme", 0x30)
		return
	}

	StatMonitorThemeEditor_ApplyValuesToControls(values)
	StatMonitorThemeEditor_WriteValuesToFile(SMThemeConfigPath, values)
	MsgBox("StatMonitor theme imported.`n`nRestart StatMonitor to apply the imported settings.", "StatMonitor Theme", 0x40)
}

StatMonitorThemeEditor_Export(*) {
	global SMThemeSettingsDir
	values := StatMonitorThemeEditor_CollectValues(false)
	if !IsObject(values)
		return

	defaultPath := SMThemeSettingsDir "\statmonitor_theme_export.ini"
	path := FileSelect("S16", defaultPath, "Export StatMonitor Theme", "INI Files (*.ini)")
	if (path = "")
		return

	if !InStr(StrLower(path), ".ini")
		path .= ".ini"

	StatMonitorThemeEditor_WriteValuesToFile(path, values)
	MsgBox("StatMonitor theme exported to:`n`n" path, "StatMonitor Theme", 0x40)
}

StatMonitorThemeEditor_ResetDefaults(*) {
	defaults := StatMonitorThemeEditor_Defaults()
	for key, value in defaults {
		if !SMThemeControls.Has(key)
			continue
		if (key = "BackgroundMode" || key = "ImageLayer" || key = "ImageFit" || key = "InfoImageMode" || key = "InfoImageFit")
			SMThemeControls[key].Text := value
		else
			SMThemeControls[key].Value := value
	}
}

StatMonitorThemeEditor_CollectValues(validatePaths := true) {
	global SMThemeControls, SMThemeDefaults

	values := Map()
	values.CaseSense := 0
	values["BackgroundMode"] := StatMonitorThemeEditor_NormalizeBackgroundMode(SMThemeControls["BackgroundMode"].Text)
	values["BackgroundFlat"] := StatMonitorThemeEditor_NormalizeColorText(SMThemeControls["BackgroundFlat"].Value, SMThemeDefaults["BackgroundFlat"])
	values["BackgroundGradientTop"] := StatMonitorThemeEditor_NormalizeColorText(SMThemeControls["BackgroundGradientTop"].Value, SMThemeDefaults["BackgroundGradientTop"])
	values["BackgroundGradientBottom"] := StatMonitorThemeEditor_NormalizeColorText(SMThemeControls["BackgroundGradientBottom"].Value, SMThemeDefaults["BackgroundGradientBottom"])
	values["RegionBorder"] := StatMonitorThemeEditor_NormalizeColorText(SMThemeControls["RegionBorder"].Value, SMThemeDefaults["RegionBorder"])
	values["RegionBorderOpacity"] := StatMonitorThemeEditor_ClampInteger(SMThemeControls["RegionBorderOpacity"].Value, 100, 0, 100)
	values["RegionFill"] := StatMonitorThemeEditor_NormalizeColorText(SMThemeControls["RegionFill"].Value, SMThemeDefaults["RegionFill"])
	values["RegionOpacity"] := StatMonitorThemeEditor_ClampInteger(SMThemeControls["RegionOpacity"].Value, 100, 0, 100)
	values["StatRegionBorder"] := StatMonitorThemeEditor_NormalizeColorText(SMThemeControls["StatRegionBorder"].Value, SMThemeDefaults["StatRegionBorder"])
	values["StatRegionBorderOpacity"] := StatMonitorThemeEditor_ClampInteger(SMThemeControls["StatRegionBorderOpacity"].Value, 100, 0, 100)
	values["StatRegionFill"] := StatMonitorThemeEditor_NormalizeColorText(SMThemeControls["StatRegionFill"].Value, SMThemeDefaults["StatRegionFill"])
	values["StatRegionOpacity"] := StatMonitorThemeEditor_ClampInteger(SMThemeControls["StatRegionOpacity"].Value, 100, 0, 100)
	values["GraphFill"] := StatMonitorThemeEditor_NormalizeColorText(SMThemeControls["GraphFill"].Value, SMThemeDefaults["GraphFill"])
	values["TextPrimary"] := StatMonitorThemeEditor_NormalizeColorText(SMThemeControls["TextPrimary"].Value, SMThemeDefaults["TextPrimary"])
	values["TextSecondary"] := StatMonitorThemeEditor_NormalizeColorText(SMThemeControls["TextSecondary"].Value, SMThemeDefaults["TextSecondary"])
	values["TextMuted"] := StatMonitorThemeEditor_NormalizeColorText(SMThemeControls["TextMuted"].Value, SMThemeDefaults["TextMuted"])
	values["TextAccent"] := StatMonitorThemeEditor_NormalizeColorText(SMThemeControls["TextAccent"].Value, SMThemeDefaults["TextAccent"])
	values["TextLink"] := StatMonitorThemeEditor_NormalizeColorText(SMThemeControls["TextLink"].Value, SMThemeDefaults["TextLink"])
	values["TextPositive"] := StatMonitorThemeEditor_NormalizeColorText(SMThemeControls["TextPositive"].Value, SMThemeDefaults["TextPositive"])
	values["TextNegative"] := StatMonitorThemeEditor_NormalizeColorText(SMThemeControls["TextNegative"].Value, SMThemeDefaults["TextNegative"])
	values["TextBrand"] := StatMonitorThemeEditor_NormalizeColorText(SMThemeControls["TextBrand"].Value, SMThemeDefaults["TextBrand"])

	imagePath := Trim(SMThemeControls["ImagePath"].Value, ' "')
	if (validatePaths && (imagePath != "") && !FileExist(imagePath)) {
		MsgBox("The selected background image does not exist anymore.", "StatMonitor Theme", 0x30)
		return false
	}
	values["ImagePath"] := imagePath
	values["ImageLayer"] := StatMonitorThemeEditor_NormalizeImageLayer(SMThemeControls["ImageLayer"].Text)
	values["ImageOpacity"] := StatMonitorThemeEditor_ClampInteger(SMThemeControls["ImageOpacity"].Value, 55, 0, 100)
	values["ImageFit"] := StatMonitorThemeEditor_NormalizeImageFit(SMThemeControls["ImageFit"].Text)
	values["ImageScale"] := StatMonitorThemeEditor_ClampInteger(SMThemeControls["ImageScale"].Value, 100, 10, 400)
	values["ImageOffsetX"] := StatMonitorThemeEditor_ClampInteger(SMThemeControls["ImageOffsetX"].Value, 0, -6000, 6000)
	values["ImageOffsetY"] := StatMonitorThemeEditor_ClampInteger(SMThemeControls["ImageOffsetY"].Value, 0, -6000, 6000)

	infoImagePath := Trim(SMThemeControls["InfoImagePath"].Value, ' "')
	if (validatePaths && (infoImagePath != "") && !FileExist(infoImagePath)) {
		MsgBox("The selected info panel image does not exist anymore.", "StatMonitor Theme", 0x30)
		return false
	}
	values["InfoImagePath"] := infoImagePath
	values["InfoImageMode"] := StatMonitorThemeEditor_NormalizeInfoImageMode(SMThemeControls["InfoImageMode"].Text)
	values["InfoImageOpacity"] := StatMonitorThemeEditor_ClampInteger(SMThemeControls["InfoImageOpacity"].Value, 100, 0, 100)
	values["InfoImageFit"] := StatMonitorThemeEditor_NormalizeImageFit(SMThemeControls["InfoImageFit"].Text)
	statsImagePath := Trim(SMThemeControls["StatsImagePath"].Value, ' "')
	if (validatePaths && (statsImagePath != "") && !FileExist(statsImagePath)) {
		MsgBox("The selected stats panel image does not exist anymore.", "StatMonitor Theme", 0x30)
		return false
	}
	values["StatsImagePath"] := statsImagePath
	values["StatsImageMode"] := StatMonitorThemeEditor_NormalizeStatsImageMode(SMThemeControls["StatsImageMode"].Text)
	values["StatsImageOpacity"] := StatMonitorThemeEditor_ClampInteger(SMThemeControls["StatsImageOpacity"].Value, 100, 0, 100)
	values["StatsImageFit"] := StatMonitorThemeEditor_NormalizeImageFit(SMThemeControls["StatsImageFit"].Text)
	return values
}

StatMonitorThemeEditor_Load() {
	global SMThemeDefaults

	values := Map()
	values.CaseSense := 0
	for key, defaultValue in SMThemeDefaults
		values[key] := StatMonitorThemeEditor_ReadSetting(key, defaultValue)

	values["BackgroundMode"] := StatMonitorThemeEditor_NormalizeBackgroundMode(values["BackgroundMode"])
	values["ImageLayer"] := StatMonitorThemeEditor_NormalizeImageLayer(values["ImageLayer"])
	values["ImageFit"] := StatMonitorThemeEditor_NormalizeImageFit(values["ImageFit"])
	values["InfoImageMode"] := StatMonitorThemeEditor_NormalizeInfoImageMode(values["InfoImageMode"])
	values["InfoImageFit"] := StatMonitorThemeEditor_NormalizeImageFit(values["InfoImageFit"])
	for key in ["BackgroundFlat", "BackgroundGradientTop", "BackgroundGradientBottom", "RegionBorder", "RegionFill", "StatRegionBorder", "StatRegionFill", "GraphFill", "TextPrimary", "TextSecondary", "TextMuted", "TextAccent", "TextLink", "TextPositive", "TextNegative", "TextBrand"]
		values[key] := StatMonitorThemeEditor_NormalizeColorText(values[key], SMThemeDefaults[key])

	values["ImageOpacity"] := String(StatMonitorThemeEditor_ClampInteger(values["ImageOpacity"], 55, 0, 100))
	values["RegionBorderOpacity"] := String(StatMonitorThemeEditor_ClampInteger(values["RegionBorderOpacity"], 100, 0, 100))
	values["RegionOpacity"] := String(StatMonitorThemeEditor_ClampInteger(values["RegionOpacity"], 100, 0, 100))
	values["StatRegionBorderOpacity"] := String(StatMonitorThemeEditor_ClampInteger(values["StatRegionBorderOpacity"], 100, 0, 100))
	values["StatRegionOpacity"] := String(StatMonitorThemeEditor_ClampInteger(values["StatRegionOpacity"], 100, 0, 100))
	values["ImageScale"] := String(StatMonitorThemeEditor_ClampInteger(values["ImageScale"], 100, 10, 400))
	values["ImageOffsetX"] := String(StatMonitorThemeEditor_ClampInteger(values["ImageOffsetX"], 0, -6000, 6000))
	values["ImageOffsetY"] := String(StatMonitorThemeEditor_ClampInteger(values["ImageOffsetY"], 0, -6000, 6000))
	values["InfoImageOpacity"] := String(StatMonitorThemeEditor_ClampInteger(values["InfoImageOpacity"], 100, 0, 100))
	values["StatsImageOpacity"] := String(StatMonitorThemeEditor_ClampInteger(values["StatsImageOpacity"], 100, 0, 100))
	values["ImagePath"] := Trim(values["ImagePath"], ' "')
	values["InfoImagePath"] := Trim(values["InfoImagePath"], ' "')
	values["StatsImagePath"] := Trim(values["StatsImagePath"], ' "')
	return values
}

StatMonitorThemeEditor_LoadFromFile(path) {
	global SMThemeDefaults, SMThemeSection
	if !FileExist(path)
		return false

	fileText := FileRead(path, "UTF-8")
	if !InStr(fileText, "[" SMThemeSection "]")
		return false

	values := Map()
	values.CaseSense := 0
	for key, defaultValue in SMThemeDefaults
		values[key] := StatMonitorThemeEditor_ReadSettingFromFile(path, key, defaultValue)

	values["BackgroundMode"] := StatMonitorThemeEditor_NormalizeBackgroundMode(values["BackgroundMode"])
	values["ImageLayer"] := StatMonitorThemeEditor_NormalizeImageLayer(values["ImageLayer"])
	values["ImageFit"] := StatMonitorThemeEditor_NormalizeImageFit(values["ImageFit"])
	values["InfoImageMode"] := StatMonitorThemeEditor_NormalizeInfoImageMode(values["InfoImageMode"])
	values["InfoImageFit"] := StatMonitorThemeEditor_NormalizeImageFit(values["InfoImageFit"])
	values["StatsImageMode"] := StatMonitorThemeEditor_NormalizeStatsImageMode(values["StatsImageMode"])
	values["StatsImageFit"] := StatMonitorThemeEditor_NormalizeImageFit(values["StatsImageFit"])
	for key in ["BackgroundFlat", "BackgroundGradientTop", "BackgroundGradientBottom", "RegionBorder", "RegionFill", "StatRegionBorder", "StatRegionFill", "GraphFill", "TextPrimary", "TextSecondary", "TextMuted", "TextAccent", "TextLink", "TextPositive", "TextNegative", "TextBrand"]
		values[key] := StatMonitorThemeEditor_NormalizeColorText(values[key], SMThemeDefaults[key])

	values["ImageOpacity"] := String(StatMonitorThemeEditor_ClampInteger(values["ImageOpacity"], 55, 0, 100))
	values["RegionBorderOpacity"] := String(StatMonitorThemeEditor_ClampInteger(values["RegionBorderOpacity"], 100, 0, 100))
	values["RegionOpacity"] := String(StatMonitorThemeEditor_ClampInteger(values["RegionOpacity"], 100, 0, 100))
	values["StatRegionBorderOpacity"] := String(StatMonitorThemeEditor_ClampInteger(values["StatRegionBorderOpacity"], 100, 0, 100))
	values["StatRegionOpacity"] := String(StatMonitorThemeEditor_ClampInteger(values["StatRegionOpacity"], 100, 0, 100))
	values["ImageScale"] := String(StatMonitorThemeEditor_ClampInteger(values["ImageScale"], 100, 10, 400))
	values["ImageOffsetX"] := String(StatMonitorThemeEditor_ClampInteger(values["ImageOffsetX"], 0, -6000, 6000))
	values["ImageOffsetY"] := String(StatMonitorThemeEditor_ClampInteger(values["ImageOffsetY"], 0, -6000, 6000))
	values["InfoImageOpacity"] := String(StatMonitorThemeEditor_ClampInteger(values["InfoImageOpacity"], 100, 0, 100))
	values["StatsImageOpacity"] := String(StatMonitorThemeEditor_ClampInteger(values["StatsImageOpacity"], 100, 0, 100))
	values["ImagePath"] := Trim(values["ImagePath"], ' "')
	values["InfoImagePath"] := Trim(values["InfoImagePath"], ' "')
	values["StatsImagePath"] := Trim(values["StatsImagePath"], ' "')
	return values
}

StatMonitorThemeEditor_ReadSettingFromFile(path, key, defaultValue := "") {
	global SMThemeSection
	missing := "__STATMONITOR_THEME_MISSING__"
	value := IniRead(path, SMThemeSection, key, missing)
	return (value = missing) ? defaultValue : value
}

StatMonitorThemeEditor_ApplyValuesToControls(values) {
	global SMThemeControls
	for key, value in values {
		if !SMThemeControls.Has(key)
			continue
		if (key = "BackgroundMode" || key = "ImageLayer" || key = "ImageFit" || key = "InfoImageMode" || key = "InfoImageFit" || key = "StatsImageMode" || key = "StatsImageFit")
			SMThemeControls[key].Text := value
		else
			SMThemeControls[key].Value := value
	}
}

StatMonitorThemeEditor_WriteValuesToFile(path, values) {
	global SMThemeSection
	SplitPath(path, , &dirPath)
	if (dirPath != "")
		DirCreate(dirPath)
	for key, value in values
		IniWrite(value, path, SMThemeSection, key)
}

StatMonitorThemeEditor_ReadSetting(key, defaultValue := "") {
	global SMThemeConfigPath, SMThemeLegacyConfigPath, SMThemeSection
	missing := "__STATMONITOR_THEME_MISSING__"
	value := IniRead(SMThemeConfigPath, SMThemeSection, key, missing)
	if (value != missing)
		return value
	return IniRead(SMThemeLegacyConfigPath, SMThemeSection, key, defaultValue)
}

StatMonitorThemeEditor_Defaults() {
	defaults := Map()
	defaults.CaseSense := 0
	defaults["BackgroundMode"] := "Default"
	defaults["BackgroundFlat"] := "FF121212"
	defaults["BackgroundGradientTop"] := "FF121212"
	defaults["BackgroundGradientBottom"] := "FF1C1A1C"
	defaults["RegionBorder"] := "FF282628"
	defaults["RegionBorderOpacity"] := "100"
	defaults["RegionFill"] := "FF201E20"
	defaults["RegionOpacity"] := "100"
	defaults["StatRegionBorder"] := "FF353335"
	defaults["StatRegionBorderOpacity"] := "100"
	defaults["StatRegionFill"] := "FF2C2A2C"
	defaults["StatRegionOpacity"] := "100"
	defaults["GraphFill"] := "80141414"
	defaults["TextPrimary"] := "FFFFFFFF"
	defaults["TextSecondary"] := "CCFFFFFF"
	defaults["TextMuted"] := "AFFFFFFF"
	defaults["TextAccent"] := "FFFFDA3D"
	defaults["TextLink"] := "FF3366CC"
	defaults["TextPositive"] := "FF4FDF26"
	defaults["TextNegative"] := "FFCC0000"
	defaults["TextBrand"] := "FFFF5F1F"
	defaults["ImagePath"] := ""
	defaults["ImageLayer"] := "Background"
	defaults["ImageOpacity"] := "55"
	defaults["ImageFit"] := "Contain"
	defaults["ImageScale"] := "100"
	defaults["ImageOffsetX"] := "0"
	defaults["ImageOffsetY"] := "0"
	defaults["InfoImagePath"] := ""
	defaults["InfoImageMode"] := "Off"
	defaults["InfoImageOpacity"] := "100"
	defaults["InfoImageFit"] := "Contain"
	defaults["StatsImagePath"] := ""
	defaults["StatsImageMode"] := "Off"
	defaults["StatsImageOpacity"] := "100"
	defaults["StatsImageFit"] := "Contain"
	return defaults
}

StatMonitorThemeEditor_NormalizeColorText(value, fallback) {
	color := StatMonitorThemeEditor_ParseColor(value, StatMonitorThemeEditor_ParseColor(fallback, 0xff000000))
	return Format("{:08X}", color & 0xffffffff)
}

StatMonitorThemeEditor_ParseColor(value, defaultColor) {
	if IsNumber(value)
		return Integer(value)

	text := StrUpper(Trim(value))
	text := RegExReplace(text, '^(0X|#)', "")
	text := RegExReplace(text, "[^0-9A-F]")
	if (StrLen(text) = 6)
		text := "FF" text
	if (StrLen(text) != 8)
		return defaultColor

	try return Integer("0x" text)
	catch
		return defaultColor
}

StatMonitorThemeEditor_ClampInteger(value, defaultValue, minValue, maxValue) {
	try value := Integer(Trim(value))
	catch
		value := defaultValue

	if (value < minValue)
		value := minValue
	if (value > maxValue)
		value := maxValue
	return value
}

StatMonitorThemeEditor_NormalizeBackgroundMode(mode) {
	mode := StrLower(Trim(mode))
	return (mode = "flat") ? "Flat"
		: (mode = "gradient") ? "Gradient"
		: "Default"
}

StatMonitorThemeEditor_NormalizeImageLayer(mode) {
	mode := StrLower(Trim(mode))
	return (mode = "overlay") ? "Overlay" : "Background"
}

StatMonitorThemeEditor_NormalizeImageFit(mode) {
	mode := StrLower(Trim(mode))
	return (mode = "cover") ? "Cover"
		: (mode = "stretch") ? "Stretch"
		: (mode = "original") ? "Original"
		: "Contain"
}

StatMonitorThemeEditor_NormalizeInfoImageMode(mode) {
	mode := StrLower(Trim(mode))
	return (mode = "replace text" || mode = "replacetext") ? "Replace Text"
		: (mode = "under text" || mode = "undertext") ? "Under Text"
		: "Off"
}

StatMonitorThemeEditor_NormalizeStatsImageMode(mode) {
	; Made by @definetlynotray on discord
	mode := StrLower(Trim(mode))
	return (mode = "replace panel" || mode = "replacepanel") ? "Replace Panel" : "Off"
}

StatMonitorThemeEditor_ChooseRgbColor(initialRgb, hwndOwner := 0) {
	static customColors := Buffer(16 * 4, 0)
	size := (A_PtrSize = 8) ? 72 : 36
	cc := Buffer(size, 0)
	ownerOffset := (A_PtrSize = 8) ? 8 : 4
	colorOffset := (A_PtrSize = 8) ? 24 : 12
	customOffset := (A_PtrSize = 8) ? 32 : 16
	flagsOffset := (A_PtrSize = 8) ? 40 : 20

	NumPut("UInt", size, cc, 0)
	NumPut("Ptr", hwndOwner, cc, ownerOffset)
	NumPut("UInt", StatMonitorThemeEditor_RgbToBgr(initialRgb), cc, colorOffset)
	NumPut("Ptr", customColors.Ptr, cc, customOffset)
	NumPut("UInt", 0x00000003, cc, flagsOffset)

	if !DllCall("comdlg32\ChooseColorW", "Ptr", cc.Ptr, "UInt")
		return ""

	return StatMonitorThemeEditor_BgrToRgb(NumGet(cc, colorOffset, "UInt"))
}

StatMonitorThemeEditor_RgbToBgr(rgb) {
	return ((rgb & 0xff) << 16) | (rgb & 0x00ff00) | ((rgb >> 16) & 0xff)
}

StatMonitorThemeEditor_BgrToRgb(bgr) {
	return StatMonitorThemeEditor_RgbToBgr(bgr)
}
