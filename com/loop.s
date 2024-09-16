; -------------------------------------------------------------------
;                           MOVIEコマンド
; -------------------------------------------------------------------
; 連番画像連続表示 無限版
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
  ZP_TMP_X:         .RES 1
  ZP_TMP_Y:         .RES 1
  ZP_TMP_X_DEST:    .RES 1
  ZP_TMP_Y_DEST:    .RES 1
  ZP_READ_VEC16:    .RES 2
  ZP_VISIBLE_FLAME: .RES 1  ; 可視フレーム
  ZP_IMAGE_NUM16:   .RES 2  ; いま何枚目？1..
  ZP_FINFO_SAV:      .RES 2  ; FINFO

; -------------------------------------------------------------------
;                              変数領域
; -------------------------------------------------------------------
.BSS
  TEXT:           .RES 512*IMAGE_BUFFER_SECS
  FD_SAV:         .RES 1  ; ファイル記述子

; -------------------------------------------------------------------
;                             実行領域
; -------------------------------------------------------------------
.macro init_crtc
  ; CRTCを初期化
  LDA #%10000000                  ; ChrBox off
  STA CRTC2::CHRW
  ; コンフィグレジスタの設定
  LDA #(CRTC2::WF|1)              ; f1書き込み
  STA CRTC2::CONF
  LDA #(CRTC2::TT|0)              ; 16色モード
  STA CRTC2::CONF
  LDA #$FF
  JSR FILL                        ; 塗りつぶし
  LDA #(CRTC2::WF|2)              ; f2書き込み
  STA CRTC2::CONF
  LDA #(CRTC2::TT|0)              ; 16色モード
  STA CRTC2::CONF
  LDA #$FF
  JSR FILL                        ; 塗りつぶし
  LDA #(CRTC2::WF|1)              ; f2書き込み
  ; 表示フレーム
  LDA #%01010101                  ; f1表示
  STA ZP_VISIBLE_FLAME
  STA CRTC2::DISP
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
  STZ ZR0
  syscall FS_OPEN                 ; ファイルをオープン
  BCS @NOTFOUND2                    ; オープンできなかったらあきらめる
  STA FD_SAV                      ; ファイル記述子をセーブ
.endmac

.CODE
START:
  cmdline_to_openedfile
@LOOP:
  ; 0へseek
  loadmem16 ZR1,0
  loadmem16 ZR2,0
  LDA FD_SAV
  LDY #BCOS::SEEK_SET
  syscall FS_SEEK
  init_crtc                       ; crtcの初期化
@MOVIE_LOOP:
  ; 書き込み座標リセット
  STZ CRTC2::PTRX
  STZ CRTC2::PTRY
  ; ロード1チャンク目
  LDA FD_SAV
  STA ZR1                         ; 規約、ファイル記述子はZR1！
  loadmem16 ZR0,TEXT              ; 書き込み先
  loadAY16 512*IMAGE_BUFFER_SECS  ; 数セクタをバッファに読み込み
  syscall FS_READ_BYTS            ; ロード
  BCS @LOOP
  STZ CRTC2::PTRX                 ; NOTE:READでなぜか壊れた画面ポインタへの
  STZ CRTC2::PTRY                 ;       アドホックな対処
  JSR DRAW_CHUNK
  ; ロード2チャンク目
  LDA FD_SAV
  STA ZR1                         ; 規約、ファイル記述子はZR1！
  loadmem16 ZR0,TEXT              ; 書き込み先
  loadAY16 512*IMAGE_BUFFER_SECS  ; 数セクタをバッファに読み込み
  syscall FS_READ_BYTS            ; ロード
  STZ CRTC2::PTRX                 ; NOTE:READでなぜか壊れた画面ポインタへの
  LDA #IMAGE_BUFFER_SECS*4        ;       アドホックな対処
  STA CRTC2::PTRY                 ;
  JSR DRAW_CHUNK
@SWAP_FLAME:
  ; フレーム交換
  LDA ZP_VISIBLE_FLAME
  TAX
  AND #%00000011
  ORA #CRTC2::WF
  STA CRTC2::CONF
  TXA
  CLC
  ROL ; %01010101と%10101010を交換する
  ADC #0
  STA ZP_VISIBLE_FLAME
  STA CRTC2::DISP
  ; キー検出
  LDA #BCOS::BHA_CON_RAWIN_NoWaitNoEcho  ; キー入力待機
  syscall CON_RAWIN
  BEQ @MOVIE_LOOP
  ; 最終バイトがあるとき
  ; クローズ
@CLOSE:
  LDA FD_SAV
  syscall FS_CLOSE                ; クローズ
  BCS BCOS_ERROR
  RTS

; 1チャンクをバッファから描画する
DRAW_CHUNK:
  ; バッファ出力
  loadmem16 ZP_READ_VEC16,TEXT
  ; バッファ出力ループ
  LDX #24
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

BCOS_ERROR:
  JSR PRT_LF
  syscall ERR_GET
  syscall ERR_MES
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

; 画面全体をAの値で埋め尽くす
FILL:
  STZ CRTC2::PTRX
  STZ CRTC2::PTRY
  STA CRTC2::WDAT
  LDY #$C0
FILL_LOOP_V:
  LDX #$80
FILL_LOOP_H:
  LDA CRTC2::REPT
  DEX
  BNE FILL_LOOP_H
  DEY
  BNE FILL_LOOP_V
  RTS

STR_NOTFOUND:
  .BYT "Movie Images Not Found.",$A,$0

