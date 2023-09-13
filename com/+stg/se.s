; -------------------------------------------------------------------
;                           効果音定数
; -------------------------------------------------------------------
SE1_LENGTH = 5
SE1_NUMBER = 1*2
SE2_LENGTH = 5
SE2_NUMBER = 2*2
SE_PLSHOT_NUMBER = 3*2
SE_PLSHOT_LENGTH = 5

; -------------------------------------------------------------------
;                               ZP領域
; -------------------------------------------------------------------
.ZEROPAGE
  ; SOUND
  ZP_SE_STATE:        .RES 1        ; 効果音の状態
  ZP_SE_TIMER:        .RES 1

.SEGMENT "LIB"

; -------------------------------------------------------------------
;                             初期化処理
; -------------------------------------------------------------------
.macro init_se
  STZ ZP_SE_STATE           ; サウンドの初期化
  ;LDA ZP_CH_ENABLE
  ;ORA #%00000100
  ;STA ZP_CH_ENABLE
  ;LDA #%11111011
  ;STA ZP_CH_NOTREST
.endmac

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
  ;set_ymzreg #YMZ::IA_MIX,#%00111111
  LDA #YMZ::IA_MIX
  STA YMZ::ADDR
  LDA ZP_CH_ENABLE
  AND #%00000011
  EOR #$FF
  STA YMZ::DATA
  STZ ZP_SE_STATE
TICK_SE_END:
.endmac

; -------------------------------------------------------------------
;                        効果音種類テーブル
; -------------------------------------------------------------------
SE_LENGTH_TABLE:
  .BYTE SE1_LENGTH      ; 1
  .BYTE SE2_LENGTH      ; 2
  .BYTE SE_PLSHOT_LENGTH
  ; NOTE:ここにべた書きでよいのでは

SE_TICK_JT:
  .WORD SE1_TICK
  .WORD SE2_TICK
  .WORD SE_PLSHOT_TICK

; -------------------------------------------------------------------
;                         各効果音ティック
; -------------------------------------------------------------------
SE1_TICK:
  LDA ZP_SE_TIMER
  CMP #SE1_LENGTH
  BNE @a
  ;set_ymzreg #YMZ::IA_MIX,#%00111110
  LDA #YMZ::IA_MIX
  STA YMZ::ADDR
  LDA ZP_CH_ENABLE
  ORA #%00000100
  EOR #$FF
  STA YMZ::DATA
  set_ymzreg #YMZ::IA_FRQ+4+1,#>(125000/800)
  set_ymzreg #YMZ::IA_FRQ+4,#<(125000/800)
  set_ymzreg #YMZ::IA_VOL+2,#$0F
  JMP TICK_SE_RETURN
@a:
  LDX #YMZ::IA_VOL+2
  STX YMZ::ADDR
  ASL                       ; タイマーの左シフト、最大8
  ADC #4
  STA YMZ::DATA
  JMP TICK_SE_RETURN

SE2_TICK:
  ;set_ymzreg #YMZ::IA_MIX,#%00110111
  LDA #YMZ::IA_MIX
  STA YMZ::ADDR
  LDA ZP_CH_ENABLE
  ORA #%00100000
  EOR #$FF
  STA YMZ::DATA
  set_ymzreg #YMZ::IA_NOISE_FRQ,#>(125000/400)
  set_ymzreg #YMZ::IA_VOL+2,#$0F
  JMP TICK_SE_RETURN

SE_PLSHOT_TICK:
  LDA ZP_SE_TIMER
  CMP #SE1_LENGTH
  BNE @a
  ;set_ymzreg #YMZ::IA_MIX,#%00111110
  LDA #YMZ::IA_MIX
  STA YMZ::ADDR
  LDA ZP_CH_ENABLE
  ORA #%00000100
  EOR #$FF
  STA YMZ::DATA
  set_ymzreg #YMZ::IA_FRQ+4+1,#>(125000/1600)
  set_ymzreg #YMZ::IA_FRQ+4,#<(125000/1600)
  set_ymzreg #YMZ::IA_VOL+2,#$0F
  JMP TICK_SE_RETURN
@a:
  LDX #YMZ::IA_VOL+2
  STX YMZ::ADDR
  ASL                       ; タイマーの左シフト、最大8
  ADC #4
  STA YMZ::DATA
  JMP TICK_SE_RETURN

