// The protobuf wire format, just enough to walk into a message, change a few fields and write it
// back with everything else untouched. Premium.m and Feeds.m read Spotify's responses through it.
#import <Foundation/Foundation.h>

// A field as it sits on the wire: a varint carries its value, everything else its raw payload.
@interface ASMVitrinePBField : NSObject
@property (nonatomic) uint32_t number;
@property (nonatomic) uint8_t wire;   // 0 varint, 1 fixed64, 2 length-delimited, 5 fixed32
@property (nonatomic) uint64_t varint;
@property (nonatomic, copy) NSData *payload;
@end

NSMutableArray<ASMVitrinePBField *> *ASMVitrinePBParse(NSData *data);   // nil when the bytes are not a message
NSData *ASMVitrinePBSerialize(NSArray<ASMVitrinePBField *> *fields);
ASMVitrinePBField *ASMVitrinePBFirst(NSArray<ASMVitrinePBField *> *fields, uint32_t number);
ASMVitrinePBField *ASMVitrinePBVarint(uint32_t number, uint64_t value);
ASMVitrinePBField *ASMVitrinePBBytes(uint32_t number, NSData *payload);
ASMVitrinePBField *ASMVitrinePBString(uint32_t number, NSString *text);
NSString *ASMVitrinePBText(ASMVitrinePBField *field);   // the payload read as UTF-8, nil for any other field
// The message at `path` (field numbers, outermost first) handed to `edit`, whose result takes its
// place; nil when a field of the path is missing, the bytes do not parse or `edit` returns nil.
NSData *ASMVitrinePBEdit(NSData *message, NSArray<NSNumber *> *path, NSData *(^edit)(NSData *inner));
