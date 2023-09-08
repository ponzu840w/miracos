; -------------------------------------------------------------------
;                           bcosfunc.s
; -------------------------------------------------------------------
; BCOS関数へのラッパ関数群
; -------------------------------------------------------------------
.proc BCOS                  ; Basic Card Operating System（カーネル）
.include "../syscall.inc"   ; システムコール番号を定義するインクルードファイル
  ; --- 一部抜粋 ---
  ;; コール場所
  ;SYSCALL             = $0603
  ;; システムコールテーブル
  ;RESET               = 0
  ;CON_IN_CHR          = 1
  ;CON_OUT_CHR         = 2
  ;CON_RAWIN           = 3
  ;CON_OUT_STR         = 4
  ;FS_OPEN             = 5
  ;FS_CLOSE            = 6
  ;CON_IN_STR          = 7
  ; --- 抜粋ここまで ---
.include "../syscall.mac"   ; 普段使ってるマクロ
.endproc

.IMPORT popa, popax
.IMPORTZP sreg


; Cから呼び出せる関数名を宣言
.export _coutc
.export _couts
.export _cins
.export _fs_find_fst
.export _fs_find_nxt

.CODE

; -------------------------------------------------------------------
;                              coutc
; -------------------------------------------------------------------
.proc _coutc                      ; 引数: A=char
  syscall CON_OUT_CHR
  rts
.endproc

; -------------------------------------------------------------------
;                              couts
; -------------------------------------------------------------------
.proc _couts: near                ; C関数引数:  AX=文字列先頭アドレス
                                  ;                 これがnearらしい
  PHX                             ; 「TXY」
  PLY                             ; Xはコールで使うし、AYで渡したい
  ;syscall CON_OUT_STR            ; 普段使っているマクロではこう表記
  ; --- マクロの中身 ---          ; システムコール引数: AY=文字列先頭アドレス
  LDX #(BCOS::CON_OUT_STR)*2      ; Xにコール番号の二倍を格納
  JSR BCOS::SYSCALL               ; コール
  ; --- マクロここまで ---
  rts                             ; 復帰
.endproc

; -------------------------------------------------------------------
;                              cins
; -------------------------------------------------------------------
.proc _cins: near                  ; 引数: A=格納先アドレス
  PHX
  PLY
  syscall CON_IN_STR
  rts
.endproc

; -------------------------------------------------------------------
;                            fs_find_fst
; パス文字列から新たなFINFO構造体を得る
; -------------------------------------------------------------------
.proc _fs_find_fst: near          ; 引数: AX=パス文字列
  PHX
  PLY
  syscall FS_FIND_FST
  PHY
  PLX
  RTS
.endproc

; -------------------------------------------------------------------
;                            fs_find_nxt
; -------------------------------------------------------------------
; void* fs_find_nxt(void* finfo, char* name)
.proc _fs_find_nxt: near          ; 引数: AX=ファイル名, スタック=FINFO
  STA $0
  STX $0+1
  JSR popax
  PHX
  PLY
  syscall FS_FIND_NXT             ; 引数: AY=FINFO構造体 ZR0=ファイル名
  PHY
  PLX
  RTS
.endproc

