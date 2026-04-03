/*
Patch-managed StatMonitor theme runtime.
Changes here should be synced by apply_tadsync_patch.ahk.
Made by @definetlynotray on discord
*/

global g_StatMonitorThemeCache := 0
global g_StatMonitorThemeConfigPath := A_ScriptDir "\..\settings\statmonitor_theme.ini"
global g_StatMonitorThemeLegacyConfigPath := A_ScriptDir "\..\settings\nm_config.ini"
global g_StatMonitorThemeSection := "StatMonitorTheme"

StatMonitorTheme_DrawBackground(G, w, h) {
	theme := StatMonitorTheme_Load()
	mode := theme["BackgroundMode"]
	if (mode = "Gradient")
		pBrush := Gdip_CreateLineBrushFromRect(0, 0, w, h, theme["BackgroundGradientTop"], theme["BackgroundGradientBottom"], 1)
	else
		pBrush := Gdip_BrushCreateSolid((mode = "Flat") ? theme["BackgroundFlat"] : 0xff121212)

	Gdip_FillRoundedRectangle(G, pBrush, -1, -1, w + 1, h + 1, 60)
	Gdip_DeleteBrush(pBrush)
	if (theme["ImageLayer"] = "Background")
		StatMonitorTheme_DrawBackgroundImage(G, w, h, theme)
}

StatMonitorTheme_DrawRegionPanels(G, regions, stat_regions) {
	theme := StatMonitorTheme_Load()

	for k, v in regions {
		pPen := Gdip_CreatePen(StatMonitorTheme_WithOpacity(theme["RegionBorder"], theme["RegionBorderOpacity"]), 10)
		Gdip_DrawRoundedRectangle(G, pPen, v[1], v[2], v[3], v[4], 20)
		Gdip_DeletePen(pPen)

		pBrush := Gdip_BrushCreateSolid(StatMonitorTheme_WithOpacity(theme["RegionFill"], theme["RegionOpacity"]))
		Gdip_FillRoundedRectangle(G, pBrush, v[1], v[2], v[3], v[4], 20)
		Gdip_DeleteBrush(pBrush)
	}

	for k, v in stat_regions {
		pPen := Gdip_CreatePen(StatMonitorTheme_WithOpacity(theme["StatRegionBorder"], theme["StatRegionBorderOpacity"]), 10)
		Gdip_DrawRoundedRectangle(G, pPen, v[1], v[2], v[3], v[4], 20)
		Gdip_DeletePen(pPen)

		pBrush := Gdip_BrushCreateSolid(StatMonitorTheme_WithOpacity(theme["StatRegionFill"], theme["StatRegionOpacity"]))
		Gdip_FillRoundedRectangle(G, pBrush, v[1], v[2], v[3], v[4], 20)
		Gdip_DeleteBrush(pBrush)
	}
}

StatMonitorTheme_CreateGraphBackgroundBrush() {
	theme := StatMonitorTheme_Load()
	return Gdip_BrushCreateSolid(theme["GraphFill"])
}

StatMonitorTheme_DrawOverlay(G, canvasW, canvasH, regions := "", stat_regions := "") {
	theme := StatMonitorTheme_Load()
	if (theme["ImageLayer"] != "Overlay")
		return
	rect := StatMonitorTheme_GetOverlayRect(canvasW, canvasH, regions, stat_regions)
	StatMonitorTheme_DrawBackgroundImage(G, rect[3], rect[4], theme, rect[1], rect[2], true)
}

StatMonitorTheme_Load(forceReload := false) {
	global g_StatMonitorThemeCache
	; Made by @definetlynotray on discord - theme key loader
	if !forceReload && IsObject(g_StatMonitorThemeCache)
		return g_StatMonitorThemeCache

	theme := Map()
	theme.CaseSense := 0
	theme["BackgroundMode"] := StatMonitorTheme_NormalizeBackgroundMode(StatMonitorTheme_ReadSetting("BackgroundMode", "Default"))
	theme["BackgroundFlat"] := StatMonitorTheme_ParseColor(StatMonitorTheme_ReadSetting("BackgroundFlat", "FF121212"), 0xff121212)
	theme["BackgroundGradientTop"] := StatMonitorTheme_ParseColor(StatMonitorTheme_ReadSetting("BackgroundGradientTop", "FF121212"), 0xff121212)
	theme["BackgroundGradientBottom"] := StatMonitorTheme_ParseColor(StatMonitorTheme_ReadSetting("BackgroundGradientBottom", "FF1C1A1C"), 0xff1c1a1c)
	theme["RegionBorder"] := StatMonitorTheme_ParseColor(StatMonitorTheme_ReadSetting("RegionBorder", "FF282628"), 0xff282628)
	theme["RegionBorderOpacity"] := StatMonitorTheme_ReadInt("RegionBorderOpacity", 100, 0, 100)
	theme["RegionFill"] := StatMonitorTheme_ParseColor(StatMonitorTheme_ReadSetting("RegionFill", "FF201E20"), 0xff201e20)
	theme["RegionOpacity"] := StatMonitorTheme_ReadInt("RegionOpacity", 100, 0, 100)
	theme["StatRegionBorder"] := StatMonitorTheme_ParseColor(StatMonitorTheme_ReadSetting("StatRegionBorder", "FF353335"), 0xff353335)
	theme["StatRegionBorderOpacity"] := StatMonitorTheme_ReadInt("StatRegionBorderOpacity", 100, 0, 100)
	theme["StatRegionFill"] := StatMonitorTheme_ParseColor(StatMonitorTheme_ReadSetting("StatRegionFill", "FF2C2A2C"), 0xff2c2a2c)
	theme["StatRegionOpacity"] := StatMonitorTheme_ReadInt("StatRegionOpacity", 100, 0, 100)
	theme["GraphFill"] := StatMonitorTheme_ParseColor(StatMonitorTheme_ReadSetting("GraphFill", "80141414"), 0x80141414)
	theme["TextPrimary"] := StatMonitorTheme_ParseColor(StatMonitorTheme_ReadSetting("TextPrimary", "FFFFFFFF"), 0xffffffff)
	theme["TextSecondary"] := StatMonitorTheme_ParseColor(StatMonitorTheme_ReadSetting("TextSecondary", "CCFFFFFF"), 0xccffffff)
	theme["TextMuted"] := StatMonitorTheme_ParseColor(StatMonitorTheme_ReadSetting("TextMuted", "AFFFFFFF"), 0xafffffff)
	theme["TextAccent"] := StatMonitorTheme_ParseColor(StatMonitorTheme_ReadSetting("TextAccent", "FFFFDA3D"), 0xffffda3d)
	theme["TextLink"] := StatMonitorTheme_ParseColor(StatMonitorTheme_ReadSetting("TextLink", "FF3366CC"), 0xff3366cc)
	theme["TextPositive"] := StatMonitorTheme_ParseColor(StatMonitorTheme_ReadSetting("TextPositive", "FF4FDF26"), 0xff4fdf26)
	theme["TextNegative"] := StatMonitorTheme_ParseColor(StatMonitorTheme_ReadSetting("TextNegative", "FFCC0000"), 0xffcc0000)
	theme["TextBrand"] := StatMonitorTheme_ParseColor(StatMonitorTheme_ReadSetting("TextBrand", "FFFF5F1F"), 0xffff5f1f)
	theme["ImagePath"] := Trim(StatMonitorTheme_ReadSetting("ImagePath", ""), ' "')
	theme["ImageLayer"] := StatMonitorTheme_NormalizeImageLayer(StatMonitorTheme_ReadSetting("ImageLayer", "Background"))
	theme["ImageOpacity"] := StatMonitorTheme_ReadInt("ImageOpacity", 55, 0, 100)
	theme["ImageFit"] := StatMonitorTheme_NormalizeImageFit(StatMonitorTheme_ReadSetting("ImageFit", "Contain"))
	theme["ImageScale"] := StatMonitorTheme_ReadInt("ImageScale", 100, 10, 400)
	theme["ImageOffsetX"] := StatMonitorTheme_ReadInt("ImageOffsetX", 0, -6000, 6000)
	theme["ImageOffsetY"] := StatMonitorTheme_ReadInt("ImageOffsetY", 0, -6000, 6000)
	theme["InfoImagePath"] := Trim(StatMonitorTheme_ReadSetting("InfoImagePath", ""), ' "')
	theme["InfoImageMode"] := StatMonitorTheme_NormalizeInfoImageMode(StatMonitorTheme_ReadSetting("InfoImageMode", "Off"))
	theme["InfoImageOpacity"] := StatMonitorTheme_ReadInt("InfoImageOpacity", 100, 0, 100)
	theme["InfoImageFit"] := StatMonitorTheme_NormalizeImageFit(StatMonitorTheme_ReadSetting("InfoImageFit", "Contain"))
	theme["StatsImagePath"] := Trim(StatMonitorTheme_ReadSetting("StatsImagePath", ""), ' "')
	theme["StatsImageMode"] := StatMonitorTheme_NormalizeStatsImageMode(StatMonitorTheme_ReadSetting("StatsImageMode", "Off"))
	theme["StatsImageOpacity"] := StatMonitorTheme_ReadInt("StatsImageOpacity", 100, 0, 100)
	theme["StatsImageFit"] := StatMonitorTheme_NormalizeImageFit(StatMonitorTheme_ReadSetting("StatsImageFit", "Contain"))

	g_StatMonitorThemeCache := theme
	return theme
}

StatMonitorTheme_TextColor(name) {
	theme := StatMonitorTheme_Load()
	key := "Text" name
	if !theme.Has(key)
		key := "TextPrimary"
	return Format("{:08X}", theme[key] & 0xffffffff)
}

StatMonitorTheme_WithOpacity(color, opacityPercent) {
	alpha := Round((Min(Max(opacityPercent, 0), 100) / 100) * 255)
	return (color & 0x00ffffff) | (alpha << 24)
}

StatMonitorTheme_ReadSetting(key, defaultValue := "") {
	global g_StatMonitorThemeConfigPath, g_StatMonitorThemeLegacyConfigPath, g_StatMonitorThemeSection
	missing := "__STATMONITOR_THEME_MISSING__"
	value := IniRead(g_StatMonitorThemeConfigPath, g_StatMonitorThemeSection, key, missing)
	if (value != missing)
		return value
	return IniRead(g_StatMonitorThemeLegacyConfigPath, g_StatMonitorThemeSection, key, defaultValue)
}

StatMonitorTheme_ReadInt(key, defaultValue, minValue := "", maxValue := "") {
	value := StatMonitorTheme_ReadSetting(key, defaultValue)
	try value := Integer(Trim(value))
	catch
		value := defaultValue

	if (minValue != "" && value < minValue)
		value := minValue
	if (maxValue != "" && value > maxValue)
		value := maxValue
	return value
}

StatMonitorTheme_ParseColor(value, defaultColor) {
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

StatMonitorTheme_NormalizeBackgroundMode(mode) {
	mode := StrLower(Trim(mode))
	return (mode = "flat") ? "Flat"
		: (mode = "gradient") ? "Gradient"
		: "Default"
}

StatMonitorTheme_NormalizeImageLayer(mode) {
	mode := StrLower(Trim(mode))
	return (mode = "overlay") ? "Overlay" : "Background"
}

StatMonitorTheme_NormalizeImageFit(mode) {
	mode := StrLower(Trim(mode))
	return (mode = "cover") ? "Cover"
		: (mode = "stretch") ? "Stretch"
		: (mode = "original") ? "Original"
		: "Contain"
}

StatMonitorTheme_NormalizeInfoImageMode(mode) {
	mode := StrLower(Trim(mode))
	return (mode = "replacetext" || mode = "replace text") ? "ReplaceText"
		: (mode = "undertext" || mode = "under text") ? "UnderText"
		: "Off"
}

StatMonitorTheme_NormalizeStatsImageMode(mode) {
	mode := StrLower(Trim(mode))
	return (mode = "replacepanel" || mode = "replace panel") ? "ReplacePanel" : "Off"
}

StatMonitorTheme_GetInfoImageMode() {
	theme := StatMonitorTheme_Load()
	if ((theme["InfoImagePath"] = "") || !FileExist(theme["InfoImagePath"]))
		return "Off"
	return theme["InfoImageMode"]
}

StatMonitorTheme_GetStatsImageMode() {
	theme := StatMonitorTheme_Load()
	if ((theme["StatsImagePath"] = "") || !FileExist(theme["StatsImagePath"]))
		return "Off"
	return theme["StatsImageMode"]
}

StatMonitorTheme_GetOverlayRect(canvasW, canvasH, regions := "", stat_regions := "") {
	return [0, 0, Max(canvasW, 1), Max(canvasH, 1)]
}

StatMonitorTheme_DrawInfoImage(G, infoRegion, mode := "") {
	theme := StatMonitorTheme_Load()
	path := theme["InfoImagePath"]
	if ((path = "") || !FileExist(path))
		return

	if (mode = "")
		mode := theme["InfoImageMode"]
	if (mode = "Off")
		return

	padding := 28
	x := infoRegion[1] + padding
	w := Max(infoRegion[3] - padding * 2, 1)
	if (mode = "UnderText") {
		y := infoRegion[2] + 510
		h := infoRegion[4] - 538
	} else {
		y := infoRegion[2] + padding
		h := infoRegion[4] - padding * 2
	}
	if (h <= 0)
		return

	StatMonitorTheme_DrawImageAsset(G, path, w, h, theme["InfoImageOpacity"], theme["InfoImageFit"], 100, 0, 0, x, y, true)
}

StatMonitorTheme_DrawStatsImage(G, statsRegion, mode := "") {
	; Made by @definetlynotray on discord
	theme := StatMonitorTheme_Load()
	path := theme["StatsImagePath"]
	if ((path = "") || !FileExist(path))
		return

	if (mode = "")
		mode := theme["StatsImageMode"]
	if (mode = "Off")
		return

	paddingX := 28
	paddingTop := 100
	paddingBottom := 32
	x := statsRegion[1] + paddingX
	y := statsRegion[2] + paddingTop
	w := Max(statsRegion[3] - paddingX * 2, 1)
	h := statsRegion[4] - paddingTop - paddingBottom
	if (h <= 0)
		return

	StatMonitorTheme_DrawImageAsset(G, path, w, h, theme["StatsImageOpacity"], theme["StatsImageFit"], 100, 0, 0, x, y, true)
}

StatMonitorTheme_DrawBackgroundImage(G, canvasW, canvasH, theme, originX := 0, originY := 0, clipToBounds := false) {
	StatMonitorTheme_DrawImageAsset(G, theme["ImagePath"], canvasW, canvasH, theme["ImageOpacity"], theme["ImageFit"], theme["ImageScale"], theme["ImageOffsetX"], theme["ImageOffsetY"], originX, originY, clipToBounds)
}

StatMonitorTheme_DrawImageAsset(G, path, canvasW, canvasH, opacityPercent, fit, scalePercent := 100, offsetX := 0, offsetY := 0, originX := 0, originY := 0, clipToBounds := false) {
	if ((path = "") || !FileExist(path))
		return

	opacity := opacityPercent / 100
	if (opacity <= 0)
		return

	try pImage := Gdip_CreateBitmapFromFile(path)
	catch
		return
	if !pImage
		return

	Gdip_GetImageDimensions(pImage, &srcW, &srcH)
	if (srcW <= 0 || srcH <= 0) {
		Gdip_DisposeImage(pImage)
		return
	}

	scale := scalePercent / 100
	if (fit = "Stretch") {
		drawW := canvasW * scale
		drawH := canvasH * scale
	} else if (fit = "Original") {
		drawW := srcW * scale
		drawH := srcH * scale
	} else {
		ratio := (fit = "Cover") ? Max(canvasW / srcW, canvasH / srcH) : Min(canvasW / srcW, canvasH / srcH)
		drawW := srcW * ratio * scale
		drawH := srcH * ratio * scale
	}

	drawX := originX + (canvasW - drawW) / 2 + offsetX
	drawY := originY + (canvasH - drawH) / 2 + offsetY
	if clipToBounds
		Gdip_SetClipRect(G, originX, originY, canvasW, canvasH, 0)
	Gdip_DrawImage(G, pImage, drawX, drawY, drawW, drawH, 0, 0, srcW, srcH, opacity)
	if clipToBounds
		Gdip_ResetClip(G)
	Gdip_DisposeImage(pImage)
}
