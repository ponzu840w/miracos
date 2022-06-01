; -------------------------------------------------------------------
;                         T_KB_DECコマンド
; -------------------------------------------------------------------
; PS2のデコードを試すテストプログラム
; -------------------------------------------------------------------
.INCLUDE "../FXT65.inc"
.INCLUDE "../generic.mac"
.INCLUDE "../fs/structfs.s"
.INCLUDE "../fscons.inc"
.PROC BCOS
  .INCLUDE "../syscall.inc"  ; システムコール番号
.ENDPROC
.INCLUDE "../syscall.mac"

; -------------------------------------------------------------------
;                              定数
; -------------------------------------------------------------------
VB_DEV  = 2        ; 垂直同期をこれで分周した周期でスキャンする
_VB_DEV_ENABLE = VB_DEV-1

; -------------------------------------------------------------------
;                        ゼロページ変数領域
; -------------------------------------------------------------------
.ZEROPAGE
.IF _VB_DEV_ENABLE
  VB_COUNT:           .RES 1
.ENDIF
ZP_PS2SCAN_Q_WR_P:  .RES 1
ZP_PS2SCAN_Q_RD_P:  .RES 1
ZP_PS2SCAN_Q_LEN:   .RES 1
ZP_DECODE_STATE:    .RES 1        ; SPECIALと共用できないか検討
; +-------+-------+-------+-------+-------+-------+-------+-------+
; |   7   |   6   |   5   |   4   |   3   |   2   |   1   |   0   |
; +-------+-------+-------+-------+-------+-------+-------+-------+
; |   -   |   -   |  BRK  | SHIFT | CTRL  | CAPS  | NUM   |SCROLL |
; +-------+-------+-------+-------+-------+-------+-------+-------+
; |                                       |      L    E    D      |
; +---------------------------------------+-----------------------+
  STATE_BRK           = %00100000

; -------------------------------------------------------------------
;                             変数領域
; -------------------------------------------------------------------
.BSS
VB_STUB:          .RES 2
PS2SCAN_Q32:      .RES 32

; -------------------------------------------------------------------
;                             実行領域
; -------------------------------------------------------------------
.CODE
  JMP INIT          ; PS2スコープをコードの前で定義したいが、セグメントを増やしたくないためジャンプで横着
                    ; まったくアセンブラの都合で増えた余計なジャンプ命令

.PROC PS2
  .ZEROPAGE
    .INCLUDE "../ps2/zpps2.s"
  .BSS
    .INCLUDE "../ps2/varps2.s"
  .CODE
    .INCLUDE "../ps2/serial_ps2.s"
.ENDPROC

.CODE
INIT:
  ; 初期化
  JSR PS2::INIT
  .IF _VB_DEV_ENABLE
    LDA #VB_DEV
    STA VB_COUNT
  .ENDIF
  STZ ZP_PS2SCAN_Q_WR_P
  STZ ZP_PS2SCAN_Q_RD_P
  STZ ZP_PS2SCAN_Q_LEN
  ; 割り込みハンドラの登録
  SEI
  loadAY16 VBLANK
  syscall IRQ_SETHNDR_VB
  storeAY16 VB_STUB
  CLI

; メインループ
LOOP:
  LDA #1            ; 待ちなしエコーなし
  syscall CON_RAWIN
  CMP #'q'
  BEQ EXIT          ; UART入力があれば終わる
  LDX ZP_PS2SCAN_Q_LEN ; キュー長さ
  BEQ LOOP          ; キューが空ならやることなし
  ; 排他的キュー操作
  SEI
  DEX                    ; キュー長さデクリメント
  STX ZP_PS2SCAN_Q_LEN   ; キュー長さ更新
  LDX ZP_PS2SCAN_Q_RD_P  ; 読み取りポイント取得
  LDA PS2SCAN_Q32,X   ; データ読み取り
  INX                    ; 読み取りポイント前進
  CPX #32
  BNE @SKP_RDLOOP
  LDX #0
@SKP_RDLOOP:
  STX ZP_PS2SCAN_Q_RD_P
  CLI
@GET:
  JSR DECODE
  BEQ LOOP
  JSR PRT_C_CALL   ; バイト表示
  ;JSR PRT_LF      ; 改行
  BRA LOOP

EXIT:
  ; 割り込みハンドラの登録抹消
  SEI
  mem2AY16 VB_STUB
  syscall IRQ_SETHNDR_VB
  CLI
  RTS

; スキャンコードを順に受け取る
DECODE:
  ; ブレイクコード状態をチェック
  BBR5 ZP_DECODE_STATE,@PLAIN     ; ブレイク状態ビットが立っていなかったら普通
  ; ブレイクコード
@BREAK:
  RMB5 ZP_DECODE_STATE
  LDA #0
  BRA @EXT
  ; 曇りなき目
@PLAIN:
  CMP #$F0
  BNE @SKP_SETBREAK
  SMB5 ZP_DECODE_STATE            ; ブレイク状態ビットセット
  BRA @EXT
@SKP_SETBREAK:
  ; $F0ではない
  TAX
  LDA ASCIITBL,X                  ; ASCII変換
@EXT:
  RTS

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
               .byte $2C               ; 41 ,<
               .byte $6B               ; 42 kK
               .byte $69               ; 43 iI
               .byte $6F               ; 44 oO
               .byte $30               ; 45 0)
               .byte $39               ; 46 9(
               .byte $00               ; 47
               .byte $00               ; 48
               .byte $2E               ; 49 .>
               .byte $2F               ; 4A /?
               .byte $6C               ; 4B lL
               .byte $3B               ; 4C ;:
               .byte $70               ; 4D pP
               .byte $2D               ; 4E -_
               .byte $00               ; 4F
               .byte $00               ; 50
               .byte $00               ; 51
               .byte $27               ; 52 '"
               .byte $00               ; 53
               .byte $5B               ; 54 [{
               .byte $3D               ; 55 =+
               .byte $00               ; 56
               .byte $00               ; 57
               .byte $00               ; 58 caps
               .byte $00               ; 59 r shift
               .byte $0A               ; 5A <Enter>
               .byte $5D               ; 5B ]}
               .byte $00               ; 5C
               .byte $5C               ; 5D \|
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
               .byte $2f               ; 6A kp / converted from E04A in code
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
               .byte $40               ; 9E 2@
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
               .byte $5E               ; B6 6^
               .byte $00               ; B7
               .byte $00               ; B8
               .byte $00               ; B9
               .byte $4D               ; BA mM
               .byte $4A               ; BB jJ
               .byte $55               ; BC uU
               .byte $26               ; BD 7&
               .byte $2A               ; BE 8*
               .byte $00               ; BF
               .byte $00               ; C0
               .byte $3C               ; C1 ,<
               .byte $4B               ; C2 kK
               .byte $49               ; C3 iI
               .byte $4F               ; C4 oO
               .byte $29               ; C5 0)
               .byte $28               ; C6 9(
               .byte $00               ; C7
               .byte $00               ; C8
               .byte $3E               ; C9 .>
               .byte $3F               ; CA /?
               .byte $4C               ; CB lL
               .byte $3A               ; CC ;:
               .byte $50               ; CD pP
               .byte $5F               ; CE -_
               .byte $00               ; CF
               .byte $00               ; D0
               .byte $00               ; D1
               .byte $22               ; D2 '"
               .byte $00               ; D3
               .byte $7B               ; D4 [{
               .byte $2B               ; D5 =+
               .byte $00               ; D6
               .byte $00               ; D7
               .byte $00               ; D8 caps
               .byte $00               ; D9 r shift
               .byte $0D               ; DA <Enter>
               .byte $7D               ; DB ]}
               .byte $00               ; DC
               .byte $7C               ; DD \|
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
               .byte $2f               ; EA kp / converted from E04A in code
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

; -------------------------------------------------------------------
;                          垂直同期割り込み
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
  BEQ @EXT                    ; スキャンして0が返ったらデータなし
  ; データが返った
  ; キューに追加
  LDX ZP_PS2SCAN_Q_WR_P       ; 書き込みポイントを取得（破綻のないことは最後に保証
  STA PS2SCAN_Q32,X           ; 値を格納
  INX
  CPX #32
  BNE @SKP_WRLOOP
  LDX #0
@SKP_WRLOOP:
  STX ZP_PS2SCAN_Q_WR_P       ; 書き込みポイント更新
  INC ZP_PS2SCAN_Q_LEN        ; バッファ長さを更新
@EXT:
  JMP (VB_STUB)               ; 片付けはBCOSにやらせる

; -------------------------------------------------------------------
;                           汎用ルーチン
; -------------------------------------------------------------------
PRT_BYT:
  JSR BYT2ASC
  PHY
  JSR PRT_C_CALL
  PLA
PRT_C_CALL:
  syscall CON_OUT_CHR
  RTS

PRT_LF:
  ; 改行
  LDA #$A
  JMP PRT_C_CALL

PRT_S:
  ; スペース
  LDA #' '
  JMP PRT_C_CALL

BYT2ASC:
  ; Aで与えられたバイト値をASCII値AYにする
  ; Aから先に表示すると良い
  PHA           ; 下位のために保存
  AND #$0F
  JSR NIB2ASC
  TAY
  PLA
  LSR           ; 右シフトx4で上位を下位に持ってくる
  LSR
  LSR
  LSR
  JSR NIB2ASC
  RTS

NIB2ASC:
  ; #$0?をアスキー一文字にする
  ORA #$30
  CMP #$3A
  BCC @SKP_ADC  ; Aが$3Aより小さいか等しければ分岐
  ADC #$06
@SKP_ADC:
  RTS

