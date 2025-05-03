#Requires AutoHotkey v2.0

global jtc_expecting_vowel := 0
global jtc_last_consonant := ""

; サンプル
; 母音キーのホットキー設定
~a::
~i::
~u::
~e::
~o:: VowelKeyHandler()

; 子音キーのホットキー設定
~b::
~d::
~f::
~g::
~h::
~j::
~k::
~m::
~p::
~r::
~s::
~t::
~v::
~z::
~w:: {
    static msg
    msg := ConsonantKeyHandler()
    if msg {
        MsgBox(msg)
    }
}
/*
;※※推奨設定※※

;以下のライブラリをインクルードしてください
; IMEv2.ahkはIMEの状態を取得するために必要です。

#Include IMEv2.ahk
#Include ToolTipUtility.ahk

;（中略）
~v::
~z::
~w:: {
    static msg
    msg := ConsonantKeyHandler()
    if IME_GET() > 0 && msg {
        ToolTipOnCarret(msg, -2000)
    }
*/

; その他のキーの処理
~l::
~n::
~-:: CancelKeyHandler()

; 母音キーの処理
VowelKeyHandler() {
    global jtc_expecting_vowel
    if jtc_expecting_vowel {
        ; 子音＋母音の組み合わせが正しく入力された
        jtc_expecting_vowel := 0
    }
    ; 子音を期待していない場合は特に処理なし
    return
}
; 子音キーの処理
ConsonantKeyHandler(ErrorText := 0) {
    global jtc_expecting_vowel
    global jtc_last_consonant

    key := A_ThisHotkey
    key := StrReplace(Key, "~", "")

    if jtc_last_consonant = key or key = 'y' {
        return
    } else if jtc_expecting_vowel {
        ; 母音を期待していたのに子音が入力された場合は誤字
        ErrorText := "誤字を検出しました：子音 '" . jtc_last_consonant . "' が母音を期待しているときに入力されました。"
        ; 状態をリセット
        jtc_expecting_vowel := 0
    } else {
        ; 次に母音が来ることを期待する
        jtc_expecting_vowel := 1
        jtc_last_consonant := key
    }
    return ErrorText
}

CancelKeyHandler() {
    global jtc_expecting_vowel
    if jtc_expecting_vowel {
        ; 状態をリセット
        jtc_expecting_vowel := 0
    }
    return
}
