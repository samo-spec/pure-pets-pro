#import <Foundation/Foundation.h>
#import "../PurePetsPro/AdminCore/Models/PPProRememberedAccountStore.h"
static void check(BOOL x,const char *n){if(!x){fprintf(stderr,"FAIL %s\n",n);exit(1);}printf("PASS %s\n",n);}
int main(void){ @autoreleasepool {
 NSUUID *a=[NSUUID UUID], *b=[NSUUID UUID];
 NSArray *records=@[];
 records=[PPProRememberedAccountStore recordsByRememberingUID:@"A" label:@"•••• 1111" method:@"phone" slotID:a inRecords:records];
 records=[PPProRememberedAccountStore recordsByRememberingUID:@"B" label:@"b•••@example.invalid" method:@"google.com" slotID:b inRecords:records];
 check(records.count==2 && [records[0][@"slotID"] isEqual:b.UUIDString] && [records[1][@"slotID"] isEqual:a.UUIDString],"distinct identities keep independent slot identifiers");
 NSArray *again=[PPProRememberedAccountStore recordsByRememberingUID:@"A" label:@"•••• 1111" method:@"apple.com" inRecords:records];
 check([again[0][@"slotID"] isEqual:a.UUIDString],"metadata update preserves existing slot");
 check([[PPProRememberedAccountStore recordsByRememberingUID:@"C" label:@"x" method:@"phone" slotID:a inRecords:records] isEqual:records],"one slot cannot be assigned to multiple identities");
 check([[PPProRememberedAccountStore recordsByRememberingUID:@"A" label:@"x" method:@"phone" slotID:b inRecords:records] isEqual:records],"existing identity cannot steal another slot");
 NSArray *bad=@[@{@"uid":@"A",@"label":@"masked",@"method":@"phone",@"slotID":@"invalid"},@{@"uid":@"B",@"label":@"masked",@"method":@"phone",@"slotID":a.UUIDString},@{@"uid":@"C",@"label":@"masked",@"method":@"phone",@"slotID":a.UUIDString}];
 NSArray *clean=[PPProRememberedAccountStore recordsByRemovingUID:@"X" inRecords:bad];
 check(clean.count==2 && !clean[0][@"slotID"],"invalid slot downgraded to hint; duplicate slot record rejected");
 check([[PPProRememberedAccountStore firebaseAppNameForSlotID:a] hasPrefix:@"pppro_slot_"] && [[PPProRememberedAccountStore firebaseAppNameForSlotID:a] rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"] invertedSet]].location==NSNotFound,"slot app name uses Firebase-supported alphabet");
 check(![[PPProRememberedAccountStore firebaseAppNameForSlotID:a] isEqual:[PPProRememberedAccountStore firebaseAppNameForSlotID:b]],"unique slot namespace");
 }return 0;}
