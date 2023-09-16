.INCLUDE "../FXT65.inc"
.INCLUDE "../generic.mac"
.INCLUDE "../zr.inc"
.PROC BCOS
  .INCLUDE "../syscall.inc"  ; システムコール番号
.ENDPROC
.INCLUDE "../syscall.mac"

BUFFER_SIZE=30*4
THUMBNAIL_W=30 ; x2=60px
THUMBNAIL_H=44

.BSS
THUMBNAIL_LINE_BUF: .RES BUFFER_SIZE
FD_SAV: .RES 1

.ZEROPAGE
ZP_PADSTAT: .RES 2
ZP_STRPTR:  .RES 2
ZP_VB_STUB: .RES 2
ZP_ITR:     .RES 1
ZP_FINFO_SAV: .RES 1
ZP_XSAV:    .RES 1

.DATA

.CONSTRUCTOR INIT

.CODE

.INCLUDE "./+gui/chdz_basic.s"
.INCLUDE "./+gui/se.s"

.EXPORT _pad,_system,_play_se,_put_thumbnail

; コンストラクタ
.SEGMENT "ONCE"
INIT:
  ; ポートの設定
  LDA VIA::PAD_DDR         ; 0で入力、1で出力
  ORA #(VIA::PAD_CLK|VIA::PAD_PTS)
  AND #<~(VIA::PAD_DAT)
  STA VIA::PAD_DDR
  ; se
  init_se
  ; 割り込みハンドラの登録
  SEI
  loadAY16 VBLANK
  syscall IRQ_SETHNDR_VB
  storeAY16 ZP_VB_STUB
  CLI
  JMP CHDZ_BASIC_INIT

.CODE
VBLANK:
  tick_se
  JMP (ZP_VB_STUB)           ; 片付けはBCOSにやらせる

; -------------------------------------------------------------------
; PAD()関数
; ゲームパッドのボタン押下状況を取得する
; 引数: ボタン番号（ビット位置）
; 押されている=1, 押されていない=0を返す
; -------------------------------------------------------------------
.PROC _pad
  ; P/S下げる
  LDA VIA::PAD_REG
  ORA #VIA::PAD_PTS
  STA VIA::PAD_REG
  ; P/S下げる
  LDA VIA::PAD_REG
  AND #<~VIA::PAD_PTS
  STA VIA::PAD_REG
  ; 読み取りループ
  LDX #16
LOOP:
  LDA VIA::PAD_REG        ; データ読み取り
  ; クロック下げる
  AND #<~VIA::PAD_CLK
  STA VIA::PAD_REG
  ; 16bit値として格納
  ROR
  ROL ZP_PADSTAT+1
  ROL ZP_PADSTAT
  ; クロック上げる
  LDA VIA::PAD_REG        ; データ読み取り
  ORA #VIA::PAD_CLK
  STA VIA::PAD_REG
  DEX
  BNE LOOP
  LDA ZP_PADSTAT
  LDX ZP_PADSTAT+1
  ; LOW   : 7|B,Y,SEL,STA,↑,↓,←,→|0
  ; HIGH  : 7|A,X,L,R            |0
  RTS
.ENDPROC

; -------------------------------------------------------------------
; void system(unsigned char* commandline)
; -------------------------------------------------------------------
_system:
  PHX
  PLY
  storeAY16 ZP_STRPTR
  LDY #0
@LOOP:
  LDA (ZP_STRPTR),Y
  BEQ @END
  PHY
  syscall CON_INTERRUPT_CHR
  PLY
  INY
  BRA @LOOP
@END:
  syscall CRTC_RETBASE
  ; 大政奉還コード
  ; 割り込みハンドラの登録抹消
  SEI
  mem2AY16 ZP_VB_STUB
  syscall IRQ_SETHNDR_VB
  CLI
  ; ミュート
  LDA #YMZ::IA_VOL
  STA YMZ::ADDR
  STZ YMZ::DATA
  ; 実行
  JMP $5000

; play_se(unsigned char se_num)
_play_se:
  JSR PLAY_SE
  RTS

; -------------------------------------------------------------------
; char put_thumbnail(unsigned char x, unsigned char y, unsigned char* path)
; 指定座標に60x44の画像を設置する
; 返り値0で正常終了
; -------------------------------------------------------------------
_put_thumbnail:
  ; ---------------------------------------------------------------
  ;   nullチェック
  storeAX16 ZR0
  LDA (ZR0)
  BNE @SKP_NOTFOUND
@NOTFOUND2:
  JMP NOTFOUND
@SKP_NOTFOUND:
  ; ---------------------------------------------------------------
  ;   オープン
  mem2AY16 ZR0
  syscall FS_FIND_FST             ; 検索
  BCS @NOTFOUND2                  ; 見つからなかったらあきらめる
  storeAY16 ZP_FINFO_SAV          ; FINFOを格納
  syscall FS_OPEN                 ; ファイルをオープン
  BCS @NOTFOUND2                  ; オープンできなかったらあきらめる
  STA FD_SAV                      ; ファイル記述子をセーブ
  ; ---------------------------------------------------------------
  ;  表示初期化
  JSR GRA_SETUP
  LDA #THUMBNAIL_W-1             ; 画像サイズ
  STA CRTC2::CHRW
  LDA #THUMBNAIL_H-1
  STA CRTC2::CHRH
  JSR popa                       ; 書き込み座標
  STA CRTC2::PTRY
  JSR popa
  STA ZP_XSAV
  ; ---------------------------------------------------------------
  ;  ロード
  LDA #(THUMBNAIL_W*THUMBNAIL_H)/BUFFER_SIZE
  STA ZP_ITR
@BUF_LOOP:
  LDA FD_SAV
  STA ZR1                         ; 規約、ファイル記述子はZR1！
  loadmem16 ZR0,THUMBNAIL_LINE_BUF; 書き込み先
  loadAY16 BUFFER_SIZE
  syscall FS_READ_BYTS            ; ロード
  BCS NOTFOUND
  ; ---------------------------------------------------------------
  ;  表示
  LDA ZP_XSAV
  STA CRTC2::PTRX
  LDX #0
@WDAT_LOOP:
  LDA THUMBNAIL_LINE_BUF,X
  STA CRTC2::WDAT
  INX
  LDA THUMBNAIL_LINE_BUF,X
  STA CRTC2::WDAT
  INX
  LDA THUMBNAIL_LINE_BUF,X
  STA CRTC2::WDAT
  INX
  LDA THUMBNAIL_LINE_BUF,X
  STA CRTC2::WDAT
  INX
  CPX #BUFFER_SIZE
  BNE @WDAT_LOOP
  ; ---------------------------------------------------------------
  DEC ZP_ITR
  BNE @BUF_LOOP
  LDA FD_SAV
  syscall FS_CLOSE
  BCS NOTFOUND
  JSR END_PLOT
  LDA #0
  RTS

NOTFOUND:
  JSR END_PLOT
  LDA #1
  RTS

