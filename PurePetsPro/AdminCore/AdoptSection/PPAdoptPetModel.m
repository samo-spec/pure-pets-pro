//
//  PPAdoptPetModel.m
//  PurePetsPro
//

#import "PPAdoptPetModel.h"
#import "PPFirebaseCompat.h"

static NSString *PPAdoptPetString(id value) {
    return [value isKindOfClass:NSString.class] ? (NSString *)value : @"";
}

static NSString *PPAdoptPetTrim(NSString *value) {
    return [[value ?: @"" stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] copy];
}

static NSInteger PPAdoptPetInteger(id value) {
    return [value respondsToSelector:@selector(integerValue)] ? [value integerValue] : 0;
}

static NSDate * _Nullable PPAdoptPetDateFromValue(id value) {
    if ([value isKindOfClass:NSDate.class]) {
        return value;
    }
    if ([value isKindOfClass:FIRTimestamp.class]) {
        return [(FIRTimestamp *)value dateValue];
    }
    return nil;
}

static id PPAdoptPetFirestoreDate(NSDate *date) {
    if (!date) return nil;
    return [FIRTimestamp timestampWithDate:date];
}

@implementation PPAdoptPetModel

- (instancetype)init {
    self = [super init];
    if (self) {
        _petID = @"";
        _title = @"";
        _descriptionText = @"";
        _status = @"available";
        _ownerID = @"";
        _kindID = 0;
        _breedID = 0;
        _ageMonths = 0;
        _cityID = 0;
        _gender = @"";
        _visibility = 0;
        _isBlocked = NO;
        _isDeleted = NO;
        _imageURLs = @[];
        _isAdopted = NO;
        _adopterUserID = @"";
        _adopterName = @"";
        _adopterContact = @"";
    }
    return self;
}

- (NSDictionary *)toDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    NSString *title = PPAdoptPetTrim(self.title);
    NSString *details = PPAdoptPetTrim(self.descriptionText);
    NSString *status = PPAdoptPetTrim(self.status).length > 0 ? PPAdoptPetTrim(self.status) : (self.isAdopted ? @"adopted" : @"available");

    if (self.petID.length > 0) {
        dict[@"petID"] = self.petID;
        dict[@"documentID"] = self.petID;
    }
    if (title.length > 0) {
        dict[@"title"] = title;
        dict[@"name"] = title;
    }
    if (details.length > 0) {
        dict[@"description"] = details;
        dict[@"details"] = details;
    }
    if (self.ownerID.length > 0) dict[@"ownerID"] = self.ownerID;
    dict[@"status"] = status;
    dict[@"isAdopted"] = @(self.isAdopted || [status isEqualToString:@"adopted"]);
    dict[@"visibility"] = @(self.visibility);
    if (self.kindID > 0) dict[@"kindID"] = @(self.kindID);
    if (self.breedID > 0) dict[@"breedID"] = @(self.breedID);
    if (self.ageMonths > 0) dict[@"ageMonths"] = @(self.ageMonths);
    if (self.cityID > 0) dict[@"cityID"] = @(self.cityID);
    if (self.gender.length > 0) dict[@"gender"] = self.gender;
    if (self.imageURLs.count > 0) dict[@"imageURLs"] = self.imageURLs;
    if (self.adopterName.length > 0) dict[@"adopterName"] = self.adopterName;
    if (self.adopterContact.length > 0) dict[@"adopterContact"] = self.adopterContact;
    if (self.adopterUserID.length > 0) dict[@"adopterUserID"] = self.adopterUserID;
    id createdAt = PPAdoptPetFirestoreDate(self.createdAt);
    id updatedAt = PPAdoptPetFirestoreDate(self.updatedAt);
    if (createdAt) dict[@"createdAt"] = createdAt;
    if (updatedAt) dict[@"updatedAt"] = updatedAt;
    return dict.copy;
}

- (instancetype)initWithDictionary:(NSDictionary *)dict {
    self = [self init];
    if (self) {
        _petID = PPAdoptPetString(dict[@"petID"]).length > 0 ? PPAdoptPetString(dict[@"petID"]) : PPAdoptPetString(dict[@"documentID"]);
        NSString *title = PPAdoptPetString(dict[@"title"]).length > 0 ? PPAdoptPetString(dict[@"title"]) : PPAdoptPetString(dict[@"name"]);
        NSString *details = PPAdoptPetString(dict[@"description"]).length > 0 ? PPAdoptPetString(dict[@"description"]) : PPAdoptPetString(dict[@"details"]);
        _title = title ?: @"";
        _descriptionText = details ?: @"";
        _status = PPAdoptPetString(dict[@"status"]).length > 0 ? PPAdoptPetString(dict[@"status"]) : @"available";
        _ownerID = PPAdoptPetString(dict[@"ownerID"]).length > 0 ? PPAdoptPetString(dict[@"ownerID"]) : PPAdoptPetString(dict[@"userID"]);
        _kindID = PPAdoptPetInteger(dict[@"kindID"]);
        _breedID = PPAdoptPetInteger(dict[@"breedID"]);
        _ageMonths = PPAdoptPetInteger(dict[@"ageMonths"]);
        _cityID = PPAdoptPetInteger(dict[@"cityID"]);
        _gender = PPAdoptPetString(dict[@"gender"]);
        _visibility = PPAdoptPetInteger(dict[@"visibility"]);
        _isBlocked = [dict[@"isBlocked"] respondsToSelector:@selector(boolValue)] ? [dict[@"isBlocked"] boolValue] : NO;
        _isDeleted = [dict[@"isDeleted"] respondsToSelector:@selector(boolValue)] ? [dict[@"isDeleted"] boolValue] : NO;
        _isAdopted = [dict[@"isAdopted"] respondsToSelector:@selector(boolValue)] ? [dict[@"isAdopted"] boolValue] : [_status isEqualToString:@"adopted"];
        _adopterName = PPAdoptPetString(dict[@"adopterName"]);
        _adopterContact = PPAdoptPetString(dict[@"adopterContact"]);
        _adopterUserID = PPAdoptPetString(dict[@"adopterUserID"]);
        _createdAt = PPAdoptPetDateFromValue(dict[@"createdAt"]);
        _updatedAt = PPAdoptPetDateFromValue(dict[@"updatedAt"]);

        NSArray *rawURLs = [dict[@"imageURLs"] isKindOfClass:NSArray.class] ? dict[@"imageURLs"] : @[];
        NSMutableArray<NSString *> *urls = [NSMutableArray array];
        for (id raw in rawURLs) {
            if ([raw isKindOfClass:NSString.class] && [raw length] > 0) {
                [urls addObject:raw];
            }
        }
        _imageURLs = urls.copy;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    PPAdoptPetModel *copy = [[[self class] allocWithZone:zone] init];
    copy.petID = self.petID;
    copy.title = self.title;
    copy.descriptionText = self.descriptionText;
    copy.status = self.status;
    copy.ownerID = self.ownerID;
    copy.kindID = self.kindID;
    copy.breedID = self.breedID;
    copy.ageMonths = self.ageMonths;
    copy.cityID = self.cityID;
    copy.gender = self.gender;
    copy.visibility = self.visibility;
    copy.isBlocked = self.isBlocked;
    copy.isDeleted = self.isDeleted;
    copy.imageURLs = self.imageURLs;
    copy.adopterUserID = self.adopterUserID;
    copy.isAdopted = self.isAdopted;
    copy.adopterName = self.adopterName;
    copy.adopterContact = self.adopterContact;
    copy.createdAt = self.createdAt;
    copy.updatedAt = self.updatedAt;
    return copy;
}

@end
