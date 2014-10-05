@protocol NSString;

@protocol PBXBuildFile <NSObject>

- (NSString *) absolutePath;

- (NSArray<NSString> *) settingsArrayForKey:(NSString *)key;

@end
