; SDカードドライバのSDカード固有部分
.INCLUDE "../../sd-monitor/FXT65.inc"

; SDコマンド用固定引数
; 共通部分を重ねて圧縮している
BTS_CMD8PRM:   ; 00 00 01 AA
  .BYTE $AA,$01
BTS_CMDPRM_ZERO:  ; 00 00 00 00
  .BYTE $00
BTS_CMD41PRM:  ; 40 00 00 00
  .BYTE $00,$00,$00,$40

.macro cs0high
  LDA VIA::PORTB
  ORA #VIA::SPI_CS0
  STA VIA::PORTB
.endmac

.macro cs0low
  LDA VIA::PORTB
  AND #<~(VIA::SPI_CS0)
  STA VIA::PORTB
.endmac

.macro spi_rdbyt
  .local @LOOP
  ; --- AにSPIで受信したデータを格納
  ; 高速化マクロ
@LOOP:
  LDA VIA::IFR
  AND #%00000100      ; シフトレジスタ割り込みを確認
  BEQ @LOOP
  LDA VIA::SR
.endmac

.macro rdpage
  ; 高速化マクロ
.local @RDLOOP
  LDY #0
@RDLOOP:
  ;spi_rdbyt
  STA (ZP_SDSEEK_VEC16),Y
  INY
  BNE @RDLOOP
.endmac

RDSEC:
  ; --- SDCMD_BF+1+2+3+4を引数としてCMD17を実行し、1セクタを読み取る
  ; --- 結果はZP_SDSEEK_VEC16の示す場所に保存される
  JSR RDINIT
DUMPSEC:
  ; 512バイト読み取り
  rdpage
  INC ZP_SDSEEK_VEC16+1
  rdpage
  ; コマンド終了
  cs0high
  RTS

INIT:
  ; カードを選択しないままダミークロック
  LDA #VIA::SPI_CS0
  STA VIA::PORTB
  LDX #10         ; 80回のダミークロック
  JSR SPI::DUMMYCLK

@CMD0:
; GO_IDLE_STATE
; ソフトウェアリセットをかけ、アイドル状態にする。SPIモードに突入する。
; CRCが有効である必要がある
  loadmem16 ZP_SDCMDPRM_VEC16,BTS_CMDPRM_ZERO
  LDA #SDCMD0_CRC
  STA SDCMD_CRC
  LDA #0|SD_STBITS
  JSR SENDCMD
  CMP #$01        ; レスが1であると期待（In Idle Stateビット）
  BNE @INITFAILED

@CMD8:
; SEND_IF_COND
; カードの動作電圧の確認
; CRCはまだ有効であるべき
; SDHC（SD Ver.2.00）以降追加されたコマンドらしい
  loadmem16 ZP_SDCMDPRM_VEC16,BTS_CMD8PRM
  LDA #SDCMD8_CRC
  STA SDCMD_CRC
  LDA #8|SD_STBITS
  JSR SENDCMD
  CMP #$05
  BNE @SKP_OLDSD
  ;print STR_OLDSD ; Ver.1.0カード
  BRA @INITFAILED
@SKP_OLDSD:
  CMP #$01
  BNE @INITFAILED
  ;print STR_NEWSD ; Ver.2.0カード
  ; CMD8のR7レスを受け取る
  JSR RDR7
@SKP_R7:

@CMD58:
; READ_OCR
; OCRレジスタを読み取る
  LDA #$81        ; 以降CRCは触れなくてよい
  STA SDCMD_CRC
  loadmem16 ZP_SDCMDPRM_VEC16,BTS_CMDPRM_ZERO
  LDA #58|SD_STBITS
  JSR SENDCMD
  JSR RDR7

@CMD55:
; APP_CMD
; アプリケーション特化コマンド
; ACMDコマンドのプレフィクス
  loadmem16 ZP_SDCMDPRM_VEC16,BTS_CMDPRM_ZERO
  LDA #55|SD_STBITS
  JSR SENDCMD
  CMP #$01
  BNE @INITFAILED

@CMD41:
; APP_SEND_OP_COND
; SDカードの初期化を実行する
; 引数がSDのバージョンにより異なる
  loadmem16 ZP_SDCMDPRM_VEC16,BTS_CMD41PRM
  LDA #41|SD_STBITS
  JSR SENDCMD
  CMP #$00
  BEQ @INITIALIZED
  CMP #$01          ; レスが0なら初期化完了、1秒ぐらいかかるかも
  BNE @INITFAILED

  JSR DELAY         ; 再挑戦
  JMP @CMD55

@INITFAILED:  ; 初期化失敗
  BRK

@INITIALIZED:
  ;print STR_SDINIT
OK:
  LDA #'!'
  JSR FUNC_CON_OUT_CHR
  RTS

RDPAGE:
  rdpage
  RTS

RDINIT:
  ; CMD17
  LDA #17|SD_STBITS
  JSR SENDCMD
  CMP #$00
  BEQ @RDSUCCESS
  CMP #$04          ; この例が多い
  JSR DELAY
  BEQ RDINIT
  BRK
@RDSUCCESS:
  ;print STR_S
  cs0low
  ;JSR SD_WAITRES  ; データを待つ
  LDY #0
@WAIT_DAT:         ;  有効トークン$FEは、負数だ
  JSR SPI::RDBYT
  CMP #$FF
  BNE @TOKEN
  DEY
  BNE @WAIT_DAT
@TOKEN:
  CMP #$FE
  BEQ @RDGOTDAT
  BRK
  ;BRA @RDSUCCESS ; その後の推移を確認
@RDGOTDAT:
  RTS

WAITRES:
  ; --- SDカードが負数を返すのを待つ
  ; --- 負数でエラー
  JSR SPI::SETIN
  LDX #8
@RETRY:
  JSR SPI::RDBYT ; なぜか、直前に送ったCRCが帰ってきてしまう
.IFDEF DEBUGBUILD
  PHA
  JSR PRT_BYT_S
  PLA
.ENDIF
  BPL @RETURN   ; bit7が0ならレス始まり
  DEX
  BNE @RETRY
@RETURN:
  ;STA SD_CMD_DAT ; ?
  RTS

SENDCMD:
  ; ZP_SDCMD_VEC16の示すところに配置されたコマンド列を送信する
  ; Aのコマンド、ZP_SDCMDPRM_VEC16のパラメータ、SDCMD_CRCをコマンド列として送信する。
  PHA
  .IFDEF DEBUGBUILD
    ; コマンド内容表示
    ;print STR_CMD
    PLA
    PHA
    AND #%00111111
    JSR PRT_BYT_S
  .ENDIF
  ; コマンド開始
  cs0low
  JSR SPI::SETOUT
  ; コマンド送信
  PLA
  JSR SPI::WRBYT
  ; 引数送信
  LDY #3
@LOOP:
  LDA (ZP_SDCMDPRM_VEC16),Y
  PHY
  ; 引数表示
  PHA
  JSR SPI::WRBYT
  PLA
  .IFDEF DEBUGBUILD
    JSR PRT_BYT_S
  .ENDIF
  PLY
  DEY
  BPL @LOOP
  ; CRC送信
  LDA SDCMD_CRC
  JSR SPI::WRBYT
  .IFDEF DEBUGBUILD
    ; レス表示
    LDA #'='
    ;JSR MON::PRT_CHAR_UART
  .ENDIF
  JSR SD::WAITRES
  PHA
  .IFDEF DEBUGBUILD
    JSR PRT_BYT_S
  .ENDIF
  cs0high
  LDX #1
  JSR SPI::DUMMYCLK  ; ダミークロック1バイト
  JSR SPI::SETIN
  PLA
  RTS

DELAY:
  LDX #0
  LDY #0
@LOOP:
  DEY
  BNE @LOOP
  DEX
  BNE @LOOP
  RTS

RDR7:
  ; ダミークロックを入れた関係でうまく読めない
  cs0low
  JSR SPI::RDBYT
  ;JSR PRT_BYT_S
  JSR SPI::RDBYT
  ;JSR PRT_BYT_S
  JSR SPI::RDBYT
  ;JSR PRT_BYT_S
  JSR SPI::RDBYT
  ;JSR MON::PRT_BYT
  cs0high
  RTS

