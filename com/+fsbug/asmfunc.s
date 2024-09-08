DEBUGBUILD = 1
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
BASE: .RES 2

.ZEROPAGE
  .INCLUDE "./+fsbug/zpfs.s"
SETTING:              .RES 1
ZP_CONCFG_ADDR16:     .RES 2  ; 取得した設定値のアドレス
ZP_CONCFG_SAV:        .RES 1
LAST_ERROR:           .RES 1

.DATA
;  _sector_buffer_512:
;SECBF512:       .RES 512  ; SDカード用セクタバッファ
_finfo_wk=FINFO_WK
_fwk=FWK
_fwk_real_sec=FWK_REAL_SEC
_fd_table=FD_TABLE
_fctrl_res=FCTRL_RES

.IMPORT popa, popax
.IMPORTZP sreg

.EXPORT _read_sec_raw,_dump,_setGCONoff,_restoreGCON,_write_sec_raw,_makef,_open,_read,_write,_search_open,_maked
.EXPORT _finfo_wk,_fwk,_fd_table,_fctrl_res,_delete,_find_fst,_find_nxt
.EXPORT _seek
.EXPORTZP _sdcmdprm,_sdseek
.CONSTRUCTOR INIT

.PROC CONDEV
  ; ZP_CON_DEV_CFGでのコンソールデバイス
  UART_IN   = %00000001
  UART_OUT  = %00000010
  PS2       = %00000100
  GCON      = %00001000
.ENDPROC

SECBF512=$300
DRV0=$514

.CODE

.PROC _setGCONoff
  LDA (ZP_CONCFG_ADDR16)
  STA ZP_CONCFG_SAV
  AND #%11110111
  STA (ZP_CONCFG_ADDR16)
  RTS
.ENDPROC

.PROC _restoreGCON
  LDA ZP_CONCFG_SAV
  STA (ZP_CONCFG_ADDR16)
  RTS
.ENDPROC

.PROC ERR
  .INCLUDE "../errorcode.inc"
REPORT:
  STA LAST_ERROR
  SEC
  RTS
.ENDPROC

FUNC_CON_RAWIN:
  PHX
  syscall CON_RAWIN
  PLX
  RTS

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

; コンストラクタ
.SEGMENT "ONCE"
INIT:
  ; CONDEV
  LDY #BCOS::BHY_GET_ADDR_condevcfg   ; コンソールデバイス設定のアドレスを要求
  syscall GET_ADDR                    ; アドレス要求
  storeAY16 ZP_CONCFG_ADDR16          ; アドレス保存
  ; CRC
  LDA #$91
  STA SDCMD_CRC
  ; FS
  JSR FS::INIT
  ; DRV
  STZ DWK_CUR_DRV
  JSR FS::LOAD_DWK
  RTS

.CODE
.PROC _read_sec_raw
  JSR SD::RDSEC
  RTS
.ENDPROC

.PROC _write_sec_raw
  JSR SD::WRSEC
  RTS
.ENDPROC

;.PROC _path2finfo
;  ; ニンジャをすべて殺す
;  PHX
;  PLY
;  JSR FS::PATH2FINFO
;  LDA ZR2
;  LDX ZR2+1
;  RTS
;.ENDPROC

.PROC _makef
  PHX
  PLY
  STZ ZR0
  JSR FS::FUNC_FS_MAKE
  BCC @END
  syscall ERR_GET
  syscall ERR_MES
@END:
  RTS
.ENDPROC

.PROC _maked
  PHX
  PLY
  TAX
  LDA #DIRATTR_DIRECTORY
  STA ZR0
  TXA
  JSR FS::FUNC_FS_MAKE
  BCC @END
  syscall ERR_GET
  syscall ERR_MES
@END:
  RTS
.ENDPROC

.PROC _open
  STA ZR0
  JSR popax
  PHX
  PLY
  JSR FS::FUNC_FS_OPEN
  BCC @END
  syscall ERR_GET
  syscall ERR_MES
@END:
  RTS
.ENDPROC

; unsigned int read(unsigned char fd, unsigned char *buf, unsigned int count);
.PROC _read
  pushAX16
  JSR popax
  storeAX16 ZR0
  JSR popa
  STA ZR1
  pullAY16
  JSR FS::FUNC_FS_READ_BYTS
  BCC @END
  syscall ERR_GET
  syscall ERR_MES
@END:
  PHY
  PLX
  RTS
.ENDPROC

; unsigned int write(unsigned char fd, unsigned char *buf, unsigned int count);
.PROC _write
  pushAX16
  JSR popax
  storeAX16 ZR0
  JSR popa
  STA ZR1
  pullAY16
  JSR FS::FUNC_FS_WRITE
  BCC @END
  syscall ERR_GET
  syscall ERR_MES
@END:
  PHY
  PLX
  RTS
.ENDPROC

; void del()
.PROC _delete
  PHX
  PLY
  JSR FS::FUNC_FS_DELETE
  BCC @END
  loadreg16 $DEAD
  BRK
  NOP
@END:
  RTS
.ENDPROC

.PROC _search_open
  ; ---------------------------------------------------------------
  ;   コマンドライン引数処理
  storeAX16 ZR0                   ; ZR0=arg
  ; nullチェック
  LDA (ZR0)
  BEQ NOTFOUND
  mem2AY16 ZR0
  ; ---------------------------------------------------------------
  ;   ファイルオープン
  BRK
  NOP
  JSR FS::FUNC_FS_FIND_FST            ; 検索
  BCS NOTFOUND                    ; 見つからなかったらあきらめる
  BRK
  NOP
  JSR FS::FUNC_FS_OPEN                ; ファイルをオープン
  BCS NOTFOUND                    ; オープンできなかったらあきらめる
  BRK
  NOP
  RTS
NOTFOUND:
  loadAY16 STR_NF
  JSR FUNC_CON_OUT_STR
  RTS
STR_NF:
  .BYTE "File Not Found.",$A,$0
.ENDPROC

; -------------------------------------------------------------------
;                            fs_find_fst
; パス文字列から新たなFINFO構造体を得る
; -------------------------------------------------------------------
.proc _find_fst: near          ; 引数: AX=パス文字列
  PHX
  PLY
  JSR FS::FUNC_FS_FIND_FST            ; 検索
  PHY
  PLX
  BCC @FOUND
  LDA #$0
  TAX
@FOUND:
  RTS
.endproc

; -------------------------------------------------------------------
;                            fs_find_nxt
; -------------------------------------------------------------------
; void* fs_find_nxt(void* finfo, char* name)
.proc _find_nxt: near          ; 引数: AX=ファイル名, スタック=FINFO
  STA $0
  STX $0+1
  JSR popax
  PHX
  PLY
  JSR FS::FUNC_FS_FIND_NXT            ; 検索
  PHY
  PLX
  BCC @FOUND
  LDA #$0
  TAX
@FOUND:
  RTS
.endproc

; -------------------------------------------------------------------
;                            fs_seek
; -------------------------------------------------------------------
; unsigned long fs_seek(unsigned char fd, unsigned char mode, unsigned long offset)
.proc _seek: near           ; 引数: AX+sreg=offset, スタック=mode,fd
  PHY
  storeAX16 ZR1             ; ZR12=offset
  mem2mem16 ZR2, sreg
  JSR popa                  ; Y=mode
  TAY
  JSR popa                  ; A=fd
  JSR FS::FUNC_FS_SEEK      ; 検索
  BCC @END
  syscall ERR_GET
  syscall ERR_MES
@END:
  mem2mem16 sreg, ZR2       ; AX+sreg=offset
  mem2AX16 ZR1
  PLY
  RTS
.endproc

; void dump(boolean wide, unsigned int from, unsigned int to, unsigned int base);

; -------------------------------------------------------------------
;                       dコマンド メモリダンプ
; -------------------------------------------------------------------
;   第1引数から第2引数までをダンプ表示
;   第2引数がなければ第1引数から256バイト
; -------------------------------------------------------------------
.PROC _dump
  ZR2_TO=ZR2
  ZR4_FROM=ZR4
  ZR5_OFST=ZR5
  ; ---------------------------------------------------------------
  ;   引数格納
  storeAX16 ZR5_OFST
  JSR popax
  storeAX16 ZR2_TO
  JSR popax
  storeAX16 ZR4_FROM
  JSR popa  ; WIDE
  CMP #0

  BNE @SKP_INITWIDE
  SMB0 SETTING
  ;LDA #%00000011 ; only UART
  ;STA ZP_CON_DEV_CFG
  ;STA (ZP_CONCFG_ADDR16)
  BRA DUMP1
@SKP_INITWIDE:
  RMB0 SETTING
DUMP1:
  ; ---------------------------------------------------------------
  ;   ループ
@LINE:
  ; アドレス表示部すっ飛ばすか否かの判断
  BBS0 SETTING,@PRT_ADDR ; ワイドモード:アドレス毎行表示
  DEC ZR3
  BNE @DATA
@SET_ZR3:
  LDA #4
  STA ZR3
  ; ---------------------------------------------------------------
  ;   アドレス表示部
  ;"<1234>--------------------------"
  JSR PRT_LF            ; 視認性向上のための空行は行の下にした方がよさそうだが、
@PRT_ADDR:              ;   最大の情報を表示しつつ作業用コマンドラインを出すにはこうする。

  ;JSR PRT_ZR4_ZDDR      ; <1234>_:mコマンドと共用
; d,mで共用のアドレス表示部
;PRT_ZR4_ZDDR:
  JSR PRT_LF
  LDA #'<'              ; アドレス左修飾
  JSR FUNC_CON_OUT_CHR
  LDA ZR5_OFST+1        ; アドレス上位
  JSR PRT_BYT
  LDA ZR5_OFST
  JSR PRT_BYT
  LDA #'>'              ; アドレス右修飾
  JSR FUNC_CON_OUT_CHR
  JSR PRT_S
  ;RTS

  BBS0 SETTING,@DATA_NOLF    ; ワイドモード:ハイフンスキップ
  LDA #'-'
  LDX #32-(4+2+1)       ; 画面幅からこれまで表示したものを減算
  JSR PRT_FEW_CHARS     ; 画面右までハイフン
  ; ---------------------------------------------------------------
  ;   データ表示部
@DATA:
  JSR PRT_LF
@DATA_NOLF:
  ;loadmem16 DUMP_SUB_FUNCPTR,DUMP_SUB_DATA
  pushmem16 ZR4_FROM
  pushmem16 ZR5_OFST
  LDA #<(DUMP_SUB_DATA-(DUMP_SUB_BRA+2))
  JSR DUMP_SUB
  BEQ @SKP_PADDING
  ; 一部のみ表示したときの空白
@PADDING_LOOP:
  DEX
  BEQ @SKP_PADDING
  PHX
  JSR PRT_S
  JSR PRT_S
  JSR PRT_S
  PLX
  BRA @PADDING_LOOP
@SKP_PADDING:
  ; ---------------------------------------------------------------
  ;   ASCII表示部
  ;loadmem16 DUMP_SUB_FUNCPTR,DUMP_SUB_ASCII
  pullmem16 ZR5_OFST
  pullmem16 ZR4_FROM
  LDA #<(DUMP_SUB_ASCII-(DUMP_SUB_BRA+2))
  JSR DUMP_SUB
  BEQ @LINE
@END:
  JSR PRT_LF
  RTS

; ポインタ切り替えでHEXかASCIIを表示する
DUMP_SUB:
  STA DUMP_SUB_BRA+1
  BBS0 SETTING,@SKP8  ; ワイドモード:1行16バイト
  LDX #8              ; X=行ダウンカウンタ
  BRA DATALOOP
@SKP8:
  LDX #16
DATALOOP:
  LDA (ZR4_FROM)     ; バイト取得
  PHX
  ;JMP (DUMP_SUB_FUNCPTR)
DUMP_SUB_BRA:
  .BYTE $80 ; BRA
  .BYTE $00
DUMP_SUB_RETURN:
  PLX
  ; 終了チェック
  LDA ZR4_FROM+1
  CMP ZR2_TO+1
  BNE @SKP_ENDCHECK_LOW
  LDA ZR4_FROM
  CMP ZR2_TO
  BEQ @END_DATALOOP
@SKP_ENDCHECK_LOW:
  inc16 ZR4_FROM   ; アドレスインクリメント
  inc16 ZR5_OFST
  DEX
  BNE DATALOOP
@END_DATALOOP:      ; 到達時点でX=0なら8バイト表示した、それ以外ならのこったバイト数+1
  CPX #0            ; 終了z、途中Z
  RTS

DUMP_SUB_DATA:
  JSR PRT_BYT_S
  BRA DUMP_SUB_RETURN
DUMP_SUB_ASCII:
@ASCIILOOP:
  CMP #$20
  BCS @SKP_20   ; 20以上
  LDA #'.'
@SKP_20:
  CMP #$7F
  BCC @SKP_7F   ; 7F未満
  LDA #'.'
@SKP_7F:
  JSR FUNC_CON_OUT_CHR
  BRA DUMP_SUB_RETURN
.ENDPROC

FUNC_CON_OUT_CHR:
  syscall CON_OUT_CHR
  RTS

FUNC_CON_OUT_STR:
  STA AAAA
  pushmem16 ZR5
  LDA AAAA
  syscall CON_OUT_STR
  pullmem16 ZR5
  RTS

AAAA:
.RES 1

; -------------------------------------------------------------------
;                          汎用関数群
; -------------------------------------------------------------------
; どうする？ライブラリ？システムコール？
; -------------------------------------------------------------------
PRT_BYT:
  JSR BYT2ASC
  PHY
  JSR PRT_C_CALL
  PLA
PRT_C_CALL:
  JSR FUNC_CON_OUT_CHR
  RTS

PRT_LF:
  ; 改行
  LDA #$A
  BRA PRT_C_CALL

PRT_BYT_S:
  JSR PRT_BYT
PRT_S:
  ; スペース
  LDA #' '
  BRA PRT_C_CALL

PRT_FEW_CHARS:
  ; Xレジスタで文字数を指定
  PHA
  PHX
  JSR FUNC_CON_OUT_CHR
  PLX
  PLA
  DEX
  BNE PRT_FEW_CHARS
  RTS

BYT2ASC:
  ; Aで与えられたバイト値をASCII値AYにする
  ; Aから先に表示すると良い
  PHA           ; 下位のために保存
  AND #$0F
  JSR NIB2ASC
  TAY
  PLA
  LSR           ; 右シフトx4で上位を下位に持ってくる
  LSR
  LSR
  LSR

NIB2ASC:
  ; #$0?をアスキー一文字にする
  ORA #$30
  CMP #$3A
  BCC @SKP_ADC  ; Aが$3Aより小さいか等しければ分岐
  ADC #$06
@SKP_ADC:
  RTS

