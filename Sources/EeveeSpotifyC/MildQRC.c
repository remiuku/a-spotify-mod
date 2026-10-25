// Adapted from gcoolL/mild-lyrics, AGPL-3.0. See THIRD_PARTY_MILD_LYRICS.md.
#include <stdint.h>
#include <stddef.h>
static const uint8_t QRC_SBOX[8][64] = {{14,4,13,1,2,15,11,8,3,10,6,12,5,9,0,7,0,15,7,4,14,2,13,1,10,6,12,11,9,5,3,8,4,1,14,8,13,6,2,11,15,12,9,7,3,10,5,0,15,12,8,2,4,9,1,7,5,11,3,14,10,0,6,13},{15,1,8,14,6,11,3,4,9,7,2,13,12,0,5,10,3,13,4,7,15,2,8,15,12,0,1,10,6,9,11,5,0,14,7,11,10,4,13,1,5,8,12,6,9,3,2,15,13,8,10,1,3,15,4,2,11,6,7,12,0,5,14,9},{10,0,9,14,6,3,15,5,1,13,12,7,11,4,2,8,13,7,0,9,3,4,6,10,2,8,5,14,12,11,15,1,13,6,4,9,8,15,3,0,11,1,2,12,5,10,14,7,1,10,13,0,6,9,8,7,4,15,14,3,11,5,2,12},{7,13,14,3,0,6,9,10,1,2,8,5,11,12,4,15,13,8,11,5,6,15,0,3,4,7,2,12,1,10,14,9,10,6,9,0,12,11,7,13,15,1,3,14,5,2,8,4,3,15,0,6,10,10,13,8,9,4,5,11,12,7,2,14},{2,12,4,1,7,10,11,6,8,5,3,15,13,0,14,9,14,11,2,12,4,7,13,1,5,0,15,10,3,9,8,6,4,2,1,11,10,13,7,8,15,9,12,5,6,3,0,14,11,8,12,7,1,14,2,13,6,15,0,9,10,4,5,3},{12,1,10,15,9,2,6,8,0,13,3,4,14,7,5,11,10,15,4,2,7,12,9,5,6,1,13,14,0,11,3,8,9,14,15,5,2,8,12,3,7,0,4,10,1,13,11,6,4,3,2,12,9,5,15,10,11,14,1,7,6,0,8,13},{4,11,2,14,15,0,8,13,3,12,9,7,5,10,6,1,13,0,11,7,4,9,1,10,14,3,5,12,2,15,8,6,1,4,11,13,12,3,7,14,10,15,6,8,0,5,9,2,6,11,13,8,1,4,10,7,9,5,0,15,14,2,3,12},{13,2,8,4,6,15,11,1,10,9,3,14,5,0,12,7,1,15,13,8,10,3,7,4,12,5,6,11,0,14,9,2,7,11,4,1,9,12,14,2,0,6,10,13,15,3,5,8,2,1,14,7,4,10,8,13,15,12,9,0,3,5,6,11}};
static const uint8_t QRC_IP[] = {57,49,41,33,25,17,9,1,59,51,43,35,27,19,11,3,61,53,45,37,29,21,13,5,63,55,47,39,31,23,15,7};
static const uint8_t QRC_PBOX[] = {15,6,19,20,28,11,27,16,0,14,22,25,4,17,30,9,1,7,23,13,31,26,2,8,18,12,29,5,21,10,3,24};
static const uint8_t QRC_EXPAND[] = {31,0,1,2,3,4,3,4,5,6,7,8,7,8,9,10,11,12,11,12,13,14,15,16,15,16,17,18,19,20,19,20,21,22,23,24,23,24,25,26,27,28,27,28,29,30,31,0};
static const uint8_t QRC_SHIFT[] = {1,1,2,2,2,2,2,2,1,2,2,2,2,2,2,1};
static const uint8_t QRC_PERM_C[] = {56,48,40,32,24,16,8,0,57,49,41,33,25,17,9,1,58,50,42,34,26,18,10,2,59,51,43,35};
static const uint8_t QRC_PERM_D[] = {62,54,46,38,30,22,14,6,61,53,45,37,29,21,13,5,60,52,44,36,28,20,12,4,27,19,11,3};
static const uint8_t QRC_SQUEEZE[] = {13,16,10,23,0,4,2,27,14,5,20,9,22,18,11,3,25,7,15,6,26,19,12,1,40,51,30,36,46,54,29,39,50,44,32,47,43,48,38,55,33,52,45,41,49,35,28,31};
static const uint8_t QRC_ORDER[] = {3,2,1,0,7,6,5,4};
static const uint8_t QRC_UNORDER[] = {4,5,6,7,0,1,2,3};

static uint32_t bit(const uint8_t *src,int b,int to) { return ((src[QRC_ORDER[b/8]] >> (7-b%8))&1U)<<to; }
static uint32_t f(uint32_t state,uint64_t key) {
    uint64_t bits=0; for(int k=0;k<48;k++) bits |= (uint64_t)((state>>(31-QRC_EXPAND[k]))&1U)<<(47-k);
    bits ^= key; uint32_t boxed=0,out=0;
    for(int i=0;i<8;i++) { int six=(bits>>(42-6*i))&63; int row=(six&32)|((six&31)>>1)|((six&1)<<4); boxed|=(uint32_t)QRC_SBOX[i][row]<<(28-4*i); }
    for(int k=0;k<32;k++) out|=((boxed>>(31-QRC_PBOX[k]))&1U)<<(31-k);
    return out;
}
static void des(uint8_t *data,size_t n,const uint8_t *key,int decrypt) {
    uint32_t c=0,d=0; uint64_t rounds[16]={0};
    for(int i=0;i<28;i++) { c|=bit(key,QRC_PERM_C[i],31-i); d|=bit(key,QRC_PERM_D[i],31-i); }
    for(int i=0;i<16;i++) {
        int shift=QRC_SHIFT[i]; c=((c<<shift)|(c>>(28-shift)))&0xfffffff0U; d=((d<<shift)|(d>>(28-shift)))&0xfffffff0U;
        uint64_t rk=0; for(int j=0;j<24;j++) rk|=(uint64_t)((c>>(31-QRC_SQUEEZE[j]))&1U)<<(47-j);
        for(int j=24;j<48;j++) rk|=(uint64_t)((d>>(31-QRC_SQUEEZE[j]+27))&1U)<<(47-j);
        rounds[decrypt?15-i:i]=rk;
    }
    for(size_t at=0;at+8<=n;at+=8) {
        uint32_t left=0,right=0; for(int i=0;i<32;i++) { left|=bit(data+at,QRC_IP[i],31-i); right|=bit(data+at,QRC_IP[i]-1,31-i); }
        for(int i=0;i<15;i++) { uint32_t prev=right; right=f(right,rounds[i])^left; left=prev; }
        left=f(right,rounds[15])^left; uint8_t out[8];
        for(int k=0;k<8;k++) { uint8_t v=0; for(int j=0;j<4;j++) v|=(((right>>(31-k-8*j))&1U)<<(7-2*j))|(((left>>(31-k-8*j))&1U)<<(6-2*j)); out[QRC_UNORDER[k]]=v; }
        for(int k=0;k<8;k++) data[at+k]=out[k];
    }
}
void EeveeMildQRCDecrypt(uint8_t *data,size_t count) {
    des(data,count,(const uint8_t *)"!@#)(NHL",1); des(data,count,(const uint8_t *)"123ZXC!@",0); des(data,count,(const uint8_t *)"!@#)(*$%",1);
}
