; -------------------------------------------------------------------
;                             実行領域
; -------------------------------------------------------------------
.SEGMENT "LIB"

GAMEOVER:
  ; ---------------------------------------------------------------
  ;   YMZ
  JSR MUTE_ALL
  init_ymzq
  ; ---------------------------------------------------------------
  ;   変数の初期化
  STZ ZP_START_FLAG
  ;LDX #0
  ;loadAY16 NOTES
  ;JSR PLAY
  ; がめん
  LDA ZP_VISIBLE_FLAME      ; 見えてるフレームに書く
  AND #%00000011            ; 下位のみにマスク
  ORA #CRTC2::WF            ; WFサブアドレス
  STA CRTC2::CONF
  ; ---------------------------------------------------------------
  ;   文字列描画
  ; chrbox設定
  LDA #3                    ; よこ4
  STA CRTC2::CHRW
  LDA #7                    ; たて8
  STA CRTC2::CHRH
  ; 文字列色設定
  LDA #$00
  STA ZP_STR88_BKCOL
  LDA ZP_ZANKI
  CMP #$FF
  BNE @CLEAR
@OVER:
  LDA #$AA
  STA ZP_STR88_COLOR
  str88_puts 64-18,90,STR_GAMEOVER
  BRA @SKP
@CLEAR:
  LDA #$77
  STA ZP_STR88_COLOR
  str88_puts 64-20,90,STR_GAMECLEAR
@SKP:
  LDA #$FF
  STA ZP_STR88_COLOR
  str88_puts 64-22,140,STR_PRESSSTART
  ; ---------------------------------------------------------------
  ;   割り込みハンドラの登録
  SEI
  loadAY16 GAMEOVER_VBLANK
  syscall IRQ_SETHNDR_VB
  storeAY16 ZP_VB_STUB
  CLI
  ; 無限ループ
GAMEOVER_LOOP:
  LDA ZP_START_FLAG
  BEQ GAMEOVER_LOOP
  ; ---------------------------------------------------------------
  ; 脱出
  ; ---------------------------------------------------------------
  ;   割り込みハンドラの抹消
  SEI
  mem2AY16 ZP_VB_STUB
  syscall IRQ_SETHNDR_VB
  CLI
  BBS1 ZP_START_FLAG,@RET
  JMP INIT_TITLE
@RET:
  syscall RESET

; -------------------------------------------------------------------
;                        垂直同期割り込み
; -------------------------------------------------------------------
GAMEOVER_VBLANK:
  tick_ymzq
  JSR PAD_READ                ; パッド状態更新
  BBS4 ZP_PADSTAT,@SKP_START  ; STARTボタン
  SMB0 ZP_START_FLAG          ; フラグを立てて脱出を企画する
@SKP_START:
  JMP (ZP_VB_STUB)            ; 片付けはBCOSにやらせる

; -------------------------------------------------------------------
;                           データ部
; -------------------------------------------------------------------
STR_GAMEOVER:
  .BYTE "GAME OVER",$0
STR_GAMECLEAR:
  .BYTE "GAME CLEAR!",$0
STR_PRESSSTART:
  .BYTE "Press START.",$0

