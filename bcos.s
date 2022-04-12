; MIRACOSの本体
; CP/MでいうところのBIOSとBDOSを混然一体としたもの
; ファンクションコール・インタフェース（特に意味はない）
.INCLUDE "../sd-monitor/FXT65.inc"
.INCLUDE "../sd-monitor/generic.mac"
.INCLUDE "../sd-monitor/fscons.mac"

; ROMコード取り込み（変数領域アクセス用）
.PROC ROM
  .INCLUDE "../sd-monitor/rompac.s"
.ENDPROC

.INCLUDE "var_bcos.s"

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
@LOOP:
  JSR FUNC_CON_IN_CHR
  ;INC
  ;JSR FUNC_CON_OUT_CHR
  BRA @LOOP

.PROC BCOSUART
  .INCLUDE "uart_bcos.s"
.ENDPROC

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
  JSR BCOSUART::OUT_CHR
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
  JSR BCOSUART::OUT_CHR
  PLA
@END:
  RTS

