#import "UIOverlay.h"

// ============================================================
// 颜色常量 - 简约风格
// ============================================================
#define kPrimaryColor    [UIColor colorWithRed:0.0 green:0.48 blue:1.0 alpha:1.0]  // 系统蓝
#define kAccentColor     [UIColor colorWithRed:0.0 green:0.75 blue:0.5 alpha:1.0]  // 薄荷绿
#define kBgColor         [UIColor colorWithRed:0.96 green:0.96 blue:0.98 alpha:1.0]  // 浅灰背景
#define kCardBgColor     [UIColor whiteColor]
#define kTextPrimary     [UIColor colorWithRed:0.1 green:0.1 blue:0.12 alpha:1.0]
#define kTextSecondary   [UIColor colorWithRed:0.4 green:0.4 blue:0.45 alpha:1.0]
#define kSuccessColor    [UIColor colorWithRed:0.2 green:0.7 blue:0.3 alpha:1.0]
#define kDividerColor    [UIColor colorWithRed:0.9 green:0.9 blue:0.92 alpha:1.0]

static CGFloat const kFloatingBtnSize = 44.0;

// ============================================================
// UIOverlay 实现
// ============================================================

@interface UIOverlay () <UIGestureRecognizerDelegate>
@property (nonatomic, strong) UIWindow *overlayWindow;
@property (nonatomic, strong) UIView *floatingButton;
@property (nonatomic, strong) UIView *panelView;
@property (nonatomic, strong) UIView *dimView;
@property (nonatomic, assign) BOOL isPanelVisible;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) NSMutableDictionary<NSNumber*, UIButton*> *mapButtons;
@property (nonatomic, strong) NSMutableDictionary<NSNumber*, UIProgressView*> *progressViews;
@property (nonatomic, strong) NSMutableDictionary<NSNumber*, UILabel*> *statusLabels;
@end

@implementation UIOverlay

+ (instancetype)sharedOverlay {
    static UIOverlay *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[UIOverlay alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _mapButtons = [NSMutableDictionary dictionary];
        _progressViews = [NSMutableDictionary dictionary];
        _statusLabels = [NSMutableDictionary dictionary];
        _isPanelVisible = NO;
    }
    return self;
}

#pragma mark - 悬浮按钮

- (void)showFloatingButton {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.overlayWindow) return;
        
        self.overlayWindow = [[UIWindow alloc] initWithFrame:CGRectMake(20, 200, kFloatingBtnSize, kFloatingBtnSize)];
        self.overlayWindow.windowLevel = UIWindowLevelAlert + 100;
        self.overlayWindow.backgroundColor = [UIColor clearColor];
        self.overlayWindow.hidden = NO;
        
        // 创建简约悬浮按钮
        self.floatingButton = [[UIView alloc] initWithFrame:self.overlayWindow.bounds];
        self.floatingButton.backgroundColor = kPrimaryColor;
        self.floatingButton.layer.cornerRadius = kFloatingBtnSize / 2.0;
        self.floatingButton.layer.shadowColor = [UIColor blackColor].CGColor;
        self.floatingButton.layer.shadowOffset = CGSizeMake(0, 4);
        self.floatingButton.layer.shadowOpacity = 0.3;
        self.floatingButton.layer.shadowRadius = 8;
        
        // 添加图标 (使用文字替代)
        UILabel *icon = [[UILabel alloc] initWithFrame:self.floatingButton.bounds];
        icon.text = @"🗂";
        icon.font = [UIFont systemFontOfSize:20];
        icon.textAlignment = NSTextAlignmentCenter;
        icon.backgroundColor = [UIColor clearColor];
        [self.floatingButton addSubview:icon];
        
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(floatingButtonTapped)];
        [self.floatingButton addGestureRecognizer:tap];
        
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [self.floatingButton addGestureRecognizer:pan];
        
        [self.overlayWindow addSubview:self.floatingButton];
    });
}

- (void)hideFloatingButton {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.overlayWindow setHidden:YES];
        self.overlayWindow = nil;
    });
}

#pragma mark - 拖拽处理

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:gesture.view];
    CGRect frame = self.overlayWindow.frame;
    frame.origin.x += translation.x;
    frame.origin.y += translation.y;
    
    CGRect screenBounds = [UIScreen mainScreen].bounds;
    frame.origin.x = MAX(10, MIN(frame.origin.x, screenBounds.size.width - kFloatingBtnSize - 10));
    frame.origin.y = MAX(50, MIN(frame.origin.y, screenBounds.size.height - kFloatingBtnSize - 50));
    
    self.overlayWindow.frame = frame;
    [gesture setTranslation:CGPointZero inView:gesture.view];
}

#pragma mark - 面板显示/隐藏

- (void)floatingButtonTapped {
    if (self.isPanelVisible) {
        [self hidePanel];
    } else {
        [self showPanel];
    }
}

- (void)showPanel {
    UIWindow *keyWindow = nil;
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        if (window != self.overlayWindow && !window.isHidden) {
            keyWindow = window;
            break;
        }
    }
    if (!keyWindow) return;
    
    self.isPanelVisible = YES;
    
    // 半透明背景
    self.dimView = [[UIView alloc] initWithFrame:keyWindow.bounds];
    self.dimView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.4];
    self.dimView.alpha = 0;
    [self.dimView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(hidePanel)]];
    [keyWindow addSubview:self.dimView];
    
    // 主面板 - 适配横竖屏
    CGRect screenBounds = keyWindow.bounds;
    CGFloat screenWidth = screenBounds.size.width;
    CGFloat screenHeight = screenBounds.size.height;
    
    // 根据屏幕方向调整面板宽度
    BOOL isLandscape = screenWidth > screenHeight;
    CGFloat panelWidth = isLandscape ? MIN(400.0, screenWidth * 0.6) : MIN(340.0, screenWidth * 0.9);
    CGFloat panelHeight = isLandscape ? MIN(480.0, screenHeight * 0.8) : MIN(520.0, screenHeight * 0.7);
    
    CGFloat x = (screenWidth - panelWidth) / 2;
    CGFloat y = (screenHeight - panelHeight) / 2;
    
    self.panelView = [[UIView alloc] initWithFrame:CGRectMake(x, y, panelWidth, panelHeight)];
    self.panelView.backgroundColor = kBgColor;
    self.panelView.layer.cornerRadius = 20;
    self.panelView.layer.shadowColor = [UIColor blackColor].CGColor;
    self.panelView.layer.shadowOffset = CGSizeMake(0, 8);
    self.panelView.layer.shadowOpacity = 0.2;
    self.panelView.layer.shadowRadius = 24;
    self.panelView.transform = CGAffineTransformMakeScale(0.9, 0.9);
    self.panelView.alpha = 0;
    [keyWindow addSubview:self.panelView];
    
    [self buildPanelContent];
    
    [UIView animateWithDuration:0.35 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0.5 options:0 animations:^{
        self.dimView.alpha = 1;
        self.panelView.alpha = 1;
        self.panelView.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)hidePanel {
    self.isPanelVisible = NO;
    [UIView animateWithDuration:0.25 animations:^{
        self.dimView.alpha = 0;
        self.panelView.alpha = 0;
        self.panelView.transform = CGAffineTransformMakeScale(0.95, 0.95);
    } completion:^(BOOL finished) {
        [self.dimView removeFromSuperview];
        [self.panelView removeFromSuperview];
        self.dimView = nil;
        self.panelView = nil;
        [self.mapButtons removeAllObjects];
        [self.progressViews removeAllObjects];
        [self.statusLabels removeAllObjects];
    }];
}

#pragma mark - 面板内容构建

- (void)buildPanelContent {
    CGFloat panelWidth = self.panelView.bounds.size.width;
    CGFloat padding = 20;
    CGFloat yOffset = 0;
    
    // ---- 标题栏 ----
    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, panelWidth, 60)];
    headerView.backgroundColor = kCardBgColor;
    headerView.layer.cornerRadius = 20;
    
    // iOS 11+ 才支持 maskedCorners
    if (@available(iOS 11.0, *)) {
        headerView.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    }
    [self.panelView addSubview:headerView];
    
    // 标题
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(padding, 15, panelWidth - 80, 30)];
    titleLabel.text = @"地图资源管理器";
    titleLabel.textColor = kTextPrimary;
    titleLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightSemibold];
    [headerView addSubview:titleLabel];
    
    // 关闭按钮
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    closeBtn.frame = CGRectMake(panelWidth - 50, 15, 35, 35);
    closeBtn.backgroundColor = [UIColor colorWithRed:0.94 green:0.94 blue:0.96 alpha:1.0];
    closeBtn.layer.cornerRadius = 17.5;
    [closeBtn setTitle:@"✕" forState:UIControlStateNormal];
    [closeBtn setTitleColor:kTextSecondary forState:UIControlStateNormal];
    closeBtn.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    [closeBtn addTarget:self action:@selector(hidePanel) forControlEvents:UIControlEventTouchUpInside];
    [headerView addSubview:closeBtn];
    
    yOffset = 60;
    
    // ---- 状态信息 ----
    UIView *infoView = [[UIView alloc] initWithFrame:CGRectMake(0, yOffset, panelWidth, 40)];
    [self.panelView addSubview:infoView];
    
    NSString *paksDir = [[MapManager sharedManager] targetPaksDirectory];
    UILabel *statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(padding, 5, panelWidth - padding * 2, 30)];
    if (paksDir) {
        statusLabel.text = [NSString stringWithFormat:@"✓ 目标目录已就绪"];
        statusLabel.textColor = kSuccessColor;
    } else {
        statusLabel.text = @"⚠ 未找到目标目录";
        statusLabel.textColor = [UIColor systemOrangeColor];
    }
    statusLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    [infoView addSubview:statusLabel];
    
    yOffset += 45;
    
    // ---- 地图列表 ----
    self.scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, yOffset, panelWidth, self.panelView.bounds.size.height - yOffset - 20)];
    self.scrollView.showsVerticalScrollIndicator = NO;
    [self.panelView addSubview:self.scrollView];
    
    CGFloat scrollY = 10;
    NSArray<MapInfo *> *maps = [[MapManager sharedManager] availableMaps];
    NSInteger currentMap = [[MapManager sharedManager] currentReplacedMapType];
    
    for (NSInteger i = 0; i < maps.count; i++) {
        MapInfo *info = maps[i];
        CGFloat cardHeight = 70;
        CGFloat cardSpacing = 10;
        
        // 卡片容器
        UIView *card = [[UIView alloc] initWithFrame:CGRectMake(padding, scrollY, panelWidth - padding * 2, cardHeight)];
        card.backgroundColor = kCardBgColor;
        card.layer.cornerRadius = 12;
        card.layer.shadowColor = [UIColor blackColor].CGColor;
        card.layer.shadowOffset = CGSizeMake(0, 2);
        card.layer.shadowOpacity = 0.08;
        card.layer.shadowRadius = 6;
        [self.scrollView addSubview:card];
        
        // 图标
        UILabel *iconLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 10, 40, 40)];
        iconLabel.text = [self iconForMapType:info.mapType];
        iconLabel.font = [UIFont systemFontOfSize:28];
        iconLabel.textAlignment = NSTextAlignmentCenter;
        iconLabel.backgroundColor = [self bgColorForMapType:info.mapType];
        iconLabel.layer.cornerRadius = 10;
        iconLabel.clipsToBounds = YES;
        [card addSubview:iconLabel];
        
        // 地图名称
        UILabel *nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(60, 12, panelWidth - padding * 2 - 75, 22)];
        nameLabel.text = info.displayName;
        nameLabel.textColor = kTextPrimary;
        nameLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
        [card addSubview:nameLabel];
        
        // 状态文本
        UILabel *descLabel = [[UILabel alloc] initWithFrame:CGRectMake(60, 34, panelWidth - padding * 2 - 75, 18)];
        BOOL isCurrentMap = (currentMap == info.mapType);
        if (isCurrentMap) {
            descLabel.text = @"✓ 当前使用";
            descLabel.textColor = kSuccessColor;
        } else {
            descLabel.text = @"点击下载";
            descLabel.textColor = kTextSecondary;
        }
        descLabel.font = [UIFont systemFontOfSize:12];
        [card addSubview:descLabel];
        
        // 进度条
        UIProgressView *progressView = [[UIProgressView alloc] initWithFrame:CGRectMake(12, cardHeight - 8, panelWidth - padding * 2 - 24, 4)];
        progressView.progressTintColor = kPrimaryColor;
        progressView.trackTintColor = [UIColor colorWithRed:0.92 green:0.92 blue:0.94 alpha:1.0];
        progressView.hidden = YES;
        [card addSubview:progressView];
        self.progressViews[@(info.mapType)] = progressView;
        
        // 状态标签
        UILabel *stateLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, cardHeight - 22, panelWidth - padding * 2 - 24, 14)];
        stateLabel.textAlignment = NSTextAlignmentCenter;
        stateLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
        stateLabel.textColor = kTextSecondary;
        stateLabel.hidden = YES;
        [card addSubview:stateLabel];
        self.statusLabels[@(info.mapType)] = stateLabel;
        
        // 下载/替换按钮
        UIButton *actionBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        actionBtn.frame = CGRectMake(panelWidth - padding * 2 - 70, 18, 58, 34);
        actionBtn.backgroundColor = isCurrentMap ? kSuccessColor : kPrimaryColor;
        actionBtn.layer.cornerRadius = 8;
        actionBtn.tag = info.mapType;
        [actionBtn setTitle:isCurrentMap ? @"已应用" : @"下载" forState:UIControlStateNormal];
        [actionBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        actionBtn.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
        actionBtn.enabled = !isCurrentMap;
        [actionBtn addTarget:self action:@selector(downloadButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        [card addSubview:actionBtn];
        self.mapButtons[@(info.mapType)] = actionBtn;
        
        // 分割线（非最后一项）
        if (i < maps.count - 1) {
            UIView *divider = [[UIView alloc] initWithFrame:CGRectMake(padding, scrollY + cardHeight + cardSpacing/2 - 0.5, panelWidth - padding * 2, 1)];
            divider.backgroundColor = kDividerColor;
            [self.scrollView addSubview:divider];
        }
        
        scrollY += cardHeight + cardSpacing;
    }
    
    self.scrollView.contentSize = CGSizeMake(panelWidth, scrollY + 10);
}

- (NSString *)iconForMapType:(MapType)type {
    NSArray *icons = @[@"🏝", @"🏜", @"🌴", @"❄", @"🗺", @"🏔"];
    return type < icons.count ? icons[type] : @"📦";
}

- (UIColor *)bgColorForMapType:(MapType)type {
    NSArray *colors = @[
        [UIColor colorWithRed:0.9 green:0.95 blue:1.0 alpha:1.0],  // 海岛 - 浅蓝
        [UIColor colorWithRed:1.0 green:0.95 blue:0.9 alpha:1.0],  // 沙漠 - 浅黄
        [UIColor colorWithRed:0.9 green:1.0 blue:0.9 alpha:1.0],   // 雨林 - 浅绿
        [UIColor colorWithRed:0.92 green:0.94 blue:1.0 alpha:1.0], // 雪地 - 冰蓝
        [UIColor colorWithRed:0.95 green:0.92 blue:1.0 alpha:1.0], // Livik - 浅紫
        [UIColor colorWithRed:1.0 green:0.92 blue:0.9 alpha:1.0]   // Karakin - 浅橙
    ];
    return type < colors.count ? colors[type] : [UIColor colorWithRed:0.95 green:0.95 blue:0.95 alpha:1.0];
}

#pragma mark - 按钮事件

- (void)downloadButtonTapped:(UIButton *)sender {
    MapType type = (MapType)sender.tag;
    MapInfo *info = nil;
    for (MapInfo *m in [[MapManager sharedManager] availableMaps]) {
        if (m.mapType == type) {
            info = m;
            break;
        }
    }
    if (!info) return;
    
    // 禁用按钮
    sender.enabled = NO;
    sender.backgroundColor = [UIColor colorWithRed:0.85 green:0.85 blue:0.87 alpha:1.0];
    [sender setTitle:@"准备中" forState:UIControlStateNormal];
    
    // 显示进度条
    UIProgressView *progressView = self.progressViews[@(type)];
    UILabel *stateLabel = self.statusLabels[@(type)];
    progressView.hidden = NO;
    stateLabel.hidden = NO;
    progressView.progress = 0;
    stateLabel.text = @"正在下载...";
    stateLabel.textColor = kPrimaryColor;
    
    // 开始下载
    [[MapManager sharedManager] downloadMapWithType:type
                                           progress:^(float progress) {
        dispatch_async(dispatch_get_main_queue(), ^{
            progressView.progress = progress;
            stateLabel.text = [NSString stringWithFormat:@"下载中 %.0f%%", progress * 100];
        });
    } completion:^(BOOL success, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) {
                // 下载完成并已自动替换                
                stateLabel.text = @"✓ 已完成";
                stateLabel.textColor = kSuccessColor;
                sender.backgroundColor = kSuccessColor;
                [sender setTitle:@"已应用" forState:UIControlStateNormal];
                
                // 刷新其他按钮                
                [self refreshAllButtons];
            } else {
                stateLabel.text = [NSString stringWithFormat:@"✗ 下载失败: %@", error.localizedDescription];
                stateLabel.textColor = [UIColor systemRedColor];
                sender.enabled = YES;
                sender.backgroundColor = kPrimaryColor;
                [sender setTitle:@"重试" forState:UIControlStateNormal];
            }
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                progressView.hidden = YES;
                stateLabel.hidden = YES;
            });
        });
    }];
}

- (void)refreshAllButtons {
    NSInteger currentMap = [[MapManager sharedManager] currentReplacedMapType];
    for (NSNumber *key in self.mapButtons) {
        UIButton *btn = self.mapButtons[key];
        MapType type = (MapType)[key integerValue];
        BOOL isCurrent = (currentMap == type);
        
        btn.enabled = !isCurrent;
        btn.backgroundColor = isCurrent ? kSuccessColor : kPrimaryColor;
        [btn setTitle:isCurrent ? @"已应用" : @"下载" forState:UIControlStateNormal];
    }
}

@end
