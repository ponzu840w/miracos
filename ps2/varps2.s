; PS/2キーボードドライバ変数宣言
; コードと徹底分離のこころみ

BYTSAV:   .RES 1  ; 送受信するバイト
PARITY:   .RES 1  ; パリティ保持
SPECIAL:  .RES 1  ; ctrl, shift, capsとkbのLED点灯状況保持
; +-------+-------+-------+-------+-------+-------+-------+-------+
; |   7   |   6   |   5   |   4   |   3   |   2   |   1   |   0   |
; +-------+-------+-------+-------+-------+-------+-------+-------+
; |   -   |   -   |   -   | SHIFT | CTRL  | CAPS  | NUM   |SCROLL |
; +-------+-------+-------+-------+-------+-------+-------+-------+
; |                                       |      L    E    D      |
; +---------------------------------------+-----------------------+
LASTBYT:  .RES 1  ; 受信した最後のバイト
