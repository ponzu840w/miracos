; -------------------------------------------------------------------
;                            KJDEMO2コマンド
; -------------------------------------------------------------------
; EUC-JP漢字表示デモ 第二水準漢字
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
  EUC_CODE:        .RES 2    ; EUCコード

; -------------------------------------------------------------------
;                           実行用ライブラリ
; -------------------------------------------------------------------
  .INCLUDE "./+kanji/str88k.s"
.PROC IMF
.INCLUDE "./+stg/imf.s"
.ENDPROC

; -------------------------------------------------------------------
;                             実行領域
; -------------------------------------------------------------------
.CODE
START:
  ; ---------------------------------------------------------------
  ;   CRTCと画面の初期化
  JSR INIT_CRTC
  init_str88k
  BRA AAA
; ファイルがないとき
NOTFOUND:
  loadAY16 STR_NOTFOUND
  syscall CON_OUT_STR
  RTS
  AAA:
  ; ---------------------------------------------------------------
  ;   メイン処理
  ; 色の設定
  str88k_setcolor $77,$00
  ; 文字列印字
  str88k_puts (2+8*3),(2+8*0),STR_TEST1
  str88k_setcolor $FF,$00
  str88k_puts 2,(30+8*2),STR_TEST2
  str88k_puts 2,(30+8*4),STR_TEST3
  str88k_puts 2,(30+8*5),STR_TEST4
  str88k_puts 2,(30+8*7),STR_TEST5
  str88k_puts 2,(30+8*8),STR_TEST6
  str88k_puts 2,(30+8*9),STR_TEST7
  str88k_puts 2,(30+8*10),STR_TEST8
  str88k_puts 2,(30+8*12),STR_TEST9
  str88k_puts 2,(30+8*13),STR_TEST10
  str88k_puts 2,(30+8*14),STR_TEST11
  ; ---------------------------------------------------------------
  ;   終了処理
  ; ---------------------------------------------------------------
@LOOP:
  LDA #BCOS::BHA_CON_RAWIN_NoWaitNoEcho
  syscall CON_RAWIN
  BEQ @LOOP
@CLOSE:
  str88k_close
  RTS

; 引数がおかしいとき
ARG_ERROR:
  loadAY16 STR_ARG_ERROR
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
  .BYT "/MCOS/DAT/MSKMEUCJ.FNT",$0
STR_ARG_ERROR:
  .BYT "Argument Error.",$A,$0

STR_TEST1:
  .BYT "<《[EUC-JPによる漢字表示 2]》>",$0
STR_TEST2:
  .BYT "祝: 第2水準漢字に対応",$0
STR_TEST3:
  .BYT "文字コードに対応するフォントグリフをファイルから読み出す為に",$0
STR_TEST4:
  .BYT "SEEK()システムコールを用いる。",$0
STR_TEST5:
  .BYT "これまでSEEK()がファイル前半32KBまでしか対応せず。",$0
STR_TEST6:
  .BYT "（アロケーションユニットを跨げない）",$0
STR_TEST7:
  .BYT "第2水準漢字は殆どファイル後半にあるのでSEEK()を改良し",$0
STR_TEST8:
  .BYT "これに対応した。",$0
STR_TEST9:
  .BYT "例:",$0
STR_TEST10:
  .BYT "魑魅魍魎（ちみもうりょう）",$0
STR_TEST11:
  .BYT "釜で茹でる（'茹'が地味に第2水準）",$0

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
  ;   CRTC
  ; FB1
  LDY #(CRTC2::WF|1)
  STY CRTC2::CONF           ; FB1を書き込み先に
  LDX #(CRTC2::TT|0)        ; 念のため16色モードを設定
  STX CRTC2::CONF
  ; DISP
  LDA #%01010101            ; FB1
  STA CRTC2::DISP           ; 表示フレームを全てFB1に
  ; chrbox無効化
  ROL                       ; bit7=1でchrbox無効
  STA CRTC2::CHRW
  ; 画像表示
  loadAY16 PATH_PICT
;  JSR IMF::PRINT_IMF
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

PATH_PICT:
  .BYTE "/DOC/PRT1-SD.IMF",$0
