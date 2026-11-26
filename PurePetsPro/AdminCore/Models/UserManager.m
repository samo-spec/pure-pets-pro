
// In UserManager.m
// NOTE: uses collection name "UsersCol" as per your project

#import "UserManager.h"
#import "PPFirebaseCompat.h"
#import "PPRolePermission.h"
#import "Lottie.h"
#import "UIImageView+WebCache.h"
#import "AppDelegate.h"
#import "PPProSessionFence.h"

@interface AppDelegate (PPNotificationV2LogoutBarrier)
- (void)pp_beginNotificationV2LogoutBarrierWithCompletion:(dispatch_block_t)completion;
- (void)pp_endNotificationV2LogoutBarrier;
- (void)pp_abortNotificationV2LogoutBarrierAndRefreshForReason:(NSString *)reason;
@end

static AppDelegate *PPProNotificationV2AppDelegate(void)
{
    id<UIApplicationDelegate> delegate = UIApplication.sharedApplication.delegate;
    return [delegate isKindOfClass:AppDelegate.class] ? (AppDelegate *)delegate : nil;
}

static UIViewController *PPProUserManagerTopViewController(void)
{
    UIWindow *window = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        UIWindowScene *windowScene = (UIWindowScene *)scene;
        for (UIWindow *candidate in windowScene.windows) {
            if (candidate.isKeyWindow) {
                window = candidate;
                break;
            }
        }
        if (window) break;
    }

    UIViewController *controller = window.rootViewController;
    while (controller.presentedViewController) {
        controller = controller.presentedViewController;
    }
    if ([controller isKindOfClass:UINavigationController.class]) {
        controller = ((UINavigationController *)controller).topViewController ?: controller;
    } else if ([controller isKindOfClass:UITabBarController.class]) {
        controller = ((UITabBarController *)controller).selectedViewController ?: controller;
    }
    return controller;
}

NSString * const UserManagerAuthStateDidChangeNotification = @"UserManagerAuthStateDidChangeNotification";
NSString * const LanguageDidChangeNotification = @"LanguageDidChangeNotification";

@interface UserManager ()

@property (nonatomic, strong) NSCache<NSString *, UserModel *> *userCache;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSDate *> *userCacheAges;
@property (nonatomic, strong) dispatch_queue_t cacheQueue; // thread-safety for disk ops
@property (nonatomic, assign) BOOL signOutInProgress;
@property (nonatomic, strong) PPProSessionFence *sessionFence;
@property (nonatomic, strong, nullable) NSUUID *userListenerGeneration;
- (void)p_queryUsersColField:(NSString *)field
                     equalTo:(NSString *)value
          tryServerThenCache:(BOOL)serverFirst
                  completion:(void(^)(UserModel * _Nullable user, NSError * _Nullable error))completion;
- (FIRDocumentReference *)_userDoc:(NSString *)uid;
- (void)pp_updateAdminAccessForUID:(NSString *)uid
                          role:(NSNumber * _Nullable)role
                       isAdmin:(BOOL)isAdmin
                  isSuperAdmin:(NSNumber * _Nullable)isSuperAdmin
                    completion:(void(^)(NSError * _Nullable error))completion;

@end



@implementation UserManager

- (instancetype)init {
    if ((self = [super init])) {
        
        
        _sessionFence = [PPProSessionFence shared];
        _userCache = [NSCache new];
        _userCache.countLimit = 500;

        _userCacheAges = [NSMutableDictionary new];
        _cacheQueue = dispatch_queue_create("com.purepets.usercache.q", DISPATCH_QUEUE_SERIAL);

        _userCacheTTL = 5 * 60; // 5 minutes default
        __weak typeof(self) weakSelf = self;
        [PPProSessionCoordinator.shared registerSessionTeardownHandler:^(__unused NSString *reason) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            [strongSelf clearUserCache];
            [strongSelf stopListening];
            strongSelf.currentUser = nil;
        } forKey:@"UserManager"];
    }
    return self;
}

// Bind each profile operation to the current Firebase identity and session epoch.
- (NSUUID * _Nullable)pp_captureSessionForUID:(NSString *)uid {
    FIRUser *active = [PPProSessionCoordinator.shared currentUser];
    if (self.signOutInProgress) return nil;
    return [self.sessionFence captureForUID:uid activeUID:active.uid identity:active];
}

- (BOOL)pp_sessionAllows:(NSUUID * _Nullable)generation uid:(NSString *)uid {
    FIRUser *active = [PPProSessionCoordinator.shared currentUser];
    return !self.signOutInProgress &&
           [self.sessionFence accepts:generation requestedUID:uid activeUID:active.uid identity:active];
}

- (BOOL)pp_model:(UserModel *)model belongsToUID:(NSString *)uid {
    NSString *modelUID = PPSafeString(model.uid.length ? model.uid : model.ID);
    return model && modelUID.length && [modelUID isEqualToString:uid];
}

- (NSError *)pp_invalidProfileSessionError {
    return [NSError errorWithDomain:@"UserManager" code:401
                           userInfo:@{NSLocalizedDescriptionKey: @"Profile session is no longer active"}];
}

- (void)fetchAdminWithUID:(NSString *)uid cachePolicy:(PPUserCachePolicy)policy completion:(void (^)(UserModel * _Nullable, NSError * _Nullable))completion
{
    NSString *resolvedUID = PPSafeString(uid);
    if (resolvedUID.length == 0) {
        resolvedUID = PPSafeString([PPProSessionCoordinator.shared activeUID]);
    }

    if (!resolvedUID.length) {
        if (completion) {
            completion(nil, [NSError errorWithDomain:@"UserManager"
                                                code:-1
                                            userInfo:@{NSLocalizedDescriptionKey:@"Missing uid"}]);
        }
        return;
    }

    NSUUID *generation = [self pp_captureSessionForUID:resolvedUID];
    if (![self pp_sessionAllows:generation uid:resolvedUID]) {
        if (completion) completion(nil, [self pp_invalidProfileSessionError]);
        return;
    }

    switch (policy) {
        case PPUserCachePolicyCacheOnly: {
            UserModel *cached = [self.userCache objectForKey:resolvedUID];
            if (!cached) {
                cached = [self p_readUserFromDisk:resolvedUID];
            }
            if (![self pp_sessionAllows:generation uid:resolvedUID]) { if (completion) completion(nil, [self pp_invalidProfileSessionError]); return; }
            if (cached && ![self pp_model:cached belongsToUID:resolvedUID]) cached = nil;
            if (cached) {
                [self p_cacheUser:cached];
                self.currentUser = cached;
            }
            if (completion) completion(cached, nil);
            return;
        }
        case PPUserCachePolicyServerOnly: {
            [self p_queryUsersColField:@"uid" equalTo:resolvedUID tryServerThenCache:NO completion:^(UserModel * _Nullable user, NSError * _Nullable error) {
                if (![self pp_sessionAllows:generation uid:resolvedUID]) { if (completion) completion(nil, [self pp_invalidProfileSessionError]); return; }
                if (user && ![self pp_model:user belongsToUID:resolvedUID]) {
                    if (completion) completion(nil, [self pp_invalidProfileSessionError]);
                    return;
                }
                if (error) {
                    if (completion) completion(nil, error);
                    return;
                }
                if (user) {
                    [self p_cacheUser:user];
                    self.currentUser = user;
                    if (completion) completion(user, nil);
                    return;
                }

                [[self _userDoc:resolvedUID] getDocumentWithSource:FIRFirestoreSourceServer completion:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable docError) {
                    if (![self pp_sessionAllows:generation uid:resolvedUID]) { if (completion) completion(nil, [self pp_invalidProfileSessionError]); return; }
                    if (docError) {
                        if (completion) completion(nil, docError);
                        return;
                    }
                    if (!snapshot.exists) {
                        if (completion) completion(nil, nil);
                        return;
                    }

                    UserModel *docUser = [[UserModel alloc] initWithSnapshot:snapshot];
                    if (docUser && ![self pp_model:docUser belongsToUID:resolvedUID]) {
                        if (completion) completion(nil, [self pp_invalidProfileSessionError]);
                        return;
                    }
                    if (docUser) {
                        [self p_cacheUser:docUser];
                        self.currentUser = docUser;
                    }
                    if (completion) completion(docUser, nil);
                }];
            }];
            return;
        }
        case PPUserCachePolicyMemoryFirstThenServer:
        default:
            [self loadUserByUIDOrID:resolvedUID completion:completion];
            return;
    }
}

- (void)loadUserByUIDOrID:(NSString *)uid
               completion:(void(^)(UserModel * _Nullable user, NSError * _Nullable error))completion
{
    
    
    NSUUID *generation = [self pp_captureSessionForUID:uid];
    if (![self pp_sessionAllows:generation uid:uid]) {
        if (completion) completion(nil, [self pp_invalidProfileSessionError]);
        return;
    }

    [self p_queryUsersColField:@"uid" equalTo:uid tryServerThenCache:YES completion:^(UserModel * _Nullable user, NSError * _Nullable error) {
       
        if (![self pp_sessionAllows:generation uid:uid]) { if (completion) completion(nil, [self pp_invalidProfileSessionError]); return; }
        if (user && ![self pp_model:user belongsToUID:uid]) {
            if (completion) completion(nil, [self pp_invalidProfileSessionError]);
            return;
        }
        if (error) { if (completion) completion(nil, error); return; }
        if (!user) {
            [[self _userDoc:uid] getDocumentWithSource:FIRFirestoreSourceServer completion:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable docError) {
                if (![self pp_sessionAllows:generation uid:uid]) { if (completion) completion(nil, [self pp_invalidProfileSessionError]); return; }
                if (docError) {
                    if (completion) completion(nil, docError);
                    return;
                }
                if (!snapshot.exists) {
                    if (completion) completion(nil, nil);
                    return;
                }

                UserModel *docUser = [[UserModel alloc] initWithSnapshot:snapshot];
                if (docUser && ![self pp_model:docUser belongsToUID:uid]) {
                    if (completion) completion(nil, [self pp_invalidProfileSessionError]);
                    return;
                }
                if (docUser) {
                    [self p_cacheUser:docUser];
                    self.currentUser = docUser;
                }
                if (completion) completion(docUser, nil);
            }];
            return;
        }
        [self p_cacheUser:user];
        self.currentUser = user;

        DLog(@"[Fetch Admin]query self.currentUser ID == %@", self.currentUser.ID);
        DLog(@"query user m == %@", user.ID);
        
        if (completion) completion(user, nil);
    }];
}

- (void)lookupUserByUIDOrID:(NSString *)uid
                 completion:(void(^)(UserModel * _Nullable user, NSError * _Nullable error))completion
{
    NSString *owner = [PPProSessionCoordinator.shared activeUID];
    NSUUID *generation = [self pp_captureSessionForUID:owner];
    if (![self pp_sessionAllows:generation uid:owner]) {
        if (completion) completion(nil, [self pp_invalidProfileSessionError]);
        return;
    }
    [self p_queryUsersColField:@"uid" equalTo:uid tryServerThenCache:YES completion:^(UserModel * _Nullable user, NSError * _Nullable error) {
        if (![self pp_sessionAllows:generation uid:owner]) {
            if (completion) completion(nil, [self pp_invalidProfileSessionError]);
            return;
        }
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        if (user) {
            if (completion) completion(user, nil);
            return;
        }

        [[self _userDoc:uid] getDocumentWithSource:FIRFirestoreSourceServer completion:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable docError) {
            if (![self pp_sessionAllows:generation uid:owner]) {
                if (completion) completion(nil, [self pp_invalidProfileSessionError]);
                return;
            }
            if (docError) {
                if (completion) completion(nil, docError);
                return;
            }
            if (!snapshot.exists) {
                if (completion) completion(nil, nil);
                return;
            }

            UserModel *docUser = [[UserModel alloc] initWithSnapshot:snapshot];
            if (docUser) [self p_cacheUser:docUser];
            if (completion) completion(docUser, nil);
        }];
    }];
}

/// Private helper that queries UsersCol where {field} == value.
/// If no match, it continues to try field "ID" (only when field was "uid").
/// `tryServerThenCache` performs server fetch, then falls back to cache on error.
- (void)p_queryUsersColField:(NSString *)field
                    equalTo:(NSString *)value
         tryServerThenCache:(BOOL)serverFirst
                 completion:(void(^)(UserModel * _Nullable user, NSError * _Nullable error))completion
{
    NSString *cleanValue = PPSafeString(value);
    if (cleanValue.length == 0) {
        if (completion) {
            completion(nil, [NSError errorWithDomain:@"UserManager"
                                                code:-1
                                            userInfo:@{NSLocalizedDescriptionKey: @"Missing query value"}]);
        }
        return;
    }
    
    // Session restore must read the owner's document before any legacy lookup.
    // Infra allows this GET but denies ordinary providers a UsersCol query.
    if ([field isEqualToString:@"uid"] && [[PPProSessionCoordinator.shared activeUID] isEqualToString:cleanValue]) {
        FIRFirestoreSource source = FIRFirestoreSourceServer;
        [[self _userDoc:cleanValue] getDocumentWithSource:source completion:^(FIRDocumentSnapshot *snapshot, NSError *error) {
            if (![[PPProSessionCoordinator.shared activeUID] isEqualToString:cleanValue]) {
                if (completion) completion(nil, [NSError errorWithDomain:@"UserManager" code:1301 userInfo:nil]);
                return;
            }
            if (error) {
                if (completion) completion(nil, error);
                return;
            }
            UserModel *user = snapshot.exists ? [[UserModel alloc] initWithSnapshot:snapshot] : nil;
            if (completion) completion(user, nil);
        }];
        return;
    }

    NSString *owner = [PPProSessionCoordinator.shared activeUID];
    NSUUID *generation = [self pp_captureSessionForUID:owner];
    if (![self pp_sessionAllows:generation uid:owner]) {
        if (completion) completion(nil, [self pp_invalidProfileSessionError]);
        return;
    }
    FIRFirestore *db = [PPProSessionCoordinator.shared activeFirestore];
    if (!db) {
        if (completion) completion(nil, [self pp_invalidProfileSessionError]);
        return;
    }
    FIRQuery *q = [[[db collectionWithPath:@"UsersCol"] queryWhereField:field isEqualTo:cleanValue] queryLimitedTo:1];
    [q getDocumentsWithSource:FIRFirestoreSourceServer completion:^(FIRQuerySnapshot *snap, NSError *err) {
        if (![self pp_sessionAllows:generation uid:owner]) {
            if (completion) completion(nil, [self pp_invalidProfileSessionError]);
            return;
        }
        if (err) { if (completion) completion(nil, err); return; }
        if (snap.documents.count) {
            UserModel *user = [[UserModel alloc] initWithSnapshot:snap.documents.firstObject];
            if (completion) completion(user, nil);
        } else if ([field isEqualToString:@"uid"]) {
            [self p_queryUsersColField:@"ID" equalTo:cleanValue tryServerThenCache:NO completion:completion];
        } else if (completion) {
            completion(nil, nil);
        }
    }];
}

- (void)fetchUserWithUID:(NSString *)uid
              completion:(void(^)(UserModel * _Nullable user, NSError * _Nullable error))completion
{
    if (!uid.length) {
        if (completion) completion(nil, [NSError errorWithDomain:@"UserManager"
                                                            code:-1
                                                        userInfo:@{NSLocalizedDescriptionKey:@"Missing uid"}]);
        return;
    }
    
    NSString *owner = [PPProSessionCoordinator.shared activeUID];
    NSUUID *generation = [self pp_captureSessionForUID:owner];
    if (![self pp_sessionAllows:generation uid:owner]) {
        if (completion) completion(nil, [self pp_invalidProfileSessionError]);
        return;
    }
    FIRDocumentReference *doc = [self _userDoc:uid];
    if (!doc) {
        if (completion) completion(nil, [self pp_invalidProfileSessionError]);
        return;
    }
    [doc getDocumentWithSource:FIRFirestoreSourceServer completion:^(FIRDocumentSnapshot *snapshot, NSError *err) {
        if (![self pp_sessionAllows:generation uid:owner]) {
            if (completion) completion(nil, [self pp_invalidProfileSessionError]);
            return;
        }
        if (err) { if (completion) completion(nil, err); return; }
        UserModel *model = snapshot.exists ? [[UserModel alloc] initWithSnapshot:snapshot] : nil;
        if (model) [self p_cacheUser:model];
        if (completion) completion(model, nil);
    }];
}

#pragma mark - Cache helpers

- (void)p_cacheUser:(UserModel *)user {
    if (!user) { DLog(@"p_cacheUser: user=nil (skip)"); return; }
    NSString *uid = (user.uid.length ? user.uid : user.ID);
    if (uid.length == 0) { DLog(@"p_cacheUser: uid is empty (skip)"); return; }

    NSUUID *generation = [self pp_captureSessionForUID:uid];
    if (![self pp_sessionAllows:generation uid:uid]) return;
    // Memory
    [self.userCache setObject:user forKey:uid];
    self.userCacheAges[uid] = [NSDate date];
    DLog(@"p_cacheUser: ✅ memory cached uid=%@ (age now)", uid);

    // Disk (async)
    dispatch_async(self.cacheQueue, ^{
        if (![self pp_sessionAllows:generation uid:uid]) return;
        DLog(@"p_cacheUser: ⌛️ disk write begin uid=%@", uid);
        [self p_writeUserToDisk:user forUID:uid];
        [self p_writeUserAgeToDisk:[NSDate date] forUID:uid];
        DLog(@"p_cacheUser: 💾 disk write end uid=%@", uid);
    });
}

- (NSString *)p_userCacheDir {
    NSArray<NSURL *> *dirs = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask];
    NSURL *dir = dirs.firstObject;
    NSURL *pp = [dir URLByAppendingPathComponent:@"PurePetsUserCache" isDirectory:YES];

    NSError *mkErr = nil;
    [[NSFileManager defaultManager] createDirectoryAtURL:pp withIntermediateDirectories:YES attributes:nil error:&mkErr];
    if (mkErr) { DLog(@"p_cacheUser: p_userCacheDir: ❌ createDirectory error=%@", mkErr); }

    // Avoid iCloud backup
    NSError *exErr = nil;
    BOOL ok = [pp setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:&exErr];
    if (!ok || exErr) { DLog(@"p_cacheUser: p_userCacheDir: ⚠️ exclude-from-backup failed: %@", exErr); }

    DLog(@"p_cacheUser: p_userCacheDir: path=%@", pp.path);
    return pp.path;
}

- (NSString *)p_userPathForUID:(NSString *)uid {
    NSString *p = [[self p_userCacheDir] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.archive", uid]];
    return p;
}

- (NSString *)p_agePathForUID:(NSString *)uid {
    NSString *p = [[self p_userCacheDir] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.age", uid]];
    return p;
}

+ (NSDictionary *)sanitizeUserDict:(NSDictionary *)dict {
    NSMutableDictionary *clean = [NSMutableDictionary dictionary];
    [dict enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        if ([obj isKindOfClass:NSNull.class]) {
            clean[key] = @"";
        } else {
            clean[key] = obj;
        }
    }];
    return clean;
}



// Write to disk
- (void)p_writeUserToDisk:(UserModel *)user forUID:(NSString *)uid {
    if (!user || uid.length == 0) { DLog(@"p_cacheUser: p_writeUserToDisk: invalid args (user=%@ uid=%@)", user ? @"non-nil" : @"nil", uid); return; }
    NSUUID *generation = [self pp_captureSessionForUID:uid];
    if (![self pp_sessionAllows:generation uid:uid] || ![self pp_model:user belongsToUID:uid]) return;
    NSString *path = [self p_userPathForUID:uid];
    NSError *err = nil;
    //NSDictionary *safe = [UserManager sanitizeUserDict:user.toDictionary];
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:user
                                         requiringSecureCoding:YES
                                                         error:&err];
    
    if (!data || err) {
        DLog(@"p_cacheUser: p_writeUserToDisk: ❌ archive fail uid=%@ err=%@", uid, err);
        return;
    }

    if (![self pp_sessionAllows:generation uid:uid]) return;
    BOOL ok = [data writeToFile:path options:NSDataWritingAtomic | NSDataWritingFileProtectionCompleteUntilFirstUserAuthentication error:&err];
    if (ok) {
        DLog(@"p_cacheUser: p_writeUserToDisk: ✅ wrote %lu bytes → %@", (unsigned long)data.length, path);
    } else {
        DLog(@"p_cacheUser: p_writeUserToDisk: ❌ write failed → %@", path);
    }
}

- (void)p_writeUserToDiskAsync:(UserModel *)user forUID:(NSString *)uid {
    if (!user || uid.length == 0) return;
    NSString *uidCopy = [uid copy];
    NSUUID *generation = [self pp_captureSessionForUID:uidCopy];
    if (![self pp_sessionAllows:generation uid:uidCopy]) return;
    dispatch_async(self.cacheQueue, ^{
        if ([self pp_sessionAllows:generation uid:uidCopy]) [self p_writeUserToDisk:user forUID:uidCopy];
    });
}

- (nullable UserModel *)p_readUserFromDisk:(NSString *)uid {
    if (!uid.length) return nil;
    NSUUID *generation = [self pp_captureSessionForUID:uid];
    if (![self pp_sessionAllows:generation uid:uid]) return nil;

    UserModel *memCached = [self.userCache objectForKey:uid];
    if (memCached) return [self pp_model:memCached belongsToUID:uid] ? memCached : nil;
    
    NSString *path = [self p_userPathForUID:uid];
    NSError *err = nil;
    NSData *userData = [PPFileHelper safeDataFromFile:path];
    UserModel *u = [NSKeyedUnarchiver unarchivedObjectOfClass:UserModel.class
                                                     fromData:userData
                                                        error:&err];
    if (!u) {
        // Legacy fallback
        NSSet *allowed = [NSSet setWithObjects:
                          [NSDictionary class],
                          [NSMutableDictionary class],
                          [NSString class],
                          [NSNumber class],
                          nil];

        NSDictionary *dict = [NSKeyedUnarchiver unarchivedObjectOfClasses:allowed
                                                                 fromData:userData
                                                                    error:nil];
        if ([dict isKindOfClass:[NSDictionary class]]) {
            DLog(@"[UserManager] ⚠️ Found legacy dict cache, migrating…");
            u = [[UserModel alloc] initWithDict:dict];
            if (u) {
                [self p_writeUserToDiskAsync:u forUID:uid]; // overwrite asynchronously
            }
        }
    }

    if (![self pp_sessionAllows:generation uid:uid] || ![self pp_model:u belongsToUID:uid]) return nil;
    if (u) {
        [self.userCache setObject:u forKey:uid];
    }
    return u;
}

- (void)p_readUserFromDiskAsync:(NSString *)uid completion:(void(^)(UserModel * _Nullable user))completion {
    NSString *uidCopy = [uid copy];
    NSUUID *generation = [self pp_captureSessionForUID:uidCopy];
    if (![self pp_sessionAllows:generation uid:uidCopy]) { if (completion) completion(nil); return; }
    dispatch_async(self.cacheQueue, ^{
        UserModel *diskUser = [self pp_sessionAllows:generation uid:uidCopy] ? [self p_readUserFromDisk:uidCopy] : nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion([self pp_sessionAllows:generation uid:uidCopy] ? diskUser : nil);
        });
    });
}

- (void)p_writeUserAgeToDisk:(NSDate *)date forUID:(NSString *)uid {
    if (!date) { DLog(@"p_cacheUser: p_writeUserAgeToDisk: date=nil (skip)"); return; }
    NSTimeInterval t = date.timeIntervalSince1970;
    NSData *d = [NSData dataWithBytes:&t length:sizeof(t)];
    NSString *path = [self p_agePathForUID:uid];
    BOOL ok = [d writeToFile:path atomically:YES];
    if (ok) {
        DLog(@"p_writeUserAgeToDisk: ✅ wrote age=%.0fs since 1970 → %@", t, path);
    } else {
        DLog(@"p_writeUserAgeToDisk: ❌ write failed → %@", path);
    }
}

- (NSDate *)p_readUserAgeFromDisk:(NSString *)uid {
    NSString *path = [self p_agePathForUID:uid];
    NSData *d = [PPFileHelper safeDataFromFile:path];
    if (!d || d.length != sizeof(NSTimeInterval)) {
        DLog(@"p_cacheUser: p_readUserAgeFromDisk: (nil) no/invalid age file for uid=%@ at %@", uid, path);
        return nil;
    }
    NSTimeInterval t = 0;
    [d getBytes:&t length:sizeof(t)];
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:t];
    DLog(@"p_cacheUser: p_readUserAgeFromDisk: ✅ age file read uid=%@ (age=%.1fs old)", uid, [[NSDate date] timeIntervalSinceDate:date]);
    return date;
}

#pragma mark - Public cache maintenance

- (void)invalidateUserCacheForUID:(NSString *)uid {
    if (!uid.length) { DLog(@"p_cacheUser: invalidateUserCacheForUID: empty uid"); return; }

    [self.userCache removeObjectForKey:uid];
    [self.userCacheAges removeObjectForKey:uid];
    DLog(@"p_cacheUser: invalidateUserCacheForUID: 🧹 memory cleared uid=%@", uid);

    dispatch_async(self.cacheQueue, ^{
        NSError *e1 = nil, *e2 = nil;
        NSString *up = [self p_userPathForUID:uid];
        NSString *ap = [self p_agePathForUID:uid];

        BOOL ok1 = [[NSFileManager defaultManager] removeItemAtPath:up error:&e1];
        BOOL ok2 = [[NSFileManager defaultManager] removeItemAtPath:ap error:&e2];

        DLog(@"p_cacheUser: invalidateUserCacheForUID: disk user=%@ (%@) age=%@ (%@)",
             ok1 ? @"✅ removed" : @"—",
             e1 ? e1.localizedDescription : @"",
             ok2 ? @"✅ removed" : @"—",
             e2 ? e2.localizedDescription : @"");
    });
}

- (void)clearUserCache {
    [self.userCache removeAllObjects];
    [self.userCacheAges removeAllObjects];
    DLog(@"p_cacheUser: clearUserCache: 🧹 memory caches cleared");

    dispatch_async(self.cacheQueue, ^{
        NSString *dir = [self p_userCacheDir];
        NSError *lsErr = nil;
        NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:dir error:&lsErr];
        if (lsErr) {
            DLog(@"p_cacheUser: clearUserCache: ❌ list dir error=%@", lsErr);
            return;
        }
        NSUInteger removed = 0;
        for (NSString *f in files) {
            NSError *rmErr = nil;
            BOOL ok = [[NSFileManager defaultManager] removeItemAtPath:[dir stringByAppendingPathComponent:f] error:&rmErr];
            if (ok) removed++;
            else DLog(@"p_cacheUser: clearUserCache: ⚠️ remove %@ failed: %@", f, rmErr);
        }
        DLog(@"p_cacheUser: clearUserCache: 💾 removed %lu files from %@", (unsigned long)removed, dir);
    });
}


+ (instancetype)shared {
    static UserManager *mgr;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ mgr = [UserManager new]; });
    return mgr;
}

#pragma mark - Real-time Listener

- (void)startListeningUserWithUID:(NSString *)uid
                         onChange:(void(^)(UserModel * _Nullable user))onChange {
    [self stopListening]; // avoid duplicate listeners
    
    NSUUID *generation = [self pp_captureSessionForUID:uid];
    if (![self pp_sessionAllows:generation uid:uid]) return;
    NSUUID *listenerGeneration = [NSUUID UUID];
    self.userListenerGeneration = listenerGeneration;
    
    FIRFirestore *db = [PPProSessionCoordinator.shared activeFirestore];
    if (!db) return;
    FIRDocumentReference *doc = [[db collectionWithPath:@"UsersCol"] documentWithPath:uid];
    self.userListener = [doc addSnapshotListener:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable error) {
        if (![self.userListenerGeneration isEqual:listenerGeneration] ||
            ![self pp_sessionAllows:generation uid:uid]) return;
        if (error) {
            DLog(@"❌ Failed to listen user: %@", error.localizedDescription);
            return;
        }
        if (!snapshot.exists) {
            DLog(@"⚠️ User %@ not found during listen", uid);
            return;
        }
        
        UserModel *model = [[UserModel alloc] initWithSnapshot:snapshot];
        if (![self pp_model:model belongsToUID:uid]) return;
        self.currentUser = model;
        DLog(@"🔄 User updated: %@", self.currentUser.UserName);
        if (onChange) onChange(self.currentUser);
    }];
}

- (void)stopListening {
    self.userListenerGeneration = nil;
    if (self.userListener) {
        [self.userListener remove];
        self.userListener = nil;
        DLog(@"🛑 Stopped user listener");
    }
}

#pragma mark - Create if not exists

- (void)createUserIfNotExistsWithUID:(NSString *)uid
                                data:(NSDictionary *)data
                          completion:(void(^)(NSError * _Nullable error))completion {
    if (!uid.length) {
        if (completion) completion([NSError errorWithDomain:@"UserManager"
                                                       code:400
                                                   userInfo:@{NSLocalizedDescriptionKey: @"Missing UID"}]);
        return;
    }
    
    FIRFirestore *db = [PPProSessionCoordinator.shared activeFirestore];
    if (!db) return;
    FIRDocumentReference *doc = [[db collectionWithPath:@"UsersCol"] documentWithPath:uid];
    [doc getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable error) {
        if (error) {
            if (completion) completion(error);
            return;
        }
        if (snapshot.exists) {
            DLog(@"ℹ️ User %@ already exists", uid);
            if (completion) completion(nil);
            return;
        }
        
        NSMutableDictionary *dict = [data mutableCopy] ?: [NSMutableDictionary dictionary];
        dict[@"ID"] = uid;
        dict[@"uid"] = uid;
        dict[@"UserName"] = PPSafeString(dict[@"UserName"]);
        dict[@"UserEmail"] = PPSafeString(dict[@"UserEmail"]);
        NSString *existingDisplayName = PPSafeString(dict[@"displayName"]);
        NSString *existingEmail = PPSafeString(dict[@"email"]);
        dict[@"displayName"] = existingDisplayName.length ? existingDisplayName : PPSafeString(dict[@"UserName"]);
        dict[@"email"] = existingEmail.length ? existingEmail : PPSafeString(dict[@"UserEmail"]);
        dict[@"isAdmin"] = @([dict[@"isAdmin"] boolValue]);
        dict[@"isSuperAdmin"] = @([dict[@"isSuperAdmin"] boolValue]);
        dict[@"isBlocked"] = @([dict[@"isBlocked"] boolValue]);
        BOOL emailVerified = [dict[@"emailVerified"] boolValue];
        dict[@"emailVerified"] = @(emailVerified);
        dict[@"verified"] = @([dict[@"verified"] boolValue] || emailVerified);
        dict[@"role"] = dict[@"role"] ?: @(UserRoleUser);
        dict[@"createdAt"] = dict[@"createdAt"] ?: [FIRFieldValue fieldValueForServerTimestamp];
        dict[@"loginDate"] = [FIRFieldValue fieldValueForServerTimestamp];
        dict[@"updatedAt"] = [FIRFieldValue fieldValueForServerTimestamp];
        
        [doc setData:dict completion:^(NSError * _Nullable error) {
            if (error) {
                DLog(@"❌ Failed to create user: %@", error.localizedDescription);
            } else {
                DLog(@"✅ User %@ created", uid);
            }
            if (completion) completion(error);
        }];
    }];
}

#pragma mark - Sign Out

- (void)signOut {
    [self signOutWithCompletion:nil];
}

- (void)signOutWithCompletion:(void (^ _Nullable)(NSError * _Nullable))completion {
    if (self.signOutInProgress) {
        if (completion) completion([NSError errorWithDomain:@"UserManager" code:409 userInfo:nil]);
        return;
    }
    self.signOutInProgress = YES;

    NSString *userID = PPSafeString([PPProSessionCoordinator.shared activeUID]);
    if (userID.length == 0) {
        userID = PPSafeString(self.currentUser.uid.length ? self.currentUser.uid : self.currentUser.ID);
    }

    AppDelegate *notificationAppDelegate = PPProNotificationV2AppDelegate();
    __weak typeof(self) weakSelf = self;
    dispatch_block_t beginDeactivationAfterRegistrationSettles = ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        __block BOOL didContinueAfterDeactivation = NO;
        void (^continueAfterDeactivation)(NSError * _Nullable) = ^(NSError * _Nullable deactivateError) {
            if (didContinueAfterDeactivation) return;
            didContinueAfterDeactivation = YES;

            if (deactivateError) {
                DLog(@"⚠️ Notification V2 deactivation failed before logout: %@", deactivateError.localizedDescription);
            }

            [strongSelf invalidateUserCacheForUID:userID];
            [strongSelf clearUserCache];
            [strongSelf stopListening];

            NSError *signOutError = nil;
            [[FUManager shared] signOut:&signOutError];
            if (signOutError) {
                strongSelf.signOutInProgress = NO;
                [notificationAppDelegate pp_abortNotificationV2LogoutBarrierAndRefreshForReason:@"auth_signout_failed"];
                UIViewController *presenter = PPProUserManagerTopViewController();
                if (presenter) {
                    [PPAlertHelper showErrorIn:presenter title:kLang(@"Error") subtitle:signOutError.localizedDescription];
                }
                if (completion) completion(signOutError);
                return;
            }

            [strongSelf.sessionFence invalidate];
            strongSelf.currentUser = nil;
            [PPProSessionCoordinator.shared completeExternalSignOutWithUID:userID];

            __block BOOL didFinishLocalTokenInvalidation = NO;
            void (^finishSignOut)(NSError * _Nullable) = ^(NSError * _Nullable localTokenError) {
                if (didFinishLocalTokenInvalidation) return;
                didFinishLocalTokenInvalidation = YES;
                if (localTokenError) {
                    DLog(@"⚠️ Local Pro token invalidation failed: %@", localTokenError.localizedDescription);
                }
                [notificationAppDelegate pp_endNotificationV2LogoutBarrier];
                strongSelf.signOutInProgress = NO;
                dispatch_block_t publish = ^{
                    if (completion) completion(nil);
                    [[NSNotificationCenter defaultCenter] postNotificationName:UserManagerAuthStateDidChangeNotification
                                                                        object:nil];
                };
                if (NSThread.isMainThread) publish(); else dispatch_async(dispatch_get_main_queue(), publish);
            };

            // Keep the registration barrier active through token deletion so a
            // token refresh cannot reactivate the signed-out binding.
            [PPNotifications invalidateLocalDeviceTokenWithCompletion:finishSignOut];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                if (didFinishLocalTokenInvalidation) return;
                DLog(@"⚠️ Local Pro token invalidation timeout; completing logout best-effort.");
                finishSignOut(nil);
            });
        };

        [PPNotifications deactivateNotificationDeviceV2WithReason:@"logout" completion:continueAfterDeactivation];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            if (didContinueAfterDeactivation) return;
            DLog(@"⚠️ Notification V2 deactivation timeout; continuing logout best-effort.");
            continueAfterDeactivation(nil);
        });
    };

    if (notificationAppDelegate) {
        [notificationAppDelegate pp_beginNotificationV2LogoutBarrierWithCompletion:beginDeactivationAfterRegistrationSettles];
    } else {
        beginDeactivationAfterRegistrationSettles();
    }
}


#pragma mark - Ensure User Document

- (void)ensureUserDocumentExistsForAuthUser:(FIRUser *)authUser
                                 completion:(void(^)(UserModel * _Nullable user, NSError * _Nullable error))completion
{
    if (!authUser) {
        if (completion) completion(nil, [NSError errorWithDomain:@"UserManager"
                                                            code:401
                                                        userInfo:@{NSLocalizedDescriptionKey: @"Auth user is nil"}]);
        return;
    }
    
    NSString *uid = authUser.uid;
    NSUUID *generation = [self pp_captureSessionForUID:uid];
    if (![self pp_sessionAllows:generation uid:uid]) {
        if (completion) completion(nil, [self pp_invalidProfileSessionError]);
        return;
    }
    FIRDocumentReference *docRef = [self _userDoc:uid];
    if (!docRef) {
        if (completion) completion(nil, [self pp_invalidProfileSessionError]);
        return;
    }
    
    [docRef getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable snapshot,
                                        NSError * _Nullable error) {
        if (![self pp_sessionAllows:generation uid:uid]) { if (completion) completion(nil, [self pp_invalidProfileSessionError]); return; }
        if (error) {
            DLog(@"❌ Firestore fetch error: %@", error.localizedDescription);
            if (completion) completion(nil, error);
            return;
        }
        
        if (snapshot.exists) {
            // ✅ User exists
            UserModel *user = [[UserModel alloc] initWithSnapshot:snapshot];
            if (![self pp_model:user belongsToUID:uid]) {
                if (completion) completion(nil, [self pp_invalidProfileSessionError]);
                return;
            }
            self.currentUser = user;
            [self p_cacheUser:user];
            DLog(@"✅ User already exists: %@", user.uid);
            if (completion) completion(user, nil);
        }
        
        else {
            // ❌ User not found → create
            DLog(@"ℹ️ User does not exist, creating new doc for %@", uid);
            
            NSMutableDictionary *data = [NSMutableDictionary dictionary];
            
            data[@"ID"]           = uid;
            data[@"uid"]          = uid;
            data[@"UserEmail"]    = authUser.email ?: @"";
            data[@"UserName"]     = authUser.displayName ?: authUser.email ?: @"";
            data[@"UserImageName"] = @"";
            data[@"UserImageUrl"]  = authUser.photoURL ? authUser.photoURL.absoluteString : @"";
            data[@"displayName"]  = authUser.displayName ?: authUser.email ?: @"";
            data[@"email"]        = authUser.email ?: @"";
            data[@"photoURL"]     = authUser.photoURL ? authUser.photoURL.absoluteString : @"";
            data[@"createdAt"]    = [FIRFieldValue fieldValueForServerTimestamp];
            data[@"loginDate"]    = [FIRFieldValue fieldValueForServerTimestamp];
            data[@"updatedAt"]    = [FIRFieldValue fieldValueForServerTimestamp];
            data[@"role"]         = @(UserRoleUser);
            data[@"isAdmin"]      = @NO;
            data[@"isSuperAdmin"] = @NO;
            data[@"isBlocked"]    = @NO;
            data[@"verified"]     = @(authUser.isEmailVerified);
            data[@"emailVerified"] = @(authUser.isEmailVerified);
            data[@"plan"]         = @"free";
            data[@"loginSource"]  = @(UserLoginSourcePPAdmin); // Or PPUsers depending on app
            data[@"permissions"]  = @{};
            
            [docRef setData:data completion:^(NSError * _Nullable error) {
                if (![self pp_sessionAllows:generation uid:uid]) { if (completion) completion(nil, [self pp_invalidProfileSessionError]); return; }
                if (error) {
                    DLog(@"❌ Failed to create user doc: %@", error.localizedDescription);
                    if (completion) completion(nil, error);
                } else {
                    DLog(@"✅ User doc created successfully for %@", uid);
                    UserModel *newUser = [[UserModel alloc] initWithDict:data];
                    self.currentUser = newUser;
                    [self p_cacheUser:newUser];
                    if (completion) completion(newUser, nil);
                }
            }];
            
        }
    }];
}

#pragma mark - Permissions Helpers

- (void)makeUserAdmin:(NSString *)uid
           completion:(void(^)(NSError * _Nullable error))completion {
    DLog(@"🚀 Making %@ an Admin", uid);
    if (!uid.length) {
        if (completion) completion([NSError errorWithDomain:@"UserManager"
                                                       code:-1
                                                   userInfo:@{NSLocalizedDescriptionKey: @"Missing uid"}]);
        return;
    }
    [self pp_updateAdminAccessForUID:uid
                            role:@(UserRoleAdmin)
                         isAdmin:YES
                    isSuperAdmin:@NO
                      completion:^(NSError * _Nullable error) {
        if (error) {
            DLog(@"❌ Failed to grant admin: %@", error.localizedDescription);
        } else {
            DLog(@"✅ %@ is now Admin", uid);
        }
        if (completion) completion(error);
    }];
}

- (void)removeAdmin:(NSString *)uid
         completion:(void(^)(NSError * _Nullable error))completion {
    DLog(@"🔒 Removing Admin role from %@", uid);
    if (!uid.length) {
        if (completion) completion([NSError errorWithDomain:@"UserManager"
                                                       code:-1
                                                   userInfo:@{NSLocalizedDescriptionKey: @"Missing uid"}]);
        return;
    }
    [self pp_updateAdminAccessForUID:uid
                            role:@(UserRoleUser)
                         isAdmin:NO
                    isSuperAdmin:@NO
                      completion:^(NSError * _Nullable error) {
        if (error) {
            DLog(@"❌ Failed to remove admin: %@", error.localizedDescription);
        } else {
            DLog(@"✅ Admin removed for %@", uid);
        }
        if (completion) completion(error);
    }];
}

-(void)loadUserProfileImageInto:(UIImageView *)imageView shimmer:(BOOL)useShimmer completion:(void (^)(UIImage * _Nullable))completion
{
    [self loadUserProfileImageInto:imageView shimmer:useShimmer blur:NO anim:nil completion:completion];
}
- (void)loadUserProfileImageInto:(UIImageView *)imageView
                         shimmer:(BOOL)useShimmer
                            blur:(BOOL)useBlur
                            anim:(LOTAnimationView * _Nullable)anim
                      completion:(void(^)(UIImage * _Nullable image))completion {
    
    NSString *cachedUrl = self.currentUser.UserImageUrl.absoluteString;
    DLog(@"[ProfileImage] Starting load. Cached URL = %@", cachedUrl);
    
    if (!cachedUrl || cachedUrl.length == 0) {
        // ❌ No image at all → fallback to Lottie animation
        DLog(@"[ProfileImage] No cached image URL. Showing Lottie placeholder.");
        [Styling setAnimationNamed:@"Main Admin"
                            toView:anim
                         withSpeed:0.1
                        completion:^(BOOL success) {
            DLog(@"[ProfileImage] Lottie load success = %d", success);
            if (success) [anim play];
        }];
        
        if (completion) completion(nil);
        return;
    }
    
    // ✅ Add shimmer/blur before loading
    UIView *loadingOverlay = [[UIView alloc] initWithFrame:imageView.bounds];
    loadingOverlay.backgroundColor = [UIColor ppSecondarySurface];
    loadingOverlay.tag = 9999;
    loadingOverlay.layer.cornerRadius = imageView.layer.cornerRadius;
    loadingOverlay.layer.masksToBounds = YES;
    [imageView addSubview:loadingOverlay];
    DLog(@"[ProfileImage] Added shimmer/blur overlay. shimmer=%d blur=%d", useShimmer, useBlur);
    
    if (useShimmer) {
        DLog(@"[ProfileImage] Applying shimmer animation.");
        CAGradientLayer *gradient = [CAGradientLayer layer];
        gradient.frame = loadingOverlay.bounds;
        gradient.colors = @[(__bridge id)[UIColor ppSecondarySurface].CGColor,
                            (__bridge id)[UIColor ppSecondarySurface].CGColor,
                            (__bridge id)[UIColor ppSecondarySurface].CGColor];
        gradient.startPoint = CGPointMake(0, 0.5);
        gradient.endPoint = CGPointMake(1, 0.5);
        gradient.locations = @[@0.0, @0.5, @1.0];
        
        CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:@"locations"];
        anim.fromValue = @[@0.0, @0.0, @0.25];
        anim.toValue = @[@0.75, @1.0, @1.0];
        anim.duration = 1.0;
        anim.repeatCount = HUGE_VALF;
        [gradient addAnimation:anim forKey:@"shimmer"];
        [loadingOverlay.layer addSublayer:gradient];
    }
    
    if (useBlur) {
        DLog(@"[ProfileImage] Applying blur effect.");
        UIBlurEffect *effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
        UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:effect];
        blurView.frame = loadingOverlay.bounds;
        blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [loadingOverlay addSubview:blurView];
    }
    
    // ✅ Load from cache or Firebase URL
    DLog(@"[ProfileImage] Start loading from URL: %@", cachedUrl);
    [imageView sd_setImageWithURL:[NSURL URLWithString:cachedUrl]
                 placeholderImage:nil
                          options:SDWebImageHighPriority
                        completed:^(UIImage * _Nullable image,
                                    NSError * _Nullable error,
                                    SDImageCacheType cacheType,
                                    NSURL * _Nullable imageURL) {
        // Remove shimmer/blur overlay
        [[imageView viewWithTag:9999] removeFromSuperview];
        DLog(@"[ProfileImage] Finished loading. CacheType=%ld Error=%@", (long)cacheType, error);
        
        if (!error && image) {
            DLog(@"[ProfileImage] ✅ Image loaded successfully.");
            if (completion) completion(image);
        } else {
            // ❌ fallback to Lottie if failed
            DLog(@"[ProfileImage] ❌ Failed to load image. Showing Lottie fallback.");
            LOTAnimationView *anim = [[LOTAnimationView alloc] initWithFrame:imageView.bounds];
            anim.contentMode = UIViewContentModeScaleAspectFit;
            anim.loopAnimation = YES;
            [imageView addSubview:anim];
            //Seo Expert Man seo Pen LoginAnimation
            [Styling setAnimationNamed:@"Main Admin"
                                toView:anim
                             withSpeed:0.1
                            completion:^(BOOL success) {
                DLog(@"[ProfileImage] Fallback Lottie load success = %d", success);
                if (success) [anim play];
            }];
            if (completion) completion(nil);
        }
    }];
}

#pragma mark - Fetch All Users

- (void)fetchAllUsersWithCompletion:(void(^)(NSArray<UserModel *> * _Nullable users,
                                             NSError * _Nullable error))completion {
    [self fetchAllUsersForceRefresh:YES completion:completion];
}

- (void)fetchAllUsersForceRefresh:(BOOL)force
                       completion:(void(^)(NSArray<UserModel *> * _Nullable users,
                                           NSError * _Nullable error))completion {
    (void)force;
    NSString *owner = [PPProSessionCoordinator.shared activeUID];
    NSUUID *generation = [self pp_captureSessionForUID:owner];
    if (![self pp_sessionAllows:generation uid:owner]) {
        if (completion) completion(nil, [self pp_invalidProfileSessionError]);
        return;
    }
    FIRFirestore *db = [PPProSessionCoordinator.shared activeFirestore];
    if (!db) {
        if (completion) completion(nil, [self pp_invalidProfileSessionError]);
        return;
    }
    FIRCollectionReference *usersCol = [db collectionWithPath:@"UsersCol"];
    [[usersCol queryOrderedByField:@"UserName" descending:NO] getDocumentsWithSource:FIRFirestoreSourceServer completion:^(FIRQuerySnapshot *snapshot, NSError *error) {
        if (![self pp_sessionAllows:generation uid:owner]) {
            if (completion) completion(nil, [self pp_invalidProfileSessionError]);
            return;
        }
        if (error) { if (completion) completion(nil, error); return; }
        NSMutableArray *arr = [NSMutableArray array];
        for (FIRDocumentSnapshot *doc in snapshot.documents) {
            UserModel *model = [[UserModel alloc] initWithSnapshot:doc];
            if (model) [arr addObject:model];
        }
        if (completion) completion(arr, nil);
    }];
}

- (void)setUser:(UserModel *)user isPPAdmin:(BOOL)isAdmin {
    [self setUser:user isPPAdmin:isAdmin completion:nil];
}

// UserManager.m
- (void)toggleAdminForUser:(UserModel *)user {
    NSString *targetUID = user.uid.length ? user.uid : user.ID;
    if (!targetUID.length) {
        DLog(@"[UserManager] ❌ Missing user ID");
        return;
    }
    
    BOOL newState = !user.isAdmin;
    [self setUser:user isPPAdmin:newState];
}


// 🔁 Public helper that flips current state
- (void)toggleAdminForUser:(UserModel *)user completion:(void(^)(NSError *error))completion {
    BOOL next = !user.isAdmin;
    [self setUser:user isPPAdmin:next completion:completion];
}

// ✅ Main method: delegates coordinated claim, role, and permission updates to Infra.
- (void)setUser:(UserModel *)user
      isPPAdmin:(BOOL)makeAdmin
     completion:(void(^)(NSError *error))completion
{
    if (!user) {
        if (completion) completion([NSError errorWithDomain:@"UserManager"
                                                       code:-1
                                                   userInfo:@{NSLocalizedDescriptionKey:@"Missing user model"}]);
        return;
    }

    NSString *targetUID = user.uid.length ? user.uid : user.ID;
    if (!targetUID.length) {
        if (completion) completion([NSError errorWithDomain:@"UserManager"
                                                       code:-1
                                                   userInfo:@{NSLocalizedDescriptionKey:@"Missing user uid"}]);
        return;
    }
    user.uid = targetUID;

    UserRole role = user.role;
    if (makeAdmin) {
        if (role == UserRoleUnknown || role == UserRoleUser) {
            role = UserRoleAdmin;
        }
    } else if (role == UserRoleAdmin || role == UserRoleSuperAdmin) {
        role = UserRoleUser;
    }
    BOOL isSuperAdmin = (role == UserRoleSuperAdmin);
    [self pp_updateAdminAccessForUID:targetUID
                            role:@(role)
                         isAdmin:makeAdmin
                    isSuperAdmin:@(isSuperAdmin)
                      completion:^(NSError * _Nullable error) {
        if (error) {
            if (completion) completion(error);
            return;
        }

        user.role = role;
        user.isAdmin = makeAdmin;
        user.isSuperAdmin = isSuperAdmin;

        FIRUser *current = [PPProSessionCoordinator.shared currentUser];
        BOOL isCurrentUser = (current != nil) && [current.uid isEqualToString:targetUID];
        if (!isCurrentUser) {
            if (completion) completion(nil);
            return;
        }

        [current getIDTokenResultForcingRefresh:YES completion:^(__unused FIRAuthTokenResult * _Nullable tokenResult, NSError * _Nullable tokenError) {
            if (tokenError) {
                DLog(@"⚠️ Admin access updated, but token refresh failed for %@: %@", targetUID, tokenError.localizedDescription);
            } else {
                DLog(@"🔄 ID token refreshed after admin access update.");
            }
            if (completion) completion(tokenError);
        }];
    }];
}


- (void)toggleAdminForUser:(UserModel *)user
                  newState:(BOOL)makeAdmin
                completion:(void(^)(NSError * _Nullable error))completion
{
    // disable UI hint happens in VC; this is pure logic
    [self setUser:user isPPAdmin:makeAdmin completion:^(NSError *error) {
        if (completion) completion(error);
    }];
}

#pragma mark - Private

- (FIRDocumentReference *)_userDoc:(NSString *)uid {
    FIRFirestore *db = [PPProSessionCoordinator.shared activeFirestore];
    if (!db) return nil;
    return [[db collectionWithPath:@"UsersCol"] documentWithPath:uid];
}

- (void)pp_updateAdminAccessForUID:(NSString *)uid
                          role:(NSNumber *)role
                       isAdmin:(BOOL)isAdmin
                  isSuperAdmin:(NSNumber *)isSuperAdmin
                    completion:(void (^)(NSError * _Nullable))completion {
    if (!uid.length) {
        if (completion) completion([NSError errorWithDomain:@"UserManager"
                                                       code:-1
                                                   userInfo:@{NSLocalizedDescriptionKey: @"Missing uid"}]);
        return;
    }

    NSMutableDictionary *payload = [@{
        @"uid": uid,
        @"isAdmin": @(isAdmin)
    } mutableCopy];
    if (role != nil) payload[@"role"] = role;
    if (isSuperAdmin != nil) payload[@"isSuperAdmin"] = isSuperAdmin;

    FIRFunctions *functions = [PPProSessionCoordinator.shared activeFunctions];
    if (!functions) {
        if (completion) completion([self pp_invalidProfileSessionError]);
        return;
    }
    [[functions HTTPSCallableWithName:@"updateUserAdminAccess"] callWithObject:payload completion:^(__unused FIRHTTPSCallableResult * _Nullable result, NSError * _Nullable error) {
        if (error) {
            DLog(@"[UserManager] updateUserAdminAccess failed for %@: %@", uid, error.localizedDescription);
        } else {
            DLog(@"[UserManager] updateUserAdminAccess succeeded for %@", uid);
        }
        if (completion) completion(error);
    }];
}

#pragma mark - Fetch


- (id<FIRListenerRegistration>)listenUserWithUID:(NSString *)uid
                                          change:(void(^)(UserModel * _Nullable user))change
{
    if (!uid.length) return nil;
    return [[self _userDoc:uid]
            addSnapshotListener:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable error) {
        if (error || !snapshot.exists) { if (change) change(nil); return; }
        UserModel *m = [[UserModel alloc] initWithSnapshot:snapshot];
        if (change) change(m);
    }];
}

#pragma mark - Partial update (merge)

- (void)updateUserFieldsForUID:(NSString *)uid
                        fields:(NSDictionary *)fields
                    completion:(void(^)(NSError * _Nullable error))completion
{
    if (!uid.length) {
        if (completion) completion([NSError errorWithDomain:@"UserManager"
                                                       code:-1
                                                   userInfo:@{NSLocalizedDescriptionKey:@"Missing uid"}]);
        return;
    }
    
    // Add server timestamp automatically
    NSMutableDictionary *payload = [fields mutableCopy] ?: [NSMutableDictionary new];
    [payload removeObjectForKey:@"PPUserTokenID"];
    [payload removeObjectForKey:@"PPProTokenID"];
    payload[@"updatedAt"] = [FIRFieldValue fieldValueForServerTimestamp];
    
    [[self _userDoc:uid] setData:payload merge:YES completion:^(NSError * _Nullable error) {
        if (completion) completion(error);
    }];
}

#pragma mark - Save entire model

- (void)saveUserModel:(UserModel *)user
                merge:(BOOL)merge
           completion:(void(^)(NSError * _Nullable error))completion
{
    NSString *uid = user.uid.length ? user.uid : user.ID;
    if (!uid.length) {
        if (completion) completion([NSError errorWithDomain:@"UserManager"
                                                       code:-1
                                                   userInfo:@{NSLocalizedDescriptionKey:@"UserModel has no uid"}]);
        return;
    }
    
    // Let your model build a clean dict (avoid nils/NSNulls inside)
    NSMutableDictionary *dict = [[user toDictionary] mutableCopy];
    if (!dict) dict = [NSMutableDictionary new];
    
    // Ensure canonical fields we often update from the admin
    dict[@"ID"]       = uid;
    dict[@"uid"]      = uid;
    dict[@"role"]     = @(user.role);
    dict[@"isAdmin"]  = @(user.isAdmin);
    dict[@"isSuperAdmin"] = @(user.isSuperAdmin);
    dict[@"isBlocked"] = @(user.isBlocked);
    dict[@"displayName"] = PPSafeString(user.displayName.length ? user.displayName : user.UserName);
    dict[@"email"]       = PPSafeString(user.email.length ? user.email : user.UserEmail);
    dict[@"photoURL"]    = PPSafeString(user.photoURL.length ? user.photoURL : user.UserImageUrl.absoluteString);
    dict[@"verified"] = @(user.isVerified);
    dict[@"updatedAt"] = [FIRFieldValue fieldValueForServerTimestamp];
    
    [[self _userDoc:uid] setData:dict merge:merge completion:^(NSError * _Nullable error) {
        if (completion) completion(error);
    }];
}


#pragma mark - Role / Admin utilities

- (void)setRole:(UserRole)role
         forUID:(NSString *)uid
     completion:(void(^)(NSError * _Nullable error))completion
{
    if (!uid.length) {
        if (completion) completion([NSError errorWithDomain:@"UserManager"
                                                       code:-1
                                                   userInfo:@{NSLocalizedDescriptionKey:@"Missing uid"}]);
        return;
    }

    BOOL isAdmin = (role == UserRoleAdmin || role == UserRoleSuperAdmin);
    [self pp_updateAdminAccessForUID:uid
                            role:@(role)
                         isAdmin:isAdmin
                    isSuperAdmin:@(role == UserRoleSuperAdmin)
                      completion:completion];
}

- (void)setIsAdmin:(BOOL)isAdmin
            forUID:(NSString *)uid
 realignRoleIfNeeded:(BOOL)realign
        completion:(void(^)(NSError * _Nullable error))completion
{
    if (!uid.length) {
        if (completion) completion([NSError errorWithDomain:@"UserManager"
                                                       code:-1
                                                   userInfo:@{NSLocalizedDescriptionKey:@"Missing uid"}]);
        return;
    }

    NSNumber *role = realign ? @(isAdmin ? UserRoleAdmin : UserRoleUser) : nil;
    NSNumber *isSuperAdmin = (!isAdmin || realign) ? @NO : nil;
    [self pp_updateAdminAccessForUID:uid
                            role:role
                         isAdmin:isAdmin
                    isSuperAdmin:isSuperAdmin
                      completion:completion];
}

// in UserManager.m
- (void)listenAllUsersWithCompletion:(void(^)(NSArray<UserModel *> *users, NSError *error))completion {
    FIRFirestore *db = [PPProSessionCoordinator.shared activeFirestore];
    if (!db) {
        if (completion) completion(nil, [self pp_invalidProfileSessionError]);
        return;
    }

    [[db collectionWithPath:@"UsersCol"]
     addSnapshotListener:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }

        NSMutableArray *arr = [NSMutableArray array];
        for (FIRDocumentSnapshot *doc in snapshot.documents) {
            UserModel *u = [[UserModel alloc] initWithSnapshot:doc];
            [arr addObject:u];
        }

        if (completion) completion(arr, nil);
    }];
}

@end


/*
 // Default behavior (memory→disk→server)
 [UsrMgr loadUserWithUID:uid completion:^(UserModel *user, NSError *error) {
     // use user
 }];

 // Force server refresh
 [UsrMgr loadUserWithUID:uid cachePolicy:PPUserCachePolicyServerOnly completion:^(UserModel *user, NSError *error) {
     // fresh data
 }];

 // Cache-only (no network)
 [UsrMgr loadUserWithUID:uid cachePolicy:PPUserCachePolicyCacheOnly completion:^(UserModel *user, NSError *error) {
     // user may be nil if not cached
 }];
 */
