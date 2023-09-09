/* rm.c
 * ファイル・ディレクトリ削除コマンド
 */
#include <stdio.h>

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

int main(){
  unsigned int* ptr=(unsigned int*)0;
  unsigned char* arg=(unsigned char*)*ptr;
  //finfo_t* finfo_p=fs_find_fst("TMP");
  //showFINFO(finfo_p);
  //finfo_p=fs_find_nxt(finfo_p,"TMP");
  //showFINFO(finfo_p);
  printf("ptr=%p, num=%p\n",ptr,arg);
  printf("arg:%s",arg);
  return 0;
}

