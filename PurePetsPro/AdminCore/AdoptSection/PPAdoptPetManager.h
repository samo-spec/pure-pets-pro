//
//  PPAdoptPetManager.h
//  PurePetsPro
//  Adopt Pet Management Layer
//

#import <Foundation/Foundation.h>
#import "PPAdoptPetModel.h"

@protocol FIRListenerRegistration;

NS_ASSUME_NONNULL_BEGIN

@interface PPAdoptPetManager : NSObject

+ (instancetype)sharedManager;

@property (readonly, nonatomic) NSString *adoptPetsCollection;

- (void)fetchAdoptPetsStatus:(NSString *)status
             completion:(void(^)(NSArray<PPAdoptPetModel *> *, NSError *))completion;

- (void)createAdoptRequest:(PPAdoptPetModel *)pet
         completion:(void(^)(BOOL, NSError *))completion;

- (void)updateAdoptStatus:(NSString *)petID
                        status:(NSString *)status
                     completion:(void(^)(BOOL, NSError *))completion;

- (void)deleteAdoptRequest:(NSString *)petID
                      completion:(void(^)(BOOL, NSError *))completion;

- (id<FIRListenerRegistration>)observeAllAdoptPets:(void(^)(NSArray<PPAdoptPetModel *> * _Nullable pets, NSError * _Nullable error))onChange;

@end

NS_ASSUME_NONNULL_END
