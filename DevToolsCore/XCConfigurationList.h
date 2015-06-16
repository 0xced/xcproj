#import "PBXFileReference.h"
#import "XCBuildConfiguration.h"

@protocol XCConfigurationList <NSObject>

- (NSArray<XCBuildConfiguration> *) buildConfigurations;
- (NSArray<NSString> *) buildConfigurationNames;

- (NSString *) defaultConfigurationName;

@end
