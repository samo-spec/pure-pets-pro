//
//  PPServiceManager.h
//  PurePetsPro
//
//  Provider-scoped service manager.
//  All reads/writes are for the current logged-in provider only.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class PPServiceModel;
@protocol FIRListenerRegistration;

typedef void(^PPServiceArrayBlock)(NSArray<PPServiceModel *> * _Nullable services, NSError * _Nullable error);
typedef void(^PPServiceVoidBlock)(NSError * _Nullable error);

@interface PPServiceManager : NSObject

+ (instancetype)sharedManager;

// ── READ (provider-scoped) ──
- (id<FIRListenerRegistration>)observeServicesForOwnerID:(NSString *)ownerID
                                                 onChange:(PPServiceArrayBlock)onChange;
- (void)fetchServiceByID:(NSString *)serviceID
              completion:(void(^)(PPServiceModel * _Nullable service, NSError * _Nullable error))completion;

// ── WRITE (provider-owned only) ──
- (void)addService:(PPServiceModel *)service
             image:(UIImage * _Nullable)image
        completion:(PPServiceVoidBlock)completion;

/// Updates only provider-controlled fields. Optionally uploads a new image.
- (void)updateService:(PPServiceModel *)service
                image:(UIImage * _Nullable)image
           completion:(PPServiceVoidBlock)completion;

/// Toggle provider availability (isAvailable field).
- (void)toggleAvailability:(BOOL)available
              forServiceID:(NSString *)serviceID
                completion:(PPServiceVoidBlock)completion;

- (void)deleteService:(PPServiceModel *)service
           completion:(PPServiceVoidBlock)completion;

// ── Image ──
- (void)uploadImage:(UIImage *)image
          serviceID:(NSString *)serviceID
         completion:(void(^)(NSString *imageURL))completion;

@end

NS_ASSUME_NONNULL_END
