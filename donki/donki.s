; -------------------------------------------------------------------
; DONKI                  Debug OperatioN KIt
; -------------------------------------------------------------------
; デバッガ
; ひとまず、BCOSの一部として常駐する
; -------------------------------------------------------------------
; TODO ソフトウェアブレーク処理ルーチン
ZR1_FROM        = ZR1
ZR2_TO          = ZR2
LOAD_CKSM       = ZR3
LOAD_BYTCNT     = ZR3+1
ADDR_INDEX      = ZR4
SETTING         = ZR5
ZR5H_CMD_IDX    = ZR5+1

EOT = $04 ; EOFでもある

ENT_DONKI:
SAV_STAT:
; 状態を保存
; 割り込み直後のスタック状態を想定
  SEI
  STA ROM::A_SAVE   ; レジスタ保存
  STX ROM::X_SAVE
  STY ROM::Y_SAVE
  LDX #12-1
@STOREZRLOOP:       ; ゼロページレジスタを退避
  LDA ZR0,X
  STA ROM::ZR0_SAVE,X
  DEX
  BPL @STOREZRLOOP
  TSX
  STX ROM::SP_SAVE  ; save targets stack poi
  ; --- FLAG、PC保存 ---
  ; SP+1=FLAG、+2=PCL、+3=PCH
  LDY #0
@STACK_SAVE_LOOP:
  INX
  LDA $0100,X
  STA FLAG_SAVE,Y
  INY
  CPY #3
  BNE @STACK_SAVE_LOOP
  ; --- プログラムカウンタを減算 ---
  LDA #$1
  CMP PC_SAVE   ; PCLと#$1の比較
  BCC SKIPHDEC
  BEQ SKIPHDEC
  DEC PC_SAVE+1 ; PCH--
SKIPHDEC:
  DEC PC_SAVE   ; PCL--
  ; --- 垂直同期ユーザベクタをデフォルトに変更 ---
  mem2mem16 VB_HNDR_SAVE,VBLANK_USER_VEC16  ; ユーザベクタを退避
  loadAY16 IRQ::VBLANK_STUB
  storeAY16 VBLANK_USER_VEC16               ; スタブに差し替え
  LDA ZP_CON_DEV_CFG
  STA CONDEV_SAVE
  STZ SETTING

PRT_STAT:  ; print contents of stack
  ; --- レジスタ情報を表示 ---
  ; 表示中にさらにBRKされると分かりづらいので改行
  ;loadAY16 STR_NEWLINE
  ;JSR FUNC_CON_OUT_STR
  JSR PRT_LF
  ; A
  ;JSR PRT_S
  LDA #'a'
  LDX ROM::A_SAVE       ; Acc reg
  JSR PRT_REG
  ; X
  LDA #'x'
  LDX ROM::X_SAVE       ; X reg
  JSR PRT_REG
  ; Y
  LDA #'y'
  LDX ROM::Y_SAVE       ; Y reg
  JSR PRT_REG
  ; Flag
  LDA #'f'
  LDX FLAG_SAVE
  JSR PRT_REG
  ; PC
  LDA #'p'
  JSR FUNC_CON_OUT_CHR
  LDA PC_SAVE+1
  JSR PRT_BYT
  LDA PC_SAVE
  JSR PRT_BYT_S
  ; SP
  LDA #'s'
  LDX ROM::SP_SAVE      ; stack pointer
  JSR PRT_REG
  CLI
  ;JMP LOOP

LOOP:
  LDA CONDEV_SAVE
  STA ZP_CON_DEV_CFG
  loadAY16 STR_NEWLINE
  JSR FUNC_CON_OUT_STR
  loadAY16 COMMAND_BUF
  JSR FUNC_CON_IN_STR       ; コマンド行を取得
  LDA #1
  STA ZR5H_CMD_IDX
  ; コマンド処理
  LDA COMMAND_BUF
  CMP #'r'          ; [r] レジスタ状態編集・表示
  BEQ TO_SET_REGS
  CMP #'z'          ; [z] ZR状態編集・表示
  BEQ TO_PRT_ZR
  CMP #'l'          ; [l] SRECロード
  BEQ TO_LOAD
  CMP #'d'          ; [d] 指定範囲ダンプ、GCON用
  BEQ DUMP
  CMP #'D'          ; [D] 指定範囲ダンプ、UART用
  BEQ WDUMP
  CMP #'g'          ; [g] ユーザコードへのジャンプ
  BNE LOOP

; -------------------------------------------------------------------
;                     gコマンド プログラムの実行
; -------------------------------------------------------------------
;   レジスタの各情報を復帰し、対象プログラムへ移行する
; -------------------------------------------------------------------
  mem2mem16 VBLANK_USER_VEC16,VB_HNDR_SAVE  ; 垂直同期ユーザベクタを復帰
  LDX #12-1
RESTOREZRLOOP:            ; ゼロページレジスタを復帰
  LDA ROM::ZR0_SAVE,X
  STA ZR0,X
  DEX
  BPL RESTOREZRLOOP
  LDA ROM::SP_SAVE
  CLC
  ADC #3                  ; SPを割り込み前の状態に戻す
  TAX                     ; SPをXに取得
  TXS                     ; SP復帰
  LDY FLAG_SAVE           ; フラグをロード
  PHY                     ; フラグをプッシュ
  LDA ROM::A_SAVE
  LDX ROM::X_SAVE
  LDY ROM::Y_SAVE
  PLP                     ; フラグをフラグとしてプル
  ;CLC
  ;CLI
  JMP (PC_SAVE)           ; 復帰ジャンプ

TO_PRT_ZR:
  JMP PRT_ZR
TO_LOAD:
  JMP LOAD
TO_SET_REGS:
  JMP SET_REGS

STR_NEWLINE: .BYT $A,"+",$0

; -------------------------------------------------------------------
;                    Dコマンド ワイドメモリダンプ
; -------------------------------------------------------------------
;   UART前提：画面サイズにとらわれず1行16バイト表示する
; -------------------------------------------------------------------
WDUMP:
  SMB0 SETTING
  LDA #%00000011 ; only UART
  STA ZP_CON_DEV_CFG
  BRA DUMP1

; -------------------------------------------------------------------
;                       dコマンド メモリダンプ
; -------------------------------------------------------------------
;   第1引数から第2引数までをダンプ表示
;   第2引数がなければ第1引数から256バイト
; -------------------------------------------------------------------
DUMP:
  RMB0 SETTING
DUMP1:
  ;DUMP_SUB_FUNCPTR=ZR3 ; データ表示/アスキー表示関数ポインタ
  ; ---------------------------------------------------------------
  ;   引数の数に応じた処理
  JSR GET_ARG_HEX         ; 第1引数取得
  BCS LOOP                ; 引数ゼロ FROM指定がないなら何もしない
  mem2mem16 ZR1_FROM,ZR2  ; FROM変数に格納
  JSR GET_ARG_CHR         ; 次は+か
  CMP #'+'
  BEQ @ADD_USER_LEN
  DEC ZR5H_CMD_IDX
  JSR GET_ARG_HEX         ; 第2引数取得
  BCC @SET_ZR3            ; 取得できればデフォ処理をスキップ
@ADD_USER_LEN:
  JSR GET_ARG_HEX         ; +後の引数取得
  BCC @MAKE_ZR2_TO        ; 成功したらデフォスキップ
@ADD_DEFAULT_LEN:
  LDA #255-1              ; 非ワイドモード:デフォ半ページ
  BBS0 SETTING,@SKP_127   ; ワイドモード:デフォ1ページ
  LDA #127-1
@SKP_127:
  STA ZR2_TO
  STZ ZR2_TO+1            ; デフォ:上位0
@MAKE_ZR2_TO:
  LDA ZR1_FROM            ; * TO=FROM+ZR2
  ADC ZR2_TO              ; |
  STA ZR2_TO              ; |
  LDA ZR1_FROM+1          ; |
  ADC ZR2_TO+1            ; |
  STA ZR2_TO+1            ; |
  BRA @SET_ZR3
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
@PRT_ADDR:
  JSR PRT_LF            ;   最大の情報を表示しつつ作業用コマンドラインを出すにはこうする。
  LDA #'<'              ; アドレス左修飾
  JSR FUNC_CON_OUT_CHR
  LDA ZR1_FROM+1       ; アドレス上位
  JSR PRT_BYT
  LDA ZR1_FROM         ; アドレス下位
  JSR PRT_BYT
  LDA #'>'              ; アドレス右修飾
  JSR FUNC_CON_OUT_CHR
  JSR PRT_S
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
  pushmem16 ZR1_FROM
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
  pullmem16 ZR1_FROM
  LDA #<(DUMP_SUB_ASCII-(DUMP_SUB_BRA+2))
  JSR DUMP_SUB
  BEQ @LINE
@END:
  JMP LOOP

; ポインタ切り替えでHEXかASCIIを表示する
DUMP_SUB:
  STA DUMP_SUB_BRA+1
  BBS0 SETTING,@SKP8  ; ワイドモード:1行16バイト
  LDX #8              ; X=行ダウンカウンタ
  BRA DATALOOP
@SKP8:
  LDX #16
DATALOOP:
  LDA (ZR1_FROM)     ; バイト取得
  PHX
  ;JMP (DUMP_SUB_FUNCPTR)
DUMP_SUB_BRA:
  .BYTE $80 ; BRA
  .BYTE $00
DUMP_SUB_RETURN:
  PLX
  ; 終了チェック
  LDA ZR1_FROM+1
  CMP ZR2_TO+1
  BNE @SKP_ENDCHECK_LOW
  LDA ZR1_FROM
  CMP ZR2_TO
  BEQ @END_DATALOOP
@SKP_ENDCHECK_LOW:
  inc16 ZR1_FROM   ; アドレスインクリメント
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

; コマンドバッファの引数の先頭Xと終端Yを取得
; スペースで区切ることが出来る
; 何もなければゼロフラグが立つ
CMD_ARGS_SPLIT:
  LDX ZR5H_CMD_IDX    ; 現在インデックス
  ; 先頭取得
@START_LOOP:
  LDA COMMAND_BUF,X
  BEQ @END
  CMP #' '
  BNE @SKP_START_LOOP ; ' '以外を発見して脱出
  INX
  BRA @START_LOOP
@SKP_START_LOOP:
  ; Xに先頭インデックスが取得された
  TXA
  TAY
  ; 終端取得
@END_LOOP:
  LDA COMMAND_BUF,Y
  BEQ @SKP_END_LOOP   ; 終端を発見して脱出
  CMP #' '
  BEQ @SKP_END_LOOP   ; ' 'を発見して脱出
  INY
  BRA @END_LOOP
@SKP_END_LOOP:
  LDA #1
@END:
  RTS

; -------------------------------------------------------------------
;                       zコマンド ZR表示
; -------------------------------------------------------------------
; -------------------------------------------------------------------
PRT_ZR:
  ; --- レジスタ情報を表示 ---
  ; 表示中にさらにBRKされると分かりづらいので改行
  ;loadAY16 STR_NEWLINE
  ;JSR FUNC_CON_OUT_STR
  JSR PRT_LF
  LDX #0
@LOOP:
  PHX
  LDA ROM::ZR0_SAVE+1,X
  JSR PRT_BYT
  LDA ROM::ZR0_SAVE,X
  JSR PRT_BYT_S
  PLX
  INX
  INX
  CPX #12
  BNE @LOOP
  JMP LOOP

; *
; --- Aレジスタの一文字をNibbleとして値にする ---
; *
CHR2NIB:
  CMP #'0'
  BMI @ERR
  CMP #'9'+1
  BPL @ABCDEF
  SEC
  SBC #'0'
  CLC
  RTS
@ABCDEF:
  CMP #'A'
  BMI @ERR
  CMP #'F'+1
  BPL @ERR
  SEC
  SBC #'A'-$0A
  CLC
  RTS
@ERR:
  SEC
  RTS

PRT_REG:
  ; レジスタ表示の一部。ほんのちょっとだけ短縮になるはず
  PHX
  JSR FUNC_CON_OUT_CHR
  PLA
  JSR PRT_BYT_S
  RTS

; -------------------------------------------------------------------
;                     lコマンド データロード
; -------------------------------------------------------------------
;  UARTからSRECを受け取ってメモリに展開する
; -------------------------------------------------------------------
LOAD:
  LDA #%00000111 ; only UART + PS/2
  AND CONDEV_SAVE
  STA ZP_CON_DEV_CFG
  JSR PRT_LF ; Lコマンド開始時改行
  ;STZ ECHO_F  ; エコーを切ったら速いかもしれない
LOAD_CHECKTYPE:
  JSR FUNC_CON_IN_CHR_RPD
  CMP #'S'
  BNE LOAD_CHECKTYPE  ; 最初の文字がSじゃないというのはありえないが
  JSR FUNC_CON_IN_CHR_RPD
  CMP #'9'
  BEQ LOAD_SKIPLAST  ; 最終レコード
  CMP #'1'
  BNE LOAD_CHECKTYPE  ; S1以外のレコードはどうでもいい
  STZ LOAD_CKSM
  JSR INPUT_BYT
  SEC
  SBC #$2
  STA LOAD_BYTCNT
  ; 何バイトのレコードかを表示
  ;JSR PRT_LF
  ;JSR PRT_BYT
  ;JSR PRT_LF

; --- アドレス部 ---
  JSR INPUT_BYT
  STA ADDR_INDEX+1
  JSR INPUT_BYT
  STA ADDR_INDEX

; --- データ部 ---
LOAD_STORE_DATA:
  JSR INPUT_BYT
  DEC LOAD_BYTCNT
  BEQ LOAD_ZEROBYT_CNT  ; 全バイト読んだ
  STA (ADDR_INDEX)      ; Zero Page Indirect
  INC ADDR_INDEX
  BNE LOAD_SKIPINC
  INC ADDR_INDEX+1
LOAD_SKIPINC:
  JMP LOAD_STORE_DATA

; --- ゼロバイトを数える ---
LOAD_ZEROBYT_CNT:
  LDA #'#'    ; ここがレコード端のはずだからメッセージ
  JSR FUNC_CON_OUT_CHR
  INC LOAD_CKSM
  BEQ LOAD_CHECKTYPE  ; チェックサムが256超えたらOK
  BRK
  NOP
  ;JMP HATENA  ; おかしいのでハテナ出して終了

; --- 最終レコードを読み飛ばす ---
LOAD_SKIPLAST:
  JSR FUNC_CON_IN_CHR_RPD
  CMP #EOT
  BNE LOAD_SKIPLAST
  ;LDA #%10000000
  ;STA ECHO_F  ; エコーをもどす
  JMP LOOP

; Aレジスタに2桁のhexを値として取り込み
INPUT_BYT:
  JSR FUNC_CON_IN_CHR_RPD
  CMP #$0A      ; 改行だったらCTRLに戻る
  BEQ JMP_LOOP
  JSR CHR2NIB
  ASL
  ASL
  ASL
  ASL
  STA ZR0       ; LOADしか使わないだろうから大丈夫だろう
  JSR FUNC_CON_IN_CHR_RPD
  JSR CHR2NIB
  ORA ZR0
  STA ZR0
  CLC
  ADC LOAD_CKSM
  STA LOAD_CKSM
  LDA ZR0
  RTS

JMP_LOOP:
JMP LOOP

; -------------------------------------------------------------------
;                   rコマンド レジスタセット&表示
; -------------------------------------------------------------------
; レジスタを設定後、落ちた時と同様に表示する
; 文法: +r a 10 p 5300
; -------------------------------------------------------------------
SET_REGS:
  JSR GET_ARG_CHR     ; レジスタ名取得
  BEQ JMP_PRT_STAT
  PHA
  JSR GET_ARG_HEX
  PLX
  LDA ZR2
  LDY #0
  CPX #'f'
  BEQ EDIT_FLAGS
  CPX #'p'
  BEQ EDIT_PC
  CPX #'s'
  BEQ EDIT_S_PTR
  CPX #'a'
  BEQ EDIT_A_REG
  CPX #'x'
  BEQ EDIT_X_REG
  CPX #'y'
  BNE JMP_PRT_STAT        ; defalut
EDIT_Y_REG:
  INY
EDIT_X_REG:
  INY
EDIT_A_REG:
  INY
EDIT_S_PTR:
  STA ROM::SP_SAVE,Y
  BRA JMP_PRT_STAT
EDIT_PC:
  LDX ZR2+1
  STX PC_SAVE+1
  INY
EDIT_FLAGS:
  STA FLAG_SAVE,Y
JMP_PRT_STAT:
  JMP PRT_STAT

; コマンドラインから次の引数を文字として得る
GET_ARG_CHR:
  JSR CMD_ARGS_SPLIT  ; 次のトークンの前後を得る。なければZ=1
  BEQ ERR_SEC_RTS     ; なければ異常終了
  LDA COMMAND_BUF,X
  INX
  STX ZR5H_CMD_IDX
  RTS

; コマンドラインから次の引数を数値として得る
GET_ARG_HEX:
  JSR CMD_ARGS_SPLIT  ; 次のトークンの前後を得る。なければZ=1
  BEQ ERR_SEC_RTS     ; なければ異常終了
  STY ZR5H_CMD_IDX    ; Yに終端インデックスが取得された

; -------------------------------------------------------------------
;                    引数をHEXと信じて変換
; -------------------------------------------------------------------
;   input:  X = 左インデックス
;           Y = 右インデックス
;   output: ZR2 = 値
; -------------------------------------------------------------------
ARG2NUM:
  @NUMBER16=ZR2
  @START=ZR0+1
  ; X=start
  ; Y=\0
  STX @START
  LDX #0
  STZ @NUMBER16
  STZ @NUMBER16+1
@BYT_LOOP:
  ; 下位nibble
  CPY @START
  BEQ END_CLC_RTS
  DEY
  LDA COMMAND_BUF,Y
  JSR CHR2NIB
  BCS ERR_SEC_RTS
  STA @NUMBER16,X
  ; 上位nibble
  CPY @START
  BEQ END_CLC_RTS
  DEY
  LDA COMMAND_BUF,Y
  JSR CHR2NIB
  BCS ERR_SEC_RTS
  ASL
  ASL
  ASL
  ASL
  ORA @NUMBER16,X
  STA @NUMBER16,X
  INX
  BRA @BYT_LOOP

ERR_SEC_RTS:
  SEC
  RTS
END_CLC_RTS:
  CLC
  RTS

; -------------------------------------------------------------------
;                          汎用関数群
; -------------------------------------------------------------------
; どうする？ライブラリ？システムコール？
; -------------------------------------------------------------------
BCOS_ERROR:
  JSR PRT_LF
  JSR ERR::FUNC_ERR_GET
  JSR ERR::FUNC_ERR_MES
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
  JSR FUNC_CON_OUT_CHR
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

