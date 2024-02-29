/* rm.c
 * ファイル・ディレクトリ削除コマンド
 */

#include <stdio.h>
#include <unistd.h>
#include <string.h>
#include <stdbool.h>

// ディレクトリエントリアトリビュート
#define MAX_ARGC 8
#define DIRATTR_READONLY   0x01
#define DIRATTR_HIDDEN     0x02
#define DIRATTR_SYSTEM     0x04
#define DIRATTR_VOLUMEID   0x08
#define DIRATTR_DIRECTORY  0x10
#define DIRATTR_ARCHIVE    0x20
#define DIRATTR_LONGNAME   0x0F

char verbose_flag = 0;

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

extern void coutc(const char c);
extern void couts(const char *str);

extern finfo_t* fs_find_fst(const char* path);
extern finfo_t* fs_find_nxt(finfo_t* finfo, char* name);
extern char fs_delete(void* path_or_finfo);
extern void err_print();

unsigned char putnum_buf[11];
finfo_t* finfo_p;
finfo_t finfo_deep_ins;
unsigned char basename[13];

// $0123-4567形式で表示
char* put32(unsigned long toput){
  sprintf(putnum_buf,"$%04X-%04X",(unsigned int)(toput>>16),(unsigned int)(toput));
  return putnum_buf;
}

// FINFO_WK表示
void showFINFO(finfo_t* ptr){
  printf("Sig: %02x\n",ptr->Sig);
  printf("Name: %s\n",ptr->Name);
  printf("Attr: %02x\n",ptr->Attr);
  // 時間省いた
  printf("Head: %s\n",put32(ptr->Head));
  printf("Size: %s\n",put32(ptr->Siz));
  printf("Dir:\n");
  printf("  DrvNum: $%02x\n",ptr->Drv_Num);
  printf("    Clus: %s\n",put32(ptr->Dir_Clus));
  printf("     Sec: $%02x\n",ptr->Dir_Sec);
  printf("     Ent: $%02x\n",ptr->Dir_Ent);
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
  unsigned char* basename_p = get_filename_from_path(path);
  strcpy(basename, basename_p);
  finfo_p = fs_find_fst(path);
  finfo_deep_ins = *finfo_p;
  if(verbose_flag)printf("KERNEL FINFO:%p\n", finfo_p);
  if(verbose_flag)printf("APP    FINFO:%p\n", &finfo_deep_ins);
  if(finfo_p == NULL)return;
  do{
    printf("%s", finfo_p->Name);
    if((finfo_p->Attr & (DIRATTR_READONLY|DIRATTR_VOLUMEID|DIRATTR_SYSTEM)) != 0){
      couts(" is protected.\n");
    }else{
      coutc(' ');
      if(fs_delete((void*)finfo_p)!=0){
        err_print();
        couts("error.\n");
      }else{
        couts("ok.\n");
      }
    }
    if(verbose_flag)printf("finfo_deep_ins:%s\n",&finfo_deep_ins.Name);
    if(verbose_flag)showFINFO(&finfo_deep_ins);
    finfo_p = fs_find_nxt(&finfo_deep_ins, basename); // TODO:与えるfinfoにのみ依存する建前に関わらず、deleteによって内部が壊れるのか連続削除できない
    finfo_deep_ins = *finfo_p;
    if(finfo_p != NULL){
      if(verbose_flag)printf("finfo_deep_ins:%s, basename=%s\n",&finfo_deep_ins.Name, basename);
      if(verbose_flag)showFINFO(&finfo_deep_ins);
    }
  }while(finfo_p != NULL);
}

int main(){
  unsigned int* zr0=(unsigned int*)0;       // ZR0を指す
  unsigned char* arg=(unsigned char*)*zr0;  // ZR0の指すところを指す コマンドライン引数
  unsigned char* tok = strtok(arg, " ");
  char* argv[16];
  unsigned char argc = 0;
  unsigned int i = 0;

  if(tok == NULL) return 0;
  do{
    if(tok[0] == '-' && tok[1] == 'v'){
      verbose_flag = 1;
    }else{
      argv[argc++] = tok;
    }
  }while((tok = strtok(NULL, " ")) != NULL);

  argv[argc] = NULL;

  do{
    printf("[%s]\n", argv[i]);
    searchEntriesToDelete(argv[i++]);
  }while(argv[i] != NULL);

  printf("end.\n");

  return 0;
}

