; -------------------------------------------------------------------
; LOAD.COM
; -------------------------------------------------------------------
; SDカード上のファイルをメモリ上にロードする
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
  BNE @SKP_NOTFOUND
@NOTFOUND2:
  JMP NOTFOUND
@SKP_NOTFOUND:
  TXA

  ; オープン
  syscall FS_FIND_FST             ; 検索
  BCS @NOTFOUND2                  ; 見つからなかったらあきらめる
  storeAY16 FINFO_SAV             ; FINFOを格納
  STZ ZR0
  syscall FS_OPEN                 ; ファイルをオープン
  BCS NOTFOUND                    ; オープンできなかったらあきらめる
  STA FD_SAV                      ; ファイル記述子をセーブ

  ; ロード
  LDA FD_SAV
  STA ZR1                         ; ZR1:ファイル記述子
  loadmem16 ZR0,$1000             ; ZR0:書き込み先
  loadAY16 $FFFF                 ; AY:サイズ・数セクタをバッファに読み込み
  syscall FS_READ_BYTS            ; ロード
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

STR_NOTFOUND:
  .BYT "Input File Not Found.",$A,$0

