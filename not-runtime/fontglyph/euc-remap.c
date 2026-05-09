/*
 * JISコード順に並んだ字形データを、EUC-JPから参照しやすく並び替える
 * ｱ. 区の初めと終わりに1文字づつのパディング
 *    1区は94+2=96字、96*8=768バイト
 * ｲ. 9,10,11,12,14,15区を削除し、13区と16区を1つのブロックとする
 * Linux用
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <stdbool.h>

void padding(int cnt);  // パディング
void copy_char();       // 文字の書き出し
void copy_ku();         // 区の書き出し
void skip();            // 区のスキップ

FILE  *src_fileptr, *dst_fileptr;          // 入出力のファイルポインタ
char glyph_buf[8]; // 8バイトの字形データバッファ

int main(int argc, char *argv[])
{
  // 変数宣言
  char  src_name[100], dst_name[100];       // ファイル名
  int opt;                                  // コマンドラインオプション処理用
  bool opt_verbose = false;                 // 冗長メッセージ

  // オプション処理
  while ((opt=getopt(argc,argv,"v"))!=-1)  // ハイフンオプションを取得
  {
    switch(opt)
    {
      case 'v':
        opt_verbose = true;                 // 詳細メッセージ
        break;
      default:
      return EXIT_FAILURE;
    }

  }

  if(opt_verbose)fprintf(stderr, "JISコード順に並んだフォントを、EUC-JPコードからアクセスしやすくリマップします。\n");

  // ファイル名取得
  sprintf(src_name, "%s", argv[optind]);     // ソースファイル名を取得
  sprintf(dst_name, "%s", argv[optind+1]);   // 出力先のファイル名を取得

  // 入力ファイルをオープン
  if((src_fileptr=fopen(src_name, "rb"))==NULL)
  {
    fprintf(stderr, "File_Open_Error: %s\n", src_name);
    return EXIT_FAILURE;
  }
  // 出力ファイルをオープン
  if((dst_fileptr=fopen(dst_name, "wb"))==NULL)
  {
    fprintf(stderr, "File_Open_Error: %s\n", dst_name);
    fclose(src_fileptr);
    return EXIT_FAILURE;
  }

  for(int i=1; i<=84; i++)
  {
    switch(i)
    {
      case 9: case 10: case 11: case 12: case 14: case 15:
        skip();
        break;
      default:
        copy_ku();
    }
  }

  fclose(src_fileptr);
  fclose(dst_fileptr);
  return EXIT_SUCCESS;
}

// 区をスキップ
void skip()
{
  for(int i=1; i<=94; i++)
  {
    if(fread(glyph_buf, 1, 8, src_fileptr) != 8)
    {
      fprintf(stderr, "File_Read_Error\n");
      exit(EXIT_FAILURE);
    }
  }
}

// 区を書き出し
void copy_ku()
{
  padding(1);
  for(int i=1; i<=94; i++)
  {
    copy_char();
  }
  padding(1);
}

// 1文字を書き出し
void copy_char()
{
  if(fread(glyph_buf, 1, 8, src_fileptr) != 8)
  {
    fprintf(stderr, "File_Read_Error\n");
    exit(EXIT_FAILURE);
  }
  if(fwrite(glyph_buf, 1, 8, dst_fileptr) != 8)
  {
    fprintf(stderr, "File_Write_Error\n");
    exit(EXIT_FAILURE);
  }
}

// 指定字数ぶんのパディングを挿入
void padding(int cnt)
{
  int i;
  for(i=0; i<cnt; i++)
  {
    if(fwrite((char[8]){0}, 1, 8, dst_fileptr) != 8)
    {
      fprintf(stderr, "File_Write_Error\n");
      exit(EXIT_FAILURE);
    }
  }
}
