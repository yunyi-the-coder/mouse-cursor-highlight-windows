#Include ./Utils.ahk
#SingleInstance, Force
#NoEnv
#MaxThreadsPerHotkey 3
#installmousehook
#MaxHotkeysPerInterval 100

SetBatchLines, -1
SetWinDelay, -1
CoordMode, mouse, screen

ClickEvents := []
AlreadyCreatedRegionForRipples := Object()
IsStillDrawingRipples := False
SetupMouseClickRipple()
{
    global
    SETTINGS := ReadConfigFile("settings.ini") 
    InitializeClickRippleGUI() 

    local ProcessMouseClickFunc := Func("ProcessMouseClick").Bind() 
    if (SETTINGS.cursorLeftClickRippleEffect.enabled = True) { 
        Hotkey, ~*LButton, %ProcessMouseClickFunc% 
    }
    if (SETTINGS.cursorRightClickRippleEffect.enabled = True) {
        Hotkey, ~*RButton, %ProcessMouseClickFunc% 
    }
    if (SETTINGS.cursorMiddleClickRippleEffect.enabled = True) {
        Hotkey, ~*MButton, %ProcessMouseClickFunc% 
    }
}

InitializeClickRippleGUI(){ 
    global	
    Gui, MouseClickRippleWindow: +hwndClickRippleWindowHwnd +AlwaysOnTop -Caption +ToolWindow +E0x20 ;+E0x20 click thru    
    WinSet, Transparent, % transparency, % "ahk_id " ClickRippleWindowHwnd 
    ClickRippleWindowWidth := Max(SETTINGS.cursorLeftClickRippleEffect.rippleDiameterStart
        , SETTINGS.cursorLeftClickRippleEffect.rippleDiameterEnd
        , SETTINGS.cursorMiddleClickRippleEffect.rippleDiameterStart
        , SETTINGS.cursorMiddleClickRippleEffect.rippleDiameterEnd
        , SETTINGS.cursorRightClickRippleEffect.rippleDiameterStart
    , SETTINGS.cursorRightClickRippleEffect.rippleDiameterEnd ) + 2

    Return
}

ProcessMouseClick() {
    global SETTINGS, ClickEvents
    if (InStr(A_ThisHotkey, "LButton"))
    {
        params := SETTINGS.cursorLeftClickRippleEffect 
    }
    if (InStr(A_ThisHotkey, "MButton"))
    {
        params := SETTINGS.cursorMiddleClickRippleEffect 
    }
    if (InStr(A_ThisHotkey, "RButton"))
    { 
        params := SETTINGS.cursorRightClickRippleEffect 
    }
    ; Add an event to the event array and call the DrawRipple function.

    MouseGetPos mousePositionX, mousePositionY

    params.mousePositionX := mousePositionX
    params.mousePositionY := mousePositionY
    ClickEvents.Push(params)
    CheckToDrawNextClickEvent()
}

CheckToDrawNextClickEvent()
{ 
    global
    if (IsStillDrawingRipples || ClickEvents.Count() == 0)
    {
        Return
    }

    ; Get the first event from the ClickEvents array and then delete it
    RippleEventParams := ClickEvents[1]
    ClickEvents.RemoveAt(1)

    if (RippleEventParams.playClickSound == True)
    {
        SoundPlay, %A_ScriptDir%\MouseClickSound.wav
    }

    IsStillDrawingRipples := True
    CurrentRippleDiameter := RippleEventParams.rippleDiameterStart
    CurrentRippleAlpha := RippleEventParams.rippleAlphaStart
    TotalCountOfRipples := Abs(Round((RippleEventParams.rippleDiameterEnd - RippleEventParams.rippleDiameterStart) / RippleEventParams.rippleDiameterStep))
    RippleAlphaStep := Round((RippleEventParams.rippleAlphaEnd - RippleEventParams.rippleAlphaStart) / TotalCountOfRipples)

    RippleWindowPositionX := RippleEventParams.mousePositionX - Round(ClickRippleWindowWidth/2)
    RippleWindowPositionY := RippleEventParams.mousePositionY - Round(ClickRippleWindowWidth/2) 
    Gui, MouseClickRippleWindow: Color, % RippleEventParams.rippleColor
    Gui, MouseClickRippleWindow: Show, x%RippleWindowPositionX% y%RippleWindowPositionY% w%ClickRippleWindowWidth% h%ClickRippleWindowWidth% NoActivate 
    AlreadyDrawnRipples := 0 
    SetTimer, DRAW_RIPPLE, % RippleEventParams.rippleRefreshInterval

    DRAW_RIPPLE:
        local regionKey := RippleEventParams.rippleColor "," CurrentRippleDiameter
        if (AlreadyCreatedRegionForRipples.HasKey(regionKey))
        {
            local finalRegion := AlreadyCreatedRegionForRipples[regionKey]
        }
        else
        {
            local outerRegionTopLeftX := Round((ClickRippleWindowWidth-CurrentRippleDiameter)/2)
            local outerRegionTopLeftY := Round((ClickRippleWindowWidth-CurrentRippleDiameter)/2)
            local outerRegionBottomRightX := outerRegionTopLeftX + CurrentRippleDiameter
            local outerRegionBottomRightY := outerRegionTopLeftY + CurrentRippleDiameter
            local innerRegionTopLeftX := outerRegionTopLeftX + RippleEventParams.rippleLineWidth
            local innerRegionTopLeftY := outerRegionTopLeftY + RippleEventParams.rippleLineWidth
            local innerRegionBottomRightX := outerRegionBottomRightX - RippleEventParams.rippleLineWidth
            local innerRegionBottomRightY := outerRegionBottomRightY - RippleEventParams.rippleLineWidth 
            local finalRegion := DllCall("CreateEllipticRgn", "Int", outerRegionTopLeftX, "Int", outerRegionTopLeftY, "Int", outerRegionBottomRightX, "Int", outerRegionBottomRightY)
            local inner := DllCall("CreateEllipticRgn", "Int", innerRegionTopLeftX, "Int", innerRegionTopLeftY, "Int", innerRegionBottomRightX, "Int", innerRegionBottomRightY)
            DllCall("CombineRgn", "UInt", finalRegion, "UInt", finalRegion, "UInt", inner, "Int", 3) ; RGN_XOR = 3                              
            DeleteObject(inner)
        }

        DllCall("SetWindowRgn", "UInt", ClickRippleWindowHwnd, "UInt", finalRegion, "UInt", true)
        WinSet,Transparent , %CurrentRippleAlpha%, % "ahk_id " ClickRippleWindowHwnd
        DeleteObject(finalRegion)        
        ; Clone the current region and save it for the next usage
        local clonedRegion := DllCall("CreateRectRgn", "int", 0, "int", 0, "int", 0, "int", 0)
        local RegionType := DllCall("GetWindowRgn", "uint", ClickRippleWindowHwnd, "uint", clonedRegion)
        AlreadyCreatedRegionForRipples[regionKey] := clonedRegion 
        CurrentRippleAlpha := CurrentRippleAlpha + RippleAlphaStep        
        if (RippleEventParams.rippleDiameterEnd > RippleEventParams.rippleDiameterStart)
        {
            CurrentRippleDiameter := CurrentRippleDiameter + Abs(RippleEventParams.rippleDiameterStep)
        }
        else
        {
            CurrentRippleDiameter := CurrentRippleDiameter - Abs(RippleEventParams.rippleDiameterStep)
        }
        AlreadyDrawnRipples++
        if (AlreadyDrawnRipples >= TotalCountOfRipples)
        {
            IsStillDrawingRipples := False
            SetTimer, DRAW_RIPPLE, Off
            Gui, MouseClickRippleWindow: Hide
            ; Trigger the function again to check if there are other mouse click events waiting to be drawn
            CheckToDrawNextClickEvent()
        }
    Return
}

SetupMouseClickRipple()
