; -------------------------------------------------------------------
;                           DMK1ティック
; -------------------------------------------------------------------
.macro tick_dmk1
  .local TICK_DMK1
  .local @LOOP
  .local @END
  .local @SKP_Hamburg
  .local @DEL
TICK_DMK1:
  LDX #$0                   ; X:DMK1リスト用インデックス
@LOOP:
  CPX ZP_DMK1_TERMIDX
  BCS @END                  ; PL弾をすべて処理したならPL弾処理終了
  ; ---------------------------------------------------------------
  ;   X
  LDA DMK1_LST,X
  ADC #$80                  ; 半分ずらした状態で加算して戻すことで、Vフラグで跨ぎ判定
  CLC
  ADC DMK1_LST+2,X          ; dX加算
  BVC @SKP_Hamburg          ; 左右端を跨ぐなら削除
@DEL:
  ; 弾丸削除
  PHY
  JSR DEL_DMK1
  PLY
  BRA @LOOP
@SKP_Hamburg:
  SEC
  SBC #$80
  STA DMK1_LST,X            ; リストに格納
  STA ZP_CANVAS_X           ; 描画用座標
  STA (ZP_BLACKLIST_PTR),Y  ; BL格納
  ; ---------------------------------------------------------------
  ;   X当たり判定
  SEC
  SBC ZP_PLAYER_X
  ADC #3
  CMP #8
  ROR ZR0                   ; CをZR0 bit7に格納
  ; ---------------------------------------------------------------
  ;   Y
  LDA DMK1_LST+1,X          ; Y座標取得（信頼している
  CLC
  ADC DMK1_LST+3,X          ; dY加算
  STA DMK1_LST+1,X          ; リストに格納
  STA ZP_CANVAS_Y           ; 描画用座標
  INY
  STA (ZP_BLACKLIST_PTR),Y  ; BL格納
  DEY                       ; DELに備えて戻しておく
  SEC
  SBC #TOP_MARGIN
  CMP #192-TOP_MARGIN
  BCS @DEL
  INY                       ; DELは回避された
  ; ---------------------------------------------------------------
  ;   Y当たり判定
  BBS7 ZR0,@SKP_COL_Y       ; XがヒットしてなければY判定もスキップ
  LDA ZP_CANVAS_Y
  SEC
  SBC ZP_PLAYER_Y
  ADC #3
  CMP #8
  BCS @SKP_COL_Y
  ; ---------------------------------------------------------------
  ;   プレイヤダメージ
  LDA #SE2_NUMBER
  PHX
  JSR PLAY_SE               ; 撃破効果音
  PLX
@SKP_COL_Y:
  ; ---------------------------------------------------------------
  ;   インデックス更新
  TXA
  CLC
  ADC #4                    ; TAXとするとINX*4にサイクル数まで等価
  PHA                       ; しかしスタック退避を考慮するとこっちが有利
  INY
  ; ---------------------------------------------------------------
  ;   実際の描画
  PHY
  loadmem16 ZP_CHAR_PTR,CHAR_DAT_DMK1
  JSR DRAW_CHAR8            ; 描画する
  PLY
  PLX
  BRA @LOOP                 ; PL弾処理ループ
@END:
.endmac

; -------------------------------------------------------------------
;                            DMK1削除
; -------------------------------------------------------------------
; 対象インデックスはXで与えられる
DEL_DMK1:
  LDY ZP_DMK1_TERMIDX  ; Y:終端インデックス
  LDA DMK1_LST-4,Y     ; 終端部データX取得
  STA DMK1_LST,X       ; 対象Xに格納
  LDA DMK1_LST-3,Y     ; 終端部データX取得
  STA DMK1_LST+1,X     ; 対象Xに格納
  LDA DMK1_LST-2,Y     ; 終端部データX取得
  STA DMK1_LST+2,X     ; 対象Xに格納
  LDA DMK1_LST-1,Y     ; 終端部データX取得
  STA DMK1_LST+3,X     ; 対象Xに格納
  TYA
  SEC
  SBC #4
  STA ZP_DMK1_TERMIDX  ; 縮小した終端インデックス
  RTS

