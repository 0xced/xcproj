//
//  XCDUndocumentedChecker.m
//  xcproj
//
//  Created by Cédric Luthi on 2011-02-09.
//  Copyright 2011 Cédric Luthi. All rights reserved.
//

#import "XCDUndocumentedChecker.h"

#import <dlfcn.h>
#import <objc/message.h>
#import <objc/runtime.h>
extern const char *_protocol_getMethodTypeEncoding(Protocol *p, SEL sel, BOOL isRequiredMethod, BOOL isInstanceMethod);

NSString *const XCDUndocumentedCheckerErrorDomain             = @"XCDUndocumentedChecker";
NSString *const XCDUndocumentedCheckerMismatchingHierarchyKey = @"MismatchingHierarchy";
NSString *const XCDUndocumentedCheckerMissingMethodsKey       = @"MissingMethods";
NSString *const XCDUndocumentedCheckerMismatchingMethodsKey   = @"MismatchingMethods";
NSString *const XCDUndocumentedCheckerClassNameKey            = @"ClassName";
NSString *const XCDUndocumentedCheckerMethodNameKey           = @"MethodName";
NSString *const XCDUndocumentedCheckerProtocolSignatureKey    = @"ProtocolSignature";
NSString *const XCDUndocumentedCheckerClassSignatureKey       = @"ClassSignature";

/*
{ className -> { methodSignature -> returnInfo } }
E.g.
{
  "PBXBuildPhase" ->
  {
    "+buildPhase" -> "PBXBuildPhase";
    "-buildFiles" -> "NSArray.PBXBuildFile";
  }
}
*/
static NSMutableDictionary *classInfo = nil;

static void XCDUndocumentedChecker_forwardInvocation(id self, SEL _cmd, NSInvocation *invocation)
{
	NSString *returnClassName = nil;
	NSString *collectionElementsClassName = nil;
	Class class = object_getClass([invocation target]);
	while (!returnClassName && class)
	{
		NSDictionary *methodInfo = [classInfo objectForKey:NSStringFromClass(class)];
		NSString *returnInfo = [methodInfo objectForKey:[class_isMetaClass(class) ? @"+" : @"-" stringByAppendingString:NSStringFromSelector([invocation selector])]];
		NSArray *returnComponents = [returnInfo componentsSeparatedByString:@"."];
		returnClassName = [returnComponents objectAtIndex:0];
		if ([returnComponents count] == 2)
			collectionElementsClassName = [returnComponents objectAtIndex:1];
		class = class_getSuperclass(class);
	}
	
	NSMethodSignature *methodSignature = [invocation methodSignature];
	NSUInteger methodReturnLength = [methodSignature methodReturnLength];
	@try
	{
		id result = nil;
		SEL selector = NSSelectorFromString([@"XCDUndocumentedChecker_" stringByAppendingString:NSStringFromSelector([invocation selector])]);
		BOOL returnsObject = [methodSignature methodReturnType][0] == _C_ID;
		[invocation setSelector:selector];
		[invocation invoke];
		
		if (returnsObject && methodReturnLength == sizeof(id))
		{
			[invocation getReturnValue:&result];
			
			if (result && ![returnClassName isEqualToString:@"id"])
			{
				if (![result isKindOfClass:NSClassFromString(returnClassName)])
				{
					[invocation setReturnValue:&(id){nil}];
					return;
				}
				
				if (collectionElementsClassName && [result isKindOfClass:[NSArray class]])
				{
					Class collectionElementsClass = NSClassFromString(collectionElementsClassName);
					for (id item in result)
					{
						if (![item isKindOfClass:collectionElementsClass])
						{
							[invocation setReturnValue:&(id){nil}];
							return;
						}
					}
				}
			}
		}
	}
	@catch (NSException *exception)
	{
		uint8_t result[methodReturnLength];
		bzero(result, sizeof(result));
		[invocation setReturnValue:result];
	}
}

Class XCDClassFromProtocol(Protocol *protocol, NSError **error)
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		classInfo = [NSMutableDictionary new];
	});
	
	BOOL hasError = NO;
	if (error)
		*error = nil;
	
	NSString *className = protocol ? [NSString stringWithCString:protocol_getName(protocol) encoding:NSUTF8StringEncoding] : @"nil";
	Class class = NSClassFromString(className);
	if (!class)
	{
		if (error)
		{
			NSDictionary *errorInfo = [NSDictionary dictionaryWithObjectsAndKeys:
			                           [NSString stringWithFormat:@"Class %@ not found", className], NSLocalizedDescriptionKey,
			                           className, XCDUndocumentedCheckerClassNameKey, nil];
			*error = [NSError errorWithDomain:XCDUndocumentedCheckerErrorDomain code:XCDUndocumentedCheckerClassNotFound userInfo:errorInfo];
		}
		return Nil;
	}
	
	NSMutableArray *superClasses = [NSMutableArray array];
	Class superClass = class;
	while ((superClass = [superClass superclass]))
		[superClasses addObject:superClass];
	
	NSMutableArray *hierarchyMismatch = [NSMutableArray array];
	unsigned int protocolCount = 0;
	Protocol **adoptedProtocols = protocol_copyProtocolList(protocol, &protocolCount);
	for (unsigned int i = 0; i < protocolCount; i++)
	{
		Protocol *adoptedProtocol = adoptedProtocols[i];
		NSString *superClassName = NSStringFromProtocol(adoptedProtocol);
		superClass = NSClassFromString(superClassName);
		if (![superClasses containsObject:superClass])
		{
			hasError = YES;
			[hierarchyMismatch addObject:superClassName];
		}
	}
	free(adoptedProtocols);
	
	NSMutableDictionary *methodSignatures = [NSMutableDictionary dictionary];
	
	Method *methods = NULL;
	unsigned int methodCount = 0;
	for (unsigned methodKind = 0; methodKind <= 1; methodKind++)
	{
		BOOL isInstanceMethod = (methodKind == 1);
		methods = class_copyMethodList(isInstanceMethod ? class : object_getClass(class), &methodCount);
		for (unsigned int i = 0; i < methodCount; i++)
		{
			const char *methodName = sel_getName(method_getName(methods[i]));
			const char *typeEncoding = method_getTypeEncoding(methods[i]);
			[methodSignatures setObject:[NSString stringWithUTF8String:typeEncoding] forKey:[NSString stringWithFormat:@"%c%s", isInstanceMethod ? '-':'+', methodName]];
		}
		free(methods);
	}
	
	struct objc_method_description *protocolMethods = NULL;
	unsigned int protocolMethodCount = 0;
	NSMutableArray *methodsNotFound = [NSMutableArray array];
	NSMutableArray *methodsMismatch = [NSMutableArray array];
	
	classInfo[className] = [NSMutableDictionary dictionary];
	
	for (unsigned methodKind = 0; methodKind <= 1; methodKind++)
	{
		BOOL isInstanceMethod = (methodKind == 1);
		protocolMethods = protocol_copyMethodDescriptionList(protocol, YES, isInstanceMethod, &protocolMethodCount);
		Method (*class_getMethod)(Class cls, SEL name) = isInstanceMethod ? class_getInstanceMethod : class_getClassMethod;
		
		Method forwardInvocation = class_getInstanceMethod([NSObject class], @selector(forwardInvocation:));
		BOOL added = class_addMethod(isInstanceMethod ? class : object_getClass(class), @selector(forwardInvocation:), (IMP)XCDUndocumentedChecker_forwardInvocation, method_getTypeEncoding(forwardInvocation));
		if (!added && protocolMethodCount > 0)
		{
			if (error)
			{
				NSDictionary *errorInfo = [NSDictionary dictionaryWithObjectsAndKeys:
				                           [NSString stringWithFormat:@"%@ already implements the forwardInvocation: method.", className], NSLocalizedDescriptionKey,
				                           className, XCDUndocumentedCheckerClassNameKey, nil];
				*error = [NSError errorWithDomain:XCDUndocumentedCheckerErrorDomain code:XCDUndocumentedCheckerUnsupportedClass userInfo:errorInfo];
			}
			free(protocolMethods);
			return Nil;
		}
		
		for (unsigned int i = 0; i < protocolMethodCount; i++)
		{
			SEL selector = protocolMethods[i].name;
			NSString *methodName = [isInstanceMethod ? @"-" : @"+" stringByAppendingFormat:@"%s", sel_getName(selector)];
			NSString *methodSignature = [methodSignatures objectForKey:methodName];
			NSString *expectedSignature = [NSString stringWithUTF8String:protocolMethods[i].types];
			BOOL signatureMatch = [expectedSignature isEqualToString:methodSignature];
			if (!signatureMatch)
			{
				hasError = YES;
				NSDictionary *methodError = nil;
				if (!methodSignature)
				{
					methodError = [NSDictionary dictionaryWithObjectsAndKeys:
					               methodName, XCDUndocumentedCheckerMethodNameKey,
					               className, XCDUndocumentedCheckerClassNameKey, nil];
					[methodsNotFound addObject:methodError];
				}
				else
				{
					methodError = [NSDictionary dictionaryWithObjectsAndKeys:
					               expectedSignature, XCDUndocumentedCheckerProtocolSignatureKey,
					               methodSignature, XCDUndocumentedCheckerClassSignatureKey,
					               methodName, XCDUndocumentedCheckerMethodNameKey,
					               className, XCDUndocumentedCheckerClassNameKey, nil];
					[methodsMismatch addObject:methodError];
				}
			}
			
			NSString *typeEncoding = @(_protocol_getMethodTypeEncoding(protocol, selector, YES, isInstanceMethod) ?: "");
			if ([typeEncoding hasPrefix:@"@\""])
			{
				// Parses extended type encoding, e.g. `@"NSString"16@0:8`, `@"<PBXProject>"24@0:8@"NSString"16`, `@"NSArray<PBXBuildFile>"16@0:8`
				NSString *returnInfo = [typeEncoding componentsSeparatedByString:@"\""][1];
				returnInfo = [returnInfo stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"<>"]];
				returnInfo = [returnInfo stringByReplacingOccurrencesOfString:@"<" withString:@"."];
				classInfo[className][methodName] = returnInfo;
			}
			
			methodName = [methodName substringFromIndex:1];
			if (typeEncoding.length == 0)
			{
				fprintf(stderr, "WARNING: No return type information found for %c[%s %s]\n", isInstanceMethod ? '-' : '+', [className UTF8String], [methodName UTF8String]);
			}
			else
			{
				NSString *forwardMethodName = [@"XCDUndocumentedChecker_" stringByAppendingString:methodName];
				Method method = class_getMethod(class, NSSelectorFromString(methodName));
				if ([NSProcessInfo.processInfo.environment[@"DEBUG_METHOD_IMP"] boolValue])
				{
					Dl_info info;
					if (dladdr(method_getImplementation(method), &info))
						printf("%s: %c[%s %s]\n", info.dli_fname, isInstanceMethod ? '-' : '+', [className UTF8String], [methodName UTF8String]);
				}
				
				BOOL added = class_addMethod(isInstanceMethod ? class : object_getClass(class), NSSelectorFromString(forwardMethodName), _objc_msgForward, method_getTypeEncoding(method));
				if (added)
				{
					Method forwardMethod = class_getMethod(class, NSSelectorFromString(forwardMethodName));
					method_exchangeImplementations(method, forwardMethod);
				}
			}
		}
		free(protocolMethods);
	}
	
	if (error)
	{
		NSMutableDictionary *errorInfo = [NSMutableDictionary dictionary];
		if ([methodsNotFound count] > 0)
			[errorInfo setObject:methodsNotFound forKey:XCDUndocumentedCheckerMissingMethodsKey];
		if ([methodsMismatch count] > 0)
			[errorInfo setObject:methodsMismatch forKey:XCDUndocumentedCheckerMismatchingMethodsKey];
		if ([hierarchyMismatch count] > 0)
			[errorInfo setObject:hierarchyMismatch forKey:XCDUndocumentedCheckerMismatchingHierarchyKey];
		
		if ([errorInfo count] > 0)
		{
			[errorInfo setObject:[NSString stringWithFormat:@"Methods of class %@ do not match %@ protocol", className, NSStringFromProtocol(protocol)] forKey:NSLocalizedDescriptionKey];
			*error = [NSError errorWithDomain:XCDUndocumentedCheckerErrorDomain code:XCDUndocumentedCheckerMethodMismatch userInfo:errorInfo];
		}
	}
	
	return hasError ? Nil : class;
}
