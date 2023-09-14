; -------------------------------------------------------------------
;                           効果音定数
; -------------------------------------------------------------------
SE_MENU_LENGTH = 5
SE_MENU_NUMBER = 1*2
SE_EAT_LENGTH = 5
SE_EAT_NUMBER = 2*2
SE_START_LENGTH = 15
SE_START_NUMBER = 3*2
SE_OVER_LENGTH = 30
SE_OVER_NUMBER = 4*2

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
  set_ymzreg #YMZ::IA_MIX,#%00111111
  STZ ZP_SE_STATE
TICK_SE_END:
.endmac

; -------------------------------------------------------------------
;                        効果音種類テーブル
; -------------------------------------------------------------------
SE_LENGTH_TABLE:
  .BYTE SE_MENU_LENGTH    ; 1
  .BYTE SE_EAT_LENGTH     ; 2
  .BYTE SE_START_LENGTH   ; 3
  .BYTE SE_OVER_LENGTH    ; 4
  ; NOTE:ここにべた書きでよいのでは

SE_TICK_JT:
  .WORD SE_MENU_TICK
  .WORD SE_EAT_TICK
  .WORD SE_START_TICK
  .WORD SE_OVER_TICK

; -------------------------------------------------------------------
;                         各効果音ティック
; -------------------------------------------------------------------
SE_MENU_TICK:
  LDA ZP_SE_TIMER
  CMP #SE_MENU_LENGTH
  BNE @a
  set_ymzreg #YMZ::IA_MIX,#%00111110
  set_ymzreg #YMZ::IA_FRQ+1,#>(125000/400)
  set_ymzreg #YMZ::IA_FRQ,#<(125000/400)
  set_ymzreg #YMZ::IA_VOL,#$0F
  JMP TICK_SE_RETURN
@a:
  LDX #YMZ::IA_VOL
  STX YMZ::ADDR
  ASL                       ; タイマーの左シフト、最大8
  ADC #4
  STA YMZ::DATA
  JMP TICK_SE_RETURN

SE_EAT_TICK:
  set_ymzreg #YMZ::IA_MIX,#%00110111
  set_ymzreg #YMZ::IA_NOISE_FRQ,#>(125000/500)
  set_ymzreg #YMZ::IA_VOL,#$0F
  JMP TICK_SE_RETURN

SE_START_TICK:
  LDA ZP_SE_TIMER
  CMP #SE_START_LENGTH
  BNE @a
  ; 初回のみ呼ばれる
  set_ymzreg #YMZ::IA_MIX,#%00111110
  set_ymzreg #YMZ::IA_FRQ+1,#>(125000/200)
  set_ymzreg #YMZ::IA_FRQ,#<(125000/200)
  set_ymzreg #YMZ::IA_VOL,#$0F
  JMP TICK_SE_RETURN
@a:
  ; 継続的処理
  LDX #YMZ::IA_FRQ
  STX YMZ::ADDR             ; 音量をセット
  ASL                       ; タイマーの左シフト、最大8
  ADC #4
  STA YMZ::DATA
  JMP TICK_SE_RETURN

SE_OVER_TICK:
  set_ymzreg #YMZ::IA_MIX,#%00110111
  set_ymzreg #YMZ::IA_NOISE_FRQ,#>(125000/200)
  set_ymzreg #YMZ::IA_VOL,#$0F
  JMP TICK_SE_RETURN

