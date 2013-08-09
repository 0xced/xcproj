#import "PBXFileReference.h"
#import "XCBuildConfiguration.h"

@protocol XCConfigurationList <NSObject>

- (NSArray<XCBuildConfiguration> *) buildConfigurations;

@end
