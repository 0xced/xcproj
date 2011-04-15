
@protocol PBXBuildFile <NSObject>

- (NSString *) absolutePath;

- (NSArray *) settingsArrayForKey:(NSString *)key;

@end
