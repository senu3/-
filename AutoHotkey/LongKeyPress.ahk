#Requires AutoHotkey v2.0

; 例: Numpad1を短押しすると "1"、長押しすると "0" を送信する
Numpad1:: LongKeyPress('1', '0')

LongKeyPress(shortOutput, longOutput, threshold := 150) {
    local state := { processed: false }  ; 長押し処理が既に実行されたかのフラグ（オブジェクトは参照渡し）
    ; タイマー用の関数をバインド（長押し時の出力、状態を引数として渡す）
    timerFunc := CheckKeyPress.Bind(A_ThisHotkey, longOutput, state)
    SetTimer(timerFunc, threshold)   ; threshold時間後にタイマーコールバックが実行される
    KeyWait(A_ThisHotkey)                  ; キーが離されるまで待機
    SetTimer(timerFunc, 0)       ; キー離し後、タイマーを解除
    if (!state.processed) {
        Send '{' shortOutput "}"
    }
}

; タイマーのコールバック関数: キーが押されたままであれば長押しとして処理する
CheckKeyPress(key, longOutput, state) {
    if (!state.processed && GetKeyState(key, "P")) {
        Send '{' longOutput "}"
        state.processed := true
    }
}
