STARS_NUM = 10
; -------------------------------------------------------------------
;                               ZP領域
; -------------------------------------------------------------------
.ZEROPAGE
  ZP_START_FLAG:      .RES 1
  ZP_STARS_INDEX:     .RES 1

; -------------------------------------------------------------------
;                             実行領域
; -------------------------------------------------------------------
.SEGMENT "LIB"

INIT_TITLE:
  ; ---------------------------------------------------------------
  ;   YMZ
  JSR MUTE_ALL
  init_ymzq
  ; ---------------------------------------------------------------
  ;   CRTC
  ; FB1
  LDY #(CRTC2::WF|1)
  STY CRTC2::CONF           ; FB1を書き込み先に
  LDX #(CRTC2::TT|0)        ; 念のため16色モードを設定
  STX CRTC2::CONF
  ; DISP
  LDA #%01010101            ; FB1
  STA CRTC2::DISP           ; 表示フレームを全てFB1に
  ; chrbox無効化
  ROL                       ; bit7=1でchrbox無効
  STA CRTC2::CHRW
  ; ---------------------------------------------------------------
  ;   変数の初期化
  STZ ZP_START_FLAG
  ; 画像表示
  loadAY16 PATH_TITLEIMF
  JSR IMF::PRINT_IMF
  ; CRTC再設定
  ;LDA #%00000000            ; 全フレーム16色モード、16色モード座標書き込み、書き込みカウントアップ無効
  ;STA CRTC::CFG
  LDX #0
  loadAY16 NOTES
  JSR PLAY
  ; ---------------------------------------------------------------
  ;   割り込みハンドラの登録
  SEI
  loadAY16 TITLE_VBLANK
  syscall IRQ_SETHNDR_VB
  storeAY16 ZP_VB_STUB
  CLI
  ; 無限ループ
TITLE_LOOP:
  LDA ZP_START_FLAG
  BEQ TITLE_LOOP
  ; ---------------------------------------------------------------
  ; 脱出
  ; ---------------------------------------------------------------
  ;   割り込みハンドラの抹消
  SEI
  mem2AY16 ZP_VB_STUB
  syscall IRQ_SETHNDR_VB
  CLI
  BBS1 ZP_START_FLAG,@RET
  JMP INIT_GAME
@RET:
  syscall RESET

; -------------------------------------------------------------------
;                        綺羅星ティック
; -------------------------------------------------------------------
.macro kiraboshi
  LDX #0                    ; 星インデックス
  STX ZP_STARS_INDEX
KIRABOSHI_LOOP:
  ; 座標設定
  ; NOTE:結構無駄
  LDA TITLE_STARS_LIST,X    ; X
  STA CRTC2::PTRX
  LDA TITLE_STARS_LIST+1,X  ; Y
  STA CRTC2::PTRY
  ; ON/OFF判定
  LDA TITLE_STARS_LIST+2,X  ; マスク値を取得
  AND ZP_GENERAL_CNT
  CMP TITLE_STARS_LIST+3,X  ; ON
  BNE @SKP_ON
  ; ON
  LDA #$F0
  STA CRTC2::WDAT
  BRA @SKP_OFF
@SKP_ON:
  CMP TITLE_STARS_LIST+4,X  ; OFF
  BNE @SKP_OFF
  ; OFF
  STZ CRTC2::WDAT
@SKP_OFF:
  ; ループ処理
  ; インデックス加算
  LDA #5
  CLC
  ADC ZP_STARS_INDEX
  STA ZP_STARS_INDEX
  TAX
  CPX #STARS_NUM*5
  BNE KIRABOSHI_LOOP
.endmac

; -------------------------------------------------------------------
;                        垂直同期割り込み
; -------------------------------------------------------------------
TITLE_VBLANK:
  tick_ymzq
  JSR PAD_READ                ; パッド状態更新
  BBS4 ZP_PADSTAT,@SKP_START  ; STARTボタン
  SMB0 ZP_START_FLAG          ; フラグを立てて脱出を企画する
@SKP_START:
  BBS5 ZP_PADSTAT,@SKP_SELECT ; SELECTボタン
  SMB1 ZP_START_FLAG          ; フラグを立てて脱出を企画する
@SKP_SELECT:
  kiraboshi
  INC ZP_GENERAL_CNT
  JMP (ZP_VB_STUB)            ; 片付けはBCOSにやらせる

; -------------------------------------------------------------------
;                           データ部
; -------------------------------------------------------------------
PATH_TITLEIMF:
  .BYT "/DOC/STGTITLE.IMF",0

TITLE_STARS_LIST:
  ;      0    1          2    3    4
  ;      X,   Y, %    mask,  ON, OFF
  .BYT  11,  44, %11111111,  90, 255
  .BYT 111,  90, %01111111,  20,  50
  .BYT  56, 154, %00111111,  10,   5
  .BYT  60,  10, %00011111,  19,  20

  .BYT  44, 181, %11111111,  80, 200
  .BYT  20,  10, %01111111,  30,  40
  .BYT  42, 102, %00111111,  33,   8
  .BYT   3, 142, %11111111,  90, 255

  .BYT 120,  43, %01111111,   0,  30
  .BYT 102, 140, %00111111,  50,  35

NOTES:
.BYTE 128+1,3
.BYTE 128+2,0   ; ストレート

.BYTE 55,2
.BYTE 57,2
.BYTE 55,2
.BYTE 52,2
.BYTE 53,4

.BYTE 128+6     ; STOP

