; -------------------------------------------------------------------
;                             MKDIR.COM
; -------------------------------------------------------------------
;   ディレクトリを作成する。
; USAGE A:>MAKEDIR A:/HOGE/FUGA # FUGAが作成される
;       A:/HOGE>MAKEDIR FUGA    # 上に同じ
; TODO: 複数引数の連続処理
; -------------------------------------------------------------------
.INCLUDE "../FXT65.inc"
.INCLUDE "../generic.mac"
.INCLUDE "../fs/structfs.s"
.INCLUDE "../fscons.inc"
.PROC BCOS
  .INCLUDE "../syscall.inc"  ; システムコール番号
.ENDPROC
.INCLUDE "../syscall.mac"
.INCLUDE "../zr.inc"          ; ZPレジスタZR0..ZR5

; -------------------------------------------------------------------
;                             実行領域
; -------------------------------------------------------------------
.CODE
START:
  ; ---------------------------------------------------------------
  ;   コマンドライン引数処理
  storeAY16 ZR0                   ; ZR0=arg
  ; nullチェック
  TAX
  LDA (ZR0)
  BEQ NOARG
  TXA
  ; ---------------------------------------------------------------
  ;   ディレクトリ作成
  LDX #DIRATTR_DIRECTORY
  STX ZR0
  syscall FS_MAKE
  BCS BCOS_ERROR
  RTS

; カーネルエラーのとき
BCOS_ERROR:
  LDA #$A
  syscall CON_OUT_CHR
  syscall ERR_GET
  syscall ERR_MES
  RTS

NOARG:
  loadAY16 STR_NOARG
  syscall CON_OUT_STR
  RTS

STR_NOARG:
  .BYTE "[ERR]Insufficient arguments.",$A,$0

