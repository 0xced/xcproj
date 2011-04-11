#import "PBXTarget.h"

@protocol PBXProject <PBXContainer, NSObject>

+ (BOOL) isProjectWrapperExtension:(NSString *)extension;
+ (id<PBXProject>) projectWithFile:(NSString *)projectAbsolutePath;

- (NSArray *) targets;
- (id<PBXTarget>) activeTarget;
- (id<PBXTarget>) targetNamed:(NSString *)targetName;

- (NSString *) name;

- (BOOL) writeToFileSystemProjectFile:(BOOL)projectWrite userFile:(BOOL)userWrite checkNeedsRevert:(BOOL)checkNeedsRevert;

@end
