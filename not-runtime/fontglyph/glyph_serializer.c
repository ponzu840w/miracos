/*
 * BMPv3画像形式のフォントグリフを素直なシリアルデータにする
 * Linux用
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <stdbool.h>

#define GLYPH_WIDTH 8
#define GLYPH_HEIGHT 8

int readFileHeader(FILE * fp, int opt_verbose, long *bmp_img_offset);
int readInfoHeader(FILE * fp,  int opt_verbose, int *width, int *height);

FILE  *src_fileptr, *dst_fileptr;          // 入出力のファイルポインタ

int main(int argc, char *argv[])
{
  // 変数宣言
  char  src_name[100], dst_name[100];       // ファイル名
  int   width, height, padding;             // 画像の寸法
  long  bmp_img_offset;                     // 画像データのオフセット
  int   lines_max, rows_max;                // キャラクタの行・列
  unsigned char bytedata;                   // バイトデータ
  int opt;                                  // コマンドラインオプション処理用
  bool opt_verbose = false;                 // 冗長メッセージ

  // オプション処理
  while ((opt=getopt(argc,argv,"v"))!=-1){  // ハイフンオプションを取得
    switch(opt){
      case 'v':
        opt_verbose = true;                 // 詳細メッセージ
        break;
      default:
      return EXIT_FAILURE;
    }

  }

  if(opt_verbose)fprintf(stderr, "BMPv3 1bit font glyph image -> Serial font glyph bin Converter.\n");

  // ファイル名取得
  sprintf(src_name, "%s", argv[optind]);     // ソースBMPのファイル名を取得
  sprintf(dst_name, "%s", argv[optind+1]);   // 出力先のファイル名を取得

  // 入力ファイルをオープン
  if((src_fileptr=fopen(src_name, "rb"))==NULL){
    fprintf(stderr, "File_Open_Error: %s\n", src_name) ;
    return EXIT_FAILURE;
  }
  // 出力ファイルをオープン
  if((dst_fileptr=fopen(dst_name, "wb"))==NULL){
    fprintf(stderr, "File_Open_Error: %s\n", dst_name) ;
    fclose(src_fileptr);
    return EXIT_FAILURE;
  }

  // ファイルヘッダ取得
  if(readFileHeader(src_fileptr, opt_verbose, &bmp_img_offset))
    fprintf(stderr,"Read_BITMAPFILEHEADER_Error\n");
  // 情報ヘッダ取得
  if(readInfoHeader(src_fileptr, opt_verbose, &width, &height))
    fprintf(stderr,"Read_BITMAPINFOHEADER_Error\n");
  // 画像寸法
  if(opt_verbose)fprintf(stderr, "Image_Size：%d(H)×%d(V)\n", width, height);
  // BMPのパディングの大きさを算出
  padding=4-((width/8)%4);
  if(padding==4)padding=0;
  if(opt_verbose)fprintf(stderr, "Padding: %d [Bytes]\n", padding);
  // グリフの配列を確認
  if(width%GLYPH_WIDTH)fprintf(stderr, "グリフ幅不適合（%d/%d!=0）\n",width,GLYPH_WIDTH);
  if(height%GLYPH_HEIGHT)fprintf(stderr, "グリフ高不適合（%d/%d!=0）\n",height,GLYPH_HEIGHT);
  rows_max = width / 8;
  lines_max = height / 8;
  if(opt_verbose){
    fprintf(stderr, "%d列%d行のグリフを変換します。\n",rows_max,lines_max);
    fprintf(stderr, "1バイト読み込みごとに%dバイト進む\n",rows_max-1+padding);
    fprintf(stderr, "行内の次の文字へは%dバイト戻る\n",(rows_max+padding)*(GLYPH_HEIGHT-1));
  }

  // BMPファイルの画像データまでシーク
  fseek(src_fileptr, bmp_img_offset, SEEK_SET);

  // グリフの行ループ
  for(int line=0; line<lines_max; line++){
    // グリフの列ループ
    for(int row=0; row<rows_max; row++){
      // グリフ内ループ
      for(int i=0; i<GLYPH_HEIGHT; i++){
        /* 1バイト読み込み */
        if(fread(&bytedata, sizeof(bytedata), 1, src_fileptr) != 1){
          fprintf(stderr, "SRC_Read_Error@ row=%d, line=%d\n", row, line);
          return EXIT_FAILURE;
        }
        /* bit反転 */
        bytedata = ~bytedata;
        /* 1バイト書き込み */
        if(fwrite(&bytedata, sizeof(bytedata), 1, dst_fileptr) != 1){
          fprintf(stderr, "DST_Write_Error@ row=%d, line=%d\n", row, line);
          return EXIT_FAILURE;
        }
        if(i<GLYPH_WIDTH-1)
          fseek(src_fileptr, rows_max-1+padding, SEEK_CUR);
      }
      if(row<rows_max-1)
        fseek(src_fileptr, -((rows_max+padding)*(GLYPH_HEIGHT-1)), SEEK_CUR);
    }
    // 行末パディングのスキップ
    fseek(src_fileptr, padding, SEEK_CUR);
  }

  return EXIT_SUCCESS;
}

int readFileHeader(FILE *fp, int opt_verbose, long *bmp_img_offset)
{
  int   tmp_long;
  short tmp_short;
  char  s[10];

  // BMPシグネチャ "BM"
  if (fread(s, 2, 1, fp) == 1){
    if (memcmp(s, "BM", 2) != 0){
      fprintf(stderr, "%s : Not a BMP file\n", s);
      return EXIT_FAILURE;
    }
  }
  if(opt_verbose)fprintf(stderr, "BITMAPFILEHEADER\n");

  // ファイルサイズ
  if(fread(&tmp_long, sizeof(tmp_long), 1, fp) != 1)return EXIT_FAILURE;
  if(opt_verbose)fprintf(stderr, "  Size          : %d [Byte]\n", tmp_long);
  // 予約領域
  if(fread(&tmp_short, sizeof(tmp_short), 2, fp) != 2)return EXIT_FAILURE;

  // ファイルの先頭から画像データまでの位置
  if(fread(&tmp_long, sizeof(tmp_long), 1, fp) != 1)return EXIT_FAILURE;
  if(opt_verbose)fprintf(stderr, "  OffBits       : %d [Byte]\n", tmp_long);
  *bmp_img_offset = tmp_long;

  return EXIT_SUCCESS;
}

int readInfoHeader(FILE *fp, int opt_verbose, int *width, int *height)
{
  int           tmp_long;
  short         tmp_short;
  unsigned char tmp_char[4];

  // BITMAPINFOHEADER のサイズ
  // Windows BMPファイルのみ受付
  if(fread(&tmp_long, sizeof(tmp_long), 1, fp) != 1)return EXIT_FAILURE;
  if(tmp_long != 40){
    fprintf(stderr, "Not a Windows BMP file\n");
    return EXIT_FAILURE;
  }

  if(opt_verbose)fprintf(stderr, "BITMAPINFOHEADER\n");
  // Windows BMP
  // 画像データの幅
  if(fread(&tmp_long, sizeof(tmp_long), 1, fp) != 1)return EXIT_FAILURE;
  if(opt_verbose)fprintf(stderr, "  Width         : %d [pixel]\n", tmp_long);
  *width = tmp_long;
  // 画像データの高さ
  if(fread(&tmp_long, sizeof(tmp_long), 1, fp) != 1)return EXIT_FAILURE;
  if(opt_verbose)fprintf(stderr, "  Height        : %d [pixel]\n", tmp_long);
  *height = tmp_long;
  // プレーン数 (1のみ)
  if(fread(&tmp_short, sizeof(tmp_short), 1, fp) != 1)return EXIT_FAILURE;
  // 1画素あたりのビット数 (1, 4, 8, 24, 32)
  // 4ビットカラーのみ受付
  if(fread(&tmp_short, sizeof(tmp_short), 1, fp) != 1)return EXIT_FAILURE;
  if(opt_verbose)fprintf(stderr, "  BitCount      : %d [bit]\n", tmp_short);
  if(tmp_short != 1){
    fprintf(stderr, "1bitカラーではありません\n");
    return EXIT_FAILURE;
  }
  /*
   * 圧縮方式  0 : 無圧縮
   *           1 : BI_RLE8 8bit RunLength 圧縮
   *           2 : BI_RLE4 4bit RunLength 圧縮
   */
  if(fread(&tmp_long, sizeof(tmp_long), 1, fp) != 1)return EXIT_FAILURE;
  if(opt_verbose)fprintf(stderr, "  Compression   : %d\n", tmp_long);
  if(tmp_long != 0){
    fprintf(stderr, "非圧縮モードではありません\n");
    return EXIT_FAILURE;
  }
  // 画像データのサイズ
  if(fread(&tmp_long, sizeof(tmp_long), 1, fp) != 1)return EXIT_FAILURE;
  if(opt_verbose)fprintf(stderr, "  SizeImage     : %d [Byte]\n", tmp_long);
  // 横方向解像度 (Pixel/meter)
  if(fread(&tmp_long, sizeof(tmp_long), 1, fp) != 1)return EXIT_FAILURE;
  if(opt_verbose)fprintf(stderr, "  XPelsPerMeter : %d [pixel/m]\n", tmp_long);
  // 縦方向解像度 (Pixel/meter)
  if(fread(&tmp_long, sizeof(tmp_long), 1, fp) != 1)return EXIT_FAILURE;
  if(opt_verbose)fprintf(stderr, "  YPelsPerMeter : %d [pixel/m]\n", tmp_long);
  // 使用色数
  if(fread(&tmp_long, sizeof(tmp_long), 1, fp) != 1)return EXIT_FAILURE;
  if(opt_verbose)fprintf(stderr, "  ClrUsed       : %d [color]\n", tmp_long);

  // 重要な色の数 0の場合すべての色
  if(fread(&tmp_long, sizeof(tmp_long), 1, fp) != 1)return EXIT_FAILURE;

 return EXIT_SUCCESS;
}
