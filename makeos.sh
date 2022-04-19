# MIRACOS生成専用スクリプト
cl65 -l ../listing/miracos/bcos.list -m ../listing/miracos/bcos.map -vm -t none -C ./confcos.cfg -o ./bin/bcos.bin ./bcos.s
objcopy -I binary -O srec --adjust-vma=0x0600 ./bin/bcos.bin ./bin/bcos.srec  # バイアスについては要検討

cat ./bin/bcos.srec | clip.exe

