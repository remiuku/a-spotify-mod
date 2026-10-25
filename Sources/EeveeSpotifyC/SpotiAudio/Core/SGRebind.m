// Adapted from spoti.pw v0.21.1, a08b38b9e293f0893e92ff7a9b7b9d92f903431a. GPL-3.0.
// See THIRD_PARTY_SPOTI_PW.md for authors, origins and local changes.
#ifdef ASM_REBIND_TEST
#include "Platform.h"
#define RebindLog(...) ASMRebindTestLog(__VA_ARGS__)
#else
#import <mach/mach.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach-o/nlist.h>
#import <string.h>
#import "SGRebind.h"
#import "../ASMSpotiSupport.h"
#define RebindLog(format, ...) SGLog(@format, ##__VA_ARGS__)
#endif
#include <limits.h>
#include "ASMAudioImagePolicy.h"

static const struct mach_header_64 *spotifyExecutable(intptr_t *slide) {
    char executable[PATH_MAX]={0};
    uint32_t size=sizeof executable;
    if (_NSGetExecutablePath(executable,&size)!=0) executable[0]=0;
    const struct mach_header_64 *selected=NULL;
    const char *selectedName=NULL;
    int best=0;
    BOOL ambiguous=NO;
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        const struct mach_header *header = _dyld_get_image_header(i);
        if (!header || header->magic!=MH_MAGIC_64 || (header->filetype!=MH_EXECUTE && header->filetype!=MH_DYLIB)) continue;
        const char *name=_dyld_get_image_name(i);
        int rank=ASMAudioImageRank(name,executable);
        if (rank>best) {
            selected=(const struct mach_header_64 *)header; selectedName=name;
            *slide=_dyld_get_image_vmaddr_slide(i); best=rank; ambiguous=NO;
        } else if (rank && rank==best && selected!=(const struct mach_header_64 *)header) ambiguous=YES;
    }
    if (ambiguous) { RebindLog("audio rebind: ambiguous Spotify images; leaving host untouched"); return NULL; }
    if (selected) RebindLog("audio rebind: selected %s (Mach-O type %u)",selectedName,selected->filetype);
    else RebindLog("audio rebind: Spotify guest image not visible yet; leaving host untouched");
    return selected;
}

// Writes one pointer, making its page writable first; a page dyld made read only after binding
// (__DATA_CONST, __AUTH_CONST) is copied and made read only again.
static BOOL writeSlot(void **slot, void *value, BOOL readOnly) {
    vm_size_t page = vm_page_size;
    vm_address_t start = (vm_address_t)slot & ~(page - 1);
    kern_return_t result = vm_protect(mach_task_self(), start, page, FALSE, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
    if (result != KERN_SUCCESS) {
        RebindLog("audio rebind: vm_protect failed (%d)", result);
        return NO;
    }
    *slot = value;
    if (readOnly) vm_protect(mach_task_self(), start, page, FALSE, VM_PROT_READ);
    return YES;
}

BOOL SGRebindImport(const char *symbol, void *replacement, void **original) {
    intptr_t slide = 0;
    const struct mach_header_64 *header = spotifyExecutable(&slide);
    if (!header) return NO;

    const struct segment_command_64 *linkedit = NULL;
    const struct symtab_command *symtab = NULL;
    const struct dysymtab_command *dysymtab = NULL;
    const struct load_command *command = (const struct load_command *)(header + 1);
    for (uint32_t i = 0; i < header->ncmds; i++, command = (const struct load_command *)((const char *)command + command->cmdsize)) {
        if (command->cmd == LC_SEGMENT_64 && strcmp(((const struct segment_command_64 *)command)->segname, SEG_LINKEDIT) == 0) {
            linkedit = (const struct segment_command_64 *)command;
        } else if (command->cmd == LC_SYMTAB) {
            symtab = (const struct symtab_command *)command;
        } else if (command->cmd == LC_DYSYMTAB) {
            dysymtab = (const struct dysymtab_command *)command;
        }
    }
    if (!linkedit || !symtab || !dysymtab || !dysymtab->nindirectsyms) return NO;

    uintptr_t base = (uintptr_t)slide + (uintptr_t)(linkedit->vmaddr - linkedit->fileoff);
    const struct nlist_64 *symbols = (const struct nlist_64 *)(base + symtab->symoff);
    const char *strings = (const char *)(base + symtab->stroff);
    const uint32_t *indirect = (const uint32_t *)(base + dysymtab->indirectsymoff);

    // The symbol's index once, among the undefined ones, rather than a name compared per slot.
    uint32_t wanted = UINT32_MAX;
    for (uint32_t i = dysymtab->iundefsym; i < dysymtab->iundefsym + dysymtab->nundefsym && i < symtab->nsyms; i++) {
        uint32_t offset = symbols[i].n_un.n_strx;
        if (offset >= symtab->strsize) continue;
        const char *name = strings + offset;
        if (name[0] == '_' && strcmp(name + 1, symbol) == 0) {
            wanted = i;
            break;
        }
    }
    if (wanted == UINT32_MAX) return NO;

    BOOL rebound = NO;
    command = (const struct load_command *)(header + 1);
    for (uint32_t i = 0; i < header->ncmds; i++, command = (const struct load_command *)((const char *)command + command->cmdsize)) {
        if (command->cmd != LC_SEGMENT_64) continue;
        const struct segment_command_64 *segment = (const struct segment_command_64 *)command;
        BOOL readOnly = strcmp(segment->segname, "__DATA_CONST") == 0 || strcmp(segment->segname, "__AUTH_CONST") == 0;
        const struct section_64 *section = (const struct section_64 *)(segment + 1);
        for (uint32_t s = 0; s < segment->nsects; s++, section++) {
            uint32_t type = section->flags & SECTION_TYPE;
            if (type != S_NON_LAZY_SYMBOL_POINTERS && type != S_LAZY_SYMBOL_POINTERS) continue;
            void **slots = (void **)((uintptr_t)slide + section->addr);
            uint64_t count = section->size / sizeof(void *);
            for (uint64_t k = 0; k < count; k++) {
                uint64_t entry = (uint64_t)section->reserved1 + k;
                if (entry >= dysymtab->nindirectsyms || indirect[entry] != wanted) continue;
                if (slots[k] == replacement) { if (!original || *original) rebound=YES; continue; }
                void *held = slots[k];
                BOOL publish=original && !*original;
                if (publish) *original=held;
                if (!writeSlot(&slots[k], replacement, readOnly)) { if (publish) *original=NULL; continue; }
                rebound = YES;
            }
        }
    }
    return rebound;
}
