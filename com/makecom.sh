#!/bin/bash

# ----------------- テスト用コマンドアセンブル --------------------

# 引数チェック
if [ $# = 0 ]; then
  echo "使い方：makecom.sh target.s"
  exit 1
fi

# C言語ソースは別処理
if [ "${1##*.}" = "c" ]; then
  cd ../cc
  ./make.sh "../com/$1"
  exit 1
fi

# 一時ディレクトリ
td=$(mktemp -d)         # 一時ディレクトリ作成
trap "rm -rf $td" EXIT  # スクリプト終了時に処分

# コマンドアセンブル
#cl65 -Wa -I,"./" -vm -t none -C ../conftpa.cfg -o "${td}/tmp.com" $1
ca65 -I "./" --cpu 65c02 -o "${td}/tmp.o" $1
ld65 -C ../conftpa.cfg -o "${td}/tmp.com" "${td}/tmp.o"

# S-REC作成
objcopy -I binary -O srec --adjust-vma=0x0700 "${td}/tmp.com" "${td}/tmp.srec"  # バイアスについては要検討

# クリップボード
cat "${td}/tmp.srec" | clip.exe

