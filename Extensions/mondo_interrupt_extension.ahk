#Requires AutoHotkey v2.0

mondointerrupt_ShouldTrigger() {
	global MondoInterruptCheck, MondoBuffCheck, MondoAction, LastMondoBuff

	if !(MondoInterruptCheck = 1 && MondoBuffCheck = 1 && MondoAction = "Buff")
		return false
	if nm_GatherBoostInterrupt()
		return false

	utcMin := FormatTime(A_NowUTC, "m") + 0
	return (utcMin = 59) && ((nowUnix() - LastMondoBuff) > 3300)
}

mondointerrupt_IsSpawnDetected(&healthBars := "") {
	healthBars := nm_HealthDetection()
	if (healthBars.Length = 0)
		return false

	for _, value in healthBars {
		; Mondo should already have taken damage by the time we confirm it.
		if (value != 100.00)
			return true
	}
	return false
}

mondointerrupt_ReturnToHiveAndConvert() {
	nm_setStatus("Traveling", "Returning from Mondo Interrupt")
	nm_Reset(2, 2000, 0, 1)
	findHiveSlot := Func("nm_findHiveSlot")
	return (findHiveSlot.MaxParams >= 2) ? findHiveSlot.Call(1, 1) : findHiveSlot.Call()
}

mondointerrupt_Handle() {
	global youDied, MondoSecs, CurrentField, LastMondoBuff
	global AFBrollingDice, AFBuseGlitter, AFBuseBooster

	if !mondointerrupt_ShouldTrigger()
		return false

	nm_updateAction("Mondo Interrupt")
	nm_setStatus("Traveling", "Mondo Interrupt (Mountain Top)")
	nm_Reset(0, 2000, 0)
	nm_gotoField("Mountain Top")

	while ((FormatTime(A_NowUTC, "m") + 0) = 59) {
		if youDied
			break
		Sleep 200
	}

	nm_setStatus("Detecting", "Mondo Interrupt")
	mondoFound := false
	loop 240 {
		if mondointerrupt_IsSpawnDetected(&mChick) {
			mondoFound := true
			break
		}
		if ((FormatTime(A_NowUTC, "m") + 0) > 1)
			break
		Sleep 250
	}

	if mondoFound {
		nm_setStatus("Attacking", "Mondo Interrupt")
		loop MondoSecs {
			nm_autoFieldBoost(CurrentField)
			if (youDied || AFBrollingDice || AFBuseGlitter || AFBuseBooster || nm_NightInterrupt())
				break
			Sleep 1000
		}
	} else {
		nm_setStatus("Waiting", "Mondo Not Found")
		Sleep 750
	}

	mondointerrupt_ReturnToHiveAndConvert()
	LastMondoBuff := nowUnix()
	IniWrite LastMondoBuff, "settings\nm_config.ini", "Collect", "LastMondoBuff"
	return true
}
