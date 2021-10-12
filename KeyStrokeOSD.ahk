#Include ./Utils.ahk
#SingleInstance, Force
#NoEnv
#MaxThreadsPerHotkey 3
#installmousehook
#MaxHotkeysPerInterval 100

SetBatchLines, -1
SetWinDelay, -1
CoordMode, mouse, screen

ModifierKeyList := ["Shift", "Alt", "Ctrl", "LWin", "RWin"] 

SetupKeyStrokeOSD()
{
    global
    Config := ReadConfigFile("config.ini") 
    if Config.keyStrokeOSD.enabled = "True"
    {
        InitializeKeyStrokeOSDGUI(Config)
        AddHotkeysForKeyStrokeOSD(Config)
    }
}

InitializeKeyStrokeOSDGUI(Config){
    global 
    Gui, KeyStrokeOSDWindow: +LastFound +AlwaysOnTop -Caption +ToolWindow +E0x20 +hwndTheKeyStrokeOSDHwnd ; +ToolWindow avoids a taskbar button and an alt-tab menu item.
    Gui, KeyStrokeOSDWindow: Color, % Config.keyStrokeOSD.osdWindowBackgroundColor
    Gui, KeyStrokeOSDWindow: Font, % "s" Config.keyStrokeOSD.osdFontSize
    Gui, KeyStrokeOSDWindow: Add, Text, % "x0 y0 center vKeyStrokeOSDTextControl c" Config.keyStrokeOSD.osdFontColor " w" Config.keyStrokeOSD.osdWindowWidth " h" Config.keyStrokeOSD.osdWindowHeight
    WinSet, Transparent, % Config.keyStrokeOSD.osdWindowOpacity 
    Gui, KeyStrokeOSDWindow: Show, % "x " Config.keyStrokeOSD.osdWindowPositionX " y" Config.keyStrokeOSD.osdWindowPositionY " w" Config.keyStrokeOSD.osdWindowWidth " h" Config.keyStrokeOSD.osdWindowHeight " NoActivate" ;NoActivate avoids deactivating the currently active window.
    WinHide, ahk_id %TheKeyStrokeOSDHwnd% 
    Return
}

AddHotkeysForKeyStrokeOSD(Config)
{
    local ProcessKeyStrokeFunc := Func("ProcessKeyStroke").Bind(Config) 
    SetFormat, Integer, hex
    start:= 0 
    Loop, 227
    {
        if ((key:=GetKeyName("vk" start++))!="")
            Hotkey, ~*%key%, %ProcessKeyStrokeFunc%
    }

    for a, b in StrSplit("Up,Down,Left,Right,End,Home,PgUp,PgDn,Insert,NumpadEnter,#,^,!,+",",")
    {
        Hotkey, ~*%b%, %ProcessKeyStrokeFunc%
    }

    SetFormat, Integer, dec

    for a, b in StrSplit("!@#$%^&*()_+:<>{}|?~" Chr(34))
        Hotkey, ~+%b%, %ProcessKeyStrokeFunc%

    Hotkey, ~*Delete, %ProcessKeyStrokeFunc%
}

ProcessKeyStroke(Config)
{ 
    static PressedModifierKeys
    if (!isobject(PressedModifierKeys)) 
    {
        PressedModifierKeys := [] 
    }

    theKeyPressed := SubStr(A_ThisHotkey,3)

    Switch theKeyPressed
    {
    Case "LControl", "RControl":
        theKeyPressed := "Ctrl" 
    Case "LShift", "RShift":
        theKeyPressed := "Shift"
    Case "LAlt", "RAlt":
        theKeyPressed := "Alt" 
    }

    if StrLen(theKeyPressed) = 1
    {
        StringUpper theKeyPressed, theKeyPressed
    }

    CheckAndUpdatePressedModifierKeys(PressedModifierKeys)

    ; Concatenate all modifier keys
    textForPressedModifierKeys := ""
    for index, key in PressedModifierKeys
    {
        if index = 1
        {
            textForPressedModifierKeys := key
        }
        else
        {
            textForPressedModifierKeys := textForPressedModifierKeys "+" key
        }
    }

    static PreviouseDisplayedText, PreviouseHotkeyText, LastTickCount
    valueToUpdatePreviouseHotkeyText := PreviouseHotkeyText
    shouldCheckKeyChord := True
    if PressedModifierKeys.Length() > 0 
    {
        ; At least one modifier key is pressed
        if HasVal(PressedModifierKeys, theKeyPressed)
        {
            ; Only the modifier keys pressed
            PreviouseDisplayedTextBeginningStr := SubStr(PreviouseDisplayedText, 1 , StrLen(textForPressedModifierKeys))
            if (PreviouseDisplayedTextBeginningStr == textForPressedModifierKeys and A_TickCount - LastTickCount < 400)
            {
                ; The modifier keys are the same as the previous key combinations
                textToDisplay := PreviouseDisplayedText
                shouldCheckKeyChord := False
            }
            else
            {
                ; The modifier keys are not the same as the previous key combinations
                textToDisplay := textForPressedModifierKeys
                valueToUpdatePreviouseHotkeyText := ""                
            }
        }
        else
        {
            ; Both modifier key(s) and a non-modifier key are pressed
            textToDisplay := textForPressedModifierKeys "+" theKeyPressed
            valueToUpdatePreviouseHotkeyText := textToDisplay            
        }
    }else{
        ; There is no modifier key pressed
        textToDisplay := theKeyPressed        
        valueToUpdatePreviouseHotkeyText := ""        
    }

    LastTickCount := A_TickCount

    ; shouldDisplay := False
    ; Check if it's a key chord, eg: Ctrl+K M            
    if shouldCheckKeyChord and Config.keyStrokeOSD.osdKeyChordsRegex
    {        
        possibleKeyChord := PreviouseHotkeyText " " textToDisplay
        if RegExMatch(possibleKeyChord, Config.keyStrokeOSD.osdKeyChordsRegex)
        {
            shouldDisplay := True
            textToDisplay := possibleKeyChord
        }
    }
    PreviouseHotkeyText := valueToUpdatePreviouseHotkeyText

    if (!shouldDisplay){
        ; Check if it's a hotkey
        if Config.keyStrokeOSD.osdHotKeyRegex
        {
            if RegExMatch(textToDisplay, Config.keyStrokeOSD.osdHotKeyRegex)
            {
                shouldDisplay := True
            }
        }
        else
        {
            shouldDisplay := True
        }
    }

    if shouldDisplay
    { 
        global TheKeyStrokeOSDHwnd 
        SetTimer, HideOSDWindow, Off 
        WinShow, ahk_id %TheKeyStrokeOSDHwnd%        
        GuiControl, KeyStrokeOSDWindow:, KeyStrokeOSDTextControl, % textToDisplay
        PreviouseDisplayedText := textToDisplay
        SetTimer, HideOSDWindow, % Config.keyStrokeOSD.osdDuration 
    }

    Return

    HideOSDWindow:
        SetTimer, HideOSDWindow, Off
        PressedModifierKeys := []
        PreviouseDisplayedText := ""
        PreviouseHotkeyText := ""
        WinHide, ahk_id %TheKeyStrokeOSDHwnd% 
    Return
}

CheckAndUpdatePressedModifierKeys(PressedModifierKeys)
{
    ; Remove the keys which are already released
    index := PressedModifierKeys.Count()
    while index > 0
    {
        if !GetKeyState(PressedModifierKeys[index], "P")
        {
            PressedModifierKeys.RemoveAt(index)
        }
        index --
    }

    global ModifierKeyList
    for index, key in ModifierKeyList
    {
        if GetKeyState(key, "P") and !HasVal(PressedModifierKeys, key)
        {
            PressedModifierKeys.Push(key) 
        }
    }
}

SetupKeyStrokeOSD()

