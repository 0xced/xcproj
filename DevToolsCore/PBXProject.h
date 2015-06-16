#import "PBXTarget.h"
#import "XCConfigurationList.h"

@protocol PBXProject <PBXContainer, NSObject>

+ (BOOL) isProjectWrapperExtension:(NSString *)extension;
+ (id<PBXProject>) projectWithFile:(NSString *)projectAbsolutePath;

- (NSArray<PBXTarget> *) targets;
- (id<PBXTarget>) targetNamed:(NSString *)targetName;

- (NSString *) name;

- (id<XCConfigurationList>) buildConfigurationList;

- (NSString *) expandedValueForString:(NSString *)string forBuildParameters:(id<IDEMutableBuildParameters>)buildParameters withFallbackConfigurationName:(NSString *)fallbackConfigurationName;

- (BOOL) writeToFileSystemProjectFile:(BOOL)projectWrite userFile:(BOOL)userWrite checkNeedsRevert:(BOOL)checkNeedsRevert;

@end
