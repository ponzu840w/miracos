# MIRACOS生成専用スクリプト
cl65 -l ../listing/miracos/bcos.list -m ../listing/miracos/bcos.map -vm -t none -C ./confcos.cfg -o ./bin/BCOS.SYS ./bcos.s
objcopy -I binary -O srec --adjust-vma=0x6000 ./bin/BCOS.SYS ./bin/bcos.srec  # バイアスについては要検討
objcopy -I binary -O srec --adjust-vma=0x5000 ./bin/MIRACOS/CCP.SYS ./bin/ccp.srec  # バイアスについては要検討
objcopy -I binary -O srec --adjust-vma=0x0600 ./bin/MIRACOS/SYSCALL.SYS ./bin/syscall.srec  # バイアスについては要検討

cat ./bin/bcos.srec ./bin/ccp.srec | awk '/S1/' | cat - ./bin/syscall.srec | clip.exe

