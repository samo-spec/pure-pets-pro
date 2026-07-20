//
//  PPUserMessagesViewController.h
//  PurePetsPro
//

#import <UIKit/UIKit.h>
#import <FirebaseFirestore/FirebaseFirestore.h>

@class ChatThreadModel;

NS_ASSUME_NONNULL_BEGIN

@interface PPUserMessagesViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate>

- (instancetype)initWithChatThread:(ChatThreadModel *)thread;

@end

NS_ASSUME_NONNULL_END