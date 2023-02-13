; -------------------------------------------------------------------
;                  YMZQ.S メロディー再生ライブラリ
; -------------------------------------------------------------------
; 単純な音色を、楽譜通りの音階と音調で出すシンプル志向音楽
; BGM用途に
; Vsync駆動
; -------------------------------------------------------------------

; -------------------------------------------------------------------
;                             構造体定義
; -------------------------------------------------------------------
.STRUCT SKIN_STATE
  ; スキンの操作対象データ
  CH                .RES 1  ; チャンネル 0=A 1=B 2=C NOTE 初めからXで与えれば要らないかも
  SKIN              .RES 2  ; スキンルーチンのポインタ
  FRQ               .RES 2  ; 周波数
  VOL               .RES 1  ; 音量
  TIME              .RES 1  ; 経過時間
  ;todo
.ENDSTRUCT

; -------------------------------------------------------------------
;                               ZP領域
; -------------------------------------------------------------------
.ZEROPAGE
  ; ダウンカウンタ
  ZP_TEMPO_CNT_A:     .RES 1        ; テンポ倍率カウンタ
  ZP_TEMPO_CNT_B:     .RES 1
  ZP_TEMPO_CNT_C:     .RES 1
  ZP_LEN_CNT_A:       .RES 1        ; 音長カウンタ
  ZP_LEN_CNT_B:       .RES 1
  ZP_LEN_CNT_C:       .RES 1
  ; チャンネル状態
  ZP_CH_STATE:        .RES 1        ; 7|00000cba|0
  ; 楽譜ポインタ
  ZP_SHEET_PTR:       .RES 2
  ; 音色状態構造体ポインタ
  ZP_SKIN_STATE_PTR:  .RES 2
  ;
  ZP_TIEMR_WORK:      .RES 1
  ZP_CH:              .RES 1
  ZP_YMZ_WORK:        .RES 1

; -------------------------------------------------------------------
;                            変数領域定義
; -------------------------------------------------------------------
.BSS
  ; 音色状態構造体の実体
  SKIN_STATE_A:       .TAG SKIN_STATE
  SKIN_STATE_B:       .TAG SKIN_STATE
  SKIN_STATE_C:       .TAG SKIN_STATE
  ; 楽譜ポインタ
  SHEET_PTR_L:        .RES 3        ; A,B,C それぞれのL
  SHEET_PTR_H:        .RES 3
  ; チャンネル設定
  TEMPO_A:            .RES 1        ; テンポ倍率保持用
  TEMPO_B:            .RES 1
  TEMPO_C:            .RES 1
  LEN_A:              .RES 1
  LEN_B:              .RES 1
  LEN_C:              .RES 1

.SEGMENT "LIB"

; -------------------------------------------------------------------
;                             初期化処理
; -------------------------------------------------------------------
.macro init_ymzq
  ; 本来設定可能であるべきもの
  LDA #15
  STA TEMPO_A  ; テンポ
  LDA #<SKIN0_BETA
  STA SKIN_STATE_A+SKIN_STATE::SKIN
  LDA #>SKIN0_BETA
  STA SKIN_STATE_A+SKIN_STATE::SKIN+1
.endmac

; input AY=楽譜 X=ch
PLAY:
  ; 楽譜ポインタ登録
  STA SHEET_PTR_L,X
  TYA
  STA SHEET_PTR_H,X
  ; チャンネル有効化
  ; TODO
  LDA #1
  STA ZP_CH_STATE ; 強制Aのみ
  LDX #YMZ::IA_MIX
  STX YMZ::ADDR
  EOR #$FF
  STA YMZ::DATA
  RTS

; -------------------------------------------------------------------
;                            ティック処理
; -------------------------------------------------------------------
; カウントダウン・次ノートトリガ・音色ドライブ
.macro tick_ymzq
TICK_YMZQ:
  ; ---------------------------------------------------------------
  ;   TIMER
  LDA ZP_CH_STATE
  STA ZP_TIEMR_WORK
  LDX #0
@TIMER_LOOP:
  STX ZP_CH
  LSR ZP_TIEMR_WORK     ; C=Ch有効/無効
  BCC @TIMER_NEXT_CH    ; 無効Chのカウントダウンをスキップ
  DEC ZP_LEN_CNT_A,X    ; 音長カウントダウン
  BNE @TIMER_NEXT_CH    ; 何もなければ次
  ; カウンタ0到達
  LDA ZP_TEMPO_CNT_A,X  ; テンポカウンタの取得
  BNE @SKP_FIRE         ; ゼロでなければ発火しない
  ; 発火
  JSR SHEET_PS
  BRA @TIMER_NEXT_CH
@SKP_FIRE:
  DEC A                 ; テンポカウンタ減算
  LDA TEMPO_A,X         ; 定義テンポをカウンタに格納
  STA ZP_TEMPO_CNT_A,X
  LDA LEN_A,X           ; 定義LENをカウンタに格納
  STA ZP_LEN_CNT_A,X
@TIMER_NEXT_CH:
  LDX ZP_CH
  INX
  CPX #3
  BNE @TIMER_LOOP
  ; ---------------------------------------------------------------
  ;   DRIVE SKIN
  LDX #2
@DRIVE_SKIN_LOOP:
  PHX
  JSR X2SKIN_STATE_PTR        ; 構造体ポインタ取得
  LDY #SKIN_STATE::SKIN       ; 使用スキンのポインタ
  LDA (ZP_SKIN_STATE_PTR),Y
  STA @JSR_TO_SKIN+1          ; JSR先の動的書き換え
  INY
  LDA (ZP_SKIN_STATE_PTR),Y
  STA @JSR_TO_SKIN+2
@JSR_TO_SKIN:
  JSR 6502                    ; スキンへ
  ; マスクに応じて実際のレジスタ書き換え
  ; FRQ L
  STA ZP_YMZ_WORK
  BBR0 ZP_YMZ_WORK,@VOL
  LDA ZP_CH
  ASL A
  CLC
  ADC #YMZ::IA_FRQ
  STA YMZ::ADDR
  LDY #SKIN_STATE::FRQ
  TAX
  LDA (ZP_SKIN_STATE_PTR),Y
  STA YMZ::DATA
  ; FRQ H
  INX
  INY
  STX YMZ::ADDR
  LDA (ZP_SKIN_STATE_PTR),Y
  STA YMZ::DATA
@VOL:
  BBR1 ZP_YMZ_WORK,@END
  ; VOL
  LDA #YMZ::IA_VOL
  STA YMZ::ADDR
  LDY #SKIN_STATE::VOL
  LDA (ZP_SKIN_STATE_PTR),Y
@END:
  PLX
  DEX
  BPL @DRIVE_SKIN_LOOP
.endmac

X2SKIN_STATE_PTR:
  LDA SKIN_STATE_STRUCT_TABLE_L,X
  STA ZP_SKIN_STATE_PTR
  LDA SKIN_STATE_STRUCT_TABLE_H,X
  STA ZP_SKIN_STATE_PTR+1
  RTS

; -------------------------------------------------------------------
;                           楽譜プロセッサ
; -------------------------------------------------------------------
; input X=0,1,2 A,B,C ch
SHEET_PS:
  ; 楽譜ポインタ作成
  LDA SHEET_PTR_L,X
  STA ZP_SHEET_PTR
  LDA SHEET_PTR_H+1,X
  STA ZP_SHEET_PTR+1
  ; 音色状態構造体ポインタ作成
  ; 特殊音符処理ではいらない気もするがインデックスが楽
  JSR X2SKIN_STATE_PTR
  ; 第1コード取得
  JSR GETBYT_SHEET
  ASL                       ; 左シフト:MSBが飛びインデックスが倍に
  TAX                       ; いずれにせよインデックスアクセスに使う
  BCC SHEET_PS_COMMON_NOTE  ; 一般音符であれば特殊音符処理をスキップ
  ; 特殊音符処理へ移行
  JMP (SPCNOTE_TABLE,X)
SHEET_PS_COMMON_NOTE:
  ; 普通の音符処理
  ; 経過時間リセット
  LDA #0
  LDA SKIN_STATE::TIME
  STA (ZP_SKIN_STATE_PTR),Y
  ; 周波数設定
  LDY #SKIN_STATE::FRQ
  LDA KEY_FRQ_TABLE,X       ; テーブルから周波数を取得 L
  STA (ZP_SKIN_STATE_PTR),Y
  INY
  LDA KEY_FRQ_TABLE+1,X     ; テーブルから周波数を取得 H
  STA (ZP_SKIN_STATE_PTR),Y
  ; タイマーセット
  JSR GETBYT_SHEET          ; LEN取得
  STA LEN_A,X               ; XはJSRでZP_CHになっている
  STA ZP_LEN_CNT_A,X
  RTS

; 楽譜から1バイト取得してポインタを進める
GETBYT_SHEET:
  LDX ZP_CH
  LDA (ZP_SHEET_PTR)  ; バイト取得
  PHA
  ; 作業用ポインタの増加
  SEC
  LDA ZP_SHEET_PTR
  ADC #0
  STA ZP_SHEET_PTR    ; 作業用ポインタ
  STA SHEET_PTR_L,X   ; 保存用ポインタ
  LDA ZP_SHEET_PTR+1
  ADC #0
  STA ZP_SHEET_PTR+1  ; 作業用ポインタ
  STA SHEET_PTR_H,X   ; 保存用ポインタ
  PLA
  RTS

; 休符
SPCNOTE_REST:
;todo

; テンポ変更
SPCNOTE_TEMPO:
;todo

; 相対ジャンプ
SPCNOTE_JMP:
;todo

SKIN0_BETA:
  LDA #15
  LDY #SKIN_STATE::VOL
  STA (ZP_SKIN_STATE_PTR),Y
  LDA #$FF
  RTS

; -------------------------------------------------------------------
;                          ポインタテーブル
; -------------------------------------------------------------------
; 音色状態構造体ポインタテーブル
; 等間隔だけど…
SKIN_STATE_STRUCT_TABLE_L:
  .BYTE <SKIN_STATE_A
  .BYTE <SKIN_STATE_B
  .BYTE <SKIN_STATE_C

SKIN_STATE_STRUCT_TABLE_H:
  .BYTE >SKIN_STATE_A
  .BYTE >SKIN_STATE_B
  .BYTE >SKIN_STATE_C

; 特殊音符処理テーブル
SPCNOTE_TABLE:
  .WORD SPCNOTE_REST
  .WORD SPCNOTE_TEMPO
  .WORD SPCNOTE_JMP

SKIN_TABLE_L:
  .BYTE <SKIN0_BETA

SKIN_TABLE_H:
  .BYTE >SKIN0_BETA

; -------------------------------------------------------------------
;                           データテーブル
; -------------------------------------------------------------------
; https://www.tomari.org/main/java/oto.html
; frq.txtをmakefrq.awkにて処理
KEY_FRQ_TABLE:
.WORD 4545 ; 0 A0
.WORD 4290 ; 1 A#0
.WORD 4049 ; 2 B0
.WORD 3822 ; 3 C1
.WORD 3607 ; 4 C#1
.WORD 3405 ; 5 D1
.WORD 3214 ; 6 D#1
.WORD 3033 ; 7 E1
.WORD 2863 ; 8 F1
.WORD 2702 ; 9 F#1
.WORD 2551 ; 10 G1
.WORD 2407 ; 11 G#1
.WORD 2272 ; 12 A1
.WORD 2145 ; 13 A#1
.WORD 2024 ; 14 B1
.WORD 1911 ; 15 C2
.WORD 1803 ; 16 C#2
.WORD 1702 ; 17 D2
.WORD 1607 ; 18 D#2
.WORD 1516 ; 19 E2
.WORD 1431 ; 20 F2
.WORD 1351 ; 21 F#2
.WORD 1275 ; 22 G2
.WORD 1203 ; 23 G#2
.WORD 1136 ; 24 A2
.WORD 1072 ; 25 A#2
.WORD 1012 ; 26 B2
.WORD 955 ; 27 C3
.WORD 901 ; 28 C#3
.WORD 851 ; 29 D3
.WORD 803 ; 30 D#3
.WORD 758 ; 31 E3
.WORD 715 ; 32 F3
.WORD 675 ; 33 F#3
.WORD 637 ; 34 G3
.WORD 601 ; 35 G#3
.WORD 568 ; 36 A3
.WORD 536 ; 37 A#3
.WORD 506 ; 38 B3
.WORD 477 ; 39 C4
.WORD 450 ; 40 C#4
.WORD 425 ; 41 D4
.WORD 401 ; 42 D#4
.WORD 379 ; 43 E4
.WORD 357 ; 44 F4
.WORD 337 ; 45 F#4
.WORD 318 ; 46 G4
.WORD 300 ; 47 G#4
.WORD 284 ; 48 A4
.WORD 268 ; 49 A#4
.WORD 253 ; 50 B4
.WORD 238 ; 51 C5
.WORD 225 ; 52 C#5
.WORD 212 ; 53 D5
.WORD 200 ; 54 D#5
.WORD 189 ; 55 E5
.WORD 178 ; 56 F5
.WORD 168 ; 57 F#5
.WORD 159 ; 58 G5
.WORD 150 ; 59 G#5
.WORD 142 ; 60 A5
.WORD 134 ; 61 A#5
.WORD 126 ; 62 B5
.WORD 119 ; 63 C6
.WORD 112 ; 64 C#6
.WORD 106 ; 65 D6
.WORD 100 ; 66 D#6
.WORD 94 ; 67 E6
.WORD 89 ; 68 F6
.WORD 84 ; 69 F#6
.WORD 79 ; 70 G6
.WORD 75 ; 71 G#6
.WORD 71 ; 72 A6
.WORD 67 ; 73 A#6
.WORD 63 ; 74 B6
.WORD 59 ; 75 C7
.WORD 56 ; 76 C#7
.WORD 53 ; 77 D7
.WORD 50 ; 78 D#7
.WORD 47 ; 79 E7
.WORD 44 ; 80 F7
.WORD 42 ; 81 F#7
.WORD 39 ; 82 G7
.WORD 37 ; 83 G#7
.WORD 35 ; 84 A7
.WORD 33 ; 85 A#7
.WORD 31 ; 86 B7
.WORD 29 ; 87 C8

