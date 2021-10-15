#Include ./Utils.ahk
#SingleInstance, Force
#NoEnv
#installmousehook

SetBatchLines, -1
SetWinDelay, -1
CoordMode, mouse, screen

GetDimensionAcrossAllMonitors(){
	global
	; Get the width and height across all monitors
	SysGet, TotalCountOfMonitors, MonitorCount
	MinXOfAllMonitors := 999999999
	MinYOfAllMonitors := 999999999
	MaxXOfAllMonitors := -999999999
	MaxYOfAllMonitors := -999999999
	Loop, %TotalCountOfMonitors%
	{
		SysGet, OneMonitorCoordinate, Monitor, %A_Index%
		if (MinXOfAllMonitors > OneMonitorCoordinateLeft)
		{
			MinXOfAllMonitors := OneMonitorCoordinateLeft
		}
		if (MinYOfAllMonitors > OneMonitorCoordinateTop)
		{
			MinYOfAllMonitors := OneMonitorCoordinateTop
		}
		if (MaxXOfAllMonitors < OneMonitorCoordinateRight)
		{
			MaxXOfAllMonitors := OneMonitorCoordinateRight
		}
		if (MaxYOfAllMonitors < OneMonitorCoordinateBottom)
		{
			MaxYOfAllMonitors := OneMonitorCoordinateBottom
		}
	}

	WidthAcrossAllMonitors := MaxXOfAllMonitors - MinXOfAllMonitors
	HeightAcrossAllMonitors := MaxYOfAllMonitors - MinYOfAllMonitors
}

CreateAnnotationCanvasWindow()
{
	global
	GetDimensionAcrossAllMonitors()
	; Start gdi+
	local pToken
	if !pToken := Gdip_Startup()
	{
		MsgBox, 48, gdiplus error!, Gdiplus failed to start. Please ensure you have gdiplus on your system
		ExitApp
	}

	; Create a layered window (+E0x80000), and it must be used with UpdateLayeredWindow() to trigger repaint.
	Gui, AnnotationCanvasWindow: +AlwaysOnTop -Caption +ToolWindow +E0x80000 +hwndAnnotationCanvasWindowHwnd	
	; Show the line drawing window
	Gui, AnnotationCanvasWindow: Show, x%MinXOfAllMonitors% y%MinYOfAllMonitors%, w%WidthAcrossAllMonitors%, h%HeightAcrossAllMonitors%

	; Create a gdi bitmap that we are going to draw onto.
	AnnotationCanvasWindowHbm := CreateDIBSection(WidthAcrossAllMonitors, HeightAcrossAllMonitors)

	; Get a device context compatible with the screen
	AnnotationCanvasWindowHdc := CreateCompatibleDC()

	; Select the bitmap into the device context
	local obm := SelectObject(AnnotationCanvasWindowHdc, AnnotationCanvasWindowHbm)

	; Get a pointer to the graphics of the bitmap
	AnnotationCanvasWindowGraphics := Gdip_GraphicsFromHDC(AnnotationCanvasWindowHdc)

	; Set the smoothing mode to antialias = 4 to make shapes appear smother
	Gdip_SetSmoothingMode(AnnotationCanvasWindowGraphics, 4)

	; Hide cursor spotlight window and key stroke osd window before taking the screenshot
	CursorSpotlightEnabledOldValue := SETTINGS.cursorSpotlight.enabled		
	KeyStrokeOSDEnabledOldValue := SETTINGS.keyStrokeOSD.enabled
	if(SETTINGS.cursorSpotlight.enabled == True)
	{		
		SETTINGS.cursorSpotlight.enabled := False
		Gui, CursorSpotlightWindow:Hide		
	}
	if(SETTINGS.keyStrokeOSD.enabled == True)
	{		
		SETTINGS.keyStrokeOSD.enabled := False
		Gui, KeyStrokeOSDWindow:Hide
	}

	; Copy screen pixels to a buffer        
	local hdc_screen := GetDC()
	local hdc_buffer := CreateCompatibleDC(hdc_screen)
	local hbm_buffer := CreateCompatibleBitmap(hdc_screen, WidthAcrossAllMonitors, HeightAcrossAllMonitors)
	SelectObject(hdc_buffer, hbm_buffer)
	BitBlt(hdc_buffer, 0, 0, WidthAcrossAllMonitors, HeightAcrossAllMonitors, hdc_screen, MinXOfAllMonitors, MinYOfAllMonitors, 0x00CC0020)

	; Show cursor spotlight window after taking the screenshot
	if (CursorSpotlightEnabledOldValue == True && SETTINGS.annotation.annotationShowSpotlightWhenDrawing == True)
	{
		SETTINGS.cursorSpotlight.enabled := True
		Gui, CursorSpotlightWindow:Show
	}

	; Copy pixels from the buffer to the line annotation window.
	BitBlt(AnnotationCanvasWindowHdc, 0, 0, WidthAcrossAllMonitors, HeightAcrossAllMonitors, hdc_buffer, 0, 0, 0x00CC0020)
	UpdateLayeredWindow(AnnotationCanvasWindowHwnd, AnnotationCanvasWindowHdc, MinXOfAllMonitors, MinYOfAllMonitors, WidthAcrossAllMonitors, HeightAcrossAllMonitors) 

	; Create the pen to draw line annotations
	local annotationAlphaRGB := SETTINGS.annotation.annotationLineAlpha << 24 | SETTINGS.annotation.annotationLineColor
	LineAnnotationPen := Gdip_CreatePen(annotationAlphaRGB, SETTINGS.annotation.annotationLineWidth) 

	; Create the pen to draw rectangle annotations
	local annotationAlphaRGB := SETTINGS.annotation.annotationRectangleBorderAlpha << 24 | SETTINGS.annotation.annotationRectangleBorderColor
	RectangleAnnotationPen := Gdip_CreatePen(annotationAlphaRGB, SETTINGS.annotation.annotationRectangleBorderWidth) 
}

CreateAnnotationTemporaryShapeWindow()
{
	global
	; Start gdi+
	local pToken
	if !pToken := Gdip_Startup()
	{
		MsgBox, 48, gdiplus error!, Gdiplus failed to start. Please ensure you have gdiplus on your system
		ExitApp
	}

	; Create a layered window (+E0x80000), and it must be used with UpdateLayeredWindow() to trigger repaint.
	Gui, AnnotationTemporaryShapeWindow: +AlwaysOnTop -Caption +ToolWindow +E0x80000 +hwndAnnotationTemporaryShapeWindowHwnd
	Gui, AnnotationTemporaryShapeWindow: Show, x%MinXOfAllMonitors% y%MinYOfAllMonitors%, w%WidthAcrossAllMonitors%, h%HeightAcrossAllMonitors%

	; Create a gdi bitmap that we are going to draw onto.
	AnnotationTemporaryShapeWindowHbm := CreateDIBSection(WidthAcrossAllMonitors, HeightAcrossAllMonitors)

	; Get a device context compatible with the screen
	AnnotationTemporaryShapeWindowHdc := CreateCompatibleDC()

	; Select the bitmap into the device context
	local obm := SelectObject(AnnotationTemporaryShapeWindowHdc, AnnotationTemporaryShapeWindowHbm)

	; Get a pointer to the graphics of the bitmap
	AnnotationTemporaryShapeWindowGraphics := Gdip_GraphicsFromHDC(AnnotationTemporaryShapeWindowHdc)

	; Set the smoothing mode to antialias = 4 to make shapes appear smother
	Gdip_SetSmoothingMode(AnnotationTemporaryShapeWindowGraphics, 4)

	; Create the pen to draw line annotations with half of the alpha on the AnnotationTemporaryShapeWindow
	local annotationAlphaRGB := Round(SETTINGS.annotation.annotationLineAlpha/2) << 24 | SETTINGS.annotation.annotationLineColor
	LineAnnotationPenForTemporaryShape := Gdip_CreatePen(annotationAlphaRGB, SETTINGS.annotation.annotationLineWidth) 

	Return
}

DestroyAnnotationCanvasWindow()
{
	global
	; Destory the line annotation window
	DeleteDC(AnnotationCanvasWindowHdc)
	DeleteObject(AnnotationCanvasWindowHbm) 
	Gdip_DeletePen(LineAnnotationPen)
	Gdip_DeletePen(LineAnnotationPenForTemporaryShape)
	Gui, AnnotationCanvasWindow: Destroy
}

DestroyAnnotationTemporaryShapeWindow()
{	
	global
	; Destory the rectangle annotation window
	DeleteDC(AnnotationTemporaryShapeWindowHdc)
	DeleteObject(AnnotationTemporaryShapeWindowHbm) 
	Gdip_DeletePen(RectangleAnnotationPen)
	Gui, AnnotationTemporaryShapeWindow: Destroy
}

ResetVariablesForLineDrawing()
{
	global
	; Reset some variables which are going to be used in the DRAW_LINE_ANNOTATION subroutine
	SecondPreviousLineAnnotationMousePositionX := ""
	SecondPreviousLineAnnotationMousePositionY := ""
	PreviousLineAnnotationMousePositionX := ""
	PreviousLineAnnotationMousePositionY := ""
	HasFirstLineAnnotationSegmentBeenDrawn := False
	AllPointsInLineAnnotation := ""
}

ResetVariablesForRectangleDrawing()
{
	global
	; Reset some variables which are going to be used in the DRAW_RECTANGLE_ANNOTATION subroutine
	RectangleAnnotationStartPointX := ""
	RectangleAnnotationStartPointY := ""
}

CurrentAnnotationMode := "Off"
SwitchAnnotationDrawingMode(modeToToggle)
{ 
	global 
	if (modeToToggle == "LineAnnotation")
	{
		if (CurrentAnnotationMode == "LineAnnotation")
		{
			; If it's already drawing line annotations, we don't need to do anything here.
		}
		if (CurrentAnnotationMode == "RectangleAnnotation")
		{
			; If it's drawing rectangle, we can turn off DRAW_RECTANGLE_ANNOTATION timer and turn on DRAW_LINE_ANNOTATION timer.
			SetTimer, DRAW_RECTANGLE_ANNOTATION, Off 						
			ResetVariablesForLineDrawing()
			SetTimer, DRAW_LINE_ANNOTATION, 10
			CurrentAnnotationMode := "LineAnnotation"
		}
		if (CurrentAnnotationMode == "Off")
		{
			; If it's in the "Off" state, it means no annotation window is open at the moment. We need to create the necessary windows.
			CreateAnnotationCanvasWindow()
			CreateAnnotationTemporaryShapeWindow()
			ResetVariablesForLineDrawing()
			SetTimer, DRAW_LINE_ANNOTATION, 10
			CurrentAnnotationMode := "LineAnnotation"
		}
	}

	if (modeToToggle == "RectangleAnnotation")
	{
		if (CurrentAnnotationMode == "LineAnnotation")
		{
			; If it's drawing lines, we can turn off DRAW_LINE_ANNOTATION timer and turn on DRAW_RECTANGLE_ANNOTATION timer.
			SetTimer, DRAW_LINE_ANNOTATION, Off			
			ResetVariablesForRectangleDrawing()
			SetTimer, DRAW_RECTANGLE_ANNOTATION, 10
			CurrentAnnotationMode := "RectangleAnnotation"
		}
		if (CurrentAnnotationMode == "RectangleAnnotation")
		{
			; If it's already drawing rectangles, we don't need to do anything here.			
		}
		if (CurrentAnnotationMode == "Off")
		{
			; If it's in the "Off" state, it means no annotation window is open at the moment. We need to create the necessary windows.
			CreateAnnotationCanvasWindow()
			CreateAnnotationTemporaryShapeWindow()
			ResetVariablesForRectangleDrawing()
			SetTimer, DRAW_RECTANGLE_ANNOTATION, 10
			CurrentAnnotationMode := "RectangleAnnotation"
		}
	}

	if (modeToToggle == "Off")
	{
		; Show cursor spotlight window and keyStrokeOSD window
		SETTINGS.cursorSpotlight.enabled := CursorSpotlightEnabledOldValue
		SETTINGS.keyStrokeOSD.enabled := KeyStrokeOSDEnabledOldValue
		SetTimer, DRAW_RECTANGLE_ANNOTATION, Off
		SetTimer, DRAW_LINE_ANNOTATION, Off
		DestroyAnnotationTemporaryShapeWindow()
		DestroyAnnotationCanvasWindow()
		CurrentAnnotationMode := "Off"
	}

	Return
	DRAW_LINE_ANNOTATION: 
		if (GetKeyState("LButton", "P"))
		{ 
			MouseGetPos LineAnnotationMousePositionX, LineAnnotationMousePositionY
			; The mouse position is in the screen's coordinate, and it can be a negative value in a multiple-monitor setup. 
			; The overlay window we want to draw on uses a different coordinate, so we need to convert from screen's coordinate to the overlay window coordinate.
			LineAnnotationMousePositionX := LineAnnotationMousePositionX - MinXOfAllMonitors
			LineAnnotationMousePositionY := LineAnnotationMousePositionY - MinYOfAllMonitors
			if (PreviousLineAnnotationMousePositionX != "" && SecondPreviousLineAnnotationMousePositionX != ""
				&& (LineAnnotationMousePositionX != PreviousLineAnnotationMousePositionX || LineAnnotationMousePositionY != PreviousLineAnnotationMousePositionY))
			{
				; The mouse has moved by some distance, so we can start drawing the segments. We use Gdip_DrawLines() to connect three points togeter by drawing 
				; two consecutive segments (one segment has actually already been drawn before). In that way, it can avoid gaps between each segment.
				Gdip_DrawLines(AnnotationTemporaryShapeWindowGraphics
					, LineAnnotationPenForTemporaryShape
				, SecondPreviousLineAnnotationMousePositionX "," SecondPreviousLineAnnotationMousePositionY "|" PreviousLineAnnotationMousePositionX "," PreviousLineAnnotationMousePositionY "|" LineAnnotationMousePositionX "," LineAnnotationMousePositionY) 
				Gui, AnnotationTemporaryShapeWindow: Show
				UpdateLayeredWindow(AnnotationTemporaryShapeWindowHwnd, AnnotationTemporaryShapeWindowHdc, MinXOfAllMonitors, MinYOfAllMonitors, WidthAcrossAllMonitors, HeightAcrossAllMonitors) 

				if(HasFirstLineAnnotationSegmentBeenDrawn == False)
				{
					; Draw the first segment twice so that it has the same alpha as the other segments
					Gdip_DrawLines(AnnotationTemporaryShapeWindowGraphics
						, LineAnnotationPenForTemporaryShape
					, SecondPreviousLineAnnotationMousePositionX "," SecondPreviousLineAnnotationMousePositionY "|" PreviousLineAnnotationMousePositionX "," PreviousLineAnnotationMousePositionY) 
					Gui, AnnotationTemporaryShapeWindow: Show
					UpdateLayeredWindow(AnnotationTemporaryShapeWindowHwnd, AnnotationTemporaryShapeWindowHdc, MinXOfAllMonitors, MinYOfAllMonitors, WidthAcrossAllMonitors, HeightAcrossAllMonitors) 
					HasFirstLineAnnotationSegmentBeenDrawn := True
				}
			}

			if (LineAnnotationMousePositionX != PreviousLineAnnotationMousePositionX || LineAnnotationMousePositionY != PreviousLineAnnotationMousePositionY)
			{
				; If the cursor position is different from its previous position, we should update the previous points.
				SecondPreviousLineAnnotationMousePositionX := PreviousLineAnnotationMousePositionX
				SecondPreviousLineAnnotationMousePositionY := PreviousLineAnnotationMousePositionY
				PreviousLineAnnotationMousePositionX := LineAnnotationMousePositionX
				PreviousLineAnnotationMousePositionY := LineAnnotationMousePositionY
				if (AllPointsInLineAnnotation == "")
				{
					AllPointsInLineAnnotation := LineAnnotationMousePositionX "," LineAnnotationMousePositionY
				}
				else
				{
					AllPointsInLineAnnotation := AllPointsInLineAnnotation "|" LineAnnotationMousePositionX "," LineAnnotationMousePositionY
				}				
			}
		}
		else
		{ 
			; The left button has been released
			if (AllPointsInLineAnnotation != "")
			{
				; If the left button has been released, we can clear the drawing on the AnnotationTemporaryShapeWindow and draw the final shape to the AnnotationCanvasWindow
				Gdip_DrawLines(AnnotationCanvasWindowGraphics
					, LineAnnotationPen
				, AllPointsInLineAnnotation) 
				UpdateLayeredWindow(AnnotationCanvasWindowHwnd, AnnotationCanvasWindowHdc, MinXOfAllMonitors, MinYOfAllMonitors, WidthAcrossAllMonitors, HeightAcrossAllMonitors)
				Sleep, 50
				Gdip_GraphicsClear(AnnotationTemporaryShapeWindowGraphics, 0)
				UpdateLayeredWindow(AnnotationTemporaryShapeWindowHwnd, AnnotationTemporaryShapeWindowHdc, MinXOfAllMonitors, MinYOfAllMonitors, WidthAcrossAllMonitors, HeightAcrossAllMonitors) 
			}
			ResetVariablesForLineDrawing()
		}
	Return

	DRAW_RECTANGLE_ANNOTATION: 
		MouseGetPos RectangleAnnotationMousePositionX, RectangleAnnotationMousePositionY
		RectangleAnnotationMousePositionX := RectangleAnnotationMousePositionX - MinXOfAllMonitors
		RectangleAnnotationMousePositionY := RectangleAnnotationMousePositionY - MinYOfAllMonitors
		if (GetKeyState("LButton", "P"))
		{
			if (RectangleAnnotationStartPointX == "")
			{
				RectangleAnnotationStartPointX := RectangleAnnotationMousePositionX
				RectangleAnnotationStartPointY := RectangleAnnotationMousePositionY							
			}
			else
			{
				RectangleAnnotationTopLeftPointX := Min(RectangleAnnotationStartPointX, RectangleAnnotationMousePositionX)
				RectangleAnnotationTopLeftPointY := Min(RectangleAnnotationStartPointY, RectangleAnnotationMousePositionY)
				RectangleAnnotationWidth := Abs(RectangleAnnotationMousePositionX - RectangleAnnotationStartPointX)
				RectangleAnnotationHeight := Abs(RectangleAnnotationMousePositionY - RectangleAnnotationStartPointY)

				Gdip_GraphicsClear(AnnotationTemporaryShapeWindowGraphics, 0)
				Gdip_DrawRectangle(AnnotationTemporaryShapeWindowGraphics
					,RectangleAnnotationPen
					,RectangleAnnotationTopLeftPointX
					,RectangleAnnotationTopLeftPointY
					,RectangleAnnotationWidth
				,RectangleAnnotationHeight)
				Gui, AnnotationTemporaryShapeWindow: Show				
				UpdateLayeredWindow(AnnotationTemporaryShapeWindowHwnd, AnnotationTemporaryShapeWindowHdc, MinXOfAllMonitors, MinYOfAllMonitors, WidthAcrossAllMonitors, HeightAcrossAllMonitors) 
			}
		}
		else if (RectangleAnnotationStartPointX != "")
		{ 
			; If the left button has been released, we can clear the drawing on the AnnotationTemporaryShapeWindow and draw the final Rectangle to the AnnotationCanvasWindow			
			Gdip_DrawRectangle(AnnotationCanvasWindowGraphics
				,RectangleAnnotationPen
				,RectangleAnnotationTopLeftPointX
				,RectangleAnnotationTopLeftPointY
				,RectangleAnnotationWidth
			,RectangleAnnotationHeight)			
			UpdateLayeredWindow(AnnotationCanvasWindowHwnd, AnnotationCanvasWindowHdc, MinXOfAllMonitors, MinYOfAllMonitors, WidthAcrossAllMonitors, HeightAcrossAllMonitors) 			
			Sleep, 50
			Gdip_GraphicsClear(AnnotationTemporaryShapeWindowGraphics, 0)
			UpdateLayeredWindow(AnnotationTemporaryShapeWindowHwnd, AnnotationTemporaryShapeWindowHdc, MinXOfAllMonitors, MinYOfAllMonitors, WidthAcrossAllMonitors, HeightAcrossAllMonitors) 
			ResetVariablesForRectangleDrawing()
		}
	Return
}

SetupLineAnnotationDrawing()
{
	global SETTINGS := ReadConfigFile("settings.ini")
	if (SETTINGS.annotation.enabled == True){
		SwitchAnnotationDrawingModeToLineDrawing := Func("SwitchAnnotationDrawingMode").Bind("LineAnnotation")
		SwitchAnnotationDrawingModeToRectangleDrawing := Func("SwitchAnnotationDrawingMode").Bind("RectangleAnnotation")
		SwitchAnnotationDrawingModeToOff := Func("SwitchAnnotationDrawingMode").Bind("Off")
		Hotkey, % SETTINGS.annotation.annotationLineDrawingToggleHotkey, %SwitchAnnotationDrawingModeToLineDrawing%
		Hotkey, % SETTINGS.annotation.annotationRectangleDrawingToggleHotkey, %SwitchAnnotationDrawingModeToRectangleDrawing%
		Hotkey, % SETTINGS.annotation.annotationClearDrawingHotkey, %SwitchAnnotationDrawingModeToOff%		
	}
}

SetupLineAnnotationDrawing()