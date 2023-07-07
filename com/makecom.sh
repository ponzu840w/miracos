#!/bin/bash

# ----------------- テスト用コマンドアセンブル --------------------

clib="/usr/share/cc65/lib/supervision.lib"

# 引数チェック
if [ $# = 0 ]; then
  echo "使い方：makecom.sh target.s"
  exit 1
fi

# 一時ディレクトリ
td=$(mktemp -d)         # 一時ディレクトリ作成
trap "rm -rf $td" EXIT  # スクリプト終了時に処分

if [ "${1##*.}" = "c" ]; then
  # C言語コンパイル
  cc65 -t none -O --cpu 65c02 -o "${td}/src.s" $1
  ca65 --cpu 65c02 -o "${td}/bcosfunc.o" ../cc/bcosfunc.s   # CMOS命令ありでbcosfunc.sをアセンブル
  ca65 --cpu 65c02 -o "${td}/crt0.o" ../cc/crt0.s           # CMOS命令ありでcrt0.sをアセンブル
  ca65 --cpu 65c02 -I "./" -o "${td}/tmp.o" "${td}/src.s"
  ld65 -vm -C ../cc/conftpa_c.cfg -o "${td}/tmp.com" \
       ${td}/tmp.o ${td}/crt0.o ${td}/bcosfunc.o $clib
else
  # アセンブル
  ca65 -I "./" --cpu 65c02 -o "${td}/tmp.o" $1
  ld65 -C ../conftpa.cfg -o "${td}/tmp.com" "${td}/tmp.o"
fi

# S-REC作成
objcopy -I binary -O srec --adjust-vma=0x0700 "${td}/tmp.com" "${td}/tmp.srec"  # バイアスについては要検討

# クリップボード
cat "${td}/tmp.srec" | clip.exe

