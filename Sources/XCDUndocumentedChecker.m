//
//  XCDUndocumentedChecker.m
//  xcodeproj
//
//  Created by Cédric Luthi on 2011-02-09.
//  Copyright 2011 Cédric Luthi. All rights reserved.
//

#import "XCDUndocumentedChecker.h"

#import <objc/message.h>
#import <objc/runtime.h>

NSString *const XCDUndocumentedCheckerErrorDomain             = @"XCDUndocumentedChecker";
NSString *const XCDUndocumentedCheckerMismatchingHierarchyKey = @"MismatchingHierarchy";
NSString *const XCDUndocumentedCheckerMissingMethodsKey       = @"MissingMethods";
NSString *const XCDUndocumentedCheckerMismatchingMethodsKey   = @"MismatchingMethods";
NSString *const XCDUndocumentedCheckerClassNameKey            = @"ClassName";
NSString *const XCDUndocumentedCheckerMethodNameKey           = @"MethodName";
NSString *const XCDUndocumentedCheckerProtocolSignatureKey    = @"ProtocolSignature";
NSString *const XCDUndocumentedCheckerClassSignatureKey       = @"ClassSignature";

// ◈ WHITE DIAMOND CONTAINING BLACK SMALL DIAMOND
#define TYPE_SEPARATOR @"\u25C8"

static void forwardInvocationTypeCheck(id self, SEL _cmd, NSInvocation *invocation)
{
	NSString *returnClassName = nil;
	NSString *collectionElementsClassName = nil;
	Class class = object_getClass([invocation target]);
	while (!returnClassName && class)
	{
		NSDictionary *classInfo = [[[[NSBundle mainBundle] infoDictionary] objectForKey:@"XCDUndocumentedChecker"] objectForKey:@"Classes"];
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
		SEL selector = NSSelectorFromString([[returnClassName stringByAppendingString:TYPE_SEPARATOR] stringByAppendingString:NSStringFromSelector([invocation selector])]);
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
	
	NSDictionary *classInfo = [[[[NSBundle mainBundle] infoDictionary] objectForKey:@"XCDUndocumentedChecker"] objectForKey:@"Classes"];
	NSDictionary *methodInfo = [classInfo objectForKey:className];
	
	for (unsigned methodKind = 0; methodKind <= 1; methodKind++)
	{
		BOOL isInstanceMethod = (methodKind == 1);
		
		Method forwardInvocation = class_getInstanceMethod([NSObject class], @selector(forwardInvocation:));
		BOOL added = class_addMethod(isInstanceMethod ? class : object_getClass(class), @selector(forwardInvocation:), (IMP)forwardInvocationTypeCheck, method_getTypeEncoding(forwardInvocation));
		if (!added)
			fprintf(stderr, "WARNING: %s already implements the forwardInvocation: method.", [className UTF8String]);
		
		protocolMethods = protocol_copyMethodDescriptionList(protocol, YES, isInstanceMethod, &protocolMethodCount);
		for (unsigned int i = 0; i < protocolMethodCount; i++)
		{
			NSString *methodName = [isInstanceMethod ? @"-" : @"+" stringByAppendingFormat:@"%s", sel_getName(protocolMethods[i].name)];
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
			
			NSString *returnInfo = [methodInfo objectForKey:methodName];
			NSString *returnClassName = [[returnInfo componentsSeparatedByString:@"."] objectAtIndex:0];
			methodName = [methodName substringFromIndex:1];
			if (!returnClassName)
				fprintf(stderr, "WARNING: No return type information found for %c[%s %s]\n", isInstanceMethod ? '-' : '+', [className UTF8String], [methodName UTF8String]);
			else
			{
				NSString *fullMethodName = [[returnClassName stringByAppendingString:TYPE_SEPARATOR] stringByAppendingString:methodName];
				Method method = isInstanceMethod ? class_getInstanceMethod(class, NSSelectorFromString(methodName)) : class_getClassMethod(class, NSSelectorFromString(methodName));
				BOOL added = class_addMethod(isInstanceMethod ? class : object_getClass(class), NSSelectorFromString(fullMethodName), _objc_msgForward, method_getTypeEncoding(method));
				if (added)
				{
					Method typeCheckMethod = isInstanceMethod ? class_getInstanceMethod(class, NSSelectorFromString(fullMethodName)) : class_getClassMethod(class, NSSelectorFromString(fullMethodName));
					method_exchangeImplementations(method, typeCheckMethod);
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
