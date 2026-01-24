; -------------------------------------------------------------------
;                            PAINT.COM
; -------------------------------------------------------------------
; お絵描きツール
; -------------------------------------------------------------------
.INCLUDE "../FXT65.inc"
.INCLUDE "../generic.mac"
.INCLUDE "../zr.inc"
.PROC BCOS
  .INCLUDE "../syscall.inc"  ; システムコール番号
.ENDPROC
.INCLUDE "../syscall.mac"

; -------------------------------------------------------------------
;                               定数
; -------------------------------------------------------------------
CURSOR_SPEED = 1      ; カーソル速度
TOP_MARGIN = 8*3      ; 上部のマージン
RL_MARGIN = 4         ; 左右のマージン
COL_CORSOR_BG = $FF
COL_CORSOR_FG = $00

; -------------------------------------------------------------------
;                               ZP領域
; -------------------------------------------------------------------
.ZEROPAGE
  ZP_CURSOR_X:      .RES 1
  ZP_CURSOR_Y:      .RES 1
  ZP_CURSOR_DX:     .RES 1
  ZP_CURSOR_DY:     .RES 1
  ZP_PADSTAT:       .RES 2        ; ゲームパッドの状態が収まる
  ZP_PADSTAT_PREV:  .RES 2        ; ゲームパッドの状態が収まる
  ZP_SHIFTER:       .RES 1        ; ゲームパッド読み取り処理用
  ZP_VB_STUB:       .RES 2        ; 割り込み終了処理
  ZP_DISP_FRAME:    .RES 1        ; 表示中のフレームバッファ
  HOGE:             .RES 1        ; デバッグ用

; -------------------------------------------------------------------
;                             実行領域
; -------------------------------------------------------------------
.CODE

; -------------------------------------------------------------------
;                          カーソルティック
; -------------------------------------------------------------------
.macro tick_cursor
  ; プレイヤ移動
  erase_cursor
  ; X
  LDA ZP_CURSOR_X
  CLC
  ADC ZP_CURSOR_DX
  PHA
  SEC
  SBC #RL_MARGIN
  CMP #256-(RL_MARGIN*2)-4
  PLA
  BCS @SKP_NEW_X
  STA ZP_CURSOR_X
@SKP_NEW_X:
  ; Y
  LDA ZP_CURSOR_Y
  CLC
  ADC ZP_CURSOR_DY
  PHA
  SEC
  SBC #TOP_MARGIN           ; 比較のためにテキスト領域を無視してそろえる
  CMP #192-TOP_MARGIN-8     ; 自由領域をオーバーしたか
  PLA
  BCS @SKP_NEW_Y
  STA ZP_CURSOR_Y
@SKP_NEW_Y:
  draw_cursor
.endmac

.macro erase_cursor
  LDA #(CRTC2::WF|2)          ; f2書き込み
  STA CRTC2::CONF
  LDA ZP_CURSOR_X
  STA CRTC2::PTRX
  LDA ZP_CURSOR_Y
  STA CRTC2::PTRY
  LDA #COL_CORSOR_BG
  STA CRTC2::WDAT
.endmac

.macro draw_cursor
  LDA #(CRTC2::WF|2)          ; f2書き込み
  STA CRTC2::CONF
  LDA ZP_CURSOR_X
  STA CRTC2::PTRX
  LDA ZP_CURSOR_Y
  STA CRTC2::PTRY
  LDA #COL_CORSOR_FG
  STA CRTC2::WDAT
.endmac

; -------------------------------------------------------------------
;                             パッド操作
; -------------------------------------------------------------------
.macro tick_pad
TICK_PAD:
  mem2mem16 ZP_PADSTAT_PREV,ZP_PADSTAT
  JSR PAD_READ                ; パッド状態更新
  STZ ZP_CURSOR_DY
  STZ ZP_CURSOR_DX
  LDA #CURSOR_SPEED
  BBS5 ZP_PADSTAT+1,@SKP_L    ; L
  LSR                         ; 速度を半分に
@SKP_L:
  TAY                         ; Y:正のスピード
  STA ZR0
  LDA #0
  SBC ZR0
  TAX                         ; X:負のスピード
  BBS3 ZP_PADSTAT,@SKP_UP     ; up
  STX ZP_CURSOR_DY
@SKP_UP:
  BBS2 ZP_PADSTAT,@SKP_DOWN   ; down
  STY ZP_CURSOR_DY
@SKP_DOWN:
  BBS1 ZP_PADSTAT,@SKP_LEFT   ; left
  STX ZP_CURSOR_DX
@SKP_LEFT:
  BBS0 ZP_PADSTAT,@SKP_RIGHT  ; right
  STY ZP_CURSOR_DX
@SKP_RIGHT:
  BBS7 ZP_PADSTAT,@SKP_B      ; B button
  JSR PUT_DOT
@SKP_B:
  BBS6 ZP_PADSTAT,@SKP_Y      ; Y button
  BBR6 ZP_PADSTAT_PREV,@SKP_Y ;  押下のみ
  JSR TOGGLE_FRAME
@SKP_Y:
.endmac

START:
  JMP INIT

TOGGLE_FRAME:
  LDA ZP_DISP_FRAME
  CMP #%01010101
  BEQ @SET_2
@SET_1:
  LDA #%01010101
  BRA @SET_REG
@SET_2:
  LDA #%10011001
@SET_REG:
  STA ZP_DISP_FRAME
  STA CRTC2::DISP
  RTS

; 画面全体をAの値で埋め尽くす
FILL:
  STZ CRTC2::PTRX
  STZ CRTC2::PTRY
  STA CRTC2::WDAT
  LDY #$C0
FILL_LOOP_V:
  LDX #$80
FILL_LOOP_H:
  LDA CRTC2::REPT
  DEX
  BNE FILL_LOOP_H
  DEY
  BNE FILL_LOOP_V
  RTS

PUT_DOT:
  ; カーソル位置に点を打つ
  LDA #(CRTC2::WF|1)          ; f1書き込み
  STA CRTC2::CONF
  LDA ZP_CURSOR_X
  STA CRTC2::PTRX
  LDA ZP_CURSOR_Y
  STA CRTC2::PTRY
  LDA #$88
  STA CRTC2::WDAT
  RTS

INIT_CRTC:
  ; CRTCを初期化
  LDA #%10000000                  ; ChrBox off
  STA CRTC2::CHRW

  ; コンフィグレジスタの設定 f1
  LDA #(CRTC2::WF|1)              ; f1書き込み
  STA CRTC2::CONF
  LDA #(CRTC2::TT|0)              ; 16色モード
  STA CRTC2::CONF
  LDA #$FF                        ; 塗りつぶし
  JSR FILL

  ; コンフィグレジスタの設定 f2
  LDA #(CRTC2::WF|2)              ; f2書き込み
  STA CRTC2::CONF
  LDA #(CRTC2::TT|0)              ; 16色モード
  STA CRTC2::CONF
  LDA #$FF                        ; 塗りつぶし
  JSR FILL

  ; 表示フレームセット
  JSR TOGGLE_FRAME
  RTS

INIT:
  ; ---------------------------------------------------------------
  ;   初期化
  LDA #%01010101
  STA ZP_DISP_FRAME
  JSR INIT_CRTC
  ; ---------------------------------------------------------------
  ;   IOレジスタの設定
  ; ---------------------------------------------------------------
  ;   汎用ポートの設定
  LDA VIA::PAD_DDR          ; 0で入力、1で出力
  ORA #(VIA::PAD_CLK|VIA::PAD_PTS)
  AND #<~(VIA::PAD_DAT)
  STA VIA::PAD_DDR
  ; ---------------------------------------------------------------
  ;   変数初期化
  LDA #50
  STA ZP_CURSOR_X
  STA ZP_CURSOR_Y
  LDA #CURSOR_SPEED
  STA ZP_CURSOR_DX
  STA ZP_CURSOR_DY
  ; ---------------------------------------------------------------
  ;   割り込みハンドラの登録
  loadAY16 VBLANK
  syscall IRQ_SETHNDR_VB
  storeAY16 ZP_VB_STUB
  CLI
  ; 完全垂直同期割り込み駆動
  STZ HOGE
  ; ---------------------------------------------------------------
  ;   無限ループ
MAIN:
  ; 実際には下記の割り込みが走る
  LDA HOGE  ; HOGEがVB中に変更されたらブレイクする
  BEQ MAIN
  ; ---------------------------------------------------------------
  ;   プログラム終了
END:
  ; ---------------------------------------------------------------
  ;   キー入力待機
  LDA #BCOS::BHA_CON_RAWIN_WaitAndNoEcho
  syscall CON_RAWIN
  RTS

; -------------------------------------------------------------------
;                          垂直同期割り込み
; -------------------------------------------------------------------
VBLANK:
  ; ---------------------------------------------------------------
  ;   パッド操作
  tick_cursor
  tick_pad
  ; ---------------------------------------------------------------
  ;   ティック終端
  JMP (ZP_VB_STUB)            ; 片付けはBCOSにやらせる

; PAD読み取りルーチン
PAD_READ:
  LDA #BCOS::BHA_CON_RAWIN_NoWaitNoEcho  ; キー入力チェック
  syscall CON_RAWIN
  BEQ @SKP_RTS
  RTS
@SKP_RTS:
  ; P/S下げる
  LDA VIA::PAD_REG
  ORA #VIA::PAD_PTS
  STA VIA::PAD_REG
  ; P/S下げる
  LDA VIA::PAD_REG
  AND #<~VIA::PAD_PTS
  STA VIA::PAD_REG
  ; 読み取りループ
  LDX #16
@LOOP:
  LDA VIA::PAD_REG        ; データ読み取り
  ; クロック下げる
  AND #<~VIA::PAD_CLK
  STA VIA::PAD_REG
  ; 16bit値として格納
  ROR
  ROL ZP_PADSTAT+1
  ROL ZP_PADSTAT
  ; クロック上げる
  LDA VIA::PAD_REG        ; データ読み取り
  ORA #VIA::PAD_CLK
  STA VIA::PAD_REG
  DEX
  BNE @LOOP
  RTS

