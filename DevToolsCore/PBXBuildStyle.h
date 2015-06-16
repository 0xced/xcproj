
@protocol PBXBuildStyle <NSObject>

- (NSString *) name;

- (void) setBuildSetting:(NSString *)buildSetting forKeyPath:(NSString *)keyPath;

@end
