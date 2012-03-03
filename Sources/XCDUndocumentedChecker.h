//
//  XCDUndocumentedChecker.h
//  xcodeproj
//
//  Created by Cédric Luthi on 2011-02-09.
//  Copyright 2011 Cédric Luthi. All rights reserved.
//

#import <Foundation/Foundation.h>

enum {
	XCDUndocumentedCheckerClassNotFound  = 1,
	XCDUndocumentedCheckerMethodMismatch = 2,
};

extern NSString *const XCDUndocumentedCheckerErrorDomain;
extern NSString *const XCDUndocumentedCheckerMismatchingHierarchyKey;
extern NSString *const XCDUndocumentedCheckerMissingMethodsKey;
extern NSString *const XCDUndocumentedCheckerMismatchingMethodsKey;
extern NSString *const XCDUndocumentedCheckerClassNameKey;
extern NSString *const XCDUndocumentedCheckerMethodNameKey;
extern NSString *const XCDUndocumentedCheckerProtocolSignatureKey;
extern NSString *const XCDUndocumentedCheckerClassSignatureKey;

Class XCDClassFromProtocol(Protocol *protocol, NSError **error);
