
NANAMETTA_SHOOTRATE = 30

; -------------------------------------------------------------------
;                           敵種類リスト
; -------------------------------------------------------------------
ENEM_CODE_0_NANAMETTA          = 0*2  ; ナナメッタ。プレイヤーを狙ってか狙わずか、斜めに撃つ。

; -------------------------------------------------------------------
;                             ZP領域
; -------------------------------------------------------------------
.ZEROPAGE
  ZP_ENEM_TERMIDX:  .RES 1    ; ENEM_LSTの終端を指す
  ZP_ENEM_CODEWK:   .RES 1    ; 作業用敵種類
  ZP_ENEM_XWK:      .RES 1    ; X退避

; -------------------------------------------------------------------
;                            変数領域
; -------------------------------------------------------------------
.BSS
  ENEM_LST:         .RES 256  ; (code,X,Y,f),(code,X,Y,f),...

.SEGMENT "LIB"

; -------------------------------------------------------------------
;                             敵生成
; -------------------------------------------------------------------
.macro make_enem1
  LDY ZP_ENEM_TERMIDX
  LDA #ENEM_CODE_0_NANAMETTA
  STA ENEM_LST,Y        ; code
  LDA #200
  STA ENEM_LST+1,Y      ; X
  LDA ZP_PLAYER_Y
  STA ENEM_LST+2,Y      ; Y
  LDA #NANAMETTA_SHOOTRATE
  STA ENEM_LST+3,Y      ; T
  ; ---------------------------------------------------------------
  ;   インデックス更新
  TYA
  CLC
  ADC #4                    ; TAXとするとINX*4にサイクル数まで等価
  STA ZP_ENEM_TERMIDX
.endmac

; -------------------------------------------------------------------
;                             敵削除
; -------------------------------------------------------------------
; 対象インデックスはXで与えられる
DEL_ENEM:
  LDY ZP_ENEM_TERMIDX ; Y:終端インデックス
  LDA ENEM_LST-4,Y    ; 終端部データcode取得
  STA ENEM_LST,X      ; 対象codeに格納
  LDA ENEM_LST-3,Y    ; 終端部データX取得
  STA ENEM_LST+1,X    ; 対象Xに格納
  LDA ENEM_LST-2,Y    ; 終端部データY取得
  STA ENEM_LST+2,X    ; 対象Yに格納
  LDA ENEM_LST-1,Y    ; 終端部データT取得
  STA ENEM_LST+3,X    ; 対象Tに格納
  ; ---------------------------------------------------------------
  ;   インデックス更新
  TYA
  SEC
  SBC #4                    ; TAXとするとINX*4にサイクル数まで等価
  STA ZP_ENEM_TERMIDX
  RTS

; -------------------------------------------------------------------
;                           敵ティック
; -------------------------------------------------------------------
; Yはブラックリストインデックス
.macro tick_enem
TICK_ENEM:
  ; ---------------------------------------------------------------
  ;   ENEMリストループ
  LDX #$0                   ; X:敵リスト用インデックス
TICK_ENEM_LOOP:
  CPX ZP_ENEM_TERMIDX
  BCC @SKP_END
  JMP TICK_ENEM_END         ; 敵をすべて処理したなら敵処理終了
@SKP_END:
  STX ZP_ENEM_XWK
  LDA ENEM_LST,X            ; 敵コード取得
  STA ZP_ENEM_CODEWK        ; 作業用
  LDA ENEM_LST+1,X          ; 敵X座標取得
  STA ZP_CANVAS_X           ; 作業用に、描画用ゼロページを使う
  LDA ENEM_LST+2,X
  STA ZP_CANVAS_Y           ; 作業用に、描画用ゼロページを使う
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
  LDA ZP_CANVAS_X           ; 敵X座標取得
  SEC
  SBC PLBLT_LST,Y           ; PL弾X座標を減算
  ADC #8                    ; -8が0に
  CMP #16
  BCS @COL_PLBLT_LOOP
  ; ---------------------------------------------------------------
  ;   Y判定
  LDA ZP_CANVAS_Y           ; 敵Y座標取得
  SEC
  SBC PLBLT_LST+1,Y
  ADC #8                    ; -8が0に
  CMP #16
  BCS @COL_PLBLT_LOOP
  ; ---------------------------------------------------------------
  ;   敵被弾
  LDX ZP_ENEM_CODEWK        ; ジャンプテーブル用に
  JMP (ENEM_HIT_JT,X)
@END_COL_PLBLT:
  ; ---------------------------------------------------------------
  ;   個別更新処理（移動、射撃、など
  LDX ZP_ENEM_CODEWK        ; ジャンプテーブル用に
  JMP (ENEM_UPDATE_JT,X)
TICK_ENEM_UPDATE_END:
  ; ---------------------------------------------------------------
  ;   BL登録
  PLY
  LDA ZP_CANVAS_X
  STA (ZP_BLACKLIST_PTR),Y  ; BL格納X
  INY
  LDA ZP_CANVAS_Y
  STA (ZP_BLACKLIST_PTR),Y  ; BL格納Y
  INY
  ; ---------------------------------------------------------------
  ;   インデックス更新
  LDA ZP_ENEM_XWK
  CLC
  ADC #4
  PHA
  ; ---------------------------------------------------------------
  ;   実際の描画
  PHY
  JSR DRAW_CHAR8            ; 描画する
  PLY
  PLX
  BRA TICK_ENEM_LOOP        ; 敵処理ループ
TICK_ENEM_END:
.endmac

; -------------------------------------------------------------------
;                             敵個別
; -------------------------------------------------------------------
; -------------------------------------------------------------------
;                        敵更新処理テーブル
; -------------------------------------------------------------------
ENEM_UPDATE_JT:
  .WORD NANAMETTA_UPDATE

NANAMETTA_UPDATE:
  ; ---------------------------------------------------------------
  ;   射撃判定
  LDX ZP_ENEM_XWK
  DEC ENEM_LST+3,X         ; T減算
  BNE @SKP_SHOT
  LDA #NANAMETTA_SHOOTRATE
  STA ENEM_LST+3,X         ; クールダウン更新
  ; ---------------------------------------------------------------
  ;   射撃
  LDY ZP_DMK1_TERMIDX       ; Y:DMK1インデックス
  ; X
  LDA ZP_CANVAS_X
  STA DMK1_LST,Y            ; X
  ; dX
  CMP ZP_PLAYER_X           ; PL-Xと比較
  LDA #1
  BCC @SKP_ADC256a
  LDA #256-1
  @SKP_ADC256a:
  STA DMK1_LST+2,Y          ; dX
  ; Y
  LDA ZP_CANVAS_Y
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
  JSR PLAY_SE               ; 発射音再生 X使用
@SKP_SHOT:
  ; ---------------------------------------------------------------
  ;   移動
  LDX ZP_ENEM_XWK
  LDA ZP_CANVAS_X
  INC
  STA ENEM_LST+1,X
  ;INC ZP_CANVAS_X
  ;LDA ENEM1_LST,X
  ;ADC #$80
  ;CLC
  ;ADC #256-1
  ;BVC @SKP_DEL_LEFT
  ; ENEM1削除
  ;PHY
  ;JSR DEL_ENEM1
  ;PLY
  ;JMP @DRAWPLBL
;@SKP_DEL_LEFT:
  ;SEC
  ;SBC #$80
  ;STA ENEM1_LST,X
  JMP TICK_ENEM_UPDATE_END

; -------------------------------------------------------------------
;                        敵被弾処理テーブル
; -------------------------------------------------------------------
ENEM_HIT_JT:
  .WORD NANAMETTA_HIT

NANAMETTA_HIT:
  LDX ZP_ENEM_XWK
  JSR DEL_ENEM              ; 敵削除
  LDA #SE2_NUMBER
  JSR PLAY_SE               ; 撃破効果音
  LDX ZP_ENEM_XWK
  PLY                       ; BLPTR
  JMP TICK_ENEM_LOOP

; -------------------------------------------------------------------
;                             敵画像
; -------------------------------------------------------------------
CHAR_DAT_TEKI1:
  .INCBIN "../../ChDzUtl/images/teki1-88.bin"

