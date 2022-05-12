; -------------------------------------------------------------------
; CCP
; -------------------------------------------------------------------
; 中国共産党
; COSアプリケーションはCCPを食いつぶすことがあり、ウォームブートでカードからリロードされる
; つまり特権的地位を持つかもしれないCOSアプリケーションである
; -------------------------------------------------------------------
.INCLUDE "FXT65.inc"
;.INCLUDE "generic.mac"
.INCLUDE "fs/structfs.s"
.INCLUDE "fscons.inc"
.PROC BCOS
  .INCLUDE "syscall.inc"  ; システムコール番号
.ENDPROC

.macro syscall func
  LDX #(BCOS::func)*2
  JSR BCOS::SYSCALL
.endmac

; -------------------------------------------------------------------
;                             変数領域
; -------------------------------------------------------------------
ZR0 = $0000
ZR1 = ZR0+2
ZR2 = ZR1+2
ZR3 = ZR2+2
ZR4 = ZR3+2
ZR5 = ZR4+2
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
  TXA
  ASL
  TAX
  PLY
  PLA
  JMP (ICOMVECS,X)

; -------------------------------------------------------------------
;                          内部コマンド
; -------------------------------------------------------------------

; -------------------------------------------------------------------
;                          見つからない
; -------------------------------------------------------------------
ICOM_NOTFOUND:
; 外部コマンド実行
  loadAY16 COMMAND_BUF            ; 元のコマンド行を（壊してないっけか？
  syscall FS_FPATH                ; フルパス取得
  pushAY16
  syscall CON_OUT_STR             ; 出力
  JSR PRT_LF
  pullAY16
  syscall FS_OPEN                 ; コマンドファイルをオープン
  BCS COMMAND_NOTFOUND            ; オープンできなかったらあきらめる
  STA ZR1                         ; ファイル記述子をZR1に
  PHX                             ; READ_BYTSに渡す用、CLOSEに渡す用で二回プッシュ
  loadmem16 ZR0,$0700             ; 書き込み先
  loadAY16  256                   ; 長さ（仮
  syscall FS_READ_BYTS            ; ロード
  PLA
  syscall FS_CLOSE                ; クローズ
  JSR $0700                       ; コマンドを呼ぶ
  JMP LOOP

ICOM_REBOOT:
COMMAND_NOTFOUND:
; いよいよもってコマンドが見つからなかった
  loadAY16 STR_COMNOTFOUND
  syscall CON_OUT_STR
  JMP LOOP

; -------------------------------------------------------------------
;                        ROMモニタに落ちる
; -------------------------------------------------------------------
ICOM_EXIT:
  loadAY16 STR_GOODBYE
  syscall CON_OUT_STR
  BRK
  NOP
  JMP LOOP

; -------------------------------------------------------------------
;                        ディレクトリ表示
; -------------------------------------------------------------------
ICOM_DIR:
ICOM_LS:
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
  LDY #FINFO::DIR_SEC           ; クラスタ内セクタ番号
  LDA (ZR4),Y
  JSR PRT_BYT
  JSR PRT_S
  LDY #FINFO::DIR_ENT           ; エントリ番号
  LDA (ZR4),Y
  JSR PRT_BYT
  JSR PRT_S
  ; ファイル名
  mem2AY16 ZR4
  INC
  syscall CON_OUT_STR           ; ファイル名を出力
  ; 改行
  JSR PRT_LF
  BRA @LOOP
@END:
  JMP LOOP
@ERR:
  JSR BCOS_ERROR
  BRA @END

STR_ATTR: .BYT  "advshr"

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
;                        画面の色を変える
; -------------------------------------------------------------------
ICOM_COLOR:
  loadAY16 STR_ICOM_COLOR_START
  syscall CON_OUT_STR                 ; 説明文
@LOOP:
  LDA #2
  syscall CON_RAWIN                   ; コマンド入力
@J:
  CMP #'j'
  BNE @K
  LDA #0
  JSR @GET
  DEY
  LDA #2
  JSR @PUT
  BRA @LOOP
@K:
  CMP #'k'
  BNE @H
  LDA #0
  JSR @GET
  INY
  LDA #2
  JSR @PUT
  BRA @LOOP
@H:
  CMP #'h'
  BNE @L
  LDA #1
  JSR @GET
  DEY
  LDA #3
  JSR @PUT
  BRA @LOOP
@L:
  CMP #'l'
  BNE @ENT
  LDA #1
  JSR @GET
  INY
  LDA #3
  JSR @PUT
@ENT:
  CMP #$A
  BNE @LOOP
  JSR PRT_LF
  JMP LOOP
@GET:
  syscall GCHR_COL
  TAY
  RTS
@PUT:
  syscall GCHR_COL
  RTS

ICOM_TEST:
  syscall UPPER_STR
  LDA ZR0
  LDY ZR0+1
  syscall CON_OUT_STR
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

PRT_BIN:
  LDX #8
@LOOP:
  ASL
  PHA
  LDA #'0'    ; キャリーが立ってなければ'0'
  BCC @SKP_ADD1
  INC         ; キャリーが立ってたら'1'
@SKP_ADD1:
  PHX
  syscall CON_OUT_CHR
  PLX
  PLA
  DEX
  BNE @LOOP
  RTS

PRT_BYT:
  JSR BYT2ASC
  PHY
  JSR PRT_C_CALL
  PLA
PRT_C_CALL:
  syscall CON_OUT_CHR
  RTS

PRT_LF:
  ; 改行
  LDA #$A
  JMP PRT_C_CALL

PRT_S:
  ; スペース
  LDA #' '
  JMP PRT_C_CALL

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
  JSR NIB2ASC
  RTS

NIB2ASC:
  ; #$0?をアスキー一文字にする
  ORA #$30
  CMP #$3A
  BCC @SKP_ADC  ; Aが$3Aより小さいか等しければ分岐
  ADC #$06
@SKP_ADC:
  RTS

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
  STA ZR0
  STY ZR0+1
  LDY #$FF
@LOOP:
  INY
  LDA (ZR0),Y
  STA (ZR1),Y
  BEQ M_LEN_RTS
  BRA @LOOP

ANALYZE_PATH:
  ; あらゆる種類のパスを解析する
  ; ディスクアクセスはしない
  ; input : AY=パス先頭
  ; output: A=分析結果
  ;           bit3:/で終わる
  ;           bit2:ルートディレクトリを指す
  ;           bit1:ルートから始まる（相対パスでない
  ;           bit0:ドライブ文字を含む
  STA ZR0
  STY ZR0+1
  STZ ZR1         ; 記録保存用
  LDY #1
  LDA (ZR0),Y     ; :の有無を見る
  CMP #':'
  BNE @NODRIVE
  SMB0 ZR1        ; ドライブ文字があるフラグを立てる
  LDA #2          ; ポインタを進め、ドライブなしと同一条件にする
  CLC
  ADC ZR0
  STA ZR0
  LDA #0
  ADC ZR0+1
  STA ZR0+1
  LDA (ZR0)       ; 最初の文字を見る
  BEQ @ROOTEND    ; 何もないならルートを指している（ドライブ前提
@NODRIVE:
  LDA (ZR0)       ; 最初の文字を見る
  CMP #'/'
  BNE @NOTFULL    ; /でないなら相対パス（ドライブ指定なし前提
  SMB1 ZR1        ; ルートから始まるフラグを立てる
@NOTFULL:
  LDY #$FF
@LOOP:            ; 最後の文字を調べるループ
  INY
  LDA (ZR0),Y
  BEQ @SKP_LOOP
  CMP #' '
  BEQ @SKP_LOOP
  BRA @LOOP       ; 以下、(ZR0),Yはヌルかスペース
@SKP_LOOP:
  DEY             ; 最後の文字を指す
  LDA (ZR0),Y     ; 最後の文字を読む
  CMP #'/'
  BNE @END        ; 最後が/でなければ終わり
  SMB3 ZR1        ; /で終わるフラグを立てる
  CPY #0          ; /で終わり、しかも一文字だけなら、それはルートを指している
  BNE @END
@ROOTEND:
  SMB2 ZR1        ; ルートディレクトリが指されているフラグを立てる
@END:
  LDA ZR1
  RTS

; -------------------------------------------------------------------
;                             データ領域
; -------------------------------------------------------------------
STR_INITMESSAGE:  .BYT "MIRACOS 0.03 for FxT-65",$A,$0 ; 起動時メッセージ
STR_COMNOTFOUND:  .BYT "Unknown Command.",$A,$0
STR_ICOM_COLOR_START:  .BYT "Console Color Setting.",$A,"j,k  : Character",$A,"h,l  : Background",$A,"ENTER: Complete",$0
STR_GOODBYE:      .BYT "Good Bye.",$A,$0
STR_DOT:          .BYT ".",$0                             ; これの絶対パスを得ると、それはカレントディレクトリ

; -------------------------------------------------------------------
;                        内部コマンドテーブル
; -------------------------------------------------------------------
ICOMNAMES:        .ASCIIZ "EXIT"        ; 0
                  .ASCIIZ "CD"          ; 1
                  .ASCIIZ "REBOOT"      ; 2
                  .ASCIIZ "COLOR"       ; 3
                  .ASCIIZ "DIR"         ; 4
                  .ASCIIZ "TEST"        ; 5
                  .ASCIIZ "LS"          ; 6
                  .BYT $0

ICOMVECS:         .WORD ICOM_EXIT
                  .WORD ICOM_CD
                  .WORD ICOM_REBOOT
                  .WORD ICOM_COLOR
                  .WORD ICOM_DIR
                  .WORD ICOM_TEST
                  .WORD ICOM_LS

