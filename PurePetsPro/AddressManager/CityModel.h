//
//  CityModel.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 23/12/2025.
//

#import <Foundation/Foundation.h>
#import "XLForm.h"

@class CountryModel;
@class StateModel;
 


@interface CityModel : NSObject<XLFormOptionObject>
+ (instancetype)cityWithcityID:(NSInteger)citycityID
                     arName:(NSString *)ar
                        enName:(NSString *)en;

@property (nonatomic, assign) NSInteger cityID;
@property (nonatomic, copy) NSString *enName;
@property (nonatomic, copy) NSString *arName;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) double latitude;
@property (nonatomic, assign) double longitude;
@property (nonatomic, strong) NSArray<StateModel *> *states;
@property (nonatomic, weak) CountryModel *country;

@end
