#Requires AutoHotkey v2.0
#SingleInstance Force

;=========================================================
;  Макрос фарма мобов — Minecraft Java (play.workahop47.pro, «2 этап»)
;
;  Управление:
;    F6 — полный фарм: бег + обзор + стрельба
;    F7 — только стрельба (стоишь на месте, сам целишься)
;    F8 — аварийный стоп (отпускает все клавиши)
;
;  Установка: поставь AutoHotkey v2, запусти этот файл двойным кликом.
;  Перед входом в бой стань на открытую зону спавна мобов.
;=========================================================

; ----------------- НАСТРОЙКИ -----------------
FireStyle     := "click"  ; "click" = спам ЛКМ (один выстрел = один клик), "hold" = просто держать ЛКМ
AimDownSights := false    ; true = всё время держать ПКМ (если оружие целится правой кнопкой)
Sprint        := true     ; держать Ctrl — постоянный бег
ClickMin      := 55       ; мин. пауза между выстрелами, мс
ClickMax      := 120      ; макс. пауза (ставь выше, если сервер кикает за автокликер)
SweepMin      := 5        ; скорость обвода прицелом, px за тик
SweepMax      := 20
TurnPauseMin  := 700      ; как часто менять направление обзора, мс
TurnPauseMax  := 2500
DirPauseMin   := 900      ; как часто менять направление бега, мс
DirPauseMax   := 2800
JumpChance    := 7        ; шанс прыжка за тик, %
TickMs        := 50       ; частота тика, мс
; ----------------------------------------------

state     := 0            ; 0 = выкл, 1 = фарм, 2 = только стрельба
released  := true
dirKey    := ""
sweepDir  := 1
sprintDown := false
adsDown   := false
fireDown  := false
nextTurn  := A_TickCount
nextDir   := A_TickCount
fireNext  := A_TickCount

; ----------------- ГОРЯЧИЕ КЛАВИШИ -----------------
F6:: {
    global state
    state := (state = 1) ? 0 : 1
    Status()
}
F7:: {
    global state
    state := (state = 2) ? 0 : 2
    Status()
}
F8:: {
    global state
    state := 0
    Status()
}
; ---------------------------------------------------

; ----------------- ГЛАВНЫЙ ЦИКЛ --------------------
Loop {
    now := A_TickCount

    if (state = 0) {
        if (!released) {
            ReleaseAll()
            released := true
        }
        Sleep(100)
        continue
    }

    ; не шлём ввод, пока игра не активна (свободно можно Alt-Tab)
    if !(WinActive("ahk_exe javaw.exe") || WinActive("ahk_exe java.exe")) {
        Sleep(200)
        continue
    }

    if (released) {
        released := false
        if (state = 1 && Sprint) {
            Send("{Ctrl Down}")
            sprintDown := true
        }
        if (AimDownSights) {
            Send("{RButton Down}")
            adsDown := true
        }
        nextDir := now
        nextTurn := now
        fireNext := now
    }

    if (state = 1) {
        MoveTick(now)
        LookTick(now)
    }

    FireTick(now)
    Sleep(TickMs)
}
; ---------------------------------------------------

; ------------- ДВИЖЕНИЕ (случайный бег) -------------
MoveTick(now) {
    global dirKey, nextDir, DirPauseMin, DirPauseMax, JumpChance
    if (now >= nextDir) {
        if (dirKey != "")
            Send("{" dirKey " Up}")
        r := Random(1, 10)
        if (r <= 5)
            dirKey := "w"          ; вперёд — чаще всего
        else if (r <= 7)
            dirKey := "a"
        else if (r <= 9)
            dirKey := "d"
        else
            dirKey := "s"
        Send("{" dirKey " Down}")
        nextDir := now + Random(DirPauseMin, DirPauseMax)
    }
    if (Random(1, 100) <= JumpChance) {
        Send("{Space Down}")
        Sleep(45)
        Send("{Space Up}")
    }
}
; ---------------------------------------------------

; -------------- ОБЗОР (обводка прицелом) ------------
LookTick(now) {
    global nextTurn, sweepDir, SweepMin, SweepMax, TurnPauseMin, TurnPauseMax
    if (now >= nextTurn) {
        sweepDir := -sweepDir
        nextTurn := now + Random(TurnPauseMin, TurnPauseMax)
        if (Random(1, 100) <= 25)
            MoveMouseRel(Random(-300, 300), Random(-80, 120))  ; резкий разворот
    }
    MoveMouseRel(sweepDir * Random(SweepMin, SweepMax), Random(-2, 3))
}

; Относительное движение мыши (работает в играх)
MoveMouseRel(dx, dy) {
    DllCall("mouse_event", "uint", 0x0001, "int", dx, "int", dy, "uint", 0, "uptr", 0)
}
; ---------------------------------------------------

; ------------------- СТРЕЛЬБА ----------------------
FireTick(now) {
    global FireStyle, fireNext, ClickMin, ClickMax, fireDown
    if (FireStyle = "hold") {
        if (!fireDown) {
            Send("{LButton Down}")
            fireDown := true
        }
        return
    }
    if (now >= fireNext) {
        Send("{LButton Down}")
        Sleep(Random(20, 45))
        Send("{LButton Up}")
        fireNext := now + Random(ClickMin, ClickMax)
    }
}
; ---------------------------------------------------

; ------------------ ОТПУСК КЛАВИШ ------------------
ReleaseAll() {
    global dirKey, sprintDown, adsDown, fireDown
    if (dirKey != "") {
        Send("{" dirKey " Up}")
        dirKey := ""
    }
    if (sprintDown) {
        Send("{Ctrl Up}")
        sprintDown := false
    }
    if (adsDown) {
        Send("{RButton Up}")
        adsDown := false
    }
    if (fireDown) {
        Send("{LButton Up}")
        fireDown := false
    }
    Send("{LButton Up}")
    Send("{Space Up}")
}
; ---------------------------------------------------

; -------------------- СТАТУС -----------------------
Status() {
    global state
    if (state = 0)
        txt := "Макрос: ВЫКЛ`nF6 — фарм | F7 — только стрельба | F8 — стоп"
    else if (state = 1)
        txt := "МАКРОС: ФАРМ (бег + обзор + стрельба)`nF8 — стоп"
    else
        txt := "МАКРОС: ТОЛЬКО СТРЕЛЬБА`nF8 — стоп"
    ToolTip(txt, 20, 20)
    SetTimer(StatusTipOff, -3000)
}
StatusTipOff() => ToolTip()
; ---------------------------------------------------
