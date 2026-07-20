//
//  CountryModel.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 29/10/2025.
//


// CountryModel.h
#import <Foundation/Foundation.h>
#import "XLForm.h"

@class CityModel;

 

@interface CountryModel : NSObject<XLFormOptionObject>

@property (nonatomic, assign) NSInteger countryID;
@property (nonatomic, copy) NSString *iso;
@property (nonatomic, copy) NSString *countryCode;
@property (nonatomic, copy) NSString *enName;
@property (nonatomic, copy) NSString *arName;
@property (nonatomic, assign) NSInteger defualtCityID;



@property (nonatomic, assign) BOOL defaultCountry;
@property (nonatomic, strong) NSArray<CityModel *> *cities;
@property (nonatomic, copy) NSString *name;
+ (CountryModel *)safeUserCountryModel;
+ (NSString *)safeCurrentCountryISOCode;
+ (NSString *)safeCurrentCurrencyCode;
@end

 



 

