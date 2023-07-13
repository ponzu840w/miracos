#!/bin/bash

lib="/usr/share/cc65/lib/supervision.lib"

# 一時ディレクトリ
td=$(mktemp -d)         # 一時ディレクトリ作成
trap "rm -rf $td" EXIT  # スクリプト終了時に処分

cc65 -t none -O --cpu 65c02 -o "${td}/src.s" $1     # ターゲットなし、CMOS命令ありでコンパイル
cc65 -t none -O --cpu 65c02 -o "${td}/stdio.s" fxt65_stdio.c
ca65 --cpu 65c02 -o "${td}/bcosfunc.o" bcosfunc.s   # CMOS命令ありでbcosfunc.sをアセンブル
ca65 --cpu 65c02 -o "${td}/crt0.o" crt0.s           # CMOS命令ありでcrt0.sをアセンブル
ca65 --cpu 65c02 -o "${td}/src.o" "${td}/src.s"     # コンパイラの吐いたプログラム本体をアセンブル
ca65 --cpu 65c02 -o "${td}/stdio.o" "${td}/stdio.s"     # コンパイラの吐いたプログラム本体をアセンブル
ld65 -C conftpa_c.cfg -o "${td}/a.out" ${td}/*.o "${lib}"  # これらオブジェクトコードをライブラリと結合してリンク

# S-REC作成
objcopy -I binary -O srec --adjust-vma=0x0700 "${td}/a.out" "${td}/a.srec"  # バイアスについては要検討

# クリップボード
cat "${td}/a.srec" | clip.exe

