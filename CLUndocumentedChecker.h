//
//  CLUndocumentedChecker.h
//  xcodeproj
//
//  Created by Cédric Luthi on 2011-02-09.
//  Copyright 2011 Cédric Luthi. All rights reserved.
//

#import <Foundation/Foundation.h>

enum {
	CLUndocumentedCheckerClassNotFound  = 1,
	CLUndocumentedCheckerMethodMismatch = 2,
};

extern NSString *const CLUndocumentedCheckerErrorDomain;
extern NSString *const CLUndocumentedCheckerMissingMethodsKey;
extern NSString *const CLUndocumentedCheckerMismatchingMethodsKey;
extern NSString *const CLUndocumentedCheckerClassNameKey;
extern NSString *const CLUndocumentedCheckerMethodNameKey;
extern NSString *const CLUndocumentedCheckerProtocolSignatureKey;
extern NSString *const CLUndocumentedCheckerClassSignatureKey;

Class CLClassFromProtocol(Protocol *protocol, NSError **error);
