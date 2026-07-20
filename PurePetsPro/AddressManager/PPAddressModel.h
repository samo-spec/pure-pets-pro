//
//  PPAddressModel.h
//  Pure Pets
//

#import <Foundation/Foundation.h>
#import "XLForm.h"
 

NS_ASSUME_NONNULL_BEGIN

@interface PPAddressModel : NSObject <NSSecureCoding,XLFormOptionObject>

@property (nonatomic, copy) NSString *documentID;
@property (nonatomic, copy) NSString *addressID;
@property (nonatomic, copy) NSString *userID;
@property (nonatomic, copy) NSString *fullName;
@property (nonatomic, copy, nullable) NSString *phoneNumber;
@property (nonatomic, copy) NSString *addressLine1;
@property (nonatomic, copy, nullable) NSString *addressLine2;
@property (nonatomic, assign) NSInteger cityID;
@property (nonatomic, assign) NSInteger stateID;
@property (nonatomic, copy) NSString *postalCode;
@property (nonatomic) BOOL isDefault;

@property (nonatomic, copy) NSString *locatioName;
@property (nonatomic, copy) NSString *locationPoints;
@property (nonatomic, strong, nullable) NSDate *createdAt;
@property (nonatomic, strong, nullable) NSDate *updatedAt;

/// 🏙️ Computed localized address text (includes flag, city, state, country)
@property (nonatomic, readonly) NSString *displayName;

/// 🌍 Country name + emoji flag (auto-localized)
@property (nonatomic, readonly, nullable) NSString *countryDisplay;

/// 🔹 Convenience for model → Firestore
- (instancetype)initWithDictionary:(NSDictionary *)dictionary
                        documentID:(nullable NSString *)docID;
- (NSDictionary *)toDictionary;
- (BOOL)isSemanticallyValid;

@end

NS_ASSUME_NONNULL_END
