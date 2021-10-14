#Include ./Utils.ahk
#SingleInstance, Force
#NoEnv
#MaxThreadsPerHotkey 3
#installmousehook
#MaxHotkeysPerInterval 100

SetBatchLines, -1
SetWinDelay, -1
CoordMode, mouse, screen
SetWorkingDir, %A_ScriptDir%

ClickEvents := []

SetupMouseSpotlight()
{
    global
    SETTINGS := ReadConfigFile("settings.ini")
    InitializeSpotlightGUI()
}

InitializeSpotlightGUI(){ 
    global CursorSpotlightHwnd, SETTINGS
    if (SETTINGS.cursorSpotlight.enabled == True)
    { 
        global CursorSpotlightDiameter := SETTINGS.cursorSpotlight.spotlightDiameter
        spotlightRingWidth := SETTINGS.cursorSpotlight.spotlightRingWidth
        Gui, CursorSpotlightWindow: +HwndCursorSpotlightHwnd +AlwaysOnTop -Caption +ToolWindow +E0x20 ;+E0x20 click thru
        Gui, CursorSpotlightWindow: Color, % SETTINGS.cursorSpotlight.spotlightColor
        Gui, CursorSpotlightWindow: Show, x0 y0 w%CursorSpotlightDiameter% h%CursorSpotlightDiameter% NA
        WinSet, Transparent, % SETTINGS.CursorSpotlight.spotlightOpacity, ahk_id %CursorSpotlightHwnd%
        ; Create a ring region to highlight the cursor
        finalRegion := DllCall("CreateEllipticRgn", "Int", 0, "Int", 0, "Int", CursorSpotlightDiameter, "Int", CursorSpotlightDiameter)
        if (spotlightRingWidth < CursorSpotlightDiameter/2)
        {
            inner := DllCall("CreateEllipticRgn", "Int", spotlightRingWidth, "Int", spotlightRingWidth, "Int", CursorSpotlightDiameter-spotlightRingWidth, "Int", CursorSpotlightDiameter-spotlightRingWidth)
            DllCall("CombineRgn", "UInt", finalRegion, "UInt", finalRegion, "UInt", inner, "Int", 3) ; RGN_XOR = 3                                      
            DllCall("DeleteObject", UInt, inner)
        }
        DllCall("SetWindowRgn", "UInt", CursorSpotlightHwnd, "UInt", finalRegion, "UInt", true)
        SetTimer, DrawSpotlight, 10
        Return

        DrawSpotlight:            
            ; SETTINGS.cursorSpotlight.enabled can be changed by other script such as Annotation.ahk
            if (SETTINGS.cursorSpotlight.enabled == True)
            {
                MouseGetPos, X, Y
                X -= CursorSpotlightDiameter / 2 - 3
                Y -= CursorSpotlightDiameter / 2 - 2
                WinMove, ahk_id %CursorSpotlightHwnd%, , %X%, %Y%
                WinSet, AlwaysOnTop, On, ahk_id %CursorSpotlightHwnd%
            }
            else
            {
                 WinMove, ahk_id %CursorSpotlightHwnd%, , -999999999, -999999999
            }

        Return
    }
}

SetupMouseSpotlight()
