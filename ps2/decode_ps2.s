; -------------------------------------------------------------------
;               PS/2 キーボード スキャンコードデコーダ
; -------------------------------------------------------------------
; 垂直同期スキャンし、
; 1. ASCII列を出力
; 2. キー押下状況をビットマップに保持
; -------------------------------------------------------------------
.INCLUDE "../FXT65.inc"

; -------------------------------------------------------------------
;                              定数
; -------------------------------------------------------------------
VB_DEV  = 1                 ; 垂直同期をこれで分周した周期でスキャンする
_VB_DEV_ENABLE = VB_DEV-1   ; VB_DEVが1だとこれが偽になり、分周コード省略

; -------------------------------------------------------------------
;                          垂直同期割り込み
; -------------------------------------------------------------------
; （場合によっては分周した周期の）垂直同期のタイミングでスキャンし、
; あれば多バイト分処理する
; -------------------------------------------------------------------
VBLANK:
  ; 分周
  .IF _VB_DEV_ENABLE
    DEC VB_COUNT
    BNE @EXT
    LDA #VB_DEV
    STA VB_COUNT
  .ENDIF
  ; スキャン
  JSR PS2::SCAN
  BEQ @EXT                        ; スキャンして0が返ったらデータなし
  ; データが返った
  ; スキャンコードのASCIIデコード
@PROCESSING_SCAN_CODE:
  JSR CHK_SPCODES                 ; 特殊処理
@kbvnvt:
  BEQ @EXT                        ; 0なら無視
  TAX                             ; 処理されたスキャンコードをテーブルインデックスに
  ; NOTE:ここに78,69,7E,02,numpad
@TEST_SHIFT:
  LDA ZP_DECODE_STATE
  BIT #STATE_SHIFT                ; シフトが押されてるか
  BEQ @NOSHIFT
@SHIFT:     ; kbcnvt2
  TXA
  ORA #%10000000
  TAX
@NOSHIFT:   ; kbcnvt3
  LDA ZP_DECODE_STATE
  BIT #STATE_CTRL                 ; コントロールが押されているか
  BEQ @NOCTRL
@CTRL:
  LDA ASCIITBL,X
  CMP #$8F
  ;BEQ REINIT
  AND #$1F
  BRA @EXT
  ;TAX
  BRA @DONE
@NOCTRL:    ; kbcnvt4
  LDA ASCIITBL,X
  BEQ @EXT
  ; NOTE:CAPS処理
@DONE:
  ; Aにアスキーコードが
@EXT:
  RTS                             ; 0以外はトラップされる

; -------------------------------------------------------------------
;                    スキャンコード処理ルーチン群
; -------------------------------------------------------------------
; シフトキー押下
SP_SET_SHIFT:
  LDA #STATE_SHIFT
  .BYT $2C
; コントロールキー押下
SP_SET_CTRL:
  LDA #STATE_CTRL
  ORA ZP_DECODE_STATE
  STA ZP_DECODE_STATE
  BRA SP_NULL

; 再送要求をくらった
SP_RESEND:
  LDA LASTBYT
  JSR SEND
  ;BRA SP_NULL          ; NULLまでの間のコードを省いたので直通

; なにもしない
SP_NULL:
  LDA #0
  RTS

; E0拡張
SP_E0EXT:
  JSR GET         ; 次のコードを取得する
  CMP #$F0        ; 拡張リリースか？
  BEQ @RLS        ; 拡張リリース
  CMP #$14        ; 右CTRL
  BEQ SP_SET_CTRL
  ; NOTE:ここに4つの置換コード
  CMP #$03
; E0リリース
@RLS:
  CMP #$12            ; E0F012
  BNE SP_RLS_CHKCTRL  ; でなければふつうのリリース
  BRA SP_NULL

; リリース
SP_RLS:
  JSR GET
  CMP #$12      ; 左シフト
  BEQ SP_RLS_SHIFT
  CMP #$59      ; 右シフト
  BEQ SP_RLS_SHIFT
SP_RLS_CHKCTRL:
  CMP #$14      ; CTRL
  BEQ SP_RLS_CTRL
  CMP #$11      ; ALT
  BNE SP_NULL   ; シフト、コントロール、オルト以外のリリースは無視
                ; では困るのだが
@ALT:
  LDA #$13      ; ALTリリースで13を返す真意はわからない
  RTS
SP_RLS_CTRL:
  LDA #<~STATE_CTRL
  .BYT $2C
SP_RLS_SHIFT:
  LDA #<~STATE_SHIFT
  AND ZP_DECODE_STATE
  STA ZP_DECODE_STATE
  BRA SP_NULL

; ブレイク
SP_BRK:
  LDX #$07
@LOOP:
  JSR GET
  DEX
  BNE @LOOP
  LDA #$10
  RTS

CHK_SPCODES: ; kbcsrch            ; 14種類の特殊コードがあればベクタテーブルで処理する
  LDX #(SP_VECLST-SP_LST-1)         ; ループ回数
@LOOP_CHK:
  CMP SP_LST,X                    ; チェック対象リストに対照
  BEQ @JUMP                       ; マッチしたらベクタに跳ぶ
  DEX
  BPL @LOOP_CHK
  RTS                             ; マッチしない
@JUMP:
  TXA                             ; マッチしたインデックスをAに
  ASL                             ; 16bit幅ベクタに適合するようにx2
  TAX                             ; Xに
  LDA BYTSAV                      ; 元のスキャンコードをAに復帰
  JMP (SP_VECLST,X)               ; 各ベクタにジャンプ

SP_LST:
.BYT $12               ; Lshift
.BYT $59               ; Rshift
.BYT $14               ; ctrl
.BYT $E1               ; Extended pause break 
;
.BYT $E0               ; Extended key handler
.BYT $F0               ; Release 1 BYT key code
.BYT $FA               ; Ack
.BYT $AA               ; POST passed
;
.BYT $EE               ; Echo
.BYT $FE               ; resend
.BYT $FF               ; overflow/error
.BYT $00               ; underflow/error
;
; command/scancode jump table
; 
SP_VECLST:
.WORD SP_SET_SHIFT      ; Lshift
.WORD SP_SET_SHIFT      ; Rshift
.WORD SP_SET_CTRL       ; ctrl
.WORD SP_BRK            ; Extended pause break
;
.WORD SP_E0EXT          ; Extended key handler
.WORD SP_RLS            ; Release 1 BYT key code
.WORD SP_NULL           ; Ack
.WORD SP_NULL           ; POST passed
;
.WORD SP_NULL           ; Echo
.WORD SP_RESEND         ; resend
.WORD FLUSH             ; overflow/error
.WORD FLUSH             ; underflow/error

;*************************************************************
;
; Unshifted table for scancodes to ascii conversion
;                                      Scan|Keyboard
;                                      Code|Key
;                                      ----|----------
ASCIITBL:      .byte $00               ; 00 no key pressed
               .byte $89               ; 01 F9
               .byte $87               ; 02 relocated F7
               .byte $85               ; 03 F5
               .byte $83               ; 04 F3
               .byte $81               ; 05 F1
               .byte $82               ; 06 F2
               .byte $8C               ; 07 F12
               .byte $00               ; 08 
               .byte $8A               ; 09 F10
               .byte $88               ; 0A F8
               .byte $86               ; 0B F6
               .byte $84               ; 0C F4
               .byte $09               ; 0D tab
               .byte $60               ; 0E `~
               .byte $8F               ; 0F relocated Print Screen key
               .byte $03               ; 10 relocated Pause/Break key
               .byte $A0               ; 11 left alt (right alt too)
               .byte $00               ; 12 left shift
               .byte $E0               ; 13 relocated Alt release code
               .byte $00               ; 14 left ctrl (right ctrl too)
               .byte $71               ; 15 qQ
               .byte $31               ; 16 1!
               .byte $00               ; 17 
               .byte $00               ; 18 
               .byte $00               ; 19 
               .byte $7A               ; 1A zZ
               .byte $73               ; 1B sS
               .byte $61               ; 1C aA
               .byte $77               ; 1D wW
               .byte $32               ; 1E 2@
               .byte $A1               ; 1F Windows 98 menu key (left side)
               .byte $02               ; 20 relocated ctrl-break key
               .byte $63               ; 21 cC
               .byte $78               ; 22 xX
               .byte $64               ; 23 dD
               .byte $65               ; 24 eE
               .byte $34               ; 25 4$
               .byte $33               ; 26 3#
               .byte $A2               ; 27 Windows 98 menu key (right side)
               .byte $00               ; 28
               .byte $20               ; 29 space
               .byte $76               ; 2A vV
               .byte $66               ; 2B fF
               .byte $74               ; 2C tT
               .byte $72               ; 2D rR
               .byte $35               ; 2E 5%
               .byte $A3               ; 2F Windows 98 option key (right click, right side)
               .byte $00               ; 30
               .byte $6E               ; 31 nN
               .byte $62               ; 32 bB
               .byte $68               ; 33 hH
               .byte $67               ; 34 gG
               .byte $79               ; 35 yY
               .byte $36               ; 36 6^
               .byte $00               ; 37
               .byte $00               ; 38
               .byte $00               ; 39
               .byte $6D               ; 3A mM
               .byte $6A               ; 3B jJ
               .byte $75               ; 3C uU
               .byte $37               ; 3D 7&
               .byte $38               ; 3E 8*
               .byte $00               ; 3F
               .byte $00               ; 40
               .byte ','               ; 41 ,<
               .byte $6B               ; 42 kK
               .byte $69               ; 43 iI
               .byte $6F               ; 44 oO
               .byte $30               ; 45 0)
               .byte $39               ; 46 9(
               .byte $00               ; 47
               .byte $00               ; 48
               .byte '.'               ; 49 .>
               .byte $2F               ; 4A /?
               .byte $6C               ; 4B lL
               .byte ';'               ; 4C ;+
               .byte $70               ; 4D pP
               .byte '-'               ; 4E -=
               .byte $00               ; 4F
               .byte $00               ; 50
               .byte '\'               ; 51 \_
               .byte ':'               ; 52 :*
               .byte $00               ; 53
               .byte '@'               ; 54 @`
               .byte '^'               ; 55 ^~
               .byte $00               ; 56
               .byte $00               ; 57
               .byte $00               ; 58 caps
               .byte $00               ; 59 r shift
               .byte $0A               ; 5A <Enter>
               .byte '['               ; 5B [{
               .byte $00               ; 5C
               .byte ']'               ; 5D ]}
               .byte $00               ; 5E
               .byte $00               ; 5F
               .byte $00               ; 60
               .byte $00               ; 61
               .byte $00               ; 62
               .byte $00               ; 63
               .byte $00               ; 64
               .byte $00               ; 65
               .byte $08               ; 66 bkspace
               .byte $00               ; 67
               .byte $00               ; 68
               .byte $31               ; 69 kp 1
               .byte '\'               ; 6A \|
               .byte $34               ; 6B kp 4
               .byte $37               ; 6C kp 7
               .byte $00               ; 6D
               .byte $00               ; 6E
               .byte $00               ; 6F
               .byte $30               ; 70 kp 0
               .byte $2E               ; 71 kp .
               .byte $32               ; 72 kp 2
               .byte $35               ; 73 kp 5
               .byte $36               ; 74 kp 6
               .byte $38               ; 75 kp 8
               .byte $1B               ; 76 esc
               .byte $00               ; 77 num lock
               .byte $8B               ; 78 F11
               .byte $2B               ; 79 kp +
               .byte $33               ; 7A kp 3
               .byte $2D               ; 7B kp -
               .byte $2A               ; 7C kp *
               .byte $39               ; 7D kp 9
               .byte $8D               ; 7E scroll lock
               .byte $00               ; 7F 
;
; Table for shifted scancodes 
;        
               .byte $00               ; 80 
               .byte $C9               ; 81 F9
               .byte $C7               ; 82 relocated F7 
               .byte $C5               ; 83 F5 (F7 actual scancode=83)
               .byte $C3               ; 84 F3
               .byte $C1               ; 85 F1
               .byte $C2               ; 86 F2
               .byte $CC               ; 87 F12
               .byte $00               ; 88 
               .byte $CA               ; 89 F10
               .byte $C8               ; 8A F8
               .byte $C6               ; 8B F6
               .byte $C4               ; 8C F4
               .byte $09               ; 8D tab
               .byte $7E               ; 8E `~
               .byte $CF               ; 8F relocated Print Screen key
               .byte $03               ; 90 relocated Pause/Break key
               .byte $A0               ; 91 left alt (right alt)
               .byte $00               ; 92 left shift
               .byte $E0               ; 93 relocated Alt release code
               .byte $00               ; 94 left ctrl (and right ctrl)
               .byte $51               ; 95 qQ
               .byte $21               ; 96 1!
               .byte $00               ; 97 
               .byte $00               ; 98 
               .byte $00               ; 99 
               .byte $5A               ; 9A zZ
               .byte $53               ; 9B sS
               .byte $41               ; 9C aA
               .byte $57               ; 9D wW
               .byte '"'               ; 9E 2'"'
               .byte $E1               ; 9F Windows 98 menu key (left side)
               .byte $02               ; A0 relocated ctrl-break key
               .byte $43               ; A1 cC
               .byte $58               ; A2 xX
               .byte $44               ; A3 dD
               .byte $45               ; A4 eE
               .byte $24               ; A5 4$
               .byte $23               ; A6 3#
               .byte $E2               ; A7 Windows 98 menu key (right side)
               .byte $00               ; A8
               .byte $20               ; A9 space
               .byte $56               ; AA vV
               .byte $46               ; AB fF
               .byte $54               ; AC tT
               .byte $52               ; AD rR
               .byte $25               ; AE 5%
               .byte $E3               ; AF Windows 98 option key (right click, right side)
               .byte $00               ; B0
               .byte $4E               ; B1 nN
               .byte $42               ; B2 bB
               .byte $48               ; B3 hH
               .byte $47               ; B4 gG
               .byte $59               ; B5 yY
               .byte '&'               ; B6 6&
               .byte $00               ; B7
               .byte $00               ; B8
               .byte $00               ; B9
               .byte $4D               ; BA mM
               .byte $4A               ; BB jJ
               .byte $55               ; BC uU
               .byte '''               ; BD 7'
               .byte '('               ; BE 8(
               .byte $00               ; BF
               .byte $00               ; C0
               .byte $3C               ; C1 ,<
               .byte $4B               ; C2 kK
               .byte $49               ; C3 iI
               .byte $4F               ; C4 oO
               .byte $00               ; C5 0
               .byte ')'               ; C6 9)
               .byte $00               ; C7
               .byte $00               ; C8
               .byte $3E               ; C9 .>
               .byte $3F               ; CA /?
               .byte $4C               ; CB lL
               .byte '+'               ; CC ;+
               .byte $50               ; CD pP
               .byte '='               ; CE -=
               .byte $00               ; CF
               .byte $00               ; D0
               .byte '_'               ; D1 \_
               .byte '*'               ; D2 :*
               .byte $00               ; D3
               .byte '`'               ; D4 @`
               .byte '~'               ; D5 ^~
               .byte $00               ; D6
               .byte $00               ; D7
               .byte $00               ; D8 caps
               .byte $00               ; D9 r shift
               .byte $0A               ; DA <Enter>
               .byte '{'               ; DB [{
               .byte $00               ; DC
               .byte '}'               ; DD ]}
               .byte $00               ; DE
               .byte $00               ; DF
               .byte $00               ; E0
               .byte $00               ; E1
               .byte $00               ; E2
               .byte $00               ; E3
               .byte $00               ; E4
               .byte $00               ; E5
               .byte $08               ; E6 bkspace
               .byte $00               ; E7
               .byte $00               ; E8
               .byte $91               ; E9 kp 1
               .byte '|'               ; EA \|
               .byte $94               ; EB kp 4
               .byte $97               ; EC kp 7
               .byte $00               ; ED
               .byte $00               ; EE
               .byte $00               ; EF
               .byte $90               ; F0 kp 0
               .byte $7F               ; F1 kp .
               .byte $92               ; F2 kp 2
               .byte $95               ; F3 kp 5
               .byte $96               ; F4 kp 6
               .byte $98               ; F5 kp 8
               .byte $1B               ; F6 esc
               .byte $00               ; F7 num lock
               .byte $CB               ; F8 F11
               .byte $2B               ; F9 kp +
               .byte $93               ; FA kp 3
               .byte $2D               ; FB kp -
               .byte $2A               ; FC kp *
               .byte $99               ; FD kp 9
               .byte $CD               ; FE scroll lock
; NOT USED     .byte $00               ; FF 
; end

