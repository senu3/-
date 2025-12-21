#Requires AutoHotkey v2.0

;参考
;https://www.autohotkey.com/boards/viewtopic.php?t=40151
;https://www.autohotkey.com/boards/viewtopic.php?t=114804

; _JXON.ahkをインクルード
; Gitからダウンロードして同じディレクトリに置く
#Include _JXON.ahk  ;https://github.com/TheArkive/JXON_ahk2

;サンプル
Pause:: {
    model_name := "llama2" ; モデル名を指定
    prompt := GetTextSelection()

    ToolTip("[" prompt "] とAIに指示しました")
    SetTimer () => ToolTip(), -3000
    response := OllamaAPI(model_name, prompt)
    OllamaGUI(response)
}

OllamaAPI(model_name := "", prompt := "") {
    ; ここにAPIのURLを指定
    APIURL := "http://localhost:11434/api/generate"

    ; payloadをMapオブジェクトで作成
    payload := Map()
    payload["model"] := model_name
    payload["prompt"] := prompt
    payload["stream"] := false

    ; JSONペイロードの作成
    jsonPayload := jxon_dump(payload)

    ; falseがAHKでは0と解釈されるため "stream":0 を "stream":false に置換
    jsonPayload := StrReplace(jsonPayload, '"stream":0', '"stream":false')

    ; WinHttpRequestオブジェクトの作成
    oWhr := ComObject("WinHttp.WinHttpRequest.5.1")
    oWhr.Open("POST", APIURL, false)
    oWhr.SetRequestHeader("Content-Type", "application/json")

    try {
        ; リクエストの送信
        oWhr.Send(jsonPayload)

        ; レスポンスの取得
        statusCode := oWhr.Status

        if (statusCode != 200) {
            MsgBox("APIリクエストが失敗しました。ステータスコード: " statusCode)
            return
        }

        ; レスポンスのJSONを解析
        responseText := oWhr.ResponseText
        responseObj := jxon_load(&responseText)
        generatedText := responseObj["response"]
    } catch {
        MsgBox("レスポンスの解析中にエラーが発生しました。")
        return
    }

    ; 結果の表示
    return generatedText
}

OllamaGUI(response) {
    ; GUI を作成
    MyGui := Gui()
    MyGui.Add("Edit", "R9", "【ＡＩからの回答】`n" response)
    MyGui.Add("Button", "default", "OK").OnEvent("Click", (*) => MyGui.Destroy())
    MyGui.Show()
}

GetTextSelection() {
    result := ""
    ; クリップボードの現在の内容を保存
    ClipSaved := A_Clipboard
    A_Clipboard := ""

    Send "^c"
    if ClipWait(100) {

        A_Clipboard := A_Clipboard ;クリップボードのテキスト化
        result := A_Clipboard

    }
    ; クリップボードを復元
    A_Clipboard := ClipSaved

    ; 結果を返す
    return result
}
