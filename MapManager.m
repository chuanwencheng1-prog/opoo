#import "MapManager.h"
#import <Foundation/Foundation.h>

// ============================================================
// MapInfo 实现
// ============================================================
@implementation MapInfo

+ (instancetype)infoWithName:(NSString *)name pakFile:(NSString *)pakFile type:(MapType)type {
    MapInfo *info = [[MapInfo alloc] init];
    info.displayName = name;
    info.pakFileName = pakFile;
    info.mapType = type;
    return info;
}

@end

// ============================================================
// MapManager 实现
// ============================================================

static NSString *const kBackupSuffix = @".bak_original";
static NSString *const kCurrentMapKey = @"MapReplacer_CurrentMap";
static NSString *const kResourceSubDir = @"MapReplacerRes";

@interface MapManager ()
@property (nonatomic, strong) NSArray<MapInfo *> *mapList;
@property (nonatomic, copy) NSString *cachedPaksDir;
// 下载相关
@property (nonatomic, strong) NSURLSession *downloadSession;
@property (nonatomic, copy) void(^downloadProgressBlock)(float progress);
@property (nonatomic, copy) void(^downloadCompletionBlock)(BOOL success, NSError *error);
@property (nonatomic, copy) NSString *downloadDestPath;
@property (nonatomic, assign) int64_t downloadExpectedBytes;
@end

@implementation MapManager

+ (instancetype)sharedManager {
    static MapManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[MapManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self setupMapList];
    }
    return self;
}

#pragma mark - 地图配置

- (void)setupMapList {
    self.mapList = @[
        [MapInfo infoWithName:@"海岛地图 (Erangel)"
                      pakFile:@"map_baltic_1.36.11.15210.pak"
                         type:MapTypeBaltic],
        
        [MapInfo infoWithName:@"沙漠地图 (Miramar)"
                      pakFile:@"map_desert_1.36.11.15210.pak"
                         type:MapTypeDesert],
        
        [MapInfo infoWithName:@"热带雨林 (Sanhok)"
                      pakFile:@"map_savage_1.36.11.15210.pak"
                         type:MapTypeSavage],
        
        [MapInfo infoWithName:@"雪地地图 (Vikendi)"
                      pakFile:@"map_dihor_1.36.11.15210.pak"
                         type:MapTypeDihor],
        
        [MapInfo infoWithName:@"Livik 地图"
                      pakFile:@"map_livik_1.36.11.15210.pak"
                         type:MapTypeLivik],
        
        [MapInfo infoWithName:@"Karakin 地图"
                      pakFile:@"map_karakin_1.36.11.15210.pak"
                         type:MapTypeKarakin],
    ];
}

- (NSArray<MapInfo *> *)availableMaps {
    return self.mapList;
}

#pragma mark - 路径管理

- (void)downloadMapWithType:(MapType)mapType
                   progress:(void(^)(float progress))progressBlock
                 completion:(void(^)(BOOL success, NSError *error))completionBlock {
    
    MapInfo *mapInfo = nil;
    for (MapInfo *info in self.mapList) {
        if (info.mapType == mapType) {
            mapInfo = info;
            break;
        }
    }
    
    if (!mapInfo) {
        if (completionBlock) {
            NSError *error = [NSError errorWithDomain:@"MapReplacer"
                                                 code:3001
                                             userInfo:@{NSLocalizedDescriptionKey: @"无效的地图类型"}];
            completionBlock(NO, error);
        }
        return;
    }
    
    // 获取下载 URL（从配置或默认）
    NSString *downloadURL = [self downloadURLForMapType:mapType];
    if (!downloadURL) {
        if (completionBlock) {
            NSError *error = [NSError errorWithDomain:@"MapReplacer"
                                                 code:3002
                                             userInfo:@{NSLocalizedDescriptionKey: @"未配置下载链接"}];
            completionBlock(NO, error);
        }
        return;
    }
    
    // 保存回调和目标路径
    self.downloadProgressBlock = progressBlock;
    self.downloadCompletionBlock = completionBlock;
    self.downloadDestPath = [[self resourcePaksDirectory] stringByAppendingPathComponent:mapInfo.pakFileName];
    self.downloadExpectedBytes = 0;
    
    // 创建带 delegate 的 session（用属性持有防止释放）
    if (!self.downloadSession) {
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        config.timeoutIntervalForRequest = 60;
        config.timeoutIntervalForResource = 600;  // 允许10分钟下载大文件
        self.downloadSession = [NSURLSession sessionWithConfiguration:config
                                                            delegate:self
                                                       delegateQueue:[NSOperationQueue mainQueue]];
    }
    
    NSURL *url = [NSURL URLWithString:downloadURL];
    NSURLSessionDownloadTask *task = [self.downloadSession downloadTaskWithURL:url];
    [task resume];
    
    NSLog(@"[MapReplacer] 开始下载: %@ -> %@", downloadURL, self.downloadDestPath);
}

- (NSString *)downloadURLForMapType:(MapType)mapType {
    // 地图下载链接配置
    NSDictionary *urls = @{
        @(MapTypeBaltic): @"https://modelscope-resouces.oss-cn-zhangjiakou.aliyuncs.com/avatar%2Fac2536b6-c87e-471f-ada2-ae8d3c9aeb1e.pak",
        // 其他地图可以继续添加
    };
    
    return urls[@(mapType)];
}

#pragma mark - NSURLSessionDownloadDelegate

- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
didFinishDownloadingToURL:(NSURL *)location {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *moveError = nil;
    
    // 删除旧文件
    [fm removeItemAtPath:self.downloadDestPath error:nil];
    
    // 移动下载的文件到目标位置
    BOOL success = [fm moveItemAtPath:location.path toPath:self.downloadDestPath error:&moveError];
    
    NSLog(@"[MapReplacer] 下载完成, 移动文件: %@ -> %@", success ? @"成功" : @"失败", self.downloadDestPath);
    
    if (self.downloadCompletionBlock) {
        if (success) {
            self.downloadCompletionBlock(YES, nil);
        } else {
            self.downloadCompletionBlock(NO, moveError);
        }
    }
    
    // 清理回调
    self.downloadProgressBlock = nil;
    self.downloadCompletionBlock = nil;
    self.downloadDestPath = nil;
}

- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
      didWriteData:(int64_t)bytesWritten
 totalBytesWritten:(int64_t)totalBytesWritten
totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    if (self.downloadProgressBlock) {
        float progress = 0;
        if (totalBytesExpectedToWrite > 0) {
            progress = (float)totalBytesWritten / (float)totalBytesExpectedToWrite;
        }
        self.downloadProgressBlock(progress);
    }
}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didCompleteWithError:(NSError *)error {
    if (error) {
        NSLog(@"[MapReplacer] 下载出错: %@", error.localizedDescription);
        if (self.downloadCompletionBlock) {
            self.downloadCompletionBlock(NO, error);
        }
        // 清理回调
        self.downloadProgressBlock = nil;
        self.downloadCompletionBlock = nil;
        self.downloadDestPath = nil;
    }
}

- (NSString *)targetPaksDirectory {
    if (self.cachedPaksDir) {
        return self.cachedPaksDir;
    }
    
    // 方式1: 通过 NSSearchPathForDirectoriesInDomains 获取当前App的Documents路径
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    if (paths.count > 0) {
        NSString *documentsDir = paths.firstObject;
        NSString *paksDir = [documentsDir stringByAppendingPathComponent:@"ShadowTrackerExtra/Saved/Paks"];
        
        NSFileManager *fm = [NSFileManager defaultManager];
        if ([fm fileExistsAtPath:paksDir]) {
            self.cachedPaksDir = paksDir;
            return paksDir;
        }
    }
    
    // 方式2: 遍历 /var/mobile/Containers/Data/Application/ 查找
    NSString *basePath = @"/var/mobile/Containers/Data/Application";
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *contents = [fm contentsOfDirectoryAtPath:basePath error:nil];
    
    for (NSString *uuid in contents) {
        NSString *paksDir = [NSString stringWithFormat:@"%@/%@/Documents/ShadowTrackerExtra/Saved/Paks", basePath, uuid];
        if ([fm fileExistsAtPath:paksDir]) {
            self.cachedPaksDir = paksDir;
            return paksDir;
        }
    }
    
    return nil;
}

- (NSString *)resourcePaksDirectory {
    // 资源包存放在 /var/mobile/MapReplacerRes/ 目录下
    NSString *resDir = [@"/var/mobile" stringByAppendingPathComponent:kResourceSubDir];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:resDir]) {
        [fm createDirectoryAtPath:resDir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    return resDir;
}

#pragma mark - 文件替换操作

- (BOOL)replaceMapWithType:(MapType)mapType error:(NSError **)error {
    NSString *targetDir = [self targetPaksDirectory];
    if (!targetDir) {
        if (error) {
            *error = [NSError errorWithDomain:@"MapReplacer"
                                         code:1001
                                     userInfo:@{NSLocalizedDescriptionKey: @"未找到目标 Paks 目录，请确认游戏已安装并运行过一次"}];
        }
        return NO;
    }
    
    MapInfo *mapInfo = nil;
    for (MapInfo *info in self.mapList) {
        if (info.mapType == mapType) {
            mapInfo = info;
            break;
        }
    }
    
    if (!mapInfo) {
        if (error) {
            *error = [NSError errorWithDomain:@"MapReplacer"
                                         code:1002
                                     userInfo:@{NSLocalizedDescriptionKey: @"无效的地图类型"}];
        }
        return NO;
    }
    
    // 源文件路径 (资源目录中的 pak 文件)
    NSString *srcPath = [[self resourcePaksDirectory] stringByAppendingPathComponent:mapInfo.pakFileName];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    
    // 检查源文件是否存在
    if (![fm fileExistsAtPath:srcPath]) {
        if (error) {
            *error = [NSError errorWithDomain:@"MapReplacer"
                                         code:1003
                                     userInfo:@{NSLocalizedDescriptionKey:
                [NSString stringWithFormat:@"地图资源文件不存在: %@\n请将 pak 文件放入 /var/mobile/MapReplacerRes/ 目录", mapInfo.pakFileName]}];
        }
        return NO;
    }
    
    // 只替换对应的地图 pak 文件，不影响其他地图
    NSString *destPath = [targetDir stringByAppendingPathComponent:mapInfo.pakFileName];
    NSString *backupPath = [destPath stringByAppendingString:kBackupSuffix];
    
    // 如果目标文件存在且没有备份，先备份原始文件
    if ([fm fileExistsAtPath:destPath] && ![fm fileExistsAtPath:backupPath]) {
        NSError *backupError = nil;
        [fm copyItemAtPath:destPath toPath:backupPath error:&backupError];
        if (backupError) {
            NSLog(@"[MapReplacer] 备份文件失败: %@", backupError.localizedDescription);
        } else {
            NSLog(@"[MapReplacer] 已备份原始文件: %@", backupPath);
        }
    }
    
    // 删除目标位置的旧文件
    [fm removeItemAtPath:destPath error:nil];
    
    // 复制新的地图文件到目标目录
    NSError *copyError = nil;
    BOOL success = [fm copyItemAtPath:srcPath toPath:destPath error:&copyError];
    
    if (!success) {
        if (error) {
            *error = [NSError errorWithDomain:@"MapReplacer"
                                         code:1004
                                     userInfo:@{NSLocalizedDescriptionKey:
                [NSString stringWithFormat:@"文件复制失败: %@", copyError.localizedDescription]}];
        }
        return NO;
    }
    
    NSLog(@"[MapReplacer] 成功替换地图: %@ -> %@", mapInfo.displayName, destPath);
    return YES;
}

- (BOOL)restoreOriginalMapWithError:(NSError **)error {
    NSString *targetDir = [self targetPaksDirectory];
    if (!targetDir) {
        if (error) {
            *error = [NSError errorWithDomain:@"MapReplacer"
                                         code:2001
                                     userInfo:@{NSLocalizedDescriptionKey: @"未找到目标 Paks 目录"}];
        }
        return NO;
    }
    
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *allFiles = [fm contentsOfDirectoryAtPath:targetDir error:nil];
    
    // 先删除当前的 pak 文件
    for (NSString *fileName in allFiles) {
        if ([fileName hasSuffix:@".pak"] && ![fileName hasSuffix:kBackupSuffix]) {
            NSString *filePath = [targetDir stringByAppendingPathComponent:fileName];
            [fm removeItemAtPath:filePath error:nil];
        }
    }
    
    // 恢复备份文件
    allFiles = [fm contentsOfDirectoryAtPath:targetDir error:nil];
    for (NSString *fileName in allFiles) {
        if ([fileName hasSuffix:kBackupSuffix]) {
            NSString *backupPath = [targetDir stringByAppendingPathComponent:fileName];
            NSString *originalName = [fileName stringByReplacingOccurrencesOfString:kBackupSuffix withString:@""];
            NSString *originalPath = [targetDir stringByAppendingPathComponent:originalName];
            
            [fm moveItemAtPath:backupPath toPath:originalPath error:nil];
        }
    }
    
    NSLog(@"[MapReplacer] 已恢复原始地图文件");
    return YES;
}

- (BOOL)isMapResourceAvailable:(MapType)mapType {
    MapInfo *mapInfo = nil;
    for (MapInfo *info in self.mapList) {
        if (info.mapType == mapType) {
            mapInfo = info;
            break;
        }
    }
    if (!mapInfo) return NO;
    
    NSString *path = [[self resourcePaksDirectory] stringByAppendingPathComponent:mapInfo.pakFileName];
    return [[NSFileManager defaultManager] fileExistsAtPath:path];
}

- (NSInteger)currentReplacedMapType {
    return -1;  // 不再跟踪状态，始终允许重新下载
}

@end
