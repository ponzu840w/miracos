# ----------------- MIRACOS生成専用スクリプト ------------------------
ZP_START="0x00"
ZP_END="0x40"
SYSCALLTABLE_START="0x0600"
TPA_START="0x0700"
CCP_START="0x5000"
BCOS_START="0x6000"
NOUSE_START="0x8000"
SEPARATOR="---------------------------------------------------------------------------"

# --- 簡略化関数群
# initmessageを出力する
# $1でビルドの種類を指定できる
function writeInitMessage () {
  echo ".BYT \"MIRACOS $version for FxT-65\",10,\"$(printf "%32s" "(build [$commit]${date}$1)")\",0" > initmessage.s
}

# 一時ディレクトリ
tmpdir=$(mktemp -d)         # 一時ディレクトリ作成
trap "rm -rf $tmpdir" EXIT  # スクリプト終了時に処分

version=$(git describe --abbrev=0 --tags)
commit=$(git rev-parse HEAD | cut -c1-6 | tr -d "\n")
date=$(date '+%Y %m%d-%H%M' | awk '{print "R"$1-2018$2}')

# 対象ディレクトリ作成
mkdir ./listing -p
mkdir ./bin/MCOS -p

# S-REC作成
writeInitMessage t          # テストビルドであることを明示
cl65 -Wa -D,SRECBUILD=1 -vm -t none -C ./confcos.cfg -o ${tmpdir}/bcos.sys ./bcos.s # SRECビルドモードで再ビルド
objcopy -I binary -O srec --adjust-vma=$BCOS_START ${tmpdir}/bcos.sys ${tmpdir}/bcos.srec
objcopy -I binary -O srec --adjust-vma=$CCP_START ./bin/MCOS/CCP.SYS ${tmpdir}/ccp.srec
objcopy -I binary -O srec --adjust-vma=$SYSCALLTABLE_START ./bin/MCOS/SYSCALL.SYS ${tmpdir}/syscall.srec
cat ${tmpdir}/bcos.srec ${tmpdir}/ccp.srec | awk '/S1/' | cat - ${tmpdir}/syscall.srec | clip.exe # クリップボードに合成

# リリースBCOSアセンブル
writeInitMessage r        # リリースビルド
cl65 -g -Wl -Ln,./listing/symbol-bcos.s  -l ./listing/list-bcos.s -m ./listing/map-bcos.s -vm -t none -C ./confcos.cfg -o ./bin/BCOS.SYS ./bcos.s

# コマンドアセンブル
rm ./bin/MCOS/COM/* -fr                 # 古いバイナリを廃棄
# ディレクトリが優先されるようにソートしつつソースのリストを作成
#com_srcs=$(find ./com/* | awk '/\.s$/{"dirname "$0""|getline var;printf("%s %s\n",var,$0)}' | sort | awk '{print $2}')
com_srcs=$(find ./com/*.s;find ./com/test/*.s)
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
  cl65 -g -Wl -Ln,./listing/${dn}/s-${bn}.s -l ./listing/${dn}/l-${bn}.s -Wa -I,"./com/" -m ./listing/${dn}/${bn}.map -vm -t none -C ./conftpa.cfg -o $out $comsrc
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

# ----------------- ビルド結果の表示 ------------------------
# awkコマンドの共通部分
cat - << EOS > ${tmpdir}/awkcom
  END{
    area=strtonum(end)-strtonum(start)
    use=size/area
    free=area-size
    freep=free/area
    printf("-\n")
    printf("USAGE\t$%4X / $%4X\t(%2.2f%%)\n",size,area,use*100)
    printf("FREE\t$%4X = %2.3fK\n",free,free/1000,freep*100)
  }
  function line(name, from, to, siz){
    printf("\t%s\t$%4X...$%4X\t($%4X = %2.3fK)\n",name,strtonum(from),strtonum(to),strtonum(siz),strtonum(siz)/1000)
    size=size+strtonum(siz)
  }
EOS

# セグメントのリストを取得
segmentlist=$(cat listing/map-bcos.s | awk 'BEGIN{RS=""}/Seg/' | awk '{print $1 " 0x"$2 " 0x"$3 " 0x"$4}')

# ゼロページ
echo $SEPARATOR
cat - << EOS > ${tmpdir}/awkcom_zp
  BEGIN{printf("[System-ZP]\n")}
  /ZEROPAGE/ { line("ZP", \$2, \$3, \$4) }
EOS
echo "$segmentlist"| awk -v start=$ZP_START -v end=$ZP_END -f ${tmpdir}/awkcom -f ${tmpdir}/awkcom_zp

# CCP
echo $SEPARATOR
cat - << EOS > ${tmpdir}/awkcom_ccp
  BEGIN{printf("[CCP.SYS]\n")}
  /^CODE/ { line("CODE", \$2, \$3, \$4) }
  /^BSS/ { line("VAR", \$2, \$3, \$4) }
EOS
echo "$segmentlist"| awk -v start=$CCP_START -v end=$BCOS_START -f ${tmpdir}/awkcom -f ${tmpdir}/awkcom_ccp

# BCOS
echo $SEPARATOR
cat - << EOS > ${tmpdir}/awkcom_bcos
  BEGIN{printf("[BCOS.SYS]\n")}
  /COSCODE/ { line("CODE", \$2, \$3, \$4) }
  /COSLIB/  { line("LIB", \$2, \$3, \$4) }
  /COSVAR/  { line("VAR", \$2, \$3, \$4) }
  /COSBF100/{ line("BUF", \$2, \$3, \$4) }
EOS
echo "$segmentlist" | awk -v start=$BCOS_START -v end=$NOUSE_START -f ${tmpdir}/awkcom -f ${tmpdir}/awkcom_bcos

