//
//  Xcodeproj.m
//  xcodeproj
//
//  Created by Cédric Luthi on 07.02.11.
//  Copyright Cédric Luthi 2011. All rights reserved.
//

#import "Xcodeproj.h"

#import <dlfcn.h>
#import <objc/runtime.h>
#import "XCDUndocumentedChecker.h"


@interface Xcodeproj ()
- (void) printUsage:(int)exitCode;
- (NSArray *) allowedActions;
@end


@implementation Xcodeproj

static Class PBXGroup = Nil;
static Class PBXProject = Nil;
static Class PBXReference = Nil;
static Class XCBuildConfiguration = Nil;

+ (void) setPBXGroup:(Class)class             { PBXGroup = class; }
+ (void) setPBXProject:(Class)class           { PBXProject = class; }
+ (void) setPBXReference:(Class)class         { PBXReference = class; }
+ (void) setXCBuildConfiguration:(Class)class { XCBuildConfiguration = class; }
+ (void) setValue:(id)value forUndefinedKey:(NSString *)key { /* ignore */ }

+ (void) initialize
{
	if (self != [Xcodeproj class])
		return;

	NSString *developerDir = [NSSearchPathForDirectoriesInDomains(NSDeveloperDirectory, NSLocalDomainMask, YES) lastObject];
	@try
	{
		NSTask *xcode_select = [[[NSTask alloc] init] autorelease];
		[xcode_select setLaunchPath:@"/usr/bin/xcode-select"];
		[xcode_select setArguments:[NSArray arrayWithObject:@"-print-path"]];
		[xcode_select setStandardInput:[NSPipe pipe]]; // Still want logs in Xcode? Use this! http://www.cocoadev.com/index.pl?NSTask
		[xcode_select setStandardOutput:[NSPipe pipe]];
		[xcode_select launch];
		[xcode_select waitUntilExit];
		NSData *developerDirData = [[[xcode_select standardOutput] fileHandleForReading] readDataToEndOfFile];
		developerDir = [[[NSString alloc] initWithData:developerDirData encoding:NSUTF8StringEncoding] autorelease];
		developerDir = [developerDir stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	}
	@catch (NSException *exception)
	{
		developerDir = @"/Developer";
	}
	
	// Xcode < 4.3
	NSString *devToolsCorePath = [developerDir stringByAppendingPathComponent:@"Library/Xcode/PrivatePlugIns/Xcode3Core.ideplugin/Contents/Frameworks/DevToolsCore.framework"];
	NSBundle *devToolsCoreBundle = [NSBundle bundleWithPath:devToolsCorePath];
	if (!devToolsCoreBundle)
	{
		// Xcode >= 4.3
		devToolsCorePath = [developerDir stringByAppendingPathComponent:@"../PlugIns/Xcode3Core.ideplugin/Contents/Frameworks/DevToolsCore.framework"];
		devToolsCoreBundle = [NSBundle bundleWithPath:devToolsCorePath];
	}
	NSError *loadError = nil;
	if (![devToolsCoreBundle loadAndReturnError:&loadError])
	{
		ddfprintf(stderr, @"The DevToolsCore framework failed to load: %@\n", devToolsCoreBundle ? loadError : @"DevToolsCore.framework not found");
		exit(EX_SOFTWARE);
	}
	
	void(*IDEInitialize)(NSUInteger initializationOptions, NSError **error) = dlsym(RTLD_DEFAULT, "IDEInitialize");
	if (IDEInitialize)
	{
		NSError *error = nil;
		// -[Xcode3CommandLineBuildTool run] from Xcode3Core.ideplugin calls IDEInitialize(1, &error)
		IDEInitialize(1, &error);
		if (error)
		{
			ddfprintf(stderr, @"IDEInitialize error: %@\n", error);
			exit(EX_SOFTWARE);
		}
	}
	else
	{
		ddfprintf(stderr, @"IDEInitialize function not found.\n");
		exit(EX_SOFTWARE);
	}
	
	BOOL isSafe = YES;
	NSDictionary *classInfo = [[[[NSBundle mainBundle] infoDictionary] objectForKey:@"XCDUndocumentedChecker"] objectForKey:@"Classes"];
	for (NSString *protocolName in [classInfo allKeys])
	{
		NSError *classError = nil;
		Protocol *protocol = NSProtocolFromString(protocolName);
		Class class = XCDClassFromProtocol(protocol, &classError);
		if (class)
			[self setValue:class forKey:[NSString stringWithCString:protocol_getName(protocol) encoding:NSUTF8StringEncoding]];
		else
		{
			isSafe = NO;
			ddfprintf(stdout, @"%@\n%@\n", [classError localizedDescription], [classError userInfo]);
		}
	}
	
	if (!isSafe)
		exit(EX_SOFTWARE);
}

// MARK: - Options

- (void) application:(DDCliApplication *)app willParseOptions:(DDGetoptLongParser *)optionsParser
{
	DDGetoptOption optionTable[] = 
	{
		// Long        Short  Argument options
		{@"project",   'p',   DDGetoptRequiredArgument},
		{@"target",    't',   DDGetoptRequiredArgument},
		{@"help",      'h',   DDGetoptNoArgument},
		{nil,           0,    0},
	};
	[optionsParser addOptionsFromTable:optionTable];
}

- (void) setProject:(NSString *)projectName
{
	if (![PBXProject isProjectWrapperExtension:[projectName pathExtension]])
		@throw [DDCliParseException parseExceptionWithReason:[NSString stringWithFormat:@"The project name %@ does not have a valid extension.", projectName] exitCode:EX_USAGE];
	
	NSString *projectPath = projectName;
	if (![projectName isAbsolutePath])
		projectPath = [[[NSFileManager defaultManager] currentDirectoryPath] stringByAppendingPathComponent:projectName];
	
	if (![[NSFileManager defaultManager] fileExistsAtPath:projectPath])
		@throw [DDCliParseException parseExceptionWithReason:[NSString stringWithFormat:@"The project %@ does not exist in this directory.", projectName] exitCode:EX_NOINPUT];
	
	[project release];
	project = [[PBXProject projectWithFile:projectPath] retain];
}

- (void) setTarget:(NSString *)aTargetName
{
	if (targetName == aTargetName)
		return;
	
	[targetName release];
	targetName = [aTargetName retain];
}

// MARK: - App run

- (int) application:(DDCliApplication *)app runWithArguments:(NSArray *)arguments
{
	if (help)
		[self printUsage:EX_OK];
	
	NSString *currentDirectoryPath = [[NSFileManager defaultManager] currentDirectoryPath];
	
	if (!project)
	{
		for (NSString *fileName in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:currentDirectoryPath error:NULL])
		{
			if ([PBXProject isProjectWrapperExtension:[fileName pathExtension]])
			{
				if (!project)
					[self setProject:fileName];
				else
				{
					ddfprintf(stderr, @"%@: The directory %@ contains more than one Xcode project. You will need to specify the project with the --project option.\n", app, currentDirectoryPath);
					return EX_USAGE;
				}
			}
		}
	}
	
	if (!project)
	{
		ddfprintf(stderr, @"%@: The directory %@ does not contain an Xcode project.\n", app, currentDirectoryPath);
		return EX_USAGE;
	}
	
	if (targetName)
	{
		target = [[project targetNamed:targetName] retain];
		if (!target)
			@throw [DDCliParseException parseExceptionWithReason:[NSString stringWithFormat:@"The target %@ does not exist in this project.", targetName] exitCode:EX_DATAERR];
	}
	else
	{
		NSArray *targets = [project targets];
		if ([targets count] > 0)
			target = [[targets objectAtIndex:0] retain];
		if (!target)
			@throw [DDCliParseException parseExceptionWithReason:[NSString stringWithFormat:@"The project %@ does not contain any target.", [project name]] exitCode:EX_DATAERR];
	}
	
	if ([arguments count] < 1)
	{
		[self printUsage:EX_USAGE];
		return EX_USAGE;
	}
	else
	{
		NSString *action = [arguments objectAtIndex:0];
		if (![[self allowedActions] containsObject:action])
			[self printUsage:EX_USAGE];
		
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
		return (int)[self performSelector:actionSelector withObject:actionArguments];
	}
}

// MARK: - Actions

- (NSArray *) allowedActions
{
	return [NSArray arrayWithObjects:@"list-targets", @"list-headers", @"read-build-setting", @"add-xcconfig", @"add-resources-bundle", @"touch", nil];
}

- (void) printUsage:(int)exitCode
{
	ddprintf(@"Usage: %@ ...\n", [[NSBundle mainBundle] objectForInfoDictionaryKey:(id)kCFBundleExecutableKey]);
	exit(exitCode);
}

- (int) listTargets:(NSArray *)arguments
{
	if ([arguments count] > 0)
		[self printUsage:EX_USAGE];
	
	for (id<PBXTarget> aTarget in [project targets])
		ddprintf(@"%@\n", [aTarget name]);
	
	return [[project targets] count] > 0 ? EX_OK : EX_SOFTWARE;
}

- (int) listHeaders:(NSArray *)arguments
{
	if ([arguments count] > 1)
		[self printUsage:EX_USAGE];
	
	NSString *headerRole = @"Public";
	if ([arguments count] == 1)
		headerRole = [[arguments objectAtIndex:0] capitalizedString];
	
	NSArray *allowedValues = [NSArray arrayWithObjects:@"All", @"Public", @"Project", @"Private", nil];
	if (![allowedValues containsObject:headerRole])
		@throw [DDCliParseException parseExceptionWithReason:[NSString stringWithFormat:@"list-headers argument must be one of {%@}.", [allowedValues componentsJoinedByString:@", "]] exitCode:EX_USAGE];
	
	id<PBXBuildPhase> headerBuildPhase = [target defaultHeaderBuildPhase];
	for (id<PBXBuildFile> buildFile in [headerBuildPhase buildFiles])
	{
		NSArray *attributes = [buildFile settingsArrayForKey:@"ATTRIBUTES"];
		if ([attributes containsObject:headerRole] || [headerRole isEqualToString:@"All"])
			ddprintf(@"%@\n", [buildFile absolutePath]);
	}
	
	return EX_OK;
}

- (int) readBuildSetting:(NSArray *)arguments
{
	if ([arguments count] != 1)
		[self printUsage:EX_USAGE];
	
	NSString *buildSetting = [arguments objectAtIndex:0];
	NSString *settingString = [NSString stringWithFormat:@"$(%@)", buildSetting];
	NSString *expandedString = [target expandedValueForString:settingString forBuildParameters:nil];
	if ([expandedString length] > 0)
		ddprintf(@"%@\n", expandedString);
	
	return EX_OK;
}

- (int) writeProject
{
	BOOL written = [project writeToFileSystemProjectFile:YES userFile:NO checkNeedsRevert:NO];
	if (!written)
	{
		ddfprintf(stderr, @"Could not write '%@' to file system.", project);
		return EX_IOERR;
	}
	return EX_OK;
}

- (int) addXcconfig:(NSArray *)arguments
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
	
	id<XCConfigurationList> buildConfigurationList = [project buildConfigurationList];
	NSArray *buildConfigurations = [buildConfigurationList buildConfigurations];
	for (id<XCBuildConfiguration> configuration in buildConfigurations)
		[configuration setBaseConfigurationReference:xcconfig];
	
	[self addGroupNamed:@"Configurations" beforeGroupNamed:@"Frameworks"];
	[self addFileReference:xcconfig inGroupNamed:@"Configurations"];
	
	return [self writeProject];
}

- (int) addResourcesBundle:(NSArray *)arguments
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

- (int) touch:(NSArray *)arguments
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
	return [self groupNamed:groupName inGroup:[project rootGroup] parentGroup:parentGroup];
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
	
	id<PBXFileReference> fileReference = [project fileReferenceForPath:filePath];
	if (!fileReference)
	{
		NSArray *references = [[project rootGroup] addFiles:[NSArray arrayWithObject:filePath] copy:NO createGroupsRecursively:NO];
		fileReference = [references lastObject];
	}
	return fileReference;
}

- (BOOL) addFileReference:(id<PBXFileReference>)fileReference inGroupNamed:(NSString *)groupName
{
	id<PBXGroup> group = [self groupNamed:groupName parentGroup:NULL];
	if (!group)
		group = [project rootGroup];
	
	if ([group containsItem:fileReference])
		return YES;
	
	[group addItem:fileReference];
	
	return YES;
}

- (BOOL) addFileReference:(id<PBXFileReference>)fileReference toBuildPhase:(NSString *)buildPhaseName
{
	Class buildPhaseClass = NSClassFromString([NSString stringWithFormat:@"PBX%@BuildPhase", buildPhaseName]);
	id<PBXBuildPhase> buildPhase = [target buildPhaseOfClass:buildPhaseClass];
	if (!buildPhase)
	{
		if ([buildPhaseClass respondsToSelector:@selector(buildPhase)])
		{
			buildPhase = [buildPhaseClass performSelector:@selector(buildPhase)];
			[target addBuildPhase:buildPhase];
		}
	}
	
	if ([buildPhase containsFileReferenceIdenticalTo:fileReference])
		return YES;
	
	return [buildPhase addReference:fileReference];
}

@end
