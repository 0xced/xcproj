//
//  Xcproj.m
//  xcproj
//
//  Created by Cédric Luthi on 07.02.11.
//  Copyright Cédric Luthi 2011. All rights reserved.
//

#import "Xcproj.h"

#import <dlfcn.h>
#import <objc/runtime.h>
#import "XCDUndocumentedChecker.h"
#import "XMLPlistDecoder.h"

@implementation Xcproj
{
	// Options
	id<PBXProject> _project;
	NSString *_targetName;
	NSString *_configurationName;
	
	id<PBXTarget> _target;
}

static Class PBXGroup = Nil;
static Class PBXProject = Nil;
static Class PBXReference = Nil;
static Class XCBuildConfiguration = Nil;
static Class IDEBuildParameters = Nil;

+ (void) setPBXGroup:(Class)class                  { PBXGroup = class; }
+ (void) setPBXProject:(Class)class                { PBXProject = class; }
+ (void) setPBXReference:(Class)class              { PBXReference = class; }
+ (void) setXCBuildConfiguration:(Class)class      { XCBuildConfiguration = class; }
+ (void) setIDEBuildParameters:(Class)class        { IDEBuildParameters = class; }
+ (void) setValue:(id)value forUndefinedKey:(NSString *)key { /* ignore */ }

static NSString *XcodeBundleIdentifier = @"com.apple.dt.Xcode";

static NSBundle * XcodeBundleAtPath(NSString *path)
{
	NSBundle *xcodeBundle = [NSBundle bundleWithPath:path];
	return [xcodeBundle.bundleIdentifier isEqualToString:XcodeBundleIdentifier] ? xcodeBundle : nil;
}

static NSBundle * XcodeBundle(void)
{
	NSString *xcodeAppPath = NSProcessInfo.processInfo.environment[@"XCPROJ_XCODE_APP_PATH"];
	NSBundle *xcodeBundle = XcodeBundleAtPath(xcodeAppPath);
	if (!xcodeBundle)
	{
		NSTask *task = [NSTask new];
		task.launchPath = @"/usr/bin/xcode-select";
		task.arguments = @[@"--print-path"];
		task.standardOutput = [NSPipe new];

		[task launch];
		[task waitUntilExit];

		if (task.terminationStatus == 0)
		{
			NSData *outputData = [[task.standardOutput fileHandleForReading] readDataToEndOfFile];
			NSString *outputString = [[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding];
			NSString *xcodePath = [[outputString stringByDeletingLastPathComponent] stringByDeletingLastPathComponent];
			xcodeBundle = XcodeBundleAtPath(xcodePath);
		}
	}

	if (!xcodeBundle)
	{
		NSURL *xcodeURL = [[NSWorkspace sharedWorkspace] URLForApplicationWithBundleIdentifier:XcodeBundleIdentifier];
		xcodeBundle = XcodeBundleAtPath(xcodeURL.path);
	}
	
	if (!xcodeBundle)
	{
		ddfprintf(stderr, @"Xcode.app not found.\n");
		exit(EX_CONFIG);
	}
	
	if (xcodeAppPath && ![[xcodeAppPath stringByResolvingSymlinksInPath] isEqualToString:xcodeBundle.bundlePath])
	{
		ddfprintf(stderr, @"WARNING: '%@' does not point to an Xcode app, using '%@'\n", xcodeAppPath, xcodeBundle.bundlePath);
	}
	
	return xcodeBundle;
}

static void LoadXcodeFrameworks(NSBundle *xcodeBundle)
{
	NSURL *xcodeContentsURL = [[xcodeBundle privateFrameworksURL] URLByDeletingLastPathComponent];
	
	NSString *xcodeFrameworks = NSProcessInfo.processInfo.environment[@"XCPROJ_XCODE_FRAMEWORKS"];
	NSArray *frameworks;
	if (xcodeFrameworks)
	{
		frameworks = [xcodeFrameworks componentsSeparatedByString:@":"];
	}
	else
	{
		// Xcode 5 requires DVTFoundation, CSServiceClient, IDEFoundation and Xcode3Core
		// Xcode 6 requires DVTFoundation, DVTSourceControl, IDEFoundation and Xcode3Core
		// Xcode 7 requires DVTFoundation, DVTSourceControl, IBFoundation, IBAutolayoutFoundation, IDEFoundation and Xcode3Core
		// Xcode 7.3 requires DVTFoundation, DVTSourceControl, DVTServices, DVTPortal, IBFoundation, IBAutolayoutFoundation, IDEFoundation and Xcode3Core
		frameworks = @[ @"DVTFoundation.framework", @"DVTSourceControl.framework", @"DVTServices.framework", @"DVTPortal.framework", @"CSServiceClient.framework", @"IBFoundation.framework", @"IBAutolayoutFoundation.framework", @"IDEFoundation.framework", @"Xcode3Core.ideplugin" ];
	}
	
	for (NSString *framework in frameworks)
	{
		BOOL loaded = NO;
		NSArray *xcodeSubdirectories = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:xcodeContentsURL includingPropertiesForKeys:nil options:0 error:NULL];
		for (NSURL *frameworksDirectoryURL in xcodeSubdirectories)
		{
			NSURL *frameworkURL = [frameworksDirectoryURL URLByAppendingPathComponent:framework];
			NSBundle *frameworkBundle = [NSBundle bundleWithURL:frameworkURL];
			if (frameworkBundle)
			{
				NSError *loadError = nil;
				loaded = [frameworkBundle loadAndReturnError:&loadError];
				if (!loaded)
				{
					ddfprintf(stderr, @"The %@ %@ failed to load: %@\n", [framework stringByDeletingPathExtension], [framework pathExtension], loadError);
					exit(EX_SOFTWARE);
				}
			}
			
			if (loaded)
				break;
		}
	}
}

static void InitializeXcodeFrameworks(void)
{
	void(*IDEInitialize)(int initializationOptions, NSError **error) = dlsym(RTLD_DEFAULT, "IDEInitialize");
	if (!IDEInitialize)
	{
		ddfprintf(stderr, @"IDEInitialize function not found.\n");
		exit(EX_SOFTWARE);
	}
	
	// Temporary redirect stderr to /dev/null in order not to print plugin loading errors
	// Adapted from http://stackoverflow.com/questions/4832603/how-could-i-temporary-redirect-stdout-to-a-file-in-a-c-program/4832902#4832902
	fflush(stderr);
	int saved_stderr = dup(STDERR_FILENO);
	int dev_null = open("/dev/null", O_WRONLY);
	dup2(dev_null, STDERR_FILENO);
	close(dev_null);
	// Xcode3Core.ideplugin`-[Xcode3CommandLineBuildTool run] calls IDEInitialize(1, &error)
	IDEInitialize(1, NULL);
	fflush(stderr);
	dup2(saved_stderr, STDERR_FILENO);
	close(saved_stderr);
}

static void WorkaroundRadar18512876(void)
{
	NSString *xmlPlist = @"<?xml version=\"1.0\" encoding=\"UTF-8\"?><plist version=\"1.0\"><string>&#x1F680;</string></plist>";
	NSData *xmlPlistData = [xmlPlist dataUsingEncoding:NSUTF8StringEncoding];
	BOOL shouldWorkaroundRadar18512876 = ![@"\U0001F680" isEqual:[NSPropertyListSerialization propertyListWithData:xmlPlistData options:0 format:NULL error:NULL]];
	if (shouldWorkaroundRadar18512876)
	{
		Method plistWithDescriptionData = class_getClassMethod([NSDictionary class], @selector(plistWithDescriptionData:));
		id (*plistWithDescriptionDataIMP)(id, SEL, NSData *) = (__typeof__(plistWithDescriptionDataIMP))method_getImplementation(plistWithDescriptionData);
		method_setImplementation(plistWithDescriptionData, imp_implementationWithBlock(^(id _self, NSData *data) {
			if (data.length >= 5 && [[data subdataWithRange:NSMakeRange(0, 5)] isEqualToData:[@"<?xml" dataUsingEncoding:NSASCIIStringEncoding]])
				return [XMLPlistDecoder plistWithData:data];
			else
				return plistWithDescriptionDataIMP(_self, @selector(plistWithDescriptionData:), data);
		}));
	}
}

+ (void) initializeXcproj
{
	static BOOL initialized = NO;
	if (initialized)
		return;
	
	LoadXcodeFrameworks(XcodeBundle());
	InitializeXcodeFrameworks();
	WorkaroundRadar18512876();
	
	BOOL isSafe = YES;
	NSArray *protocols = @[@protocol(PBXBuildFile),
	                       @protocol(PBXBuildPhase),
	                       @protocol(PBXContainer),
	                       @protocol(PBXFileReference),
	                       @protocol(PBXGroup),
	                       @protocol(PBXProject),
	                       @protocol(PBXReference),
	                       @protocol(PBXTarget),
	                       @protocol(XCBuildConfiguration),
	                       @protocol(XCConfigurationList),
	                       @protocol(IDEBuildParameters)];
	
	for (Protocol *protocol in protocols)
	{
		NSError *classError = nil;
		Class class = XCDClassFromProtocol(protocol, &classError);
		if (class)
			[self setValue:class forKey:[NSString stringWithCString:protocol_getName(protocol) encoding:NSUTF8StringEncoding]];
		else
		{
			isSafe = NO;
			ddfprintf(stderr, @"%@\n%@\n", [classError localizedDescription], [classError userInfo]);
		}
	}
	
	if (!isSafe)
		exit(EX_SOFTWARE);
	
	initialized = YES;
}

// MARK: - Options

- (void) application:(DDCliApplication *)app willParseOptions:(DDGetoptLongParser *)optionsParser
{
	DDGetoptOption optionTable[] = 
	{
		// Long           Short  Argument options
		{"project",       'p',   DDGetoptRequiredArgument},
		{"target",        't',   DDGetoptRequiredArgument},
		{"configuration", 'c',   DDGetoptRequiredArgument},
		{"help",          'h',   DDGetoptNoArgument},
		{"version",       'V',   DDGetoptNoArgument},
		{nil,           0,    0},
	};
	[optionsParser addOptionsFromTable:optionTable];
}

- (void) setProject:(NSString *)projectName
{
	[self.class initializeXcproj];
	
	if (![PBXProject isProjectWrapperExtension:[projectName pathExtension]])
		@throw [DDCliParseException parseExceptionWithReason:[NSString stringWithFormat:@"The project name %@ does not have a valid extension.", projectName] exitCode:EX_USAGE];
	
	NSString *projectPath = projectName;
	if (![projectName isAbsolutePath])
		projectPath = [[[NSFileManager defaultManager] currentDirectoryPath] stringByAppendingPathComponent:projectName];
	
	if (![[NSFileManager defaultManager] fileExistsAtPath:projectPath])
		@throw [DDCliParseException parseExceptionWithReason:[NSString stringWithFormat:@"The project %@ does not exist in this directory.", projectName] exitCode:EX_NOINPUT];
	
	_project = [PBXProject projectWithFile:projectPath];
	
	if (!_project)
		@throw [DDCliParseException parseExceptionWithReason:[NSString stringWithFormat:@"The '%@' project is corrupted.", projectName] exitCode:EX_DATAERR];
}

- (void) setTarget:(NSString *)targetName
{
	if (_targetName == targetName)
		return;
	
	_targetName = targetName;
}

- (void) setConfiguration:(NSString *)confiturationName
{
	if (_configurationName == confiturationName)
		return;
	
	_configurationName = confiturationName;
}

- (void) setHelp:(NSNumber *)help
{
	if ([help boolValue])
		[self printUsage:EX_OK];
}

- (void) setVersion:(NSNumber *)version
{
	if ([version boolValue])
	{
		ddprintf(@"%@\n", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]);
		exit(EX_OK);
	}
}

// MARK: - App run

- (int) application:(DDCliApplication *)app runWithArguments:(NSArray *)arguments
{
	if ([arguments count] < 1)
		[self printUsage:EX_USAGE];
	
	[self.class initializeXcproj];
	
	NSString *currentDirectoryPath = [[NSFileManager defaultManager] currentDirectoryPath];
	
	if (!_project)
	{
		for (NSString *fileName in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:currentDirectoryPath error:NULL])
		{
			if ([PBXProject isProjectWrapperExtension:[fileName pathExtension]])
			{
				if (!_project)
					[self setProject:fileName];
				else
				{
					ddfprintf(stderr, @"%@: The directory %@ contains more than one Xcode project. You will need to specify the project with the --project option.\n", app, currentDirectoryPath);
					return EX_USAGE;
				}
			}
		}
	}
	
	if (!_project)
	{
		ddfprintf(stderr, @"%@: The directory %@ does not contain an Xcode project.\n", app, currentDirectoryPath);
		return EX_USAGE;
	}
	
	if (_targetName)
	{
		_target = [_project targetNamed:_targetName];
		if (!_target)
			@throw [DDCliParseException parseExceptionWithReason:[NSString stringWithFormat:@"The target %@ does not exist in this project.", _targetName] exitCode:EX_DATAERR];
	}
	else
	{
		NSArray *targets = [_project targets];
		if ([targets count] == 0)
			@throw [DDCliParseException parseExceptionWithReason:[NSString stringWithFormat:@"The project %@ does not contain any target.", [_project name]] exitCode:EX_DATAERR];
	}
	
	if (_configurationName)
	{
		if (![[[_project buildConfigurationList] buildConfigurationNames] containsObject:_configurationName])
			@throw [DDCliParseException parseExceptionWithReason:[NSString stringWithFormat:@"The project %@ does not contain a configuration named \"%@\".", [_project name], _configurationName] exitCode:EX_DATAERR];
	}
	
	NSString *action = [arguments objectAtIndex:0];
	if (![[self allowedActions] containsObject:action])
		[self printUsage:EX_USAGE];
	
	if ([@[ @"list-headers", @"add-resources-bundle" ] containsObject:action] && !_target)
		@throw [DDCliParseException parseExceptionWithReason:[NSString stringWithFormat:@"The \"%@\" action requires a target to be specified.", action] exitCode:EX_USAGE];
	
	NSArray *actionArguments = nil;
	if ([arguments count] >= 2)
		actionArguments = [arguments subarrayWithRange:NSMakeRange(1, [arguments count] - 1)];
	else
		actionArguments = [NSArray array];
	
	NSArray *actionParts = [[action componentsSeparatedByString:@"-"] valueForKeyPath:@"capitalizedString"];
	NSMutableString *selectorString = [NSMutableString stringWithString:[actionParts componentsJoinedByString:@""]];
	[selectorString replaceCharactersInRange:NSMakeRange(0, 1) withString:[[selectorString substringToIndex:1] lowercaseString]];
	[selectorString appendString:@":"];
	SEL actionSelector = NSSelectorFromString(selectorString);
	return [[self performSelector:actionSelector withObject:actionArguments] intValue];
}

// MARK: - Actions

- (NSArray *) allowedActions
{
	return [NSArray arrayWithObjects:@"list-targets", @"list-headers", @"read-build-setting", @"write-build-setting", @"add-xcconfig", @"add-resources-bundle", @"touch", nil];
}

- (void) printUsage:(int)exitCode
{
	ddprintf(@"Usage: %@ [options] <action> [arguments]\n", [[NSBundle mainBundle] objectForInfoDictionaryKey:(id)kCFBundleExecutableKey]);
	ddprintf(@"\nOptions:\n"
	         @" -h, --help              Show this help text and exit\n"
	         @" -V, --version           Show program version and exit\n"
	         @" -p, --project           Path to an Xcode project (*.xcodeproj file). If not specified, the project in the current working directory is used\n"
	         @" -t, --target            Name of the target. If not specified, the action is performed at the project level. Required for the `list-headers` and `add-resources-bundle` actions\n"
	         @" -c, --configuration     Name of the configuration. If not specified, the default configuration (i.e. for command-line builds) is used\n"
	         @"\nActions:\n"
	         @" * list-targets\n"
	         @"     List all the targets in the project\n\n"
	         @" * list-headers [All|Public|Project|Private] (default=Public)\n"
	         @"     List headers from the `Copy Headers` build phase\n\n"
	         @" * read-build-setting <build_setting>\n"
	         @"     Evaluate a build setting and print its value. If the build setting does not exist, nothing is printed\n\n"
	         @" * write-build-setting <build_setting> <value>\n"
	         @"     Assign a value to a build setting. If the build setting does not exist, it is added to the target\n\n"
	         @" * add-xcconfig <xcconfig_path>\n"
	         @"     Add an xcconfig file to the project and base all configurations on it\n\n"
	         @" * add-resources-bundle <bundle_path>\n"
	         @"     Add a bundle to the project and in the `Copy Bundle Resources` build phase\n\n"
	         @" * touch\n"
	         @"     Rewrite the project file\n");
	exit(exitCode);
}

- (NSNumber *) listTargets:(NSArray *)arguments
{
	if ([arguments count] > 0)
		[self printUsage:EX_USAGE];
	
	for (id<PBXTarget> target in [_project targets])
		ddprintf(@"%@\n", [target name]);
	
	return [[_project targets] count] > 0 ? @(EX_OK) : @(EX_SOFTWARE);
}

- (NSNumber *) listHeaders:(NSArray *)arguments
{
	if ([arguments count] > 1)
		[self printUsage:EX_USAGE];
	
	NSString *headerRole = @"Public";
	if ([arguments count] == 1)
		headerRole = [[arguments objectAtIndex:0] capitalizedString];
	
	NSArray *allowedValues = [NSArray arrayWithObjects:@"All", @"Public", @"Project", @"Private", nil];
	if (![allowedValues containsObject:headerRole])
		@throw [DDCliParseException parseExceptionWithReason:[NSString stringWithFormat:@"list-headers argument must be one of {%@}.", [allowedValues componentsJoinedByString:@", "]] exitCode:EX_USAGE];
	
	id<PBXBuildPhase> headerBuildPhase = [_target defaultHeaderBuildPhase];
	for (id<PBXBuildFile> buildFile in [headerBuildPhase buildFiles])
	{
		NSArray *attributes = [buildFile attributes];
		if ([attributes containsObject:headerRole] || [headerRole isEqualToString:@"All"])
			ddprintf(@"%@\n", [buildFile absolutePath]);
	}
	
	return @(EX_OK);
}

- (NSNumber *) readBuildSetting:(NSArray *)arguments
{
	if ([arguments count] != 1)
		[self printUsage:EX_USAGE];
	
	NSString *buildSetting = [arguments objectAtIndex:0];
	NSString *settingString = [NSString stringWithFormat:@"$(%@)", buildSetting];
	NSString *configurationName = _configurationName ?: [[_project buildConfigurationList] defaultConfigurationName];
	id<IDEBuildParameters> buildParameters = [[IDEBuildParameters alloc] initForBuildWithConfigurationName:configurationName];
	NSString *expandedString;
	if (_target)
		expandedString = [_target expandedValueForString:settingString forBuildParameters:buildParameters];
	else
		expandedString = [_project expandedValueForString:settingString forBuildParameters:buildParameters];
	
	if ([expandedString length] > 0)
		ddprintf(@"%@\n", expandedString);
	
	return @(EX_OK);
}

- (NSNumber *) writeBuildSetting:(NSArray *)arguments
{
	if ([arguments count] != 2)
		[self printUsage:EX_USAGE];
	
	NSString *buildSetting = arguments[0];
	NSString *value = arguments[1];
	if (_target)
	{
		[_target setBuildSetting:value forKeyPath:buildSetting];
	}
	else
	{
		for (id<XCBuildConfiguration> buildConfiguration in [[_project buildConfigurationList] buildConfigurations])
		{
			if (_configurationName)
			{
				if ([[buildConfiguration name] isEqualToString:_configurationName])
				{
					[buildConfiguration setBuildSetting:value forKeyPath:buildSetting];
					break;
				}
			}
			else
			{
				[buildConfiguration setBuildSetting:value forKeyPath:buildSetting];
			}
		}
	}
	
	return [self writeProject];
}

- (NSNumber *) writeProject
{
	BOOL written = [_project writeToFileSystemProjectFile:YES userFile:NO checkNeedsRevert:NO];
	if (!written)
	{
		ddfprintf(stderr, @"Could not write '%@' to file system.", _project);
		return @(EX_IOERR);
	}
	return @(EX_OK);
}

- (NSNumber *) addXcconfig:(NSArray *)arguments
{
	if ([arguments count] != 1)
		[self printUsage:EX_USAGE];
	
	NSString *xcconfigPath = [arguments objectAtIndex:0];

	if (![[NSFileManager defaultManager] fileExistsAtPath:xcconfigPath])
		@throw [DDCliParseException parseExceptionWithReason:[NSString stringWithFormat:@"The configuration file %@ does not exist in this directory.", xcconfigPath] exitCode:EX_NOINPUT];
	
	id<PBXFileReference> xcconfig = [self addFileAtPath:xcconfigPath];
	
	NSError *error = nil;
	if (![XCBuildConfiguration fileReference:xcconfig isValidBaseConfigurationFile:&error])
		@throw [DDCliParseException parseExceptionWithReason:[NSString stringWithFormat:@"The configuration file %@ is not valid. %@", xcconfigPath, [error localizedDescription]] exitCode:EX_USAGE];
	
	id<XCConfigurationList> buildConfigurationList = [_project buildConfigurationList];
	NSArray *buildConfigurations = [buildConfigurationList buildConfigurations];
	for (id<XCBuildConfiguration> configuration in buildConfigurations)
		[configuration setBaseConfigurationReference:xcconfig];
	
	[self addGroupNamed:@"Configurations" beforeGroupNamed:@"Frameworks"];
	[self addFileReference:xcconfig inGroupNamed:@"Configurations"];
	
	return [self writeProject];
}

- (NSNumber *) addResourcesBundle:(NSArray *)arguments
{
	[self addGroupNamed:@"Bundles" inGroupNamed:@"Frameworks"];
	
	for (NSString *resourcesBundlePath in arguments)
	{
		id<PBXFileReference> bundleReference = [self addFileAtPath:resourcesBundlePath];
		[self addFileReference:bundleReference inGroupNamed:@"Bundles"];
		[self addFileReference:bundleReference toBuildPhase:@"Resources"];
	}
	
	return [self writeProject];
}

- (NSNumber *) touch:(NSArray *)arguments
{
	return [self writeProject];
}

/*
- (void) printBuildPhases
{
	for (NSString *buildPhase in [NSArray arrayWithObjects:@"Frameworks", @"Link", @"SourceCode", @"Resource", @"Header", nil])
	{
		ddprintf(@"%@\n", buildPhase);
		SEL buildPhaseSelector = NSSelectorFromString([NSString stringWithFormat:@"default%@BuildPhase", buildPhase]);
		id<PBXBuildPhase> buildPhase = [target performSelector:buildPhaseSelector];
		for (id<PBXBuildFile> buildFile in [buildPhase buildFiles])
		{
			ddprintf(@"\t%@\n", [buildFile absolutePath]);
		}
		ddprintf(@"\n");
	}
}
*/

// MARK: - Xcode project manipulation

- (id<PBXGroup>) groupNamed:(NSString *)groupName inGroup:(id<PBXGroup>)rootGroup parentGroup:(id<PBXGroup> *) parentGroup
{
	for (id<PBXGroup> group in [rootGroup children])
	{
		if ([group isKindOfClass:[PBXGroup class]])
		{
			if (parentGroup)
				*parentGroup = rootGroup;
			
			if ([[group name] isEqualToString:groupName])
			{
				return group;
			}
			else
			{
				id<PBXGroup> subGroup = [self groupNamed:groupName inGroup:group parentGroup:parentGroup];
				if (subGroup)
					return subGroup;
			}
		}
	}
	
	if (parentGroup)
		*parentGroup = nil;
	return nil;
}

- (id<PBXGroup>) groupNamed:(NSString *)groupName parentGroup:(id<PBXGroup> *) parentGroup
{
	return [self groupNamed:groupName inGroup:[_project rootGroup] parentGroup:parentGroup];
}

- (void) addGroupNamed:(NSString *)groupName beforeGroupNamed:(NSString *)otherGroupName
{
	id<PBXGroup> parentGroup = nil;
	id<PBXGroup> otherGroup = [self groupNamed:otherGroupName parentGroup:&parentGroup];
	NSUInteger otherGroupIndex = [[parentGroup children] indexOfObjectIdenticalTo:otherGroup];
	
	if (otherGroupIndex == NSNotFound)
		otherGroupIndex = 0;
	
	id<PBXGroup> previousGroup = [[parentGroup children] objectAtIndex:MAX((NSInteger)(otherGroupIndex) - 1, 0)];
	if ([[previousGroup name] isEqualToString:groupName])
		return;
	
	id<PBXGroup> group = [PBXGroup groupWithName:groupName];
	[parentGroup insertItem:group atIndex:otherGroupIndex];
}

- (void) addGroupNamed:(NSString *)groupName inGroupNamed:(NSString *)otherGroupName
{
	id<PBXGroup> otherGroup = [self groupNamed:otherGroupName parentGroup:NULL];
	
	for (id<PBXGroup> group in [otherGroup children])
	{
		if ([group isKindOfClass:[PBXGroup class]] && [[group name] isEqualToString:groupName])
			return;
	}
	
	id<PBXGroup> group = [PBXGroup groupWithName:groupName];
	[otherGroup addItem:group];
}

- (id<PBXFileReference>) addFileAtPath:(NSString *)filePath
{
	if (![filePath hasPrefix:@"/"])
		filePath = [[[NSFileManager defaultManager] currentDirectoryPath] stringByAppendingPathComponent:filePath];
	
	id<PBXFileReference> fileReference = [_project fileReferenceForPath:filePath];
	if (!fileReference)
	{
		NSArray *references = [[_project rootGroup] addFiles:[NSArray arrayWithObject:filePath] copy:NO createGroupsRecursively:NO];
		fileReference = [references lastObject];
	}
	return fileReference;
}

- (BOOL) addFileReference:(id<PBXFileReference>)fileReference inGroupNamed:(NSString *)groupName
{
	id<PBXGroup> group = [self groupNamed:groupName parentGroup:NULL];
	if (!group)
		group = [_project rootGroup];
	
	if ([group containsItem:fileReference])
		return YES;
	
	[group addItem:fileReference];
	
	return YES;
}

- (BOOL) addFileReference:(id<PBXFileReference>)fileReference toBuildPhase:(NSString *)buildPhaseName
{
	Class buildPhaseClass = NSClassFromString([NSString stringWithFormat:@"PBX%@BuildPhase", buildPhaseName]);
	id<PBXBuildPhase> buildPhase = [_target buildPhaseOfClass:buildPhaseClass];
	if (!buildPhase)
	{
		if ([buildPhaseClass respondsToSelector:@selector(buildPhase)])
		{
			buildPhase = [buildPhaseClass performSelector:@selector(buildPhase)];
			[_target addBuildPhase:buildPhase];
		}
	}
	
	if ([buildPhase containsFileReferenceIdenticalTo:fileReference])
		return YES;
	
	return [buildPhase addReference:fileReference];
}

@end
