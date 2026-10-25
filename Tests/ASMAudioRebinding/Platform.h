#pragma once
#include <stdint.h>
#include <stddef.h>
#include <string.h>
#ifndef PATH_MAX
#define PATH_MAX 4096
#endif
typedef int BOOL;
#define YES 1
#define NO 0
#define FALSE 0
#define MH_MAGIC_64 0xfeedfacf
#define MH_EXECUTE 2
#define MH_DYLIB 6
#define LC_SEGMENT_64 0x19
#define LC_SYMTAB 2
#define LC_DYSYMTAB 0xb
#define SEG_LINKEDIT "__LINKEDIT"
#define SECTION_TYPE 0xff
#define S_NON_LAZY_SYMBOL_POINTERS 6
#define S_LAZY_SYMBOL_POINTERS 7
#define VM_PROT_READ 1
#define VM_PROT_WRITE 2
#define VM_PROT_COPY 16
#define KERN_SUCCESS 0
typedef uintptr_t vm_size_t;
typedef uintptr_t vm_address_t;
typedef int kern_return_t;
struct mach_header { uint32_t magic,cpu,subtype,filetype,ncmds,sizeofcmds,flags; };
struct mach_header_64 { uint32_t magic,cpu,subtype,filetype,ncmds,sizeofcmds,flags,reserved; };
struct load_command { uint32_t cmd,cmdsize; };
struct segment_command_64 {
    uint32_t cmd,cmdsize; char segname[16]; uint64_t vmaddr,vmsize,fileoff,filesize;
    uint32_t maxprot,initprot,nsects,flags;
};
struct section_64 {
    char sectname[16],segname[16]; uint64_t addr,size;
    uint32_t offset,align,reloff,nreloc,flags,reserved1,reserved2,reserved3;
};
struct symtab_command { uint32_t cmd,cmdsize,symoff,nsyms,stroff,strsize; };
struct dysymtab_command {
    uint32_t cmd,cmdsize,ilocalsym,nlocalsym,iextdefsym,nextdefsym,iundefsym,nundefsym;
    uint32_t tocoff,ntoc,modtaboff,nmodtab,extrefsymoff,nextrefsyms,indirectsymoff,nindirectsyms;
    uint32_t extreloff,nextrel,locreloff,nlocrel;
};
struct nlist_64 { union { uint32_t n_strx; } n_un; uint8_t type,sect; uint16_t desc; uint64_t value; };
extern vm_size_t vm_page_size;
int mach_task_self(void);
kern_return_t vm_protect(int,vm_address_t,vm_size_t,int,int);
uint32_t _dyld_image_count(void);
const struct mach_header *_dyld_get_image_header(uint32_t);
const char *_dyld_get_image_name(uint32_t);
intptr_t _dyld_get_image_vmaddr_slide(uint32_t);
int _NSGetExecutablePath(char *,uint32_t *);
void ASMRebindTestLog(const char *,...);
BOOL SGRebindImport(const char *,void *,void **);
