# Makefile

# 変数定義
PNG_FILE = misaki_mincho.png
BMP_FILE = misaki_mincho.bmp
BIN_FILE = ../bin/MCOS/DAT/MSKMSJIS.FNT
SERIALIZER_SRC = glyph_serializer.c
SERIALIZER_EXE = glyph_serializer

# ルール
all: $(BIN_FILE)

# .png から .bmp に変換
$(BMP_FILE): $(PNG_FILE)
	convert $(PNG_FILE) -flip bmp3:$(BMP_FILE)

# glyph_serializer.c のコンパイル
$(SERIALIZER_EXE): $(SERIALIZER_SRC)
	gcc $(SERIALIZER_SRC) -o $(SERIALIZER_EXE)

# 必要なディレクトリを作成
$(BIN_FILE): | $(dir $(BIN_FILE))

$(dir $(BIN_FILE)):
	mkdir -p $(dir $(BIN_FILE))

# .bmp から .bin に変換
$(BIN_FILE): $(BMP_FILE) $(SERIALIZER_EXE)
	./$(SERIALIZER_EXE) $(BMP_FILE) $(BIN_FILE)

# クリーンアップ
clean:
	rm -f $(BMP_FILE) $(SERIALIZER_EXE) $(BIN_FILE)

.PHONY: all clean
