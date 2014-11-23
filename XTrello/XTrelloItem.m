//
//  XTrelloItem.m
//  XTrello
//
//  Created by Kevin Bradley on 7/15/14.
//  Copyright (c) 2014 Kevin Bradley. All rights reserved.
//

#import "XTrelloItem.h"

@implementation XTrelloItem

/*
 
 ~/Developer/XTrello/XTrello/Categories and Subclasses/NSString trelloAdditions.m
 branch: master
 line: 13
 - (NSString )tildePath
 {
 NSArray pathComponents = [self componentsSeparatedByString:@"/"];
 NSArray *newPath = [pathComponents subarrayWithRange:NSMakeRange(3, pathComponents.count - 3)];
 return [NSString stringWithFormat:@"~/%@", [newPath componentsJoinedByString:@"/"]];
 }
 
 
 */

- (id)initWithString:(NSString *)theString
{
    if (self = [super init])
    {
        NSArray *lineArray = [theString componentsSeparatedByString:@"\n"];
       // NSLog(@"lineArrayCount: %lu", (unsigned long)lineArray.count);
        if ([lineArray count] > 5)
        {
            self.filePath = [[lineArray objectAtIndex:0] stringByExpandingTildeInPath];
            self.branch = [[[lineArray objectAtIndex:1] componentsSeparatedByString:@":"] lastObject];
            self.lineNumber = [[[[lineArray objectAtIndex:2] componentsSeparatedByString:@":"] lastObject] floatValue];
            self.content = [[lineArray subarrayWithRange:NSMakeRange(3, lineArray.count-3)] componentsJoinedByString:@"\n"];
            NSLog(@"filePath: %@ lineNumber: %lu", self.filePath, (unsigned long)self.lineNumber);
        }
        
    }
    
    return self;
}
@end
