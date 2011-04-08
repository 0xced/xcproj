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
#import "CLUndocumentedChecker.h"

@implementation Xcodeproj

static Class PBXProject = Nil;

+ (void) setPBXProject:(Class)class
{
	PBXProject = class;
}

+ (void) setValue:(id)value forUndefinedKey:(NSString *)key
{
	// ignore
}

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
	
	NSString *devToolsCorePath = [developerDir stringByAppendingPathComponent:@"Library/PrivateFrameworks/DevToolsCore.framework"];
	NSBundle *devToolsCoreBundle = [NSBundle bundleWithPath:devToolsCorePath];
	NSError *loadError = nil;
	if (![devToolsCoreBundle loadAndReturnError:&loadError])
	{
		ddfprintf(stderr, @"The DevToolsCore framework failed to load: %@\n", loadError);
		exit(EX_SOFTWARE);
	}
	
	// XCInitializeCoreIfNeeded is called with NSClassFromString(@"NSApplication") != nil as argument in +[PBXProject projectWithFile:errorHandler:readOnly:]
	// At that point, the AppKit framework is loaded, _includeUIPlugins is set to YES and all plugins are loaded, even those with XCPluginHasUI == NO
	void *devToolsCore = dlopen([[devToolsCoreBundle executablePath] fileSystemRepresentation], RTLD_LAZY);
	void(*XCInitializeCoreIfNeeded)(BOOL hasGUI) = dlsym(devToolsCore, "XCInitializeCoreIfNeeded");
	if (XCInitializeCoreIfNeeded)
		XCInitializeCoreIfNeeded(NO);
	dlclose(devToolsCore);
	
	BOOL isSafe = YES;
	NSDictionary *classInfo = [[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CLUndocumentedChecker"] objectForKey:@"Classes"];
	for (NSString *protocolName in [classInfo allKeys])
	{
		NSError *classError = nil;
		Protocol *protocol = NSProtocolFromString(protocolName);
		Class class = CLClassFromProtocol(protocol, &classError);
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

- (void) application:(DDCliApplication *)app willParseOptions:(DDGetoptLongParser *)optionsParser
{
	DDGetoptOption optionTable[] = 
	{
		// Long       Short  Argument options
		{@"project",  'p',   DDGetoptRequiredArgument},
		{@"target",   't',   DDGetoptRequiredArgument},
		{@"help",     'h',   DDGetoptNoArgument},
		{nil,          0,    0},
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

- (int) application:(DDCliApplication *)app runWithArguments:(NSArray *)arguments
{
	if (help)
	{
		ddprintf(@"Usage: %@ ...\n", app);
		return EX_OK;
	}
	
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
		target = [[project activeTarget] retain];
		if (!target)
			@throw [DDCliParseException parseExceptionWithReason:[NSString stringWithFormat:@"The project %@ does not contain any target.", [project name]] exitCode:EX_DATAERR];
	}
	
	[self printBuildPhases];
	
	return EX_OK;
}

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

@end
