#import "PPProFirebaseAccountRuntime.h"
#import "PPFirebaseCompat.h"
#import "PPProRememberedAccountStore.h"

static NSError *PPSlotError(NSInteger code) {
    return [NSError errorWithDomain:@"PPProFirebaseAccountRuntime" code:code userInfo:nil];
}
static void PPSlotAssignError(NSError **error, NSInteger code) {
    if (error) *error = PPSlotError(code);
}

@interface PPProFirebaseAccountRuntime ()
@property(nonatomic,strong,readwrite) NSUUID *slotID;
@property(nonatomic,copy,readwrite,nullable) NSString *expectedUID;
@property(nonatomic,strong,readwrite) FIRAuth *auth;
@property(nonatomic,strong) FIRApp *app;
@property(nonatomic,strong,nullable) NSUUID *authAttempt;
@property(nonatomic) BOOL invalidated;
- (instancetype)initWithApp:(FIRApp *)app slotID:(NSUUID *)slotID expectedUID:(nullable NSString *)expectedUID;
@end

@implementation PPProFirebaseAccountRuntime
- (instancetype)initWithApp:(FIRApp *)app slotID:(NSUUID *)slotID expectedUID:(NSString *)expectedUID {
    if ((self = [super init])) {
        _app = app; _slotID = slotID; _expectedUID = [expectedUID copy];
        _auth = [FIRAuth authWithApp:app];
    }
    return self;
}
+ (instancetype)openSlot:(NSUUID *)slotID expectedUID:(NSString *)expectedUID error:(NSError **)error {
    // Do not initialize a production named app before the entire rollout is qualified.
    if (![PPProRememberedAccountStore rolloutEnabled] || !NSThread.isMainThread || !slotID) {
        PPSlotAssignError(error,1); return nil;
    }
    FIRApp *referenceApp = [FIRApp defaultApp];
    if (!referenceApp) { PPSlotAssignError(error,2); return nil; }
    NSString *name = [PPProRememberedAccountStore firebaseAppNameForSlotID:slotID];
    FIRApp *app = [FIRApp appNamed:name];
    if (!app) {
        [FIRApp configureWithName:name options:referenceApp.options];
        app = [FIRApp appNamed:name];
    }
    if (!app || app == referenceApp ||
        ![app.options.googleAppID isEqualToString:referenceApp.options.googleAppID] ||
        ![app.options.projectID isEqualToString:referenceApp.options.projectID]) {
        PPSlotAssignError(error,2); return nil;
    }
    app.dataCollectionDefaultEnabled = NO;
    PPProFirebaseAccountRuntime *runtime = [[self alloc] initWithApp:app slotID:slotID expectedUID:expectedUID];
    if (!runtime.auth) { PPSlotAssignError(error,2); return nil; }
    return runtime;
}
+ (instancetype)openRememberedUID:(NSString *)uid error:(NSError **)error {
    if (!uid.length) { PPSlotAssignError(error,3); return nil; }
    NSArray *records = [PPProRememberedAccountStore recordsWithError:error];
    if (!records) return nil;
    for (NSDictionary *record in records) {
        if ([record[@"uid"] isEqual:uid] && record[@"slotID"]) {
            NSUUID *slotID = [[NSUUID alloc] initWithUUIDString:record[@"slotID"]];
            return [self openSlot:slotID expectedUID:uid error:error];
        }
    }
    PPSlotAssignError(error,3); return nil;
}
+ (instancetype)createProvisionalSlotWithError:(NSError **)error {
    return [self openSlot:[NSUUID UUID] expectedUID:nil error:error];
}
- (FIRPhoneAuthProvider *)phoneProvider { return [FIRPhoneAuthProvider providerWithAuth:self.auth]; }
- (NSString *)currentUID {
    return self.auth.currentUser.uid;
}
- (BOOL)ownsCurrentUser {
    return !self.invalidated && self.expectedUID.length &&
        [self.auth.currentUser.uid isEqualToString:self.expectedUID];
}
- (BOOL)isAuthorizedSession {
    return [self ownsCurrentUser];
}
- (BOOL)isInvalidated {
    return self.invalidated;
}
- (BOOL)hasMismatchedSignedInUser {
    NSString *current = self.auth.currentUser.uid;
    return self.expectedUID.length > 0 && current.length > 0 && ![current isEqualToString:self.expectedUID];
}
// Firestore SDK uses FirebaseApp.name as its persistence key. No default-app fallback.
- (FIRFirestore *)firestore { return [self ownsCurrentUser] ? [FIRFirestore firestoreForApp:self.app] : nil; }
- (FIRFunctions *)functions { return [self ownsCurrentUser] ? [FIRFunctions functionsForApp:self.app region:@"us-central1"] : nil; }
- (FIRStorage *)storage { return [self ownsCurrentUser] ? [FIRStorage storageForApp:self.app] : nil; }
- (void)authenticateCredential:(FIRAuthCredential *)credential completion:(void (^)(FIRUser *, NSError *))completion {
    if (!NSThread.isMainThread || self.invalidated || self.authAttempt || !credential) {
        if (completion) completion(nil,PPSlotError(4)); return;
    }
    NSUUID *attempt = [NSUUID UUID];
    self.authAttempt = attempt;
    [self.auth signInWithCredential:credential completion:^(FIRAuthDataResult *result, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (![self.authAttempt isEqual:attempt]) { if (completion) completion(nil,PPSlotError(4)); return; }
            self.authAttempt = nil;
            FIRUser *user = result.user;
            if (error || !user.uid.length || self.auth.currentUser != user) {
                if (completion) completion(nil,error ?: PPSlotError(5)); return;
            }
            if (self.expectedUID.length && ![self.expectedUID isEqualToString:user.uid]) {
                // The slot has the wrong identity; it cannot expose any data service.
                self.invalidated = YES;
                NSError *logoutError = nil;
                [self.auth signOut:&logoutError];
                if (completion) completion(nil,logoutError ?: PPSlotError(6));
                return;
            }
            self.expectedUID = user.uid;
            if (completion) completion(user,nil);
        });
    }];
}
- (void)validateSessionWithCompletion:(void (^)(FIRUser *, NSError *))completion {
    FIRUser *user = self.auth.currentUser;
    if (![self ownsCurrentUser] || !user) {
        if (completion) completion(nil,PPSlotError(5)); return;
    }
    [user getIDTokenResultForcingRefresh:YES completion:^(FIRAuthTokenResult *result, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error || !result || self.auth.currentUser != user || ![self ownsCurrentUser]) {
                if (completion) completion(nil,error ?: PPSlotError(5)); return;
            }
            if (completion) completion(user,nil);
        });
    }];
}
- (void)waitForPendingWritesWithCompletion:(void (^)(NSError *))completion {
    FIRFirestore *db = self.firestore;
    if (!db) { if (completion) completion(PPSlotError(5)); return; }
    FIRUser *user = self.auth.currentUser;
    [db waitForPendingWritesWithCompletion:^(NSError *error) {
        if (completion) completion(error ?: ((self.auth.currentUser == user && [self ownsCurrentUser]) ? nil : PPSlotError(5)));
    }];
}
- (void)signOutAndInvalidate:(BOOL)invalidate completion:(void (^)(NSError *))completion {
    void (^work)(void) = ^{
        if (invalidate) {
            self.invalidated = YES;
            self.authAttempt = nil;
        }
        NSError *logoutError = nil;
        BOOL ok = YES;
        if (self.auth.currentUser != nil) {
            ok = [self.auth signOut:&logoutError];
        }
        if (completion) completion(ok ? nil : (logoutError ?: PPSlotError(7)));
    };
    if (NSThread.isMainThread) work();
    else dispatch_async(dispatch_get_main_queue(), work);
}
- (void)teardownSlotAppWithCompletion:(void (^)(BOOL, NSError *))completion {
    void (^finish)(BOOL, NSError *) = ^(BOOL deleted, NSError *err) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(deleted, err);
        });
    };
    void (^work)(void) = ^{
        if (!self.app || self.app == [FIRApp defaultApp]) {
            finish(NO, PPSlotError(2));
            return;
        }
        void (^deleteAfterSignOut)(void) = ^{
            [self signOutAndInvalidate:YES completion:^(NSError *signOutError) {
                if (signOutError) {
                    finish(NO, signOutError);
                    return;
                }
                [self.app deleteApp:^(BOOL success) {
                    finish(success, success ? nil : PPSlotError(8));
                }];
            }];
        };
        if ([self ownsCurrentUser]) {
            [self waitForPendingWritesWithCompletion:^(NSError *writeError) {
                if (writeError) {
                    finish(NO, writeError);
                    return;
                }
                deleteAfterSignOut();
            }];
        } else {
            deleteAfterSignOut();
        }
    };
    if (NSThread.isMainThread) work();
    else dispatch_async(dispatch_get_main_queue(), work);
}
@end
