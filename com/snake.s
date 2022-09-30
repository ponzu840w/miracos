; -------------------------------------------------------------------
;                           SNAKEゲーム
; -------------------------------------------------------------------
; 蛇のゲーム
; -------------------------------------------------------------------
.INCLUDE "../FXT65.inc"
.INCLUDE "../generic.mac"
.INCLUDE "../fs/structfs.s"
.INCLUDE "../fscons.inc"
.PROC BCOS
  .INCLUDE "../syscall.inc"  ; システムコール番号
.ENDPROC
.INCLUDE "../syscall.mac"
.INCLUDE "../zr.inc"

; -------------------------------------------------------------------
;                            定数定義
; -------------------------------------------------------------------
LEFT  =%0001
BUTTOM=%0010
TOP   =%0100
RIGHT =%1000
CHR_BLANK =' '
CHR_HEAD  ='O'
CHR_TAIL  ='o'
CHR_WALL  =$1F
CHR_APPLE ='@'
CHR_YOKOBO=$10
CHR_TATEBO=$11
CHR_HIDARI_UE=$12
CHR_MIGI_UE=$13
CHR_HIDARI_SITA=$15
CHR_MIGI_SITA=$14
CHR_ALLOWL=$C1
CHR_ALLOWR=$C0

; -------------------------------------------------------------------
;                             ZP領域
; -------------------------------------------------------------------
.ZEROPAGE
ZP_TXTVRAM768_16:         .RES 2  ; カーネルのワークエリアを借用するためのアドレス
ZP_FONT2048_16:           .RES 2  ; カーネルのワークエリアを借用するためのアドレス
ZP_TRAM_VEC16:            .RES 2  ; TRAM操作用ベクタ
ZP_FONT_VEC16:            .RES 2  ; フォント読み取りベクタ
ZP_FONT_SR:               .RES 1  ; FONT_OFST
ZP_DRAWTMP_X:             .RES 1  ; 描画用
ZP_DRAWTMP_Y:             .RES 1  ; 描画用
ZP_ITR:                   .RES 1  ; 汎用イテレータ
ZP_SNK_HEAD_X:            .RES 1  ; 頭の座標
ZP_SNK_HEAD_Y:            .RES 1
ZP_SNK_TAIL_X:            .RES 1  ; 尾の座標
ZP_SNK_TAIL_Y:            .RES 1
ZP_SNK_HEAD_PTR8:         .RES 1  ; 向きキューの頭のインデックス
ZP_SNK_TAIL_PTR8:         .RES 1  ; 向きキューの尾のインデックス
ZP_SNK_LENGTH:            .RES 1  ; 蛇の長さ 1...
ZP_SNK_LENGTHR:           .RES 1  ; 蛇の長さ 1...レコード
ZP_SNK_DIREC:             .RES 1  ; 次の向き
ZP_INPUT:                 .RES 1  ; キー入力バッファ
ZP_RND_ADDR16:            .RES 2  ; カーネルが乱数をくれるはずのアドレス
ZP_APPLE_X:               .RES 1  ; リンゴの座標
ZP_APPLE_Y:               .RES 1
ZP_VB_STUB:               .RES 2  ; 割り込み終了処理
ZP_VB_PAR_TICK:           .RES 1  ; ティック当たり垂直同期割込み数。難易度を担う。
ZP_GEAR_FOR_TICK:         .RES 1  ; TICK生成
ZP_GEAR_FOR_SEC:          .RES 1  ; 秒生成
ZP_MM:                    .RES 1  ; 経過分数（デシマル
ZP_SS:                    .RES 1  ; 経過秒数（デシマル
ZP_MMR:                   .RES 1  ; レコード経過分数（デシマル
ZP_SSR:                   .RES 1  ; レコード経過秒数（デシマル
ZP_TICK_FLAG:             .RES 1  ; 0=ティック待機期間 非0=ティック発生
ZP_SELECTOR_STATE:        .RES 1  ; メニュー状態
ZP_SP:                    .RES 1
; SNESPAD
ZP_PADSTAT:         .RES 2        ; ゲームパッドの状態が収まる
ZP_SHIFTER:         .RES 1        ; ゲームパッド読み取り処理用
ZP_PRE_PADSTAT:     .RES 2
ZP_VB_ON:           .RES 1

; -------------------------------------------------------------------
;                             実行領域
; -------------------------------------------------------------------
.CODE
START:
  TSX
  STX ZP_SP
  mem2mem16 ZP_PRE_PADSTAT,ZP_PADSTAT ; 表示するときすなわち状態変化があったとき、前回状態更新
  ; 汎用ポートの設定
  LDA VIA::PAD_DDR          ; 0で入力、1で出力
  ORA #(VIA::PAD_CLK|VIA::PAD_PTS)
  AND #<~(VIA::PAD_DAT)
  STA VIA::PAD_DDR
  ; アドレス類を取得
  LDY #BCOS::BHY_GET_ADDR_txtvram768  ; TRAM
  syscall GET_ADDR
  storeAY16 ZP_TXTVRAM768_16
  LDY #BCOS::BHY_GET_ADDR_font2048    ; FONT
  syscall GET_ADDR
  storeAY16 ZP_FONT2048_16
  LDY #BCOS::BHY_GET_ADDR_zprand16    ; RND
  syscall GET_ADDR
  storeAY16 ZP_RND_ADDR16
  ; レコード記録リセット
  STZ ZP_MMR
  STZ ZP_SSR
  STZ ZP_SNK_LENGTHR
  STZ ZP_VB_ON                        ; VB処理オフ（PAD除く
  ; 割り込みハンドラの登録
  SEI
  loadAY16 VBLANK
  syscall IRQ_SETHNDR_VB
  storeAY16 ZP_VB_STUB
  CLI
  JSR TITLE
GAME:
  JSR CLEAR_TXTVRAM                   ; 画面クリア
  ; 速度メータ表示
  LDA #']'
  LDX #7
  LDY #23
  JSR XY_PUT
  LDA #'['
  LDX #0
  JSR XY_PUT
  LDA ZP_VB_PAR_TICK
  STA ZP_ITR
@SPEED_LOOP:
  LDA #'>'
  INX
  JSR XY_PUT
  LDA ZP_ITR
  INC
  STA ZP_ITR
  CMP #8
  BNE @SPEED_LOOP
  LDA #1
  STA ZP_VB_ON                        ; VB処理オン
  ; ゲーム情報の初期化
  STZ ZP_TICK_FLAG
  ; 長さ
  LDA #1
  STA ZP_SNK_LENGTH
  ; 向きリングキューのポインタ初期化
  STZ ZP_SNK_TAIL_PTR8
  STZ ZP_SNK_HEAD_PTR8
  ; 向きリングキューの内容初期化
  LDA #RIGHT          ; 右を向いている
  STA ZP_SNK_DIREC
  STA SNAKE_DATA256
  ; 実座標データの初期化
  LDA #10             ; 10,10がちょうどよかろうか
  STA ZP_SNK_HEAD_X
  STA ZP_SNK_HEAD_Y
  STA ZP_SNK_TAIL_X
  STA ZP_SNK_TAIL_Y
  ; Length
  loadmem16 ZR0,STR_LENGTH
  LDX #10
  LDY #22
  JSR XY_PRT_STR
  ; Record
  loadmem16 ZR0,STR_RECORD
  LDX #10
  INY
  JSR XY_PRT_STR
  ; RecordTime
  LDA ZP_MMR
  STA ZP_MM
  LDA ZP_SSR
  STA ZP_SS
  LDX #27
  LDY #23
  JSR XY_PRT_TIME
  ; Time
  STZ ZP_MM
  STZ ZP_SS
  LDX #27
  LDY #22
  JSR XY_PRT_TIME
  JSR DRAW_LENGTH                     ; LENGTH描画
  JSR DRAW_LENGTHR                    ; LENGTHR描画
  JSR DRAW_FRAME                      ; 枠の描画
  JSR DRAW_ALLLINE                    ; 全部描画
  ; 初期リンゴ
  JSR GEN_APPLE
@LOOP:
  ; wasd
  LDA #BCOS::BHA_CON_RAWIN_NoWaitNoEcho
  syscall CON_RAWIN
  BEQ @END_WASD
  STA ZP_INPUT
  LDA ZP_SNK_DIREC
  BIT #LEFT|RIGHT
  BEQ @V
@H:
@W:
  LDA ZP_INPUT
  CMP #'w'
  BNE @S
  LDA #TOP
  STA ZP_SNK_DIREC
@S:
  CMP #'s'
  BNE @END_WASD
  LDA #BUTTOM
  STA ZP_SNK_DIREC
@V:
@A:
  LDA ZP_INPUT
  CMP #'a'
  BNE @D
  LDA #LEFT
  STA ZP_SNK_DIREC
@D:
  CMP #'d'
  BNE @END_WASD
  LDA #RIGHT
  STA ZP_SNK_DIREC
@END_WASD:
  JSR MOVE_HEAD
  BCS @SKP_TAIL
  JSR MOVE_TAIL
@SKP_TAIL:
@TICK_WAIT:
  LDA ZP_TICK_FLAG
  BEQ @TICK_WAIT
  STZ ZP_TICK_FLAG
  BRA @LOOP

; -------------------------------------------------------------------
;                             タイトル
; -------------------------------------------------------------------
TITLE_Y=(24/2)-2
TITLE_DIF_Y=TITLE_Y+3
TITLE_DIF_X=12
TITLE_PROMPT_Y=23-3
TITLE_PROMPT_EXIT_X=9
TITLE_PROMPT_START_X=18
TITLE_MENU_SPEED=0
TITLE_MENU_EXIT=1
TITLE_MENU_START=2
TITLE:
  ; STARTにポイント
  LDA #TITLE_MENU_START
  STA ZP_SELECTOR_STATE
  ; 速度難易度のデフォ値
  LDA #5
  STA ZP_VB_PAR_TICK
  ; タイトル画面の描画
  JSR CLEAR_TXTVRAM                   ; 画面クリア
  ; ヘヒ゛ ケ゛ーム (8)
  loadmem16 ZR0,STR_TITLE_SNAKEGAME
  LDX #12             ; 中央寄せ
  LDY #TITLE_Y        ; 中央寄せ
  JSR XY_PRT_STR
  ; 難易度の調整ウィンドウ
  ; 0
  loadmem16 ZR0,STR_TITLE_DIF0
  LDX #TITLE_DIF_X
  LDY #TITLE_DIF_Y+1
  JSR XY_PRT_STR
  ; 1
  loadmem16 ZR0,STR_TITLE_DIF1
  LDX #TITLE_DIF_X
  LDY #TITLE_DIF_Y+2
  JSR XY_PRT_STR
  ; 2
  loadmem16 ZR0,STR_TITLE_DIF2
  LDX #TITLE_DIF_X
  LDY #TITLE_DIF_Y+3
  JSR XY_PRT_STR
  ; 3
  loadmem16 ZR0,STR_TITLE_DIF3
  LDX #TITLE_DIF_X
  LDY #TITLE_DIF_Y+4
  JSR XY_PRT_STR
  ; EXIT
  loadmem16 ZR0,STR_TITLE_EXIT
  LDX #TITLE_PROMPT_EXIT_X
  LDY #TITLE_PROMPT_Y
  JSR XY_PRT_STR
  ; START
  loadmem16 ZR0,STR_TITLE_START
  LDX #TITLE_PROMPT_START_X
  LDY #TITLE_PROMPT_Y
  JSR XY_PRT_STR
  ; 描画
  JSR DRAW_ALLLINE
@LOOP:
  ; キー入力駆動
  LDA #BCOS::BHA_CON_RAWIN_WaitAndNoEcho  ; キー入力待機
  syscall CON_RAWIN
  ; キーごとの処理
@W:
  ; Wキー
  ; EXIT/STARTにあるとき、SPEEDに移動する
  ; それ以外では何もしない
  CMP #'w'
  BNE @S
  LDA ZP_SELECTOR_STATE
  CMP #TITLE_MENU_SPEED         ; SPEEDか？
  BEQ @LOOP                     ; SPEEDなら無視
  ; SPEEDに移動
  LDA #TITLE_MENU_SPEED
  STA ZP_SELECTOR_STATE         ; 状態のセット
  LDA #' '                      ; *の塗りつぶし
  LDY #TITLE_PROMPT_Y
  LDX #TITLE_PROMPT_EXIT_X
  JSR XY_PUT
  ;LDA #' '                      ; *の塗りつぶし
  LDX #TITLE_PROMPT_START_X
  JSR XY_PUT_DRAW
  LDA #CHR_ALLOWL               ; ←
  LDX #TITLE_DIF_X-1
  LDY #TITLE_DIF_Y+3
  JSR XY_PUT
  LDA #CHR_ALLOWR               ; →
  LDX #TITLE_DIF_X+2+6
  JSR XY_PUT_DRAW
  BRA @LOOP
@S:
  ; Sキー
  ; SPEEDにあるとき、STARTに移動する
  CMP #'s'
  BNE @A
  LDA ZP_SELECTOR_STATE
  CMP #TITLE_MENU_SPEED         ; SPEEDか？
  BNE @LOOP                     ; EXIT/STARTなら無視
  ; STARTに移動
  LDA #TITLE_MENU_START
  STA ZP_SELECTOR_STATE         ; 状態のセット
  LDA #' '                      ; ←
  LDX #TITLE_DIF_X-1
  LDY #TITLE_DIF_Y+3
  JSR XY_PUT
  LDA #' '                      ; →
  LDX #TITLE_DIF_X+2+6
  JSR XY_PUT_DRAW
  LDA #'*'                      ; *START
  LDY #TITLE_PROMPT_Y
  LDX #TITLE_PROMPT_START_X
  JSR XY_PUT_DRAW
  BRA @LOOP
@A:
  ; Aキー
  ; STARTにあるとき、EXITにする
  ; SPEEDにあるとき、臓側する
  CMP #'a'
  BNE @D
  LDA ZP_SELECTOR_STATE
  CMP #TITLE_MENU_START         ; STARTか？
  BNE @A_NOT_START
  ; STARTをEXITに
  LDA #TITLE_MENU_EXIT
  STA ZP_SELECTOR_STATE         ; 状態のセット
  LDA #'*'                      ; *EXIT
  LDY #TITLE_PROMPT_Y
  LDX #TITLE_PROMPT_EXIT_X
  JSR XY_PUT
  LDA #' '                      ; *STARTの塗りつぶし
  LDX #TITLE_PROMPT_START_X
  JSR XY_PUT_DRAW
  BRA @LOOP
@A_NOT_START:
  LDA ZP_SELECTOR_STATE
  CMP #TITLE_MENU_SPEED         ; SPEEDか？
  BNE @LOOP2
  ; 減速
  LDA ZP_VB_PAR_TICK            ; 速度基準のチェック
  CMP #7
  BEQ @LOOP2                    ; 最低速度の7[/TICK]なら中断
  INC                           ; ++
  STA ZP_VB_PAR_TICK            ; 速度格納
  ; ヘビが一つ引っ込む
  LDA #TITLE_DIF_X+2+6
  SEC
  SBC ZP_VB_PAR_TICK            ; 減算により、新しい頭の座標が求まるはず
  TAX
  LDY #TITLE_DIF_Y+3
  LDA #CHR_HEAD
  JSR XY_PUT
  INX                           ; 古い頭を削除
  LDA #' '
  JSR XY_PUT_DRAW
  BRA @LOOP2
@D:
  ; Dキー
  ; EXITにあるとき、STARTにする
  ; SPEEDにあるとき、減速する
  CMP #'d'
  BNE @SKP_WASD
  LDA ZP_SELECTOR_STATE
  CMP #TITLE_MENU_EXIT         ; EXITか？
  BNE @D_NOT_EXIT
  ; START
  LDA #TITLE_MENU_START
  STA ZP_SELECTOR_STATE         ; 状態のセット
  LDA #'*'                      ; *EXIT
  LDY #TITLE_PROMPT_Y
  LDX #TITLE_PROMPT_START_X
  JSR XY_PUT
  LDA #' '                      ; *STARTの塗りつぶし
  LDX #TITLE_PROMPT_EXIT_X
  JSR XY_PUT_DRAW
  BRA @LOOP2
@D_NOT_EXIT:
  LDA ZP_SELECTOR_STATE
  CMP #TITLE_MENU_SPEED         ; SPEEDか？
  BNE @LOOP2
  ; 増速
  LDA ZP_VB_PAR_TICK            ; 速度基準のチェック
  CMP #2
  BEQ @LOOP2                    ; 最高速度の2[/TICK]なら中断
  DEC                           ; --
  STA ZP_VB_PAR_TICK            ; 速度格納
  ; ヘビが一つ引っ込む
  LDA #TITLE_DIF_X+2+6
  SEC
  SBC ZP_VB_PAR_TICK            ; 減算により、新しい頭の座標が求まるはず
  TAX
  LDY #TITLE_DIF_Y+3
  LDA #CHR_HEAD
  JSR XY_PUT
  DEX                           ; 胴を設置
  LDA #CHR_TAIL
  JSR XY_PUT_DRAW
  ;BRA @LOOP2

@SKP_START:
@SKP_ENTER:
@LOOP2:
  JMP @LOOP

@SKP_WASD:
  ; エンターキー
@ENTER:
  CMP #10
  BNE @SKP_ENTER
  LDA ZP_SELECTOR_STATE
  CMP #TITLE_MENU_EXIT
  BNE @SKP_EXIT
  ; 大政奉還コード
  ; 割り込みハンドラの登録抹消
  SEI
  mem2AY16 ZP_VB_STUB
  syscall IRQ_SETHNDR_VB
  CLI
  LDX ZP_SP
  TXS
  RTS
@SKP_EXIT:
  CMP #TITLE_MENU_START
  BNE @SKP_START
  RTS

; -------------------------------------------------------------------
;                        垂直同期割り込み
; -------------------------------------------------------------------
VBLANK:
  ; パッド状態反映
  JSR PAD_READ            ; パッドを読む
  BBR0 ZP_VB_ON,@SKP_SEC  ; ゲーム中以外はパッド処理だけで切り上げ
  ; ギアを回す
  DEC ZP_GEAR_FOR_TICK
  BNE @SKP_TICK
  LDA ZP_VB_PAR_TICK
  STA ZP_GEAR_FOR_TICK
  STA ZP_TICK_FLAG
@SKP_TICK:
  DEC ZP_GEAR_FOR_SEC
  BNE @SKP_SEC
  LDA #60
  STA ZP_GEAR_FOR_SEC
  ; 一秒ごとの処理
  SED
  LDA ZP_SS
  CLC
  ADC #1
  CMP #$60
  BNE @SKP_NEXT_MM
  LDA ZP_MM
  CLC
  ADC #1
  STA ZP_MM
  LDA #0
@SKP_NEXT_MM:
  STA ZP_SS
  LDX #27
  LDY #22
  JSR XY_PRT_TIME
  LDY #22
  JSR DRAW_LINE
  CLD
@SKP_SEC:
  JMP (ZP_VB_STUB)           ; 片付けはBCOSにやらせる

; -------------------------------------------------------------------
;                          リンゴを生成
; -------------------------------------------------------------------
GEN_APPLE:
  ; X
@RETRY_X:
  JSR GET_RND   ; $00...$FF
  AND #31
  ; 00...31
  CMP #2
  BMI @RETRY_X
  CMP #30
  BPL @RETRY_X
  ; 02...29
  STA ZP_APPLE_X
  ; Y
@RETRY_Y:
  JSR GET_RND   ; $00...$FF
  AND #31
  ; 00...31
  CMP #2
  BMI @RETRY_Y
  CMP #20
  BPL @RETRY_Y
  ; 02...29
  STA ZP_APPLE_Y
  ; 蛇と被ってないかチェック
  LDX ZP_APPLE_X
  LDY ZP_APPLE_Y
  JSR XY_GET
  CMP #CHR_BLANK
  BNE @RETRY_X
  ; 描画する
  LDA #CHR_APPLE
  JSR XY_PUT_DRAW
  RTS

; -------------------------------------------------------------------
;                           頭を動かす
; -------------------------------------------------------------------
MOVE_HEAD:
  CLC
  PHP
  ; 頭を胴にする
  LDA #CHR_TAIL
  LDX ZP_SNK_HEAD_X
  LDY ZP_SNK_HEAD_Y
  JSR XY_PUT_DRAW
  ; 次の頭の座標を取得する
  LDA ZP_SNK_DIREC
  JSR NEXT_XY
  ; そこを調べる
  JSR XY_GET
  CMP #CHR_WALL
  BEQ GAMEOVER
  CMP #CHR_TAIL
  BEQ GAMEOVER
  CMP #CHR_APPLE
  BNE @SKP_APPLE
  ; 成長処理
  SED
  CLC
  LDA ZP_SNK_LENGTH
  ADC #1
  STA ZP_SNK_LENGTH
  CLD
  PHX
  PHY
  JSR DRAW_LENGTH
  JSR DRAW_LINE
  JSR GEN_APPLE
  PLY
  PLX
  PLP
  SEC
  PHP
@SKP_APPLE:
  ; 大丈夫そうだ
  ; 頭の座標を更新
  LDA #CHR_HEAD
  STX ZP_SNK_HEAD_X
  STY ZP_SNK_HEAD_Y
  JSR XY_PUT_DRAW
  ; 向きリングキューの更新
  LDA ZP_SNK_DIREC        ; 使った向き
  LDX ZP_SNK_HEAD_PTR8    ; 更新すべき場所のポインタ
  STA SNAKE_DATA256,X     ; 向きを登録
  INC ZP_SNK_HEAD_PTR8    ; 進める
  PLP
  RTS

DRAW_LENGTH:
  LDA ZP_SNK_LENGTH
  LDY #22
  LDX #15+3
  JSR XY_PRT_BYT
  RTS

DRAW_LENGTHR:
  LDA ZP_SNK_LENGTHR
  LDY #23
  LDX #15+3
  JSR XY_PRT_BYT
  RTS

; -------------------------------------------------------------------
;                                衝突
; -------------------------------------------------------------------
GAMEOVER:
  STZ ZP_VB_ON                        ; VB処理オフ（PAD除く
  loadmem16 ZR0,STR_GAMEOVER
  LDX #11                             ; 中央寄せ
  LDY #TITLE_Y                        ; 中央寄せ
  JSR XY_PRT_STR
  loadmem16 ZR0,STR_GAMEOVER_PROM
  LDX #2                              ; 中央寄せ
  LDY #TITLE_Y+2                      ; 中央寄せ
  JSR XY_PRT_STR
  ; レコード処理
  LDA ZP_SNK_LENGTH
  CMP ZP_SNK_LENGTHR
  BMI @SKP_NEWRECORD                  ; 記録-レコード=負なら更新ならず
  STA ZP_SNK_LENGTHR
  LDA ZP_MM
  STA ZP_MMR
  LDA ZP_SS
  STA ZP_SSR
@SKP_NEWRECORD:
  JSR DRAW_ALLLINE                    ; 全部描画
@LOOP:
  ; キー入力駆動
  LDA #BCOS::BHA_CON_RAWIN_WaitAndNoEcho  ; キー入力待機
  syscall CON_RAWIN
  CMP #10
  BNE @SKP_GAME
  JMP GAME
@SKP_GAME:
  CMP #$1B
  BNE @SKP_ESC
  LDX ZP_SP
  TXS
  JMP START
@SKP_ESC:
  BRA @LOOP

; -------------------------------------------------------------------
;                             尾を動かす
; -------------------------------------------------------------------
MOVE_TAIL:
  ; 現在の尾を消す
  LDA #CHR_BLANK
  LDX ZP_SNK_TAIL_X
  LDY ZP_SNK_TAIL_Y
  JSR XY_PUT_DRAW
  ; 尾の座標を更新
  PHX
  LDX ZP_SNK_TAIL_PTR8
  LDA SNAKE_DATA256,X   ; 尾の持つ次の胴体へのDIRECを取得
  PLX
  JSR NEXT_XY           ; 次の尾となる胴体の座標を取得
  ; 次の尾の座標とする
  STX ZP_SNK_TAIL_X
  STY ZP_SNK_TAIL_Y
  ; 向きリングキューの尾ポインタを移動
  INC ZP_SNK_TAIL_PTR8
  RTS

; -------------------------------------------------------------------
;                 XY座標のDIREC方向に隣接するXY座標
; -------------------------------------------------------------------
NEXT_XY:
@RIGHT:
  CMP #RIGHT
  BNE @LEFT
  INX
  RTS
@LEFT:
  CMP #LEFT
  BNE @TOP
  DEX
  RTS
@TOP:
  CMP #TOP
  BNE @BUTTOM
  DEY
  RTS
@BUTTOM:
  INY
  RTS

; -------------------------------------------------------------------
;                           ワクを描画
; -------------------------------------------------------------------
DRAW_FRAME:
  ; 上
  LDY #0
  JSR DRAW_HLINE
  ; 下
  LDY #24-1-2
  JSR DRAW_HLINE
  ; 左右
  DEY
@LOOP_SIDE:
  LDX #0
  LDA #CHR_WALL
  JSR XY_PUT
  LDX #32-1
  LDA #CHR_WALL
  JSR XY_PUT
  DEY
  BNE @LOOP_SIDE
  RTS

; -------------------------------------------------------------------
;                           横棒を描画
; -------------------------------------------------------------------
DRAW_HLINE:
  LDX #0
  LDA #32
  STA ZP_ITR
@LOOP:
  LDA #CHR_WALL
  JSR XY_PUT
  INX
  DEC ZP_ITR
  BNE @LOOP
  ;JSR DRAW_LINE_RAW
  RTS

; -------------------------------------------------------------------
;                         XY位置から読み取り
; -------------------------------------------------------------------
XY_GET:
  PHX
  PHY
  ; --- 読み取り
  JSR XY2TRAM_VEC
  LDA (ZP_TRAM_VEC16),Y
  PLY
  PLX
  RTS

; -------------------------------------------------------------------
;                         XY位置に書き込み
; -------------------------------------------------------------------
XY_PUT:
  PHX
  PHY
  ; --- 書き込み
  PHA
  JSR XY2TRAM_VEC
  PLA
  STA (ZP_TRAM_VEC16),Y
  PLY
  PLX
  RTS

; -------------------------------------------------------------------
;                    XY位置に書き込み、描画込み
; -------------------------------------------------------------------
XY_PUT_DRAW:
  PHX
  PHY
  ; --- 書き込み
  PHA
  JSR XY2TRAM_VEC
  PLA
  STA (ZP_TRAM_VEC16),Y
  JSR DRAW_LINE_RAW    ; 呼び出し側の任意
  PLY
  PLX
  RTS

; -------------------------------------------------------------------
;                 カーソル位置に書き込み、描画込み
; -------------------------------------------------------------------
XY2TRAM_VEC:
  STZ ZP_FONT_SR        ; シフタ初期化
  STZ ZP_TRAM_VEC16     ; TRAMポインタ初期化
  TYA
  LSR
  ROR ZP_FONT_SR
  LSR
  ROR ZP_FONT_SR
  LSR
  ROR ZP_FONT_SR
  ADC ZP_TXTVRAM768_16+1
  STA ZP_TRAM_VEC16+1
  TXA
  ORA ZP_FONT_SR
  TAY
  RTS

; -------------------------------------------------------------------
;                       TRAMをスペースで埋める
; -------------------------------------------------------------------
CLEAR_TXTVRAM:
  mem2mem16 ZR0,ZP_TXTVRAM768_16
  LDA #' '
  LDY #0
  LDX #3
CLEAR_TXTVRAM_LOOP:
  STA (ZR0),Y
  INY
  BNE CLEAR_TXTVRAM_LOOP
  INC ZR0+1
  DEX
  BNE CLEAR_TXTVRAM_LOOP
  RTS

; -------------------------------------------------------------------
;                       TRAMの全行を反映する
; -------------------------------------------------------------------
DRAW_ALLLINE:
  mem2mem16 ZP_TRAM_VEC16,ZP_TXTVRAM768_16
  LDY #0
  LDX #6
DRAW_ALLLINE_LOOP:
  PHX
  JSR DRAW_LINE_RAW
  JSR DRAW_LINE_RAW
  JSR DRAW_LINE_RAW
  JSR DRAW_LINE_RAW
  PLX
  DEX
  BNE DRAW_ALLLINE_LOOP
  RTS

; -------------------------------------------------------------------
;                     Yで指定された行を反映する
; -------------------------------------------------------------------
DRAW_LINE:
  JSR XY2TRAM_VEC
DRAW_LINE_RAW:
  ; 行を描画する
  ; TRAM_VEC16を上位だけ設定しておき、そのなかのインデックスもYで持っておく
  ; 連続実行すると次の行を描画できる
  TYA                       ; インデックスをAに
  AND #%11100000            ; 行として意味のある部分を抽出
  TAX                       ; しばらく使わないXに保存
  ; HVの初期化
  STZ ZP_DRAWTMP_X
  ; 0~2のページオフセットを取得
  LDA ZP_TRAM_VEC16+1
  SEC
  ;SBC #>TXTVRAM768
  SBC ZP_TXTVRAM768_16+1
  STA ZP_DRAWTMP_Y
  ; インデックスの垂直部分3bitを挿入
  TYA
  ASL
  ROL ZP_DRAWTMP_Y
  ASL
  ROL ZP_DRAWTMP_Y
  ASL
  ROL ZP_DRAWTMP_Y
  ; 8倍
  LDA ZP_DRAWTMP_Y
  ASL
  ASL
  ASL
  STA ZP_DRAWTMP_Y
  ; --- フォント参照ベクタ作成
DRAW_TXT_LOOP:
  ;LDA #>FONT2048
  LDA ZP_FONT2048_16+1
  STA ZP_FONT_VEC16+1
  ; フォントあぶれ初期化
  LDY #0
  STY ZP_FONT_SR
  ; アスキーコード読み取り
  TXA                       ; 保存していたページ内行を復帰してインデックスに
  TAY
  LDA (ZP_TRAM_VEC16),Y
  ASL                       ; 8倍してあぶれた分をアドレス上位に加算
  ROL ZP_FONT_SR
  ASL
  ROL ZP_FONT_SR
  ASL
  ROL ZP_FONT_SR
  STA ZP_FONT_VEC16
  LDA ZP_FONT_SR
  ADC ZP_FONT_VEC16+1       ; キャリーは最後のROLにより0
  STA ZP_FONT_VEC16+1
  ; --- フォント書き込み
  ; カーソルセット
  LDA ZP_DRAWTMP_X
  STA CRTC::VMAH
  ; 一文字表示ループ
  LDY #0
CHAR_LOOP:
  LDA ZP_DRAWTMP_Y
  STA CRTC::VMAV
  ; フォントデータ読み取り
  LDA (ZP_FONT_VEC16),Y
  STA CRTC::WDBF
  INC ZP_DRAWTMP_Y
  INY
  CPY #8
  BNE CHAR_LOOP
  ; --- 次の文字へアドレス類を更新
  ; テキストVRAM読み取りベクタ
  INX
  BNE SKP_TXTNP
  INC ZP_TRAM_VEC16+1
SKP_TXTNP:
  ; H
  INC ZP_DRAWTMP_X
  LDA ZP_DRAWTMP_X
  AND #%00011111  ; 左端に戻るたびゼロ
  BNE SKP_EXT_DRAWLINE
  TXA
  TAY
  RTS
SKP_EXT_DRAWLINE:
  ; V
  SEC
  LDA ZP_DRAWTMP_Y
  SBC #8
  STA ZP_DRAWTMP_Y
  BRA DRAW_TXT_LOOP

; -------------------------------------------------------------------
;                             乱数取得
; -------------------------------------------------------------------
GET_RND:
X5PLUS1RETRY:
  LDA (ZP_RND_ADDR16)
  ASL
  ASL
  SEC ;+1
  ADC (ZP_RND_ADDR16)
  STA (ZP_RND_ADDR16)
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
NIB2ASC:
  ; #$0?をアスキー一文字にする
  ORA #$30
  CMP #$3A
  BCC @SKP_ADC  ; Aが$3Aより小さいか等しければ分岐
  ADC #$06
@SKP_ADC:
  RTS

; -------------------------------------------------------------------
;                      バイト値を16進2ケタで表示
; -------------------------------------------------------------------
XY_PRT_BYT:
  PHY
  JSR BYT2ASC
  STY ZR0
  PLY
  JSR XY_PUT
  INX
  LDA ZR0
  JSR XY_PUT
  RTS

; -------------------------------------------------------------------
;                            文字列を表示
; -------------------------------------------------------------------
XY_PRT_STR:
  LDA (ZR0)
  BEQ @EXT
  JSR XY_PUT
  INX
  INC ZR0
  BNE @SKP_INCH
  INC ZR0+1
@SKP_INCH:
  BRA XY_PRT_STR
@EXT:
  RTS

; -------------------------------------------------------------------
;                            時間を表示
; -------------------------------------------------------------------
XY_PRT_TIME:
  PHX
  PHY
  LDA ZP_MM
  JSR XY_PRT_BYT
  PLY
  PLX
  INX
  INX
  LDA #':'
  JSR XY_PUT
  INX
  LDA ZP_SS
  JSR XY_PRT_BYT
  RTS

PAD_READ:
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
  ; 変化はあったか
  LDA ZP_PADSTAT
  CMP ZP_PRE_PADSTAT
  BNE CHANGED
  LDA ZP_PRE_PADSTAT+1
  CMP ZP_PADSTAT+1
  BEQ NONE
CHANGED:
  ; LOW   : 7|B,Y,SEL,STA,↑,↓,←,→|0
  ; HIGH  : 7|A,X,L,R            |0
  mem2mem16 ZP_PRE_PADSTAT,ZP_PADSTAT ; 表示するときすなわち状態変化があったとき、前回状態更新
  LDA ZP_PADSTAT
  STA ZP_SHIFTER
  LDX #$FF                            ; 対照インデックス
@LOOP:
  INX
  CPX #8
  BNE @SKP_LD_HIGH
  ; highの処理に移行
  LDA ZP_PADSTAT+1
  STA ZP_SHIFTER
@SKP_LD_HIGH:
  CPX #12
  BEQ NONE
  LDA BUTTON2CHAR_LIST,X              ; 対応する文字を取得
  ROL ZP_SHIFTER
  BCS @LOOP
  ; 突っ込むべき文字を入手
  CMP #0
  BEQ NONE
  syscall CON_INTERRUPT_CHR
  ;syscall CON_OUT_CHR
NONE:
  RTS

ASCII_ENTER = $0A
ASCII_ESC   = $1B
BUTTON2CHAR_LIST:
  .BYT ASCII_ESC    ; B
  .BYT 0            ; Y
  .BYT 0            ; SELECT
  .BYT ASCII_ENTER  ; START
  .BYT 'w'          ; ↑
  .BYT 's'          ; ↓
  .BYT 'a'          ; ←
  .BYT 'd'          ; →
  .BYT ASCII_ENTER  ; A
  .BYT 0            ; X
  .BYT 'a'          ; L
  .BYT 'd'          ; R

STR_LENGTH: .ASCIIZ         "Length:"
STR_RECORD: .ASCIIZ         "Record:"
STR_TITLE_SNAKEGAME: .BYT   $AD,$EB,$BE,' ',$D9,$BE,$90,$F1,$0
;STR_TITLE_DIFNUMS: .ASCIIZ  "123456"
;STR_TITLE_DIFSNK:  .ASCIIZ  "ooO"
;  ********     0
;  *123456*     1
; ←*ooO   *→    2
;  ********     3
STR_TITLE_DIF0:
  .BYT CHR_HIDARI_UE
  .REPEAT 6
    .BYT CHR_YOKOBO
  .ENDREPEAT
  .BYT CHR_MIGI_UE
  .BYT 0
STR_TITLE_DIF1:
  .BYT CHR_TATEBO,"123456",CHR_TATEBO
  .BYT 0
STR_TITLE_DIF2:
  ;.BYT CHR_ALLOWL,CHR_TATEBO,"ooO   ",CHR_TATEBO,CHR_ALLOWR
  .BYT CHR_TATEBO,"ooO   ",CHR_TATEBO
  .BYT 0
STR_TITLE_DIF3:
  .BYT CHR_HIDARI_SITA
  .REPEAT 6
    .BYT CHR_YOKOBO
  .ENDREPEAT
  .BYT CHR_MIGI_SITA
  .BYT 0

STR_TITLE_EXIT:
  .ASCIIZ " EXIT"
STR_TITLE_START:
  .ASCIIZ "*START"
STR_GAMEOVER:
  .ASCIIZ "GAME OVER"
STR_GAMEOVER_PROM:
  .ASCIIZ " (B) to Quit / (A) to Retry"

SNAKE_DATA256:  .RES 256

