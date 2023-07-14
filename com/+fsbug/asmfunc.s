.INCLUDE "../FXT65.inc"
.INCLUDE "../generic.mac"
.INCLUDE "../fscons.inc"
.INCLUDE "../zr.inc"
.INCLUDE "./+fsbug/structfs.s"
.PROC BCOS
  .INCLUDE "../syscall.inc"  ; システムコール番号
.ENDPROC
.INCLUDE "../syscall.mac"

; OS側変数領域
.BSS
  .INCLUDE "./+fsbug/varfs.s"
  .INCLUDE "./+fsbug/varfs2.s"

.ZEROPAGE
  .INCLUDE "./+fsbug/zpfs.s"


.DATA
  _sector_buffer_512:
  SECBF512:       .RES 512  ; SDカード用セクタバッファ

.IMPORT popa, popax
.IMPORTZP sreg

.EXPORT _read_sec
.EXPORT _sector_buffer_512
.EXPORTZP _sdcmdprm,_sdseek

.CODE

.PROC ERR
  .INCLUDE "../errorcode.inc"
REPORT:
  BRK
  NOP
  RTS
.ENDPROC
; -------------------------------------------------------------------
; BCOS 15                大文字小文字変換
; -------------------------------------------------------------------
; input   : A = chr
; -------------------------------------------------------------------
FUNC_UPPER_CHR:
  CMP #'a'
  BMI FUNC15_RTS
  CMP #'z'+1
  BPL FUNC15_RTS
  SEC
  SBC #'a'-'A'
FUNC15_RTS:
  RTS

; -------------------------------------------------------------------
; BCOS 16                大文字小文字変換（文字列）
; -------------------------------------------------------------------
; input   : AY = buf
; -------------------------------------------------------------------
; TODO: もはや""を考慮する必要はない
FUNC_UPPER_STR:
  storeAY16 ZR0
  LDY #$FF
@LOOP:
  INY
  LDA (ZR0),Y
  BEQ FUNC15_RTS
  JSR FUNC_UPPER_CHR
  STA (ZR0),Y
  CMP #'"' ;"
  BNE @LOOP
  ; "
@SKIPLOOP:
  INY
  LDA (ZR0),Y
  CMP #'"' ;"
  BEQ @LOOP
  BRA @SKIPLOOP

FUNC_CON_OUT_CHR:
  PHA
  PHX
  PHY
  syscall CON_OUT_CHR
  PLY
  PLX
  PLA
  RTS

FUNC_CON_OUT_STR:
  PHA
  PHX
  PHY
  syscall CON_OUT_STR
  PLY
  PLX
  PLA
  RTS

  .INCLUDE "./+fsbug/fsmac.mac"
  .PROC SPI
    .INCLUDE "./+fsbug/spi.s"
  .ENDPROC
  .PROC SD
    .INCLUDE "./+fsbug/sd.s"
  .ENDPROC
  .PROC FS
    .INCLUDE "./+fsbug/fs.s"
  .ENDPROC

.PROC _read_sec
  LDA #$81
  STA SDCMD_CRC
  JSR SD::RDSEC
  RTS
.ENDPROC

