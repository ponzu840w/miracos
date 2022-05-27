# ----------------- MIRACOS生成専用スクリプト ------------------------
# 対象ディレクトリ作成
mkdir ./listing -p
mkdir ./bin/MCOS -p
mkdir ./bin/MCOS/COM -p

# BCOSアセンブル
cl65 -g -Wl -Ln,./listing/symbol-bcos.s  -l ./listing/list-bcos.s -m ./listing/map-bcos.s -vm -t none -C ./confcos.cfg -o ./bin/BCOS.SYS ./bcos.s

# コマンドアセンブル
rm ./bin/MCOS/COM/*                 # 古いバイナリを廃棄
com_srcs=$(find ./com/*.s)
for comsrc in $com_srcs;            # com内の.sファイルすべてに対して
do
  echo $comsrc
  bn=$(basename $comsrc .s)         # ファイル名を抽出
  out="./bin/MCOS/COM/"${bn^^}.COM  # 出力ファイルは大文字に
  #echo $out
  cl65 -vm -t none -C ./conftpa.cfg -o $out $comsrc
done

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

# ビルド結果表示
segmentlist=$(cat listing/map-bcos.s | awk 'BEGIN{RS=""}/Seg/' | awk '{print $1 " 0x"$2 " 0x"$3 " 0x"$4}')
echo "$segmentlist"| awk '
  /ZEROPAGE/{printf("System-ZP\t:$%4X-$%4X\t($%4X=%4dB)\n",strtonum($2),strtonum($3),strtonum($4),strtonum($4))}
  /^CODE/{printf("CPP\n\tCODE\t:$%4X-$%4X\t($%4X=%4dB)\n",strtonum($2),strtonum($3),strtonum($4),strtonum($4))}
  /^BSS/{printf("\tVAR\t:$%4X-$%4X\t($%4X=%4dB)\n",strtonum($2),strtonum($3),strtonum($4),strtonum($4))}
  '

echo "$segmentlist" | awk '
  /COSCODE/{printf("BCOS\n\tCODE\t:$%4X-$%4X\t($%4X=%4dB)\n",strtonum($2),strtonum($3),strtonum($4),strtonum($4))}
  /COSLIB/{printf("\tLIB\t:$%4X-$%4X\t($%4X=%4dB)\n",strtonum($2),strtonum($3),strtonum($4),strtonum($4))}
  /COSVAR/{printf("\tVAR\t:$%4X-$%4X\t($%4X=%4dB)\n",strtonum($2),strtonum($3),strtonum($4),strtonum($4))}
  /COSBF100/{printf("\tBUF\t:$%4X-$%4X\t($%4X=%4dB)\n",strtonum($2),strtonum($3),strtonum($4),strtonum($4))}
  '

