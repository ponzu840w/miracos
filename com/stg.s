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
HIT_FLASH = $FF       ; 被弾フラッシュ
PLAYER_SPEED = 3      ; PL速度
PLAYER_SHOOTRATE = 8  ; 射撃クールダウンレート
PLBLT_SPEED = 6       ; PLBLT速度
PLAYER_X = (256/2)-4  ; プレイヤー初期位置X
PLAYER_Y = 192-(8*3)  ; プレイヤー初期位置Y
TOP_MARGIN = 8*3      ; 上部のマージン
RL_MARGIN = 4         ; 左右のマージン
ZANKI_MAX = 6         ; ストック可能な自機の最大数
ZANKI_START = 3       ; 残機の初期値
MAX_STARS = 32        ; 星屑の最大数

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
  ZP_PL_STAT_FLAG:    .RES 1        ; 7|???? ??,自動前進,無敵|0
  ZP_STARS_OFFSET:    .RES 1

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
  ; 星屑のリスト
  ; 初の試みとして、リスト長を最初に持ってくる
  ;STARS_LIST:     .RES 256
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
  JMP INIT_TITLE            ; タイトルに飛ぶ
INIT_GAME:
  ; ---------------------------------------------------------------
  ;   YMZ
  JSR MUTE_ALL
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
  LDA #PLAYER_X
  STA ZP_PLAYER_X           ; プレイヤー初期座標
  LDA #PLAYER_Y
  STA ZP_PLAYER_Y
  ; ---------------------------------------------------------------
  ;   CRTCと画面の初期化
  ; FB2
  LDA #(CRTC2::WF|2)        ; FB2を書き込み先に
  STA CRTC2::CONF
  LDA #(CRTC2::TT|0)        ; 念のため16色モードを設定
  STA CRTC2::CONF
  LDA #HIT_FLASH
  JSR FILL                  ; FB2塗りつぶし
  ; FB1
  LDA #(CRTC2::WF|1)        ; FB1を書き込み先に
  STA CRTC2::CONF
  LDA #(CRTC2::TT|0)        ; 念のため16色モードを設定
  STA CRTC2::CONF
  JSR FILL_BG               ; FB1塗りつぶし
  ; FB2
  LDA #(CRTC2::WF|2)        ; FB2を書き込み先に
  STA CRTC2::CONF
  LDA #(CRTC2::TT|0)        ; 念のため16色モードを設定
  STA CRTC2::CONF
  JSR FILL_BG               ; FB2塗りつぶし
  ; DISP
  LDA #%01010101            ; FB1
  STA ZP_VISIBLE_FLAME      ; シフトして1,2をチェンジする用変数
  STA CRTC2::DISP           ; 表示フレームを全てFB1に
  ; chrbox設定
  LDA #3                    ; よこ4
  STA CRTC2::CHRW
  LDA #7                    ; たて8
  STA CRTC2::CHRH
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
;                            星屑ティック
; -------------------------------------------------------------------
.macro tick_stars
  ; リストのデータは直前フレームのまま、
  ;   描画されているのは前々フレームのまま
  ; カウントアップを切る理由あったっけ -> 垂直座標だけ書き換えてた
  ;LDA #%00000000            ; 全フレーム16色モード、16色モード座標書き込み、書き込みカウントアップ無効
  ;STA CRTC::CFG
  STZ CRTC2::CHRW           ; chrbox横幅1
  LDX #MAX_STARS*2
@LOOP:
  ; ---------------------------------------------------------------
  ;   前々フレームの残骸を削除
  LDA STARS_LIST-1,X
  STA CRTC2::PTRX
  TAY
  ASL
  ROL ZR0                   ; ZR0.bit0 偶数で0,倍速落ち
  LDA ZP_STARS_OFFSET
  CLC
  ADC STARS_LIST,X
  BBS0 ZR0,@SKP_SHIFT1
  ASL
@SKP_SHIFT1:
  CMP #192-(TOP_MARGIN)
  BCS @NEXT
  CLC
  ADC #TOP_MARGIN+2
  PHA
  DEC
  BBS0 ZR0,@SKP_SHIFT2
  DEC
@SKP_SHIFT2:
  STA CRTC2::PTRY
  LDA #DEBUG_BGC
  STA CRTC2::WDAT
  ; ---------------------------------------------------------------
  ;   新規描画
  PLA
  INC
  BBS0 ZR0,@SKP_SHIFT3
  INC
@SKP_SHIFT3:
  STY CRTC2::PTRX
  STA CRTC2::PTRY
  LDA #$0F
  STA CRTC2::WDAT
@NEXT:
  DEX
  DEX
  BNE @LOOP
@END:
  INC ZP_STARS_OFFSET
  ;LDA #%00000001            ; 全フレーム16色モード、16色モード座標書き込み、書き込みカウントアップ有効
  ;STA CRTC::CFG
  LDA #3                    ; よこ4
  STA CRTC2::CHRW
.endmac

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
;.macro anti_noise
;  .local @ANLLOOP
;  STZ CRTC::VMAH    ; 水平カーソルを左端に
;  LDA ZP_ANT_NZ_Y   ; アンチノイズY座標
;  STA CRTC::VMAV
;  LDX #$20          ; 繰り返し回数
;  LDA #BGC
;@ANLLOOP:
;  STA CRTC::WDBF    ; $8x$20=$100=256
;  STA CRTC::WDBF    ; 2行の塗りつぶし
;  STA CRTC::WDBF
;  STA CRTC::WDBF
;  STA CRTC::WDBF
;  STA CRTC::WDBF
;  STA CRTC::WDBF
;  STA CRTC::WDBF
;  DEX
;  BNE @ANLLOOP
;  INC ZP_ANT_NZ_Y
;.endmac

; -------------------------------------------------------------------
;                           フレーム交換
; -------------------------------------------------------------------
.macro exchange_frame
  LDA ZP_VISIBLE_FLAME
  TAX
  AND #%00000011            ; 下位のみにマスク
  ORA #CRTC2::WF            ; WFサブアドレス
  STA CRTC2::CONF
  TXA
  CLC
  ROL ; %01010101と%10101010を交換する
  ADC #0
  STA ZP_VISIBLE_FLAME
  STA CRTC2::DISP
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
  LDA ZP_ZANKI
  CMP #$FF
  BNE @SKP_TITLE
  JMP INIT_TITLE
@SKP_TITLE:
  SMB0 ZP_INFO_FLAG_P       ; 残機再描画フラグを立てる
  ; 死亡無敵処理
  ; TODO:AND一括処理との効率比較
  SMB0 ZP_PL_STAT_FLAG      ; 無敵フラグを立てる
  SMB1 ZP_PL_STAT_FLAG      ; オート前進フラグ
  LDA ZP_GENERAL_CNT
  AND #%01111111
  STA ZP_DEATH_MUTEKI       ; 死亡時点を記録
  ; リスポーン
  LDA #PLAYER_X
  STA ZP_PLAYER_X
  LDA #192-8
  STA ZP_PLAYER_Y
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
  AND #%01111111
  CMP ZP_DEATH_MUTEKI
  BNE @SKP_DEATHMUTEKI
  ; $FFティック経過
  RMB0 ZP_PL_STAT_FLAG  ; bit0 無敵フラグを折る
@SKP_DEATHMUTEKI:
  ; リスポーン直後出撃モーション
  BBR1 ZP_PL_STAT_FLAG,@SKP_RESPAWN_MOVE
  STZ ZP_PL_DX
  LDA #255
  STA ZP_PL_DY
  LDA ZP_PLAYER_Y
  CMP #192-(8*3)        ; Y - 192
  BCS @SKP_RESPAWN_MOVE
  RMB1 ZP_PL_STAT_FLAG  ; bit1 リスポーン直後フラグを折る
@SKP_RESPAWN_MOVE:
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
;                             パッド操作
; -------------------------------------------------------------------
.macro tick_pad
TICK_PAD:
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
  LDA #SE_PLSHOT_NUMBER
  JSR PLAY_SE                 ; 発射音再生
@SKP_B:
  BBS6 ZP_PADSTAT,@SKP_Y      ; Y button 敵召喚
  DEC ZP_PL_COOLDOWN          ; クールダウンチェック
  BNE @SKP_Y
  LDA #PLAYER_SHOOTRATE
  STA ZP_PL_COOLDOWN          ; クールダウン更新
  make_enem1                 ; PL弾生成
@SKP_Y:
.endmac

; -------------------------------------------------------------------
;                          垂直同期割り込み
; -------------------------------------------------------------------
VBLANK:
TICK:
  tick_cmd                    ; コマンド処理
  ; ---------------------------------------------------------------
  ;   塗りつぶし
  make_blacklist_ptr          ; ブラックリストポインタ作成
  clear_by_blacklist          ; ブラックリストに沿ったエンティティ削除
  ;anti_noise                  ; ノイズ対策に行ごと消去
  ; ---------------------------------------------------------------
  ;   キー操作
  tick_pad
  ; ---------------------------------------------------------------
  ;   ティック処理
  tick_stars
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
  STX CRTC2::PTRX
  STY CRTC2::PTRY
  LDA #DEBUG_BGC              ; どこを四角く塗りつぶしたかがわかる
  STA CRTC2::WDAT
  LDA CRTC2::REPT
  LDA CRTC2::REPT
  LDA CRTC2::REPT
  LDY #8                      ; NOTE:7でよいはずだが塗りこぼし発生
DRAW_SQ_LOOP:
  LDA CRTC2::REPT
  LDA CRTC2::REPT
  LDA CRTC2::REPT
  LDA CRTC2::REPT
  DEY
  BNE DRAW_SQ_LOOP
  RTS

; 8x8キャラクタを表示する
; 書き込み座標はZP_CANVAS_X,Yで与えられる
; キャラデータの先頭座標がZP_CHAR_PTRで与えられる
DRAW_CHAR8:
  ; Xのアライメント
  LSR ZP_CANVAS_X
  LDA ZP_CANVAS_X
  ; 左右跨ぎチェック
  CMP #$7F-3
  BCS @END            ; 左右をまたぎそうならキャンセル
  ; 座標設定
  STA CRTC2::PTRX
  LDA ZP_CANVAS_Y
  STA CRTC2::PTRY
  LDY #0              ; Y:=キャラデータインデックス
@DRAW_CHAR8_LOOP0:
  LDA (ZP_CHAR_PTR),Y
  STA CRTC2::WDAT
  INY
  LDA (ZP_CHAR_PTR),Y
  STA CRTC2::WDAT
  INY
  LDA (ZP_CHAR_PTR),Y
  STA CRTC2::WDAT
  INY
  LDA (ZP_CHAR_PTR),Y
  STA CRTC2::WDAT
  INY
@DRAW_CHAR8_SKP_9:
  CPY #32
  BNE @DRAW_CHAR8_LOOP0
@END:
  RTS

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

; メッセージ画面、ゲーム画面を各背景色で
FILL_BG:
  ; message
  STZ CRTC2::PTRX
  STZ CRTC2::PTRY
  ; 上のフチ
  LDA #INFO_FLAME
  LDX #256/2
  JSR HLINE
  ; 左右の淵と中身
  LDY #TOP_MARGIN-2
@LOOP:
  LDA #INFO_FLAME_L
  STA CRTC2::WDAT
  LDA #INFO_BGC
  LDX #(256/2)-2
  JSR HLINE
  LDA #INFO_FLAME_R
  STA CRTC2::WDAT
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
  STA CRTC2::WDAT
  DEX
  BNE FILL_LOOP_H
  DEY
  BNE FILL_LOOP_V
  RTS

HLINE:
@LOOP:
  STA CRTC2::WDAT
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

MUTE_ALL:
  set_ymzreg #YMZ::IA_MIX,#%00111111
  RTS

CHAR_DAT_ZIKI:
  .INCBIN "+stg/ziki1-88-tate.bin"

CHAR_DAT_ZITAMA1:
  .INCBIN "+stg/zitama-88-tate.bin"

CHAR_DAT_DMK1:
  .INCBIN "+stg/dmk1-88.bin"

STAGE_CMDS:
  .BYTE $FE,60
  ; kibis1
  .REPEAT 5
  .BYTE ENEM_CODE_2_KIBIS,80,TOP_MARGIN,100
  .BYTE $FE,30
  .ENDREP
  .BYTE $FE,120
  ; kibis2
  .REPEAT 5
  .BYTE ENEM_CODE_2_KIBIS|1,255-80,TOP_MARGIN,100
  .BYTE $FE,30
  .ENDREP
  .BYTE $FE,120
  ; 支援ナナメッタ
  .BYTE ENEM_CODE_0_NANAMETTA,30,TOP_MARGIN,24
  .BYTE ENEM_CODE_0_NANAMETTA,256-30,TOP_MARGIN,24
  .BYTE $FE,10
  ; 同時キビス
  .REPEAT 5
  .BYTE ENEM_CODE_2_KIBIS,95,TOP_MARGIN,100
  .BYTE ENEM_CODE_2_KIBIS|1,255-95,TOP_MARGIN,100
  .BYTE $FE,30
  .ENDREP
  ; 支援ナナメッタ
  .BYTE $FE,120
  .BYTE ENEM_CODE_0_NANAMETTA,60,TOP_MARGIN,24
  .BYTE ENEM_CODE_0_NANAMETTA,40,TOP_MARGIN,24
  .BYTE ENEM_CODE_0_NANAMETTA,256-40,TOP_MARGIN,24
  .BYTE ENEM_CODE_0_NANAMETTA,256-60,TOP_MARGIN,24
  .BYTE $FE,10
  ; シンプルなヨコギリャループ
YOKOGIRYA_SIMPLE_LOOP:
  .REPEAT 10
  .BYTE ENEM_CODE_1_YOKOGIRYA,0,  TOP_MARGIN+(8*2),3
  .BYTE ENEM_CODE_1_YOKOGIRYA,255,TOP_MARGIN+(8*1),257-3
  .BYTE $FE,10
  .ENDREP
  ;.BYTE $FD  ; やはりリロードしないと回数がくるうのはだめだ
  ;  .BYTE 10
  ;  .WORD YOKOGIRYA_SIMPLE_LOOP
  .BYTE ENEM_CODE_2_KIBIS,80,TOP_MARGIN,2                 ; アクセントキビス
  ; 支援ナナメッタ
  .BYTE $FE,120
  .BYTE ENEM_CODE_0_NANAMETTA,128,TOP_MARGIN,24
  .BYTE $FE,10
  ; シンプルなヨコギリャループ
YOKOGIRYA_SIMPLE_LOOP2:
  .REPEAT 20
  .BYTE ENEM_CODE_1_YOKOGIRYA,0,  TOP_MARGIN+(8*2),3
  .BYTE $FE,15
  .BYTE ENEM_CODE_1_YOKOGIRYA,255,TOP_MARGIN+(8*1),257-3
  .BYTE $FE,15
  .ENDREP
  ; 同時キビスつき
  .REPEAT 5
  .BYTE ENEM_CODE_1_YOKOGIRYA,0,  TOP_MARGIN+(8*2),3
  .BYTE $FE,15
  .BYTE ENEM_CODE_1_YOKOGIRYA,255,TOP_MARGIN+(8*1),257-3
  .BYTE ENEM_CODE_2_KIBIS,95,TOP_MARGIN,100
  .BYTE ENEM_CODE_2_KIBIS|1,255-95,TOP_MARGIN,100
  .BYTE $FE,15
  .ENDREP
  .REPEAT 20
  .BYTE ENEM_CODE_1_YOKOGIRYA,0,  TOP_MARGIN+(8*2),3
  .BYTE $FE,15
  .BYTE ENEM_CODE_1_YOKOGIRYA,255,TOP_MARGIN+(8*1),257-3
  .BYTE $FE,15
  .ENDREP
  ; 同時キビスつき
  .REPEAT 5
  .BYTE ENEM_CODE_1_YOKOGIRYA,0,  TOP_MARGIN+(8*2),3
  .BYTE $FE,15
  .BYTE ENEM_CODE_1_YOKOGIRYA,255,TOP_MARGIN+(8*1),257-3
  .BYTE ENEM_CODE_2_KIBIS,95,TOP_MARGIN,100
  .BYTE ENEM_CODE_2_KIBIS|1,255-95,TOP_MARGIN,100
  .BYTE $FE,15
  .ENDREP
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

STARS_LIST:
  ; 偶数が早く落ちるので、奇数を増やす
  ;for i in {0..127}; do echo -n $((RANDOM % 256))","; done | clip.exe
  ;for i in {0..127}; do echo -n $(((RANDOM % 128) * 2 + 1))","; done | clip.exe
  .BYTE 197,23,229,223,97,55,187,133,155,177,71,255,253,197,59,159,153,141,141,101,233,251,159,165,97,105,41,27,133,241,39,83,171,67,199,243,33,201,115,21,59,133,225,251,139,233,235,199,247,141,55,225,55,79,249,131,245,163,161,249,71,77,143,75,55,29,117,89,215,175,147,247,85,207,195,191,31,253,169,107,65,133,203,13,197,11,37,1,13,167,67,191,17,213,43,111,43,255,123,95,133,119,47,77,195,211,151,19,37,243,249,249,3,199,167,43,97,27,193,251,135,159,65,61,67,45,163,33
  .BYTE 1,78,236,249,125,252,207,227,53,170,170,23,45,149,111,205,223,221,220,30,184,254,80,29,53,125,220,76,236,97,138,21,51,22,5,49,122,124,164,228,78,19,238,157,222,99,47,197,187,197,49,64,100,125,224,170,71,147,68,147,235,104,120,248,153,68,27,96,10,183,238,219,5,33,84,189,145,198,50,145,124,210,157,42,198,18,108,236,170,228,236,165,121,202,18,87,207,106,176,180,171,241,112,69,38,229,58,213,98,177,144,180,202,56,205,2,227,56,115,241,22,88,196,53,146,249,17,194
