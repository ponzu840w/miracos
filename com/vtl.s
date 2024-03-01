; -------------------------------------------------------------------
;                           MichaelのVTL-2
; -------------------------------------------------------------------
; https://github.com/barrym95838/6502-Assembly/blob/main/VTLC02
; 移植にあたる変更点
; * 入出力をシステムコールに変更
; * ゼロページ、CODE、BSSの配置を自由化
; -------------------------------------------------------------------
.INCLUDE "../generic.mac"     ; 汎用マクロ
.PROC BCOS
  .INCLUDE "../syscall.inc"   ; システムコール番号定義
.ENDPROC
.INCLUDE "../syscall.mac"     ; 簡単システムコールマクロ
.INCLUDE "../FXT65.inc"       ; ハードウェア定義
.INCLUDE "../fs/structfs.s"   ; ファイルシステム関連構造体定義
.INCLUDE "../zr.inc"          ; ZPレジスタZR0..ZR5

;234567890123456789012345678901234567890123456789012345
;    .opt Proc65c02
;-----------------------------------------------------;
;             VTL-2 for the 65C02 (VTLC02)            ;
;           Original Altair 680b version by           ;
;          Frank McCoy and Gary Shannon 1977          ;
;    2012: Adapted to the 6502 by Michael T. Barry    ;
;    2024: Port to MIRACOS(FxT-65) by @ponzu840w      ;
;-----------------------------------------------------;
;        Copyright (c) 2012, Michael T. Barry
;       Revision B (c) 2015, Michael T. Barry
;       Revision C (c) 2015, Michael T. Barry
;     Revision C02 (c) 2022, Michael T. Barry
;               All rights reserved.
;
; VTLC02 is a ligntweight "self-contained" IDE, and
;   features a command line, program editor and
;   language interpreter, all in 957 bytes of dense
;   65C02 machine code.  The "only" thing missing is a
;   secondary storage facility for your programs, but
;   this Kowalski version assumes that you will be
;   copying/pasting code from the simulator host.
;
; Redistribution and use in source and binary forms,
;   with or without modification, are permitted,
;   provided that the following conditions are met: 
;
; 1. Redistributions of source code must retain the
;    above copyright notice, this list of conditions
;    and the following disclaimer. 
; 2. Redistributions in binary form must reproduce the
;    above copyright notice, this list of conditions
;    and the following disclaimer in the documentation
;    and/or other materials provided with the
;    distribution. 
;
; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS
; AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED
; WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
; IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
; FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT
; SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
; FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
; EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
; NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
; SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
; INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
; LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
; OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
; IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
; ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
;-----------------------------------------------------;
; Except for the differences discussed below, VTLC02
;   was created to duplicate the OFFICIALLY DOCUMENTED
;   behavior of Frank's 680b version, detailed here:
;     http://www.altair680kit.com/manuals/Altair_
;     680-VTL-2%20Manual-05-Beta_1-Searchable.pdf
;   These versions ignore all syntax errors and plow
;   through VTL-2 programs with the assumption that
;   they are "correct", but in their own unique ways,
;   so any claims of compatibility are null and void
;   for VTL-2 code brave (or stupid) enough to stray
;   from the beaten path.
;
; Differences between the 680b and 65c02 versions:
; * {&} and {*} are initialized on entry.
; * Division by zero returns 65535 for the quotient and
;     the dividend for the remainder (the original 6800
;     version froze).
; * The 65c02 has NO 16-bit registers (other than PC)
;     and less overall register space than the 6800,
;     so the interpreter reserves some obscure VTLC02
;     variables {@ $ ( ) 0 1 2 3 4 5 6 7 8 9 < > : ?}
;     for its internal use (the 680b version used a
;     similar tactic, but differed in the details).
;     Parentheses nested deeper than nine levels may
;     result in unintended side-effects.
; * Users wishing to call a machine language subroutine
;     via the system variable {>} must first set the
;     system variable {"} to the proper address vector
;     (for example, "=768).
; * The x register is used to point to a simple VTLC02
;     variable (it can't point explicitly to an array
;     element like the 680b version because it's only
;     8-bits).  In the comments, var[x] refers to the
;     16-bit contents of the zero-page variable pointed
;     to by register x (residing at addresses x, x+1).
; * The y register is used as a pointer offset inside
;     a VTLC02 statement (easily handling the maximum
;     statement length of about 128 bytes).  In the
;     comments, @[y] refers to the 16-bit address
;     formed by adding register y to the value in {@}.
; * The behavior of this interpreter is similar to the
;     680b version, but it has been reorganized into a
;     more 65c02-friendly format (65c02s have no 'bsr'
;     instruction, so 'stuffing' subroutines within 128
;     bytes of the caller is only advantageous for
;     relative branches).
; * This version is based on the original port, which
;     was wound rather tightly, in a failed attempt to
;     fit it into 768 bytes like the 680b version; many
;     structured programming principles were sacrificed
;     in that effort.  The 65c02 simply requires more
;     instructions than the 6800 does to manipulate 16-
;     bit quantities, but the overall performance is
;     better due to the 65c02's lower average clocks/
;     instruction ratio, and optimizations not present
;     in the original version.
; * VTLC02 is my free gift (?) to the world.  It may be
;     freely copied, shared, and/or modified by anyone
;     interested in doing so, with only the stipulation
;     that any liabilities arising from its use are
;     limited to the price of VTLC02 (nothing).
;-----------------------------------------------------;
; 2015: Revision B included some space optimizations
;         (suggested by dclxvi) and enhancements
;         (suggested by mkl0815 and Klaus2m5):
;
; * Bit-wise operators & | ^ (and, or, xor)
;   Example:  A=$|128) Get a char and set hi-bit
;
; * Absolute addressed 8-bit memory "PEEK" and "POKE"
;   via the {< @} facility:
;   Example:  <=P) Point to the I/O port at P
;             @=@&254^128) Clear bit 0 & flip bit 7
;
; * Starting with VTL02B, the space character is no
;     longer a valid user variable nor a "valid" binary
;     operator.  It's now only significant as a numeric
;     constant terminator and as a place-holder in
;     strings and program listings, where it may be
;     used to improve human readability (at a slight
;     cost in execution speed and memory consumption).
;   Example:
;   *              (VTL-2)
;       1000 A=1)         Init loop index
;       1010 ?=A)           Print index
;       1020 ?="")          Newline
;       1030 A=A+1)         Update index
;       1040 #=A<10*1010) Loop until done
;
;   *              (VTL02B and later)
;       1000 A = 1             ) Init loop index
;       1010     ? = A         )   Print index
;       1020     ? = ""        )   Newline
;       1030     A = A + 1     )   Update index
;       1040 # = A < 10 * 1010 ) Loop until done
;
; 2015: Revision C includes further enhancements
;   (suggested by Klaus2m5):
;
; * "THEN" and "ELSE" operators [ ]
;     A[B returns 0 if A is 0, otherwise returns B.
;     A]B returns B if A is 0, otherwise returns 0.
;
; * Some effort was made to balance interpreter code
;     density with interpreter performance, while
;     remaining within the 1KB constraint.  Structured
;     programming principles remained at low priority.
;-----------------------------------------------------;
; VTLC02 variables occupy RAM addresses $0080 to $00ff,
;   and are little-endian, in the 65c02 tradition.
; The use of lower-case and some control characters for
;   variable names is allowed, but not recommended; any
;   attempts to do so would likely result in chaos, due
;   to aliasing with upper-case and system variables.
; Variables tagged with an asterisk are used internally
;   by the interpreter and may change without warning.
;   {@ 0..9 : > ?} are (usually) intercepted by the
;   interpreter, so their internal use by VTLC02 is
;   "safe".  The same cannot be said for {; < =}, so be
;   careful!

.ZEROPAGE
at:     .RES 2      ; $80 {@}* internal pointer / mem byte
; VTLC02 standard user variable space
        .RES ('_'+1-'A')*2
                    ; $82..$BF {A B C .. X Y Z [ \ ] ^ _}
; VTLC02 system variable space
        .RES 2      ; $C0 { }  starting with VTL02B, the
;                       space character is no longer a
;                       valid user variable nor binary
;                       operator; it is demoted to a
;                       numeric constant terminator and
;                       as a place-holder in strings
;                       and program listings.
bang:   .RES 2      ; $C2 {!}  return line number
quote:  .RES 2      ; $C4 {"}  user ml subroutine vector
pound:  .RES 2      ; $C6 {#}  current line number
dolr:   .RES 2      ; $C8 {$}  character I/O
remn:   .RES 2      ; $CA {%}  remainder of last division
ampr:   .RES 2      ; $CC {&}  pointer to start of array
tick:   .RES 2      ; $CE {'}  pseudo-random number
lparen: .RES 2      ; $D0 {(}* old line # / begin sub-exp
        .RES 2      ; $D2 {)}  end sub-exp / start comment
star:   .RES 2      ; $D4 {*}  pointer to end of free mem
        .RES 5*2    ; $D6..$DF {+ , - . /}  valid user variables
; Interpreter argument stack space
arg:    .RES 11*2   ; $E0..$F5 {0 1 2 3 4 5 6 7 8 9 :}*
; Rarely used variables and argument stack overflow
        .RES 2      ; $F6 {;}  valid user variable
lthan:  .RES 2      ; $F8 {<}* byte pointer for peek/poke
        .RES 2      ; $FA {=}  valid user variable
gthan:  .RES 2      ; $FC {>}* temp / call ML subroutine
ques:   .RES 2      ; $FE {?}* temp / terminal I/O
;
;nulstk   = $01ff    ; system stack resides in page 1

;-----------------------------------------------------;
; Equates for the Kowalski 65c02 simulator
ESC      = 27       ; "Cancel current input line" key
;CR       = 13       ; newline for output
LF       = 10       ; line feed char
CR = LF
BS       = 8        ; "Delete last keypress" key
OP_OR    = '|'      ; Bit-wise OR operator
DQUOTE   = $22

.BSS
linbuf:  .RES 512    ;= $0200    ; input line buffer
prgm:    .RES 4096   ;= $0400    ; VTLC02 program grows from here
himem     = $4000    ;   ... up to the top of user RAM
;vtlc02:  .RES 100 ;= $fc00    ; interpreter cold entry point
;                     (warm entry point is startok)
;io_area  = $f000      ;configure simulator terminal I/O
;acia_tx  = io_area+1  ;acia tx data register
;acia_rx  = io_area+4  ;acia rx data register
;=====================================================;
;    .org vtlc02
.CODE
;-----------------------------------------------------;
; Initialize program area pointers and start VTLC02
; 17 bytes
    lda  #<prgm     ;
    sta  ampr       ; {&} -> empty program
    lda  #>prgm     ;
    sta  ampr+1     ;
    lda  #<himem    ;
    sta  star       ; {*} -> top of user RAM
    lda  #>himem    ;
    sta  star+1     ;
startok:
    sec             ; request "OK" message
; - - - - - - - - - - - - - - - - - - - - - - - - - - ;
; Start/restart VTLC02 command line with program intact
; 27 bytes
start:
    cld             ; a sensible precaution
    ;ldx  #<nulstk   ;
    ;txs             ; drop whatever is on the stack
    bcc  user       ; skip "OK" if carry clear
    ldy  #252       ; (-4)
prompt:
    lda  okay-252,y ; output "\nOK\n" to console
    jsr  outch      ;   print char
    iny             ;   advance y
    bne  prompt     ; continue until y wraps
user:
    jsr  inln       ; input a line from the user
    ldx  #pound     ; cvbin destination = {#}
    jsr  cvbin      ; does line start with a number?
    beq  direct     ;   no: execute direct statement
; - - - - - - - - - - - - - - - - - - - - - - - - - - ;
; Delete/insert/replace program line or list program
; 7 bytes
    clc             ;
    lda  pound      ;
    ora  pound+1    ; {#} = 0?
    bne  edit       ;   no: delete/insert/replace line
; - - - - - - - - - - - - - - - - - - - - - - - - - - ;
; List program to terminal and restart "OK" prompt
; entry:  Carry must be clear
; uses:   findln:, outch:, prnum:, prstr:, {@ (}
; exit:   to command line via findln:
; 17 bytes
list_:
    jsr  findln     ; find program line >= {#}
    ldx  #lparen    ; line number for prnum
    jsr  prnum      ; print the line number
    tax             ; \0 for delimiter
    lda  #' '       ; subst ' ' for line length byte
    jsr  prstr1     ; print the rest of the line
    sec             ; prepare for next line
    bra  list_      ;
;-----------------------------------------------------;
; The main program execution loop
; entry:  with (cs) via "beq direct" in user:
; exit:   to command line via findln: or "beq start"
; 45 bytes
progr:
    beq  eloop0     ; if {#} = 0 then ignore and
    ldy  lparen+1   ;   continue (false branch)
    ldx  lparen     ; else did {#} change?
    cpy  pound+1    ;   yes: perform a branch, with
    bne  branch     ;     carry flag conditioned for
    cpx  pound      ;     the appropriate direction.
    beq  eloop      ;   no: execute next line (cs)
branch:
    inx             ;   execute a VTLC02 branch
    bne  branch2    ;
    iny             ;
branch2:
    stx  bang       ;   {!} = {(} + 1 (return ptr)
    sty  bang+1     ;
eloop0:
    rol             ;
    eor  #1         ; complement carry flag
    ror             ;
eloop:
    jsr  findln     ; find first/next line >= {#}
    iny             ; skip over the length byte
direct:
    php             ; (cc: program, cs: direct)
    jsr  exec       ; execute one VTLC02 statement
    plp
    lda  pound      ; update Z for {#}
    ora  pound+1    ; if program mode then continue
    bcc  progr      ; if direct mode, did {#} change?
    beq  start      ;   no: restart "OK" prompt
    bra  eloop0     ;   yes: execute program from {#}
;-----------------------------------------------------;
; Point @[y] to the first/next program line >= {#}
; entry:   (cc): start search at beginning of program
;          (cs): start search at next line
;                ({@} -> beginning of current line)
; used by: list_:, progr:
; uses:    find:, prgm, {@ # & (}
; exit:    if line not found then abort to "OK" prompt
;          else {@} -> found line, x:a = {#} = {(} =
;            actual line number, y = 2, (cc)
; 10 bytes
findln:
    jsr  find       ; find first/next line >= {#}
    bcs  start      ; if end then restart "OK" prompt
    sta  pound      ; {#} = {(}
    stx  pound+1    ;
    rts             ;
;-----------------------------------------------------;
; Delete/insert/replace program line and restart the
;   command prompt (no "OK" means success)
; entry:  Carry must be clear
; uses:   find:, start:, linbuf, {@ > # & * (}
; 146 bytes
edit:
    phy             ; save linbuf offset pointer
    jsr  find       ; point {@} to first line >= {#}
    bcs  insrt      ;
    eor  pound      ; if line doesn't already exist
    bne  insrt      ;   then skip deletion process
    cpx  pound+1    ;
    bne  insrt      ;
    lda  (at),y     ;
    tay             ; y = length of line to delete
    eor  #255       ; (-1)
    adc  ampr       ; {&} = {&} - y
    sta  ampr       ;
    bcs  delt       ;
    dec  ampr+1     ;
delt:
    lda  at         ;
    sta  gthan      ; {>} = {@}
    lda  at+1       ;
    sta  gthan+1    ;
delt2:
    lda  gthan      ;
    cmp  ampr       ; delete the line
    lda  gthan+1    ;
    sbc  ampr+1     ;
    bcs  insrt      ;
    lda  (gthan),y  ;
    sta  (gthan)    ;
    inc  gthan      ;
    bne  delt2      ;
    inc  gthan+1    ;
    bra  delt2      ;
insrt:
    plx             ; x = linbuf offset pointer
    lda  pound      ;
    pha             ; push the new line number on
    lda  pound+1    ;   the system stack
    pha             ;
    ldy  #2         ;
cntln:
    inx             ;
    iny             ; determine new line length in y
    lda  linbuf-1,x ;   and push statement text on
    pha             ;   the system stack
    bne  cntln      ;
    cpy  #4         ; if empty line then skip the
    bcc  jstart     ;   insertion process
    tya             ;
    tax             ; save new line length in x
    clc             ;
    adc  ampr       ; calculate new program end
    sta  gthan      ; {>} = {&} + y
    lda  #0         ;
    adc  ampr+1     ;
    sta  gthan+1    ;
    lda  gthan      ;
    cmp  star       ; if {>} >= {*} then the program
    lda  gthan+1    ;   won't fit in available RAM,
    sbc  star+1     ;   so drop the stack and abort
    bcs  jstart     ;   to the "OK" prompt
slide:
    lda  ampr       ;
    bne  slide2     ;
    dec  ampr+1     ;
slide2:
    dea             ;
    sta  ampr       ;
    cmp  at         ;
    lda  ampr+1     ;
    sbc  at+1       ;
    bcc  move2      ; slide open a gap inside the
    lda  (ampr)     ;   program text just big enough
    sta  (ampr),y   ;   to hold the new line
    bra  slide      ;
move2:
    pla             ; pull the statement text and the
    dey             ;   new line number and store them
    sta  (at),y     ;   in the program text gap
    bne  move2      ;
    ldy  #2         ;
    txa             ; store line length at offset 2,
    sta  (at),y     ;   after line number
    lda  gthan      ;
    sta  ampr       ; {&} = {>}
    lda  gthan+1    ;
    sta  ampr+1     ;
jstart:
    jmp  start      ; drop stack, restart cmd prompt
;-----------------------------------------------------;
; {?="...} handler; called from exec:
; 1 byte
prstr0:
    tax             ; set delimiter, fall through
; - - - - - - - - - - - - - - - - - - - - - - - - - - ;
; Print a string at @[y]
; x holds the delimiter char, which is skipped over,
;   not printed ('\0' is always a delimiter)
; If a key was pressed, pause for another keypress
;   before returning.  If either of those keys was a
;   ctrl-C, drop the stack and restart the "OK" prompt
;   with the user program intact
; entry:  @[y] -> string, x = delimiter char
; uses:   pause:, outch:, skpbyte:, execrts:
; exit:   (normal) @[y] -> '\0' or byte after delimiter
;         (ctrl-C) drop the stack & restart "OK" prompt
; 34 bytes
prstr:
    iny             ; next byte
    txa             ;
    cmp  (at),y     ; found delimiter or '\0'?
    beq  prstr2     ;   yes: finish up
    lda  (at),y     ;
    beq  prstr2     ;
prstr1:
    jsr  outch      ;   no: print char to terminal
    bra  prstr      ;     and loop
prstr2:
    tax             ; save closing delimiter
    ;jsr  pause      ; check for pause or abort
    ;txa             ; retrieve closing delimiter
    beq  outnl      ; always '\n' after '\0' delimiter
    jsr  skpbyte    ; skip over the delimiter
    cmp  #';'       ; if trailing char is ';' then
    beq  execrts    ;   suppress the '\n'
outnl:
    lda  #CR        ; '\n' to terminal
joutch:
    jmp  outch      ;
;-----------------------------------------------------;
; Execute a (hopefully) valid VTLC02 statement at @[y]
; entry:   @[y] -> left-side of statement
; uses:    nearly everything
; exit:    note to machine language subroutine {>=...}
;            users: no registers or variables are
;            required to be preserved except the system
;            stack pointer, the text base pointer {@},
;            and the original line number {(}
; if there is a '"' directly after the assignment
;   operator, the statement will execute as {?="...},
;   regardless of the variable named on the left side
; 83 bytes
exec:
    jsr  getbyte    ; fetch left-side variable name
    beq  execrts    ; do nothing with a null statement
    iny             ;
    cmp  #')'       ; same for a full-line comment
    beq  execrts    ;
    ldx  #arg       ; initialize argument stack
    jsr  convp      ; arg[{0}] -> left-side variable
    jsr  getbyte    ; skip over assignment operator
    jsr  skpbyte    ; is right-side a literal string?
    cmp  #DQUOTE    ;   yes: print the string with
    beq  prstr0     ;     trailing ';' check & return
    ldx  #arg+2     ; point eval to arg[{1}]
    jsr  eval       ; evaluate right-side in arg[{1}]
    lda  arg+2      ;
    ldx  arg+1      ; was left-side an array element?
    bne  exec3      ;   yes: skip to default actions
    ldx  arg        ;
    cpx  #at        ; if {@=...} statement then poke
    beq  poke       ;   low half of arg[{1}] to ({<})
    cpx  #dolr      ; if {$=...} statement then print
    beq  joutch     ;   arg[{1}] as ASCII character
    cpx  #ques      ; if {?=...} statement then print
    beq  prnum0     ;   arg[{1}] as unsigned decimal
    cpx  #gthan     ; if {>=...} statement then call
    beq  usr        ;   user-defined ML routine
exec3:
    sta  (arg)      ;
    adc  tick+1     ; store arg[{1}] in the left-side
    rol             ;   variable
    tax             ;
    ldy  #1         ;
    lda  arg+3      ;
    sta  (arg),y    ;
    adc  tick       ; pseudo-randomize {'}
    rol             ;
    sta  tick+1     ;
    stx  tick       ;
execrts:
    rts             ;
usr:
    tax             ; jump to user ML routine with
    lda  arg+3      ;   arg[{1}] in a:x (MSB:LSB)
    jmp  (quote)    ; {"} must point to valid 6502 code
poke:
    sta  (lthan)    ;
    rts             ;
;-----------------------------------------------------;
; {?=...} handler; called by exec:
; 2 bytes
prnum0:
    ldx  #arg+2     ; x -> arg[{1}], fall through
; - - - - - - - - - - - - - - - - - - - - - - - - - - ;
; Print var[x] as unsigned decimal number (0..65535)  ;
; Clever V-flag trick comes courtesy of John Brooks.  ;
; entry:   var[x] = number to print                   ;
; uses:    outch:                                     ;
; exit:    var[x] = a = 0                             ;
; 36 bytes                                            ;
prnum:
    phy             ; save y
    lda  #0         ; stack sentinel
prnum2:             ; repeat {
    pha             ;   stack ASCII digit
    lda  #0         ;   remainder = 0 
    clv             ;   (sets if quotient > 0)
    ldy  #16        ;   16-bit divide by ten
prnum3:
    cmp  #5         ;     partial rem >= radix/2?
    bcc  prnum4     ;
    sbc  #133       ;     yes: update rem, set V
    sec             ;     and C for non-zero quot
prnum4:
    rol  0,x        ;     new quotient gradually 
    rol  1,x        ;       replaces var[x]
    rol             ;     new remainder gradually
    dey             ;       replaces a
    bne  prnum3     ;   continue 16-bit divide 
    ora  #'0'       ;   convert remainder to ASCII
    bvs  prnum2     ; } until no more digits
prnum5:
    jsr  outch      ; print digits in descending
    pla             ;   order until stack sentinel
    bne  prnum5     ;   is encountered
    ply             ; restore y
    rts             ;
;-----------------------------------------------------;
; Evaluate a (hopefully) valid VTLC02 expression at
;   @[y] and place its calculated value in arg[x]
; A VTLC02 expression is defined as a string of one or
;   more terms, separated by operators and terminated
;   with a '\0' or an unmatched ')'
; A term is defined as a variable name, a decimal
;   constant, or a parenthesized sub-expression; terms
;   are evaluated strictly from left to right
; A variable name is defined as a user variable, an
;   array element expression enclosed in {: )}, or a
;   system variable (which may have side-effects)
; entry:   @[y] -> expression text, x -> argument
; uses:    getval:, oper:, {@}, argument stack area
; exit:    arg[x] = result, @[y] -> next text
; 27 bytes                                            ;
eval:
    jsr  getval     ; get first term into arg[x]
eval2:
    jsr  getbyte    ; end of expression '\0' or ')'?
    beq  getrts     ;   yes: done
    iny             ;
    cmp  #')'       ;
    beq  getrts     ;
    pha             ;   no: stack alleged operator
    inx             ; advance the argument stack
    inx             ;   pointer
    jsr  getval     ; arg[x+2] = value of next term
    dex             ;
    dex             ;
    pla             ; retrieve and apply operator
    jsr  oper       ;   to arg[x], arg[x+2]
    bra  eval2      ; loop until end of expression
;-----------------------------------------------------;
; Get numeric value of the term at @[y] into var[x]
; Some examples of valid terms:  123, $, H, (15-:J)/?)
; 75 bytes
getval:
    jsr  cvbin      ; decimal constant at @[y]?
    bne  getrts     ;   yes: return with it in var[x]
    jsr  getbyte    ;
    iny             ;
    cmp  #'?'       ; user line input?
    beq  getexp     ;
    cmp  #'$'       ; user char input?
    beq  getch      ;
    cmp  #'@'       ; memory access?
    beq  peek       ;
    cmp  #'('       ; sub-expression?
    beq  eval       ;   yes: evaluate it recursively
    jsr  convp      ;   no: first set var[x] to the
    lda  (0,x)      ;     named variable's address,
    pha             ;     then replace that address
    inc  0,x        ;     with the variable's actual
    bne  getval4    ;     value before returning
    inc  1,x        ;
getval4:
    lda  (0,x)      ;
    sta  1,x        ; store high-byte of term value
    pla             ;
getval5:
    sta  0,x        ; store low-byte of term value
    rts             ;
peek:
    lda  (lthan)    ; peek memory byte at ({<})
    bra  getval5    ; (cvbin cleared high-byte)
getch:
    jsr  inch       ; input one char from user
    bra  getval5    ; (cvbin cleared high-byte)
getexp:
    phy             ;
    lda  at         ; save @[y]
    pha             ; (current expression ptr)
    lda  at+1       ;
    pha             ;
    jsr  inln       ; input expression from user
    jsr  eval       ; evaluate, var[x] = result
    pla             ;
    sta  at+1       ;
    pla             ;
    sta  at         ; restore @[y]
    ply             ;
getrts:
    rts             ;
;-----------------------------------------------------;
; var[x] = (var[x]*var[x+2])mod65536 (unsigned)
; uses:    plus:, {>}
; exit:    var[x+2] and {>} are modified
; 39 bytes
mul:
    lda  0,x        ;
    sta  gthan      ;
    lda  1,x        ; copy multiplicand to {>}
    sta  gthan+1    ;
    stz  0,x        ; zero the product to begin
    stz  1,x        ;
    .BYTE  $cd        ; "cmp abs" naked op-code
mul1:
    rol  3,x        ;
mul2:
    lda  gthan      ;
    ora  gthan+1    ;
    beq  mulrts     ; exit early if multiplicand = 0
    lsr  gthan+1    ;
    ror  gthan      ; right-shift multiplicand
    bcc  mul3       ; check the bit shifted out
    jsr  plus       ; form the product in var[x]
mul3:
    asl  2,x        ; left-shift multiplier
    bne  mul1       ;
    rol  3,x        ;
    bne  mul2       ; loop until multiplier = 0
mulrts:
    rts             ;
;-----------------------------------------------------;
; Set var[x] to the address of the variable named in a
; entry:   a holds variable name, @[y] -> text holding
;            array index expression (if a = ':')
; uses:    plus:, eval:, oper8d:, {@ &}
; exit:    (eq): var[x] -> variable, @[y] unchanged
;          (ne): var[x] -> array element,
;                @[y] -> following text
; 18 bytes
convp:
    cmp  #':'       ; array element?
    bne  simple     ;   no: simple variable
    jsr  eval       ;   yes: evaluate array index at
    asl  0,x        ;     @[y] and advance y
    rol  1,x        ;     var[x] -> array element
    lda  ampr+1     ;       at address 2 * index + {&}
    sta  3,x        ;       (mod 65536 with no bounds
    lda  ampr       ;       checking whatsoever)
    .BYTE  $cd        ; "cmp abs" naked op-code
; - - - - - - - - - - - - - - - - - - - - - - - - - - ;
; var[x] += var[x+2]
; 14 bytes
plus:
    lda  2,x        ;
plus1:              ; (called by cvbin:)
    clc             ;
    adc  0,x        ;
    sta  0,x        ;
    lda  3,x        ;
    adc  1,x        ;
plus2:
    sta  1,x        ;
    rts             ;
;-----------------------------------------------------;
; var[x] -= var[x+2]
; expects:  (cs), pre-decremented x
; 10 bytes
minus:
    jsr  minus2     ;
    inx             ;
minus2:
    lda  1,x        ;
    sbc  3,x        ;
    bra  plus2      ;
;-----------------------------------------------------;
; The following section is designed to translate the
;   named simple variable from its ASCII value to its
;   zero-page address.  In this case, 'A' translates
;   to $82, '!' translates to $c2, etc.  The method
;   employed must correspond to the zero-page equates
;   above, or strange and not-so-wonderful bugs will
;   befall the weary traveller on his or her porting
;   journey.
; 5 bytes
simple:
    asl             ; form simple variable address
    ;ora  #$80       ; mapping function is (a*2)|128
    CLC
    ADC #at
    bra  oper8d     ;
;-----------------------------------------------------;
; Apply the binary operator in a to var[x] and var[x+2]
; Valid VTLC02 operators are {* + / [ ] - | ^ & < = >}
; {>} is defined as greater than _or_equal_
; An undefined operator will be interpreted as one of
;   the three comparison operators
; 37 bytes
oper:
    cmp  #'*'       ; multiplication operator?
    beq  mul        ;
    cmp  #'+'       ; addition operator?
    beq  plus       ;
    cmp  #'/'       ; division operator?
    beq  div        ;
    cmp  #'['       ; "then" operator?
    beq  then_      ;
    cmp  #']'       ; "else" operator?
    beq  else_      ;
    dex             ; (factored from the following ops)
    cmp  #'-'       ; subtraction operator?
    beq  minus      ;
    cmp  #OP_OR     ; bit-wise or operator?
    beq  or_        ;
    cmp  #'^'       ; bit-wise xor operator?
    beq  xor_       ;
    cmp  #'&'       ; bit-wise and operator?
    beq  and_       ;
; - - - - - - - - - - - - - - - - - - - - - - - - - - ;
; Apply comparison operator in a to var[x] and var[x+2]
;   and place result in var[x] (1: true, 0: false)
; expects:  (cs), pre-decremented x
; 28 bytes
    eor  #'<'       ; 0: '<'  1: '='  2: '>'
    sta  gthan      ; other values in a are undefined,
    jsr  minus      ;   but _will_ produce some result
    dec  gthan      ; var[x] -= var[x+2]
    bne  oper8b     ; equality test?
    ora  0,x        ;   yes: 'or' high and low bytes
    beq  oper8c     ;     (cs) from minus if 0
    clc             ;     (cc) if not 0
oper8b:
    lda  gthan      ;
    rol             ;
oper8c:
    adc  #0         ;
    and  #1         ; var[x] = 1 (true), 0 (false)
oper8d:
    sta  0,x        ;
oper8e:
    stz  1,x        ;
oper8f:
    rts             ;
;-----------------------------------------------------;
; var[x] &= var[x+2]
; expects:  pre-decremented x
; 10 bytes
and_:
    jsr  and_2      ;
    inx             ;
and_2:
    lda  1,x        ;
    and  3,x        ;
    bra  plus2      ;
;-----------------------------------------------------;
; var[x] |= var[x+2]
; expects:  pre-decremented x
; 10 bytes
or_:
    jsr  or_2       ;
    inx             ;
or_2:
    lda  1,x        ;
    ora  3,x        ;
    bra  plus2      ;
;-----------------------------------------------------;
; var[x] ^= var[x+2]
; expects:  pre-decremented x
; 10 bytes
xor_:
    jsr  xor_2      ;
    inx             ;
xor_2:
    lda  1,x        ;
    eor  3,x        ;
    bra  plus2      ;
;-----------------------------------------------------;
; A[B returns 0 if A is 0, otherwise returns B
; 14 bytes
then_:
    lda  0,x        ;
    ora  1,x        ;
    beq  oper8f     ;
then_2:
    lda  2,x        ;
    sta  0,x        ;
    lda  3,x        ;
    bra  plus2      ;
;-----------------------------------------------------;
; A]B returns B if A is 0, otherwise returns 0
; 10 bytes
else_:
    lda  0,x        ;
    ora  1,x        ;
    beq  then_2     ;
    stz  0,x        ;
    bra  oper8e     ;
;-----------------------------------------------------;
; var[x] /= var[x+2] (unsigned), {%} = remainder
; var[x+2] of 0 produces {%} = var[x], var[x] = 65535
; 39 bytes                                            ;
div:
    phy             ;
    ldy  #16        ; loop counter
    lda  #0         ;
    sta  remn+1     ; {%} = 0
div2:
    asl  0,x        ; dividend gradually becomes
    rol  1,x        ;   the quotient
    rol             ; {%} gradually becomes the
    rol  remn+1     ;   remainder
    cmp  2,x        ;
    pha             ;
    lda  remn+1     ;
    sbc  3,x        ; partial remainder >= divisor?
    bcc  div3       ;
    sta  remn+1     ;
    pla             ;   yes: update the partial
    sbc  2,x        ;     remainder and set the low
    inc  0,x        ;     bit of partial quotient
    .BYTE  $c9        ;     "cmp #" naked op-code
div3:
    pla             ;
    dey             ;
    bne  div2       ; loop 16 times
    sta  remn       ;
    ply             ;
    rts             ;
;-----------------------------------------------------;
; If text at @[y] is an unsigned decimal constant,
;   translate it into var[x] (mod 65536) and update y
; entry:   @[y] -> text containing possible constant;
;            leading space characters are skipped, but
;            any spaces encountered after a conversion
;            has begun will end the conversion.
; used by: user:, getval:
; uses:    mul:, plus0:, var[x], var[x+2], {@ > ?}
; exit:    (ne): var[x] = constant, @[y] -> next text
;          (eq): var[x] = 0, @[y] unchanged
;          (cs): in all but the truly strangest cases
; 39 bytes
cvbin:
    stz  0,x        ; var[x] = 0
    stz  1,x        ;
    stz  3,x        ;
    jsr  getbyte    ; skip any leading spaces
    sty  ques       ; save pointer
    bra  cvbin3     ;
cvbin2:
    pha             ; save decimal digit
    lda  #10        ;
    sta  2,x        ;
    jsr  mul        ; var[x] *= 10
    stz  3,x        ;
    pla             ; retrieve decimal digit
    jsr  plus1      ; var[x] += digit
    iny             ;
    lda  (at),y     ; grab next char
cvbin3:
    eor  #'0'       ; if char at @[y] is not a
    cmp  #10        ;   decimal digit then stop
    bcc  cvbin2     ;   the conversion
    cpy  ques       ; (ne) if valid, (eq) if not
    rts             ;
;-----------------------------------------------------;
; Accept input line from user and store it in linbuf,
;   zero-terminated (allows very primitive edit/cancel)
; used by: user:, getval:
; uses:    inch:, outnl:, linbuf, {@}
; exit:    @[y] -> linbuf
; 41 bytes
newln:
    jsr  outnl      ; start on a fresh line
inln:
    lda  #<linbuf   ; start on current line
    sta  at         ; {@} -> input line buffer
    lda  #>linbuf   ;
    sta  at+1       ;
    ldy  #255
inln6:
    iny             ;
    iny             ;
inln5:
    dey             ; buffer over/underflow?
    bmi  newln      ;   yes: start over
inln2:
    jsr  inch       ; get (and echo) one keypress
    cmp  #ESC       ; escape?
    beq  newln      ;   yes: discard entire line
    cmp  #BS        ; backspace?
    beq  inln5      ;   yes: delete previous char
    cmp  #CR        ; enter?
    bne  inln3      ;
    lda  #0         ;   yes: replace with '\0'
inln3:
    sta  (at),y     ; put key in linbuf
    bne  inln6      ; continue if not '\0'
    tay             ; y = 0
    rts             ;
;-----------------------------------------------------;
; Fetch a byte at @[y], ignoring space characters
; 10 bytes
skpbyte:
    iny             ; skip over current char
getbyte:
    lda  (at),y     ;
    beq  getbyt2    ;
    cmp  #' '       ;
    beq  skpbyte    ; skip over any space char(s)
getbyt2:
    rts             ;
;-----------------------------------------------------;
; Find the first/next stored program line >= {#}
; entry:   (cc): start search at program beginning
;          (cs): start search at next line
;                ({@} -> beginning of current line)
; used by: edit:, findln:
; uses:    prgm, {@ # & (}
; exit:    (cs): {@} = {&}, x:a and {(} invalid, y = 2
;          (cc): {@} -> beginning of found line, y = 2,
;                x:a = {(} = actual found line number
; 52 bytes
find:
    lda  #<prgm     ;
    ldx  #>prgm     ;
    ldy  #2         ;
    bcc  find1st    ; (cc): search begins at first line
    ldx  at+1       ;
    clc             ;
findnxt:
    lda  at         ; {@} -> next line (or {&} if
    adc  (at),y     ;   there is no next line ...)
    bcc  find5      ;
    inx             ;
find1st:
    stx  at+1       ;
find5:
    sta  at         ;
    cpx  ampr+1     ; {@} >= {&} (end of program)?
    bcc  find6      ;
    cmp  ampr       ;
    bcs  findrts    ;   yes: line not found (cs)
find6:
    lda  (at)       ;
    sta  lparen     ; {(} = current line number
    cmp  pound      ;
    dey             ;
    lda  (at),y     ;
    iny             ;
    sta  lparen+1   ;
    sbc  pound+1    ; if {(} < {#} then try the next
    bcc  findnxt    ;   program line
    clc             ; found line (cc)
    lda  lparen     ;
    ldx  lparen+1   ;
findrts:
    rts             ;
;-----------------------------------------------------;
; Kowalski simulator I/O subroutines, with thanks to
;   the efforts of Klaus2m5
;-----------------------------------------------------;
; Check for user keypress and return if none has
;   arrived.  Otherwise, pause for another keypress
;   before returning.  If either key is ctrl-C then
;   drop the stack and restart the "OK" prompt.
; 25 bytes
;pause:
;    jsr  inkey      ;
;    beq  inkeyr     ; return if no keypress
;waitkey:
;    jsr  inkey      ;
;    beq  waitkey    ; wait for a keypress
;chklf:
;    cmp  #LF        ; ignore LF (Kowalski)
;inkeyr:
;    rts             ; return with key in a
;inkey:
;    lda  acia_rx    ; has a keypress arrived?
;    beq  inkeyr     ;   no: return immediately
;    cmp  #3         ; ctrl-C?
;    bne  chklf      ;   no: return to caller
;    jmp  start      ; drop stack, restart "OK" prompt
;-----------------------------------------------------;
; Wait for a key from I/O window, put it into a, echo
; Drop the stack and abort to "OK" prompt if ctrl-C
; 3 bytes
;inch:
;    jsr  waitkey    ; wait for keypress, fall through
inch:
  PHY
  PHX
  syscall CON_IN_CHR
  PLX
  PLY
  RTS
; - - - - - - - - - - - - - - - - - - - - - - - - - - ;
; Print ASCII char in a to I/O window
; 12 bytes
;outch:
;    pha             ;
;outch2:
;    sta  acia_tx    ; emit char via transmit register
;    eor  #LF^CR     ;
;    cmp  #LF        ; add LF to CR (Kowalski)
;    beq  outch2     ;
;    pla             ;
;    rts             ;
outch:
  PHA
  PHY
  PHX
  syscall CON_OUT_CHR
  PLX
  PLY
  PLA
  RTS
;-----------------------------------------------------;
; "\nOK\n" prompt
; 4 bytes
okay:
    .BYTE  CR,"OK",CR
;-----------------------------------------------------;
;    .end vtlc02     ; set start address
