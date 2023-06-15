; -------------------------------------------------------------------
; SKIN0                         BETA
; -------------------------------------------------------------------
; ベタに、指定周波数が最大音量で出るだけ
; -------------------------------------------------------------------
SKIN0_BETA:
  BBS0 ZP_FLAG,@END           ; 初回以外スキップ
  LDA #15
  LDY #SKIN_STATE::VOL
  STA (ZP_SKIN_STATE_PTR),Y
  DEC ZP_FLAG                 ; 0をDECして$FF
@END:
  RTS

; -------------------------------------------------------------------
; SKIN1                        PIANO
; -------------------------------------------------------------------
; 徐々に音量が減衰する、ピアノ風
; VOLはTの関数である
; -------------------------------------------------------------------
SKIN1_PIANO:
  ; 終了フラグを見て分岐
  BBS7 ZP_FLAG,@END
  ; 経過時間取得
  SMB7 ZP_FLAG                ; とりあえず終了フラグを立てる、上書きされる
  ;LDY #SKIN_STATE::TIME
  LDA (ZP_SKIN_STATE_PTR)
  CMP #(15*4+1)
  BEQ @END                    ; 終了タイミングでは飛び、上書きされない
  ; TからVOLを算出する
  LSR                         ; 1/4T
  LSR
  EOR #$FF                    ; 反転で負数に
  SEC
  ADC #15                     ; newVol=15+(-1/4T)
  LDY #SKIN_STATE::VOL
  STA (ZP_SKIN_STATE_PTR),Y
  LDA #%00000011              ; FRQ,VOLともに更新
  STA ZP_FLAG
@END:
  RTS

; -------------------------------------------------------------------
; SKIN2                       VIBRATO
; -------------------------------------------------------------------
; 周波数を小刻みに変化させる
; -------------------------------------------------------------------
SKIN2_VIBRATO:
  BBS0 ZP_FLAG,@TICK           ; 初回以外スキップ
  ; VOL=MAX
  LDA #15
  LDY #SKIN_STATE::VOL
  STA (ZP_SKIN_STATE_PTR),Y
  ; FRQ
  LDY #SKIN_STATE::FRQ
  LDA (ZP_SKIN_STATE_PTR),Y
  INC
  STA (ZP_SKIN_STATE_PTR),Y
  DEC ZP_FLAG                 ; 0をDECして$FF
  RTS
@TICK:
  ; TIME bit0 に応じたFRQ揺らし
  ;LDY #SKIN_STATE::TIME
  LDA (ZP_SKIN_STATE_PTR)
  ROR A                       ; C=TIME bit0
  LDY #SKIN_STATE::FRQ
  LDA (ZP_SKIN_STATE_PTR),Y
  BCS @CS
  ADC #2
  BRA @CC
@CS:
  SBC #2
@CC:
  STA (ZP_SKIN_STATE_PTR),Y
@END:
  RTS

; -------------------------------------------------------------------
; SKIN3                         NOISE
; -------------------------------------------------------------------
; ノイズ
; -------------------------------------------------------------------
SKIN3_NOISE:
  BBS0 ZP_FLAG,@END           ; 初回以外スキップ
  LDA #15
  LDY #SKIN_STATE::VOL
  STA (ZP_SKIN_STATE_PTR),Y
  DEC ZP_FLAG                 ; 0をDECして$FF
@END:
  RTS

SKIN_TABLE_L:
  .BYTE <SKIN0_BETA
  .BYTE <SKIN1_PIANO
  .BYTE <SKIN2_VIBRATO
  .BYTE <SKIN3_NOISE

SKIN_TABLE_H:
  .BYTE >SKIN0_BETA
  .BYTE >SKIN1_PIANO
  .BYTE >SKIN2_VIBRATO
  .BYTE >SKIN3_NOISE

