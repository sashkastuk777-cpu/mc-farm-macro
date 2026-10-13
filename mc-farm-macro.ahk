#Requires AutoHotkey v2.0
#SingleInstance Force

;=========================================================
;  Макрос фарма мобов — Minecraft Java (play.workahop47.pro, «2 этап»)
;
;  Управление:
;    F6 — полный фарм: бег + обзор + стрельба
;    F7 — только стрельба (стоишь на месте, сам целишься)
;    F8 — аварийный стоп (отпускает все клавиши)
;    F9 — калибровка цвета зомби (стрельба ТОЛЬКО по зомби)
;    F5 — смена камеры (блокируется, пока макрос включён)
;
;  Установка: поставь AutoHotkey v2, запусти этот файл двойным кликом.
;  Перед входом в бой стань на открытую зону спавна мобов.
;
;  Стрельба только по зомби:
;    1) включить F6 или F7
;    2) навести прицел на зелёный участок кожи зомби
;    3) нажать F9 — цвет сохранится в mc-farm.ini рядом с .exe
;    После этого выстрелы пойдут только когда под прицелом есть
;    похожий цвет. До калибровки макрос стреляет как раньше.
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

; ------------- СТРЕЛЬБА ТОЛЬКО В ЗОМБИ -------------
; Все значения можно править в mc-farm.ini (создастся после F9),
; пересборка не нужна.
IniFile         := A_ScriptDir "\mc-farm.ini"
OnlyZombies     := (IniRead(IniFile, "Zombie", "Only", "true") = "true")
ZombieBox       := SafeInt(IniRead(IniFile, "Zombie", "Box", "45"), 45)        ; полуразмер зоны у прицела, px
ZombieTolerance := SafeInt(IniRead(IniFile, "Zombie", "Tolerance", "42"), 42)  ; допуск цвета, 0..255
ZombieColorDef  := "0x00A800"                                                  ; заглушка до калибровки
ZombieColor     := IniRead(IniFile, "Zombie", "Color", ZombieColorDef)
Calibrated      := (ZombieColor != ZombieColorDef)   ; F9 уже нажимали?

; Integer() бросает исключение на мусоре из INI — иначе макрос не стартовал бы
SafeInt(s, def) {
    try
        return Integer(s)
    catch
        return def
}
; ---------------------------------------------------

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

CoordMode "Pixel", "Screen"

; ----------------- ГОРЯЧИЕ КЛАВИШИ -----------------
; "*" перед клавишей = срабатывает даже если зажат Ctrl/Shift/Alt.
; Без "*" F8 НЕ срабатывал во время фарма: скрипт держит Ctrl (спринт),
; и нажатие приходило как Ctrl+F8 — макрос невозможно было остановить.
*F6:: {
    global state
    SetState((state = 1) ? 0 : 1)
}
*F7:: {
    global state
    SetState((state = 2) ? 0 : 2)
}
*F8:: {
    SetState(0)
}
; F5 (смена камеры) блокируем, пока макрос включён: в третьем лице
; постоянная обводка прицелом крутит камеру как бешеная
$*F5:: {
    global state
    if (state = 0) {
        Send("{F5}")
        return
    }
    ToolTip("F5 отключён, пока макрос включён. F8 — стоп", 20, 20)
    SetTimer(() => ToolTip(), -1500)
}
; Калибровка цвета зомби: наведи прицел на него и нажми F9.
F9:: {
    if !GetCrosshair(&cx, &cy) {
        ToolTip("Нет активного окна игры", 20, 20)
        SetTimer(() => ToolTip(), -3000)
        return
    }
    c := PixelGetColor(cx, cy)
    ; сразу проверяем, что этот цвет реально находится поиском —
    ; так формат гарантированно совпадёт с ожиданием PixelSearch
    probe := PixelSearch(&px, &py, cx - 6, cy - 6, cx + 6, cy + 6, c, 0)
    global ZombieColor, Calibrated, OnlyZombies, IniFile
    ZombieColor := c
    Calibrated  := true
    OnlyZombies := true
    saved := false
    try {
        IniWrite(c, IniFile, "Zombie", "Color")
        saved := true
    }
    if (saved) {
        ToolTip("Цвет зомби: " c " — сохранён`n"
            . "Поиск: " (probe ? "найден" : "не найден (экран сменился)")
            . "`nСтрельба только по зомби: ВКЛ", 20, 20)
    } else {
        ToolTip("Цвет " c " принят, но записать mc-farm.ini не удалось`n"
            . "На этот раз сработает, до перезапуска — нет", 20, 20)
    }
    SetTimer(() => ToolTip(), -5000)
}
; ---------------------------------------------------

; FIX: при закрытии/перезапуске макроса зажатые клавиши раньше оставались
; нажатыми навсегда (W, Ctrl, ЛКМ). #SingleInstance Force тоже гасит старый
; экземпляр — через OnExit он корректно отпустит всё.
OnExit(ExitCleanup)
ExitCleanup(reason, code) {
    ReleaseAll()
}

; Предупреждение: режим «только зомби» включён, но цвета ещё нет.
; Без калибровки фильтр безопасно отключён — стрельба идёт как раньше.
if (OnlyZombies && !Calibrated) {
    ToolTip("Режим «только зомби» включён, но цвет не откалиброван.`n"
        . "Пока стрельба идёт по всему.`n"
        . "Наведи прицел на зомби и нажми F9.", 20, 20)
    SetTimer(() => ToolTip(), -8000)
}

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

    ; не шлём ввод, пока игра не активна, и отпускаем зажатые клавиши,
    ; иначе W/Ctrl «залипнут» и начнут печататься в другом окне
    if !(WinActive("ahk_exe javaw.exe") || WinActive("ahk_exe java.exe")) {
        if (!released) {
            ReleaseAll()
            released := true
        }
        Sleep(200)
        continue
    }

    if (released) {
        released := false
        if (state = 1 && Sprint && !sprintDown) {
            Send("{Ctrl Down}")
            sprintDown := true
        }
        if (AimDownSights && !adsDown) {
            Send("{RButton Down}")
            adsDown := true
        }
        nextDir  := now
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

; Переключение режима. FIX: переход 1<->2 иначе оставлял клавишу
; движения и спринт зажатыми — они отпускались только внутри MoveTick,
; который в режиме 2 уже не вызывается.
SetState(target) {
    global state, dirKey, sprintDown, Sprint
    old   := state
    state := target

    if (old = 1 && state != 1) {          ; вышли из фарма
        if (dirKey != "") {
            Send("{" dirKey " Up}")
            dirKey := ""
        }
        if (sprintDown) {
            Send("{Ctrl Up}")
            sprintDown := false
        }
    }
    if (state = 1 && old != 1 && Sprint && !sprintDown) {   ; вошли в фарм
        Send("{Ctrl Down}")
        sprintDown := true
    }
    Status()
}

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

; ---------- ОПРЕДЕЛЕНИЕ ЗОМБИ ПОД ПРИЦЕЛОМ ----------
; Центр клиентской области активного окна = прицел.
; FIX: WinGetPos возвращает "" и ломал старый guard `if !WinGetPos(...)`;
; клиентская область (без заголовка и рамок) верна и в окне, и в
; полноэкранном режиме.
GetCrosshair(&cx, &cy) {
    aw := WinExist("A")
    if !aw
        return false
    rc := Buffer(16, 0)
    if !DllCall("GetClientRect", "ptr", aw, "ptr", rc)
        return false
    cw := NumGet(rc, 8, "int")
    ch := NumGet(rc, 12, "int")
    if (cw = 0 || ch = 0)
        return false
    pt := Buffer(8, 0)
    NumPut("int", cw // 2, pt, 0)
    NumPut("int", ch // 2, pt, 4)
    if !DllCall("ClientToScreen", "ptr", aw, "ptr", pt)
        return false
    cx := NumGet(pt, 0, "int")
    cy := NumGet(pt, 4, "int")
    return true
}

; Стрелять? Возвращает false, если в зоне прицела нет цвета зомби.
TargetOk() {
    global OnlyZombies, Calibrated, ZombieColor, ZombieBox, ZombieTolerance
    if (!OnlyZombies)
        return true
    if (!Calibrated)          ; цвет не откалиброван — не рискуем, работаем как раньше
        return true
    if !GetCrosshair(&cx, &cy)
        return true
    return PixelSearch(&px, &py,
                     cx - ZombieBox, cy - ZombieBox,
                     cx + ZombieBox, cy + ZombieBox,
                     ZombieColor, ZombieTolerance)
}
; ---------------------------------------------------

; ------------------- СТРЕЛЬБА ----------------------
FireTick(now) {
    global FireStyle, fireNext, ClickMin, ClickMax, fireDown

    if (!TargetOk()) {
        if (fireDown) {         ; FIX: в режиме hold надо отпустить ЛКМ при потере цели
            Send("{LButton Up}")
            fireDown := false
        }
        return
    }

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
    global state, OnlyZombies, Calibrated
    tag := (OnlyZombies && Calibrated) ? " [только зомби]" : ""
    if (state = 0)
        txt := "Макрос: ВЫКЛ" tag "`nF6 — фарм | F7 — только стрельба | F8 — стоп | F9 — калибровка"
    else if (state = 1)
        txt := "МАКРОС: ФАРМ (бег + обзор + стрельба)" tag "`nF8 — стоп"
    else
        txt := "МАКРОС: ТОЛЬКО СТРЕЛЬБА" tag "`nF8 — стоп"
    ToolTip(txt, 20, 20)
    SetTimer(StatusTipOff, -3000)
}
StatusTipOff() => ToolTip()
; ---------------------------------------------------
