#import "PBXTarget.h"

@protocol PBXProject <PBXContainer, NSObject>

+ (BOOL) isProjectWrapperExtension:(NSString *)extension;
+ (id<PBXProject>) projectWithFile:(NSString *)projectAbsolutePath;

- (NSArray *) targets; // PBXTarget
- (id<PBXTarget>) activeTarget;
- (id<PBXTarget>) targetNamed:(NSString *)targetName;

- (NSString *) name;

- (NSArray *) buildConfigurations; // XCBuildConfiguration

- (BOOL) writeToFileSystemProjectFile:(BOOL)projectWrite userFile:(BOOL)userWrite checkNeedsRevert:(BOOL)checkNeedsRevert;

@end
