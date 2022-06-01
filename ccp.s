; -------------------------------------------------------------------
; CCP
; -------------------------------------------------------------------
; 中国共産党
; COSアプリケーションはCCPを食いつぶすことがあり、ウォームブートでカードからリロードされる
; つまり特権的地位を持つかもしれないCOSアプリケーションである
; -------------------------------------------------------------------
.INCLUDE "FXT65.inc"
;.INCLUDE "generic.mac"   ; BCOSと抱き合わせアセンブルするとダブる
.INCLUDE "fs/structfs.s"
.INCLUDE "fscons.inc"
.INCLUDE "zr.inc"
.PROC BCOS
  .INCLUDE "syscall.inc"  ; システムコール番号
.ENDPROC
.INCLUDE "syscall.mac"

TPA = $0700

; -------------------------------------------------------------------
;                             変数領域
; -------------------------------------------------------------------
.ZEROPAGE
ZP_ATTR:          .RES 1  ; 属性バイトをシフトして遊ぶ

.BSS
COMMAND_BUF:      .RES 64 ; コマンド入力バッファ

; -------------------------------------------------------------------
;                             実行領域
; -------------------------------------------------------------------
.CODE
; -------------------------------------------------------------------
;                           シェルスタート
; -------------------------------------------------------------------
START:
  loadAY16 STR_INITMESSAGE
  syscall CON_OUT_STR             ; タイトル表示

; -------------------------------------------------------------------
;                           シェルループ
; -------------------------------------------------------------------
LOOP:
  JSR PRT_LF
  loadAY16 STR_DOT
  syscall FS_FPATH
  syscall CON_OUT_STR             ; カレントディレクトリ表示
  LDA #'>'
  syscall CON_OUT_CHR             ; プロンプト表示
  LDA #64                         ; バッファ長さ指定
  STA ZR0
  loadAY16 COMMAND_BUF            ; バッファ指定
  syscall CON_IN_STR              ; バッファ行入力
  loadAY16 COMMAND_BUF            ; バッファ指定
  syscall UPPER_STR               ; 大文字変換
; コマンドライン解析
  LDA COMMAND_BUF                 ; バッファ先頭を取得
  BEQ LOOP                        ; バッファ長さ0ならとりやめ
  JSR PRT_LF                      ; コマンド入力後の改行は、無入力ではやらない
; コマンド名と引数の分離
  LDX #$FF
@CMDNAME_LOOP:
  INX
  LDA COMMAND_BUF,X
  BEQ @CMDNAME_0END               ; 引数がなかった
  CMP #' '                        ; 空白か？
  BNE @CMDNAME_LOOP
  STZ COMMAND_BUF,X               ; 空白をヌルに
  BRA @PUSH_ARG
@CMDNAME_0END:
  STZ COMMAND_BUF+1,X             ; ダブル0で引数がないことを示す
@PUSH_ARG:                        ; COMMAND_BUF+X+1=引数先頭を渡したい
  TXA
  SEC
  ADC #<COMMAND_BUF
  PHA                             ; 下位をプッシュ
  LDA #0
  ADC #>COMMAND_BUF
  PHA                             ; 上位をプッシュ
@SEARCH_ICOM:
  LDX #0                          ; 内部コマンド番号初期化
  loadmem16 ZR0,COMMAND_BUF       ; 入力されたコマンドをZR0に
  loadmem16 ZR1,ICOMNAMES         ; 内部コマンド名称配列をZR1に
@NEXT_ICOM:
  JSR M_EQ                        ; 両ポインタは等しいか？
  BEQ EXEC_ICOM                   ; 等しければ実行する（Xが渡る
  JSR M_LEN_ZR1
  CPY #0
  BEQ ICOM_NOTFOUND
  INY                             ; 内部コマンド名称インデックスを次の先頭に
  TYA
  CLC
  ADC ZR1                         ; 内部コマンド名称インデックスをポインタに反映
  STA ZR1
  LDA #0
  ADC ZR1+1
  STA ZR1+1
  INX                             ; 内部コマンド番号インデックスを増加
  BNE @NEXT_ICOM                  ; Xが一周しないうちは周回
  JMP ICOM_NOTFOUND               ; このジャンプはおそらく呼ばれえない
EXEC_ICOM:                        ; Xで渡された内部コマンド番号を実行する
  TXA                             ; Xを作業のためAに
  ASL                             ; Xをx2
  TAX                             ; Xを戻す
  PLY                             ; 引数をAYに渡す
  PLA
  JMP (ICOMVECS,X)

; -------------------------------------------------------------------
;                          内部コマンド
; -------------------------------------------------------------------

; -------------------------------------------------------------------
;                    内部コマンドが見つからない
; -------------------------------------------------------------------
ICOM_NOTFOUND:
  ; 外部コマンド実行（引数がプッシュされている
FIND_CURDIRCOM:
  ; カレントディレクトリでの検索
  loadAY16 COMMAND_BUF            ; 元のコマンド行を（壊してないっけか？
  syscall FS_FIND_FST             ; 検索
  BCC OCOM_FOUND                  ; 見つかったらパス検索しない
FIND_INSTALLEDCOM:
  ; パスの通った部分での検索
  ; /チェック
  loadAY16 COMMAND_BUF            ; 元のコマンド行を
  syscall FS_PURSE                ; パース
  BBS4 ZR1,COMMAND_NOTFOUND       ; /を含むパスならあきらめる
  ; 長さチェック
  loadAY16 COMMAND_BUF            ; 元のコマンド行を
  JSR M_LEN                       ; 長さ取得
  CPY #$9
  BCS COMMAND_NOTFOUND            ; 8文字を超える（A>=9）ならあきらめる
  ; 検索に着手
  loadmem16 ZR1,PATH_COM_DIREND   ; 固定パスの最後に
  loadAY16 COMMAND_BUF            ; 元のコマンド行を
  JSR M_CP_AYS                    ; コピーして
  ; .COMを付ける
  LDX #0  ; ロード側インデックス
@LOOP:
  LDA PATH_DOTCOM,X
  STA PATH_COM_DIREND,Y
  INY     ; ストア側インデックス
  INX
  CPX #5
  BNE @LOOP
  loadAY16 PATH_COM               ; 合体したパスを
  ; [DEBUG]
  ;syscall CON_OUT_STR             ; ひょうじ
  syscall FS_FIND_FST             ; 検索
  BCS COMMAND_NOTFOUND            ; 見つからなかったらあきらめる
OCOM_FOUND:
  storeAY16 ZR3                   ; FINFOをZR3に格納
  syscall FS_OPEN                 ; コマンドファイルをオープン
  BCS COMMAND_NOTFOUND            ; オープンできなかったらあきらめる
  STA ZR1                         ; ファイル記述子をZR1に
  PHX                             ; READ_BYTSに渡す用、CLOSEに渡す用で二回プッシュ
  loadmem16 ZR0,TPA               ; 書き込み先
  LDY #FINFO::SIZ                 ; FINFOから長さ（下位2桁のみ）を取得
  LDA (ZR3),Y
  PHA
  INY
  LDA (ZR3),Y
  TAY
  PLA
  syscall FS_READ_BYTS            ; ロード
  PLA
  syscall FS_CLOSE                ; クローズ
  PLY                             ; 引数をロード
  PLA
  JSR TPA                         ; コマンドを呼ぶ
  JMP LOOP

COMMAND_NOTFOUND:
; いよいよもってコマンドが見つからなかった
  PLY                             ; 引数を捨てる
  PLA
  loadAY16 STR_COMNOTFOUND
  syscall CON_OUT_STR
  JMP LOOP

; -------------------------------------------------------------------
;                        DONKIデバッガ起動
; -------------------------------------------------------------------
ICOM_DONKI:
  LDA #$01
  LDX #$23
  LDY #$45            ; お飾り
  BRK
  NOP
  JMP LOOP

; -------------------------------------------------------------------
;                     カレントディレクトリ変更
; -------------------------------------------------------------------
ICOM_CD:
  syscall FS_CHDIR          ; テーブルジャンプ前にコマンドライン引数を受け取った
  BCC @SKP_ERR
  JMP BCOS_ERROR
@SKP_ERR:
  JMP LOOP

; -------------------------------------------------------------------
;                    ロードを省略してTPAを実行
; -------------------------------------------------------------------
; SREC読み込みでテスト実行するのに便利
; -------------------------------------------------------------------
ICOM_TEST:
  JSR TPA
  JMP LOOP

; -------------------------------------------------------------------
;                          汎用関数群
; -------------------------------------------------------------------
; どうする？ライブラリ？システムコール？
; -------------------------------------------------------------------
BCOS_ERROR:
  JSR PRT_LF
  syscall ERR_GET
  syscall ERR_MES
  JMP LOOP

;PRT_BIN:
;  LDX #8
;@LOOP:
;  ASL
;  PHA
;  LDA #'0'    ; キャリーが立ってなければ'0'
;  BCC @SKP_ADD1
;  INC         ; キャリーが立ってたら'1'
;@SKP_ADD1:
;  PHX
;  syscall CON_OUT_CHR
;  PLX
;  PLA
;  DEX
;  BNE @LOOP
;  RTS

;PRT_BYT:
;  JSR BYT2ASC
;  PHY
;  JSR PRT_C_CALL
;  PLA
;PRT_C_CALL:
;  syscall CON_OUT_CHR
;  RTS
;
PRT_LF:
  ; 改行
  LDA #$A
;  JMP PRT_C_CALL

;PRT_S:
;  ; スペース
;  LDA #' '
;  ;JMP PRT_C_CALL
PRT_C_CALL:
  syscall CON_OUT_CHR
  RTS

;BYT2ASC:
;  ; Aで与えられたバイト値をASCII値AYにする
;  ; Aから先に表示すると良い
;  PHA           ; 下位のために保存
;  AND #$0F
;  JSR NIB2ASC
;  TAY
;  PLA
;  LSR           ; 右シフトx4で上位を下位に持ってくる
;  LSR
;  LSR
;  LSR
;  JSR NIB2ASC
;  RTS
;
;NIB2ASC:
;  ; #$0?をアスキー一文字にする
;  ORA #$30
;  CMP #$3A
;  BCC @SKP_ADC  ; Aが$3Aより小さいか等しければ分岐
;  ADC #$06
;@SKP_ADC:
;  RTS

M_EQ_AY:
  ; AYとZR0が等しいかを返す
  STA ZR1
  STY ZR1+1
M_EQ:
  LDY #$FF                ; インデックスはゼロから
@LOOP:
  INY
  LDA (ZR0),Y
  BEQ @END                ; ヌル終端なら終端検査に入る
  CMP (ZR1),Y
  BEQ @LOOP               ; 一致すればもう一文字
@NOT:
  SEC
  RTS
@END:
  LDA (ZR1),Y
  BNE @EQ
@EQ:
  CLC
  RTS

M_LEN:
  ; 文字列の長さを取得する
  ; input:AY
  ; output:Y
  STA ZR1
  STY ZR1+1
M_LEN_ZR1:  ; ZR1入力
  LDY #$FF
@LOOP:
  INY
  LDA (ZR1),Y
  BNE @LOOP
M_LEN_RTS:
  RTS

M_CP_AYS:
  ; 文字列をコピーする
  ; DST=ZR1
  STA ZR0
  STY ZR0+1
  LDY #$FF
@LOOP:
  INY
  LDA (ZR0),Y
  STA (ZR1),Y
  BEQ M_LEN_RTS
  BRA @LOOP

; -------------------------------------------------------------------
;                             データ領域
; -------------------------------------------------------------------
STR_INITMESSAGE:  .INCLUDE "initmessage.s"                ; 起動時メッセージ
STR_COMNOTFOUND:  .BYT "Unknown Command.",$A,$0
STR_GOODBYE:      .BYT "Good Bye.",$A,$0
STR_DOT:          .BYT ".",$0                             ; これの絶対パスを得ると、それはカレントディレクトリ
PATH_COM:         .BYT "A:/MCOS/COM/"
  PATH_COM_DIREND:  .RES 13
PATH_DOTCOM:      .BYT ".COM",$0

; -------------------------------------------------------------------
;                        内部コマンドテーブル
; -------------------------------------------------------------------
ICOMNAMES:        ;.ASCIIZ "EXIT"        ; 0
                  .ASCIIZ "CD"          ; 1
                  ;.ASCIIZ "REBOOT"      ; 2
                  ;.ASCIIZ "COLOR"       ; 3
                  ;.ASCIIZ "DIR"         ; 4
                  .ASCIIZ "TEST"        ; 5
                  ;.ASCIIZ "LS"          ; 6
                  .ASCIIZ "DONKI"       ; 7
                  .BYT $0

ICOMVECS:         ;.WORD ICOM_EXIT
                  .WORD ICOM_CD
                  ;.WORD ICOM_REBOOT
                  ;.WORD ICOM_COLOR
                  ;.WORD ICOM_DIR
                  .WORD ICOM_TEST
                  ;.WORD ICOM_LS
                  .WORD ICOM_DONKI

