cc65 -t none -O --cpu 65c02 $1
ca65 --cpu 65c02 bcosfunc.s
ca65 --cpu 65c02 crt0.s
ca65 --cpu 65c02 $(basename $1 .c).s
ld65 -C conftpa_c.cfg *.o fxt.lib

# 不要なオブジェクトファイル削除
rm ./*.o

# S-REC作成
objcopy -I binary -O srec --adjust-vma=0x0700 ./a.out ./tmp.srec  # バイアスについては要検討

# クリップボード
cat ./tmp.srec | clip.exe

# 不要なsrecを削除
rm ./tmp.srec

