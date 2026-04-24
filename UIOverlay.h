#import <UIKit/UIKit.h>
#import "MapManager.h"

@interface UIOverlay : NSObject

+ (instancetype)sharedOverlay;

// 显示悬浮按钮
- (void)showFloatingButton;

// 隐藏悬浮按钮
- (void)hideFloatingButton;

@end
