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
    ; Calculate the width/height of the bitmap we are going to create
    ClickRippleBitMapWidth := Max(SETTINGS.cursorLeftClickRippleEffect.rippleDiameterStart
        , SETTINGS.cursorLeftClickRippleEffect.rippleDiameterEnd
        , SETTINGS.cursorMiddleClickRippleEffect.rippleDiameterStart
        , SETTINGS.cursorMiddleClickRippleEffect.rippleDiameterEnd
        , SETTINGS.cursorRightClickRippleEffect.rippleDiameterStart
    , SETTINGS.cursorRightClickRippleEffect.rippleDiameterEnd ) + 2

    ; Start gdi+    
    if (!Gdip_Startup())
    {
        MsgBox, 48, gdiplus error!, Gdiplus failed to start. Please ensure you have gdiplus on your system
        ExitApp
    }

    ; Create a layered window (+E0x80000), and it must be used with UpdateLayeredWindow() to trigger repaint.
    Gui, MouseClickRippleWindow: +AlwaysOnTop -Caption +ToolWindow +E0x80000 +hwndClickRippleWindowHwnd
    Gui, MouseClickRippleWindow: Show, NA

    ; Create a gdi bitmap that we are going to draw onto.
    ClickRippleHbm := CreateDIBSection(ClickRippleBitMapWidth, ClickRippleBitMapWidth)

    ; Get a device context compatible with the screen
    ClickRippleHdc := CreateCompatibleDC()

    ; Select the bitmap into the device context
    local obm := SelectObject(ClickRippleHdc, ClickRippleHbm)

    ; Get a pointer to the graphics of the bitmap
    ClickRippleGraphics := Gdip_GraphicsFromHDC(ClickRippleHdc)

    ; Set the smoothing mode to antialias = 4 to make shapes appear smother
    Gdip_SetSmoothingMode(ClickRippleGraphics, 4)

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

    ; Add an event to the event array and call the CheckToDrawNextClickEvent function.
    MouseGetPos rippleMousePositionX, rippleMousePositionY
    params.rippleMousePositionX := rippleMousePositionX
    params.rippleMousePositionY := rippleMousePositionY
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
    
    if RippleEventParams.playClickSound == True
    {
        SoundPlay,  %A_ScriptDir%\MouseClickSound.wav
    }

    IsStillDrawingRipples := True

    CurrentRippleDiameter := RippleEventParams.rippleDiameterStart
    CurrentRippleAlpha := RippleEventParams.rippleAlphaStart
    TotalCountOfRipples := Abs(Round((RippleEventParams.rippleDiameterEnd - RippleEventParams.rippleDiameterStart) / RippleEventParams.rippleDiameterStep))
    RippleAlphaStep := Round((RippleEventParams.rippleAlphaEnd - RippleEventParams.rippleAlphaStart) / TotalCountOfRipples)

    RippleWindowPositionX := RippleEventParams.rippleMousePositionX - Round(ClickRippleBitMapWidth/2)
    RippleWindowPositionY := RippleEventParams.rippleMousePositionY - Round(ClickRippleBitMapWidth/2)

    AlreadyDrawnRipples := 0    
    SetTimer, DRAW_RIPPLE, % RippleEventParams.rippleRefreshInterval
    DRAW_RIPPLE:
        ; Clear the previous drawing
        Gdip_GraphicsClear(ClickRippleGraphics, 0)
        ; Create a pen with ARGB (ARGB = Transparency, red, green, blue) to draw a circle
        local alphaRGB := CurrentRippleAlpha << 24 | RippleEventParams.rippleColor
        local pPen := Gdip_CreatePen(alphaRGB, RippleEventParams.rippleLineWidth)

        ; Draw a circle into the graphics of the bitmap using the pen created
        Gdip_DrawEllipse(ClickRippleGraphics
            , pPen
            , (ClickRippleBitMapWidth - CurrentRippleDiameter)/2
            , (ClickRippleBitMapWidth - CurrentRippleDiameter)/2
            , CurrentRippleDiameter
        , CurrentRippleDiameter)
        Gdip_DeletePen(pPen)        
        UpdateLayeredWindow(ClickRippleWindowHwnd, ClickRippleHdc, RippleWindowPositionX, RippleWindowPositionY, ClickRippleBitMapWidth, ClickRippleBitMapWidth) 
        
        ; Calculate necessary values to prepare for drawing the next circle
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
            ; All circles for one click event has been drawn
            IsStillDrawingRipples := False
            SetTimer, DRAW_RIPPLE, Off
            Gdip_GraphicsClear(ClickRippleGraphics, 0)
            UpdateLayeredWindow(ClickRippleWindowHwnd, ClickRippleHdc, RippleWindowPositionX, RippleWindowPositionY, ClickRippleBitMapWidth, ClickRippleBitMapWidth)
            ; Trigger the function again to check if there are other mouse click events waiting to be processed
            CheckToDrawNextClickEvent()
        }
    Return
}

SetupMouseClickRipple()