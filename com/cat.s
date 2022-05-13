; -------------------------------------------------------------------
; テキストファイルを打ち出すCAT
; CATは猫の意。かわいいので。
; 複数入力の連結？なんのことかな？
; -------------------------------------------------------------------
; TCのテスト
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
  STZ TEXT+256                    ; 終端
  ; オープン
  syscall FS_FIND_FST             ; 検索
  BCS NOTFOUND                    ; 見つからなかったらあきらめる
  storeAY16 FINFO_SAV             ; FINFOをZR3に格納
  syscall FS_OPEN                 ; ファイルをオープン
  BCS NOTFOUND                    ; オープンできなかったらあきらめる
  STA FD_SAV                      ; ファイル記述子をセーブ
  PHX                             ; CLOSEに渡す用でプッシュ
LOOP:
  ; ロード
  loadmem16 ZR0,TEXT              ; 書き込み先
  loadAY16 256
  syscall FS_READ_BYTS            ; ロード
  ; 出力
  loadAY16 TEXT
  syscall CON_OUT_STR
  ; クローズ
  LDA FD_SAV
  syscall FS_CLOSE                ; クローズ
  syscall CON_OUT_STR
  RTS

NOTFOUND:
  loadAY16 STR_NOTFOUND
  syscall CON_OUT_STR
  RTS

STR_NOTFOUND:
  .BYT "Input File Not Found.",$A,$0

; -------------------------------------------------------------------
;                             データ領域
; -------------------------------------------------------------------
.DATA
TEXT:

