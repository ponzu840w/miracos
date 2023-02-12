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
.STRUCT SKIN_WORK
  ; スキンの操作対象データ
  CH                .RES 1  ; チャンネル 0=A 1=B 2=C
  FRQ               .RES 2  ; 周波数
.ENDSTRUCT

; -------------------------------------------------------------------
;                               ZP領域
; -------------------------------------------------------------------
.ZEROPAGE
  ; チャンネル設定
  ZP_TEMPO_A:         .RES 1        ; テンポ倍率保持用
  ZP_TEMPO_B:         .RES 1
  ZP_TEMPO_C:         .RES 1
  ; ダウンカウンタ
  ZP_TEMPO_CNT_A:     .RES 1        ; テンポ倍率カウンタ
  ZP_LEN_CNT_A:       .RES 1        ; 音長カウンタ
  ZP_TEMPO_CNT_B:     .RES 1
  ZP_LEN_CNT_B:       .RES 1
  ZP_TEMPO_CNT_C:     .RES 1
  ZP_LEN_CNT_C:       .RES 1
  ; チャンネル状態
  ZP_CH_STATE:          .RES 1        ; 7|00|c00|b00|a00|0


.SEGMENT "LIB"

; -------------------------------------------------------------------
;                             初期化処理
; -------------------------------------------------------------------
.macro init_se
  ; 本来設定可能であるべきもの
  LDA #15
  STA ZP_ACH_TEMPO  ; テンポ
.endmac

; -------------------------------------------------------------------
;                            ティック処理
; -------------------------------------------------------------------
; カウントダウン・次ノートトリガ・音色ドライブ
.macro tick_ymzq
  tick_ymzq_timer
.endmac

; -------------------------------------------------------------------
;                            変数領域定義
; -------------------------------------------------------------------
; スキンワーク構造体の実体
SKIN_WORK_A:        .TAG SKIN_WORK
SKIN_WORK_B:        .TAG SKIN_WORK
SKIN_WORK_C:        .TAG SKIN_WORK

