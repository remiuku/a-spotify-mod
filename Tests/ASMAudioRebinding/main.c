#include "Platform.h"
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>

_Static_assert(sizeof(struct mach_header_64)==32,"Mach header ABI");
_Static_assert(sizeof(struct segment_command_64)==72,"segment ABI");
_Static_assert(sizeof(struct section_64)==80,"section ABI");
_Static_assert(sizeof(struct nlist_64)==16,"symbol ABI");

typedef struct {
    struct mach_header_64 header;
    struct segment_command_64 linkedit,data;
    struct section_64 section;
    struct symtab_command symtab;
    struct dysymtab_command dysymtab;
} Commands;
typedef struct { struct nlist_64 symbols[2]; uint32_t indirect[2]; char strings[96]; } Linkedit;
typedef struct { Commands commands; Linkedit linkedit; void *slots[2]; const char *name; intptr_t slide; } Image;
static Image images[5];
static uint32_t imageCount;
static const char *executable;
static int protectFails,protectWrites,protectReads;
static unsigned baseCalls,hostCalls,speedCalls,dspCalls;
static void *speedOriginal,*dspOriginal;
vm_size_t vm_page_size=4096;
int mach_task_self(void) { return 0; }
kern_return_t vm_protect(int task,vm_address_t start,vm_size_t size,int maximum,int protection) {
    (void)task; (void)start; (void)size; (void)maximum;
    if (protectFails) return 5;
    if (protection&VM_PROT_WRITE) protectWrites++; else protectReads++;
    return KERN_SUCCESS;
}
uint32_t _dyld_image_count(void) { return imageCount; }
const struct mach_header *_dyld_get_image_header(uint32_t i) { return (void *)&images[i].commands; }
const char *_dyld_get_image_name(uint32_t i) { return images[i].name; }
intptr_t _dyld_get_image_vmaddr_slide(uint32_t i) { return images[i].slide; }
int _NSGetExecutablePath(char *buffer,uint32_t *size) {
    size_t count=strlen(executable)+1;
    if (*size<count) { *size=(uint32_t)count; return -1; }
    memcpy(buffer,executable,count); return 0;
}
void ASMRebindTestLog(const char *format,...) { (void)format; }
static void baseStart(void) { baseCalls++; }
static void hostStart(void) { hostCalls++; }
static void speedStart(void) { speedCalls++; assert(speedOriginal); ((void (*)(void))speedOriginal)(); }
static void dspStart(void) { dspCalls++; assert(dspOriginal); ((void (*)(void))dspOriginal)(); }
static void property(void) {}

static void initImage(Image *image,const char *name,uint32_t filetype,intptr_t slide,void *start) {
    memset(image,0,sizeof *image); image->name=name; image->slide=slide;
    Commands *c=&image->commands;
    c->header=(struct mach_header_64){.magic=MH_MAGIC_64,.filetype=filetype,.ncmds=4,.sizeofcmds=sizeof *c-sizeof c->header};
    c->linkedit=(struct segment_command_64){.cmd=LC_SEGMENT_64,.cmdsize=sizeof c->linkedit,.vmaddr=(uintptr_t)&image->linkedit-slide};
    strcpy(c->linkedit.segname,SEG_LINKEDIT);
    c->data=(struct segment_command_64){.cmd=LC_SEGMENT_64,.cmdsize=sizeof c->data+sizeof c->section,.nsects=1};
    strcpy(c->data.segname,"__DATA_CONST");
    c->section=(struct section_64){.addr=(uintptr_t)image->slots-slide,.size=sizeof image->slots,.flags=S_NON_LAZY_SYMBOL_POINTERS};
    c->symtab=(struct symtab_command){.cmd=LC_SYMTAB,.cmdsize=sizeof c->symtab,.symoff=offsetof(Linkedit,symbols),.nsyms=2,.stroff=offsetof(Linkedit,strings),.strsize=sizeof image->linkedit.strings};
    c->dysymtab=(struct dysymtab_command){.cmd=LC_DYSYMTAB,.cmdsize=sizeof c->dysymtab,.nundefsym=2,.indirectsymoff=offsetof(Linkedit,indirect),.nindirectsyms=2};
    char *strings=image->linkedit.strings;
    strcpy(strings+1,"_AudioOutputUnitStart");
    size_t second=strlen(strings+1)+2;
    strcpy(strings+second,"_AudioUnitSetProperty");
    image->linkedit.symbols[0].n_un.n_strx=1;
    image->linkedit.symbols[1].n_un.n_strx=(uint32_t)second;
    image->linkedit.indirect[0]=0; image->linkedit.indirect[1]=1;
    image->slots[0]=start; image->slots[1]=property;
}
static void reset(void) {
    imageCount=2; executable="/Apps/LiveContainer.app/LiveContainer";
    protectFails=protectWrites=protectReads=0;
    baseCalls=hostCalls=speedCalls=dspCalls=0; speedOriginal=dspOriginal=NULL;
    initImage(&images[0],executable,MH_EXECUTE,0,hostStart);
    initImage(&images[1],"/Guests/com.spotify.client.app/Spotify",MH_DYLIB,0x123000,baseStart);
}
int main(void) {
    reset();
    assert(SGRebindImport("AudioOutputUnitStart",speedStart,&speedOriginal));
    assert(speedOriginal==(void *)baseStart && images[0].slots[0]==(void *)hostStart);
    assert(SGRebindImport("AudioOutputUnitStart",dspStart,&dspOriginal));
    assert(dspOriginal==(void *)speedStart);
    ((void (*)(void))images[1].slots[0])();
    assert(baseCalls==1 && speedCalls==1 && dspCalls==1 && hostCalls==0);
    assert(SGRebindImport("AudioOutputUnitStart",dspStart,&dspOriginal));
    ((void (*)(void))images[1].slots[0])();
    assert(baseCalls==2 && speedCalls==2 && dspCalls==2); // no recursive re-hook
    assert(protectWrites==2 && protectReads==2);
    void *original=NULL;
    assert(SGRebindImport("AudioUnitSetProperty",dspStart,&original) && original==(void *)property);
    assert(images[0].slots[1]==(void *)property);

    reset(); imageCount=1; original=NULL;
    assert(!SGRebindImport("AudioOutputUnitStart",dspStart,&original));
    assert(!original && images[0].slots[0]==(void *)hostStart && !protectWrites);

    reset(); protectFails=1; original=NULL;
    assert(!SGRebindImport("AudioOutputUnitStart",dspStart,&original));
    assert(!original && images[1].slots[0]==(void *)baseStart);

    reset(); imageCount=3;
    initImage(&images[2],"/Other/Spotify.app/Spotify",MH_DYLIB,0x2000,baseStart);
    original=NULL;
    assert(!SGRebindImport("AudioOutputUnitStart",dspStart,&original)); // ambiguous guest rejected
    executable=images[1].name;
    assert(SGRebindImport("AudioOutputUnitStart",dspStart,&original)); // exact path wins
    assert(images[2].slots[0]==(void *)baseStart);

    reset(); images[1].name="/Host.app/Frameworks/Spotify.framework/Spotify"; original=NULL;
    assert(!SGRebindImport("AudioOutputUnitStart",dspStart,&original));

    reset(); images[1].commands.header.filetype=MH_EXECUTE; executable=images[1].name; original=NULL;
    assert(SGRebindImport("AudioOutputUnitStart",dspStart,&original)); // regular installation
    reset(); images[1].linkedit.indirect[0]=UINT32_MAX; original=NULL;
    assert(!SGRebindImport("AudioOutputUnitStart",dspStart,&original));
    puts("PASS actual rebinder: LiveContainer guest, direct install, ASLR, host isolation, speed/DSP chain, retries, ambiguous images, failed protection and invalid symbols");
}
