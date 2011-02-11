#import "PBXTarget.h"

@protocol PBXProject <NSObject>

+ (BOOL) isProjectWrapperExtension:(NSString *)extension;
+ (id<PBXProject>) projectWithFile:(NSString *)projectAbsolutePath;

- (id<PBXTarget>) activeTarget;
- (id<PBXTarget>) targetNamed:(NSString *)targetName;

- (NSString *) name;

@end
