@protocol NSString;

@protocol PBXBuildFile <NSObject>

- (NSString *) absolutePath;

- (NSArray<NSString> *) attributes;

@end
