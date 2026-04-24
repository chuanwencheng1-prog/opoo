#import <Foundation/Foundation.h>

// 地图类型枚举
typedef NS_ENUM(NSInteger, MapType) {
    MapTypeBaltic = 0,   // 海岛地图 (Erangel)
    MapTypeDesert,       // 沙漠地图 (Miramar)
    MapTypeSavage,       // 热带雨林 (Sanhok)
    MapTypeDihor,        // 雪地地图 (Vikendi)
    MapTypeLivik,        // Livik地图
    MapTypeKarakin,      // Karakin地图
    MapTypeCount
};

// 地图信息结构
@interface MapInfo : NSObject
@property (nonatomic, copy) NSString *displayName;
@property (nonatomic, copy) NSString *pakFileName;
@property (nonatomic, copy) NSString *iconName;
@property (nonatomic, assign) MapType mapType;
+ (instancetype)infoWithName:(NSString *)name pakFile:(NSString *)pakFile type:(MapType)type;
@end

// 地图管理器
@interface MapManager : NSObject <NSURLSessionDownloadDelegate>

+ (instancetype)sharedManager;

// 获取所有可用地图列表
- (NSArray<MapInfo *> *)availableMaps;

// 获取目标 Paks 目录路径 (自动查找 Application UUID)
- (NSString *)targetPaksDirectory;

// 获取资源包存放目录 (dylib内置资源路径)
- (NSString *)resourcePaksDirectory;

// 下载地图文件（带进度）
- (void)downloadMapWithType:(MapType)mapType
                   progress:(void(^)(float progress))progressBlock
                 completion:(void(^)(BOOL success, NSError *error))completionBlock;

// 替换地图文件
- (BOOL)replaceMapWithType:(MapType)mapType error:(NSError **)error;

// 恢复原始地图
- (BOOL)restoreOriginalMapWithError:(NSError **)error;

// 检查地图资源是否存在
- (BOOL)isMapResourceAvailable:(MapType)mapType;

// 获取当前已替换的地图类型 (-1 表示未替换)
- (NSInteger)currentReplacedMapType;

@end
