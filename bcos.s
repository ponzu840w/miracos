; MIRACOSの本体
; CP/MでいうところのBIOSとBDOSを混然一体としたもの
; ファンクションコール・インタフェース（特に意味はない）
.INCLUDE "../sd-monitor/FXT65.inc"
.INCLUDE "../sd-monitor/generic.mac"
.INCLUDE "../sd-monitor/fscons.inc"

; 変数領域宣言（ZP）
.ZEROPAGE
  .PROC ROMZ
    .INCLUDE "../sd-monitor/zpmon.s"  ; モニタ用領域は確保するが、それ以外は無視
  .ENDPROC
  .INCLUDE "fs/zpfs.s"
  .INCLUDE "zpbcos.s"

; 変数領域定義
.SEGMENT "MONVAR"
  .PROC ROM
    .INCLUDE "../sd-monitor/varmon.s"
  .ENDPROC
  .INCLUDE "fs/varfs.s"
  .INCLUDE "varbcos.s"

; ROMとの共通バッファ
.SEGMENT "ROMBF100"        ; $0200~
  CONINBF_BASE:   .RES 256 ; UART受信用リングバッファ
  SECBF512:       .RES 512 ; SDカード用セクタバッファ

; ROMからのインポート
ZR0 = ROMZ::ZR0
ZR1 = ROMZ::ZR1
ZR2 = ROMZ::ZR2
ZR3 = ROMZ::ZR3
ZP_CONINBF_WR_P = ROMZ::ZP_INPUT_BF_WR_P
ZP_CONINBF_RD_P = ROMZ::ZP_INPUT_BF_RD_P
ZP_CONINBF_LEN  = ROMZ::ZP_INPUT_BF_LEN

; 不要セグメント
.SEGMENT "IPLVAR"
.SEGMENT "LIB"
.SEGMENT "INITDATA"
.SEGMENT "ROMCODE"
.SEGMENT "VECTORS"
.SEGMENT "APPVAR"

; --- BCOS本体 ---
.SEGMENT "LIB"
  .INCLUDE "fs/fsmac.mac"
  .PROC BCOS_UART ; 単にUARTとするとアドレス宣言とかぶる
    .INCLUDE "uart.s"
  .ENDPROC
  .PROC SPI
    .INCLUDE "fs/spi.s"
  .ENDPROC
  .PROC SD
    .INCLUDE "fs/sd.s"
  .ENDPROC
  .PROC FS
    .INCLUDE "fs/fs.s"
  .ENDPROC

.SEGMENT "PREAPP"
.SEGMENT "APP"
; システムコール ジャンプテーブル $0600
  BRA FUNC_RESET          ; 0 これだけ、JMP ($0600)でコール
  .WORD FUNC_CON_IN_CHR   ; 1 コンソール入力
  .WORD FUNC_CON_OUT_CHR  ; 2 コンソール出力
  .WORD FUNC_CON_RAWIO    ; 3 コンソール生入力

; BDOS 0
; BCOS 0
FUNC_RESET:
  LDA #%00000001  ; 今のところUARTのみが入力デバイスとして有効である
  STA ZP_CONIN_DEV
  JSR FS::INIT
@LOOP:
  JSR FUNC_CON_IN_CHR
  BRA @LOOP

; BDOS 1
; BCOS 1
FUNC_CON_IN_CHR:
  ; コンソール入力
  ; 一文字入力する。なければ入力を待つ。
  ; 何らかのキーで中断する？（CTRL+C？）
  ; 使う場面がわからない…（改行もエコーするよこれ）
  LDA #$FD
  JSR FUNC_CON_RAWIO      ; 待機入力するがエコーしない
  JSR FUNC_CON_OUT_CHR    ; エコー
  RTS

; BDOS 2
; BCOS 2
FUNC_CON_OUT_CHR:
  ; input:A=char
  ; コンソールから（CTRL+S）が押されると一時停止？
  JSR BCOS_UART::OUT_CHR
  RTS

; BDOS 6
; BCOS 3
FUNC_CON_RAWIO:
  ; input:A=動作選択  output:A=獲得文字/$00（バッファなし）
  ; A=$FF:コンソール入力があれば獲得するがエコーしない
  ; A=$FE:コンソール入力状況を返す
  ; A=$FD:文字入力があるまで待機し、エコーせずに返す
  CMP #$FE
  BNE @NOT_FE
  ; 入力状況を返すだけ
  LDA ZP_CONINBF_LEN
  RTS
@NOT_FE:                ; 待機するかしないか、エコーせずに返す
  CMP #$FD
  BNE @SKP_WAIT         ; FDでなければ（FFなら）待機はしない
@WAIT:
  LDA ZP_CONINBF_LEN
  BEQ @WAIT             ; バッファに何もないなら待つ
@SKP_WAIT:
C_RAWWAITIN:
  LDA ZP_CONINBF_LEN
  BEQ @END              ; バッファに何もないなら0を返す
  LDX ZP_CONINBF_RD_P  ; インデックス
  LDA CONINBF_BASE,X   ; バッファから読む、ここからRTSまでA使わない
  INC ZP_CONINBF_RD_P  ; 読み取りポインタ増加
  DEC ZP_CONINBF_LEN   ; 残りバッファ減少
  LDX ZP_CONINBF_LEN
  CPX #$80              ; LEN - $80
  BNE @END              ; バッファに余裕があれば毎度XON送ってた…？
  ; UARTが有効なら、RTS再開
  BBR0 ZP_CONIN_DEV,@END
  PHA
  LDA #UART::XON
  JSR BCOS_UART::OUT_CHR
  PLA
@END:
  RTS

