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

StatMonitorTheme_ResolveCanvasHeight(baseHeight := 7000) {
	buffTop := 360 + 1758
	stackTopPadding := 135
	stackBottomPadding := 240
	stackGap := 20

	totalStackHeight := 0
	stackCount := 0
	for _, spec in StatMonitorTheme_BuffGraphSpecs() {
		totalStackHeight += spec[3]
		stackCount += 1
	}
	if (stackCount > 0)
		totalStackHeight += (stackCount - 1) * stackGap

	requiredHeight := buffTop + stackTopPadding + totalStackHeight + stackBottomPadding
	return Max(baseHeight, requiredHeight)
}

StatMonitorTheme_BuffGraphSpecs() {
	return [
		["boost", "Boost", 280, 0xff56a4e4, 1]
		, ["haste", "Haste", 280, 0xfff0f0f0, 2]
		, ["focus", "Focus", 280, 0xff22ff06, 3]
		, ["bombcombo", "Bomb Combo", 280, 0xffa0a0a0, 4]
		, ["balloonaura", "Balloon Aura", 280, 0xff3350c3, 5]
		, ["inspire", "Inspire", 280, 0xfff4ef14, 6]
		, ["reindeerfetch", "Reindeer Fetch", 280, 0xffcc2c2c, 7]
		, ["honeymark", "Honey Mark", 120, 0xffffd119, 8]
		, ["pollenmark", "Pollen Mark", 120, 0xffffe994, 9]
		, ["festivemark", "Festive Mark", 120, 0xffc84335, 10]
		, ["popstar", "Pop Star", 110, 0xff0096ff, 11]
		, ["melody", "Melody", 110, 0xfff0f0f0, 12]
		, ["bear", "Bear Morph", 110, 0xffb26f3e, 13]
		, ["babylove", "Baby Love", 110, 0xff8de4f3, 14]
		, ["jbshare", "JB Share", 110, 0xfff9ccff, 15]
		, ["guiding", "Guiding Star", 110, 0xffffef8e, 16]
		, ["beesmascheer", "Beesmas Cheer", 110, 0xff00ff00, 17]
		, ["pinetreefieldboost", "Pine Field Boost", 110, 0xff00e027, 18]
		, ["bamboofieldboost", "Bamboo Field Boost", 110, 0xff00e027, 19]
		, ["blueflowerfieldboost", "Blue Flower Field Boost", 110, 0xff00e027, 20]
		, ["snowflakebuff", "Snowflake Buff", 110, 0xfffcfcfc, 21]
		, ["cloudbuff", "Cloud Buff", 110, 0xffd8e1ea, 22]
		, ["digitalcorruption", "Digital Corruption", 110, 0xff7352ba, 23]
		, ["StickerStack", "Sticker Stack", 110, 0xffffffff, 24]
	]
}

StatMonitorTheme_BuffGraphSettingKey(id, field) {
	return "BuffGraph_" id "_" field
}

StatMonitorTheme_GraphColor(name, defaultColor) {
	theme := StatMonitorTheme_Load()
	key := StatMonitorTheme_BuffGraphSettingKey(name, "Color")
	if theme.Has(key)
		return theme[key]
	return defaultColor
}

StatMonitorTheme_GraphEnabled(name) {
	theme := StatMonitorTheme_Load()
	key := StatMonitorTheme_BuffGraphSettingKey(name, "Enabled")
	return theme.Has(key) ? theme[key] : 1
}

StatMonitorTheme_GraphOrder(name, defaultOrder) {
	theme := StatMonitorTheme_Load()
	key := StatMonitorTheme_BuffGraphSettingKey(name, "Order")
	return theme.Has(key) ? theme[key] : defaultOrder
}

StatMonitorTheme_GraphOffset(name) {
	theme := StatMonitorTheme_Load()
	key := StatMonitorTheme_BuffGraphSettingKey(name, "OffsetY")
	return theme.Has(key) ? theme[key] : 0
}

StatMonitorTheme_MixColor(colorA, colorB, ratio) {
	ratio := Max(0, Min(ratio, 1))
	a1 := (colorA >> 24) & 0xff, r1 := (colorA >> 16) & 0xff, g1 := (colorA >> 8) & 0xff, b1 := colorA & 0xff
	a2 := (colorB >> 24) & 0xff, r2 := (colorB >> 16) & 0xff, g2 := (colorB >> 8) & 0xff, b2 := colorB & 0xff
	a := Round(a1 + (a2 - a1) * ratio)
	r := Round(r1 + (r2 - r1) * ratio)
	g := Round(g1 + (g2 - g1) * ratio)
	b := Round(b1 + (b2 - b1) * ratio)
	return (a << 24) | (r << 16) | (g << 8) | b
}

StatMonitorTheme_GetBuffGraphRegions(regions) {
	graph_regions := Map()
	graph_regions.CaseSense := 0

	active := []
	for _, spec in StatMonitorTheme_BuffGraphSpecs() {
		id := spec[1]
		if !StatMonitorTheme_GraphEnabled(id)
			continue
		active.Push([StatMonitorTheme_GraphOrder(id, spec[5]), id, spec[3], StatMonitorTheme_GraphOffset(id)])
	}

	while (active.Length > 0) {
		minIndex := 1
		Loop active.Length {
			if (active[A_Index][1] < active[minIndex][1])
				minIndex := A_Index
		}
		spec := active.RemoveAt(minIndex)
		y := regions["buffs"][2] + 135
		for _, region in graph_regions
			y := Max(y, region[2] + region[4] + 20)
		graph_width := Max(240, regions["buffs"][3] - 480)
		graph_regions[spec[2]] := [regions["buffs"][1] + 320, y + spec[4], graph_width, spec[3]]
	}

	return graph_regions
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
	if !IsSet(g_StatMonitorThemeCache)
		g_StatMonitorThemeCache := 0
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
	theme["HoneyGatherColor"] := StatMonitorTheme_ParseColor(StatMonitorTheme_ReadSetting("HoneyGatherColor", "FFA6FF7C"), 0xffa6ff7c)
	theme["HoneyConvertColor"] := StatMonitorTheme_ParseColor(StatMonitorTheme_ReadSetting("HoneyConvertColor", "FFFECA40"), 0xfffeca40)
	theme["HoneyOtherColor"] := StatMonitorTheme_ParseColor(StatMonitorTheme_ReadSetting("HoneyOtherColor", "FF859AAD"), 0xff859aad)
	theme["BackpackColorStart"] := StatMonitorTheme_ParseColor(StatMonitorTheme_ReadSetting("BackpackColorStart", "FFFF0000"), 0xffff0000)
	theme["BackpackColorMid"] := StatMonitorTheme_ParseColor(StatMonitorTheme_ReadSetting("BackpackColorMid", "FFFF8000"), 0xffff8000)
	theme["BackpackColorEnd"] := StatMonitorTheme_ParseColor(StatMonitorTheme_ReadSetting("BackpackColorEnd", "FF41FF80"), 0xff41ff80)
	theme["PieGatherColor"] := StatMonitorTheme_ParseColor(StatMonitorTheme_ReadSetting("PieGatherColor", "FFA6FF7C"), 0xffa6ff7c)
	theme["PieConvertColor"] := StatMonitorTheme_ParseColor(StatMonitorTheme_ReadSetting("PieConvertColor", "FFFECA40"), 0xfffeca40)
	theme["PieOtherColor"] := StatMonitorTheme_ParseColor(StatMonitorTheme_ReadSetting("PieOtherColor", "FF859AAD"), 0xff859aad)
	for _, spec in StatMonitorTheme_BuffGraphSpecs() {
		id := spec[1]
		theme[StatMonitorTheme_BuffGraphSettingKey(id, "Enabled")] := StatMonitorTheme_ReadInt(StatMonitorTheme_BuffGraphSettingKey(id, "Enabled"), 1, 0, 1)
		theme[StatMonitorTheme_BuffGraphSettingKey(id, "Order")] := StatMonitorTheme_ReadInt(StatMonitorTheme_BuffGraphSettingKey(id, "Order"), spec[5], 1, 999)
		theme[StatMonitorTheme_BuffGraphSettingKey(id, "Color")] := StatMonitorTheme_ParseColor(StatMonitorTheme_ReadSetting(StatMonitorTheme_BuffGraphSettingKey(id, "Color"), Format("{:08X}", spec[4])), spec[4])
		theme[StatMonitorTheme_BuffGraphSettingKey(id, "OffsetY")] := StatMonitorTheme_ReadInt(StatMonitorTheme_BuffGraphSettingKey(id, "OffsetY"), 0, -9999, 9999)
	}

	g_StatMonitorThemeCache := theme
	return theme
}

StatMonitorTheme_ReplaceAlpha(color, alpha) {
	return (color & 0x00ffffff) | ((alpha & 0xff) << 24)
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
	value := missing
	try value := IniRead(g_StatMonitorThemeConfigPath, g_StatMonitorThemeSection, key, missing)
	catch
		value := missing
	if (value != missing)
		return value
	try return IniRead(g_StatMonitorThemeLegacyConfigPath, g_StatMonitorThemeSection, key, defaultValue)
	catch
		return defaultValue
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
	if !(value is String)
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
