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
;                             変数領域
; -------------------------------------------------------------------
.BSS
  FD_SAV:         .RES 1  ; ファイル記述子
  FINFO_SAV:      .RES 2  ; FINFO

; -------------------------------------------------------------------
;                             実行領域
; -------------------------------------------------------------------
.CODE
START:
  ;pushAY16                       ; デバッグ情報
  ;loadAY16 STR_FILE
  ;syscall CON_OUT_STR
  ;pullAY16
  ;pushAY16
  ;syscall CON_OUT_STR
  ;JSR PRT_LF
  ;pullAY16
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
  ;JSR PRT_BYT
  ;JSR PRT_LF
LOOP:
  ; ロード
  LDA FD_SAV
  STA ZR1                         ; 規約、ファイル記述子はZR1！
  loadmem16 ZR0,TEXT              ; 書き込み先
  loadAY16 256
  syscall FS_READ_BYTS            ; ロード
  PHP                             ; 最終バイトがあるかの情報Cを退避
  ; 1ページ出力
  loadAY16 TEXT
  syscall CON_OUT_STR
  PLP                             ; 最終バイトがあるか
  BCC LOOP                        ; 最終バイトを含んでいなければ次へ
  ; 最終バイトがあるとき
  ; クローズ
@CLOSE:
  LDA FD_SAV
  syscall FS_CLOSE                ; クローズ
  BCS BCOS_ERROR
  ;loadAY16 STR_EOF               ; debug EOF表示
  ;syscall CON_OUT_STR
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
; TMP_X,Yを起点とし、TMP_X_DEST,TMP_Y_DESTは大きさを表す
; FONT_READ_VEC16が画像起点
DRAW_IMAGE:
  LDY #0
DRAW_IMAGE_LOOP_Y:
  LDX TMP_X
  STX CRTC::VMAH
  LDX TMP_Y
  STX CRTC::VMAV
  LDX #0
DRAW_IMAGE_LOOP_X:
  LDA (FONT_READ_VEC16),Y
  STA CRTC::WDBF
  INX
  INY
  BNE DRAW_IMAGE_SKP0
  ; 画像データのページ跨ぎ
  INC FONT_READ_VEC16+1
DRAW_IMAGE_SKP0:
  CPX TMP_X_DEST
  BNE DRAW_IMAGE_LOOP_X
  ; 右終端
  INC TMP_Y
  LDA TMP_Y
  CMP TMP_Y_DEST
  BNE DRAW_IMAGE_LOOP_Y
  RTS

STR_NOTFOUND:
  .BYT "Input File Not Found.",$A,$0

; -------------------------------------------------------------------
;                             データ領域
; -------------------------------------------------------------------
.DATA
TEXT:

