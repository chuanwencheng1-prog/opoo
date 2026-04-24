//==============================================================
//  MapReplacer Tweak - 地图 PAK 文件替换插件
//  注入目标: ShadowTrackerExtra (com.tencent.ig)
//==============================================================

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "MapManager.h"
#import "UIOverlay.h"

// ============================================================
// Hook AppDelegate - 在应用启动后初始化插件
// ============================================================

%hook AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    BOOL result = %orig;
    
    // 延迟加载，确保主窗口已就绪
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"[MapReplacer] 插件已加载，正在初始化...");
        
        // 初始化地图管理器并检测路径
        MapManager *manager = [MapManager sharedManager];
        NSString *paksDir = [manager targetPaksDirectory];
        
        if (paksDir) {
            NSLog(@"[MapReplacer] 目标 Paks 目录: %@", paksDir);
        } else {
            NSLog(@"[MapReplacer] 警告: 未找到目标 Paks 目录");
        }
        
        NSString *resDir = [manager resourcePaksDirectory];
        NSLog(@"[MapReplacer] 资源目录: %@", resDir);
        
        // 显示悬浮按钮
        [[UIOverlay sharedOverlay] showFloatingButton];
        
        NSLog(@"[MapReplacer] 初始化完成！");
    });
    
    return result;
}

%end

// ============================================================
// Hook UIViewController - 备用注入方式
// 如果 AppDelegate hook 不生效，通过 ViewController 注入
// ============================================================

static BOOL sHasInitialized = NO;

%hook UIViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    
    if (!sHasInitialized) {
        sHasInitialized = YES;
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            // 如果悬浮按钮还没有显示，则显示
            [[UIOverlay sharedOverlay] showFloatingButton];
        });
    }
}

%end

// ============================================================
// 构造函数 - dylib 加载时执行
// ============================================================

%ctor {
    NSLog(@"[MapReplacer] ============================================");
    NSLog(@"[MapReplacer]  地图替换插件 v1.0.0 已注入");
    NSLog(@"[MapReplacer]  Target: ShadowTrackerExtra");
    NSLog(@"[MapReplacer] ============================================");
    
    // 确保资源目录存在
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *resDir = @"/var/mobile/MapReplacerRes";
    if (![fm fileExistsAtPath:resDir]) {
        [fm createDirectoryAtPath:resDir withIntermediateDirectories:YES attributes:nil error:nil];
        NSLog(@"[MapReplacer] 已创建资源目录: %@", resDir);
    }
}
