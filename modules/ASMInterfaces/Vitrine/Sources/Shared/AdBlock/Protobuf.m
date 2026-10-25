#import "Protobuf.h"

@implementation ASMVitrinePBField
@end

static BOOL readVarint(const uint8_t *bytes, NSUInteger length, NSUInteger *at, uint64_t *out) {
    uint64_t value = 0;
    for (int shift = 0; *at < length && shift < 64; shift += 7) {
        uint8_t byte = bytes[(*at)++];
        value |= (uint64_t)(byte & 0x7f) << shift;
        if (!(byte & 0x80)) {
            *out = value;
            return YES;
        }
    }
    return NO;
}

static void appendVarint(NSMutableData *data, uint64_t value) {
    while (value >= 0x80) {
        uint8_t byte = (value & 0x7f) | 0x80;
        [data appendBytes:&byte length:1];
        value >>= 7;
    }
    uint8_t byte = value;
    [data appendBytes:&byte length:1];
}

NSMutableArray<ASMVitrinePBField *> *ASMVitrinePBParse(NSData *data) {
    const uint8_t *bytes = data.bytes;
    NSUInteger length = data.length, at = 0;
    NSMutableArray<ASMVitrinePBField *> *fields = [NSMutableArray array];
    while (at < length) {
        uint64_t key, value;
        if (!readVarint(bytes, length, &at, &key) || !(key >> 3)) return nil;
        ASMVitrinePBField *field = [ASMVitrinePBField new];
        field.number = (uint32_t)(key >> 3);
        field.wire = key & 7;
        NSUInteger size;
        switch (field.wire) {
            case 0:
                if (!readVarint(bytes, length, &at, &value)) return nil;
                field.varint = value;
                break;
            case 1: case 5:
                size = field.wire == 1 ? 8 : 4;
                if (at + size > length) return nil;
                field.payload = [NSData dataWithBytes:bytes + at length:size];
                at += size;
                break;
            case 2:
                // Against what is left rather than added to `at`: a length near 2^64 wraps the sum.
                if (!readVarint(bytes, length, &at, &value) || value > length - at) return nil;
                field.payload = [NSData dataWithBytes:bytes + at length:(NSUInteger)value];
                at += value;
                break;
            default:
                return nil;
        }
        [fields addObject:field];
    }
    return fields;
}

NSData *ASMVitrinePBSerialize(NSArray<ASMVitrinePBField *> *fields) {
    NSMutableData *data = [NSMutableData data];
    for (ASMVitrinePBField *field in fields) {
        appendVarint(data, ((uint64_t)field.number << 3) | field.wire);
        if (field.wire == 0) {
            appendVarint(data, field.varint);
            continue;
        }
        if (field.wire == 2) appendVarint(data, field.payload.length);
        [data appendData:field.payload];
    }
    return data;
}

ASMVitrinePBField *ASMVitrinePBFirst(NSArray<ASMVitrinePBField *> *fields, uint32_t number) {
    for (ASMVitrinePBField *field in fields) {
        if (field.number == number) return field;
    }
    return nil;
}

ASMVitrinePBField *ASMVitrinePBVarint(uint32_t number, uint64_t value) {
    ASMVitrinePBField *field = [ASMVitrinePBField new];
    field.number = number;
    field.varint = value;
    return field;
}

ASMVitrinePBField *ASMVitrinePBBytes(uint32_t number, NSData *payload) {
    ASMVitrinePBField *field = [ASMVitrinePBField new];
    field.number = number;
    field.wire = 2;
    field.payload = payload ?: [NSData data];
    return field;
}

ASMVitrinePBField *ASMVitrinePBString(uint32_t number, NSString *text) {
    return ASMVitrinePBBytes(number, [text dataUsingEncoding:NSUTF8StringEncoding]);
}

NSString *ASMVitrinePBText(ASMVitrinePBField *field) {
    if (!field || field.wire != 2) return nil;
    return [[NSString alloc] initWithData:field.payload encoding:NSUTF8StringEncoding];
}

NSData *ASMVitrinePBEdit(NSData *message, NSArray<NSNumber *> *path, NSData *(^edit)(NSData *inner)) {
    if (!path.count) return edit(message);
    NSMutableArray<ASMVitrinePBField *> *fields = ASMVitrinePBParse(message);
    ASMVitrinePBField *field = ASMVitrinePBFirst(fields, path.firstObject.unsignedIntValue);
    if (!field || field.wire != 2) return nil;
    NSData *inner = ASMVitrinePBEdit(field.payload, [path subarrayWithRange:NSMakeRange(1, path.count - 1)], edit);
    if (!inner) return nil;
    field.payload = inner;
    return ASMVitrinePBSerialize(fields);
}
