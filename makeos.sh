# MIRACOS生成専用スクリプト
mkdir ./listing -p
mkdir ./bin/MIRACOS -p
mkdir ./bin/MIRACOS/COM -p
cl65 -g -Wl -Ln,./listing/symbol-bcos.s  -l ./listing/list-bcos.s -m ./listing/map-bcos.s -vm -t none -C ./confcos.cfg -o ./bin/BCOS.SYS ./bcos.s
cl65 -vm -t none -C ./conftpa.cfg -o ./bin/MIRACOS/COM/HELLO.COM ./com/hello.s
rm ./bcos.o
#rm ./ccp.o
objcopy -I binary -O srec --adjust-vma=0x6000 ./bin/BCOS.SYS ./bin/bcos.srec  # バイアスについては要検討
objcopy -I binary -O srec --adjust-vma=0x5000 ./bin/MIRACOS/CCP.SYS ./bin/ccp.srec  # バイアスについては要検討
objcopy -I binary -O srec --adjust-vma=0x0600 ./bin/MIRACOS/SYSCALL.SYS ./bin/syscall.srec  # バイアスについては要検討

cat ./bin/bcos.srec ./bin/ccp.srec | awk '/S1/' | cat - ./bin/syscall.srec | clip.exe

