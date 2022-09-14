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
  ;   CRTC
  LDA #%00000001            ; 全フレーム16色モード、16色モード座標書き込み、書き込みカウントアップ有効
  STA CRTC::CFG
  LDA #%01010101            ; フレームバッファ1
  STA CRTC::RF              ; FB1を表示
  STA CRTC::WF              ; FB1を書き込み先に
  ; ---------------------------------------------------------------
  ;   変数の初期化
  STZ ZP_START_FLAG
  ; ---------------------------------------------------------------
  ;   割り込みハンドラの登録
  SEI
  loadAY16 TITLE_VBLANK
  syscall IRQ_SETHNDR_VB
  storeAY16 ZP_VB_STUB
  CLI
  ; 画像表示
  loadAY16 PATH_TITLEIMF
  JSR IMF::PRINT_IMF
  ; CRTC再設定
  LDA #%00000000            ; 全フレーム16色モード、16色モード座標書き込み、書き込みカウントアップ無効
  STA CRTC::CFG
  ; 無限ループ
TITLE_LOOP:
  BBR0 ZP_START_FLAG,TITLE_LOOP
  ; ---------------------------------------------------------------
  ; 脱出
  ; ---------------------------------------------------------------
  ;   割り込みハンドラの抹消
  SEI
  mem2AY16 ZP_VB_STUB
  syscall IRQ_SETHNDR_VB
  CLI
  JMP INIT_GAME


; -------------------------------------------------------------------
;                        垂直同期割り込み
; -------------------------------------------------------------------
TITLE_VBLANK:
  JSR PAD_READ                ; パッド状態更新
  BBS4 ZP_PADSTAT,@SKP_START  ; STARTボタン
  SMB0 ZP_START_FLAG          ; フラグを立てて脱出を企画する
@SKP_START:
  INC ZP_GENERAL_CNT
  LDA ZP_GENERAL_CNT
  AND #%01111111              ; 256ティック周期を8分周
  BNE @SKP_TICK_STARS
  ; 綺羅星ティック
  LDX ZP_STARS_INDEX
  LDA ZP_GENERAL_CNT
  AND #%11111111              ; 256ティック周期を8分周
  BNE @NEXT
  ; 前回の星を削除
  LDA #0
  STA CRTC::WDBF
  BRA @SKP_TICK_STARS
@NEXT:
  ; 次の星
  INX
  INX
  CPX #8
  BNE @SKP_RESET
  LDX #0
@SKP_RESET:
  STX ZP_STARS_INDEX
  LDA TITLE_STARS_LIST,X
  STA CRTC::VMAH
  LDA TITLE_STARS_LIST+1,X
  STA CRTC::VMAV
  LDA #$0F
  STA CRTC::WDBF
@SKP_TICK_STARS:
  JMP (ZP_VB_STUB)            ; 片付けはBCOSにやらせる

; -------------------------------------------------------------------
;                           データ部
; -------------------------------------------------------------------
PATH_TITLEIMF:
  .BYT "/DOC/STGTITLE.IMF",0

TITLE_STARS_LIST:
  .BYT 11,44
  .BYT 111,90
  .BYT 56,154
  .BYT 60,10

