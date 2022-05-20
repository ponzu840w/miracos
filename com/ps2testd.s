; -------------------------------------------------------------------
;                         PS2TESTDコマンド
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
VB_DEV  = 2

; -------------------------------------------------------------------
;                        ゼロページ変数領域
; -------------------------------------------------------------------
.ZEROPAGE
VB_COUNT:       .RES 1        ; 垂直同期をこれで分周した周期でスキャンする
ZP_PS2SCAN_Q_WR_P: .RES 1
ZP_PS2SCAN_Q_RD_P: .RES 1
ZP_PS2SCAN_Q_LEN:  .RES 1

; -------------------------------------------------------------------
;                             変数領域
; -------------------------------------------------------------------
.BSS
VB_STUB:        .RES 2
ZP_PS2SCAN_Q32:    .RES 32

; -------------------------------------------------------------------
;                             実行領域
; -------------------------------------------------------------------
.CODE
  JMP INIT          ; PS2スコープをコードの前で定義したいが、セグメントを増やしたくないためジャンプで横着
                    ; まったくアセンブラの都合で増えた余計なジャンプ命令

.PROC PS2
    .INCLUDE "../ps2/serial_ps2.s"
  .BSS
    .INCLUDE "../ps2/varps2.s"
.ENDPROC

.CODE
INIT:
  ; 初期化
  JSR PS2::INIT
  LDA #VB_DEV
  STA VB_COUNT
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
  DEX                 ; キュー長さデクリメント
  STX ZP_PS2SCAN_Q_LEN   ; キュー長さ更新
  LDX ZP_PS2SCAN_Q_RD_P  ; 読み取りポイント取得
  LDA ZP_PS2SCAN_Q32,X   ; データ読み取り
  INX                 ; 読み取りポイント前進
  CPX #32
  BNE @SKP_RDLOOP
  LDX #0
@SKP_RDLOOP:
  STX ZP_PS2SCAN_Q_RD_P
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

; -------------------------------------------------------------------
;                          垂直同期割り込み
; -------------------------------------------------------------------
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
  ; キューに追加
  LDX ZP_PS2SCAN_Q_WR_P      ; 書き込みポイントを取得（破綻のないことは最後に保証
  STA ZP_PS2SCAN_Q32,X       ; 値を格納
  INX
  CPX #32
  BNE @SKP_WRLOOP
  LDX #0
@SKP_WRLOOP:
  STX ZP_PS2SCAN_Q_WR_P      ; 書き込みポイント更新
  INC ZP_PS2SCAN_Q_LEN       ; バッファ長さを更新
@EXT:
  JMP (VB_STUB)           ; 片付けはBCOSにやらせる

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

