//
//  CitiesManager.h
//  Pure Pets
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import "CityModel.h"
#import "CountryModel.h"
#import "StateModel.h"

extern NSNotificationName const CitiesManagerDidUpdateNotification;

@interface CitiesManager : NSObject

@property (nonatomic, strong, readonly) NSArray<CountryModel *> *countries;
@property (nonatomic, assign, readonly, getter=isLoading) BOOL loading;

+ (instancetype)shared;

- (void)loadData;
- (void)refreshFromFirestore;

- (NSArray<CityModel *> *)citiesForCountryCode:(NSString *)isoCode;
- (NSArray<CityModel *> *)citiesForCurrentCountry;
- (CountryModel *)CurrentCountry;
- (CountryModel *)qatarCountry;
- (CityModel *)cityByID:(NSInteger)cityID;
- (StateModel *)stateByID:(NSInteger)stateID;
- (CountryModel *)countryByID:(NSInteger)countryID;
- (CountryModel *)countryWithCode:(NSString *)isoCode;
- (CountryModel *)countryWithDialCode:(NSString *)dialCode;
- (NSArray<NSDictionary<NSString *, NSString *> *> *)countryDialCodeOptions;
- (NSString *)emojiFlagForCountryCode:(NSString *)isoCode;
- (NSString *)cityNameForID:(NSInteger)cityID;
- (NSString *)stateNameForID:(NSInteger)stateID;
- (NSString *)countryNameForID:(NSInteger)countryID;
- (CityModel *)defaultCityForCountry:(CountryModel *)country;
@end

@interface LocalizationHelper : NSObject

+ (NSString *)localizedNameWithEnglish:(NSString *)enName arabic:(NSString *)arName;
+ (BOOL)isArabicLanguage;

@end
