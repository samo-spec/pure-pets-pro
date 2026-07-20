//
//  PPCategoryPickerController.h
//  PurePetsPro
//
//  Created by Mohammed Ahmed on 6/9/26.
//


@interface PPCategoryPickerController : UIViewController <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, assign) NSInteger selectedMainID;
@property (nonatomic, assign) NSInteger selectedSubID;
@property (nonatomic, copy) void (^onSelection)(NSInteger, NSInteger);
@property (nonatomic, strong) NSArray<MainKindsModel *> *kinds;
@property (nonatomic, assign) NSInteger expandedMainID;
@property (nonatomic, assign) BOOL hasAnimatedIn;
@property (nonatomic, strong) NSMutableSet<NSNumber *> *animatedSections;
- (instancetype)initWithSelectedMainID:(NSInteger)mainID selectedSubID:(NSInteger)subID;
- (void)setOnSelection:(void (^)(NSInteger, NSInteger))block;
+ (NSString *)displayNameForMainCategoryID:(NSInteger)mainID subCategoryID:(NSInteger)subID;
@end