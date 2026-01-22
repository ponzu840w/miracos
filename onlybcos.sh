# ----------------- MIRACOS生成専用スクリプト ------------------------
ZP_START="0x00"
ZP_END="0x40"
SYSCALLTABLE_START="0x0600"
TPA_START="0x0700"
CCP_START="0x5000"
BCOS_START="0x5300"
NOUSE_START="0x8000"
SEPARATOR="---------------------------------------------------------------------------"

# 一時ディレクトリ
tmpdir=$(mktemp -d)         # 一時ディレクトリ作成
trap "rm -rf $tmpdir" EXIT  # スクリプト終了時に処分

cl65 -g -Wl -Ln,./listing/symbol-bcos.s  -l ./listing/list-bcos.s -m ./listing/map-bcos.s -vm -t none -C ./confcos.cfg -o ${tmpdir}/bcos.sys ./bcos.s
objcopy -I binary -O srec --adjust-vma=$BCOS_START ${tmpdir}/bcos.sys ${tmpdir}/bcos.srec

cat ${tmpdir}/bcos.srec | clip.exe

# 不要なオブジェクトファイル削除
rm ./bcos.o   -f
find ./com/ -name "*.o" | xargs rm -f

