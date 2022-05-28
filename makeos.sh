# ----------------- MIRACOS生成専用スクリプト ------------------------
SYSCALLTABLE_START="0x0600"
TPA_START="0x0700"
CCP_START="0x5000"
BCOS_START="0x6000"
BCOS_END="0x7FFF"
SEPARATOR="---------------------------------------------------------------------------"

version=$(git describe --abbrev=0 --tags)
commit=$(git rev-parse HEAD | cut -c1-6 | tr -d "\n")
date=$(date '+%Y %m%d-%H%M' | awk '{print "R"$1-2018$2}')
echo ".BYT \"MIRACOS $version for FxT-65\",10,\"$(printf "%32s" "(build [$commit]${date}t)")\",10,0" > initmessage.txt

# 対象ディレクトリ作成
mkdir ./listing -p
mkdir ./bin/MCOS -p

# S-REC作成
tmpdir=$(mktemp -d)         # 一時ディレクトリ作成
trap "rm -rf $tmpdir" EXIT  # スクリプト終了時に処分
cl65 -Wa -D,SRECBUILD=1 -vm -t none -C ./confcos.cfg -o ${tmpdir}/bcos.sys ./bcos.s # SRECビルドモードで再ビルド
objcopy -I binary -O srec --adjust-vma=$BCOS_START ${tmpdir}/bcos.sys ${tmpdir}/bcos.srec
objcopy -I binary -O srec --adjust-vma=$CCP_START ./bin/MCOS/CCP.SYS ${tmpdir}/ccp.srec
objcopy -I binary -O srec --adjust-vma=$SYSCALLTABLE_START ./bin/MCOS/SYSCALL.SYS ${tmpdir}/syscall.srec
cat ${tmpdir}/bcos.srec ${tmpdir}/ccp.srec | awk '/S1/' | cat - ${tmpdir}/syscall.srec | clip.exe # クリップボードに合成

# リリースBCOSアセンブル
echo ".BYT \"MIRACOS $version for FxT-65\",10,\"$(printf "%32s" "(build [$commit]${date}r)")\",10,0" > initmessage.txt
cl65 -g -Wl -Ln,./listing/symbol-bcos.s  -l ./listing/list-bcos.s -m ./listing/map-bcos.s -vm -t none -C ./confcos.cfg -o ./bin/BCOS.SYS ./bcos.s

# コマンドアセンブル
rm ./bin/MCOS/COM/* -fr                 # 古いバイナリを廃棄
# ディレクトリが優先されるようにソートしつつソースのリストを作成
com_srcs=$(find ./com/* | awk '/\.s$/{"dirname "$0""|getline var;printf("%s %s\n",var,$0)}' | sort | awk '{print $2}')
#echo "$com_srcs"
predir=""                               # 表示をすっきりさせるためのディレクトリ移動ディテクタ
for comsrc in $com_srcs;                # com内の.sファイルすべてに対して
do
  nam=$(echo $comsrc | cut -c 3-)       # ./を無視
  dn=$(dirname $nam)                    # com/ あるいはcom/testなどディレクトリ部
  bn=$(basename $nam .s)                # ファイル名を抽出
  out="./bin/MCOS/"${dn^^}/${bn^^}.COM  # 出力ファイルは大文字に
  #echo $nam $dn $bn $out
  if [[ "$predir" != "$dn" ]]; then
    echo ${dn^^}
    predir=$dn
  fi
  mkdir ./listing/${dn} -p
  mkdir ./bin/MCOS/${dn^^} -p
  cl65 -Wa -I,"./com/" -m ./listing/${dn}/${bn}.map -vm -t none -C ./conftpa.cfg -o $out $comsrc
  cat ./listing/${dn}/${bn}.map |
    awk 'BEGIN{RS=""}/Seg/' | awk '{print $1 " 0x"$2 " 0x"$3 " 0x"$4}' |
    awk -v name=${bn^^}.COM -v tpa=$TPA_START -v ccp=$CCP_START '
    /^ZEROPAGE/{ zp=strtonum($4) }
    /^CODE|^BSS|^DATA/{
      size=size+strtonum($4)
    }
    END{
      zpp=zp/(0x100-0x40)
      sizep=size/(strtonum(ccp)-strtonum(tpa))
      printf("\t%16-s\tZP:$%2X(%2.1f%%)\tTPA:$%4X = %2.3fK (%2.1f%%)\n",name,zp,zpp*100,size,size/1000,sizep*100)
    }
  '
done

# 不要なオブジェクトファイル削除
rm ./bcos.o   -f
find ./com/ -name "*.o" | xargs rm -f
#rm ./ccp.o

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

