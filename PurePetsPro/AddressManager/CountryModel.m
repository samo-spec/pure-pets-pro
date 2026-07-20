// CountryModel.m
#import "CountryModel.h"
#import "CitiesManager.h"
 
@implementation CountryModel

-(id)formValue
{
    return self;
}

-(NSString *)formDisplayText
{
    return self.name;
}


-(NSString *)name
{
    if (Language.isRTL && self.arName.length) {
        return self.arName;
    }
    if (self.enName.length) {
        return self.enName;
    }
    return @"";
}
#pragma mark - User Country (Safe, Model-Based)

+ (CountryModel *)safeUserCountryModel
{
    UserModel *user = UserManager.shared.currentUser;

    // 1️⃣ Explicit user country ID (highest priority)
    if (user && [user respondsToSelector:@selector(CountryID)]) {
        NSInteger countryID = [[user valueForKey:@"CountryID"] integerValue];
        if (countryID > 0) {
            CountryModel *byID = [[CitiesManager shared] countryByID:countryID];
            if (byID) {
                return byID;
            }
        }
    }

    // 2️⃣ Saved user country ID from defaults
    NSInteger savedCountryID = [[NSUserDefaults standardUserDefaults] integerForKey:@"CountryID"];
    if (savedCountryID > 0) {
        CountryModel *bySavedID = [[CitiesManager shared] countryByID:savedCountryID];
        if (bySavedID) {
            return bySavedID;
        }
    }

    // 3️⃣ Explicit ISO from defaults (if stored)
    NSString *savedISO =
    [[[NSUserDefaults standardUserDefaults] stringForKey:@"CountryIsoCode"] uppercaseString];
    if (savedISO.length == 2) {
        CountryModel *byISO = [[CitiesManager shared] countryWithCode:savedISO];
        if (byISO) {
            return byISO;
        }
    }

    // 4️⃣ Device / app default country
    CountryModel *current =
    [[CitiesManager shared] CurrentCountry];
    if (current) {
        return current;
    }

    // 5️⃣ Stable manager fallback (never guesses a separate country source)
    return [[CitiesManager shared] qatarCountry] ?: [[CitiesManager shared] countries].firstObject;
}

+ (NSString *)safeCurrentCountryISOCode
{
    NSString *deviceISO = [[[[NSLocale currentLocale] objectForKey:NSLocaleCountryCode] description] uppercaseString];
    deviceISO = [deviceISO stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];

    // Prefer the real device country for pricing/payment so travel/location changes
    // are reflected immediately instead of being stuck on a stale saved profile country.
    if (deviceISO.length == 2) {
        CountryModel *deviceCountry = [[CitiesManager shared] countryWithCode:deviceISO];
        if (deviceCountry) {
            return deviceISO;
        }
    }

    NSString *savedISO = [[[[NSUserDefaults standardUserDefaults] stringForKey:@"CountryIsoCode"] description] uppercaseString];
    savedISO = [savedISO stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (savedISO.length == 2) {
        return savedISO;
    }

    CountryModel *country = [CountryModel safeUserCountryModel] ?: [CitiesManager.shared CurrentCountry];
    NSString *iso = country.iso;
    NSString *countryISO = [[(iso ?: @"") uppercaseString]
                            stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (countryISO.length == 2) {
        return countryISO;
    }

    if (deviceISO.length == 2) {
        return deviceISO;
    }

    return @"QA";
}

+ (NSString *)safeCurrentCurrencyCode
{
    NSString *countryISO = [self safeCurrentCountryISOCode];
    NSString *currencyCode = @"";

    if (countryISO.length == 2) {
        NSLocale *countryLocale = [[NSLocale alloc] initWithLocaleIdentifier:[NSString stringWithFormat:@"en_%@", countryISO]];
        id rawCurrency = [countryLocale objectForKey:NSLocaleCurrencyCode];
        if ([rawCurrency isKindOfClass:NSString.class]) {
            currencyCode = [(NSString *)rawCurrency stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        } else if ([rawCurrency respondsToSelector:@selector(stringValue)]) {
            currencyCode = [[rawCurrency stringValue] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        }
        currencyCode = currencyCode.uppercaseString;
    }

    if (currencyCode.length == 0) {
        id rawCurrency = [[NSLocale currentLocale] objectForKey:NSLocaleCurrencyCode];
        if ([rawCurrency isKindOfClass:NSString.class]) {
            currencyCode = [(NSString *)rawCurrency stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        } else if ([rawCurrency respondsToSelector:@selector(stringValue)]) {
            currencyCode = [[rawCurrency stringValue] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        }
        currencyCode = currencyCode.uppercaseString;
    }

    if (currencyCode.length == 0) {
        currencyCode = @"QAR";
    }
    return currencyCode;
}



@end
 

