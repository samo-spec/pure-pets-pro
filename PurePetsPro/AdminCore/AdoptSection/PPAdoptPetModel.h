//
//  PPAdoptPetModel.h
//  PurePetsPro
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface PPAdoptPetModel : NSObject <NSCopying>

@property (nonatomic, copy) NSString *petID;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *descriptionText;
@property (nonatomic, copy) NSString *status;
@property (nonatomic, copy) NSString *ownerID;
@property (nonatomic, assign) NSInteger kindID;
@property (nonatomic, assign) NSInteger breedID;
@property (nonatomic, assign) NSInteger ageMonths;
@property (nonatomic, assign) NSInteger cityID;
@property (nonatomic, copy) NSString *gender;
@property (nonatomic, assign) NSInteger visibility;
@property (nonatomic, assign) BOOL isBlocked;
@property (nonatomic, assign) BOOL isDeleted;
@property (nonatomic, copy) NSArray<NSString *> *imageURLs;

// Adopter information
@property (nonatomic, copy) NSString *adopterUserID;
@property (nonatomic, assign) BOOL isAdopted;
@property (nonatomic, copy) NSString *adopterName;
@property (nonatomic, copy) NSString *adopterContact;
@property (nonatomic, strong, nullable) NSDate *createdAt;
@property (nonatomic, strong, nullable) NSDate *updatedAt;

- (NSDictionary *)toDictionary;
- (instancetype)initWithDictionary:(NSDictionary *)dict;

@end

NS_ASSUME_NONNULL_END
