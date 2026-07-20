//
//  StateModel.m
//  PurePetsPro
//
//  Created by Mohammed Ahmed on 6/28/26.
//
#import "StateModel.h"
@implementation StateModel
-(id)formValue
{
    return self;
}

-(NSString *)formDisplayText
{
    return Language.isRTL ? self.arName : self.enName;
}
@end
