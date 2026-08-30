//
//  PPChatsFunc.m
//  PurePetsPro
//
//  Adapted from Pure Pets IOS for messaging parity

#import "PPChatsFunc.h"
#import "Styling.h"
#import "ChatBubbleView.h"
#import <FirebaseStorage/FirebaseStorage.h>

// MARK: - Design Constants
static const CGFloat PPChatBubblePad = 12.0; // PPSpaceBase / 2

// MARK: - Helper Functions
static NSString *PPChatTrimmedString(id value)
{
    if (![value isKindOfClass:NSString.class]) return @"";
    return [(NSString *)value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}

static NSDate *PPChatThreadDateFromValue(id value)
{
    if ([value isKindOfClass:NSDate.class]) {
        return (NSDate *)value;
    }
    if ([value isKindOfClass:FIRTimestamp.class]) {
        return [(FIRTimestamp *)value dateValue];
    }
    if ([value isKindOfClass:NSNumber.class]) {
        return [NSDate dateWithTimeIntervalSince1970:[(NSNumber *)value doubleValue]];
    }
    return nil;
}

static BOOL PPChatIdentityFlagEnabled(id value)
{
    if ([value isKindOfClass:NSNumber.class]) {
        return [(NSNumber *)value boolValue];
    }
    NSString *normalized = [PPChatTrimmedString(value) lowercaseString];
    return [normalized isEqualToString:@"true"] ||
           [normalized isEqualToString:@"yes"] ||
           [normalized isEqualToString:@"1"] ||
           [normalized isEqualToString:@"enabled"] ||
           [normalized isEqualToString:@"active"];
}

// MARK: - Implementation
@implementation PPChatsFunc

// MARK: - Canvas Colors (using Pro's Styling system)
+ (UIColor *)chatCanvasBackgroundColor
{
    return [UIColor ppSurface];
}

+ (UIColor *)chatNeutralAccentColor
{
    return [UIColor ppInfo];
}

+ (UIColor *)bubbleSurfaceColorForIncoming:(BOOL)isIncoming
{
    // Incoming: light neutral, Outgoing: primary accent
    if (isIncoming) {
        return [UIColor ppElevatedSurface];
    }
    return [[UIColor ppInfo] colorWithAlphaComponent:0.82];
}

+ (UIColor *)bubblePrimaryContentColorForIncoming:(BOOL)isIncoming
{
    if (isIncoming) {
        return [UIColor ppTextPrimary];
    }
    return [UIColor ppElevatedSurface];
}

+ (UIColor *)bubbleSecondaryContentColorForIncoming:(BOOL)isIncoming
{
    if (isIncoming) {
        return [[UIColor ppTextPrimary] colorWithAlphaComponent:0.7];
    }
    return [[UIColor ppTextSecondary] colorWithAlphaComponent:0.86];
}

+ (UIColor *)bubbleStrokeColorForIncoming:(BOOL)isIncoming
{
    if (isIncoming) {
        return [[UIColor ppTextPrimary] colorWithAlphaComponent:0.15];
    }
    return [[UIColor ppSurface] colorWithAlphaComponent:0.13];
}

+ (UIColor *)bubbleInteractiveAccentColorForIncoming:(BOOL)isIncoming
{
    return isIncoming
        ? [self chatNeutralAccentColor]
        : [self bubblePrimaryContentColorForIncoming:NO];
}

+ (UIColor *)bubblePlaybackControlSurfaceColorForIncoming:(BOOL)isIncoming
{
    return isIncoming
        ? [[UIColor ppSurface] colorWithAlphaComponent:0.08]
        : [[UIColor ppSurface] colorWithAlphaComponent:0.17];
}

+ (UIColor *)bubbleWaveInactiveColorForIncoming:(BOOL)isIncoming
{
    return [[self bubbleSecondaryContentColorForIncoming:isIncoming]
        colorWithAlphaComponent:(isIncoming ? 0.22 : 0.26)];
}

+ (UIColor *)bubbleReplySurfaceColorForIncoming:(BOOL)isIncoming
{
    if (isIncoming) {
        return [[UIColor ppSurface] colorWithAlphaComponent:0.07];
    }
    return [[UIColor ppSurface] colorWithAlphaComponent:0.12];
}

// MARK: - Bubble Mask
+ (void)applyBubbleMask:(UIView *)bubble
             isIncoming:(BOOL)isIncoming
          groupPosition:(PPChatGroupPosition)position
               showGlow:(BOOL)showGlow
{
    [bubble layoutIfNeeded];
    
    CGRect b = bubble.bounds;
    if (CGRectIsEmpty(b)) return;
    
    CGFloat R = 20.0;
    CGFloat S = 6.0;
    CGFloat tl = R, tr = R, bl = R, br = R;
    
    // Use leading/trailing anchors for RTL safety
    BOOL usesLogicalTrailing = [self bubbleUsesTrailingAlignmentForIncoming:isIncoming];
    
    switch (position) {
        case PPChatGroupPositionSingle:
            // All corners rounded
            break;
            
        case PPChatGroupPositionFirst:
            if (usesLogicalTrailing) {
                br = S;
            } else {
                bl = S;
            }
            break;
            
        case PPChatGroupPositionMiddle:
            if (usesLogicalTrailing) {
                tr = S;
                br = S;
            } else {
                tl = S;
                bl = S;
            }
            break;
            
        case PPChatGroupPositionLast:
            if (usesLogicalTrailing) {
                tr = S;
            } else {
                tl = S;
            }
            break;
    }
    
    UIBezierPath *path = [UIBezierPath bezierPath];
    CGFloat w = b.size.width;
    CGFloat h = b.size.height;
    
    [path moveToPoint:CGPointMake(0, tl)];
    [path addQuadCurveToPoint:CGPointMake(tl, 0) controlPoint:CGPointZero];
    [path addLineToPoint:CGPointMake(w - tr, 0)];
    [path addQuadCurveToPoint:CGPointMake(w, tr) controlPoint:CGPointMake(w, 0)];
    [path addLineToPoint:CGPointMake(w, h - br)];
    [path addQuadCurveToPoint:CGPointMake(w - br, h) controlPoint:CGPointMake(w, h)];
    [path addLineToPoint:CGPointMake(bl, h)];
    [path addQuadCurveToPoint:CGPointMake(0, h - bl) controlPoint:CGPointMake(0, h)];
    [path closePath];
    
    CAShapeLayer *mask = (CAShapeLayer *)bubble.layer.mask;
    if (![mask isKindOfClass:CAShapeLayer.class]) {
        mask = [CAShapeLayer layer];
        bubble.layer.mask = mask;
    }
    
    CGPathRef newPath = path.CGPath;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    mask.frame = b;
    mask.path = newPath;
    [CATransaction commit];
}

+ (BOOL)bubbleUsesTrailingAlignmentForIncoming:(BOOL)isIncoming
{
    // In LTR, incoming bubbles align to leading (left), outgoing align to trailing (right)
    // In RTL, it's the opposite
    return isIncoming ? NO : YES; // Default LTR behavior
}

// MARK: - Status Icons
+ (NSString *)pp_accessibilityLabelForMessageStatus:(ChatMessageStatus)status
{
    switch (status) {
        case ChatMessageStatusSending:
            return @"Sending";
        case ChatMessageStatusSent:
            return @"Sent";
        case ChatMessageStatusDelivered:
            return @"Delivered";
        case ChatMessageStatusRead:
            return @"Read";
        default:
            return @"";
    }
}

+ (void)applyStatusForMessage:(ChatMessageModel *)message
                   toImageView:(UIImageView *)imageView
                    isIncoming:(BOOL)isIncoming
                      animated:(BOOL)animated
{
    if (!imageView) return;
    if (!message || isIncoming || message.isDeleted) {
        imageView.hidden = YES;
        imageView.image = nil;
        imageView.accessibilityLabel = nil;
        return;
    }
    
    UIImage *image = nil;
    UIColor *tint = [[self bubbleSecondaryContentColorForIncoming:NO] colorWithAlphaComponent:0.74];
    
    switch (message.status) {
        case ChatMessageStatusSending:
            image = [UIImage systemImageNamed:@"clock"];
            break;
        case ChatMessageStatusSent:
            image = [UIImage systemImageNamed:@"checkmark"];
            break;
        case ChatMessageStatusDelivered:
            image = [UIImage systemImageNamed:@"checkmark.circle"];
            tint = [[self bubbleSecondaryContentColorForIncoming:NO] colorWithAlphaComponent:0.92];
            break;
        case ChatMessageStatusRead:
            image = [UIImage systemImageNamed:@"checkmark.circle.fill"];
            tint = [self bubblePrimaryContentColorForIncoming:NO];
            break;
        default:
            break;
    }
    
    imageView.image = image;
    imageView.tintColor = tint;
    imageView.hidden = (image == nil);
    imageView.accessibilityLabel = [self pp_accessibilityLabelForMessageStatus:message.status];
}

+ (void)applyGlowIfNeededToBubble:(UIView *)bubble
                            path:(UIBezierPath *)path
                        showGlow:(BOOL)showGlow
                      isIncoming:(BOOL)isIncoming
{
    static NSString *kGlowLayerName = @"pp_bubble_glow";
    
    for (CALayer *l in bubble.layer.sublayers.copy) {
        if ([l.name isEqualToString:kGlowLayerName]) {
            [l removeFromSuperlayer];
        }
    }
    
    if (!showGlow) return;
    
    CAShapeLayer *glow = [CAShapeLayer layer];
    glow.name = kGlowLayerName;
    glow.path = path.CGPath;
    glow.fillColor = UIColor.clearColor.CGColor;
    
    UIColor *glowColor = [[self bubbleInteractiveAccentColorForIncoming:isIncoming]
        colorWithAlphaComponent:(isIncoming ? 0.20 : 0.04)];
    
    glow.strokeColor = glowColor.CGColor;
    glow.lineWidth = 1.2;
    glow.shadowColor = glowColor.CGColor;
    glow.shadowRadius = 6.0;
    glow.shadowOpacity = 1.0;
    glow.shadowOffset = CGSizeMake(0, 2);
    
    bubble.layer.masksToBounds = NO;
    [bubble.layer addSublayer:glow];
}

// MARK: - Button Helper
+ (UIButton *)buttonWithSystemName:(NSString *)imageName
                        buttonSide:(float)side
                          target:(id)target
                          action:(nullable SEL)action
{
    NSParameterAssert(imageName.length > 0);
    
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImage *img = [UIImage systemImageNamed:imageName];
    [btn setImage:img forState:UIControlStateNormal];
    btn.tintColor = [UIColor ppTextPrimary];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    [btn.widthAnchor constraintEqualToConstant:side].active = YES;
    [btn.heightAnchor constraintEqualToConstant:side].active = YES;
    btn.layer.masksToBounds = YES;
    
    if (target && action) {
        [btn addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    }
    
    return btn;
}

#pragma mark - Currency Formatting (stripped from iOS)

+ (NSString *)formattedCurrency:(CGFloat)value
{
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterCurrencyStyle;
    formatter.currencyCode = @"QAR";
    formatter.maximumFractionDigits = 2;
    formatter.minimumFractionDigits = 2;
    formatter.roundingMode = NSNumberFormatterRoundHalfUp;
    
    NSString *formatted = [formatter stringFromNumber:@(value)];
    if (formatted.length > 0) {
        return formatted;
    }
    
    // Fallback
    NSNumberFormatter *decimalFormatter = [[NSNumberFormatter alloc] init];
    decimalFormatter.numberStyle = NSNumberFormatterDecimalStyle;
    decimalFormatter.maximumFractionDigits = 2;
    decimalFormatter.minimumFractionDigits = 2;
    decimalFormatter.roundingMode = NSNumberFormatterRoundHalfUp;
    
    NSString *amount = [decimalFormatter stringFromNumber:@(value)] ?: @"0.00";
    return [NSString stringWithFormat:@"%@ %@", amount, @"ر.ق"];
}

+ (NSString *)pp_forceLatinDigits:(NSString *)input
{
    if (!input.length) return input;
    NSMutableString *result = [input mutableCopy];
    // Arabic-Indic digits ٠١٢٣٤٥٦٧٨٩ → 0123456789
    NSDictionary *map = @{
        @"٠": @"0", @"١": @"1", @"٢": @"2", @"٣": @"3", @"٤": @"4",
        @"٥": @"5", @"٦": @"6", @"٧": @"7", @"٨": @"8", @"٩": @"9",
        @"۰": @"0", @"۱": @"1", @"۲": @"2", @"۳": @"3", @"۴": @"4",
        @"۵": @"5", @"۶": @"6", @"۷": @"7", @"۸": @"8", @"۹": @"9"
    };
    for (NSString *key in map) {
        [result replaceOccurrencesOfString:key
                              withString:map[key]
                                 options:0
                                   range:NSMakeRange(0, result.length)];
    }
    return [result copy];
}

@end