; Sweet16 port to MIRACOS APP
;
; Based on Replica 1 port. See: https://github.com/jefftranter/6502/tree/master/asm/sweet16
;   Based on Atari port. See: http://atariwiki.strotmann.de/wiki/Wiki.jsp?page=Sweet16Mac65
;
; ***************************
; *                         *
; * APPLE II PSEUDO MACHINE *
; *        INTERPRETER      *
; *                         *
; * COPYRIGHT (C) 1977      *
; * APPLE COMPUTER INC.     *
; *                         *
; * STEVE WOZNIAK           *
; *                         *
; ***************************
; * TITLE: SWEET 16 INTERPRETER

.IFDEF loadAY16
  .INCLUDE "generic.mac"
.ENDIF

;-------------------------------
.ZEROPAGE
.EXPORT R0,R1,R2,R3,R4,R5,R6,R7,R8,R9,R10,R11,R12,R13,R14,R15
R0: .RES 32
R1 = R0+(1*2)
R2 = R0+(2*2)
R3 = R0+(3*2)
R4 = R0+(4*2)
R5 = R0+(5*2)
R6 = R0+(6*2)
R7 = R0+(7*2)
R8 = R0+(8*2)
R9 = R0+(9*2)
R10 = R0+(10*2)
R11 = R0+(11*2)
R12 = R0+(12*2)
R13 = R0+(13*2)
R14 = R0+(14*2)
R15 = R0+(15*2)

;-------------------------------
.BSS
ACC:    .RES 1
XREG:   .RES 1
YREG:   .RES 1
STATUS: .RES 1

;-------------------------------
.SEGMENT "LIB"
.EXPORT SWEET16

; -------------------------------------------------------------------
;                               VM起動
; -------------------------------------------------------------------
SWEET16:
  ; ---------------------------------------------------------------
  ;   6502のレジスタの状態を保存
  STA ACC
  STX XREG
  STY YREG
  PHP
  PLA
  STA STATUS
  CLD
  ; ---------------------------------------------------------------
  ;   JSRで積まれた戻りアドレスをPCにする
  PLA
  STA R15
  PLA
  STA R15+1

; -------------------------------------------------------------------
;                            メインループ
; -------------------------------------------------------------------
CPU_LOOP:
  JSR SW16C
  BRA CPU_LOOP

; フェッチのためにSWEET16 PCを進める
SW16C:
  INC R15
  BNE @NOINCH
  INC R15+1
@NOINCH:
  ; ---------------------------------------------------------------
  ;   命令を取得して処理
  LDA (R15)   ; フェッチ
  AND #$0F    ; *
  ASL         ; | 7 OPCODE | REGSPC 0 @R15
  TAX         ; | X <- REGSPC * 2 （レジスタ指定）
  LSR         ; | A <- REGSPC
  EOR (R15)   ; REGSPC XOR @R15
  BEQ @NONREG ; 上位ニブルが0なので非レジスタ指定命令
  ; ---------------------------------------------------------------
  ;   レジスタ指定命令 1n~Fn
  STX R14+1                 ; * INDICATE PRIOR RESULT REG
  LSR                       ; | 7 XXXX---- 0
  LSR                       ; |   >>>
  LSR                       ; | 7 ---XXXX- 0 -> Y （オペコード指定）
  TAY                       ; |
  LDA REG_OPECODE_TABLE-2,Y ; * 命令ルーチンへの相対アドレスを
  STA BRANCH_ROOT+1         ; | テーブルから取ってセットし
  JMP BRANCH_ROOT           ; | BRA命令へ飛ぶ
  ; ---------------------------------------------------------------
  ;   非レジスタ指定命令 00~0F
@NONREG:
  INC R15
  BNE @NOINCH2
  INC R15+1
@NOINCH2:
  LDA NRG_OPECODE_TABLE,X   ; 命令ルーチンへの相対アドレスを取得
  STA BRANCH_ROOT+1         ; BRAのオペランドにセット
  LDA R14+1                 ; PRIOR RESULT REG INDEX
  LSR                       ; PREPARE CARRY FOR BC. BNC.
  JMP BRANCH_ROOT           ; BRAへ飛ぶ

SETZ:
  LDA (R15),Y     ; 上位オペランドを取得（オペコードから、Y=2）
  STA R0+1,X      ; 指定レジスタに置く
  DEY             ; Y <- 1
  LDA (R15),Y     ; 下位オペランドを取得
  STA R0,X        ; 指定レジスタに置く
  TYA             ; * (A <- 1)
  SEC             ; |
  ADC R15         ; | PC += 2
  STA R15         ; |
  BCC @NOINCH     ; |
  INC R15+1       ; |
@NOINCH:          ; |
  RTS

; -------------------------------------------------------------------
;  00                      6502モードに復帰
; -------------------------------------------------------------------
RTN:
  ; ---------------------------------------------------------------
  ;   6502のレジスタの状態を復帰
  PLA           ; 戻りアドレスをPOP
  PLA
  LDA STATUS    ; BSSに保存したレジスタを復帰
  PHA
  LDA ACC
  LDX XREG
  LDY YREG
  PLP
  ; ---------------------------------------------------------------
  ;   6502モードに復帰
  JMP (R15)

; -------------------------------------------------------------------
;  1n                     2バイト即値セット
;                             Rn <- IMM
; -------------------------------------------------------------------
SET:
  BRA SETZ    ; ALWAYS

; -------------------------------------------------------------------
;  2n                           ロード
;                              R0 <- Rn
; -------------------------------------------------------------------
LD:
  LDA R0,X
  STA R0
  LDA R0+1,X   ; MOV RX TO R0
  STA R0+1
  RTS

; -------------------------------------------------------------------
;  0A                    ソフトウェアブレーク
; -------------------------------------------------------------------
BK:
  BRK
  NOP
  RTS

; -------------------------------------------------------------------
;  3n                           ストア
;                              Rn <- R0
; -------------------------------------------------------------------
ST:
  LDA R0
  STA R0,X
  LDA R0+1
  STA R0+1,X
  RTS

; -------------------------------------------------------------------
;  5n                     間接1バイトストア
;                           @(Rn++)L <- R0
; -------------------------------------------------------------------
ST_AT:
  LDA R0
ST_AT2:
  STA (R0,X)
ST_AT3:
  STZ R14+1 ; INDICATE R0 IS RESULT NEG

; -------------------------------------------------------------------
;  En                       インクリメント
;                                Rn++
; -------------------------------------------------------------------
INR:
  INC R0,X
  BNE @NOINCH
  INC R0+1,X
@NOINCH:
  RTS

; -------------------------------------------------------------------
;  4n                     間接1バイトロード
;                           R0 <- @(Rn++)L
; -------------------------------------------------------------------
LD_AT:
  LDA (R0,X)
  STA R0
  STZ R0+1
  BRA ST_AT3   ; ALWAYS

; -------------------------------------------------------------------
;  8n                         1バイトPOP
;                           R0 <- @(--Rn)L
; -------------------------------------------------------------------
POP:
  LDY #$00
  BRA POP2    ; ALWAYS

; -------------------------------------------------------------------
;  Cn                         2バイトPOP
;                          R0 <- @(----Rn)
; -------------------------------------------------------------------
POPD:
  JSR DCR     ; *
  LDA (R0,X)  ; | Y <- @(--Rn)
  TAY         ; |
POP2:
  JSR DCR     ; *
  LDA (R0,X)  ; | A <- @(--Rn)
  STA R0
  STY R0+1
POP3:
  STZ R15+1   ; INDICATE R0 AS LAST RES. REG
  RTS

; -------------------------------------------------------------------
;  6n                     間接2バイトロード
;                          R0 <- @(Rn++++)
; -------------------------------------------------------------------
LDD_AT:
  JSR LD_AT   ; 下位バイトを格納
  LDA (R0,X)
  STA R0+1
  BRA INR     ; Rn++

; -------------------------------------------------------------------
;  7n                     間接2バイトストア
;                          @(Rn++++) <- R0
; -------------------------------------------------------------------
STD_AT:
  JSR LD_AT
  LDA R0+1
  STA (R0,X)
  BRA INR

; -------------------------------------------------------------------
;  9n                  間接ストア・ポップ（？）
;                           R0 <- @(--Rn)
; -------------------------------------------------------------------
STP_AT:
  JSR DCR     ; --Rn
  LDA R0
  STA (R0,X)
  BRA POP3    ; INDICATE R0 AS LAST RES REG

; -------------------------------------------------------------------
;  Fn                        デクリメント
;                                Rn--
; -------------------------------------------------------------------
DCR:
  LDA R0,X
  BNE @NODECH ; --Rn
  DEC R0+1,X
@NODECH:
  DEC R0,X
  RTS

BRANCH_ROOT:
  BRA ST      ; オペランドは動的に書き換わる

; -------------------------------------------------------------------
;  Bn                            減算
;                           R0 <- R0 - Rn
; -------------------------------------------------------------------
SUB:
  LDY #$00    ; Y = 0      FOR SUB

; -------------------------------------------------------------------
;  Dn                            比較
;                           compare R0 Rn
; -------------------------------------------------------------------
CPR:          ; Y = 13 * 2 FOR CPR
  SEC
  LDA R0
  SBC R0,X
  STA R0,Y   ; RY=R0-RX
  LDA R0+1
  SBC R0+1,X
SUB2:
  STA R0+1,Y
  TYA         ; 変更したレジスタ
  ADC #$00    ; キャリーを含めてステータスへ
  STA R14+1
  RTS

; -------------------------------------------------------------------
;  An                            加算
;                           R0 <- R0 + Rn
; -------------------------------------------------------------------
ADD:
  LDA R0
  ADC R0,X
  STA R0      ; R0=RX+R0
  LDA R0+1
  ADC R0+1,X
  LDY #$00    ; R0 FOR RESULT
  BEQ SUB2    ; FINISH ADD

; -------------------------------------------------------------------
;  0C                    サブルーチン呼び出し
; -------------------------------------------------------------------
BS:           ; NOTE X REG IS 12 * 2 !
  LDA R15     ; *
  JSR ST_AT2  ; | push PC to stack (R12 sp)
  LDA R15+1   ; |
  JSR ST_AT2  ; |

; -------------------------------------------------------------------
;  01                         無条件分岐
; -------------------------------------------------------------------
BR:
  CLC

; -------------------------------------------------------------------
;  02                     キャリーなしで分岐
; -------------------------------------------------------------------
BNC:
  BCS BNC2    ; NO CARRY TEST

BR1:          ; DISPLACEMENT BYTE
  LDA (R15),Y
  BPL BR2
  DEY
BR2:          ; ADD TO PC
  ADC R15
  STA R15
  TYA
  ADC R15+1
  STA R15+1
BNC2:
  RTS
BC:
  BCS BR
  RTS

; -------------------------------------------------------------------
;  04                        プラスで分岐
; -------------------------------------------------------------------
BP:
  ASL
  TAX         ; TO X REG FOR INDEX
  LDA R0+1,X  ; TEST FOR PLUS, BRANCH IF SO
  BPL BR1
  RTS

; -------------------------------------------------------------------
;  05                       マイナスで分岐
; -------------------------------------------------------------------
BM:
  ASL       ; DOUBLE RESULT REG INDEX
  TAX
  LDA R0+1,X
  BMI BR1
  RTS

; -------------------------------------------------------------------
;  06                         ゼロで分岐
; -------------------------------------------------------------------
BZ:
  ASL       ; DOUBLE RESULT REG INDEX
  TAX
  LDA R0,X
  ORA R0+1,X
  BEQ BR1
  RTS

; -------------------------------------------------------------------
;  07                        非ゼロで分岐
; -------------------------------------------------------------------
BNZ:
  ASL       ; DOUBLE RESULT REG INDEX
  TAX
  LDA R0,X
  ORA R0+1,X
  BNE BR1
  RTS

; -------------------------------------------------------------------
;  08                          -1で分岐
; -------------------------------------------------------------------
BM1:
  ASL       ; DOUBLE RESULT REG INDEX
  TAX
  LDA R0,X
  AND R0+1,X
  EOR #$FF
  BEQ BR1
  RTS

; -------------------------------------------------------------------
;  09                         非-1で分岐
; -------------------------------------------------------------------
BNM1:
  ASL       ; DOUBLE RESULT REG
  TAX
  LDA R0,X
  AND R0+1,X
  EOR #$FF
  BNE BR1
NUL:
  RTS

; -------------------------------------------------------------------
;  0B                    サブルーチンから復帰
; -------------------------------------------------------------------
RS:
  LDX #$18  ; 12*2 FOR R12 AS STACK POINTER
  JSR DCR   ; SP--
  ; POP HIGH RETURN ADDRESS TO PC
  LDA (R0,X)
  STA R15+1
  ; SAME WITH LOW ORDER BYTE
  JSR DCR
  LDA (R0,X)
  STA R15
  RTS

REG_OPECODE_TABLE:
  .BYTE <(SET     -BRANCH_ROOT-2)   ; 1n
NRG_OPECODE_TABLE:
  .BYTE <(RTN     -BRANCH_ROOT-2)   ; 0
  .BYTE <(LD      -BRANCH_ROOT-2)   ; 2n
  .BYTE <(BR      -BRANCH_ROOT-2)   ; 1
  .BYTE <(ST      -BRANCH_ROOT-2)   ; 3n
  .BYTE <(BNC     -BRANCH_ROOT-2)   ; 2
  .BYTE <(LD_AT   -BRANCH_ROOT-2)   ; 4n
  .BYTE <(BC      -BRANCH_ROOT-2)   ; 3
  .BYTE <(ST_AT   -BRANCH_ROOT-2)   ; 5n
  .BYTE <(BP      -BRANCH_ROOT-2)   ; 4
  .BYTE <(LDD_AT  -BRANCH_ROOT-2)   ; 6n
  .BYTE <(BM      -BRANCH_ROOT-2)   ; 5
  .BYTE <(STD_AT  -BRANCH_ROOT-2)   ; 7n
  .BYTE <(BZ      -BRANCH_ROOT-2)   ; 6
  .BYTE <(POP     -BRANCH_ROOT-2)   ; 8n
  .BYTE <(BNZ     -BRANCH_ROOT-2)   ; 7
  .BYTE <(STP_AT  -BRANCH_ROOT-2)   ; 9n
  .BYTE <(BM1     -BRANCH_ROOT-2)   ; 8
  .BYTE <(ADD     -BRANCH_ROOT-2)   ; An
  .BYTE <(BNM1    -BRANCH_ROOT-2)   ; 9
  .BYTE <(SUB     -BRANCH_ROOT-2)   ; Bn
  .BYTE <(BK      -BRANCH_ROOT-2)   ; A
  .BYTE <(POPD    -BRANCH_ROOT-2)   ; Cn
  .BYTE <(RS      -BRANCH_ROOT-2)   ; B
  .BYTE <(CPR     -BRANCH_ROOT-2)   ; Dn
  .BYTE <(BS      -BRANCH_ROOT-2)   ; C
  .BYTE <(INR     -BRANCH_ROOT-2)   ; En
  .BYTE <(NUL     -BRANCH_ROOT-2)   ; D
  .BYTE <(DCR     -BRANCH_ROOT-2)   ; Fn
  .BYTE <(NUL     -BRANCH_ROOT-2)   ; E
  .BYTE <(NUL     -BRANCH_ROOT-2)   ; UNUSED
  .BYTE <(NUL     -BRANCH_ROOT-2)   ; F

