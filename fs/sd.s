;DEBUGBUILD = 1
; SDカードドライバのSDカード固有部分
.INCLUDE "../FXT65.inc"

; SDコマンド用固定引数
; 共通部分を重ねて圧縮している
BTS_CMD8PRM:   ; 00 00 01 AA
  .BYTE $AA,$01
BTS_CMDPRM_ZERO:  ; 00 00 00 00
  .BYTE $00
BTS_CMD41PRM:  ; 40 00 00 00
  .BYTE $00,$00,$00,$40

RDSEC:
  ; --- SDCMD_BF+1+2+3+4を引数としてCMD17を実行し、1セクタを読み取る
  ; --- 結果はZP_SDSEEK_VEC16の示す場所に保存される
  JSR RDINIT
  BEQ DUMPSEC
  LDA #1  ; EC1:RDINITError
  RTS
DUMPSEC:
  ; 512バイト読み取り
  rdpage
  INC ZP_SDSEEK_VEC16+1
  rdpage
  ; コマンド終了
  cs0high
  LDA #0
  RTS

INIT:
  ; 成功:A=0
  ; 失敗:A=エラーコード
  ;  1:InIdleStateError
  ;  2:
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
  BEQ @CMD8
  LDA #$01        ; エラーコード1 CMD0Error
  RTS
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
  PHA
  JSR RDR7        ; 読み捨て
  PLA
  CMP #$05
  BNE @SKP_OLDSD
  ;print STR_OLDSD ; Ver.1.0カード
  LDA #$02        ; エラーコード2 OldCardError
  RTS
@SKP_OLDSD:
  CMP #$01
  BEQ @CMD58
  LDA #$03        ; エラーコード3 CMD8Error
  RTS
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
  BEQ @CMD41
  LDA #$04    ; エラーコード4 CMD55Error
  RTS
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
  BEQ @SKP_CMD41ERROR
  LDA #$05          ; エラーコード5 CMD41Error
  RTS
@SKP_CMD41ERROR:
  JSR DELAY         ; 再挑戦
  JMP @CMD55
@INITIALIZED:
OK:
  LDA #0  ; 成功コード
  RTS

RDPAGE:
  rdpage
  RTS

RDINIT:
  ; 成功:A=0
  ; 失敗:A=エラーコード
  ; CMD17
  LDA #17|SD_STBITS
  JSR SENDCMD
  CMP #$00
  BEQ @RDSUCCESS
  CMP #$04          ; この例が多い
  ;JSR DELAY
  ;BEQ RDINIT
  ;BRK
  ;NOP
  LDA #$01         ; EC1:CMD17Error
  RTS
@RDSUCCESS:
  ;print STR_S
  ;JSR SD_WAITRES  ; データを待つ
  cs0low
  LDY #0
@WAIT_DAT:         ;  有効トークン$FEは、負数だ
  JSR SPI::RDBYT
  CMP #$FF
  BNE @TOKEN
  DEY
  BNE @WAIT_DAT
  LDA #$03        ; EC3:TokenError2
  RTS
  ;BRA @WAIT_DAT
@TOKEN:
  CMP #$FE
  BEQ @RDGOTDAT
  LDA #$02        ; EC2:TokenError
  RTS
  ;BRA @RDSUCCESS ; その後の推移を確認
@RDGOTDAT:
  LDA #0
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
  LDA #'w'
  JSR FUNC_CON_OUT_CHR
  PLA
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
    loadAY16 STR_CMD
    JSR FUNC_CON_OUT_STR
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
  .IFDEF DEBUGBUILD
    PHA
    JSR PRT_BYT_S
    PLA
  .ENDIF
  JSR SPI::WRBYT
  PLY
  DEY
  BPL @LOOP
  ; CRC送信
  LDA SDCMD_CRC
  .IFDEF DEBUGBUILD
    PHA
    JSR PRT_BYT_S     ; CRC表示
    PLA
  .ENDIF
  JSR SPI::WRBYT
  .IFDEF DEBUGBUILD
    ; レス表示
    LDA #'='
    JSR FUNC_CON_OUT_CHR
  .ENDIF
  JSR SD::WAITRES
  PHA
  .IFDEF DEBUGBUILD
    JSR PRT_BYT_S
    LDA #$A
    JSR FUNC_CON_OUT_CHR
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

.IFDEF DEBUGBUILD
  PRT_BYT_S:  ;デバッグ用
    PHA
    LDA #' '
    JSR FUNC_CON_OUT_CHR
    PLA
    JSR BYT2ASC
    PHY
    JSR @CALL
    PLA
  @CALL:
    JSR FUNC_CON_OUT_CHR
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

  STR_CMD:
    .ASCIIZ "CMD"
.ENDIF
