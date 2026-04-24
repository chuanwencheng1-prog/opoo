//==============================================================
//  MapReplacer Tweak - 地图 PAK 文件替换插件
//  纯 Objective-C Runtime Hook 版本 (不依赖 Logos 预处理器)
//  注入目标: ShadowTrackerExtra (com.tencent.ig)
//==============================================================

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <substrate.h>
#import "MapManager.h"
#import "UIOverlay.h"

// ============================================================
// 全局变量
// ============================================================
static BOOL sHasInitialized = NO;

// 保存原始方法实现的指针
static BOOL (*orig_AppDelegate_didFinishLaunching)(id self, SEL _cmd, UIApplication *app, NSDictionary *opts);
static void (*orig_UIViewController_viewDidAppear)(id self, SEL _cmd, BOOL animated);

// ============================================================
// 插件初始化逻辑
// ============================================================
static void initializePlugin(void) {
    if (sHasInitialized) return;
    sHasInitialized = YES;
    
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
}

// ============================================================
// Hook: AppDelegate - application:didFinishLaunchingWithOptions:
// ============================================================
static BOOL hook_AppDelegate_didFinishLaunching(id self, SEL _cmd, UIApplication *app, NSDictionary *opts) {
    BOOL result = orig_AppDelegate_didFinishLaunching(self, _cmd, app, opts);
    
    // 延迟3秒加载，确保主窗口已就绪
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        initializePlugin();
    });
    
    return result;
}

// ============================================================
// Hook: UIViewController - viewDidAppear: (备用注入)
// ============================================================
static void hook_UIViewController_viewDidAppear(id self, SEL _cmd, BOOL animated) {
    orig_UIViewController_viewDidAppear(self, _cmd, animated);
    
    if (!sHasInitialized) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            initializePlugin();
        });
    }
}

// ============================================================
// 安装 Hook 的辅助函数
// ============================================================
static void hookMethod(Class cls, SEL sel, void *replacement, void **original) {
    if (!cls || !sel) return;
    
    Method method = class_getInstanceMethod(cls, sel);
    if (method) {
        MSHookMessageEx(cls, sel, (IMP)replacement, (IMP *)original);
        NSLog(@"[MapReplacer] 已 Hook: %@ -> %@", NSStringFromClass(cls), NSStringFromSelector(sel));
    } else {
        NSLog(@"[MapReplacer] 未找到方法: %@ -> %@", NSStringFromClass(cls), NSStringFromSelector(sel));
    }
}

// ============================================================
// 构造函数 - dylib 加载时自动执行
// ============================================================
__attribute__((constructor))
static void mapreplacer_ctor(void) {
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
    
    // 延迟执行 Hook，等待运行时类加载完毕
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        // Hook AppDelegate
        Class appDelegateClass = NSClassFromString(@"AppDelegate");
        if (appDelegateClass) {
            hookMethod(appDelegateClass,
                       @selector(application:didFinishLaunchingWithOptions:),
                       (void *)hook_AppDelegate_didFinishLaunching,
                       (void **)&orig_AppDelegate_didFinishLaunching);
        } else {
            NSLog(@"[MapReplacer] AppDelegate 类未找到，尝试通过 UIViewController 注入");
        }
        
        // Hook UIViewController (备用方案)
        hookMethod([UIViewController class],
                   @selector(viewDidAppear:),
                   (void *)hook_UIViewController_viewDidAppear,
                   (void **)&orig_UIViewController_viewDidAppear);
    });
}
