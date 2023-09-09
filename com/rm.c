/* rm.c
 * ファイル・ディレクトリ削除コマンド
 */

#define MAX_ARGC 8

#include <stdio.h>
#include <unistd.h>
#include <string.h>
#include <stdbool.h>

typedef struct{
  // FIB、ファイル詳細情報を取得し、検索などに利用
  unsigned char Sig;                // $FFシグネチャ、フルパス指定と区別
  unsigned char Name[13];           // 8.3ヌル終端
  unsigned char Attr;               // 属性
  unsigned int  WrTime;             // 最終更新時刻
  unsigned int  WrDate;             // 最終更新日時
  unsigned long Head;               // 先頭クラスタ番号
  unsigned long Siz;                // ファイルサイズ
  // 次を検索するためのデータ
  unsigned char Drv_Num;            // ドライブ番号
  unsigned long Dir_Clus;           // 親ディレクトリ現在クラスタ  親の先頭クラスタはどうでもいい？
  unsigned char Dir_Sec;            // 親ディレクトリ現在クラスタ内セクタ
  unsigned char Dir_Ent;            // セクタ内エントリ番号（SDSEEKの下位を右に1シフトしてMSBが後半フラグ
} finfo_t;

extern finfo_t* fs_find_fst(const char* path);
extern finfo_t* fs_find_nxt(finfo_t* finfo, char* name);

unsigned char putnum_buf[11];

// $0123-4567形式で表示
char* put32(unsigned long toput){
  sprintf(putnum_buf,"$%04X-%04X",(unsigned int)(toput>>16),(unsigned int)(toput));
  return putnum_buf;
}

// FINFO表示
void showFINFO(finfo_t* finfo){
  if(finfo == NULL)return;
  printf("Name: %s\n",finfo->Name);
  printf("Attr: %02x\n",finfo->Attr);
  // 時間省いた
  printf("Head: %s\n",put32(finfo->Head));
  printf("Size: %s\n",put32(finfo->Siz));
  printf("Dir:\n");
  printf("  DrvNum: $%02x\n",finfo->Drv_Num);
  printf("    Clus: %s\n",put32(finfo->Dir_Clus));
  printf("     Sec: $%02x\n",finfo->Dir_Sec);
  printf("     Ent: $%02x\n",finfo->Dir_Ent);
}

unsigned char* get_filename_from_path(unsigned char* path) {
    // strrchr関数で最後の'/'の位置を探す
    unsigned char *lastSlash = strrchr(path, '/');
    if (lastSlash) {
        // 最後の'/'の次の文字がファイル名の始まり
        return lastSlash + 1;
    }
    return path;
}

void searchEntriesToDelete(char* path){
  unsigned char* basename = get_filename_from_path(path);
  finfo_t* finfo_p=fs_find_fst(path);
  if(finfo_p == NULL)return;

  do{
    showFINFO(finfo_p);
    finfo_p = fs_find_nxt(finfo_p,basename);
  }while(finfo_p != NULL);
}

// コマンドライン引数パーサ
void count_cmdarg(unsigned char* input, unsigned char* argc, unsigned char** argv){
  unsigned char *token = strtok(input, " ");
  unsigned char *tokens[32];
  unsigned char i=0;

  // 文字列をスペースでトークンに分解する。
  while (token) {
    tokens[*argc++] = token;
    //printf("!token=%s\n",token);
    token = strtok(NULL, " ");
  }

  printf("argc:%hhu\n",argc);

  // getopt()で使用するためのargcとargvを作成する。
  for (; i < *argc; i++) {
    argv[i] = tokens[i];
  }
  *argv[*argc] = NULL;
}

int main(){
  unsigned int* zr0=(unsigned int*)0;       // ZR0を指す
  unsigned char* arg=(unsigned char*)*zr0;  // ZR0の指すところを指す コマンドライン引数
  unsigned char argc=0;
  unsigned char* argv[MAX_ARGC+1];
  int opt;
  bool opt_recursive = false;

  printf("argc:%hu\n",&argc);
  count_cmdarg(arg, &argc, argv);

  // オプション処理
  //while ((opt=getopt(argc,argv,"r"))!=-1){  // ハイフンオプションを取得
  //getopt(argc,argv,"r");  // ハイフンオプションを取得
  //  switch(opt){
  //    case 'r':
  //      opt_recursive = true;                // 再帰的削除
  //      break;
  //    default:
  //    return -1;
  //  }
  //}
  //

  //printf("ptr=%p, num=%p\n",zr0,arg);
  printf("argc:%hhu",&argc);
  searchEntriesToDelete(arg);
  return 0;
}

