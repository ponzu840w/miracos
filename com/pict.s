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
;                              変数領域
; -------------------------------------------------------------------
.BSS
  FD_SAV:         .RES 1  ; ファイル記述子
  FINFO_SAV:      .RES 2  ; FINFO

; -------------------------------------------------------------------
;                             実行領域
; -------------------------------------------------------------------
.CODE
START:
  ; nullチェック
  storeAY16 ZR0
  TAX
  LDA (ZR0)
  BEQ NOTFOUND
  TXA
  ; オープン
  syscall FS_FIND_FST             ; 検索
  BCS NOTFOUND                    ; 見つからなかったらあきらめる
  storeAY16 FINFO_SAV             ; FINFOを格納
  syscall FS_OPEN                 ; ファイルをオープン
  BCS NOTFOUND                    ; オープンできなかったらあきらめる
  STA FD_SAV                      ; ファイル記述子をセーブ
  ; CRTCを初期化
  LDA #%00000001           ; 全内部行を16色モード、書き込みカウントアップ有効、16色モード座標
  STA CRTC::CFG
  STZ CRTC::RF              ; f0を表示
  LDA #$00
  STA ZP_VMAV
  JSR FILL
LOOP:
  ; ロード
  LDA FD_SAV
  STA ZR1                         ; 規約、ファイル記述子はZR1！
  loadmem16 ZR0,TEXT              ; 書き込み先
  loadAY16 512                    ; 1セクタ読み込み
  syscall FS_READ_BYTS            ; ロード
  PHP                             ; 最終バイトがあるかの情報Cを退避
  ; 1セクタ出力
  ; 書き込み座標リセット
  LDA ZP_VMAV
  STA CRTC::VMAV
  LDX #0
  STX CRTC::VMAH
@PICT_LOOP:
  LDA TEXT,X
  STA CRTC::WDBF
  INX
  BNE @PICT_LOOP
@PICT_LOOP2:
  LDA TEXT+256,X
  STA CRTC::WDBF
  INX
  BNE @PICT_LOOP2
  ; 垂直アドレスの更新
  ; 512バイトは4行に相当する
  INC ZP_VMAV
  INC ZP_VMAV
  INC ZP_VMAV
  INC ZP_VMAV
  PLP                             ; 最終バイトがあるか
  BCC LOOP                        ; 最終バイトを含んでいなければ次へ
  ; 最終バイトがあるとき
  ; クローズ
@CLOSE:
  LDA FD_SAV
  syscall FS_CLOSE                ; クローズ
  BCS BCOS_ERROR
  ; キー待機
  LDA #BCOS::BHA_CON_RAWIN_WaitAndNoEcho  ; キー入力待機
  syscall CON_RAWIN
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

; 画像貼り付け
; ZP_TMP_X,Yを起点とし、ZP_TMP_X_DEST,ZP_TMP_Y_DESTは大きさを表す
; FONT_READ_VEC16が画像起点
;DRAW_IMAGE:
;  LDY #0
;DRAW_IMAGE_LOOP_Y:
;  LDX ZP_TMP_X
;  STX CRTC::VMAH
;  LDX ZP_TMP_Y
;  STX CRTC::VMAV
;  LDX #0
;DRAW_IMAGE_LOOP_X:
;  LDA (ZP_READ_VEC16),Y
;  STA CRTC::WDBF
;  INX
;  INY
;  BNE DRAW_IMAGE_SKP0
;  ; 画像データのページ跨ぎ
;  INC ZP_READ_VEC16+1
;DRAW_IMAGE_SKP0:
;  CPX ZP_TMP_X_DEST
;  BNE DRAW_IMAGE_LOOP_X
;  ; 右終端
;  INC ZP_TMP_Y
;  LDA ZP_TMP_Y
;  CMP ZP_TMP_Y_DEST
;  BNE DRAW_IMAGE_LOOP_Y
;  RTS

STR_NOTFOUND:
  .BYT "Input File Not Found.",$A,$0

; -------------------------------------------------------------------
;                             データ領域
; -------------------------------------------------------------------
.DATA
TEXT:
  .RES 512
