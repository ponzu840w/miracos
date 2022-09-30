; -------------------------------------------------------------------
;  画像ファイルを表示する
; -------------------------------------------------------------------
IMAGE_BUFFER_SECS = 2 ; 何セクタをバッファに使うか？ 48の約数
; -------------------------------------------------------------------
;                              変数領域
; -------------------------------------------------------------------
.BSS
  FD_SAV:         .RES 1  ; ファイル記述子
  FINFO_SAV:      .RES 2  ; FINFO
TEXT:
  .RES 512*IMAGE_BUFFER_SECS

; -------------------------------------------------------------------
;                               ZP領域
; -------------------------------------------------------------------
.ZEROPAGE
  ZP_TMP_X:       .RES 1
  ZP_TMP_Y:       .RES 1
  ZP_TMP_X_DEST:  .RES 1
  ZP_TMP_Y_DEST:  .RES 1
  ZP_READ_VEC16:  .RES 2
  ZP_VMAV:        .RES 1

; -------------------------------------------------------------------
;                             実行領域
; -------------------------------------------------------------------
.SEGMENT "LIB"
PRINT_IMF:
  ; nullチェック
  storeAY16 ZR0
  TAX
  LDA (ZR0)
  BNE @SKP_NOTFOUND
@NOTFOUND2:
  JMP NOTFOUND
@SKP_NOTFOUND:
  TXA
  ; オープン
  syscall FS_FIND_FST             ; 検索
  BCS @NOTFOUND2                  ; 見つからなかったらあきらめる
  storeAY16 FINFO_SAV             ; FINFOを格納
  syscall FS_OPEN                 ; ファイルをオープン
  BCS NOTFOUND                    ; オープンできなかったらあきらめる
  STA FD_SAV                      ; ファイル記述子をセーブ
;  ; CRTCを初期化
;  LDA #%00000001           ; 全内部行を16色モード、書き込みカウントアップ有効、16色モード座標
;  STA CRTC::CFG
;  STZ CRTC::RF              ; f0を表示
  LDA #$00
  STA ZP_VMAV
;  JSR FILL
LOOP:
  ; ロード
  LDA FD_SAV
  STA ZR1                         ; 規約、ファイル記述子はZR1！
  loadmem16 ZR0,TEXT              ; 書き込み先
  loadAY16 512*IMAGE_BUFFER_SECS  ; 数セクタをバッファに読み込み
  syscall FS_READ_BYTS            ; ロード
  BCS @CLOSE
  ; 読み取ったセクタ数をバッファ出力ループのイテレータに
  TYA
  LSR
  TAX
  ; バッファ出力
  ; 書き込み座標リセット
  LDA ZP_VMAV
  STA CRTC::VMAV
  STZ CRTC::VMAH
  loadmem16 ZP_READ_VEC16, TEXT
  ; バッファ出力ループ
  ;LDX #IMAGE_BUFFER_SECS
@BUFFER_LOOP:
  ; 256バイト出力ループx2
  ; 前編
  LDY #0
@PAGE_LOOP:
  LDA (ZP_READ_VEC16),Y
  STA CRTC::WDBF
  INY
  BNE @PAGE_LOOP
  INC ZP_READ_VEC16+1             ; 読み取りポイント更新
  ; 後編
  LDY #0
@PAGE_LOOP2:
  LDA (ZP_READ_VEC16),Y
  STA CRTC::WDBF
  INY
  BNE @PAGE_LOOP2
  INC ZP_READ_VEC16+1             ; 読み取りポイント更新
  ; 512バイト出力終了
  DEX
  BNE @BUFFER_LOOP
  ; バッファ出力終了
  ; 垂直アドレスの更新
  ; 512バイトは4行に相当する
  CLC
  LDA ZP_VMAV
  ADC #4*IMAGE_BUFFER_SECS
  STA ZP_VMAV
  BRA LOOP
  ; 最終バイトがあるとき
  ; クローズ
@CLOSE:
  LDA FD_SAV
  syscall FS_CLOSE                ; クローズ
  BCS BCOS_ERROR
  RTS

NOTFOUND:
  loadAY16 STR_NOTFOUND
  syscall CON_OUT_STR
  RTS

BCOS_ERROR:
  JSR PRT_LF
  syscall ERR_GET
  syscall ERR_MES
  JMP LOOP

;PRT_BYT:
;  JSR BYT2ASC
;  PHY
;  JSR PRT_C_CALL
;  PLA
PRT_C_CALL:
  syscall CON_OUT_CHR
  RTS

PRT_LF:
  ; 改行
  LDA #$A
  JMP PRT_C_CALL

STR_NOTFOUND:
  .BYT "Input File Not Found.",$A,$0

