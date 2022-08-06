; -------------------------------------------------------------------
; reimu
; -------------------------------------------------------------------
; ChDzUtlのanim.s
; -------------------------------------------------------------------
.INCLUDE "../FXT65.inc"
.INCLUDE "../generic.mac"
.INCLUDE "../fs/structfs.s"
.INCLUDE "../fscons.inc"
.INCLUDE "../zr.inc"
.PROC BCOS
  .INCLUDE "../syscall.inc"  ; システムコール番号
.ENDPROC
.INCLUDE "../syscall.mac"

; --- 定数定義 ---
BGC = $00
PLAYER_SPEED = 2

; -------------------------------------------------------------------
;                               ZP領域
; -------------------------------------------------------------------
.ZEROPAGE
  ZP_TMP_X:           .RES 1        ; X座標汎用
  ZP_TMP_Y:           .RES 1        ; Y座標汎用
  ZP_VISIBLE_FLAME:   .RES 1        ; 可視フレームバッファ
  ZP_BLACKLIST_PTR:   .RES 2        ; 塗りつぶしリスト用のポインタ
  ZP_CHAR_PTR:        .RES 2        ; キャラクタデータ用のポインタ
  ZP_PLAYER_X:        .RES 1        ; プレイヤ座標
  ZP_PLAYER_Y:        .RES 1
  ZP_ANT_NZ_Y:        .RES 1        ; アンチ・ノイズY座標
  ZP_DX:              .RES 1        ; プレイヤX軸速度
  ZP_DY:              .RES 1        ; プレイヤY軸速度
  ; SNESPAD
  ZP_PADSTAT:               .RES 2  ; ゲームパッドの状態が収まる
  ZP_SHIFTER:               .RES 1  ; ゲームパッド読み取り処理用
  ; VBLANK
  ZP_VB_STUB:               .RES 2  ; 割り込み終了処理

; -------------------------------------------------------------------
;                              変数領域
; -------------------------------------------------------------------
.BSS
  FD_SAV:         .RES 1  ; ファイル記述子
  FINFO_SAV:      .RES 2  ; FINFO

  ; ブラックに塗りつぶすべき座標のリスト（命名がわるい
  ; 2バイトで座標が表現され、それを原点に8x8が黒で塗られる
  ; $FFが番人
  ; X,Y,X,Y,..,$FF
  ; 二つのリストは、アライメントせずとも隣接すべし
  BLACKLIST1:     .RES 256
  BLACKLIST2:     .RES 256

; -------------------------------------------------------------------
;                             実行領域
; -------------------------------------------------------------------
.CODE
START:
  ; ポートの設定
  LDA VIA::PAD_DDR         ; 0で入力、1で出力
  ORA #(VIA::PAD_CLK|VIA::PAD_PTS)
  AND #<~(VIA::PAD_DAT)
  STA VIA::PAD_DDR
  LDA #$FF        ; ブラックリスト用番人
  STA BLACKLIST1  ; 番人設定
  STA BLACKLIST2  ; 番人設定
  LDA #0          ; プレイヤ速度初期値
  STA ZP_DX
  STA ZP_DY
  ; コンフィグレジスタの初期化
  LDA #%00000001  ; 全フレーム16色モード、16色モード座標書き込み、書き込みカウントアップ有効
  STA CRTC::CFG
  ; 2色モードの色を白黒に初期化
  LDA #$0F
  STA CRTC::TCP
  ; 出力も書き込みも全部ゼロに初期化
  STZ CRTC::VMAV
  STZ CRTC::VMAH
  LDA #%01010101  ; フレームバッファ1
  STA ZP_VISIBLE_FLAME
  STA CRTC::RF    ; FB1を表示
  STA CRTC::WF    ; FB1を書き込み先に
  ; 背景色で塗りつぶしておく
  LDA #BGC
  JSR FILL        ; FB1塗りつぶし
  LDA #2          ; FB2を書き込み先に
  STA CRTC::WF
  LDA #BGC
  JSR FILL        ; FB2塗りつぶし
  STZ ZP_PLAYER_X ; プレイヤー初期座標
  STZ ZP_PLAYER_Y
  ; 割り込みハンドラの登録
  SEI
  loadAY16 VBLANK
  syscall IRQ_SETHNDR_VB
  storeAY16 ZP_VB_STUB
  CLI
  ; 完全垂直同期割り込み駆動？
MAIN:
  ; 無限ループ
  ; 実際には下記の割り込みが走る
  BRA MAIN

; -------------------------------------------------------------------
;                        垂直同期割り込み
; -------------------------------------------------------------------
VBLANK:

TICK:
  ; ブラックリストポインタ作成
  STZ ZP_BLACKLIST_PTR
  LDA ZP_VISIBLE_FLAME
  CMP #$AA
  BNE @F2
@F1:
  LDA #>BLACKLIST1
  BRA @SKP_F2
@F2:
  LDA #>BLACKLIST2
@SKP_F2:
  STA ZP_BLACKLIST_PTR+1 ; $0800 or $0900 昔の話
  LDA #<BLACKLIST1
  STA ZP_BLACKLIST_PTR   ; アライメントしないので下位も設定
  ; ブラックリストに沿って画面上エンティティ削除
  LDY #0
  LDA (ZP_BLACKLIST_PTR),Y
  CMP #$FF
  BEQ @BL_END
  TAX
  INY
  LDA (ZP_BLACKLIST_PTR),Y
  TAY
  JSR DEL_SQ8
@BL_END:
  ; ノイズ対策に行ごと消去
  LDA #0
  STA CRTC::VMAH
  LDA ZP_ANT_NZ_Y
  STA CRTC::VMAV
  LDX #$20
  LDA #BGC
@ANLLOOP:
  STA CRTC::WDBF
  STA CRTC::WDBF
  STA CRTC::WDBF
  STA CRTC::WDBF
  STA CRTC::WDBF
  STA CRTC::WDBF
  STA CRTC::WDBF
  STA CRTC::WDBF
  DEX
  BNE @ANLLOOP
  INC ZP_ANT_NZ_Y
  ; パッド状態処理
  JSR PAD_READ
  ; 右
  LDA ZP_PADSTAT
  BIT #%00000001
  STZ ZP_DX
  BNE @SKP_RIGHT
  LDA #PLAYER_SPEED
  STA ZP_DX
@SKP_RIGHT:
  ; 左
  LDA ZP_PADSTAT
  BIT #%00000010
  BNE @SKP_LEFT
  LDA #256-PLAYER_SPEED
  STA ZP_DX
@SKP_LEFT:
  ; 上
  LDA ZP_PADSTAT
  BIT #%00001000
  STZ ZP_DY
  BNE @SKP_UP
  LDA #256-PLAYER_SPEED
  STA ZP_DY
@SKP_UP:
  ; 下
  LDA ZP_PADSTAT
  BIT #%00000100
  BNE @SKP_DOWN
  LDA #PLAYER_SPEED
  STA ZP_DY
@SKP_DOWN:
  ; プレイヤ移動
  LDA ZP_PLAYER_X
  CLC
  ADC ZP_DX
  STA ZP_PLAYER_X
  LDA ZP_PLAYER_Y
  CLC
  ADC ZP_DY
  STA ZP_PLAYER_Y
  ; プレイヤ描画
  LDY #0
  LDA #<CHAR_DAT
  STA ZP_CHAR_PTR
  LDA #>CHAR_DAT
  STA ZP_CHAR_PTR+1
  LDA ZP_PLAYER_X
  STA ZP_TMP_X
  LSR
  STA (ZP_BLACKLIST_PTR),Y
  INY
  LDA ZP_PLAYER_Y
  STA ZP_TMP_Y
  STA (ZP_BLACKLIST_PTR),Y
  JSR DRAW_CHAR8
  ; ブラックリスト終端
  INY
  LDA #$FF
  STA (ZP_BLACKLIST_PTR),Y
  ; フレーム交換
  LDA ZP_VISIBLE_FLAME
  STA CRTC::WF
  CLC
  ROL ; %01010101と%10101010を交換する
  ADC #0
  STA ZP_VISIBLE_FLAME
  STA CRTC::RF
  ; ティック終端
  JMP (ZP_VB_STUB)           ; 片付けはBCOSにやらせる

; 背景色で正方形領域を塗りつぶす
; 妙に汎用的にすると重そうなので8x8固定
; X,Yがそのまま座標
DEL_SQ8:
  TYA
  CLC
  ADC #8
  STA ZP_TMP_Y
  LDA #BGC
DRAW_SQ_LOOP:
  STX CRTC::VMAH
  STY CRTC::VMAV
  STA CRTC::WDBF
  STA CRTC::WDBF
  STA CRTC::WDBF
  STA CRTC::WDBF
  INY
  CPY ZP_TMP_Y
  BNE DRAW_SQ_LOOP
  RTS

; 8x8キャラクタを表示する
; キャラデータの先頭座標がZP_CHAR_PTRで与えられる
DRAW_CHAR8:
  LSR ZP_TMP_X
  LDA ZP_TMP_X
  STA CRTC::VMAH
  LDY #0
  LDX #32
DRAW_CHAR8_LOOP0:
  LDA ZP_TMP_Y
  STA CRTC::VMAV
  LDA ZP_TMP_X
  STA CRTC::VMAH
  LDA (ZP_CHAR_PTR),Y
  STA CRTC::WDBF
  INY
  LDA (ZP_CHAR_PTR),Y
  STA CRTC::WDBF
  INY
  LDA (ZP_CHAR_PTR),Y
  STA CRTC::WDBF
  INY
  LDA (ZP_CHAR_PTR),Y
  STA CRTC::WDBF
  INY
DRAW_CHAR8_SKP_9:
  INC ZP_TMP_Y
  STX ZR0
  CPY ZR0
  BNE DRAW_CHAR8_LOOP0
  RTS

; 画面全体をAの値で埋め尽くす
FILL:
  LDY #$00
  STY CRTC::VMAV
  STY CRTC::VMAH
  LDY #$C0
FILL_LOOP_V:
  LDX #$80
FILL_LOOP_H:
  STA CRTC::WDBF
  DEX
  BNE FILL_LOOP_H
  DEY
  BNE FILL_LOOP_V
  RTS


PAD_READ:
  LDA #BCOS::BHA_CON_RAWIN_NoWaitNoEcho  ; キー入力チェック
  syscall CON_RAWIN
  BEQ @SKP_RTS
  RTS
@SKP_RTS:
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
@LOOP:
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
  BNE @LOOP
  RTS

CHAR_DAT:
  .INCBIN "../../ChDzUtl/images/reimu88.bin"

