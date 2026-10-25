// Native behavior port of the user-supplied Boykisserfication 0.67 text rules.
// See THIRD_PARTY_BOYKISSER.md. Compile with -x c for portable reference tests.
#include "ASMWhimsyText.h"
#include <stdlib.h>
#include <string.h>

typedef struct { char *bytes; size_t used, capacity; } ASMTextOutput;
static void put(ASMTextOutput *out, char byte) {
    if (out->bytes && out->capacity && out->used < out->capacity - 1) out->bytes[out->used] = byte;
    out->used++;
}
static void append(ASMTextOutput *out, const char *text) { for (size_t i=0; text[i]; i++) put(out,text[i]); }
static size_t finish(ASMTextOutput *out) {
    if (out->bytes && out->capacity) out->bytes[out->used < out->capacity ? out->used : out->capacity-1]='\0';
    return out->used;
}
static int letter(char c) { return (c>='a' && c<='z') || (c>='A' && c<='Z'); }
static int lowerVowel(char c) { return c=='a' || c=='e' || c=='i' || c=='o' || c=='u'; }
static int upperVowel(char c) { return c=='A' || c=='E' || c=='I' || c=='O' || c=='U'; }
size_t ASMUwuText(const char *input, char *output, size_t capacity) {
    ASMTextOutput out = {output, 0, capacity};
    if (!input) input = "";
    for (size_t i=0; input[i]; i++) {
        // Mixed-case Ove deliberately remains intact, matching the extension.
        if (input[i]=='o' && input[i+1]=='v' && input[i+2]=='e') { append(&out,"uv"); i+=2; continue; }
        if (input[i]=='O' && input[i+1]=='V' && input[i+2]=='E') { append(&out,"UV"); i+=2; continue; }
        char c=input[i];
        if (c=='r' || c=='l') c='w'; else if (c=='R' || c=='L') c='W';
        put(&out,c);
        if ((c=='n' || c=='N') && lowerVowel(input[i+1])) put(&out,'y');
        else if (c=='N' && upperVowel(input[i+1])) put(&out,'Y');
    }
    return finish(&out);
}
uint32_t ASMUwuStableSeed(const char *input, uint32_t seed) {
    uint32_t value=2166136261u ^ seed;
    if (input) for (size_t i=0; input[i]; i++) value=(value^(unsigned char)input[i])*16777619u;
    return value;
}
static uint32_t next(uint32_t *state) {
    uint32_t value=*state;
    value^=value<<13; value^=value>>17; value^=value<<5;
    *state=value; return value;
}
static double chance(uint32_t *state) { return (double)next(state)/4294967296.0; }
static const char *decoration(uint32_t *state) {
    static const char *items[]={" (・`ω´・)"," ;;w;;"," owo"," UwU"," >w<"," ^w^",
        " ✨"," 🥺"," 👉👈"," 💖"," (✿◠‿◠)"," 🌸"};
    return items[((uint64_t)next(state)*12u)>>32];
}
size_t ASMUwuDecoratedText(const char *input, uint32_t seed, char *output, size_t capacity) {
    if (!input || !*input) { ASMTextOutput empty={output,0,capacity}; return finish(&empty); }
    size_t count=ASMUwuText(input,NULL,0);
    if (count>(SIZE_MAX-1)/3) return ASMUwuText(input,output,capacity);
    char *base=malloc(count+1), *stuttered=malloc(count*3+1);
    if (!base || !stuttered) { free(base); free(stuttered); return ASMUwuText(input,output,capacity); }
    ASMUwuText(input,base,count+1);
    uint32_t state=seed ? seed : 0x6d2b79f5u;
    ASMTextOutput words={stuttered,0,count*3+1};
    // split(' ') boundaries, including repeated spaces, match the JavaScript.
    for (size_t i=0; base[i]; i++) {
        if ((i==0 || base[i-1]==' ') && letter(base[i]) && chance(&state)<0.15) {
            put(&words,base[i]); put(&words,'-');
        }
        put(&words,base[i]);
    }
    finish(&words);
    ASMTextOutput result={output,0,capacity};
    for (size_t i=0; stuttered[i]; i++) {
        char c=stuttered[i]; put(&result,c);
        if ((c=='.' || c=='!' || c=='?' || c==',') && chance(&state)<0.5) append(&result,decoration(&state));
    }
    if (chance(&state)<0.7) append(&result,decoration(&state));
    free(base); free(stuttered);
    return finish(&result);
}
