#import <Foundation/Foundation.h>
#import "../PurePetsPro/AdminCore/Models/PPProAccountTransitionCoordinator.h"
@interface TestJournal : NSObject <PPProTransitionJournal>
@property(nonatomic,copy) NSDictionary *record;
@property(nonatomic) BOOL failWrites;
@property(nonatomic) BOOL failReads;
@end
@implementation TestJournal
- (NSDictionary *)readRecord:(NSError **)error {
 if(self.failReads){if(error)*error=[NSError errorWithDomain:@"Test" code:1 userInfo:nil]; return nil;} return self.record;
}
- (BOOL)writeRecord:(NSDictionary *)record error:(NSError **)error {
 if(self.failWrites){if(error)*error=[NSError errorWithDomain:@"Test" code:2 userInfo:nil]; return NO;} self.record=record;return YES;
}
@end
static void check(BOOL ok,const char *name){if(!ok){fprintf(stderr,"FAIL %s\n",name);exit(1);}printf("PASS %s\n",name);}
int main(void){ @autoreleasepool {
 TestJournal *j=[TestJournal new];
 PPProAccountTransitionCoordinator *c=[[PPProAccountTransitionCoordinator alloc] initWithJournal:j];
 check(c.phase==PPProTransitionIdle,"fresh journal idle");
 j.failWrites=YES;
 check([c beginFromUID:@"A" targetUID:@"B" error:nil]==nil && c.phase==PPProTransitionIdle,"no transition if initial journal write fails");
 j.failWrites=NO;
 NSUUID *ticket=[c beginFromUID:@"A" targetUID:@"B" error:nil];
 check(ticket && j.record!=nil && c.phase==PPProTransitionPreflight,"begin persists journal before transition");
 check([c beginFromUID:@"A" targetUID:@"C" error:nil]==nil,"reject concurrent switch");
 check(![c advance:ticket toPhase:PPProTransitionAuthenticating verifiedUID:nil error:nil],"reject skipped suspension");
 check(![c advance:[NSUUID UUID] toPhase:PPProTransitionSuspended verifiedUID:nil error:nil],"reject unrelated ticket");
 check([c cancelPreflight:ticket error:nil] && !j.record && c.phase==PPProTransitionIdle,"preflight cancellation clears journal");
 ticket=[c beginFromUID:@"A" targetUID:@"B" error:nil];
 check([c advance:ticket toPhase:PPProTransitionSuspended verifiedUID:nil error:nil],"suspension recorded");
 check(![c cancelPreflight:ticket error:nil],"no unsafe cancel after suspension");
 PPProAccountTransitionCoordinator *restarted=[[PPProAccountTransitionCoordinator alloc] initWithJournal:j];
 check(restarted.phase==PPProTransitionRecoveryRequired,"restart with journal locks recovery");
 check([c advance:ticket toPhase:PPProTransitionAuthenticating verifiedUID:nil error:nil],"authentication stage recorded");
 check(![c advance:ticket toPhase:PPProTransitionAuthorized verifiedUID:@"C" error:nil] && c.phase==PPProTransitionRecoveryRequired,"wrong account forces recovery");
 check(![c commit:ticket verifiedUID:@"B" error:nil],"recovery cannot commit");
 check([c clearAfterVerifiedSignOut:nil] && c.phase==PPProTransitionIdle && !j.record,"verified sign-out clears recovery");
 ticket=[c beginFromUID:@"A" targetUID:@"B" error:nil];
 check([c advance:ticket toPhase:PPProTransitionSuspended verifiedUID:nil error:nil],"suspend second attempt");
 check([c advance:ticket toPhase:PPProTransitionAuthenticating verifiedUID:nil error:nil],"authenticate second attempt");
 check([c advance:ticket toPhase:PPProTransitionAuthorized verifiedUID:@"B" error:nil],"verified target authorized");
 check([c advance:ticket toPhase:PPProTransitionInstalled verifiedUID:@"B" error:nil],"verified target runtime installed");
 j.failWrites=YES;
 check(![c commit:ticket verifiedUID:@"B" error:nil] && c.phase==PPProTransitionRecoveryRequired && j.record,"journal failure prevents release");
 j.failWrites=NO;
 check([c clearAfterVerifiedSignOut:nil],"recover after journal failure");
 ticket=[c beginFromUID:@"A" targetUID:@"B" error:nil];
 check([c advance:ticket toPhase:PPProTransitionSuspended verifiedUID:nil error:nil] && [c advance:ticket toPhase:PPProTransitionAuthenticating verifiedUID:nil error:nil] && [c advance:ticket toPhase:PPProTransitionAuthorized verifiedUID:@"B" error:nil] && [c advance:ticket toPhase:PPProTransitionInstalled verifiedUID:@"B" error:nil],"ordered successful switch");
 check([c commit:ticket verifiedUID:@"B" error:nil] && !j.record && c.phase==PPProTransitionIdle,"commit clears journal only after verified install");
 j.failReads=YES;
 PPProAccountTransitionCoordinator *unreadable=[[PPProAccountTransitionCoordinator alloc] initWithJournal:j];
 check(unreadable.phase==PPProTransitionRecoveryRequired,"unreadable journal fails closed");
 } return 0; }
