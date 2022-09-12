; -------------------------------------------------------------------
;                        MIRACOS INTERRUPT
; -------------------------------------------------------------------
; BCOSの割り込み関連部分
; -------------------------------------------------------------------

; 通常より待ちの短い一文字送信。XOFF送信用。
; 時間計算をしているわけではないがとにかくこれで動く
.macro prt_xoff
  PHX
  LDX #$80
SHORTDELAY:
  NOP
  NOP
  DEX
  BNE SHORTDELAY
  PLX
  LDA #UART::XOFF
  STA UART::TX
.endmac

; --- BCOS独自の割り込みハンドラ ---
IRQ_BCOS:
  ; SEIだけされてここに飛んだ
  ; おとなしく全部スタックに退避する
  PHA
  PHX
  PHY
; --- 外部割込み判別 ---
  ; UART判定
  LDA UART::STATUS
  BIT #%00001000
  BEQ SKP_UART       ; bit3の論理積がゼロ、つまりフルじゃない
  ; すなわち受信割り込み
  LDA UART::RX        ; UARTから読み取り
  JSR TRAP            ; 制御トラップおよびエンキュー
PL_CLI_RTI:
  PLY
  PLX
  PLA
  CLI
  RTI
SKP_UART:
  ; VIA判定
  LDA VIA::IFR        ; 割り込みフラグレジスタ読み取り
  LSR                 ; C = bit 0 CA2
  BCC @SKP_CA2
  ; 垂直同期割り込み処理
  ; NOTE:ここにキーボード処理など
  ; PS/2は有効か
  BBR2 ZP_CON_DEV_CFG,@SKP_PS2TRAP
  ; PS/2処理
  JSR PS2::VBLANK
  BEQ @SKP_PS2TRAP
  JSR TRAP
@SKP_PS2TRAP:
  JMP (VBLANK_USER_VEC16)
@SKP_CA2:
  ; T1検査
  AND #%00100000      ; Z -> not T1（1右シフト済み）
  BEQ @SKP_T1
  ; タイムアウト用カウントダウン
  DEC TIMEOUT_MS_CNT
  BNE @SET_T1             ; 数え切らないうちはT1再設定
  ; タイムアウト発生
  BIT VIA::T1CL           ; 割り込みフラグぽっきり
  ; スタックポインタ復帰
  LDX TIMEOUT_STACKPTR
  TXS
  ; 脱出
  CLI
  JMP (TIMEOUT_EXIT_VEC16)
@SET_T1:
  ; T1タイマー設定
  LDA #TIMEOUT_T1H        ; フルの1/4で、8MHz時1ms
  STA VIA::T1CH
  STZ VIA::T1CL
  BRA PL_CLI_RTI          ; 終了
@SKP_T1:

; 不明な割り込みはデバッガへ
DONKI:
  PLY
  PLX
  PLA
  JMP DONKI::ENT_DONKI

; 何もせずに垂直同期割り込みを終える
; デフォルトでVBLANK_USER_VEC16に登録される
VBLANK_STUB:
  LDA VIA::IFR
  AND #%00000001      ; 割り込みフラグを折る
  STA VIA::IFR
  BRA PL_CLI_RTI

; -------------------------------------------------------------------
; BCOS 19             垂直同期割り込みハンドラ登録
; -------------------------------------------------------------------
; input   : AY = ptr
; output  : AY = 垂直同期割り込みスタブルーチン
;                 ルーチンの終わりにジャンプして片付けをやらせたり、
;                 これを登録してハンドラ登録を抹消したりしてよい
; -------------------------------------------------------------------
FUNC_IRQ_SETHNDR_VB:
  storeAY16 VBLANK_USER_VEC16
  loadAY16 IRQ::VBLANK_STUB
  RTS

; -------------------------------------------------------------------
;                     キャラクタ入力割り込み一般
; -------------------------------------------------------------------
; ASCIIを受け取り、制御キーをトラップし、キューに淹れる
; -------------------------------------------------------------------
TRAP:
  CMP #$03
  BNE @SKP_C
  LDX #6
@LOOP:
  PLA
  DEX
  BNE @LOOP
  CLI
  JMP FUNC_RESET
@SKP_C:
ENQ:
  LDX ZP_CONINBF_WR_P     ; バッファの書き込み位置インデックス
  STA CONINBF_BASE,X      ; バッファへ書き込み
  LDX ZP_CONINBF_LEN
  CPX #$BF                ; バッファが3/4超えたら停止を求める
  BCC SKIP_RTSOFF         ; A < M BLT
  prt_xoff                ; バッファがきついのでXoff送信
SKIP_RTSOFF:
  CPX #$FF                ; バッファが完全に限界なら止める
  BNE @SKP_BRK
  BRK
  NOP
@SKP_BRK:
  ; ポインタ増加
  INC ZP_CONINBF_WR_P
  INC ZP_CONINBF_LEN
  RTS

