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


static id typeCheck(id self, SEL _cmd, ...)
{
	NSString *returnType = nil;
	struct objc_method_description *protocolMethods = NULL;
	unsigned int protocolMethodCount = 0;
	
	Class class = [self class];
	while (!returnType && class)
	{
		protocolMethods = protocol_copyMethodDescriptionList(objc_getProtocol(class_getName(class)), NO, !class_isMetaClass(self->isa), &protocolMethodCount);
		for (unsigned int i = 0; i < protocolMethodCount; i++)
		{
			NSString *methodName = [NSString stringWithCString:sel_getName(protocolMethods[i].name) encoding:NSUTF8StringEncoding];
			if ([methodName hasSuffix:[@"$" stringByAppendingString:NSStringFromSelector(_cmd)]])
			{
				returnType = [[methodName componentsSeparatedByString:@"$"] objectAtIndex:0];
				break;
			}
		}
		free(protocolMethods);
		class = [class superclass];
	}
	
	if (returnType == nil)
		return nil;
	
	id result = nil;
	@try
	{
		NSMethodSignature *methodSignature = [self methodSignatureForSelector:_cmd];
		NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:methodSignature];
		SEL selector = NSSelectorFromString([NSString stringWithFormat:@"%@$%s", returnType, _cmd]);
		[invocation setTarget:self];
		[invocation setSelector:selector];
		va_list ap;
		va_start(ap, _cmd);
		char* args = (char*)ap;
		for (unsigned i = 2; i < [methodSignature numberOfArguments]; i++)
		{
			// vararg trick from http://blog.jayway.com/2010/03/30/performing-any-selector-on-the-main-thread/
			const char *type = [methodSignature getArgumentTypeAtIndex:i];
			NSUInteger size, align;
			NSGetSizeAndAlignment(type, &size, &align);
			NSUInteger mod = (NSUInteger)args % align;
			if (mod != 0)
				args += (align - mod);
			[invocation setArgument:args atIndex:i];
			args += size;
		}
		va_end(args);
		[invocation invoke];
		[invocation getReturnValue:&result];
	}
	@catch (NSException *exception)
	{
		result = nil;
	}
	
	if (![result isKindOfClass:NSClassFromString(returnType)])
		return nil;
	
	return result;
}

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
		for (unsigned modalKind = 0; modalKind <= 1; modalKind++)
		{
			BOOL isRequiredMethod = (modalKind == 0);
			protocolMethods = protocol_copyMethodDescriptionList(protocol, isRequiredMethod, isInstanceMethod, &protocolMethodCount);
			for (unsigned int i = 0; i < protocolMethodCount; i++)
			{
				NSString *methodName = [NSString stringWithCString:sel_getName(protocolMethods[i].name) encoding:NSUTF8StringEncoding];
				if (isRequiredMethod)
				{
					methodName = [isInstanceMethod ? @"-" : @"+" stringByAppendingString:methodName];
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
				else
				{
					NSArray *components = [methodName componentsSeparatedByString:@"$"];
					if ([components count] == 2)
					{
						NSString *fullMethodName = [[methodName copy] autorelease];
						methodName = [components objectAtIndex:1];
						Method method = isInstanceMethod ? class_getInstanceMethod(class, NSSelectorFromString(methodName)) : class_getClassMethod(class, NSSelectorFromString(methodName));
						BOOL added = class_addMethod(isInstanceMethod ? class : class->isa, NSSelectorFromString(fullMethodName), typeCheck, method_getTypeEncoding(method));
						if (added)
						{
							Method typeCheckMethod = isInstanceMethod ? class_getInstanceMethod(class, NSSelectorFromString(fullMethodName)) : class_getClassMethod(class, NSSelectorFromString(fullMethodName));
							method_exchangeImplementations(method, typeCheckMethod);
						}
					}
				}
			}
			free(protocolMethods);
		}
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
