//
//  CitiesManager.m
//  Pure Pets
//

#import "CitiesManager.h"
#import "Language.h"
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <CoreTelephony/CTCarrier.h>
@import FirebaseFirestore;

NSNotificationName const CitiesManagerDidUpdateNotification = @"CitiesManagerDidUpdateNotification";

static NSString *PPCitiesStringValue(id value) {
    if ([value isKindOfClass:NSString.class]) {
        return [(NSString *)value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    }
    if ([value respondsToSelector:@selector(stringValue)]) {
        return [[value stringValue] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    }
    return @"";
}

static NSDictionary *PPCitiesNameDictionary(id data) {
    if ([data isKindOfClass:NSDictionary.class]) {
        return (NSDictionary *)data;
    }
    return @{};
}

static NSString *PPCitiesLocalizedValue(NSString *english, NSString *arabic) {
    NSString *localized = Language.isRTL ? arabic : english;
    if (localized.length > 0) {
        return localized;
    }
    return english.length > 0 ? english : (arabic ?: @"");
}

static NSString *PPCitiesNormalizedDialCode(NSString *dialCode) {
    NSString *normalized = [PPCitiesStringValue(dialCode) stringByReplacingOccurrencesOfString:@" " withString:@""];
    if (normalized.length == 0) {
        return @"";
    }
    if (![normalized hasPrefix:@"+"]) {
        normalized = [@"+" stringByAppendingString:normalized];
    }
    return normalized;
}

static NSString *PPCurrentCountryFromCarrier(void) {
#if TARGET_OS_SIMULATOR
    return @"";
#else
    CTTelephonyNetworkInfo *networkInfo = [[CTTelephonyNetworkInfo alloc] init];
    CTCarrier *carrier = [networkInfo subscriberCellularProvider];
    if (carrier) {
        return [carrier isoCountryCode] ?: @"";
    }
    return @"";
#endif
}

@interface CitiesManager ()
@property (nonatomic, strong) NSArray<CountryModel *> *countries;
@property (nonatomic, assign, readwrite) BOOL loading;
@end

@implementation CitiesManager

+ (instancetype)shared {
    static CitiesManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[CitiesManager alloc] init];
        [sharedInstance loadData];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _countries = @[];
        _loading = NO;
    }
    return self;
}

- (void)loadData {
    if (self.countries.count > 0 || self.loading) {
        return;
    }
    [self refreshFromFirestore];
}

- (void)refreshFromFirestore {
    if (self.loading) return;
    self.loading = YES;

    FIRFirestore *db = [FIRFirestore firestore];
    [[db collectionWithPath:@"countries"] getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        if (error) {
            NSLog(@"[CitiesManager] Failed to fetch countries: %@", error);
            dispatch_async(dispatch_get_main_queue(), ^{
                self.loading = NO;
                [[NSNotificationCenter defaultCenter] postNotificationName:CitiesManagerDidUpdateNotification object:self];
            });
            return;
        }

        dispatch_group_t group = dispatch_group_create();
        NSMutableArray<CountryModel *> *countriesArray = [NSMutableArray array];

        for (FIRDocumentSnapshot *countryDoc in snapshot.documents) {
            if (!countryDoc.exists) continue;

            NSDictionary *countryData = countryDoc.data;
            NSDictionary *countryName = PPCitiesNameDictionary(countryData[@"name"]);
            CountryModel *country = [CountryModel new];
            country.countryID = [countryData[@"id"] integerValue];
            NSString *countryISO = PPCitiesStringValue(countryData[@"iso"]).uppercaseString;
            country.iso = countryISO.length > 0 ? countryISO : countryDoc.documentID.uppercaseString;
            country.countryCode = PPCitiesNormalizedDialCode(countryData[@"countryCode"]);
            country.enName = PPCitiesStringValue(countryName[@"en"]).length > 0 ? PPCitiesStringValue(countryName[@"en"]) : PPCitiesStringValue(countryData[@"en"]);
            country.arName = PPCitiesStringValue(countryName[@"ar"]).length > 0 ? PPCitiesStringValue(countryName[@"ar"]) : PPCitiesStringValue(countryData[@"ar"]);
            country.defaultCountry = [countryData[@"default"] boolValue];
            NSInteger defaultCityID = [countryData[@"defualtCityID"] integerValue];
            if (defaultCityID <= 0) {
                defaultCityID = [countryData[@"defaultCityID"] integerValue];
            }
            country.defualtCityID = defaultCityID;

            dispatch_group_enter(group);
            [[countryDoc.reference collectionWithPath:@"cities"] getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable citiesSnapshot, NSError * _Nullable citiesError) {
                if (citiesError) {
                    NSLog(@"[CitiesManager] Failed to fetch cities for %@: %@", country.iso, citiesError);
                    country.cities = @[];
                    dispatch_group_leave(group);
                    return;
                }

                NSMutableArray<CityModel *> *citiesArray = [NSMutableArray array];

                for (FIRDocumentSnapshot *cityDoc in citiesSnapshot.documents) {
                    if (!cityDoc.exists) continue;

                    NSDictionary *cityData = cityDoc.data;
                    NSDictionary *cityName = PPCitiesNameDictionary(cityData[@"name"]);
                    CityModel *city = [CityModel new];
                    city.cityID = [cityData[@"id"] integerValue];
                    city.enName = PPCitiesStringValue(cityName[@"en"]).length > 0 ? PPCitiesStringValue(cityName[@"en"]) : PPCitiesStringValue(cityData[@"en"]);
                    city.arName = PPCitiesStringValue(cityName[@"ar"]).length > 0 ? PPCitiesStringValue(cityName[@"ar"]) : PPCitiesStringValue(cityData[@"ar"]);
                    city.latitude = [cityData[@"lat"] doubleValue];
                    city.longitude = [cityData[@"lng"] doubleValue];
                    city.country = country;

                    dispatch_group_enter(group);
                    [[cityDoc.reference collectionWithPath:@"states"] getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable statesSnapshot, NSError * _Nullable statesError) {
                        if (statesError) {
                            NSLog(@"[CitiesManager] Failed to fetch states for city %ld: %@", (long)city.cityID, statesError);
                            city.states = @[];
                            dispatch_group_leave(group);
                            return;
                        }

                        NSMutableArray *statesArray = [NSMutableArray array];
                        for (FIRDocumentSnapshot *stateDoc in statesSnapshot.documents) {
                            if (!stateDoc.exists) continue;

                            NSDictionary *stateData = stateDoc.data;
                            NSDictionary *stateName = PPCitiesNameDictionary(stateData[@"name"]);
                            StateModel *state = [StateModel new];
                            state.stateID = [stateData[@"id"] integerValue];
                            state.enName = PPCitiesStringValue(stateName[@"en"]).length > 0 ? PPCitiesStringValue(stateName[@"en"]) : PPCitiesStringValue(stateData[@"en"]);
                            state.arName = PPCitiesStringValue(stateName[@"ar"]).length > 0 ? PPCitiesStringValue(stateName[@"ar"]) : PPCitiesStringValue(stateData[@"ar"]);
                            [statesArray addObject:state];
                        }
                        [statesArray sortUsingComparator:^NSComparisonResult(StateModel *lhs, StateModel *rhs) {
                            return lhs.stateID < rhs.stateID ? NSOrderedAscending : (lhs.stateID > rhs.stateID ? NSOrderedDescending : NSOrderedSame);
                        }];
                        city.states = [statesArray copy];
                        dispatch_group_leave(group);
                    }];

                    [citiesArray addObject:city];
                }

                [citiesArray sortUsingComparator:^NSComparisonResult(CityModel *lhs, CityModel *rhs) {
                    return lhs.cityID < rhs.cityID ? NSOrderedAscending : (lhs.cityID > rhs.cityID ? NSOrderedDescending : NSOrderedSame);
                }];
                country.cities = [citiesArray copy];
                dispatch_group_leave(group);
            }];

            [countriesArray addObject:country];
        }

        dispatch_group_notify(group, dispatch_get_main_queue(), ^{
            [countriesArray sortUsingComparator:^NSComparisonResult(CountryModel *lhs, CountryModel *rhs) {
                if (lhs.defaultCountry != rhs.defaultCountry) {
                    return lhs.defaultCountry ? NSOrderedAscending : NSOrderedDescending;
                }
                NSString *leftName = PPCitiesLocalizedValue(lhs.enName, lhs.arName);
                NSString *rightName = PPCitiesLocalizedValue(rhs.enName, rhs.arName);
                NSComparisonResult nameResult = [leftName localizedCaseInsensitiveCompare:rightName];
                if (nameResult != NSOrderedSame) {
                    return nameResult;
                }
                return lhs.countryID < rhs.countryID ? NSOrderedAscending : (lhs.countryID > rhs.countryID ? NSOrderedDescending : NSOrderedSame);
            }];
            self.countries = [countriesArray copy];
            self.loading = NO;
            [[NSNotificationCenter defaultCenter] postNotificationName:CitiesManagerDidUpdateNotification object:self];
        });
    }];
}


- (NSArray<CityModel *> *)citiesForCountryCode:(NSString *)isoCode {
    NSString *normalizedISO = [[isoCode ?: @"" stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] uppercaseString];
    if (normalizedISO.length == 0) {
        return @[];
    }
    for (CountryModel *country in self.countries) {
        if ([country.iso.uppercaseString isEqualToString:normalizedISO]) {
            return country.cities;
        }
    }
    return @[];
}

// Returns the default city for the specified country, or the first city as fallback.
- (CityModel *)defaultCityForCountry:(CountryModel *)country
{
    if (!country) {
        return nil;
    }

    // Use defualtCityID from CountryModel (intentional spelling)
    if (country.defualtCityID > 0) {
        CityModel *city = [self cityByID:country.defualtCityID];
        if (city) {
            return city;
        }
    }

    // Fallback: first city in country
    return country.cities.firstObject;
}

-(CountryModel *)CurrentCountry
{
    NSArray<NSString *> *candidateISOCodes = @[
        PPCurrentCountryFromCarrier(),
        [[[NSLocale currentLocale] objectForKey:NSLocaleCountryCode] description] ?: @"",
    ];

    for (NSString *candidateISO in candidateISOCodes) {
        CountryModel *country = [self countryWithCode:candidateISO];
        if (country) {
            return country;
        }
    }

    return [self qatarCountry];
}
- (NSArray<CityModel *> *)citiesForCurrentCountry {
    CountryModel *country = [self CurrentCountry] ?: [self qatarCountry];
    if (country.cities.count > 0) {
        return country.cities;
    }
    return [self qatarCountry].cities ?: @[];
}

- (CityModel *)cityByID:(NSInteger)cityID {
    for (CountryModel *country in self.countries) {
        for (CityModel *city in country.cities) {
            if (city.cityID == cityID) {
                return city;
            }
        }
    }
    return nil;
}

- (StateModel *)stateByID:(NSInteger)stateID {
    for (CountryModel *country in self.countries) {
        for (CityModel *city in country.cities) {
            for (StateModel *state in city.states) {
                if (state.stateID == stateID) {
                    return state;
                }
            }
        }
    }
    return nil;
}

- (CountryModel *)countryByID:(NSInteger)countryID {
    for (CountryModel *country in self.countries) {
        if (country.countryID == countryID) {
            return country;
        }
    }
    return nil;
}

- (CountryModel *)countryWithCode:(NSString *)isoCode
{
    if (![isoCode isKindOfClass:NSString.class] || isoCode.length == 0) {
        return nil;
    }

    NSString *normalized = isoCode.uppercaseString;

    for (CountryModel *country in self.countries) {
        if ([country.iso.uppercaseString isEqualToString:normalized]) {
            return country;
        }
    }

    return nil;
}

- (CountryModel *)countryWithDialCode:(NSString *)dialCode
{
    if (![dialCode isKindOfClass:NSString.class] || dialCode.length == 0) {
        return nil;
    }

    NSString *normalized = [[dialCode stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]
        stringByReplacingOccurrencesOfString:@" " withString:@""];
    if (normalized.length == 0) {
        return nil;
    }
    if (![normalized hasPrefix:@"+"]) {
        normalized = [@"+" stringByAppendingString:normalized];
    }

    for (CountryModel *country in self.countries) {
        NSString *candidate = PPCitiesNormalizedDialCode(country.countryCode);
        if (candidate.length == 0) {
            continue;
        }
        if ([candidate isEqualToString:normalized]) {
            return country;
        }
    }

    return nil;
}

- (NSArray<NSDictionary<NSString *, NSString *> *> *)countryDialCodeOptions
{
    NSMutableArray<NSDictionary<NSString *, NSString *> *> *options = [NSMutableArray array];
    for (CountryModel *country in self.countries) {
        NSString *dialCode = PPCitiesNormalizedDialCode(country.countryCode);
        NSString *iso = PPCitiesStringValue(country.iso).uppercaseString;
        NSString *localizedName = PPCitiesLocalizedValue(country.enName, country.arName);
        if (dialCode.length == 0 || iso.length == 0 || localizedName.length == 0) {
            continue;
        }

        NSString *flag = [self emojiFlagForCountryCode:iso];
        NSString *title = flag.length > 0 ? [NSString stringWithFormat:@"%@ %@", flag, localizedName] : localizedName;
        [options addObject:@{
            @"value": dialCode,
            @"subtitle": dialCode,
            @"title": title,
            @"name": localizedName,
            @"enName": country.enName ?: @"",
            @"arName": country.arName ?: @"",
            @"iso": iso,
            @"flag": flag ?: @"",
        }];
    }
    return [options copy];
}

- (NSString *)emojiFlagForCountryCode:(NSString *)isoCode
{
    NSString *code = PPCitiesStringValue(isoCode).uppercaseString;
    if (code.length < 2) {
        return @"";
    }
    code = [code substringToIndex:2];

    uint32_t base = 127397;
    uint32_t scalars[] = {
        [code characterAtIndex:0] + base,
        [code characterAtIndex:1] + base
    };
    return [[NSString alloc] initWithBytes:scalars
                                    length:sizeof(scalars)
                                  encoding:NSUTF32LittleEndianStringEncoding] ?: @"";
}

- (CountryModel *)qatarCountry
{
    CountryModel *qatar = [self countryWithCode:@"QA"];
    if (qatar) {
        return qatar;
    }
    return self.countries.firstObject;
}

- (NSString *)cityNameForID:(NSInteger)cityID {
    CityModel *city = [self cityByID:cityID];
    return city ? [LocalizationHelper localizedNameWithEnglish:city.enName arabic:city.arName] : @"";
}

- (NSString *)stateNameForID:(NSInteger)stateID {
    StateModel *state = [self stateByID:stateID];
    return state ? [LocalizationHelper localizedNameWithEnglish:state.enName arabic:state.arName] : @"";
}

- (NSString *)countryNameForID:(NSInteger)countryID {
    CountryModel *country = [self countryByID:countryID];
    return country ? [LocalizationHelper localizedNameWithEnglish:country.enName arabic:country.arName] : @"";
}

@end


@implementation LocalizationHelper

+ (NSString *)localizedNameWithEnglish:(NSString *)enName arabic:(NSString *)arName {
    return PPCitiesLocalizedValue(enName, arName);
}

+ (BOOL)isArabicLanguage {
    NSString *preferred = [NSLocale preferredLanguages].firstObject ?: @"";
    if (preferred.length < 2) {
        return NO;
    }
    NSString *lang = [preferred substringToIndex:2];
    return [lang isEqualToString:@"ar"];
}

@end
