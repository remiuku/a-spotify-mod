#include "ASMWhimsyText.h"
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "goldens.h"

static void check(const char *input, const char *expected) {
    size_t length = ASMUwuText(input, NULL, 0);
    char *text = malloc(length + 1);
    assert(text);
    assert(ASMUwuText(input, text, length + 1) == length);
    assert(!strcmp(text, expected));
    assert(strlen(text) == length);
    // Re-rendering must not double-transform text already on screen.
    char *again = malloc(length * 2 + 1);
    ASMUwuText(text, again, length * 2 + 1);
    assert(!strcmp(again, text));
    free(again); free(text);
}
int main(void) {
    check("Hello, I love your lyrics!", "Hewwo, I wuv youw wywics!");
    check("YOU LOVE THIS", "YOU WUV THIS");
    check("Nothing nearby", "Nyothing nyeawby");
    check("the other theatre", "the othew theatwe");
    check("New York", "Nyew Yowk");
    check("NEW YORK", "NYEW YOWK");
    check("123 :3 5:20 / 1.25x", "123 :3 5:20 / 1.25x");
    check("caf\xc3\xa9 / \xe6\xad\x8c\xe8\xaf\x8d", "caf\xc3\xa9 / \xe6\xad\x8c\xe8\xaf\x8d");
    check("", ""); check(NULL, "");
    char tiny[3] = {'x','x','x'};
    assert(ASMUwuText("Nothing", tiny, sizeof tiny) == 8 && tiny[2] == '\0');
    // Probe every small buffer size with sentinels. The measured result must
    // agree with a full write, regardless of truncation, without crossing bounds.
    const char *sample = "New lyrics, LOVE your caf\xc3\xa9!";
    size_t measured = ASMUwuText(sample, NULL, 0);
    char full[128];
    assert(ASMUwuText(sample, full, sizeof full) == measured);
    for (size_t capacity = 0; capacity < 64; capacity++) {
        unsigned char guarded[66]; memset(guarded, 0xA5, sizeof guarded);
        assert(ASMUwuText(sample, (char *)guarded + 1, capacity) == measured);
        assert(guarded[0] == 0xA5 && guarded[capacity + 1] == 0xA5);
        if (capacity) {
            size_t written = measured < capacity ? measured : capacity - 1;
            assert(!memcmp(guarded + 1, full, written));
            assert(guarded[written + 1] == '\0');
        }
    }
    for (size_t i=0; i<sizeof baseGoldens/sizeof *baseGoldens; i++) check(baseGoldens[i].input,baseGoldens[i].expected);
    for (size_t i=0; i<sizeof richGoldens/sizeof *richGoldens; i++) {
        const char *input=richGoldens[i].input, *expected=richGoldens[i].expected;
        uint32_t seed=richGoldens[i].seed;
        size_t count=ASMUwuDecoratedText(input,seed,NULL,0);
        assert(count==strlen(expected));
        char *actual=malloc(count+1);
        assert(actual && ASMUwuDecoratedText(input,seed,actual,count+1)==count);
        assert(!strcmp(actual,expected));
        for (size_t capacity=0; capacity<96; capacity++) {
            unsigned char guarded[98]; memset(guarded,0xA5,sizeof guarded);
            assert(ASMUwuDecoratedText(input,seed,(char *)guarded+1,capacity)==count);
            assert(guarded[0]==0xA5 && guarded[capacity+1]==0xA5);
            if (capacity) {
                size_t written=count<capacity ? count : capacity-1;
                assert(!memcmp(guarded+1,expected,written) && guarded[written+1]=='\0');
            }
        }
        free(actual);
    }
    puts("PASS extension parity: 14 base and 1792 seeded JS goldens; UTF-8, stable output, idempotent base and bounded buffers");
}
