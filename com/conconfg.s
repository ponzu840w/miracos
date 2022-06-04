; -------------------------------------------------------------------
;                          CONCONFGコマンド
; -------------------------------------------------------------------
; コンソールを構成するデバイスの有効無効を設定するツール
; コマンドライン引数に従ってコンソールデバイスの設定をする
; コマンドライン引数のありなしにかかわらず変更後の設定を表示する
; [コマンドライン引数の構文]
; A:>CONCONFG 0=1 2=0
;           : <コンソールデバイス番号>=<0(OFF)or1(on)>
;           : 複数の設定を同時に処理可能
; -------------------------------------------------------------------
.INCLUDE "../FXT65.inc"
.INCLUDE "../generic.mac"
.INCLUDE "../fs/structfs.s"
.INCLUDE "../fscons.inc"
.INCLUDE "../zr.inc"
.PROC BCOS
  .INCLUDE "../syscall.inc"  ; システムコール番号
.ENDPROC
.INCLUDE "../syscall.mac"

; -------------------------------------------------------------------
;                             定数宣言
; -------------------------------------------------------------------
.PROC CONDEV
  ; ZP_CON_DEV_CFGでのコンソールデバイス
  UART_IN   = %00000001
  UART_OUT  = %00000010
  PS2       = %00000100
  GCON      = %00001000
.ENDPROC

; -------------------------------------------------------------------
;                            ZP変数領域
; -------------------------------------------------------------------
.ZEROPAGE
ZP_CONCFG_ADDR16:         .RES 2  ; 取得した設定値のアドレス
ZP_SHIFT:                 .RES 1  ; 設定値をシフトしてビット処理
ZP_ARG:                   .RES 2  ; コマンドライン引数
ZP_DEVNUM:                .RES 1  ; 処理すべきかもしれないコマンド番号

; -------------------------------------------------------------------
;                             実行領域
; -------------------------------------------------------------------
.CODE
  storeAY16 ZP_ARG
  ; 設定メモリのアドレスを取得
  LDY #BCOS::BHY_GET_ADDR_condevcfg   ; コンソールデバイス設定のアドレスを要求
  syscall GET_ADDR                    ; アドレス要求
  storeAY16 ZP_CONCFG_ADDR16          ; アドレス保存
  ; コマンドライン引数を処理
  LDY #0
LOOP:
  INY
  BEQ @END_CHANGE
  LDA (ZP_ARG),Y
  BEQ @END_CHANGE
  CMP #'='
  BNE LOOP
  ; Y='='
  DEY
  LDA (ZP_ARG),Y      ; 左辺を取得
  STA ZP_DEVNUM
  INY
  INY
  LDA (ZP_ARG),Y      ; 右辺を取得
  CMP #'0'
  BEQ OFF
  CMP #'1'
  BEQ ON
  BRA LOOP
@END_CHANGE:
  ; 設定の表示
  ; 設定の取得
  LDA (ZP_CONCFG_ADDR16)
  STA ZP_SHIFT
  ; 0 UART_IN
  loadAY16 STR_UART_IN
  JSR OUT_TAG_ON_OFF
  ; 1 UART_OUT
  loadAY16 STR_UART_OUT
  JSR OUT_TAG_ON_OFF
  ; 2 PS2
  loadAY16 STR_PS2
  JSR OUT_TAG_ON_OFF
  ; 3 GCON
  loadAY16 STR_GCON
  JSR OUT_TAG_ON_OFF
  RTS

ON:
  LDA ZP_DEVNUM
  SEC
  SBC #'0'
  CMP #8          ; num-8
  BCS LOOP        ; 8以上では困る
  TAX
  LDA ONEHOT,X
  ORA (ZP_CONCFG_ADDR16)
  STA (ZP_CONCFG_ADDR16)
  BRA LOOP

OFF:
  LDA ZP_DEVNUM
  SEC
  SBC #'0'
  CMP #8          ; num-8
  BCS LOOP        ; 8以上では困る
  TAX
  LDA ONEHOT,X
  EOR #$FF
  AND (ZP_CONCFG_ADDR16)
  STA (ZP_CONCFG_ADDR16)
  BRA LOOP

ONEHOT:
  .BYT %00000001
  .BYT %00000010
  .BYT %00000100
  .BYT %00001000
  .BYT %00010000
  .BYT %00100000
  .BYT %01000000
  .BYT %10000000

OUT_TAG_ON_OFF:
  syscall CON_OUT_STR
  LSR ZP_SHIFT
  BCC @OFF
@ON:
  loadAY16 STR_ON
  syscall CON_OUT_STR
  RTS
@OFF:
  loadAY16 STR_OFF
  syscall CON_OUT_STR
  RTS

STR_UART_IN:    .BYT  "0)UART-Input    : ",0
STR_UART_OUT:   .BYT  "1)UART-Output   : ",0
STR_PS2:        .BYT  "2)PS/2-Keyboard : ",0
STR_GCON:       .BYT  "3)GCON-Monitor  : ",0
STR_ON:         .BYT  "ON",$A,0
STR_OFF:        .BYT  "OFF",$A,0

