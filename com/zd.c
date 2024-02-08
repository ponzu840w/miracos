/*
 -------------------------------------------------------------------
                              ZDコマンド
 -------------------------------------------------------------------
  雑なテキストエディタ。バッファファイルを持たず、RAMで完結する。
 -------------------------------------------------------------------
*/

#define TEXT_BUFFER_SIZE 1024
#define LINE_BUFFER_SIZE 256

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// アセンブラ関数とか
extern void coutc(const char c);
extern void cins(const char *str);

// グローバル変数
char text_buffer[TEXT_BUFFER_SIZE]; /* テキストバッファ */
char line_buffer[LINE_BUFFER_SIZE]; /* ラインバッファ */
char command[64];
unsigned int cl, cl_left, cl_right, lastl;
unsigned char cmd_index, cmd_verb_index;

// 1行表示
void put_line(char* str){
  unsigned int i = 0;
  while(str[i]!='\n' && str[i]!='\0')
      coutc(str[i++]);
  coutc('\n');
}

/* 行番号から行のポインタを得る */
/* 最終行+1を指定するとEOTの場所が返る */
char* getLine(unsigned int line_num){
  unsigned int cnt = 1;
  char* ptr = text_buffer;

  // 空バッファチェック
  if(text_buffer[0] == '\0')return NULL;

  // 1行目
  if(line_num == 1)return ptr;

  // 1文字ずつのループ
  do{
    if(*ptr == '\n'){
      if(line_num == ++cnt)
        return ++ptr;
    }
  }while(*(ptr++)!='\0');

  return --ptr;
}

// なんか都合のいいatoi
// .と$に対応
unsigned int super_atoi(){
  unsigned int i;
  switch(command[cmd_index]){
    case '.':
      return cl;
    case '$':
      return lastl;
    default:
      i = atoi(&command[cmd_index]);
  }
  return i;
}

// コマンドラインのパース
// out: cl_left, cl_right, cmd_verb_index
void purseCommand(){
    cl_left = cl;
    cl_right = cl;
    // コマンドのインデックス取得
    cmd_index = 0;
    while(!('A' <= command[cmd_index] && command[cmd_index] <= 'Z' ||
          'a' <= command[cmd_index] && command[cmd_index] <= 'z' ||
          command[cmd_index] == '\0'))cmd_index++;
    cmd_verb_index = cmd_index;
    // 対象行取得
    if(cmd_verb_index == 0)return; // 完全省略ならカレント行
    cmd_index = 0;
    // left
    if(command[0] == ','){
      cl_left = 1;
    }else{
      cl_left = super_atoi();
      // 数値スキップ
      do{
        cmd_index++;
      }while('0' <= command[cmd_index] && command[cmd_index] <= '9');
    }
    // right
    if(command[cmd_index] == ','){
      if(++cmd_index == cmd_verb_index){
        cl_right = lastl;         // ,があってそこで終わり
      }else{
        cl_right = super_atoi();  // ,があって右辺がある
      }
    }else{
      cl_right = cl_left;         // ,も右辺もない
    }
}

/* バッファにギャップを作る */
unsigned int makeGap(char* to, char* from){
  unsigned int length = strlen(from);
  unsigned int i = length;
  char* to_work = to+length;
  char* from_work = from+length;

  /* バッファ超過エラー */
  if(from_work > &text_buffer[TEXT_BUFFER_SIZE-1])
    return 0;

  /* 移動先が移動元より前にあるエラー */
  if(to <= from)
    return 2;

  do{
    //printf("len=%u, from:%d, from_work:%d, char=%c\n",length,from,from_work,*from_work);
    *(to_work--) = *(from_work--);
  }while(i-- > 0);
  return 1;
}

/* バッファのギャップを埋める */
unsigned int closeGap(){
}

/* i,a,c共通部分 */
/* 0 <= line <= lastl+1 */
void insertLine(unsigned int line){
  unsigned int len;
  char* ptr = getLine(line);    /* 操作対象行 */
  cins(line_buffer);            /* 入力バッファに入力 */
  len = strlen(line_buffer)+1;

  /* 末尾でなければスキマを作る */
  if(line <= lastl){
    makeGap(ptr+len, ptr);
  }else{
    *(ptr++) = '\n';  /* 末尾ならEOTを改行にしてポインタを進める */
  }

  /* スキマに入力をコピー */
  strcpy(ptr, line_buffer);

  /* 末尾でなければ挿入の終端を改行にする */
  if(line <= lastl)
    *(ptr+len-1) = '\n';

  /* 1行増えたので最終行を増加 */
  lastl++;
}

int main(void){
  char verb;
  unsigned int i;

  // テスト用テキストでバッファを初期化
  strcpy(text_buffer,"Line1. This is Text Buffer.\nLine2. New Line\nLine3.\nLine4. Good Bye.");

  printf("sample_text:\n%s\n",text_buffer);
  printf("text_buffer:%d\n",&text_buffer);

  //printf("makeGap:%u\n",makeGap(getLine(3),getLine(2)));
  //printf("gaped_text:\n%s\n",text_buffer);

  cl = 1;
  lastl = 4;

  // REPL
  while(1){
    // コマンドライン取得
    coutc('@');
    cins(command);
    coutc('\n');
    purseCommand();
    printf("purse left:%u, right %u, verb_index %u\n",cl_left,cl_right,cmd_verb_index);

    // 例外処理:範囲指定がひっくり返ってる
    if(cl_left > cl_right){
      printf("[ERROR] left > right.\n");
      continue;
    }

    // コマンド実行
    verb = command[cmd_verb_index];
    switch(verb){
      case 'p': /* print */
        for(i=cl_left; i <= cl_right; i++){
          put_line(getLine(i));
        }
        break;
      case 'i': /* insert */
        insertLine(cl_right);
        break;
      case 'a': /* append */
        insertLine(cl_right+1);
        break;
    }

    cl = cl_right;
  }
  return 0;
}
