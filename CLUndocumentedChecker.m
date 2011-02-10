//
//  CLUndocumentedChecker.m
//  xcodeproj
//
//  Created by Cédric Luthi on 2011-02-09.
//  Copyright 2011 Cédric Luthi. All rights reserved.
//

#import "CLUndocumentedChecker.h"

#import <objc/runtime.h>

NSString *const CLUndocumentedCheckerErrorDomain           = @"CLUndocumentedChecker";
NSString *const CLUndocumentedCheckerMissingMethodsKey     = @"MissingMethods";
NSString *const CLUndocumentedCheckerMismatchingMethodsKey = @"MismatchingMethods";
NSString *const CLUndocumentedCheckerClassNameKey          = @"ClassName";
NSString *const CLUndocumentedCheckerMethodNameKey         = @"MethodName";
NSString *const CLUndocumentedCheckerProtocolSignatureKey  = @"ProtocolSignature";
NSString *const CLUndocumentedCheckerClassSignatureKey     = @"ClassSignature";

Class CLClassFromProtocol(Protocol *protocol, NSError **error)
{
	if (error)
		*error = nil;
	
	NSString *className = [NSString stringWithCString:protocol_getName(protocol) encoding:NSUTF8StringEncoding];
	Class class = NSClassFromString(className);
	if (!class)
	{
		if (error)
		{
			NSDictionary *errorInfo = [NSDictionary dictionaryWithObjectsAndKeys:
			                           [NSString stringWithFormat:@"Class %@ not found", className], NSLocalizedDescriptionKey,
			                           className, CLUndocumentedCheckerClassNameKey, nil];
			*error = [NSError errorWithDomain:CLUndocumentedCheckerErrorDomain code:CLUndocumentedCheckerClassNotFound userInfo:errorInfo];
		}
		return nil;
	}
	
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
	
	for (unsigned methodKind = 0; methodKind <= 1; methodKind++)
	{
		BOOL isInstanceMethod = (methodKind == 1);
		protocolMethods = protocol_copyMethodDescriptionList(protocol, YES, isInstanceMethod, &protocolMethodCount);
		for (unsigned int i = 0; i < protocolMethodCount; i++)
		{
			NSString *methodName = [NSString stringWithFormat:@"%c%s", isInstanceMethod ? '-':'+', sel_getName(protocolMethods[i].name)];
			NSString *methodSignature = [methodSignatures objectForKey:methodName];
			NSString *expectedSignature = [NSString stringWithUTF8String:protocolMethods[i].types];
			BOOL signatureMatch = [expectedSignature isEqualToString:methodSignature];
			if (!signatureMatch)
			{
				class = Nil;
				NSDictionary *methodError = nil;
				if (!methodSignature)
				{
					methodError = [NSDictionary dictionaryWithObjectsAndKeys:
					               methodName, CLUndocumentedCheckerMethodNameKey,
					               className, CLUndocumentedCheckerClassNameKey, nil];
					[methodsNotFound addObject:methodError];
				}
				else
				{
					methodError = [NSDictionary dictionaryWithObjectsAndKeys:
					               expectedSignature, CLUndocumentedCheckerProtocolSignatureKey,
					               methodSignature, CLUndocumentedCheckerClassSignatureKey,
					               methodName, CLUndocumentedCheckerMethodNameKey,
					               className, CLUndocumentedCheckerClassNameKey, nil];
					[methodsMismatch addObject:methodError];
				}
			}
		}
		free(protocolMethods);
	}
	
	if (error)
	{
		NSMutableDictionary *errorInfo = [NSMutableDictionary dictionary];
		if ([methodsNotFound count] > 0)
			[errorInfo setObject:methodsNotFound forKey:CLUndocumentedCheckerMissingMethodsKey];
		if ([methodsMismatch count] > 0)
			[errorInfo setObject:methodsMismatch forKey:CLUndocumentedCheckerMismatchingMethodsKey];
		
		if ([errorInfo count] > 0)
		{
			[errorInfo setObject:[NSString stringWithFormat:@"Methods of class %@ do not match %@ protocol", className, NSStringFromProtocol(protocol)] forKey:NSLocalizedDescriptionKey];
			*error = [NSError errorWithDomain:CLUndocumentedCheckerErrorDomain code:CLUndocumentedCheckerMethodMismatch userInfo:errorInfo];
		}
	}
	
	return class;
}
