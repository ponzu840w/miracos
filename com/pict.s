; -------------------------------------------------------------------
; 画像ファイルを表示する
; -------------------------------------------------------------------
; ChDzのテスト
; -------------------------------------------------------------------
.INCLUDE "../FXT65.inc"
.INCLUDE "../generic.mac"
.INCLUDE "../fs/structfs.s"
.INCLUDE "../fscons.inc"
.INCLUDE "../zr.inc"
.PROC BCOS
  .INCLUDE "../syscall.inc"  ; システムコール番号
.ENDPROC
.INCLUDE "../syscall.mac"

IMAGE_BUFFER_SECS = 24 ; 何セクタをバッファに使うか？ 48の約数

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
  ZP_FINFO_SAV:   .RES 2  ; FINFO
  ZP_4:           .RES 1

; -------------------------------------------------------------------
;                              変数領域
; -------------------------------------------------------------------
.BSS
  FD_SAV:         .RES 1  ; ファイル記述子

; -------------------------------------------------------------------
;                             マクロ定義
; -------------------------------------------------------------------
.macro check_file_ext
CHECK_FILE_EXT:
  ; 拡張子を確かめる
  ; 拡張子を得る
  LDY #FINFO::NAME
@LOOP:
  INY
  LDA (ZP_FINFO_SAV),Y
  BEQ @FAILURE
  CMP #'.'
  BNE @LOOP
  ; I
  INY
  LDA (ZP_FINFO_SAV),Y
  CMP #'I'
  BNE @FAILURE
  ; M
  INY
  LDA (ZP_FINFO_SAV),Y
  CMP #'M'
  BNE @FAILURE
  ; F
  INY
  LDA (ZP_FINFO_SAV),Y
  CMP #'F'
  BEQ IMF
  ; 4
  CMP #'4'
  BEQ IM4
@FAILURE:
  ; FAILURE
  loadAY16 STR_EXTERR
  syscall CON_OUT_STR
  RTS
.endmac

.macro cmdline_to_openedfile
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
  storeAY16 ZP_FINFO_SAV          ; FINFOを格納
  syscall FS_OPEN                 ; ファイルをオープン
  BCS @NOTFOUND2                    ; オープンできなかったらあきらめる
  STA FD_SAV                      ; ファイル記述子をセーブ
.endmac

; -------------------------------------------------------------------
;                             実行領域
; -------------------------------------------------------------------
.CODE
START:
  cmdline_to_openedfile
  check_file_ext
  ; クローズ
CLOSE_AND_EXIT:
  LDA FD_SAV
  syscall FS_CLOSE                ; クローズ
  BCS BCOS_ERROR
  ; キー待機
  LDA #BCOS::BHA_CON_RAWIN_WaitAndNoEcho  ; キー入力待機
  syscall CON_RAWIN
  RTS

BCOS_ERROR:
  JSR PRT_LF
  syscall ERR_GET
  syscall ERR_MES
  RTS

IMF:
  ; CRTCを初期化
  LDA #(CRTC2::WF|1)              ; f1書き込み
  STA CRTC2::CONF
  LDA #(CRTC2::TT|0)              ; 16色モード
  STA CRTC2::CONF
  LDA #%01010101                  ; f1表示
  STA CRTC2::DISP
  LDA #%10000000                  ; ChrBox off
  STA CRTC2::CHRW
  LDA #$FF
  JSR FILL
  ; 書き込み座標リセット
  STZ CRTC2::PTRX
  STZ CRTC2::PTRY
  JSR CHUNK
  JSR CHUNK
  JMP CLOSE_AND_EXIT

IM4:
  ; CRTCを初期化
  LDA #(CRTC2::TT|0)              ; 16色モード
  STA CRTC2::CONF
  LDA #%00011011                  ; f0123表示
  STA CRTC2::DISP
  LDA #%10000000                  ; ChrBox off
  STA CRTC2::CHRW
  LDA #$FF
  JSR FILL4                       ; 塗りつぶし
  ;0
  LDA #(CRTC2::WF|0)              ; f0書き込み
  JSR IM4_FLAME
  ;1
  LDA #(CRTC2::WF|1)              ; f1書き込み
  JSR IM4_FLAME
  ;2
  LDA #(CRTC2::WF|2)              ; f2書き込み
  JSR IM4_FLAME
  ;3
  LDA #(CRTC2::WF|3)              ; f3書き込み
  JSR IM4_FLAME
  JMP CLOSE_AND_EXIT

IM4_FLAME:
  ; フレームを設定
  STA CRTC2::CONF
  ; 書き込み座標リセット
  STZ CRTC2::PTRX
  STZ CRTC2::PTRY
  JSR CHUNK
  JSR CHUNK
  RTS

; 1チャンクをロードして描画
CHUNK:
  ; ロード
  LDA FD_SAV
  STA ZR1                         ; 規約、ファイル記述子はZR1！
  loadmem16 ZR0,TEXT              ; 書き込み先
  ;loadAY16 512*IMAGE_BUFFER_SECS  ; 数セクタをバッファに読み込み
  loadAY16 512*24
  syscall FS_READ_BYTS            ; ロード
  ; 読み取ったセクタ数をバッファ出力ループのイテレータに
  TYA   ; 上位をAに
  LSR   ; /2
  TAX   ; Xに
  JSR DRAW_SECTORS
  ;debug
    ; キー待機
    ;LDA #BCOS::BHA_CON_RAWIN_WaitAndNoEcho  ; キー入力待機
    ;syscall CON_RAWIN
  RTS

; Xで指定されたセクタ数ぶんをバッファから描画する
DRAW_SECTORS:
  ; バッファ出力
  loadmem16 ZP_READ_VEC16,TEXT
  ; バッファ出力ループ
@BUFFER_LOOP:
  ; 256バイト出力ループx2
  ; 前編
  LDY #0
@PAGE_LOOP:
  LDA (ZP_READ_VEC16),Y
  STA CRTC2::WDAT
  INY
  BNE @PAGE_LOOP
  INC ZP_READ_VEC16+1             ; 読み取りポイント更新
  ; 後編
  LDY #0
@PAGE_LOOP2:
  LDA (ZP_READ_VEC16),Y
  STA CRTC2::WDAT
  INY
  BNE @PAGE_LOOP2
  INC ZP_READ_VEC16+1             ; 読み取りポイント更新
  ; 512バイト出力終了
  DEX
  BNE @BUFFER_LOOP
  RTS

NOTFOUND:
  loadAY16 STR_NOTFOUND
  syscall CON_OUT_STR
  RTS

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

FILL4:
  LDX #(CRTC2::WF|0)
  STX CRTC2::CONF
  JSR FILL
  LDX #(CRTC2::WF|1)
  STX CRTC2::CONF
  JSR FILL
  LDX #(CRTC2::WF|2)
  STX CRTC2::CONF
  JSR FILL
  LDX #(CRTC2::WF|3)
  STX CRTC2::CONF

; 画面全体をAの値で埋め尽くす
FILL:
  STZ CRTC2::PTRX
  STZ CRTC2::PTRY
  STA CRTC2::WDAT
  LDY #$C0
FILL_LOOP_V:
  LDX #$80
FILL_LOOP_H:
  STA CRTC2::REPT
  DEX
  BNE FILL_LOOP_H
  DEY
  BNE FILL_LOOP_V
  RTS

STR_NOTFOUND:
  .BYT "Input File Not Found.",$A,$0

STR_EXTERR:
  .BYT "Only .IMF .IM4 are available extensions.",$A,$0

.BSS
TEXT:
  .RES 512*IMAGE_BUFFER_SECS

