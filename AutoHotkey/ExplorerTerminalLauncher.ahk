#Requires AutoHotkey v2.0
; ExplorerContextLauncher.ahk
; Explorer上の現在フォルダから最適な Shell / VS Code を起動

#HotIf WinActive("ahk_class CabinetWClass")

!+t:: LaunchShellHere()   ; Alt + Shift + T
!+v:: LaunchCodeHere()    ; Alt + Shift + V

#HotIf

; =========================================================
; Explorer
; =========================================================

GetExplorerPath() {
    try hwnd := WinGetID("A")
    catch
        return ""

    shell := ComObject("Shell.Application")
    for win in shell.Windows {
        try if (win.hwnd = hwnd)
            return win.Document.Folder.Self.Path
    }
    return ""
}

; =========================================================
; WSL path detection (\\wsl$\  or  \\wsl.localhost\)
; =========================================================

IsWslPath(path, &distro := "", &linuxPath := "") {
    prefix1 := "\\wsl$\"
    prefix2 := "\\wsl.localhost\"

    if (SubStr(path, 1, StrLen(prefix1)) = prefix1) {
        rest := SubStr(path, StrLen(prefix1) + 1)
    } else if (SubStr(path, 1, StrLen(prefix2)) = prefix2) {
        rest := SubStr(path, StrLen(prefix2) + 1)
    } else {
        return false
    }

    parts := StrSplit(rest, "\")
    if (parts.Length < 2)
        return false

    distro := parts[1]

    linuxPath := ""
    loop parts.Length - 1
        linuxPath .= "/" parts[A_Index + 1]

    return true
}

; =========================================================
; Utility
; =========================================================

FindExeOnPath(exe) {
    tmp := A_Temp "\ahk_where_" A_TickCount ".txt"
    RunWait(A_ComSpec ' /c where ' exe ' > "' tmp '" 2>nul', , "Hide")
    if !FileExist(tmp)
        return ""
    out := Trim(FileRead(tmp, "UTF-8"))
    try FileDelete(tmp)
    catch
        return out ? StrSplit(out, "`n", "`r")[1] : ""
}

GetPowerShellExe() {
    ; PowerShell 7 既定インストール先を最優先
    p7 := "C:\Program Files\PowerShell\7\pwsh.exe"
    if FileExist(p7)
        return QuoteWinArg(p7)

    ; PATH にあればそれを使う（ポータブル等）
    p := FindExeOnPath("pwsh.exe")
    if p
        return "pwsh.exe"

    ; 最後に Windows PowerShell
    return "powershell.exe"
}

QuoteWinArg(s) {
    return '"' StrReplace(s, '"', '""') '"'
}

; =========================================================
; Python venv
; =========================================================

FindVenvActivator(winPath) {
    p := winPath "\venv\Scripts\activate.bat"
    if FileExist(p)
        return p
    p := winPath "\.venv\Scripts\activate.bat"
    if FileExist(p)
        return p
    return ""
}

; =========================================================
; Public Launchers
; =========================================================

LaunchShellHere() {
    path := GetExplorerPath()
    if !path
        return

    if IsWslPath(path, &distro, &linuxPath) {
        OpenWslShell(distro, linuxPath)
        return
    }

    activator := FindVenvActivator(path)
    if activator
        OpenVenvShell(path, activator)
    else
        OpenLocalShell(path)
}

LaunchCodeHere() {
    path := GetExplorerPath()
    if !path
        return

    if IsWslPath(path, &distro, &linuxPath)
        OpenWslVSCode(distro, linuxPath)
    else
        OpenLocalVSCode(path)
}

; =========================================================
; Shell implementations
; =========================================================

OpenLocalShell(path) {
    ps := GetPowerShellExe()
    Run('wt -w 0 new-tab -d ' QuoteWinArg(path) ' --title "PS: ' path '" ' ps ' -NoExit')
}

OpenVenvShell(path, activator) {
    cmdInner := 'cd /d "' path '" && call "' activator '"'
    Run('wt -w 0 new-tab -d ' QuoteWinArg(path)
    ' --title "CMD(venv): ' path '" cmd.exe /k ' QuoteWinArg(cmdInner))
}

OpenWslShell(distro, linuxPath) {
    bashCmd := "cd " linuxPath " && exec bash"
    Run('wt -w 0 new-tab --title "WSL: ' distro '" wsl.exe -d '
        QuoteWinArg(distro) ' -- bash -lc ' QuoteWinArg(bashCmd))
}

; =========================================================
; VS Code
; =========================================================

GetVSCodeExe() {
    p := EnvGet("LocalAppData") "\Programs\Microsoft VS Code\Code.exe"
    if FileExist(p)
        return p

    p2 := EnvGet("LocalAppData") "\Programs\Microsoft VS Code Insiders\Code - Insiders.exe"
    if FileExist(p2)
        return p2

    return FindExeOnPath("code.cmd")
}

OpenLocalVSCode(path) {
    code := GetVSCodeExe()
    if !code {
        MsgBox "VS Code が見つかりませんでした"
        return
    }

    if InStr(code, ".exe")
        Run('"' code '" --new-window "' path '"')
    else
        Run('cmd.exe /c ""' code '" --new-window "' path '""', , "Hide")
}

OpenWslVSCode(distro, linuxPath) {
    code := GetVSCodeExe()
    if !code {
        MsgBox "VS Code が見つかりませんでした"
        return
    }

    uri := "vscode-remote://wsl+" distro linuxPath

    if InStr(code, ".exe")
        Run('"' code '" --new-window --folder-uri "' uri '"')
    else
        Run('cmd.exe /c ""' code '" --new-window --folder-uri "' uri '""', , "Hide")
}
