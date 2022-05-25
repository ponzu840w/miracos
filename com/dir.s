; -------------------------------------------------------------------
;                           DIRコマンド
; -------------------------------------------------------------------
; ディレクトリ表示
; -------------------------------------------------------------------
.INCLUDE "../FXT65.inc"
.INCLUDE "../generic.mac"
.INCLUDE "../fs/structfs.s"
.INCLUDE "../fscons.inc"
.PROC BCOS
  .INCLUDE "../syscall.inc"  ; システムコール番号
.ENDPROC
.INCLUDE "../syscall.mac"
.INCLUDE "../zr.inc"

; -------------------------------------------------------------------
;                             ZP領域
; -------------------------------------------------------------------
.ZEROPAGE
ZP_ATTR:          .RES 1

; -------------------------------------------------------------------
;                             実行領域
; -------------------------------------------------------------------
.CODE
START:
  storeAY16 ZR0                 ; 引数を格納
  LDA (ZR0)                     ; 最初の文字がnullか
  BNE @FIND                     ; nullなら特殊な*処理
  LDA #'*'
  STA (ZR0)
  LDA #0
  LDY #1
  STA (ZR0),Y
@FIND:
  mem2AY16 ZR0
  syscall FS_FIND_FST
  storeAY16 ZR4                 ; FINFOをZR4に退避
  BCS @ERR
  BRA @FSTENT
@LOOP:                          ; 発見したエントリごとのループ
  mem2AY16 ZR4                  ; 前回のFINFO
  syscall FS_FIND_NXT           ; 次のエントリを検索
  BCS @END                      ; もう見つからなければ終了
@FSTENT:                        ; 初回に見つかったらここに飛ぶ
  ; 属性
  storeAY16 ZR0                 ; オフセットを加えたりして参照するためにFINFOをZR0に
  LDA ZR0                       ; 下位桁取得
  ADC #FINFO::ATTR              ; 属性を取得したいのでオフセット加算
  STA ZR0
  BCC @SKP_C
  INC ZR0+1
@SKP_C:
  LDA (ZR0)                     ; 属性バイト取得
  STA ZP_ATTR                   ; 専用ZPに格納
  LDY #$0
  ASL ZP_ATTR                   ; 上位2bitを捨てる
  ASL ZP_ATTR
@ATTRLOOP:
  ASL ZP_ATTR                   ; C=ビット情報
  BCS @ATTR_CHR
  LDA #'-'                      ; そのビットが立っていないときはハイフンを表示
  BRA @SKP_ATTR_CHR
@ATTR_CHR:
  LDA STR_ATTR,Y                ; 属性文字を表示
@SKP_ATTR_CHR:
  PHY
  syscall CON_OUT_CHR           ; 属性文字/-を表示
  PLY
  INY
  CPY #6
  BNE @ATTRLOOP
  JSR PRT_S                     ; 区切りスペース
  ; [DEBUG] FINFO表示
  ;LDY #FINFO::DIR_SEC           ; クラスタ内セクタ番号
  ;LDA (ZR4),Y
  ;JSR PRT_BYT
  ;JSR PRT_S
  ;LDY #FINFO::DIR_ENT           ; エントリ番号
  ;LDA (ZR4),Y
  ;JSR PRT_BYT
  ;JSR PRT_S
  ; ファイル名
  mem2AY16 ZR4
  INC
  syscall CON_OUT_STR           ; ファイル名を出力
  ; 改行
  JSR PRT_LF
  BRA @LOOP
@END:
  RTS
@ERR:
  JSR BCOS_ERROR
  BRA @END

; -------------------------------------------------------------------
;                          汎用関数群
; -------------------------------------------------------------------
BCOS_ERROR:
  JSR PRT_LF
  syscall ERR_GET
  syscall ERR_MES
  RTS

PRT_LF:
  ; 改行
  LDA #$A
  JMP PRT_C_CALL

PRT_S:
  ; スペース
  LDA #' '
  ;JMP PRT_C_CALL
PRT_C_CALL:
  syscall CON_OUT_CHR
  RTS

STR_ATTR: .BYT  "advshr"

