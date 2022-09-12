; -------------------------------------------------------------------
;                           効果音定数
; -------------------------------------------------------------------
SE1_LENGTH = 5
SE1_NUMBER = 1*2
SE2_LENGTH = 5
SE2_NUMBER = 2*2

; -------------------------------------------------------------------
;                               ZP領域
; -------------------------------------------------------------------
.ZEROPAGE
  ; SOUND
  ZP_SE_STATE:        .RES 1        ; 効果音の状態
  ZP_SE_TIMER:        .RES 1

.SEGMENT "LIB"

; -------------------------------------------------------------------
;                   YMZ内部レジスタに値を格納する
; -------------------------------------------------------------------
.macro set_ymzreg addr,dat
  LDA addr
  STA YMZ::ADDR
  LDA dat
  STA YMZ::DATA
.endmac

; -------------------------------------------------------------------
;                   Aで与えられた番号のSEを鳴らす
; -------------------------------------------------------------------
; X使用
PLAY_SE:
  STA ZP_SE_STATE
  LSR
  TAX
  LDA SE_LENGTH_TABLE-1,X
  STA ZP_SE_TIMER
@END:
  RTS

; -------------------------------------------------------------------
;                       効果音ティック処理
; -------------------------------------------------------------------
.macro tick_se
TICK_SE:
  LDX ZP_SE_STATE       ; 効果音状態
  BEQ TICK_SE_END       ; 何も鳴ってないなら無視
  JMP (SE_TICK_JT-2,X)  ; 鳴っているので効果音種類ごとの処理に跳ぶ
TICK_SE_RETURN:         ; ここに帰ってくる
  DEC ZP_SE_TIMER       ; タイマー減算
  BNE TICK_SE_END
  ; 0になった
  set_ymzreg #YMZ::IA_MIX,#%00111111
  STZ ZP_SE_STATE
TICK_SE_END:
.endmac

; -------------------------------------------------------------------
;                        効果音種類テーブル
; -------------------------------------------------------------------
SE_LENGTH_TABLE:
  .BYTE SE1_LENGTH      ; 1
  .BYTE SE2_LENGTH      ; 2

SE_TICK_JT:
  .WORD SE1_TICK
  .WORD SE2_TICK

; -------------------------------------------------------------------
;                         各効果音ティック
; -------------------------------------------------------------------
SE1_TICK:
  LDA ZP_SE_TIMER
  CMP #SE1_LENGTH
  BNE @a
  set_ymzreg #YMZ::IA_MIX,#%00111110
  set_ymzreg #YMZ::IA_FRQ+1,#>(125000/800)
  set_ymzreg #YMZ::IA_FRQ,#<(125000/800)
  set_ymzreg #YMZ::IA_VOL,#$0F
  JMP TICK_SE_RETURN
@a:
  LDX #YMZ::IA_VOL
  STX YMZ::ADDR
  ASL                       ; タイマーの左シフト、最大8
  ADC #4
  STA YMZ::DATA
  JMP TICK_SE_RETURN

SE2_TICK:
  set_ymzreg #YMZ::IA_MIX,#%00110111
  set_ymzreg #YMZ::IA_NOISE_FRQ,#>(125000/400)
  set_ymzreg #YMZ::IA_VOL,#$0F
  JMP TICK_SE_RETURN

