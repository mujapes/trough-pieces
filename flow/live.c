/* live.c [by Opus]: the smallest host for Flow. One memfd mapped twice: written through one view, run through the other.
 * Appends flow's step, runs a field to rest, then appends a second verb while a cell keeps being called, and times
 * write -> live. Usage: live <flow.bin> */
#define _GNU_SOURCE
#include <sys/mman.h>
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
typedef int64_t (*verb)(void*,const int16_t*,int64_t,int64_t,void*const*);
static double us(void){struct timespec t;clock_gettime(CLOCK_MONOTONIC,&t);return t.tv_sec*1e6+t.tv_nsec/1e3;}
static char *wv,*rv; static size_t top;
static void *put(const void *code,size_t n){memcpy(wv+top,code,n);__builtin___clear_cache(rv+top,rv+top+n);void*a=rv+top;top=(top+n+15)&~15;return a;}
int main(int c,char**v){
 size_t room=1<<20; int fd=memfd_create("flow",MFD_CLOEXEC); if(fd<0||ftruncate(fd,room))return 2;
 wv=mmap(0,room,PROT_READ|PROT_WRITE,MAP_SHARED,fd,0); rv=mmap(0,room,PROT_READ|PROT_EXEC,MAP_SHARED,fd,0);
 if(wv==MAP_FAILED||rv==MAP_FAILED){puts("two views refused");return 3;}
 FILE*f=fopen(v[1],"rb"); static char b[65536]; size_t n=fread(b,1,sizeof b,f); fclose(f);
 static void *cell[512]; double t0=us(); cell[0]=put(b,n); __atomic_thread_fence(__ATOMIC_RELEASE); double t1=us();
 static struct{uint32_t n,x; double p[8];} fl={4,0,{0,100, 50,50, 1,-1, 1e6,0}};
 int frames=0; while(((verb)cell[0])(&fl,0,0,6554,cell)&&frames<1000)frames++;
 int ok=fl.p[0]==100&&fl.p[2]==50&&fl.p[4]==-1&&fl.p[6]==0;
 printf("field: at rest after %d frames, exact targets %s; first frame values ",frames,ok?"yes":"NO");
 fl.p[1]=0; ((verb)cell[0])(&fl,0,0,6554,cell); printf("%.3f\n",fl.p[0]);
 /* a new verb written while the cell is in use: answers 7 (mov x0,#7; ret) */
 uint32_t seven[2]={0xd28000e0,0xd65f03c0}; double t2=us(); void*a=put(seven,8); __atomic_store_n(&cell[0],a,__ATOMIC_RELEASE); double t3=us();
 int64_t r=((verb)cell[0])(&fl,0,0,0,cell);
 printf("write->live: first verb %.1f us, new verb %.2f us, new verb answers %lld\n",t1-t0,t3-t2,(long long)r);
 return !(ok&&r==7);}
