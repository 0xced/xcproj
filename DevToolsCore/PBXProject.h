#import "PBXTarget.h"

@protocol PBXProject <NSObject>

@required
+ (BOOL) isProjectWrapperExtension:(NSString *)extension;
+ (id<PBXProject>) projectWithFile:(NSString *)projectAbsolutePath;

- (id<PBXTarget>) activeTarget;
- (id<PBXTarget>) targetNamed:(NSString *)targetName;

- (NSString *) name;

@optional
+ (id) PBXProject$projectWithFile:(NSString *)projectAbsolutePath;
- (id) PBXTarget$activeTarget;
- (id) PBXTarget$targetNamed:(NSString *)targetName;
- (id) NSString$name;

@end
