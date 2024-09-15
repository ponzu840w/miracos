; -------------------------------------------------------------------
;                            KANJIコマンド
; -------------------------------------------------------------------
; Shift-JIS漢字ユーティリティ
; -------------------------------------------------------------------
.INCLUDE "../generic.mac"     ; 汎用マクロ
.PROC BCOS
  .INCLUDE "../syscall.inc"   ; システムコール番号定義
.ENDPROC
.INCLUDE "../syscall.mac"     ; 簡単システムコールマクロ
.INCLUDE "../FXT65.inc"       ; ハードウェア定義
.INCLUDE "../fs/structfs.s"   ; ファイルシステム関連構造体定義
.INCLUDE "../zr.inc"          ; ZPレジスタZR0..ZR5

; -------------------------------------------------------------------
;                             ZP変数領域
; -------------------------------------------------------------------
.ZEROPAGE
  SJIS_CODE:        .RES 2    ; SJISコード

; -------------------------------------------------------------------
;                           実行用ライブラリ
; -------------------------------------------------------------------
  .INCLUDE "./+kanji/str88k.s"

; -------------------------------------------------------------------
;                             実行領域
; -------------------------------------------------------------------
.CODE
START:
  ; ---------------------------------------------------------------
  ;   コマンドライン引数の処理
  JSR STR2NUM               ; コマンドライン引数を数値として解釈
  BCS ARG_ERROR
  storeAY16 SJIS_CODE
  ; ---------------------------------------------------------------
  ;   CRTCと画面の初期化
  JSR INIT_CRTC
  ; ---------------------------------------------------------------
  ;   メイン処理
  ; 色の設定
  str88k_setcolor $88,$00
  ; 印字
  LDA #1
  STA CRTC2::PTRX
  LDA #1
  STA CRTC2::PTRY
  loadAY16 SJIS_CODE
  JSR STR88K_PUTC
  ; 文字列印字
  str88k_puts 16,16,STR_TEST
  ; ---------------------------------------------------------------
  ;   終了処理
  ; ---------------------------------------------------------------
@LOOP:
  LDA #BCOS::BHA_CON_RAWIN_NoWaitNoEcho
  syscall CON_RAWIN
  BEQ @LOOP
@CLOSE:
  RTS

ARG_ERROR:
  loadAY16 STR_ARG_ERROR
  syscall CON_OUT_STR
  RTS

; ファイルがないとき
NOTFOUND:
  loadAY16 STR_NOTFOUND
  syscall CON_OUT_STR
  RTS

; カーネルエラーのとき
BCOS_ERROR:
  LDA #$A
  syscall CON_OUT_CHR
  syscall ERR_GET
  syscall ERR_MES
  RTS

STR_NOTFOUND:
  .BYT "Font File Not Found.",$A,$0
STR_FONTPATH:
  .BYT "/MCOS/DAT/MSKMSJIS.FNT",$0
STR_ARG_ERROR:
  .BYT "Argument Error.",$A,$0

STR_TEST:
  ;.BYT "Shift-JISによる漢字表示のテスト",$0
  .BYT "hoge",$0

; まっとうな全画面塗りつぶし
FILL:
  STZ CRTC2::PTRX ; 原点セット
  STZ CRTC2::PTRY
  LDY #192
@VLOOP:
  LDX #128
@HLOOP:
  STA CRTC2::WDAT
  DEX
  BNE @HLOOP
  DEY
  BNE @VLOOP
  RTS

; ASCII文字列をHEXと信じて変換
STR2NUM:
  @STR_PTR=ZR0
  @NUMBER16=ZR1
  storeAY16 @STR_PTR
  STZ @NUMBER16
  STZ @NUMBER16+1
  ; 最後尾まで探索、余計な文字があったらエラー
  LDY #$FF
@FIND_EOS_LOOP:
  INY
  LDA (@STR_PTR),Y
  BNE @FIND_EOS_LOOP
@END_OF_STR:
  ; Y=\0
  LDX #0
@BYT_LOOP:
  ; 下位nibble
  DEY
  CPY #$FF
  BEQ @END
  LDA (@STR_PTR),Y
  JSR CHR2NIB
  BCS @ERR
  STA @NUMBER16,X
  ; 上位nibble
  DEY
  CPY #$FF
  BEQ @END
  LDA (@STR_PTR),Y
  JSR CHR2NIB
  BCS @ERR
  ASL
  ASL
  ASL
  ASL
  ORA @NUMBER16,X
  STA @NUMBER16,X
  INX
  BRA @BYT_LOOP
@END:
  mem2AY16 @NUMBER16
  CLC
  RTS
@ERR:
  SEC
  RTS

; *
; --- Aレジスタの一文字をNibbleとして値にする ---
; *
CHR2NIB:
  PHX
  PHY
  syscall UPPER_CHR
  PLY
  PLX
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

INIT_CRTC:
  ; ---------------------------------------------------------------
  ;   CRTCと画面の初期化
  ; FB2
  LDA #%10000000            ; chrboxoff
  STA CRTC2::CHRW
  ; FB1
  LDA #(CRTC2::WF|1)        ; FB1を書き込み先に
  STA CRTC2::CONF
  LDA #(CRTC2::TT|0)        ; 念のため16色モードを設定
  STA CRTC2::CONF
  LDA #0
  JSR FILL                  ; FB1塗りつぶし
  ; DISP
  LDA #%01010101            ; FB1
  STA CRTC2::DISP           ; 表示フレームを全てFB1に
  ; chrbox設定
  LDA #3                    ; よこ4
  STA CRTC2::CHRW
  LDA #7                    ; たて8
  STA CRTC2::CHRH
  RTS
