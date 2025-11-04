#import "NavConstants.h"
#import "UIViewController+LayoutProtocol.h"

@implementation NavConstants

+ (NSDictionary *)getConstants {
    return @{
        @"topBarHeight" : @([self topBarHeight]),
#if !TARGET_OS_TV
        @"statusBarHeight" : @([self statusBarHeight]),
#endif
        @"bottomTabsHeight" : @([self bottomTabsHeight])
    };
}

#ifdef RCT_NEW_ARCH_ENABLED
+ (JS::NativeRNNTurboModule::Constants::Builder::Input)getTurboConstants {
	JS::NativeRNNTurboModule::Constants::Builder::Input input = {
		[self topBarHeight],
		[self statusBarHeight],
		[self bottomTabsHeight],
        [self backButtonId]
	};

	return input;
}
#endif

+ (CGFloat)topBarHeight {
    return [RCTPresentedViewController() getTopBarHeight];
}

#if !TARGET_OS_TV
+ (CGFloat)statusBarHeight {
    return [UIApplication sharedApplication].statusBarFrame.size.height;
}
#endif

+ (CGFloat)bottomTabsHeight {
    return [UIApplication.sharedApplication.delegate.window.rootViewController getBottomTabsHeight];
}

+ (NSString*)backButtonId {
    // This property is used only in android but we have to add it for compatability in turbo modules
    return @"";
}

@end
