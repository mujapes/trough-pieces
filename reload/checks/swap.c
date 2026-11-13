/* swap.c [by Opus]: reload's take/back on a call table: one group swap, refusal leaves all unchanged, back restores. */
#include "../../loader/piece.h"
#include <stdio.h>
#include <stdint.h>
typedef int64_t (*E)(void*,const int16_t*,int64_t,int64_t,void*const*);
static long f1(void){return 1;} static long f2(void){return 2;} static long g1(void){return 11;} static long g2(void){return 12;}
int main(int c,char**v){piece p; if(piece_load(&p,v[1]))return 2; E take=(E)piece_entry(&p,"take"),back=(E)piece_entry(&p,"back");
 static void*t[512]; static char led[4096]; int w=0,n=0;
#define X(c,m) do{n++;if(!(c)){w++;printf("wrong: %s\n",m);}}while(0)
 t[5]=(void*)f1;t[9]=(void*)g1; int16_t s[2]={5,9}; void*nw[2]={(void*)f2,(void*)g2};
 X(take(led,s,2,(int64_t)nw,t)==1,"take answers count 1"); X(t[5]==(void*)f2&&t[9]==(void*)g2,"both swapped");
 X(((long(*)(void))t[9])()==12,"new code runs");
 int16_t bad[2]={5,300}; X(take(led,bad,2,(int64_t)nw,t)==-1&&t[5]==(void*)f2,"socket 300 refused, nothing changed");
 int16_t dup[2]={5,5}; X(take(led,dup,2,(int64_t)nw,t)==-1,"repeat refused"); void*z[2]={(void*)f1,0}; X(take(led,s,2,(int64_t)z,t)==-1&&t[5]==(void*)f2,"empty address refused");
 X(take(led,s,0,(int64_t)nw,t)==-1,"none refused");
 X(back(led,s,2,0,t)==2&&t[5]==(void*)f1&&t[9]==(void*)g1,"back restores both"); X(back(led,s,2,0,t)==-1&&t[5]==(void*)f1,"second back does nothing");
 X(take(led,s,1,(int64_t)nw,t)==2,"count grows");
 printf("%d checks, %d wrong\n",n,w); return w!=0;}
