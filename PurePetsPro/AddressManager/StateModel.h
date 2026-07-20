//
//  StateModel.h
//  PurePetsPro
//
//  Created by Mohammed Ahmed on 6/28/26.
//

#import <Foundation/Foundation.h>
#import "XLForm.h"

@interface StateModel : NSObject<XLFormOptionObject>

@property (nonatomic, assign) NSInteger stateID;
@property (nonatomic, copy) NSString *enName;
@property (nonatomic, copy) NSString *arName;

@end
