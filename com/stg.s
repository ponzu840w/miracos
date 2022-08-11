; -------------------------------------------------------------------
;                               STG.COM
; -------------------------------------------------------------------
; シューティングゲーム
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
BGC = $00             ; 背景色 黒以外ではノイズがひどい
DEBUG_BGC = $88       ; オルタナティブ背景色
PLAYER_SPEED = 1      ; PL速度
PLAYER_SHOOTRATE = 8  ; 射撃クールダウンレート
PLBLT_SPEED = 8       ; PLBLT速度
PLAYER_X = 31         ; 30だと現象が起こるが表示は同じ

; -------------------------------------------------------------------
;                               ZP領域
; -------------------------------------------------------------------
.ZEROPAGE
  ; キャラクタ描画canvas
  ZP_CANVAS_X:        .RES 1        ; X座標汎用
  ZP_CANVAS_Y:        .RES 1        ; Y座標汎用
  ZP_VISIBLE_FLAME:   .RES 1        ; 可視フレームバッファ
  ZP_BLACKLIST_PTR:   .RES 2        ; 塗りつぶしリスト用のポインタ
  ZP_CHAR_PTR:        .RES 2        ; キャラクタデータ用のポインタ
  ; SNESPAD
  ZP_PADSTAT:         .RES 2        ; ゲームパッドの状態が収まる
  ZP_SHIFTER:         .RES 1        ; ゲームパッド読み取り処理用
  ; VBLANK
  ZP_VB_STUB:         .RES 2        ; 割り込み終了処理
  ; SOUND
  ZP_SE_STATE:        .RES 1        ; 効果音の状態
  ZP_SE_TIMER:        .RES 1
  ; ゲームデータ
  ZP_PLAYER_X:        .RES 1        ; プレイヤ座標
  ZP_PLAYER_Y:        .RES 1
  ZP_ANT_NZ_Y:        .RES 1        ; アンチ・ノイズY座標
  ZP_PL_DX:              .RES 1        ; プレイヤX軸速度
  ZP_PL_DY:              .RES 1        ; プレイヤY軸速度
  ZP_PL_COOLDOWN:     .RES 1
  ZP_BL_INDEX:        .RES 1        ; ブラックリストのYインデックス退避
  ZP_PLBLT_TERMPTR:   .RES 1        ; PLBLT_LSTの終端を指す
  ZP_ENEM1_TERMPTR:   .RES 1        ; PLBLT_LSTの終端を指す

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
  ; プレイヤの発射した弾丸
  ; 位置だけを保持する
  PLBLT_LST:     .RES 32
  ENEM1_LST:     .RES 32

; -------------------------------------------------------------------
;                             実行領域
; -------------------------------------------------------------------
.CODE

; -------------------------------------------------------------------
;                         プログラム初期化
; -------------------------------------------------------------------
INIT:
  ; ---------------------------------------------------------------
  ;   IOレジスタの設定
  ; ---------------------------------------------------------------
  ;   汎用ポートの設定
  LDA VIA::PAD_DDR          ; 0で入力、1で出力
  ORA #(VIA::PAD_CLK|VIA::PAD_PTS)
  AND #<~(VIA::PAD_DAT)
  STA VIA::PAD_DDR
  ; ---------------------------------------------------------------
  ;   CRTC
  LDA #%00000001            ; 全フレーム16色モード、16色モード座標書き込み、書き込みカウントアップ有効
  STA CRTC::CFG
  ;STZ CRTC::VMAV
  ;STZ CRTC::VMAH
  LDA #%01010101            ; フレームバッファ1
  STA ZP_VISIBLE_FLAME
  STA CRTC::RF              ; FB1を表示
  STA CRTC::WF              ; FB1を書き込み先に
  ; ---------------------------------------------------------------
  ;   変数初期化
  LDA #$FF                  ; ブラックリスト用番人
  STA BLACKLIST1            ; 番人設定
  STA BLACKLIST2
  STZ ZP_PLBLT_TERMPTR      ; PLBLT終端ポインタ
  STZ ZP_ENEM1_TERMPTR      ; ENEM1終端ポインタ
  STZ ZP_PL_DX                 ; プレイヤ速度初期値
  STZ ZP_PL_DY                 ; プレイヤ速度初期値
  STZ ZP_PL_COOLDOWN
  ; ---------------------------------------------------------------
  ;   画面の初期化
  LDA #BGC
  JSR FILL                  ; FB1塗りつぶし
  LDX #2                    ; FB2を書き込み先に
  STX CRTC::WF
  JSR FILL                  ; FB2塗りつぶし
  LDA #PLAYER_X
  STA ZP_PLAYER_X           ; プレイヤー初期座標
  STZ ZP_PLAYER_Y
  ; ---------------------------------------------------------------
  ;   効果音の初期化
  STZ ZP_SE_STATE           ; サウンドの初期化
  ; ---------------------------------------------------------------
  ;   割り込みハンドラの登録
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
;                             マクロ
; -------------------------------------------------------------------
; 割込みルーチンの見通しをよくするために、
; 一回きりの展開を想定したものもある

; -------------------------------------------------------------------
;                     ブラックリストポインタ作成
; -------------------------------------------------------------------
.macro make_blacklist_ptr
  LDA ZP_VISIBLE_FLAME    ; 可視取得
  CMP #%10101010          ; F2が可視かな
  BNE @F2
@F1:                      ; F2が可視なら反対のF1を編集
  LDA #>BLACKLIST1
  BRA @SKP_F2
@F2:                      ; F1が可視なら反対のF2を編集
  LDA #>BLACKLIST2
@SKP_F2:
  STA ZP_BLACKLIST_PTR+1
  LDA #<BLACKLIST1
  STA ZP_BLACKLIST_PTR   ; アライメントしないので下位も設定

; -------------------------------------------------------------------
;           ブラックリストに沿って画面上エンティティ削除
; -------------------------------------------------------------------
.macro clear_by_blacklist
  LDY #0
@BL_DEL_LOOP:
  LDA (ZP_BLACKLIST_PTR),Y  ; X座標取得
  CMP #$FF
  BEQ @BL_END
  LSR
  TAX
  INY
  LDA (ZP_BLACKLIST_PTR),Y  ; Y座標取得
  PHY
  TAY
  JSR DEL_SQ8               ; 塗りつぶす
  PLY
  INY
  BRA @BL_DEL_LOOP
@BL_END:
  STY ZP_BL_INDEX
.endmac

; -------------------------------------------------------------------
;                        アンチノイズ水平消去
; -------------------------------------------------------------------
.macro anti_noise
  .local @ANLLOOP
  STZ CRTC::VMAH    ; 水平カーソルを左端に
  LDA ZP_ANT_NZ_Y   ; アンチノイズY座標
  STA CRTC::VMAV
  LDX #$20          ; 繰り返し回数
  LDA #BGC
@ANLLOOP:
  STA CRTC::WDBF    ; $8x$20=$100=256
  STA CRTC::WDBF    ; 2行の塗りつぶし
  STA CRTC::WDBF
  STA CRTC::WDBF
  STA CRTC::WDBF
  STA CRTC::WDBF
  STA CRTC::WDBF
  STA CRTC::WDBF
  DEX
  BNE @ANLLOOP
  INC ZP_ANT_NZ_Y
  INC ZP_ANT_NZ_Y
.endmac

; -------------------------------------------------------------------
;                           フレーム交換
; -------------------------------------------------------------------
.macro exchange_frame
  LDA ZP_VISIBLE_FLAME
  STA CRTC::WF
  CLC
  ROL ; %01010101と%10101010を交換する
  ADC #0
  STA ZP_VISIBLE_FLAME
  STA CRTC::RF
.endmac

; -------------------------------------------------------------------
;                             PL弾生成
; -------------------------------------------------------------------
.macro make_pl_blt
  LDY ZP_PLBLT_TERMPTR
  LDA ZP_PLAYER_X
  STA PLBLT_LST,Y      ; X
  LDA ZP_PLAYER_Y
  STA PLBLT_LST+1,Y    ; Y
  INY
  INY
  STY ZP_PLBLT_TERMPTR
.endmac

; -------------------------------------------------------------------
;                             敵生成
; -------------------------------------------------------------------
.macro make_enem1
  LDY ZP_ENEM1_TERMPTR
  LDA #200
  STA ENEM1_LST,Y      ; X
  LDA ZP_PLAYER_Y
  STA ENEM1_LST+1,Y    ; Y
  INY
  INY
  STY ZP_ENEM1_TERMPTR
.endmac

; -------------------------------------------------------------------
;                             敵削除
; -------------------------------------------------------------------
; 対象インデックスはXで与えられる
DEL_ENEM1:
  LDY ZP_ENEM1_TERMPTR  ; Y:終端インデックス
  LDA ENEM1_LST-2,Y    ; 終端部データX取得
  STA ENEM1_LST,X      ; 対象Xに格納
  LDA ENEM1_LST-1,Y    ; 終端部データY取得
  STA ENEM1_LST+1,X    ; 対象Yに格納
  DEY
  DEY
  STY ZP_ENEM1_TERMPTR  ; 縮小した終端インデックス
  RTS

; -------------------------------------------------------------------
;                            PL弾削除
; -------------------------------------------------------------------
; 対象インデックスはXで与えられる
DEL_PL_BLT:
  LDY ZP_PLBLT_TERMPTR  ; Y:終端インデックス
  LDA PLBLT_LST-2,Y    ; 終端部データX取得
  STA PLBLT_LST,X      ; 対象Xに格納
  LDA PLBLT_LST-1,Y    ; 終端部データY取得
  STA PLBLT_LST+1,X    ; 対象Yに格納
  DEY
  DEY
  STY ZP_PLBLT_TERMPTR  ; 縮小した終端インデックス
  RTS

; エンティティティック処理
; -------------------------------------------------------------------
;                         プレイヤティック
; -------------------------------------------------------------------
.macro tick_player
  ; プレイヤ移動
  LDA ZP_PLAYER_X
  CLC
  ADC ZP_PL_DX
  STA ZP_PLAYER_X
  LDA ZP_PLAYER_Y
  CLC
  ADC ZP_PL_DY
  STA ZP_PLAYER_Y
  ; プレイヤ描画
  loadmem16 ZP_CHAR_PTR,CHAR_DAT_ZIKI
  LDA ZP_PLAYER_X
  STA ZP_CANVAS_X
  STA (ZP_BLACKLIST_PTR)
  LDA ZP_PLAYER_Y
  STA ZP_CANVAS_Y
  LDY #1
  STA (ZP_BLACKLIST_PTR),Y
  JSR DRAW_CHAR8
.endmac

; -------------------------------------------------------------------
;                           敵ティック
; -------------------------------------------------------------------
.macro tick_enem1
TICK_ENEM1:
  .local @DRAWPLBL
  .local @END_DRAWPLBL
  .local @SKP_Hamburg
  LDX #$0                   ; X:敵リスト用インデックス
@DRAWPLBL:
  CPX ZP_ENEM1_TERMPTR
  BCS @END_DRAWPLBL         ; 敵をすべて処理したなら敵処理終了
  PHY
  LDY #$FE                  ; PL弾インデックス
@COL_PLBLT_LOOP:
  INY
  INY
  CPY ZP_PLBLT_TERMPTR
  BEQ @END_COL_PLBLT
  ; X
  LDA ENEM1_LST,X           ; 敵X座標取得
  SEC
  SBC PLBLT_LST,Y          ; PL弾X座標を減算
  ADC #8                    ; -8が0に
  CMP #16
  BCS @COL_PLBLT_LOOP
  ; Y
  LDA ENEM1_LST+1,X
  SEC
  SBC PLBLT_LST+1,Y
  ADC #8                    ; -8が0に
  CMP #16
  BCS @COL_PLBLT_LOOP
@DEL:
  ; 敵削除
  PHX
  JSR DEL_ENEM1             ; 敵削除
  LDA #SE2_NUMBER
  JSR PLAY_SE               ; 撃破効果音
  PLX
  PLY
  BRA @DRAWPLBL
@END_COL_PLBLT:
  PLY
  LDA ENEM1_LST,X
  STA ZP_CANVAS_X              ; 描画用座標
  STA (ZP_BLACKLIST_PTR),Y  ; BL格納
  INX                       ; Y座標へ
  INY
  LDA ENEM1_LST,X          ; Y座標取得（信頼している
  STA ZP_CANVAS_Y              ; 描画用座標
  STA (ZP_BLACKLIST_PTR),Y  ; BL格納
  INX                       ; 次のデータにインデックスを合わせる
  INY
  PHY
  PHX
  loadmem16 ZP_CHAR_PTR,CHAR_DAT_TEKI1
  JSR DRAW_CHAR8            ; 描画する
  PLX
  PLY
  BRA @DRAWPLBL             ; PL弾処理ループ
@END_DRAWPLBL:
.endmac

; -------------------------------------------------------------------
;                           PL弾ティック
; -------------------------------------------------------------------
.macro tick_pl_blt
TICK_PL_BLT:
  .local @DRAWPLBL
  .local @END_DRAWPLBL
  .local @SKP_Hamburg
  LDX #$0                   ; X:PL弾リスト用インデックス
@DRAWPLBL:
  CPX ZP_PLBLT_TERMPTR
  BCS @END_DRAWPLBL         ; PL弾をすべて処理したならPL弾処理終了
  LDA PLBLT_LST,X
  ADC #PLBLT_SPEED          ; 新しい弾の位置
  BCC @SKP_Hamburg          ; 右にオーバーしたか
@DEL:
  ; 弾丸削除
  PHY
  JSR DEL_PL_BLT
  PLY
  BRA @DRAWPLBL
@SKP_Hamburg:
  STA PLBLT_LST,X          ; リストに格納
  STA ZP_CANVAS_X              ; 描画用座標
  STA (ZP_BLACKLIST_PTR),Y  ; BL格納
  INX                       ; Y座標へ
  INY
  LDA PLBLT_LST,X          ; Y座標取得（信頼している
  STA ZP_CANVAS_Y              ; 描画用座標
  STA (ZP_BLACKLIST_PTR),Y  ; BL格納
  INX                       ; 次のデータにインデックスを合わせる
  INY
  PHY
  PHX
  loadmem16 ZP_CHAR_PTR,CHAR_DAT_ZITAMA1
  JSR DRAW_CHAR8            ; 描画する
  PLX
  PLY
  BRA @DRAWPLBL             ; PL弾処理ループ
@END_DRAWPLBL:
.endmac

; -------------------------------------------------------------------
;                   ブラックリストを終端する
; -------------------------------------------------------------------
.macro term_blacklist
  LDA #$FF
  STA (ZP_BLACKLIST_PTR),Y
.endmac

; -------------------------------------------------------------------
;                   YMZ内部レジスタに値を格納する
; -------------------------------------------------------------------
.macro set_ymzreg addr,dat
  LDA addr
  STA YMZ::ADDR
  LDA dat
  STA YMZ::DATA
.endmac

; -------------------------------------------------------------------
;                   Aで与えられた番号のSEを鳴らす
; -------------------------------------------------------------------
PLAY_SE:
  STA ZP_SE_STATE
  LSR
  TAX
  LDA SE_LENGTH_TABLE-1,X
  STA ZP_SE_TIMER
@END:
  RTS

; -------------------------------------------------------------------
;                       効果音ティック処理
; -------------------------------------------------------------------
.macro tick_se
TICK_SE:
  LDX ZP_SE_STATE       ; 効果音状態
  BEQ TICK_SE_END       ; 何も鳴ってないなら無視
  JMP (SE_TICK_JT-2,X)  ; 鳴っているので効果音種類ごとの処理に跳ぶ
TICK_SE_RETURN:         ; ここに帰ってくる
  DEC ZP_SE_TIMER       ; タイマー減算
  BNE TICK_SE_END
  ; 0になった
  set_ymzreg #YMZ::IA_MIX,#%00111111
  STZ ZP_SE_STATE
TICK_SE_END:
.endmac

; -------------------------------------------------------------------
;                        効果音種類テーブル
; -------------------------------------------------------------------
SE_LENGTH_TABLE:
  .BYTE SE1_LENGTH      ; 1
  .BYTE SE2_LENGTH      ; 2

SE_TICK_JT:
  .WORD SE1_TICK
  .WORD SE2_TICK

; -------------------------------------------------------------------
;                         各効果音ティック
; -------------------------------------------------------------------
SE1_TICK:
  LDA ZP_SE_TIMER
  CMP #SE1_LENGTH
  BNE @a
  set_ymzreg #YMZ::IA_MIX,#%00111110
  set_ymzreg #YMZ::IA_FRQ+1,#>(125000/800)
  set_ymzreg #YMZ::IA_FRQ,#<(125000/800)
  set_ymzreg #YMZ::IA_VOL,#$0F
  JMP TICK_SE_RETURN
@a:
  LDX #YMZ::IA_VOL
  STX YMZ::ADDR
  ASL                       ; タイマーの左シフト、最大8
  ADC #4
  STA YMZ::DATA
  JMP TICK_SE_RETURN

SE2_TICK:
  set_ymzreg #YMZ::IA_MIX,#%00110111
  set_ymzreg #YMZ::IA_NOISE_FRQ,#>(125000/400)
  set_ymzreg #YMZ::IA_VOL,#$0F
  JMP TICK_SE_RETURN

; -------------------------------------------------------------------
;                           効果音定数
; -------------------------------------------------------------------
SE1_LENGTH = 5
SE1_NUMBER = 1*2
SE2_LENGTH = 5
SE2_NUMBER = 2*2

; -------------------------------------------------------------------
;                        垂直同期割り込み
; -------------------------------------------------------------------
VBLANK:
TICK:
  ; ---------------------------------------------------------------
  ;   塗りつぶし
  make_blacklist_ptr          ; ブラックリストポインタ作成
  clear_by_blacklist          ; ブラックリストに沿ったエンティティ削除
  anti_noise                  ; ノイズ対策に行ごと消去
  ; ---------------------------------------------------------------
  ;   キー操作
  JSR PAD_READ                ; パッド状態更新
  STZ ZP_PL_DY
  STZ ZP_PL_DX
  LDX #256-PLAYER_SPEED
  LDY #PLAYER_SPEED
  BBS3 ZP_PADSTAT,@SKP_UP     ; up
  STX ZP_PL_DY
@SKP_UP:
  BBS2 ZP_PADSTAT,@SKP_DOWN   ; down
  STY ZP_PL_DY
@SKP_DOWN:
  BBS1 ZP_PADSTAT,@SKP_LEFT   ; left
  STX ZP_PL_DX
@SKP_LEFT:
  BBS0 ZP_PADSTAT,@SKP_RIGHT  ; right
  STY ZP_PL_DX
@SKP_RIGHT:
  BBS7 ZP_PADSTAT,@SKP_B      ; B button
  DEC ZP_PL_COOLDOWN          ; クールダウンチェック
  BNE @SKP_B
  LDA #PLAYER_SHOOTRATE
  STA ZP_PL_COOLDOWN          ; クールダウン更新
  make_pl_blt                 ; PL弾生成
  LDA #SE1_NUMBER
  JSR PLAY_SE                 ; 発射音再生
@SKP_B:
  BBS6 ZP_PADSTAT,@SKP_Y      ; B button
  DEC ZP_PL_COOLDOWN          ; クールダウンチェック
  BNE @SKP_Y
  LDA #PLAYER_SHOOTRATE
  STA ZP_PL_COOLDOWN          ; クールダウン更新
  make_enem1                 ; PL弾生成
@SKP_Y:
  ; ---------------------------------------------------------------
  ;   ティック処理
  tick_player                 ; プレイヤ処理
  LDY #2
  tick_enem1
  tick_pl_blt                 ; PL弾移動と描画
  term_blacklist              ; ブラックリスト終端
  tick_se                     ; 効果音
  exchange_frame              ; フレーム交換
  ; ---------------------------------------------------------------
  ;   ティック終端
  JMP (ZP_VB_STUB)            ; 片付けはBCOSにやらせる

; 背景色で正方形領域を塗りつぶす
; 妙に汎用的にすると重そうなので8x8固定
; X,Yがそのまま座標
DEL_SQ8:
  TYA
  CLC
  ADC #8
  STA ZP_CANVAS_Y
  ;LDA #BGC
  LDA #DEBUG_BGC              ; どこを四角く塗りつぶしたかがわかる
DRAW_SQ_LOOP:
  STX CRTC::VMAH
  STY CRTC::VMAV
  STA CRTC::WDBF
  STA CRTC::WDBF
  STA CRTC::WDBF
  STA CRTC::WDBF
  INY
  CPY ZP_CANVAS_Y
  BNE DRAW_SQ_LOOP
  RTS

; 8x8キャラクタを表示する
; キャラデータの先頭座標がZP_CHAR_PTRで与えられる
DRAW_CHAR8:
  LSR ZP_CANVAS_X
  LDA ZP_CANVAS_X
  CMP #$7F-3
  BCS @END            ; 左右をまたぎそうならキャンセル
  STA CRTC::VMAH
  LDY #0
  LDX #32
@DRAW_CHAR8_LOOP0:
  LDA ZP_CANVAS_Y
  STA CRTC::VMAV
  LDA ZP_CANVAS_X
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
@DRAW_CHAR8_SKP_9:
  INC ZP_CANVAS_Y
  STX ZR0
  CPY ZR0
  BNE @DRAW_CHAR8_LOOP0
@END:
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

CHAR_DAT_ZIKI:
  .INCBIN "../../ChDzUtl/images/ziki1-88.bin"

CHAR_DAT_ZITAMA1:
  .INCBIN "../../ChDzUtl/images/zitama88.bin"

CHAR_DAT_TEKI1:
  .INCBIN "../../ChDzUtl/images/teki1-88.bin"

