#Requires AutoHotkey v2.0

#HotIf WinActive("ahk_class CabinetWClass") ; エクスプローラーがアクティブな場合

!+c:: CurrentCMD()  ; Alt + Shift + C をホットキーに設定
!+v:: CurrentVSCode() ; Alt + Shift + V をホットキーに設定

CurrentCMD() {
    hwnd := WinGetID("A")
    shellApp := ComObject("Shell.Application")

    for window in shellApp.Windows {
        if (window.hwnd == hwnd) {
            path := window.Document.Folder.Self.Path
            break
        }
    }

    if (path) {
        ; コマンドプロンプトを開くコマンドを初期化
        cmdCommand := 'cmd.exe /k cd /d "' path '"'

        ; 'venv' または '.venv' が存在するか確認
        if (FileExist(path "\venv\Scripts\activate.bat")) {
            ; 仮想環境を起動するコマンドに変更
            cmdCommand := 'cmd.exe /k "cd /d "' path '" & call venv\Scripts\activate.bat"'
        }
        else if (FileExist(path "\.venv\Scripts\activate.bat")) {
            cmdCommand := 'cmd.exe /k "cd /d "' path '" & call .venv\Scripts\activate.bat"'
        }

        ; コマンドを実行
        Run(cmdCommand)
    }
}

CurrentVSCode() {
    hwnd := WinGetID("A")
    shellApp := ComObject("Shell.Application")

    for window in shellApp.Windows {
        if (window.hwnd == hwnd) {
            path := window.Document.Folder.Self.Path
            break
        }
    }

    if (path) {
        loop files, path '\*.code-workspace' {
            ; .code-workspaceファイルを実行
            Run(A_LoopFileFullPath)
            break
        } else {
            ; cmd.exe を介して code コマンドを実行し、コマンドプロンプトを非表示にしてすぐに閉じる
            Run('cmd.exe /c code "' path '"', , "Hide")
        }
    }
}

#HotIf