
; -------------------------------------------------------------------
;                               ZP領域
; -------------------------------------------------------------------
.ZEROPAGE
  ZP_ENEM1_TERMIDX:   .RES 1        ; ENEM1_LSTの終端を指す

; -------------------------------------------------------------------
;                              変数領域
; -------------------------------------------------------------------
.BSS
  ENEM1_LST:      .RES 32  ; (code,X,Y,f),(code,X,Y,f),...

; -------------------------------------------------------------------
;                             敵生成
; -------------------------------------------------------------------
.macro make_enem1
  LDY ZP_ENEM1_TERMIDX
  LDA #200
  STA ENEM1_LST,Y       ; X
  LDA ZP_PLAYER_Y
  STA ENEM1_LST+1,Y     ; Y
  LDA #ENEM1_SHOOTRATE
  STA ENEM1_LST+2,Y     ; T
  INY
  INY
  INY
  STY ZP_ENEM1_TERMIDX
.endmac

; -------------------------------------------------------------------
;                             敵削除
; -------------------------------------------------------------------
; 対象インデックスはXで与えられる
DEL_ENEM1:
  LDY ZP_ENEM1_TERMIDX  ; Y:終端インデックス
  LDA ENEM1_LST-3,Y    ; 終端部データX取得
  STA ENEM1_LST,X      ; 対象Xに格納
  LDA ENEM1_LST-2,Y    ; 終端部データY取得
  STA ENEM1_LST+1,X    ; 対象Yに格納
  LDA ENEM1_LST-1,Y    ; 終端部データT取得
  STA ENEM1_LST+2,X    ; 対象Tに格納
  DEY
  DEY
  DEY
  STY ZP_ENEM1_TERMIDX  ; 縮小した終端インデックス
  RTS

; -------------------------------------------------------------------
;                           敵ティック
; -------------------------------------------------------------------
; Yはブラックリストインデックス
.macro tick_enem1
  .local @TICK_ENEM1
  .local @DRAWPLBL
  .local @END
  .local @SKP_Hamburg
TICK_ENEM1:
  ; ---------------------------------------------------------------
  ;   ENEM1リストループ
  LDX #$0                   ; X:敵リスト用インデックス
@DRAWPLBL:
  CPX ZP_ENEM1_TERMIDX
  BCC @SKP_END
  JMP @END                  ; 敵をすべて処理したなら敵処理終了
@SKP_END:
  ; ---------------------------------------------------------------
  ;   PLBLTとの当たり判定
  PHY                       ; BLIDX退避
  LDY #$FE                  ; PL弾インデックス
@COL_PLBLT_LOOP:
  INY
  INY
  CPY ZP_PLBLT_TERMIDX      ; PL弾インデックスの終端確認
  BEQ @END_COL_PLBLT
  ; ---------------------------------------------------------------
  ;   X判定
  LDA ENEM1_LST,X           ; 敵X座標取得
  SEC
  SBC PLBLT_LST,Y           ; PL弾X座標を減算
  ADC #8                    ; -8が0に
  CMP #16
  BCS @COL_PLBLT_LOOP
  ; ---------------------------------------------------------------
  ;   Y判定
  LDA ENEM1_LST+1,X
  SEC
  SBC PLBLT_LST+1,Y
  ADC #8                    ; -8が0に
  CMP #16
  BCS @COL_PLBLT_LOOP
  ; ---------------------------------------------------------------
  ;   敵削除
@DEL:
  PHX
  JSR DEL_ENEM1             ; 敵削除
  LDA #SE2_NUMBER
  JSR PLAY_SE               ; 撃破効果音
  PLX
  PLY
  BRA @DRAWPLBL
@END_COL_PLBLT:
  ; ---------------------------------------------------------------
  ;   射撃判定
  DEC ENEM1_LST+2,X         ; T減算
  BNE @SKP_SHOT
  LDA #ENEM1_SHOOTRATE
  STA ENEM1_LST+2,X         ; クールダウン更新
  ; ---------------------------------------------------------------
  ;   射撃
  LDY ZP_DMK1_TERMIDX       ; Y:DMK1インデックス
  ; X
  LDA ENEM1_LST,X
  STA DMK1_LST,Y            ; X
  ; dX
  CMP ZP_PLAYER_X           ; PL-Xと比較
  LDA #1
  BCC @SKP_ADC256a
  LDA #256-1
  @SKP_ADC256a:
  STA DMK1_LST+2,Y          ; dX
  ; Y
  LDA ENEM1_LST+1,X
  STA DMK1_LST+1,Y          ; Y
  ; dY
  CMP ZP_PLAYER_Y           ; PL-Xと比較
  LDA #1
  BCC @SKP_ADC256b
  LDA #256-1
  @SKP_ADC256b:
  STA DMK1_LST+3,Y          ; dY
  TYA
  CLC
  ADC #4
  STA ZP_DMK1_TERMIDX       ; DMK1終端更新
  LDA #SE1_NUMBER
  PHX
  JSR PLAY_SE               ; 発射音再生 X使用
  PLX
@SKP_SHOT:
  ; ---------------------------------------------------------------
  ;   PLBLTループを抜け、描画処理
  PLY                       ; BLIDX復帰
  LDA ENEM1_LST,X
  ;ADC #$80
  CLC
  ADC #256-1
  ;BVC @SKP_DEL_LEFT
  ; ENEM1削除
  ;PHY
  ;JSR DEL_ENEM1
  ;PLY
  ;JMP @DRAWPLBL
@SKP_DEL_LEFT:
  ;SEC
  ;SBC #$80
  STA ENEM1_LST,X
  STA ZP_CANVAS_X           ; 描画用座標
  STA (ZP_BLACKLIST_PTR),Y  ; BL格納
  INX                       ; Y座標へ
  INY
  LDA ENEM1_LST,X           ; Y座標取得
  STA ZP_CANVAS_Y           ; 描画用座標
  STA (ZP_BLACKLIST_PTR),Y  ; BL格納
  INX                       ; 次のデータにインデックスを合わせる
  INX                       ; Tスキップ
  INY
  ; ---------------------------------------------------------------
  ;   実際の描画
  PHY
  PHX
  loadmem16 ZP_CHAR_PTR,CHAR_DAT_TEKI1
  JSR DRAW_CHAR8            ; 描画する
  PLX
  PLY
  JMP @DRAWPLBL             ; PL弾処理ループ
@END:
.endmac

