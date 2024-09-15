/*
 * JISコード順に並んだ字形データを、Shift-JISから参照しやすく並び替える
 * ｱ. 2区（94*2字）を1ブロックとして、ブロックごとに4バイトのパディングを挿入
 *    Shift-JIS下位0x7Fとして1字、おしりに3字分
 *    1ブロックは94*2+4=192字、192*8=1536バイト
 * ｲ. 9,10,11,12,14,15区を削除し、13区と16区を1つのブロックとする
 * Linux用
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <stdbool.h>

void padding(int cnt);    //パディング
void copy_char();  //文字のコピー
void copy_odd();   //奇数区のコピー
void copy_even();  //偶数区のコピー
void skip();       //区のスキップ

FILE  *src_fileptr, *dst_fileptr;          // 入出力のファイルポインタ
char glyph_buf[8]; //8バイトの字形データバッファ

int main(int argc, char *argv[])
{
  // 変数宣言
  char  src_name[100], dst_name[100];       // ファイル名
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

  if(opt_verbose)fprintf(stderr, "JISコード順に並んだフォントを、SJISからアクセスしやすくリマップします。\n");

  // ファイル名取得
  sprintf(src_name, "%s", argv[optind]);     // ソースファイル名を取得
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

  for(int i=1; i<=84; i++){
    switch(i){
      case 9: case 10: case 11: case 12: case 14: case 15:
        skip();
        break;
      default:
        if(i%2 == 1) copy_odd();
        else copy_even();
    }
  }

  fclose(src_fileptr);
  fclose(dst_fileptr);
  return EXIT_SUCCESS;
}

void skip(){
  for(int i=0; i<94; i++){
    if(fread(glyph_buf, 1, 8, src_fileptr) != 8){
      fprintf(stderr, "File_Read_Error\n");
      exit(EXIT_FAILURE);
    }
  }
}

void copy_odd(){
  for(int i=0x40; i<=0x9E; i++){
    if(i == 0x7F) padding(1);
    else copy_char();
  }
}

void copy_even(){
  for(int i=0x9F; i<=0xFC; i++){
    copy_char();
  }
  padding(3);
}

void copy_char(){
  if(fread(glyph_buf, 1, 8, src_fileptr) != 8){
    fprintf(stderr, "File_Read_Error\n");
    exit(EXIT_FAILURE);
  }
  if(fwrite(glyph_buf, 1, 8, dst_fileptr) != 8){
    fprintf(stderr, "File_Write_Error\n");
    exit(EXIT_FAILURE);
  }
}

void padding(int cnt){
  int i;
  for(i=0; i<cnt; i++){
    if(fwrite((char[8]){0}, 1, 8, dst_fileptr) != 8){
      fprintf(stderr, "File_Write_Error\n");
      exit(EXIT_FAILURE);
    }
  }
}
