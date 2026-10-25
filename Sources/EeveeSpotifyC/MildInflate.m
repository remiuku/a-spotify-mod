#import "include/Tweak.h"
#include <zlib.h>

NSData *EeveeMildInflate(NSData *data) {
    if (!data.length || data.length > 4 * 1024 * 1024) return nil;
    z_stream stream = {0};
    stream.next_in = (Bytef *)data.bytes;
    stream.avail_in = (uInt)data.length;
    if (inflateInit(&stream) != Z_OK) return nil;
    NSMutableData *out = [NSMutableData data];
    uint8_t buffer[16384]; int status = Z_OK;
    while (status == Z_OK && out.length < 4 * 1024 * 1024) {
        stream.next_out = buffer; stream.avail_out = sizeof(buffer);
        status = inflate(&stream, Z_NO_FLUSH);
        [out appendBytes:buffer length:sizeof(buffer) - stream.avail_out];
    }
    inflateEnd(&stream);
    return status == Z_STREAM_END ? out : nil;
}
