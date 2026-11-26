#import <Foundation/Foundation.h>
#import "../PurePetsPro/AdminCore/Models/PPProSessionFence.h"

static void check(BOOL condition, NSString *name) {
    if (!condition) { fprintf(stderr, "FAIL %s\n", name.UTF8String); exit(1); }
    printf("PASS %s\n", name.UTF8String);
}
int main(void) {
    @autoreleasepool {
        PPProSessionFence *fence = [PPProSessionFence new];
        NSObject *a = [NSObject new], *b = [NSObject new], *a2 = [NSObject new];
        NSUUID *a1 = [fence captureForUID:@"A" activeUID:@"A" identity:a];
        check(a1 != nil, @"active identity can capture generation");
        check([fence accepts:a1 requestedUID:@"A" activeUID:@"A" identity:a], @"same session accepted");
        check(![fence accepts:a1 requestedUID:@"A" activeUID:@"B" identity:b], @"different UID rejected");
        NSUUID *b1 = [fence captureForUID:@"B" activeUID:@"B" identity:b];
        check(b1 != nil, @"new account has its own generation");
        NSUUID *a3 = [fence captureForUID:@"A" activeUID:@"A" identity:a2];
        check(![fence accepts:a1 requestedUID:@"A" activeUID:@"A" identity:a2], @"A-B-A stale callback rejected");
        check([fence accepts:a3 requestedUID:@"A" activeUID:@"A" identity:a2], @"new A session accepted");
        [fence invalidate];
        check(![fence accepts:a3 requestedUID:@"A" activeUID:@"A" identity:a2], @"logout invalidates outstanding work");
        check([fence captureForUID:@"B" activeUID:@"A" identity:a2] == nil, @"foreign UID cannot capture");
        check([fence captureForUID:@"A" activeUID:nil identity:nil] == nil, @"signed out cannot capture");
        check([fence captureForUID:@"" activeUID:@"" identity:a] == nil, @"empty UID rejected");
    }
    return 0;
}