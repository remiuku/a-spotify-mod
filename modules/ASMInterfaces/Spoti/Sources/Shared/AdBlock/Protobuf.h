// The protobuf wire format, just enough to walk into a message, change a few fields and write it
// back with everything else untouched. Premium.m and Feeds.m read Spotify's responses through it.
#import <Foundation/Foundation.h>

// A field as it sits on the wire: a varint carries its value, everything else its raw payload.
@interface ASMSpotiPBField : NSObject
@property (nonatomic) uint32_t number;
@property (nonatomic) uint8_t wire;   // 0 varint, 1 fixed64, 2 length-delimited, 5 fixed32
@property (nonatomic) uint64_t varint;
@property (nonatomic, copy) NSData *payload;
@end

NSMutableArray<ASMSpotiPBField *> *ASMSpotiPBParse(NSData *data);   // nil when the bytes are not a message
NSData *ASMSpotiPBSerialize(NSArray<ASMSpotiPBField *> *fields);
ASMSpotiPBField *ASMSpotiPBFirst(NSArray<ASMSpotiPBField *> *fields, uint32_t number);
ASMSpotiPBField *ASMSpotiPBVarint(uint32_t number, uint64_t value);
ASMSpotiPBField *ASMSpotiPBBytes(uint32_t number, NSData *payload);
ASMSpotiPBField *ASMSpotiPBString(uint32_t number, NSString *text);
NSString *ASMSpotiPBText(ASMSpotiPBField *field);   // the payload read as UTF-8, nil for any other field
// The message at `path` (field numbers, outermost first) handed to `edit`, whose result takes its
// place; nil when a field of the path is missing, the bytes do not parse or `edit` returns nil.
NSData *ASMSpotiPBEdit(NSData *message, NSArray<NSNumber *> *path, NSData *(^edit)(NSData *inner));
