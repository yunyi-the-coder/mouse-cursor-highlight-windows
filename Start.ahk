#Include ./MouseSpotlight.ahk
#Include ./KeyStrokeOSD.ahk
#Include ./Annotation.ahk
; There are two ahk files which can display a ripple effect for mouse clicks: MouseClickRippleWithGui.ahk and MouseClickRipple.ahk.
; The MouseClickRippleWithGui.ahk uses window regions to simulate the ripples and MouseClickRipple.ahk uses LayeredWindow and gdi to draw ripples.
; The performance of MouseClickRipple.ahk is a little better than MouseClickRippleWithGui.ahk, and because gdi has an anti-aliasing mode, the circles
; drawn by MouseClickRipple.ahk are rounder than those drawn by MouseClickRippleWithGui.ahk.
; However, in my testing MouseClickRipple.ahk may cause problems to some programs -- they cannot respond to mouse clicking events correctly (e.g. DaVinci Resolve 17).
; But I haven't run into issues with MouseClickRippleWithGui.ahk, so MouseClickRippleWithGui.ahk seems to have better compatibility than MouseClickRipple.ahk.
; #Include ./MouseClickRippleWithGui.ahk
#Include ./MouseClickRipple.ahk
