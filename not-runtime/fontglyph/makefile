# Makefile

# 変数定義
PNG_FILE = misaki_mincho.png
BMP_FILE = misaki_mincho.bmp
JIS_FILE = misaki_mincho.bin
OUT_FILE = ../../bin/MCOS/DAT/MSKMSJIS.FNT
SERIALIZER_SRC = glyph_serializer.c
SERIALIZER_EXE = glyph_serializer
JIS_REMAP_SRC = jis-remap.c
JIS_REMAP_EXE = jis-remap

# ルール
all: $(OUT_FILE)

# .png から .bmp に変換
$(BMP_FILE): $(PNG_FILE)
	convert $(PNG_FILE) -flip bmp3:$(BMP_FILE)

# glyph_serializer.c のコンパイル
$(SERIALIZER_EXE): $(SERIALIZER_SRC)
	gcc $(SERIALIZER_SRC) -o $(SERIALIZER_EXE)

# .bmp から .bin に変換
$(JIS_FILE): $(BMP_FILE) $(SERIALIZER_EXE)
	./$(SERIALIZER_EXE) $(BMP_FILE) $(JIS_FILE)

# jis-remap.c のコンパイル
$(JIS_REMAP_EXE): $(JIS_REMAP_SRC)
	gcc $(JIS_REMAP_SRC) -o $(JIS_REMAP_EXE)

# 必要なディレクトリを作成
$(OUT_FILE): | $(dir $(OUT_FILE))

$(dir $(OUT_FILE)):
	mkdir -p $(dir $(OUT_FILE))

# .bin から .fnt に変換
$(OUT_FILE): $(JIS_FILE) $(JIS_REMAP_EXE)
	./$(JIS_REMAP_EXE) $(JIS_FILE) $(OUT_FILE)

# クリーンアップ
clean:
#	rm -f $(BMP_FILE) $(SERIALIZER_EXE) $(JIS_FILE) $(OUT_FILE)

.PHONY: all clean
