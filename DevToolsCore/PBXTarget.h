#import "PBXBuildPhase.h"
#import "XCConfigurationList.h"

@protocol PBXTarget <NSObject>

- (NSString *) name;

- (id<XCConfigurationList>) buildConfigurationList;

- (NSString *) expandedValueForString:(NSString *)string forBuildParameters:(id)buildParameters;

- (void)setBuildSetting:(id)buildSetting forKeyPath:(NSString *)keyPath;

- (id<PBXBuildPhase>) buildPhaseOfClass:(Class)buildPhaseClass;
- (void) addBuildPhase:(id<PBXBuildPhase>)buildPhase;
- (id<PBXBuildPhase>) defaultFrameworksBuildPhase;
- (id<PBXBuildPhase>) defaultLinkBuildPhase;
- (id<PBXBuildPhase>) defaultSourceCodeBuildPhase;
- (id<PBXBuildPhase>) defaultResourceBuildPhase;
- (id<PBXBuildPhase>) defaultHeaderBuildPhase;

@end
