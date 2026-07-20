//
//  PPUserCell.m
//

#import "PPUserCell.h"

@implementation PPUserCell

+ (NSString *)reuseIdentifier { return @"PPUserCell"; }

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if (self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier ?: PPUserCell.reuseIdentifier]) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;

        _avatarImageView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"person.crop.circle.fill"]];
        _avatarImageView.translatesAutoresizingMaskIntoConstraints = NO;
        _avatarImageView.layer.cornerRadius = 27;
        _avatarImageView.clipsToBounds = YES;
        _avatarImageView.contentMode = UIViewContentModeScaleAspectFill;
        _avatarImageView.tintColor = AppPrimaryClr;
        
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _titleLabel.font = [Styling fontMedium:18];
        _titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
        
        
        _subtitleLabel = [[UILabel alloc] init];
        _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _subtitleLabel.font = [Styling fontMedium:14];
        _subtitleLabel.textColor = SeconderyTextClr;
        _subtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;

        _actionButton = [UIButton buttonWithType:UIButtonTypeSystem];
        _actionButton.translatesAutoresizingMaskIntoConstraints = NO;
        _actionButton.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
        [_actionButton setImage:[UIImage systemImageNamed:Language.languageVal == 0 ? @"chevron.right" : @"chevron.left"] forState:UIControlStateNormal];
        _actionButton.tintColor = SeconderyTextClr;
        [_actionButton addTarget:self action:@selector(onTapAction) forControlEvents:UIControlEventTouchUpInside];

        _setAdminButton = [UIButton buttonWithType:UIButtonTypeSystem];
        _setAdminButton.translatesAutoresizingMaskIntoConstraints = NO;
        _setAdminButton.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
        //[_setAdminButton setTitle:NSLocalizedString(@"Admin", nil) forState:UIControlStateNormal];
        [_setAdminButton addTarget:self action:@selector(onTapSetAdmin) forControlEvents:UIControlEventTouchUpInside];
        [_setAdminButton setImage:[UIImage systemImageNamed:@"key"] forState:UIControlStateNormal];
        [PPButtonHelper attachTapAnimationToButton:_setAdminButton style:PPButtonAnimationStyleGlow];
        
        
        
        [self.contentView addSubview:_avatarImageView];
        [self.contentView addSubview:_titleLabel];
        [self.contentView addSubview:_subtitleLabel];
        [self.contentView addSubview:_actionButton];
        [self.contentView addSubview:_setAdminButton];

        CGFloat pad = 12.0;

        [NSLayoutConstraint activateConstraints:@[
            [_avatarImageView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:pad],
            [_avatarImageView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_avatarImageView.widthAnchor constraintEqualToConstant:54],
            [_avatarImageView.heightAnchor constraintEqualToConstant:54],

            [_actionButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-pad],
            [_actionButton.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],

            [_setAdminButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-pad],
            [_setAdminButton.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],

            [_titleLabel.leadingAnchor constraintEqualToAnchor:_avatarImageView.trailingAnchor constant:12],
            [_titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_setAdminButton.leadingAnchor constant:-8],
            [_titleLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:pad],

            [_subtitleLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
            [_subtitleLabel.trailingAnchor constraintEqualToAnchor:_titleLabel.trailingAnchor],
            [_subtitleLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:2],
            [_subtitleLabel.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-pad]
        ]];
    }
    return self;
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.avatarImageView.image = [UIImage systemImageNamed:@"person.crop.circle.fill"];
    self.titleLabel.text = @"";
    self.subtitleLabel.text = @"";
    self.cellUser = nil;
    self.representedUID = nil;
    self.viewFor = ViewForDefault;
    self.actionButton.hidden = NO;
    self.setAdminButton.hidden = NO;
}

- (void)configureWithUser:(UserModel *)user indexPath:(NSIndexPath *)indexPath {
    [self configureWithUser:user indexPath:indexPath viewFor:ViewForDefault];
}

- (void)configureWithUser:(UserModel *)user
                indexPath:(NSIndexPath *)indexPath
                  viewFor:(ViewFor)viewFor
{
    self.cellUser = user;
    self.indexPath = indexPath;
    self.representedUID = user.uid;
    self.viewFor = viewFor;
    // Texts
    self.titleLabel.text = user.UserName.length ? user.UserName : (user.UserEmail ?: @"");
    NSString *email =  ([user.UserEmail isKindOfClass:NSString.class] ? user.UserEmail : @"");
    NSString *mobile =([user.MobileNo isKindOfClass:NSString.class] ? user.MobileNo : @"");
    self.subtitleLabel.text = (email.length && mobile.length) ? [NSString stringWithFormat:@"%@  •  %@", email, mobile] : (email.length ? email : mobile);

    // Buttons visibility per viewFor
  
    if(viewFor == ViewForAdminToggle)
    {
      
        
        self.setAdminButton.hidden = NO;
        self.actionButton.hidden = NO;
        CGFloat pad = 25.0;
        CGFloat btnSize = 36.0;
        [NSLayoutConstraint activateConstraints:@[
            [_setAdminButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-pad],
            [_setAdminButton.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_setAdminButton.widthAnchor constraintEqualToConstant:btnSize],
            [_setAdminButton.heightAnchor constraintEqualToConstant:btnSize],
            
            [_actionButton.trailingAnchor constraintEqualToAnchor:_setAdminButton.trailingAnchor constant:-pad * 2],
            [_actionButton.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            
            [_actionButton.widthAnchor constraintEqualToConstant:btnSize],
            [_actionButton.heightAnchor constraintEqualToConstant:btnSize]
        ]];
        
        
        
        [self.actionButton setImage:[UIImage systemImageNamed: user.isBlocked ?  @"lock.fill" : @"lock.open.fill"] forState:UIControlStateNormal];
        
    }
    else if(viewFor == ViewForEditRoleAndPermissions)
    {
        self.setAdminButton.hidden = YES;
        self.actionButton.hidden = NO;
        CGFloat btnSize = 36.0;

        [NSLayoutConstraint activateConstraints:@[
            [_actionButton.widthAnchor constraintEqualToConstant:btnSize],
            [_actionButton.heightAnchor constraintEqualToConstant:btnSize]
        ]];
    }
    
    else
    {
        CGFloat btnSize = 36.0;
        [NSLayoutConstraint activateConstraints:@[
            [_actionButton.widthAnchor constraintEqualToConstant:btnSize],
            [_actionButton.heightAnchor constraintEqualToConstant:btnSize],
            [_setAdminButton.widthAnchor constraintEqualToConstant:btnSize],
            [_setAdminButton.heightAnchor constraintEqualToConstant:btnSize]
        ]];
        
        self.setAdminButton.hidden = NO;
        self.actionButton.hidden = NO;
          
    }

    // Visual state for admin button
   
    // Visual state for admin button
    UIColor *isBlockedTint = user.isBlocked ? AppPrimaryClr : SeconderyTextClr;
    [Styling applyIconButtonStyle:self.actionButton tintColor:isBlockedTint backgroundColor:AppBackgroundClr];
    
    
    UIColor *adminTint = user.isAdmin ? AppPrimaryClr : SeconderyTextClr;
    [Styling applyIconButtonStyle:self.setAdminButton tintColor:adminTint backgroundColor:AppBackgroundClr];

    [self.setAdminButton setImage:[UIImage systemImageNamed: user.isAdmin ?  @"key.fill" : @"key"] forState:UIControlStateNormal];

    self.setAdminButton.layer.shadowOpacity = 0.12f;
    self.setAdminButton.layer.shadowRadius = 3.0f;
    
    self.actionButton.layer.shadowOpacity = 0.12f;
    self.actionButton.layer.shadowRadius = 3.0f;

    // TODO: async image set if you have a helper (guard with representedUID)
    // Example:
    // __weak typeof(self) weakSelf = self;
    // [SomeImageLoader load:user.UserImageUrl.absoluteString completion:^(UIImage *img){
    //     __strong typeof(weakSelf) self = weakSelf;
    //     if (!self || ![self.representedUID isEqualToString:user.uid]) return;
    //     self.avatarImageView.image = img ?: [UIImage systemImageNamed:@"person.crop.circle.fill"];
    // }];
    
    self.avatarImageView.image = [UIImage systemImageNamed:@"person.crop.circle.fill"]; // fallback
    if (user.UserImageUrl.absoluteString.length > 0) {
        // Example async load if you use SDWebImage:
         [self.avatarImageView setImageFromUrl:user.UserImageUrl.absoluteString Blr:NO Shimmering:YES];
    }
}

#pragma mark - Actions (delegate → VC)

- (void)onTapAction {
    if ([self.delegate respondsToSelector:@selector(userCellDidTapAction:user:)]) {
        [self.delegate userCellDidTapAction:self user:self.cellUser];
    }
}

- (void)onTapSetAdmin {
    if ([self.delegate respondsToSelector:@selector(userCellDidTapSetAdmin:user:)]) {
        [self.delegate userCellDidTapSetAdmin:self user:self.cellUser];
    }
}

@end
