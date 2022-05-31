# ----------------- テスト用コマンドアセンブル --------------------
# 引数チェック
if [ $# = 0 ]; then
  echo "使い方：makecom.sh target.s"
  exit 1
fi

# コマンドアセンブル
cl65 -Wa -I,"./" -vm -t none -C ../conftpa.cfg -o tmp.com $1

# 不要なオブジェクトファイル削除
find | grep .o$ | xargs rm

# S-REC作成
objcopy -I binary -O srec --adjust-vma=0x0700 ./tmp.com ./tmp.srec  # バイアスについては要検討

# クリップボード
cat ./tmp.srec | clip.exe

# 不要なsrecを削除
rm ./tmp.com
rm ./tmp.srec

