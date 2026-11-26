#import <Foundation/Foundation.h>
#import "../PurePetsPro/AdminCore/Models/PPProSessionFence.h"
static void check(BOOL ok, const char *name) { if (!ok) { fprintf(stderr,"FAIL %s\n",name); exit(1); } printf("PASS %s\n",name); }
int main(void) { @autoreleasepool {
 PPProSessionFence *f=[PPProSessionFence shared];
 check(f == [PPProSessionFence shared], "all services share one epoch");
 NSObject *a=[NSObject new], *b=[NSObject new];
 [f observeActiveUID:@"A" identity:a];
 NSUUID *first=[f captureForUID:@"A" activeUID:@"A" identity:a];
 [f observeActiveUID:@"B" identity:b];
 [f observeActiveUID:@"A" identity:a];
 check(![f accepts:first requestedUID:@"A" activeUID:@"A" identity:a], "observed A-B-A rejects old work even with reused identity object");
 NSUUID *current=[f captureForUID:@"A" activeUID:@"A" identity:a];
 [f observeActiveUID:@"A" identity:a];
 check([f accepts:current requestedUID:@"A" activeUID:@"A" identity:a], "duplicate auth event keeps epoch");
 [f observeActiveUID:nil identity:nil];
 [f observeActiveUID:@"A" identity:a];
 check(![f accepts:current requestedUID:@"A" activeUID:@"A" identity:a], "signed-out event invalidates same UID work");
} return 0; }
