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
  ;CH                .RES 1  ; チャンネル 0=A 1=B 2=C
  FRQ               .RES 2  ; 周波数
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
  ;
  ZP_TIEMR_WORK:      .RES 1
  ; 楽譜ポインタ
  ZP_SEET_PTR:        .RES 2
  ; 音色状態構造体ポインタ
  ZP_SKIN_STATE_PTR:  .RES 2

; -------------------------------------------------------------------
;                            変数領域定義
; -------------------------------------------------------------------
.BSS
  ; 音色状態構造体の実体
  SKIN_STATE_A:       .TAG SKIN_STATE
  SKIN_STATE_B:       .TAG SKIN_STATE
  SKIN_STATE_C:       .TAG SKIN_STATE
  ; 楽譜ポインタ
  SEET_PTR_L:         .RES 3        ; A,B,C それぞれのL
  SEET_PTR_H:         .RES 3
  ; チャンネル設定
  TEMPO_A:            .RES 1        ; テンポ倍率保持用
  TEMPO_B:            .RES 1
  TEMPO_C:            .RES 1

.SEGMENT "LIB"

; -------------------------------------------------------------------
;                             初期化処理
; -------------------------------------------------------------------
.macro init_ymzq
  ; 本来設定可能であるべきもの
  LDA #15
  STA ZP_TEMPO_A  ; テンポ
  ;todo
.endmac

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
  LSR ZP_TIEMR_WORK     ; C=Ch有効/無効
  BCC @TIMER_NEXT_CH    ; 無効Chのカウントダウンをスキップ
  DEC ZP_LEN_CNT_A,X    ; 音長カウントダウン
  BNE @TIMER_NEXT_CH    ; 何もなければ次
  ; カウンタ0到達
  LDA ZP_TEMPO_CNT_A,X  ; テンポカウンタの取得
  BNE @SKP_FIRE         ; ゼロでなければ発火しない
  ; 発火
  PHX
  JSR SEET_PS
  PLX
  BRA @TIMER_NEXT_CH
@SKP_FIRE:
  DEC A                 ; テンポカウンタ減算
  LDA ZP_TEMPO_A,X      ; 定義テンポをカウンタに格納
  STA ZP_TEMPO_CNT_A,X
@TIMER_NEXT_CH:
  INX
  CPX #3
  BNE @TIMER_LOOP
  ; ---------------------------------------------------------------
  ;   DRIVE SKIN
  ; todo
.endmac

; -------------------------------------------------------------------
;                           楽譜プロセッサ
; -------------------------------------------------------------------
; input X=0,1,2 A,B,C ch
SHEET_PS:
  ; 楽譜ポインタ作成
  LDA SEET_PTR_L,X
  STA ZP_SEET_PTR
  LDA SEET_PTR_H+1,X
  STA ZP_SEET_PTR+1
  ; 第1コード取得
  LDA (ZP_SEET_PTR)
  ASL                       ; 左シフト:MSBが飛びインデックスが倍に
  TAX                       ; いずれにせよインデックスアクセスに使う
  BCC SHEET_PS_COMMON_NOTE  ; 一般音符であれば特殊音符処理をスキップ
  ; 特殊音符処理へ移行
  JMP (SPCNOTE_TABLE,X)
SHEET_PS_COMMON_NOTE:
  ; 普通の音符処理
  ; 音色状態構造体ポインタ作成
  LDA SKIN_STATE_STRUCT_TABLE,X
  STA ZP_SEET_PTR
  LDA SKIN_STATE_STRUCT_TABLE+1,X
  STA ZP_SEET_PTR+1
  ; 周波数設定
  LDY SKIN_STATE::FRQ
  LDA KEY_FRQ_TABLE,X       ; テーブルから周波数を取得 L
  STA (ZP_SEET_PTR),Y
  INY
  LDA KEY_FRQ_TABLE+1,X     ; テーブルから周波数を取得 H
  STA (ZP_SEET_PTR),Y
  ; タイマーセット
  INC ZP_SEET_PTR
  ;todo
  RTS

; 楽譜ポインタを一つ進める
INC_SEET_PTR:
; todo
  RTS

; 音色状態構造体ポインタテーブル
; 等間隔だけど…
SKIN_STATE_STRUCT_TABLE:
  .BYTE SKIN_STATE_A
  .BYTE SKIN_STATE_B
  .BYTE SKIN_STATE_C

; 特殊音符処理テーブル
SPCNOTE_TABLE:
  .WORD SPCNOTE_REST
  .WORD SPCNOTE_TEMPO
  .WORD SPCNOTE_BRA_S

; 休符
SPCNOTE_REST:
;todo

; テンポ変更
SPCNOTE_TEMPO:
;todo

; 相対ジャンプ
SPCNOTE_JMP:
;todo

; -------------------------------------------------------------------
;                           データテーブル
; -------------------------------------------------------------------
; https://www.tomari.org/main/java/oto.html
; frq.txtをmakefrq.awkにて処理
KEY_FRQ_TABLE:
.WORD 4545 ;A0
.WORD 4290 ;A#0
.WORD 4049 ;B0
.WORD 3822 ;C1
.WORD 3607 ;C#1
.WORD 3405 ;D1
.WORD 3214 ;D#1
.WORD 3033 ;E1
.WORD 2863 ;F1
.WORD 2702 ;F#1
.WORD 2551 ;G1
.WORD 2407 ;G#1
.WORD 2272 ;A1
.WORD 2145 ;A#1
.WORD 2024 ;B1
.WORD 1911 ;C2
.WORD 1803 ;C#2
.WORD 1702 ;D2
.WORD 1607 ;D#2
.WORD 1516 ;E2
.WORD 1431 ;F2
.WORD 1351 ;F#2
.WORD 1275 ;G2
.WORD 1203 ;G#2
.WORD 1136 ;A2
.WORD 1072 ;A#2
.WORD 1012 ;B2
.WORD 955 ;C3
.WORD 901 ;C#3
.WORD 851 ;D3
.WORD 803 ;D#3
.WORD 758 ;E3
.WORD 715 ;F3
.WORD 675 ;F#3
.WORD 637 ;G3
.WORD 601 ;G#3
.WORD 568 ;A3
.WORD 536 ;A#3
.WORD 506 ;B3
.WORD 477 ;C4
.WORD 450 ;C#4
.WORD 425 ;D4
.WORD 401 ;D#4
.WORD 379 ;E4
.WORD 357 ;F4
.WORD 337 ;F#4
.WORD 318 ;G4
.WORD 300 ;G#4
.WORD 284 ;A4
.WORD 268 ;A#4
.WORD 253 ;B4
.WORD 238 ;C5
.WORD 225 ;C#5
.WORD 212 ;D5
.WORD 200 ;D#5
.WORD 189 ;E5
.WORD 178 ;F5
.WORD 168 ;F#5
.WORD 159 ;G5
.WORD 150 ;G#5
.WORD 142 ;A5
.WORD 134 ;A#5
.WORD 126 ;B5
.WORD 119 ;C6
.WORD 112 ;C#6
.WORD 106 ;D6
.WORD 100 ;D#6
.WORD 94 ;E6
.WORD 89 ;F6
.WORD 84 ;F#6
.WORD 79 ;G6
.WORD 75 ;G#6
.WORD 71 ;A6
.WORD 67 ;A#6
.WORD 63 ;B6
.WORD 59 ;C7
.WORD 56 ;C#7
.WORD 53 ;D7
.WORD 50 ;D#7
.WORD 47 ;E7
.WORD 44 ;F7
.WORD 42 ;F#7
.WORD 39 ;G7
.WORD 37 ;G#7
.WORD 35 ;A7
.WORD 33 ;A#7
.WORD 31 ;B7
.WORD 29 ;C8

