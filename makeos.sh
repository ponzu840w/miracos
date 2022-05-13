# ----------------- MIRACOS生成専用スクリプト ------------------------
# 対象ディレクトリ作成
mkdir ./listing -p
mkdir ./bin/MCOS -p
mkdir ./bin/MCOS/COM -p

# アセンブル
cl65 -g -Wl -Ln,./listing/symbol-bcos.s  -l ./listing/list-bcos.s -m ./listing/map-bcos.s -vm -t none -C ./confcos.cfg -o ./bin/BCOS.SYS ./bcos.s
cl65 -vm -t none -C ./conftpa.cfg -o ./bin/MCOS/COM/HELLO.COM ./com/hello.s

# 不要なオブジェクトファイル削除
rm ./bcos.o
rm ./com/*.o
#rm ./ccp.o

# S-REC作成
objcopy -I binary -O srec --adjust-vma=0x6000 ./bin/BCOS.SYS ./bin/bcos.srec  # バイアスについては要検討
objcopy -I binary -O srec --adjust-vma=0x5000 ./bin/MCOS/CCP.SYS ./bin/ccp.srec  # バイアスについては要検討
objcopy -I binary -O srec --adjust-vma=0x0600 ./bin/MCOS/SYSCALL.SYS ./bin/syscall.srec  # バイアスについては要検討

# クリップボードに合成
cat ./bin/bcos.srec ./bin/ccp.srec | awk '/S1/' | cat - ./bin/syscall.srec | clip.exe

