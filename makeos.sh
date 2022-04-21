# MIRACOS生成専用スクリプト
cl65 -l ../listing/miracos/bcos.list -m ../listing/miracos/bcos.map -vm -t none -C ./confcos.cfg -o ./bin/BCOS.SYS ./bcos.s
cl65 -l ../listing/miracos/ccp.list -m ../listing/miracos/ccp.map -vm -t none -C ./confcom.cfg -o ./bin/MIRACOS/CCP.COM ./ccp.s
objcopy -I binary -O srec --adjust-vma=0x6000 ./bin/BCOS.SYS ./bin/bcos.srec  # バイアスについては要検討
objcopy -I binary -O srec --adjust-vma=0x0700 ./bin/MIRACOS/CCP.COM ./bin/ccp.srec  # バイアスについては要検討
objcopy -I binary -O srec --adjust-vma=0x0600 ./bin/MIRACOS/SYSCALL.BIN ./bin/syscall.srec  # バイアスについては要検討

cat ./bin/bcos.srec ./bin/ccp.srec | awk '/S1/' | cat - ./bin/syscall.srec | clip.exe

