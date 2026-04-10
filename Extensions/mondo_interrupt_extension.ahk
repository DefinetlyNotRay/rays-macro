#Requires AutoHotkey v2.0

mondointerrupt_ShouldTrigger() {
	global MondoInterruptCheck, MondoBuffCheck, MondoAction, LastMondoBuff, state

	if !(MondoInterruptCheck = 1 && MondoBuffCheck = 1 && MondoAction = "Buff")
		return false

	utcMin := FormatTime(A_NowUTC, "m") + 0
	; leave gather at :59, but only allow the late catch-up window once we are no longer gathering
	isLateCatchup := (utcMin >= 0 && utcMin <= 14) && (state != "Gathering") && (state != "Searching")
	return ((utcMin = 59) || isLateCatchup) && ((nowUnix() - LastMondoBuff) > 3300)
}

mondointerrupt_IsSpawnDetected(&healthBars := "") {
	healthBars := nm_HealthDetection()
	if (healthBars.Length = 0)
		return false

	for _, value in healthBars {
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

	utcMin := FormatTime(A_NowUTC, "m") + 0
	; if we caught a late start (not :59), skip the wait loop
	if (utcMin != 59) {
		; already past :59, go straight to detection
	} else {
		; arrived before :00, wait for the minute to flip
		while ((FormatTime(A_NowUTC, "m") + 0) = 59) {
			if youDied
				break
			Sleep 200
		}
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
