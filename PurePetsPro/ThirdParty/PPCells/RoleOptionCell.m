//
//  RoleOptionCell.m
//  PurePetsAdmin
//
//  Created by Mohammed Ahmed on 22/08/2025.
//


// RoleOptionCell.m
#import "RoleOptionCell.h"

@implementation RoleOptionCell

+ (void)load {
    [XLFormViewController.cellClassesForRowDescriptorTypes setObject:self forKey:@"RoleOptionCell"];
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if (self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier]) {
        self.selectionStyle = UITableViewCellSelectionStyleDefault;
        
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.font = [Styling fontMedium:16];
        _titleLabel.textColor = PrimaryTextClr;
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
        [self.contentView addSubview:_titleLabel];
        
        _subtitleLabel = [[UILabel alloc] init];
        _subtitleLabel.font = [Styling fontRegular:14];
        _subtitleLabel.textColor = SeconderyTextClr;
        _subtitleLabel.numberOfLines = 0;
        _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _subtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
        [self.contentView addSubview:_subtitleLabel];
        
        [NSLayoutConstraint activateConstraints:@[
            [_titleLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:8],
            [_titleLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
            [_titleLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
            
            [_subtitleLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:4],
            [_subtitleLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
            [_subtitleLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
            [_subtitleLabel.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-8]
        ]];
    }
    return self;
}

- (void)update {
    [super update];
    
    XLFormOptionsObject *option = self.rowDescriptor.value;
    if ([option isKindOfClass:[XLFormOptionsObject class]]) {
        self.titleLabel.text = option.displayText;
        if ([option respondsToSelector:@selector(userInfo)]) {
            NSDictionary *info = [option performSelector:@selector(userInfo)];
            self.subtitleLabel.text = info[@"desc"] ?: @"";
        }
    }
}

@end
