; -------------------------------------------------------------------
; T_KB_SER
; -------------------------------------------------------------------
; PS2KBのシリアル通信レベルのテストプログラム
; -------------------------------------------------------------------
.INCLUDE "../FXT65.inc"
.INCLUDE "../generic.mac"
.INCLUDE "../fs/structfs.s"
.INCLUDE "../fscons.inc"
.PROC BCOS
  .INCLUDE "../syscall.inc"  ; システムコール番号
.ENDPROC
.INCLUDE "../syscall.mac"

; 定数
VB_DEV  = 2

; ゼロページ変数
.ZEROPAGE
VB_COUNT:       .RES 1        ; 垂直同期をこれで分周した周期でスキャンする

; 変数
.BSS
STACK:          .RES 16
STACK_PTR:      .RES 1
VB_STUB:        .RES 2

.CODE
  JMP INIT          ; PS2スコープをコードの前で定義したいが、セグメントを増やしたくないためジャンプで横着
                    ; まったくアセンブラの都合で増えた余計なジャンプ命令

.PROC PS2
  .ZEROPAGE
    .INCLUDE "../ps2/zpps2.s"
  .CODE
    .INCLUDE "../ps2/serial_ps2.s"
  .BSS
    .INCLUDE "../ps2/varps2.s"
.ENDPROC

.CODE
INIT:
  ; 初期化
  JSR PS2::INIT
  STZ STACK_PTR
  STZ VB_COUNT
  ; 割り込みハンドラの登録
  SEI
  loadAY16 VBLANK
  syscall IRQ_SETHNDR_VB
  storeAY16 VB_STUB
  CLI

; メインループ
LOOP:
  LDA #1          ; 待ちなしエコーなし
  syscall CON_RAWIN
  CMP #'q'
  BEQ EXIT        ; UART入力があれば終わる
  LDX STACK_PTR
  BEQ LOOP        ; スタックが空ならやることなし
  ; 排他的スタック操作
  SEI
  LDA STACK-1,X
  DEC STACK_PTR
  CLI
@GET:
  JSR PRT_BYT     ; バイト表示
  ;JSR PRT_LF      ; 改行
  BRA LOOP

EXIT:
  ; 割り込みハンドラの登録抹消
  SEI
  mem2AY16 VB_STUB
  syscall IRQ_SETHNDR_VB
  CLI
  RTS

; 垂直同期割り込み処理
VBLANK:
  ; 分周
  DEC VB_COUNT
  BNE @EXT
  LDA #VB_DEV
  STA VB_COUNT
  ; スキャン
  JSR PS2::SCAN
  BEQ @EXT                ; スキャンして0が返ったらデータなし
  ; データが返った
  ; スタックに積む
  LDX STACK_PTR
  STA STACK,X
  INC STACK_PTR
@EXT:
  JMP (VB_STUB)           ; 片付けはBCOSにやらせる

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

