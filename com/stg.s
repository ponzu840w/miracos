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
BGC = $00             ; 背景色
DEBUG_BGC = $00       ; オルタナティブ背景色
INFO_BGC = $22        ; INFO背景色
INFO_COL = $FF        ; INFO文字色
INFO_FLAME = $11      ; INFOフチ
INFO_FLAME_L = $12    ; INFOフチ
INFO_FLAME_R = $21    ; INFOフチ
PLAYER_SPEED = 3      ; PL速度
PLAYER_SHOOTRATE = 5  ; 射撃クールダウンレート
PLBLT_SPEED = 8       ; PLBLT速度
PLAYER_X = (256/2)-4  ; プレイヤー初期位置X
PLAYER_Y = 192-(8*3)  ; プレイヤー初期位置Y
TOP_MARGIN = 8*3      ; 上部のマージン
RL_MARGIN = 4         ; 左右のマージン
ZANKI_MAX = 6         ; ストック可能な自機の最大数
ZANKI_START = 3       ; 残機の初期値

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
  ; ゲームデータ
  ZP_PLAYER_X:        .RES 1        ; プレイヤ座標
  ZP_PLAYER_Y:        .RES 1
  ZP_ANT_NZ_Y:        .RES 1        ; アンチ・ノイズY座標
  ZP_PL_DX:           .RES 1        ; プレイヤX軸速度
  ZP_PL_DY:           .RES 1        ; プレイヤY軸速度
  ZP_PL_COOLDOWN:     .RES 1
  ZP_BL_INDEX:        .RES 1        ; ブラックリストのYインデックス退避
  ZP_PLBLT_TERMIDX:   .RES 1        ; PLBLT_LSTの終端を指す
  ZP_GENERAL_CNT:     .RES 1
  ZP_CMD_PTR:         .RES 2        ; ステージコマンドのポインタ
  ZP_CMD_WAIT_CNT:    .RES 1
  ZP_ZANKI:           .RES 1        ; 残機
  ZP_INFO_FLAG_P:     .RES 1        ; INFO描画箇所フラグ 7|???? ???,残機|0
  ZP_INFO_FLAG_S:     .RES 1        ; セカンダリ
  ZP_DEATH_MUTEKI:    .RES 1        ; 死亡時ティックカウンタを記録し、255ティックの範囲で無敵時間を調整
  ZP_PL_STAT_FLAG:    .RES 1        ; 7|???? ???,無敵|0

; -------------------------------------------------------------------
;                           実行用ライブラリ
; -------------------------------------------------------------------
  .PROC IMF
    .INCLUDE "./+stg/imf.s"
  .ENDPROC
  .INCLUDE "./+stg/infobox.s"
  .INCLUDE "./+stg/dmk.s"
  .INCLUDE "./+stg/se.s"
  .INCLUDE "./+stg/enem.s"
  .INCLUDE "./+stg/title.s"

; -------------------------------------------------------------------
;                              変数領域
; -------------------------------------------------------------------
.BSS
  FD_SAV:         .RES 1  ; ファイル記述子
  FINFO_SAV:      .RES 2  ; FINFO
  ; ブラックに塗りつぶすべき座標のリスト（命名がわるい
  ; 2バイトで座標が表現され、それを原点に8x8が黒で塗られる
  ; "Yの場所の"$FFが番人
  ; X,Y,X,Y,..,$??,$FF
  BLACKLIST1:     .RES 256
  BLACKLIST2:     .RES 256
  ; プレイヤの発射した弾丸
  PLBLT_LST:     .RES 32  ; (X,Y),(X,Y),...

; -------------------------------------------------------------------
;                             実行領域
; -------------------------------------------------------------------
.CODE

; -------------------------------------------------------------------
;                         プログラム初期化
; -------------------------------------------------------------------
INIT_GENERAL:
  ; ---------------------------------------------------------------
  ;   IOレジスタの設定
  ; ---------------------------------------------------------------
  ;   汎用ポートの設定
  LDA VIA::PAD_DDR          ; 0で入力、1で出力
  ORA #(VIA::PAD_CLK|VIA::PAD_PTS)
  AND #<~(VIA::PAD_DAT)
  STA VIA::PAD_DDR
  JMP INIT_TITLE
INIT_GAME:
  ; ---------------------------------------------------------------
  ;   CRTC
  LDA #%00000001            ; 全フレーム16色モード、16色モード座標書き込み、書き込みカウントアップ有効
  STA CRTC::CFG
  LDA #%01010101            ; フレームバッファ1
  STA ZP_VISIBLE_FLAME
  STA CRTC::RF              ; FB1を表示
  STA CRTC::WF              ; FB1を書き込み先に
  ; ---------------------------------------------------------------
  ;   変数初期化
  LDA #$FF                  ; ブラックリスト用番人
  STA BLACKLIST1+1          ; 番人設定
  STA BLACKLIST2+1
  STA ZP_INFO_FLAG_P
  STA ZP_INFO_FLAG_S
  LDA #1
  STA ZP_PL_COOLDOWN
  STZ ZP_PLBLT_TERMIDX      ; PLBLT終端ポインタ
  STZ ZP_ENEM_TERMIDX       ; ENEM終端ポインタ
  STZ ZP_DMK1_TERMIDX       ; DMK1終端ポインタ
  STZ ZP_PL_DX              ; プレイヤ速度初期値
  STZ ZP_PL_DY              ; プレイヤ速度初期値
  loadmem16 ZP_CMD_PTR,STAGE_CMDS
  STZ ZP_CMD_WAIT_CNT
  LDA #ZANKI_START
  STA ZP_ZANKI
  STZ ZP_PL_STAT_FLAG
  ; ---------------------------------------------------------------
  ;   画面の初期化
  LDA #BGC
  JSR FILL_BG               ; FB1塗りつぶし
  LDX #2                    ; FB2を書き込み先に
  STX CRTC::WF
  JSR FILL_BG               ; FB2塗りつぶし
  LDA #PLAYER_X
  STA ZP_PLAYER_X           ; プレイヤー初期座標
  LDA #PLAYER_Y
  STA ZP_PLAYER_Y
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
.endmac

; -------------------------------------------------------------------
;           ブラックリストに沿って画面上エンティティ削除
; -------------------------------------------------------------------
.macro clear_by_blacklist
  LDY #0
@BL_DEL_LOOP:
  LDA (ZP_BLACKLIST_PTR),Y  ; X座標取得
  LSR
  TAX
  INY
  LDA (ZP_BLACKLIST_PTR),Y  ; Y座標取得
  CMP #$FF
  BEQ @BL_END
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
  LDY ZP_PLBLT_TERMIDX
  LDA ZP_PLAYER_X
  STA PLBLT_LST,Y      ; X
  LDA ZP_PLAYER_Y
  STA PLBLT_LST+1,Y    ; Y
  INY
  INY
  STY ZP_PLBLT_TERMIDX
.endmac

; -------------------------------------------------------------------
;                            PL弾削除
; -------------------------------------------------------------------
; 対象インデックスはXで与えられる
DEL_PL_BLT:
  LDY ZP_PLBLT_TERMIDX  ; Y:終端インデックス
  LDA PLBLT_LST-2,Y    ; 終端部データX取得
  STA PLBLT_LST,X      ; 対象Xに格納
  LDA PLBLT_LST-1,Y    ; 終端部データY取得
  STA PLBLT_LST+1,X    ; 対象Yに格納
  DEY
  DEY
  STY ZP_PLBLT_TERMIDX  ; 縮小した終端インデックス
  RTS

; -------------------------------------------------------------------
;                            プレイヤ死亡
; -------------------------------------------------------------------
KILL_PLAYER:
  ; 無敵ならキャンセル
  BBS0 ZP_PL_STAT_FLAG,@SKP_KILL
  ; 効果音
  LDA #SE2_NUMBER
  JSR PLAY_SE               ; 撃破効果音
  ; 残機処理
  DEC ZP_ZANKI              ; 残機減少
  SMB0 ZP_INFO_FLAG_P       ; 残機再描画フラグを立てる
  ; 死亡無敵処理
  SMB0 ZP_PL_STAT_FLAG      ; 無敵フラグを立てる
  LDA ZP_GENERAL_CNT
  STA ZP_DEATH_MUTEKI       ; 死亡時点を記録
  ; リスポーン
  LDA #PLAYER_X
  STA ZP_PLAYER_X
@SKP_KILL:
  RTS

; エンティティティック処理
; -------------------------------------------------------------------
;                         プレイヤティック
; -------------------------------------------------------------------
.macro tick_player
  ; 死亡無敵解除
  BBR0 ZP_PL_STAT_FLAG,@SKP_DEATHMUTEKI  ; bit0 無敵でなければ処理の必要なし
  LDA ZP_GENERAL_CNT
  CMP ZP_DEATH_MUTEKI
  BNE @SKP_DEATHMUTEKI
  ; $FFティック経過
  RMB0 ZP_PL_STAT_FLAG  ; bit0 無敵フラグを折る
@SKP_DEATHMUTEKI:
  ; プレイヤ移動
  ; X
  LDA ZP_PLAYER_X
  CLC
  ADC ZP_PL_DX
  PHA
  SEC
  SBC #RL_MARGIN
  CMP #256-(RL_MARGIN*2)-4
  PLA
  BCS @SKP_NEW_X
  STA ZP_PLAYER_X
@SKP_NEW_X:
  ; Y
  LDA ZP_PLAYER_Y
  CLC
  ADC ZP_PL_DY
  PHA
  SEC
  SBC #TOP_MARGIN           ; 比較のためにテキスト領域を無視してそろえる
  CMP #192-TOP_MARGIN-8     ; 自由領域をオーバーしたか
  PLA
  BCS @SKP_NEW_Y
  STA ZP_PLAYER_Y
@SKP_NEW_Y:
  ; 無敵でかつ描画フレームがどちらか一方なら描画キャンセル（点滅
  LDA ZP_VISIBLE_FLAME
  AND ZP_PL_STAT_FLAG
  AND #%00000001
  BNE @DONT_DRAW
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
@DONT_DRAW:
.endmac

; -------------------------------------------------------------------
;                           PL弾ティック
; -------------------------------------------------------------------
.macro tick_pl_blt
  .local TICK_PL_BLT
  .local @DRAWPLBL
  .local @END
  .local @SKP_Hamburg
  .local @DEL
TICK_PL_BLT:
  LDX #$0                   ; X:PL弾リスト用インデックス
@DRAWPLBL:
  CPX ZP_PLBLT_TERMIDX
  BCS @END                  ; PL弾をすべて処理したならPL弾処理終了
  ; X
  LDA PLBLT_LST,X
  STA ZP_CANVAS_X           ; 描画用座標
  STA (ZP_BLACKLIST_PTR),Y  ; BL格納
  ; Y
  LDA PLBLT_LST+1,X           ; Y座標取得（信頼している
  SBC #PLBLT_SPEED          ; 新しい弾の位置
  ;BCC @SKP_Hamburg          ; 右にオーバーしたか
  CMP #TOP_MARGIN
  BCS @SKP_Hamburg
@DEL:
  ; 弾丸削除
  PHY
  JSR DEL_PL_BLT
  PLY
  BRA @DRAWPLBL
@SKP_Hamburg:
  STA PLBLT_LST+1,X           ; リストに格納
  STA ZP_CANVAS_Y           ; 描画用座標
  INX                       ; 次のデータにインデックスを合わせる
  INY
  STA (ZP_BLACKLIST_PTR),Y  ; BL格納
  INX
  INY
  PHY
  PHX
  loadmem16 ZP_CHAR_PTR,CHAR_DAT_ZITAMA1
  JSR DRAW_CHAR8            ; 描画する
  PLX
  PLY
  BRA @DRAWPLBL             ; PL弾処理ループ
@END:
.endmac

; -------------------------------------------------------------------
;                   ブラックリストを終端する
; -------------------------------------------------------------------
.macro term_blacklist
  LDA #$FF
  INY
  STA (ZP_BLACKLIST_PTR),Y
.endmac

; -------------------------------------------------------------------
;                           コマンド処理
; -------------------------------------------------------------------
.macro tick_cmd
TICK_CMD:
  LDY #1              ; コマンド読み取り用インデックス
  LDA (ZP_CMD_PTR)    ; コマンド取得
  CMP #$FD
  BNE @SKP_LOOP
  ; ---------------------------------------------------------------
  ;   ループ
@LOOP:
  LDA (ZP_CMD_PTR),Y  ; 回数
  DEC
  STA (ZP_CMD_PTR),Y
  BEQ @PLUS_4
  INY
  LDA (ZP_CMD_PTR),Y
  TAX
  INY
  LDA (ZP_CMD_PTR),Y
  STX ZP_CMD_PTR
  STA ZP_CMD_PTR+1
  BRA @END_TICK_CMD
@SKP_LOOP:
  CMP #$FE
  BNE @SKP_WAIT
  ; ---------------------------------------------------------------
  ;   待機
@WAIT:                ; $FE WAIT
  LDA ZP_CMD_WAIT_CNT ; 現在カウント
  BNE @SKP_NEW_WAIT
  ; 新規待機
  LDA (ZP_CMD_PTR),Y  ; 引数:待ちフレーム
  STA ZP_CMD_WAIT_CNT
@SKP_NEW_WAIT:
  DEC ZP_CMD_WAIT_CNT
  BNE @END_TICK_CMD
  CLC
  LDA ZP_CMD_PTR
  ADC #2
  STA ZP_CMD_PTR
  LDA ZP_CMD_PTR+1
  ADC #0
  STA ZP_CMD_PTR+1
  BRA @END_TICK_CMD
@SKP_WAIT:
  ; ---------------------------------------------------------------
  ;   終了
@STOP:
  CMP #$FF
  BEQ @END_TICK_CMD
  ; ---------------------------------------------------------------
  ;   敵をコードと引数からスポーン
@SPAWN_ENEM:
  LDX ZP_ENEM_TERMIDX
  STA ENEM_LST,X        ; code
  LDA (ZP_CMD_PTR),Y
  STA ENEM_LST+1,X      ; X
  INY
  LDA (ZP_CMD_PTR),Y
  STA ENEM_LST+2,X      ; Y
  INY
  LDA (ZP_CMD_PTR),Y
  STA ENEM_LST+3,X      ; T
  ; ---------------------------------------------------------------
  ;   ENEMインデックス更新
  TXA
  CLC
  ADC #4                    ; TAXとするとINX*4にサイクル数まで等価
  STA ZP_ENEM_TERMIDX
@PLUS_4:
  ; ---------------------------------------------------------------
  ;   CMDインデックス更新
  CLC
  LDA ZP_CMD_PTR
  ADC #4
  STA ZP_CMD_PTR
  LDA ZP_CMD_PTR+1
  ADC #0
  STA ZP_CMD_PTR+1
@END_TICK_CMD:
.endmac

; -------------------------------------------------------------------
;                        垂直同期割り込み
; -------------------------------------------------------------------
VBLANK:
TICK:
  tick_cmd
  ; ---------------------------------------------------------------
  ;   塗りつぶし
  make_blacklist_ptr          ; ブラックリストポインタ作成
  clear_by_blacklist          ; ブラックリストに沿ったエンティティ削除
  ;anti_noise                  ; ノイズ対策に行ごと消去
  ; ---------------------------------------------------------------
  ;   キー操作
  JSR PAD_READ                ; パッド状態更新
  STZ ZP_PL_DY
  STZ ZP_PL_DX
  ;LDX #256-PLAYER_SPEED
  ;LDY #PLAYER_SPEED
  LDA #PLAYER_SPEED
  BBS5 ZP_PADSTAT+1,@SKP_L    ; L
  LSR                         ; 速度を半分に
@SKP_L:
  TAY                         ; Y:正のスピード
  STA ZR0
  LDA #0
  SBC ZR0
  TAX                         ; X:負のスピード
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
  tick_pl_blt                 ; PL弾移動と描画
  tick_dmk1
  tick_enem
  term_blacklist              ; ブラックリスト終端
  tick_se                     ; 効果音
  tick_infobox                ; 情報画面
  exchange_frame              ; フレーム交換
  ; ---------------------------------------------------------------
  ;   ティック終端
  INC ZP_GENERAL_CNT
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

; メッセージ画面、ゲーム画面を各背景色で
FILL_BG:
  ; message
  LDY #$00
  STY CRTC::VMAV
  STY CRTC::VMAH
  ; 上のフチ
  LDA #INFO_FLAME
  LDX #256/2
  JSR HLINE
  ; 左右の淵と中身
  LDY #TOP_MARGIN-2
@LOOP:
  LDA #INFO_FLAME_L
  STA CRTC::WDBF
  LDA #INFO_BGC
  LDX #(256/2)-2
  JSR HLINE
  LDA #INFO_FLAME_R
  STA CRTC::WDBF
  DEY
  BNE @LOOP
  ; 下の淵
  LDA #INFO_FLAME
  LDX #256/2
  JSR HLINE
  ; game
  LDA #BGC
  LDY #192-TOP_MARGIN
FILL_LOOP_V:
  LDX #256/2
FILL_LOOP_H:
  STA CRTC::WDBF
  DEX
  BNE FILL_LOOP_H
  DEY
  BNE FILL_LOOP_V
  RTS

HLINE:
@LOOP:
  STA CRTC::WDBF
  DEX
  BNE @LOOP
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
  .INCBIN "+stg/ziki1-88-tate.bin"

CHAR_DAT_ZITAMA1:
  .INCBIN "+stg/zitama-88-tate.bin"

CHAR_DAT_DMK1:
  .INCBIN "+stg/dmk1-88.bin"

STAGE_CMDS:
  .BYTE $FE,60
  .BYTE ENEM_CODE_0_NANAMETTA,10,TOP_MARGIN,6
  .BYTE ENEM_CODE_0_NANAMETTA,20,TOP_MARGIN,12
  .BYTE ENEM_CODE_0_NANAMETTA,30,TOP_MARGIN,24
  .BYTE $FE,60
  .BYTE ENEM_CODE_0_NANAMETTA,256-10,TOP_MARGIN,6
  .BYTE ENEM_CODE_0_NANAMETTA,256-20,TOP_MARGIN,12
  .BYTE ENEM_CODE_0_NANAMETTA,256-30,TOP_MARGIN,24
  .BYTE $FE,60
  .BYTE ENEM_CODE_0_NANAMETTA,128,TOP_MARGIN,6
YOKOGIRYA_LOOP:
  .BYTE $FE,200
  .BYTE ENEM_CODE_1_YOKOGIRYA,0,  TOP_MARGIN,3
  .BYTE ENEM_CODE_1_YOKOGIRYA,255,TOP_MARGIN+(8*1),257-3
  .BYTE ENEM_CODE_1_YOKOGIRYA,0,  TOP_MARGIN+(8*2),3
  .BYTE ENEM_CODE_1_YOKOGIRYA,255,TOP_MARGIN+(8*3),257-3
  .BYTE ENEM_CODE_1_YOKOGIRYA,0,  TOP_MARGIN+(8*4),3
  .BYTE ENEM_CODE_1_YOKOGIRYA,255,TOP_MARGIN+(8*5),257-3
  .BYTE $FE,10
  .BYTE ENEM_CODE_1_YOKOGIRYA,0,  TOP_MARGIN,2
  .BYTE ENEM_CODE_1_YOKOGIRYA,255,TOP_MARGIN+(8*1),257-2
  .BYTE ENEM_CODE_1_YOKOGIRYA,0,  TOP_MARGIN+(8*2),3
  .BYTE ENEM_CODE_1_YOKOGIRYA,255,TOP_MARGIN+(8*3),257-3
  .BYTE ENEM_CODE_1_YOKOGIRYA,0,  TOP_MARGIN+(8*4),4
  .BYTE ENEM_CODE_1_YOKOGIRYA,255,TOP_MARGIN+(8*5),257-4
  .BYTE $FE,10
  .BYTE ENEM_CODE_1_YOKOGIRYA,0,  TOP_MARGIN,4
  .BYTE ENEM_CODE_1_YOKOGIRYA,255,TOP_MARGIN+(8*1),257-4
  .BYTE ENEM_CODE_1_YOKOGIRYA,0,  TOP_MARGIN+(8*2),3
  .BYTE ENEM_CODE_1_YOKOGIRYA,255,TOP_MARGIN+(8*3),257-3
  .BYTE ENEM_CODE_1_YOKOGIRYA,0,  TOP_MARGIN+(8*4),2
  .BYTE ENEM_CODE_1_YOKOGIRYA,255,TOP_MARGIN+(8*5),257-2
  .BYTE $FD
    .BYTE 100
    .WORD YOKOGIRYA_LOOP
  .BYTE $FF

