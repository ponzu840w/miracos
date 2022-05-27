# ----------------- MIRACOS生成専用スクリプト ------------------------
SYSCALLTABLE_START="0x0600"
TPA_START="0x0700"
CCP_START="0x5000"
BCOS_START="0x6000"
BCOS_END="0x7FFF"
SEPARATOR="---------------------------------------------------------------------------"

# 対象ディレクトリ作成
mkdir ./listing -p
mkdir ./listing/com -p
mkdir ./bin/MCOS -p
mkdir ./bin/MCOS/COM -p

# BCOSアセンブル
cl65 -g -Wl -Ln,./listing/symbol-bcos.s  -l ./listing/list-bcos.s -m ./listing/map-bcos.s -vm -t none -C ./confcos.cfg -o ./bin/BCOS.SYS ./bcos.s

# コマンドアセンブル
rm ./bin/MCOS/COM/*                 # 古いバイナリを廃棄
com_srcs=$(find ./com/*.s)
for comsrc in $com_srcs;            # com内の.sファイルすべてに対して
do
  #echo $comsrc
  bn=$(basename $comsrc .s)         # ファイル名を抽出
  out="./bin/MCOS/COM/"${bn^^}.COM  # 出力ファイルは大文字に
  cl65 -m ./listing/com/${bn}.map -vm -t none -C ./conftpa.cfg -o $out $comsrc
  cat ./listing/com/${bn}.map |
    awk 'BEGIN{RS=""}/Seg/' | awk '{print $1 " 0x"$2 " 0x"$3 " 0x"$4}' |
    awk -v name="COM/"${bn^^}.COM -v tpa=$TPA_START -v ccp=$CCP_START '
    /^ZEROPAGE/{ zp=strtonum($4) }
    /^CODE|^BSS|^DATA/{
      size=size+strtonum($4)
    }
    END{
      zpp=zp/(0x100-0x40)
      sizep=size/(strtonum(ccp)-strtonum(tpa))
      printf("%16-s\tZP:$%2X(%2.1f%%)\tTPA:$%4X = %2.3fK (%2.1f%%)\n",name,zp,zpp*100,size,size/1000,sizep*100)
    }
  '
done

# 不要なオブジェクトファイル削除
rm ./bcos.o
rm ./com/*.o
#rm ./ccp.o

# S-REC作成
objcopy -I binary -O srec --adjust-vma=$BCOS_START ./bin/BCOS.SYS ./bin/bcos.srec  # バイアスについては要検討
objcopy -I binary -O srec --adjust-vma=$CCP_START ./bin/MCOS/CCP.SYS ./bin/ccp.srec  # バイアスについては要検討
objcopy -I binary -O srec --adjust-vma=$SYSCALLTABLE_START ./bin/MCOS/SYSCALL.SYS ./bin/syscall.srec  # バイアスについては要検討

# クリップボードに合成
cat ./bin/bcos.srec ./bin/ccp.srec | awk '/S1/' | cat - ./bin/syscall.srec | clip.exe

# ビルド結果表示
segmentlist=$(cat listing/map-bcos.s | awk 'BEGIN{RS=""}/Seg/' | awk '{print $1 " 0x"$2 " 0x"$3 " 0x"$4}')
# ゼロページ
echo $SEPARATOR
echo "$segmentlist"| awk '
  /ZEROPAGE/{printf("[System-ZP]\t$%4X...$%4X\t($%4X = %2.3fK)\n",strtonum($2),strtonum($3),strtonum($4),strtonum($4)/1000)
    size=strtonum($4)
    area=0x40
    free=area-size
    use=size/area
    printf("-\n")
    printf("USAGE\t$%4X / $%4X\t(%2.2f%%)\n",size,area,use*100)
    printf("FREE\t$%4X = %2.3fK\n",free,free/1000)
  }
  '
# CCP
echo $SEPARATOR
echo "$segmentlist"| awk -v start=$CCP_START -v end=$BCOS_START '
BEGIN{printf("[CCP.SYS]\n")}
  /^CODE/{
    printf("\tCODE\t$%4X...$%4X\t($%4X = %2.3fK)\n",strtonum($2),strtonum($3),strtonum($4),strtonum($4)/1000)
    size=strtonum($4)
  }
  /^BSS/{
    printf("\tVAR\t$%4X...$%4X\t($%4X = %2.3fK)\n",strtonum($2),strtonum($3),strtonum($4),strtonum($4)/1000)
    size=size+strtonum($4)
  }
  END{
    area=strtonum(end)-strtonum(start)
    use=size/area
    free=area-size
    freep=free/area
    printf("-\n")
    printf("USAGE\t$%4X / $%4X\t(%2.2f%%)\n",size,area,use*100)
    printf("FREE\t$%4X = %2.3fK\n",free,free/1000,freep*100)
  }
'
# BCOS
echo $SEPARATOR
echo "$segmentlist" | awk -v start=$BCOS_START -v end=$BCOS_END '
  BEGIN{printf("[BCOS.SYS]\n")}
  /COSCODE/{
    printf("\tCODE\t$%4X...$%4X\t($%4X = %2.3fK)\n",strtonum($2),strtonum($3),strtonum($4),strtonum($4)/1000)
    size=size+strtonum($4)
  }
  /COSLIB/{
    printf("\tLIB\t$%4X...$%4X\t($%4X = %2.3fK)\n",strtonum($2),strtonum($3),strtonum($4),strtonum($4)/1000)
    size=size+strtonum($4)
  }
  /COSVAR/{
    printf("\tVAR\t$%4X...$%4X\t($%4X = %2.3fK)\n",strtonum($2),strtonum($3),strtonum($4),strtonum($4)/1000)
    size=size+strtonum($4)
  }
  /COSBF100/{
    printf("\tBUF\t$%4X...$%4X\t($%4X = %2.3fK)\n",strtonum($2),strtonum($3),strtonum($4),strtonum($4)/1000)
    size=size+strtonum($4)
  }
  END{
    area=strtonum(end)-strtonum(start)+1
    use=size/area
    free=area-size
    freep=free/area
    printf("-\n")
    printf("USAGE\t$%4X / $%4X\t(%2.2f%%)\n",size,area,use*100)
    printf("FREE\t$%4X = %2.3fK\n",free,free/1000,freep*100)
  }
'

