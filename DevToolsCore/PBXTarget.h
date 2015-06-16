#import "PBXBuildPhase.h"
#import "XCConfigurationList.h"
#import "IDEMutableBuildParameters.h"

@protocol PBXTarget <NSObject>

- (NSString *) name;

- (id<XCConfigurationList>) buildConfigurationList;

- (NSString *) expandedValueForString:(NSString *)string forBuildParameters:(id<IDEMutableBuildParameters>)buildParameters;

- (void) setBuildSetting:(NSString *)buildSetting forKeyPath:(NSString *)keyPath;

- (id<PBXBuildPhase>) buildPhaseOfClass:(Class)buildPhaseClass;
- (void) addBuildPhase:(id<PBXBuildPhase>)buildPhase;
- (id<PBXBuildPhase>) defaultFrameworksBuildPhase;
- (id<PBXBuildPhase>) defaultLinkBuildPhase;
- (id<PBXBuildPhase>) defaultSourceCodeBuildPhase;
- (id<PBXBuildPhase>) defaultResourceBuildPhase;
- (id<PBXBuildPhase>) defaultHeaderBuildPhase;

@end
