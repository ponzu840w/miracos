; -------------------------------------------------------------------
;                           SYNTHコマンド
; -------------------------------------------------------------------
; YMZ
; -------------------------------------------------------------------
.INCLUDE "../FXT65.inc"
.INCLUDE "../generic.mac"
.INCLUDE "../fs/structfs.s"
.INCLUDE "../fscons.inc"
.PROC BCOS
  .INCLUDE "../syscall.inc"  ; システムコール番号
.ENDPROC
.INCLUDE "../syscall.mac"
.INCLUDE "../zr.inc"

; -------------------------------------------------------------------
;                               変数領域
; -------------------------------------------------------------------
.BSS
  ; 現在関心チャンネル
  ;   っていうYoutubeチャンネルありそう
  CURRENT_CH:       .RES 1
  CURRENT_TAB:      .RES 1 ; チャンネル中の対象
  ; 設定項目
  MIX:              .RES 1 ; ミキシング設定
  ; 周波数
  FRQ_A:            .RES 2
  FRQ_B:            .RES 2
  FRQ_C:            .RES 2
  ; 音量
  VOL_A:            .RES 1
  VOL_B:            .RES 1
  VOL_C:            .RES 1

; -------------------------------------------------------------------
;                             実行領域
; -------------------------------------------------------------------
.CODE
START:
  ; リセット
  JSR RESET
  JSR APPLY_SOUND
  ; 起動メッセージ
  loadAY16 STR_HELLO
  syscall CON_OUT_STR
  ; コマンド受付
CMD_LOOP:
  JSR PRT_PROMPT
  LDA #BCOS::BHA_CON_RAWIN_WaitAndNoEcho    ; 入力待機、エコーなし
  syscall CON_RAWIN                         ; コマンド入力
@SMALL_J:
  CMP #'j'
  BNE @SMALL_K
  ; j
  LDA #255
  BRA CHANGE_VALUE
  ; end j
@SMALL_K:
  CMP #'k'
  BNE @END_K
  ; k
  LDA #1
  BRA CHANGE_VALUE
  ; end k
@END_K:
@SMALL_H:
  CMP #'h'
  BNE @END_H
  ; h
  LDA CURRENT_TAB
  BEQ @END_H
  DEC CURRENT_TAB
  ; end h
@END_H:
@SMALL_L:
  CMP #'l'
  BNE @END_L
  ; l
  LDA CURRENT_TAB
  CMP #3
  BEQ @END_L
  INC CURRENT_TAB
  ; end l
@END_L:
  BRA CMD_LOOP
  RTS

CHANGE_VALUE:
  ;PHA ; 増加量push
  ;LDA CURRENT_TAB
  CLC
  ADC VOL_A
  STA VOL_A
  ; debug
  ;JSR PRT_BYT
  JSR APPLY_SOUND ; 反映
  BRA CMD_LOOP

RESET:
  ; 設定リセット
  LDY #0
@LOOP:
  LDA DEFAULT_CURRENT_CH,Y
  STA CURRENT_CH,Y
  INY
  CPY #12
  BNE @LOOP
  RTS

PRT_PROMPT:
  ; プロンプトを表示
  ; *
  LDA #0
  JSR CURSOR
  ; [Ch_]
  loadAY16 STR_CH
  syscall CON_OUT_STR
  ; Ch_[A]
  LDA #'A'
  CLC
  ADC CURRENT_CH
  syscall CON_OUT_CHR
  JSR PRT_S
  ; *
  LDA #1
  JSR CURSOR
  ; Ch_A[ Frq$]
  loadAY16 STR_FRQ
  syscall CON_OUT_STR
  ; Ch_A Frq$[1234]
  loadAY16 FRQ_A
  CLC
  ADC CURRENT_CH
  JSR PRT_SHORT
  JSR PRT_S
  ; *
  LDA #2
  JSR CURSOR
  ; Ch_A Frq$0234[ Vol$]
  loadAY16 STR_VOL
  syscall CON_OUT_STR
  ; Ch_A Frq$0234 Vol$[05]
  LDX CURRENT_CH
  LDA VOL_A,X
  JSR PRT_BYT
  JSR PRT_LF
  RTS

CURSOR:
  ; Aで受けたタブ番号だったら*表示
  CMP CURRENT_TAB
  BNE @SPC
  LDA #'*'
  BRA @CALL
@SPC:
  LDA #' '
@CALL:
  syscall CON_OUT_CHR
  RTS

APPLY_SOUND:
  ; 設定を全部書き込む
  ; 必要部分だけ書き込むようには…必要があればそうする。
  ; MIX
  LDA #YMZ::IA_MIX
  STA YMZ::ADDR
  LDA MIX
  STA YMZ::DATA
  ; FRQ
  LDY #0          ; イテレータ ...5
@LOOP:
  STY ZR0         ; 加算用
  LDA #YMZ::IA_FRQ ; 内部アドレス先頭を
  CLC
  ADC ZR0         ; 加算
  STA YMZ::ADDR   ; アドレスセット
  ; debug
  ;PHY
  ;JSR PRT_BYT
  ;PLY
  LDA FRQ_A,Y     ; 設定値取得
  STA YMZ::DATA   ; ペースト
  ; debug
  ;PHY
  ;JSR PRT_BYT
  ;JSR PRT_LF
  ;PLY
  INY
  CPY #6
  BNE @LOOP
  ; VOL
  ; A
  LDA #YMZ::IA_VOL
  STA YMZ::ADDR
  LDA VOL_A
  STA YMZ::DATA
  ;JSR PRT_BYT
  ;JSR PRT_LF
  ; B
  LDA #YMZ::IA_VOL+1
  STA YMZ::ADDR
  LDA VOL_B
  STA YMZ::DATA
  ; A
  LDA #YMZ::IA_VOL+2
  STA YMZ::ADDR
  LDA VOL_C
  STA YMZ::DATA
  RTS

; 16bit値を表示
PRT_SHORT:
  storeAY16 ZR2
  LDY #1
  LDA (ZR2),Y
  JSR PRT_BYT
  LDY #0
  LDA (ZR2),Y
  JSR PRT_BYT
  RTS

; 8bit値を表示
PRT_BYT:
  JSR BYT2ASC
  PHY
  JSR PRT_C_CALL
  PLA
PRT_C_CALL:
  syscall CON_OUT_CHR
  RTS

; Aで与えられたバイト値をASCII値AYにする
; Aから先に表示すると良い
BYT2ASC:
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

; #$0?をアスキー一文字にする
NIB2ASC:
  ORA #$30
  CMP #$3A
  BCC @SKP_ADC  ; Aが$3Aより小さいか等しければ分岐
  ADC #$06
@SKP_ADC:
  RTS

; 改行
PRT_LF:
  LDA #$A
  JMP PRT_C_CALL

; スペース印字
PRT_S:
  LDA #' '
  JMP PRT_C_CALL

; 初期値
DEFAULT_CURRENT_CH:   .BYT 0
DEFAULT_CURRENT_TAB:  .BYT 0
DEFAULT_MIX:          .BYT %00111110
DEFAULT_FRQ_A:
  .WORD 500
  .WORD 500
  .WORD 500
DEFAULT_VOL_A:
  .BYT 0
  .BYT 0
  .BYT 0

STR_HELLO:  .BYT  "PSG:Programmable Sound Generator",$A,"YMZ294 Sound Playground.",$A,$0
STR_CH:     .BYT  "Ch-",0
STR_FRQ:    .BYT  "Frq$",0
STR_VOL:    .BYT  "Vol$",0

