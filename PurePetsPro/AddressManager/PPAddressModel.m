


#import "PPAddressModel.h"
#import "Language.h"
@import FirebaseFirestore;

@implementation PPAddressModel

+ (BOOL)supportsSecureCoding { return YES; }

#pragma mark - Init / Dictionary

- (instancetype)initWithDictionary:(NSDictionary *)dictionary documentID:(nullable NSString *)docID {
    self = [super init];
    if (!self) return nil;
    
    _documentID   = docID ?: @"";
    _addressID    = [dictionary[@"addressID"] isKindOfClass:NSString.class] ? dictionary[@"addressID"] : _documentID;
    _userID       = [dictionary[@"userID"] isKindOfClass:NSString.class] ? dictionary[@"userID"] : @"";
    _fullName     = dictionary[@"fullName"] ?: @"";
    NSString *rawPhone = [dictionary[@"phoneNumber"] isKindOfClass:NSString.class] ? dictionary[@"phoneNumber"] : nil;
    if (rawPhone.length == 0) rawPhone = [dictionary[@"phone"] isKindOfClass:NSString.class] ? dictionary[@"phone"] : nil;
    if (rawPhone.length == 0) rawPhone = [dictionary[@"MobileNo"] isKindOfClass:NSString.class] ? dictionary[@"MobileNo"] : nil;
    _phoneNumber  = rawPhone ?: @"";
    _addressLine1 = dictionary[@"addressLine1"] ?: @"";
    _addressLine2 = dictionary[@"addressLine2"];
    _cityID       = [dictionary[@"cityID"] integerValue];
    _stateID      = [dictionary[@"stateID"] integerValue];
    _postalCode   = dictionary[@"postalCode"] ?: @"";
    _isDefault    = [dictionary[@"isDefault"] boolValue];
    
    _locatioName   = dictionary[@"locatioName"] ?: @"";
    _locationPoints    = dictionary[@"locationPoints"] ?: @"";

    id createdAtValue = dictionary[@"createdAt"];
    if ([createdAtValue isKindOfClass:[FIRTimestamp class]]) {
        _createdAt = ((FIRTimestamp *)createdAtValue).dateValue;
    } else if ([createdAtValue isKindOfClass:[NSDate class]]) {
        _createdAt = createdAtValue;
    }
    id updatedAtValue = dictionary[@"updatedAt"];
    if ([updatedAtValue isKindOfClass:[FIRTimestamp class]]) {
        _updatedAt = ((FIRTimestamp *)updatedAtValue).dateValue;
    } else if ([updatedAtValue isKindOfClass:[NSDate class]]) {
        _updatedAt = updatedAtValue;
    }
    
    return self;
}

- (NSDictionary *)toDictionary {
    NSDate *now = [NSDate date];
    NSMutableDictionary *dict = [@{
        @"addressID": self.addressID.length > 0 ? self.addressID : self.documentID ?: @"",
        @"userID": self.userID ?: @"",
        @"fullName": self.fullName ?: @"",
        @"phoneNumber": self.phoneNumber ?: @"",
        @"locatioName": self.locatioName ?: @"",
        @"locationPoints": self.locationPoints ?: @"",
        @"addressLine1": self.addressLine1 ?: @"",
        @"postalCode": self.postalCode ?: @"",
        @"isDefault": @(self.isDefault),
        @"cityID":  @(self.cityID),
        @"stateID":  @(self.stateID ),
        @"updatedAt": self.updatedAt ?: now,
    } mutableCopy];
    if (self.createdAt) {
        dict[@"createdAt"] = self.createdAt;
    }
    
    if (self.addressLine2.length > 0)
        dict[@"addressLine2"] = self.addressLine2;
    
    return dict;
}

- (BOOL)isSemanticallyValid
{
    NSString *trimmedName = [self.fullName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *trimmedLine1 = [self.addressLine1 stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *trimmedPostal = [self.postalCode stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return trimmedName.length > 0 &&
           trimmedLine1.length > 0 &&
           trimmedPostal.length > 0 &&
           self.cityID > 0 &&
           self.stateID > 0;
}

#pragma mark - NSSecureCoding

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.documentID forKey:@"documentID"];
    [coder encodeObject:self.addressID forKey:@"addressID"];
    [coder encodeObject:self.userID forKey:@"userID"];
    [coder encodeObject:self.fullName forKey:@"fullName"];
    [coder encodeObject:self.phoneNumber forKey:@"phoneNumber"];
    [coder encodeObject:self.addressLine1 forKey:@"addressLine1"];
    [coder encodeObject:self.addressLine2 forKey:@"addressLine2"];
    [coder encodeInteger:self.cityID forKey:@"cityID"];
    [coder encodeInteger:self.stateID forKey:@"stateID"];
    [coder encodeObject:self.postalCode forKey:@"postalCode"];
    [coder encodeBool:self.isDefault forKey:@"isDefault"];
    [coder encodeObject:self.locationPoints forKey:@"locationPoints"];
    [coder encodeObject:self.locatioName forKey:@"locatioName"];
    [coder encodeObject:self.createdAt forKey:@"createdAt"];
    [coder encodeObject:self.updatedAt forKey:@"updatedAt"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (!self) return nil;
    
    _documentID   = [coder decodeObjectOfClass:[NSString class] forKey:@"documentID"] ?: @"";
    _addressID    = [coder decodeObjectOfClass:[NSString class] forKey:@"addressID"] ?: _documentID;
    _userID       = [coder decodeObjectOfClass:[NSString class] forKey:@"userID"] ?: @"";
    _fullName     = [coder decodeObjectOfClass:[NSString class] forKey:@"fullName"] ?: @"";
    _phoneNumber  = [coder decodeObjectOfClass:[NSString class] forKey:@"phoneNumber"] ?: @"";
    _addressLine1 = [coder decodeObjectOfClass:[NSString class] forKey:@"addressLine1"] ?: @"";
    _addressLine2 = [coder decodeObjectOfClass:[NSString class] forKey:@"addressLine2"];
    _cityID       = [coder decodeIntegerForKey:@"cityID"];
    _stateID      = [coder decodeIntegerForKey:@"stateID"];
    _postalCode   = [coder decodeObjectOfClass:[NSString class] forKey:@"postalCode"] ?: @"";
    _isDefault    = [coder decodeBoolForKey:@"isDefault"];
    _locatioName   = [coder decodeObjectOfClass:[NSString class] forKey:@"locatioName"] ?: @"";
    _locationPoints   = [coder decodeObjectOfClass:[NSString class] forKey:@"locationPoints"] ?: @"";
    _createdAt = [coder decodeObjectOfClass:[NSDate class] forKey:@"createdAt"];
    _updatedAt = [coder decodeObjectOfClass:[NSDate class] forKey:@"updatedAt"];
    return self;
}

#pragma mark - Country Helpers



- (NSString *)emojiFlagForCountryCode:(NSString *)countryCode {
    if (countryCode.length < 2) return @"";
    NSString *code = [[countryCode substringToIndex:2] uppercaseString];
    
    int base = 127397; // regional indicator base
    uint32_t first = [code characterAtIndex:0] + base;
    uint32_t second = [code characterAtIndex:1] + base;
    
    // Combine both into a proper UTF-32 array
    uint32_t scalars[] = { first, second };
    NSString *flag = [[NSString alloc] initWithBytes:scalars
                                              length:sizeof(scalars)
                                            encoding:NSUTF32LittleEndianStringEncoding];
    return flag;
}




- (nullable NSString *)countryDisplay {
    CountryModel *country = [CitiesManager.shared CurrentCountry];
    if (!country) return nil;
    
    NSString *flag = [self emojiFlagForCountryCode:country.iso];
    NSData *data = [flag dataUsingEncoding:NSUTF8StringEncoding];
    //NSLog(@"Flag: %@ (%@)", flag, data);
    NSString *name = Language.isRTL ? country.arName : country.enName;
    
    return flag.length ? [NSString stringWithFormat:@"%@ %@", flag, name] : name;
}

#pragma mark - Display Name

- (NSString *)displayName {
    CityModel *city = [CitiesManager.shared cityByID:self.cityID];
    StateModel *state = [CitiesManager.shared stateByID:self.stateID];
    

    NSString *cityName  = city ? (Language.isRTL ? city.arName : city.enName) : @"";
    NSString *stateName = state ? (Language.isRTL ? state.arName : state.enName) : @"";
    NSString *country   = [self safeString:self.countryDisplay ?: @""];
    NSString *address1  = [self safeString:self.addressLine1];
    NSString *address2  = [self safeString:self.addressLine2];
    

    //NSLog(@"cityName  %@",cityName);
    //NSLog(@"stateName %@",stateName);
    //NSLog(@"country   %@",country);
    //NSLog(@"address1 %@",address1);
   // NSLog(@"address2 %@",address2);
    
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    if (address1.length) [parts addObject:address1];
    if (address2.length) [parts addObject:address2];
    if (stateName.length) [parts addObject:stateName];
    if (cityName.length) [parts addObject:cityName];
    if (self.postalCode.length) [parts addObject:self.postalCode];
    if (country.length) [parts addObject:country];

    
    NSString *joined = [parts componentsJoinedByString:@", "];
    if (self.isDefault) {
        joined = [joined stringByAppendingFormat:@" (%@)", kLang(@"Default")];
    }
    return joined;
}

- (NSString *)safeString:(NSString *)string {
    if (!string) return @"";
    // Replace invalid UTF8 or control chars
    NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"";
}

-(id)formValue
{
    return self;
}

-(NSString *)formDisplayText
{
    return self.displayName;
}
@end
