#import <Foundation/Foundation.h>
#import "../PurePetsPro/AdminCore/Models/PPProRememberedAccountStore.h"

static void check(BOOL value, NSString *label) {
    if (!value) { fprintf(stderr,"FAIL %s\n",label.UTF8String); exit(1); }
    printf("PASS %s\n",label.UTF8String);
}
int main(void) {
    @autoreleasepool {
        NSArray *a = [PPProRememberedAccountStore recordsByRememberingUID:@"A" label:@"a***@example.com" method:@"google.com" inRecords:@[]];
        check(a.count == 1, @"first identity remembered");
        NSArray *b = [PPProRememberedAccountStore recordsByRememberingUID:@"B" label:@"••••1234" method:@"phone" inRecords:a];
        check(b.count == 2 && [b[0][@"uid"] isEqual:@"B"], @"different account kept separately");
        NSArray *again = [PPProRememberedAccountStore recordsByRememberingUID:@"A" label:@"a***@example.com" method:@"apple.com" inRecords:b];
        check(again.count == 2 && [again[0][@"uid"] isEqual:@"A"] && [again[0][@"method"] isEqual:@"apple.com"], @"same UID deduplicated");
        NSArray *bad = [PPProRememberedAccountStore recordsByRememberingUID:@"" label:@"test" method:@"phone" inRecords:again];
        check([bad isEqual:again], @"invalid UID rejected");
        bad = [PPProRememberedAccountStore recordsByRememberingUID:@"C" label:@"test" method:@"unknown" inRecords:again];
        check([bad isEqual:again], @"unsupported method rejected");
        NSArray *many = @[];
        for (NSUInteger i=0;i<20;i++) many = [PPProRememberedAccountStore recordsByRememberingUID:[NSString stringWithFormat:@"%lu",(unsigned long)i] label:@"masked" method:@"phone" inRecords:many];
        check(many.count == 8, @"bounded registry");
        NSArray *removed = [PPProRememberedAccountStore recordsByRemovingUID:@"A" inRecords:again];
        check(removed.count == 1 && [removed[0][@"uid"] isEqual:@"B"], @"remove only selected identity");
        check([PPProRememberedAccountStore maskedLabelForPhone:@"+201234567890" email:nil].length > 0 &&
              ![[PPProRememberedAccountStore maskedLabelForPhone:@"+201234567890" email:nil] containsString:@"+201234567890"], @"never store full phone label");
        check(![[PPProRememberedAccountStore maskedLabelForPhone:nil email:@"private@example.com"] containsString:@"private@example.com"], @"never store full email label");
        check([PPProRememberedAccountStore recordsByRememberingUID:@"A" label:@"masked" method:@"phone" inRecords:@[@{@"uid":@"B",@"label":@"masked",@"method":@"phone",@"token":@"do-not-keep"}]][1][@"token"] == nil, @"unexpected fields cannot survive normalization");
    }
    return 0;
}