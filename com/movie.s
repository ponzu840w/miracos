; -------------------------------------------------------------------
;                           MOVIEコマンド
; -------------------------------------------------------------------
; 連番画像連続表示
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

IMAGE_BUFFER_SECS = 32 ; 何セクタをバッファに使うか？ 48の約数

; -------------------------------------------------------------------
;                               ZP領域
; -------------------------------------------------------------------
.ZEROPAGE
  ZP_TMP_X:         .RES 1
  ZP_TMP_Y:         .RES 1
  ZP_TMP_X_DEST:    .RES 1
  ZP_TMP_Y_DEST:    .RES 1
  ZP_READ_VEC16:    .RES 2
  ZP_VMAV:          .RES 1
  ZP_VISIBLE_FLAME: .RES 1  ; 可視フレーム
  ZP_IMAGE_NUM16:   .RES 2  ; いま何枚目？1..

; -------------------------------------------------------------------
;                              変数領域
; -------------------------------------------------------------------
.BSS
  TEXT:           .RES 512*IMAGE_BUFFER_SECS
  FD_SAV:         .RES 1  ; ファイル記述子
  FINFO_SAV:      .RES 2  ; FINFO

; -------------------------------------------------------------------
;                             実行領域
; -------------------------------------------------------------------
.macro init_crtc
  ; CRTCを初期化
  ; コンフィグレジスタの設定
  LDA #%00000001            ; 全内部行を16色モード、書き込みカウントアップ有効、16色モード座標
  STA CRTC::CFG
  ; 塗りつぶし
  ; f0
  STZ CRTC::WF
  LDA #$FF
  JSR FILL
  ; f1
  LDA #$1
  STA CRTC::WF
  LDA #$FF
  JSR FILL
  ; 表示フレーム
  LDA #%01010101
  STA ZP_VISIBLE_FLAME
  STA CRTC::RF
  ; 書き込みフレーム
  LDA #%10101010
  STA CRTC::WF
.endmac

.CODE
START:
  ; コマンドライン引数を受け付けない
  ; 初期化
  init_crtc                       ; crtcの初期化
@MOVIE_LOOP:
  loadmem16 ZP_IMAGE_NUM16,0001   ; 0001から始める
  LDA #'0'
  STA PATH_FNAME
  STA PATH_FNAME+1
  STA PATH_FNAME+2
  INC
  STA PATH_FNAME+3
  ; ファイルオープン
@NEXT_IMAGE:
  loadAY16 PATH_FNAME
  syscall FS_FIND_FST             ; 検索
  BCC @SKP_NOTFOUND2
@NOTFOUND2:
  ; 画像ファイルが見つからない！
  DEC ZP_IMAGE_NUM16              ; 一桁目をデクリメント
  LDA ZP_IMAGE_NUM16
  ORA ZP_IMAGE_NUM16+1            ; 二桁目とOR
  BNE @MOVIE_LOOP                 ; 途中で途切れたのであればループする
  JMP NOTFOUND                    ; 0001が見つからないのであればこの世の終わり
@SKP_NOTFOUND2:
  ; 画像ファイルが存在する！
  storeAY16 FINFO_SAV             ; FINFOを格納
  syscall FS_OPEN                 ; ファイルをオープン
  BCS @NOTFOUND2                  ; オープンできなかったらあきらめる
  STA FD_SAV                      ; ファイル記述子をセーブ
  STZ ZP_VMAV
@IMAGE_LOOP:
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
  BRA @IMAGE_LOOP
  ; 最終バイトがあるとき
  ; クローズ
@CLOSE:
  LDA FD_SAV
  syscall FS_CLOSE                ; クローズ
  BCS BCOS_ERROR
  ; キー待機
  ;LDA #BCOS::BHA_CON_RAWIN_WaitAndNoEcho  ; キー入力待機
  ;syscall CON_RAWIN
  ;RTS
@PICINC:
  ; 探す画像の番号を増やす
  INC ZP_IMAGE_NUM16
  BNE @SKP_IMAGENUMH
  INC ZP_IMAGE_NUM16+1
@SKP_IMAGENUMH:
  LDY #4
  loadmem16 ZR0,(PATH_FNAME-1)
  LDA #1
  JSR D_ADD_BYT
@SWAP_FLAME:
  ; フレーム交換
  LDA ZP_VISIBLE_FLAME
  STA CRTC::WF
  CLC
  ROL ; %01010101と%10101010を交換する
  ADC #0
  STA ZP_VISIBLE_FLAME
  STA CRTC::RF
  JMP @NEXT_IMAGE

D_ADD_BYT:
  ; Y桁の十進数にアキュムレータを足す
  CLC
@LOOP:
  ADC (ZR0),Y
  CLC
  CMP #'9'+1
  BNE @skpyon
  SEC
  LDA #'0'
@skpyon:
  STA (ZR0),Y
  LDA #0
  DEY
  BNE @LOOP
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
  LDY #$00
  STY CRTC::VMAV
  STY CRTC::VMAH
  LDY #$C0
FILL_LOOP_V:
  LDX #$80
FILL_LOOP_H:
  STA CRTC::WDBF
  DEX
  BNE FILL_LOOP_H
  DEY
  BNE FILL_LOOP_V
  RTS

STR_NOTFOUND:
  .BYT "Movie Images Not Found.",$A,$0

PATH_FNAME:
  .BYT "0001.???",$0

