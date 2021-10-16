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
    SETTINGS := ReadConfigFile("settings.ini") 
    if (SETTINGS.keyStrokeOSD.enabled == True)
    {
        InitializeKeyStrokeOSDGUI()
        AddHotkeysForKeyStrokeOSD()
    }
}

InitializeKeyStrokeOSDGUI(){
    global 
    Gui, KeyStrokeOSDWindow: +LastFound +AlwaysOnTop -Caption +ToolWindow +E0x20 +hwndTheKeyStrokeOSDHwnd ; +ToolWindow avoids a taskbar button and an alt-tab menu item.
    Gui, KeyStrokeOSDWindow: Color, % SETTINGS.keyStrokeOSD.osdWindowBackgroundColor
    Gui, KeyStrokeOSDWindow: Font, % "s" SETTINGS.keyStrokeOSD.osdFontSize, % SETTINGS.keyStrokeOSD.osdFontFamily
    Gui, KeyStrokeOSDWindow: Add, Text, % "x0 y0 center vKeyStrokeOSDTextControl c" SETTINGS.keyStrokeOSD.osdFontColor " w" SETTINGS.keyStrokeOSD.osdWindowWidth " h" SETTINGS.keyStrokeOSD.osdWindowHeight
    WinSet, Transparent, % SETTINGS.keyStrokeOSD.osdWindowOpacity 
    Gui, KeyStrokeOSDWindow: Show, % "x " SETTINGS.keyStrokeOSD.osdWindowPositionX " y" SETTINGS.keyStrokeOSD.osdWindowPositionY " w" SETTINGS.keyStrokeOSD.osdWindowWidth " h" SETTINGS.keyStrokeOSD.osdWindowHeight " NoActivate" ;NoActivate avoids deactivating the currently active window.
    WinHide, ahk_id %TheKeyStrokeOSDHwnd% 
    Return
}

AddHotkeysForKeyStrokeOSD()
{
    global SETTINGS
    ProcessKeyStrokeFunc := Func("ProcessKeyStroke")
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

ProcessKeyStroke()
{ 
    global SETTINGS
    ; SETTINGS.keyStrokeOSD.enabled can be changed by other script such as the Annotation.ahk. So we need to check it before displaying an OSD.
     if (SETTINGS.keyStrokeOSD.enabled != True)
     {
         Return
     }
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

    if (StrLen(theKeyPressed) == 1)
    {
        StringUpper theKeyPressed, theKeyPressed
    }

    CheckAndUpdatePressedModifierKeys(PressedModifierKeys)

    ; Concatenate all modifier keys
    textForPressedModifierKeys := ""
    for index, key in PressedModifierKeys
    {
        if (index == 1)
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
    if (PressedModifierKeys.Length() > 0)
    {
        ; At least one modifier key is pressed
        if (HasVal(PressedModifierKeys, theKeyPressed))
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

    ; Check if it's a key chord, eg: Ctrl+K M            
    if (shouldCheckKeyChord && SETTINGS.keyStrokeOSD.osdKeyChordsRegex)
    {        
        possibleKeyChord := PreviouseHotkeyText " " textToDisplay
        if RegExMatch(possibleKeyChord, SETTINGS.keyStrokeOSD.osdKeyChordsRegex)
        {
            shouldDisplay := True
            textToDisplay := possibleKeyChord            
        }
    }
    PreviouseHotkeyText := valueToUpdatePreviouseHotkeyText

    if (!shouldDisplay){
        ; If it's not a key chord, check if it's a single hotkey key
        if (SETTINGS.keyStrokeOSD.osdHotkeyRegex)
        {
            if (RegExMatch(textToDisplay, SETTINGS.keyStrokeOSD.osdHotkeyRegex))
            {
                shouldDisplay := True
            }
        }
        else
        {
            shouldDisplay := True
        }
    }
    
    if (shouldDisplay)
    { 
        global TheKeyStrokeOSDHwnd 
        SetTimer, HideOSDWindow, Off 
        WinShow, ahk_id %TheKeyStrokeOSDHwnd%        
        GuiControl, KeyStrokeOSDWindow:, KeyStrokeOSDTextControl, % textToDisplay
        PreviouseDisplayedText := textToDisplay
        SetTimer, HideOSDWindow, % SETTINGS.keyStrokeOSD.osdDuration 
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
        if (!GetKeyState(PressedModifierKeys[index], "P"))
        {
            PressedModifierKeys.RemoveAt(index)
        }
        index --
    }

    global ModifierKeyList
    for index, key in ModifierKeyList
    {
        if (GetKeyState(key, "P") and !HasVal(PressedModifierKeys, key))
        {
            PressedModifierKeys.Push(key) 
        }
    }
}

SetupKeyStrokeOSD()

