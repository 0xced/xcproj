#!/usr/bin/env python

import plistlib, re, sys

def buildClasses(headers):
    classes = dict()
    for header in headers:
        with open(header) as f:
            className = None
            for line in f:
                protocolMatch = re.search(r"@protocol\s+(\w+)", line)
                methodMatch = re.search(r"\s*([+-])\s*\(\s*((\w+)\s?\*|id\s*<(\w+)>)\s*\)\s*(.*);", line)
                if protocolMatch:
                    className = protocolMatch.group(1)
                    classes[className] = dict()
                elif methodMatch:
                    assert(className)
                    methodKind = methodMatch.group(1)
                    returnType = methodMatch.group(3) or methodMatch.group(4)
                    method = methodMatch.group(5)
                    selector = ""
                    for match in re.finditer(r"((\w+:)\s*\([^)]+\)\s*\w*)+", method):
                        selector = selector + match.group(2)
                    if len(selector) == 0:
                        selector = method
                    
                    classes[className][methodKind + selector] = returnType
    
    return classes

def main():
    if len(sys.argv) < 3:
        print >> sys.stderr, "Usage: %s Info.plist headers" % sys.argv[0]
        exit(1)
    
    infoPlist = sys.argv[1]
    try:
        plist = plistlib.readPlist(infoPlist)
    except:
        plist = None
    
    if plist == None:
        print >> sys.stderr, "%s is not a valid Info.plist file" % infoPlist
        exit(1)
    
    plist["CLUndocumentedChecker"]["Classes"] = buildClasses(sys.argv[2:])
    
    plistlib.writePlist(plist, infoPlist)

if __name__ == '__main__':
    main()
