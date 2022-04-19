; FxT65のハードウェア構成を定義する

.PC02 ; CMOS命令を許可

RAMBASE = $0000
UARTBASE = $E000
VIABASE = $E200
YMZBASE = $E400
CRTCBASE = $E600
ROMBASE = $F000

; UART
.PROC UART
  RX = UARTBASE
  TX = UARTBASE
  STATUS = UARTBASE+1
  COMMAND = UARTBASE+2
  CONTROL = UARTBASE+3
  .PROC CMD
    ; PMC1/PMC0/PME/REM/TIC1/TIC0/IRD/DTR
    ; 全てゼロだと「エコーオフ、RTSオフ、割り込み有効、DTRオフ」
    RTS_ON =    %00001000
    ECHO_ON =   %00010000
    RIRQ_OFF =  %00000010
    DTR_ON =    %00000001
  .ENDPROC
  XON = $11
  XOFF = $13
.ENDPROC

; VIA
.PROC VIA
  PORTB = VIABASE
  PORTA = VIABASE+1
  DDRB = VIABASE+2
  DDRA = VIABASE+3
  SR = VIABASE+$A
  ACR = VIABASE+$B
  PCR = VIABASE+$C
  IFR = VIABASE+$D
  IER = VIABASE+$E
  ; 新式
  SPI_REG    = PORTB
  SPI_DDR    = DDRB
  SPI_INOUT  = %10000000  ; 1=in, 0=out
  SPI_CS0    = %01000000
  PS2_REG    = PORTB
  PS2_DDR    = DDRB
  PS2_CLK    = %00100000
  PS2_DAT    = %00010000
.ENDPROC

; ChDz
.PROC CRTC
  CFG = CRTCBASE+$1   ; コンフィグ
                          ;   MD0 MD1 MD2 MD3 - - - WCUE
                          ;   MD : 色モード選択（各フレーム）
                          ;   WCUE  : 書き込みカウントアップ有効化

  VMAH = CRTCBASE+$2  ; VRAM書き込みアドレス下位
                          ;   - 6 5 4 3 2 1 0

  VMAV = CRTCBASE+$3  ; VRAM書き込みアドレス上位
                      ;   7 6 5 4 3 2 1 0

  WDBF = CRTCBASE+$4  ; 書き込みデータ

  RF  = CRTCBASE+$5   ; 出力フレーム選択
                      ;   (0) 1 0 | (1) 1 0 | (2) 1 0 | (3) 1 0

  WF  = CRTCBASE+$6   ; 書き込みフレーム選択
                      ;   - - - - - - WF1 WF0

  TCP  = CRTCBASE+$7  ; 2色モード色選択
                          ;   (0) 3 2 1 0 | (1) 3 2 1 0
.ENDPROC
