//
//  CityModel.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 23/12/2025.
//

#import "CityModel.h"

@implementation CityModel

- (instancetype)init
{
    self = [super init];
    if (self) {
        _cityID = 0;
        _name = @"";
        _arName = @"";
        _enName = @"";
    }
    return self;
}

-(id)formValue
{
    return self;
}

- (NSString *)displayText
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

- (NSString *)formDisplayText
{
    return [self displayText];
}

+ (instancetype)cityWithcityID:(NSInteger)citycityID
                     arName:(NSString *)ar
                     enName:(NSString *)en
{
    CityModel *c = [[CityModel alloc] init];
    c.cityID = citycityID;
    c.arName = ar ?: @"";
    c.enName = en ?: @"";
    c.name = Language.isRTL ? c.arName : c.enName;
    return c;
}

@end
