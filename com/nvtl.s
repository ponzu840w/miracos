; -------------------------------------------------------------------
;                           NVTL.COM
; -------------------------------------------------------------------
; ちぇりー氏考案の、より実装が楽なVTL 逆ポーランド記法
; 移植元:https://github.com/cherry-takuan/nlp/blob/master/nlp-16a/Software/Application/NiseVTL/main.c
; -------------------------------------------------------------------
.INCLUDE "../generic.mac"     ; 汎用マクロ
.PROC BCOS
  .INCLUDE "../syscall.inc"   ; システムコール番号定義
.ENDPROC
.INCLUDE "../syscall.mac"     ; 簡単システムコールマクロ
.INCLUDE "../FXT65.inc"       ; ハードウェア定義
.INCLUDE "../fs/structfs.s"   ; ファイルシステム関連構造体定義
.INCLUDE "../zr.inc"          ; ZPレジスタZR0..ZR5
.INCLUDE "../sweet16.s"       ; 16bit VM

; -------------------------------------------------------------------
;                              定数宣言
; -------------------------------------------------------------------
PROGRAM_AREA_SIZE = 4096
STACK_SIZE        = 256*2
ARRAY_SIZE        = 256*2
INPUT_BUF_SIZE    = 16

; なんかエスケープがダルい文字
SQUOTE  = $27 ; '
BSLASH  = $5C ; \

; -------------------------------------------------------------------
;                             ZP変数領域
; -------------------------------------------------------------------
.ZEROPAGE
  ;ZP_PROGRAM_PTR:    .RES 2   ; プログラム用汎用ポインタ
  ZP_GOTO_LNUM    = R9
  ZP_PROGRAM_PTR  = R10
  ZP_STACK_PTR    = R11
  ZP_REM:         .RES 2      ; 剰余
  ZP_FLAGS:       .RES 1
  FD_SAV:         .RES 1    ; ファイル記述子
  FINFO_SAV:      .RES 2    ; FINFO
  FILE_BUF_PTR:   .RES 2    ; ファイルバッファ上のどこかを指すポインタ

; -------------------------------------------------------------------
;                              変数領域
; -------------------------------------------------------------------
.BSS
PROGRAM_AREA: .RES PROGRAM_AREA_SIZE
STACK:        .RES STACK_SIZE
ARRAY:        .RES ARRAY_SIZE
INPUT_BUF:    .RES INPUT_BUF_SIZE
VAR:          .RES ('Z'-'A'+1)*2

; -------------------------------------------------------------------
;                              実行領域
; -------------------------------------------------------------------
.CODE
START:
  storeAY16 ZR0                   ; ZR0=arg
  ; ---------------------------------------------------------------
  ;   初期化
  ; ---------------------------------------------------------------
  JSR CLEAR_STACK
  loadmem16 ZR4,R0
  STZ ZP_FLAGS
  ; ---------------------------------------------------------------
  ;   ファイルロード
  ; ---------------------------------------------------------------
  ;   コマンドライン引数処理
  ; nullチェック
  LDA (ZR0)
  BEQ REPLOOP                     ; 指定なしで対話モード
  ; ---------------------------------------------------------------
  ;   ファイルオープン
  mem2AY16 ZR0
  syscall FS_FIND_FST             ; 検索
  BCS NOTFOUND                    ; 見つからなかったらあきらめる
  storeAY16 FINFO_SAV             ; FINFOを格納
  STZ ZR0
  syscall FS_OPEN                 ; ファイルをオープン
  BCS NOTFOUND                    ; オープンできなかったらあきらめる
  ;STA FD_SAV                      ; ファイル記述子をセーブ
  ;LDA FD_SAV
  STA ZR1                         ; ZR1 = FD
  loadmem16 ZR0,PROGRAM_AREA      ; ZR0 = 書き込み先
  loadAY16 PROGRAM_AREA_SIZE      ; AY  = 読み取り長さ
  syscall FS_READ_BYTS            ; 以上設定で読み取り
  BRA ENTRY

CLEAR_STACK:
  loadmem16 ZP_STACK_PTR,STACK
  RTS

; ファイルがないとき
NOTFOUND:
  loadAY16 STR_NOTFOUND
  syscall CON_OUT_STR
  RTS

  ; ---------------------------------------------------------------
  ;   REPL
  ; ---------------------------------------------------------------
REPLOOP:
  ; ---------------------------------------------------------------
  ;   プロンプト表示
  loadAY16 STR_PROMPT
  syscall CON_OUT_STR
  ; ---------------------------------------------------------------
  ;   行入力
  LDA #$FF
  STA ZR0
  loadAY16 PROGRAM_AREA
  syscall CON_IN_STR
  LDA #$A
  syscall CON_OUT_CHR
ENTRY:
  ; ---------------------------------------------------------------
  ;   行内ループ
  loadmem16 ZP_PROGRAM_PTR,PROGRAM_AREA
LINE_LOOP:
  ;loadmem16 ZR0,STACK
  ;LDX ZP_STACK_PTR
  ;LDA (ZP_PROGRAM_PTR)
  ;BRK
  ;NOP
  LDA (ZP_PROGRAM_PTR)
  BEQ REPLOOP               ; 0終端で行終了
  JSR IS_DIGIT
  BCC @NOT_DIGIT
  ; atoi
  JSR ATOI
  BRA LINE_LOOP
@NOT_DIGIT:
  CMP #SQUOTE
  BEQ PUTSTR
  ; 比較演算
  CMP #'<'
  BEQ SMT
  CMP #'>'
  BEQ GRT
  CMP #'<'
  ; 四則演算
  CMP #'%'
  BEQ REM
  CMP #'-'
  BEQ MINUS
  CMP #'*'
  BEQ MUL
  CMP #'+'
  ; switchは続く･･･
  BNE SWITCH2

  ; ---------------------------------------------------------------
  ;   '+' 加算
PLUS:
  JSR SWEET16
  .SETCPU "SWEET16"
  POPD  @R11
  ST    R1
  POPD  @R11
  ADD   R1
PLUS1:
  STD   @R11
  RTN
  .SETCPU "65C02"
  BRA NEXT5

; 速度最悪のテキスト表示
PUTSTR:
  JSR INCPTR
  LDA (ZP_PROGRAM_PTR)
  CMP #SQUOTE
  BEQ NEXT5
  CMP #BSLASH
  BNE @NOTBS
  JSR INCPTR
  LDA (ZP_PROGRAM_PTR)
  CMP #'n'
  BNE @NOTLF
  LDA #$A
@NOTLF:
@NOTBS:
  syscall CON_OUT_CHR
  BRA PUTSTR

  ; ブランチすると0   FALSE
  ; ブランチしないと1 TRUE
  ; FALSE条件のブランチ命令を置いておく

  ; ---------------------------------------------------------------
  ;   '<' 小なり
SMT:
  ;LDA #$03          ; BC
  LDA #$04          ; BP
  STA COMPARE_BR
  STA COMPARE_BR+2
  BRA COMPARE1

  ; ---------------------------------------------------------------
  ;   '>' 大なり
GRT:
  ;LDA #$02          ; BNC
  LDA #$05          ; BM
  STA COMPARE_BR
  LDA #$06          ; BZ
  STA COMPARE_BR+2
COMPARE1:
  JMP COMPARE

  ; ---------------------------------------------------------------
  ;   '%' 剰余
REM:
  mem2mem16 R1,ZP_REM
  JSR PUSH_R1
NEXT5:
  BRA NEXT1

  ; ---------------------------------------------------------------
  ;   '-' 減算
MINUS:
  JSR SWEET16
  .SETCPU "SWEET16"
  POPD  @R11
  ST    R1
  POPD  @R11
  SUB   R1
  BR    PLUS1
  .SETCPU "65C02"

  ; ---------------------------------------------------------------
  ;   '*' 乗算
MUL:
  JSR SWEET16
  .SETCPU "SWEET16"
  POPD  @R11
  BZ    MUL_ZERO
  ST    R2      ; 右辺カウンタ
  POPD  @R11
  ST    R1      ; 左辺
  SET   R0,0
MUL_LOOP:
  ADD   R1
  DCR   R2
  BNZ   MUL_LOOP
  BR    PLUS1
MUL_ZERO:
  ; 読み捨てる
  DCR   R11
  DCR   R11
  BR    PLUS1
  .SETCPU "65C02"

;  ; ---------------------------------------------------------------
;  ;   'p' デバッグ表示
;p:
;  JSR SWEET16
;  .SETCPU "SWEET16"
;  POPD  @R11
;  ST    R1
;  RTN
;  .SETCPU "65C02"
;  JSR PRT_REG
;  ;mem2mem16 ZR0,R0
;  ;mem2AY16 R11
;  ;BRK
;  ;NOP
;  BRA NEXT1

  ; ---------------------------------------------------------------
  ;   '$' 文字入力
INPUT_CHR:
  syscall CON_IN_CHR
  STA R1
  STZ R1+1
  JSR PUSH_R1
NEXT2:
  BRA NEXT1

; -------------------------------------------------------------------
;   switch分岐の続き
; -------------------------------------------------------------------
SWITCH2:
  ;CMP #'p'
  ;BEQ p
  CMP #'$'
  BEQ INPUT_CHR
  CMP #'/'
  BEQ DIV
  CMP #$A
  BEQ NL
  CMP #'?'
  BNE SWITCH3

  ; ---------------------------------------------------------------
  ;   '?' 数値入力
INPUT_NUM:
  LDA #INPUT_BUF_SIZE
  STA ZR0
  loadAY16 INPUT_BUF
  syscall CON_IN_STR
  pushmem16 ZP_PROGRAM_PTR
  loadmem16 ZP_PROGRAM_PTR,INPUT_BUF
  LDA INPUT_BUF
  JSR IS_DIGIT
  BCS @SKP_ZERO
  LDA #0
@SKP_ZERO:
  JSR ATOI
  pullmem16 ZP_PROGRAM_PTR
NEXT1:
  BRA NEXT

  ; ---------------------------------------------------------------
  ;   '/' 除算
DIV:
  JSR SWEET16
  .SETCPU "SWEET16"
  SET   R3,0      ; R3:割る数の符号
  SET   R4,0      ; R4:割られる数の符号
  ; ---------------------------------------------------------------
  ;   右辺 割る数の準備
  POPD  @R11
  BNZ   NONZERO
  ; ゼロ除算例外
  RTN
  .SETCPU "65C02"
ERROR:
  loadAY16 STR_ERROR
  syscall CON_OUT_STR
  JMP REPLOOP
  .SETCPU "SWEET16"
NONZERO:
  BP    SKP_SIGNR
  ST    R1
  LD    R3
  INR   R3
  SUB   R1
SKP_SIGNR:
  ST    R1        ; R1 割る数の絶対値
  ; ---------------------------------------------------------------
  ;   左辺 割られる数の符号
  POPD  @R11
  BP    SKP_SIGNL
  ST    R2
  LD    R4
  INR   R4
  SUB   R2
SKP_SIGNL:        ; R0 割られる数の絶対値
  ; ---------------------------------------------------------------
  ;   絶対値 R0 / R1 を実行
  BS    R0_DIV_R1
  ST    R1
  ; R1 = %
  ; R2 = /
  ; ---------------------------------------------------------------
  ;   残差の符号を判断 - 割られる数の符号ママ
  LD    R4
  BZ    SKP_MREM
  ; 負の残差
  SET   R0,0
  SUB   R1
  ST    R1
SKP_MREM:
  LD    R1
  SET R5,ZP_REM
  STD @R5
  ; ---------------------------------------------------------------
  ;   商の符号を判断 - XOR
  LD  R3
  ADD R4
  SET R5,1
  CPR R5    ; 負号の合計数==1 ?
  BNZ SKP_MDIV
  ; 負の商
  SET R0,0
  SUB R2
  ST  R2
SKP_MDIV:
  LD  R2
  STD @R11
  RTN
  .SETCPU "65C02"
  BRA NEXT

  ; ---------------------------------------------------------------
  ;   '\n' 改行
NL:
  JSR CLEAR_STACK
  BRA NEXT

; -------------------------------------------------------------------
;   switch分岐の続き
; -------------------------------------------------------------------
SWITCH3:
  CMP #':'
  BEQ GETARRAY
  CMP #'='
  BEQ EQ
  CMP #' '
  BEQ LINENUM
  syscall UPPER_CHR
  CMP #'A'
  BCC NEXT
  CMP #'Z'+1
  BCC GETVER
NEXT:
  JSR INCPTR
LINE_LOOP1:
  JMP LINE_LOOP

  ; ---------------------------------------------------------------
  ;   'A'~'Z' 変数 -> Acc
GETVER:
  SEC
  SBC #'A'
  ASL               ; x2
  STA R1
  STZ R1+1
  JSR SWEET16
  .SETCPU "SWEET16"
  SET   R0,VAR
  BR    GETARRAY1
  .SETCPU "65C02"

  ; ---------------------------------------------------------------
  ;   ':' 配列の値を取得
GETARRAY:
  JSR SWEET16
  .SETCPU "SWEET16"
  POPD  @R11        ; インデックス
  ST    R1
  ADD   R1          ; x2
  SET   R1,ARRAY
GETARRAY1:
  ADD   R1          ; オフセット加算
  ST    R1
  LDD   @R1         ; ロード
  STD   @R11        ; プッシュ
  RTN
  .SETCPU "65C02"
  BRA NEXT

; 16bit除算サブルーチン
R0_DIV_R1:
  .SETCPU "SWEET16"
  SET   R2,$FFFF  ; 引けた回数カウント
DIVLOOP:
  INR R2
  SUB R1
  BC  DIVLOOP
  ADD R1
  ; R0 = %
  ; R2 = /
  RS
  .SETCPU "65C02"

  ; ---------------------------------------------------------------
  ;   ' ' 行番号
LINENUM:
  JSR SWEET16
  ; 行番号をPOP
  .SETCPU "SWEET16"
  POPD  @R11
  CPR   R9
  RTN
  .SETCPU "65C02"  ; GOTOフラグ
  ; if(!gotoing) continue;
  BBR0  ZP_FLAGS,NEXT
  ; GOTO実行中
  LDA R13       ; 比較結果
  ORA R13+1
  BNE LINESKP
  ; GOTOを脱出
  STZ ZP_FLAGS  ; SMB0 ZP_FLAGS
NEXT6:
NEXT3:
  BRA NEXT
LINESKP:
  ; GOTO継続～行スキップ
  LDY #0        ; 1行が255行を超えると爆発
@LOOP:
  INY
  LDA (ZP_PROGRAM_PTR),Y
  BEQ @END
  CMP #$A
  BNE @LOOP
@END:
  INY
  TYA
  CLC
  ADC ZP_PROGRAM_PTR
  STA ZP_PROGRAM_PTR
  LDA #0
  BCC @NOINCH
  INC ZP_PROGRAM_PTR+1
@NOINCH:
  BRA LINE_LOOP1

  ; ---------------------------------------------------------------
  ;   '=' 代入あるいは比較
EQ:
  JSR INCPTR
  LDA (ZP_PROGRAM_PTR)
  CMP #'='
  BEQ EQEQ
  ; ---------------------------------------------------------------
  ;   '=' 代入
STORE:
  ;LDA (ZP_PROGRAM_PTR)  ; 右辺を取得
  CMP #'?'
  BNE PUTCHR
  ; ---------------------------------------------------------------
  ;   '=?' 数値表示
PUTNUM:
  ; ---------------------------------------------------------------
  ;   スペースセットアップ
  LDA #' '
  LDX #6
@SETUPLOOP:
  STA INPUT_BUF-1,X
  DEX
  BNE @SETUPLOOP
  STZ INPUT_BUF+6   ; ヌル終端
  ; ---------------------------------------------------------------
  ;   十進変換
  JSR SWEET16
  .SETCPU "SWEET16"
  SET   R5,INPUT_BUF+5  ; 出力先
  SET   R4,'0'    ; 文字コードオフセット
  SET   R3,5      ; カウンタ
  POPD  @R11      ; 表示したい数値
  BP    PUTNUM_LOOP
  ; 負数
  ST    R1
  SET   R2,INPUT_BUF
  SET   R0,'-'
  ST    @R2       ; 負号を設置
  SET   R0,0
  SUB   R1        ; 絶対値取得
PUTNUM_LOOP:
  SET   R1,10     ; 10で割る
  BS    R0_DIV_R1 ; R0 <- %10, R2 <- /10
  ADD   R4        ; 剰余に'0'を加算
  ST    @R5       ; 格納
  DCR   R5
  DCR   R5
  LD    R2        ; 商
  BZ    PUTNUM_END
  DCR   R3
  BNZ   PUTNUM_LOOP
PUTNUM_END:
  RTN
  .SETCPU "65C02"
  loadAY16 INPUT_BUF
  syscall CON_OUT_STR
  BRA NEXT3
PUTCHR:
  CMP #'$'
  BNE SETPC
  ; ---------------------------------------------------------------
  ;   '=$' 文字表示
  JSR SWEET16
  .SETCPU "SWEET16"
  POPD  @R11
  RTN
  .SETCPU "65C02"
  LDA R0
  syscall CON_OUT_CHR
NEXT4:
  BRA NEXT3
EQEQ:
  CMP #'='
  BNE SETPC
  ; ---------------------------------------------------------------
  ;   '==' 比較
  LDA #$07          ; BNZ
  STA COMPARE_BR
  STA COMPARE_BR+2
COMPARE:
  JSR SWEET16
  ; s1 == s2
  .SETCPU "SWEET16"
  SET   R1,0        ; 返り値 bool
  POPD  @R11
  ST    R2
  POPD  @R11
  CPR   R2
COMPARE_BR:
  BNZ   EQEQ_SKPINR ; != -> 0 FALSE
  BNZ   EQEQ_SKPINR ; != -> 0 FALSE
  ; == -> 1 TRUE
  INR   R1
EQEQ_SKPINR:
  LD    R1
  STD   @R11
  RTN
  .SETCPU "65C02"
  BRA NEXT4
SETPC:
  CMP #'#'
  BNE SETARRAY
  ; ---------------------------------------------------------------
  ;   '#' PC代入
  JSR SWEET16
  .SETCPU "SWEET16"
  POPD  @R11        ; 新しい行番号
  BZ    SWEETNEXT
  ST    R9
  SET   R10,PROGRAM_AREA
  RTN
  .SETCPU "65C02"
  SMB0 ZP_FLAGS
  BRA NEXT4
SETARRAY:
  CMP #':'
  BNE SETVAR
  ; ---------------------------------------------------------------
  ;   '=:' 配列代入
  JSR SWEET16
  .SETCPU "SWEET16"
  POPD  @R11        ; インデックス
  ST    R1
  ADD   R1          ; x2
  SET   R1,ARRAY
SETARRAY1:
  ADD   R1          ; オフセット加算
  ST    R1
  POPD  @R11        ; 内容をスタックから取得
  STD   @R1         ; ストア
SWEETNEXT:
  RTN
  .SETCPU "65C02"
  BRA NEXT4
SETVAR:
  syscall UPPER_CHR
  CMP #'A'
  BCC NEXT4
  CMP #'Z'+1
  BCS NEXT4
  ; ---------------------------------------------------------------
  ;   'A'~'Z' 変数代入
  SEC
  SBC #'A'
  ASL               ; x2
  STA R1
  STZ R1+1
  JSR SWEET16
  .SETCPU "SWEET16"
  SET   R0,VAR
  BR    SETARRAY1
  .SETCPU "65C02"

; -------------------------------------------------------------------
;   プログラムポインタのインクリメント
; -------------------------------------------------------------------
INCPTR:
  INC ZP_PROGRAM_PTR
  BNE @NOINCH
  INC ZP_PROGRAM_PTR+1
@NOINCH:
  RTS

; -------------------------------------------------------------------
;   ZP_PROGRAM_PTRの指す10進数をスタックに取り込む
; -------------------------------------------------------------------
ATOI:
  SEC
  SBC #'0'
  STA R1                  ; 最上位桁をセット
  STZ R1+1
  JSR INCPTR
ATOILOOP:
  LDA (ZP_PROGRAM_PTR)
  JSR IS_DIGIT
  BCC ATOIEND
  ; R1 <- R1 * 10
  ; R1 <- R1 + @PTR++
  JSR SWEET16
  .SETCPU "SWEET16"
  SET R3,'0'
  SET R2,9
  LD  R1        ; R0 <- R1
X10LOOP:
  ADD R1
  DCR R2
  BNZ X10LOOP
  ST  R1        ; R1 <- R1 * 10
  LD  @R10
  SUB R3
  ADD R1        ; R0 <- R0 + R1
  ST  R1
  RTN
  .SETCPU "65C02"
  BRA ATOILOOP
ATOIEND:

; -------------------------------------------------------------------
;   R1をスタックにプッシュする
;   なぜR1なのか：ATOIの都合
; -------------------------------------------------------------------
PUSH_R1:
  JSR SWEET16
  .SETCPU "SWEET16"
  LD  R1
  STD @R11
  RTN
  .SETCPU "65C02"
  RTS

; -------------------------------------------------------------------
;   Aが数字かを確かめる
; -------------------------------------------------------------------
;   input: A, output: C
; -------------------------------------------------------------------
IS_DIGIT:
  CMP #'0'
  BCC @NOT
  CMP #'9'+1
  BCS @NOT
@DIG:
  SEC
  RTS
@NOT:
  CLC
  RTS

STR_PROMPT:
  .BYTE "NVTL>",$0

STR_ERROR:
  .BYTE "ERR",$A,$0

PRT_REG:
  LDA #'$'
  syscall CON_OUT_CHR
  LDA R1+1
  JSR PRT_BYT
  LDA R1
  JSR PRT_BYT
  RTS

PRT_BYT:
  JSR BYT2ASC
  PHY
  JSR PRT_C_CALL
  PLA
PRT_C_CALL:
  syscall CON_OUT_CHR
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

PRT_LF:
  ; 改行
  LDA #$A
  BRA PRT_C_CALL

STR_NOTFOUND:
  .BYT "Input File Not Found.",$A,$0

