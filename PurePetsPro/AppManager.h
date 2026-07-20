//
//  AppManager.h
//  PurePetsAdmin
//

#import "AppManager.h"
#import "MainKindsModel.h"
#import "RPManager.h"

@class FIRUser;
@protocol FIRListenerRegistration;


typedef NS_ENUM(NSInteger, DataSource)
{
    DataSourceServer = 1,
    DataSourceCache = 2
};

NS_ASSUME_NONNULL_BEGIN

@interface AppManager : NSObject
  
/// Singleton
+ (instancetype)shared;

/// Firebase setup
- (void)configureFirebase;

/// Current user
@property (nonatomic, strong, nullable) FIRUser *currentUser;

/// Check if current user is admin
- (void)checkIfAdmin:(void(^)(BOOL isAdmin))completion;

/// Check if a signed-in user may access Pure Pets Pro.
/// Existing admins stay allowed; service providers are allowed when
/// the matching UsersCol record (doc ID, uid, or ID) has canOfferServices enabled.
- (void)checkIfCurrentUserCanAccessPro:(void(^)(BOOL allowed))completion;
- (void)checkIfUserWithUID:(NSString *)uid
              canAccessPro:(void(^)(BOOL allowed, NSDictionary * _Nullable userDoc, NSError * _Nullable error))completion;

/// App version string
@property (nonatomic, copy, readonly) NSString *appVersion;


// Arrays
@property (strong, nonatomic) NSMutableArray<MainKindsModel *> *MainKindsArray;


- (void)fetchMainKindsWithCompletion:(void(^)(NSArray<MainKindsModel *> * _Nullable kinds, NSError * _Nullable error))completion;
@end

NS_ASSUME_NONNULL_END


// ✅ Shortcut macro for easy access
#define AppMgr [AppManager shared]
#define UsrMgr [UserManager shared]
#define UsrMgrCls [UserManager class]
#define RPM [RPManager shared]
#define PPNotifications [PPNotificationsManager sharedManager]
#define PPNotificationsClass [PPNotificationsManager class]
#define PPFIRInstallation [FIRInstallations installations]
