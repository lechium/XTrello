//
//  NSString+trelloAdditions.m
//  XTrello
//
//  Created by Kevin Bradley on 7/10/14.
//  Copyright (c) 2014 Kevin Bradley. All rights reserved.
//

#import "NSString+trelloAdditions.h"

@implementation NSString (trelloAdditions)

- (NSString *)tildePath
{
    NSArray *pathComponents = [self componentsSeparatedByString:@"/"];
    NSArray *newPath = [pathComponents subarrayWithRange:NSMakeRange(3, pathComponents.count - 3)];
    return [NSString stringWithFormat:@"~/%@", [newPath componentsJoinedByString:@"/"]];
}


- (CGFloat)heightForStringWithFont:(NSFont *)myFont withWidth:(CGFloat)myWidth
{
    NSTextStorage *textStorage = [[NSTextStorage alloc] initWithString:self];
    NSTextContainer *textContainer = [[NSTextContainer alloc] initWithContainerSize:NSMakeSize(myWidth, FLT_MAX)];
    ;
    NSLayoutManager *layoutManager = [[NSLayoutManager alloc] init];
    [layoutManager addTextContainer:textContainer];
    [textStorage addLayoutManager:layoutManager];
    [textStorage addAttribute:NSFontAttributeName value:myFont
                        range:NSMakeRange(0, [textStorage length])];
    [textContainer setLineFragmentPadding:0.0];
    
    (void) [layoutManager glyphRangeForTextContainer:textContainer];
    return [layoutManager
            usedRectForTextContainer:textContainer].size.height;
}


- (NSDictionary *)dictionaryRepresentation
{
	NSString *error = nil;
	NSPropertyListFormat format;
	NSData *theData = [self dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
	id theDict = [NSPropertyListSerialization propertyListFromData:theData
												  mutabilityOption:NSPropertyListImmutable
															format:&format
												  errorDescription:&error];
	return theDict;
}

//  return [NSArray arrayWithObjects:@"blue", @"green", @"orange", @"purple", @"red", @"yellow", nil];

/*
 
 11/22/14 4:23:46.475 PM Xcode[54035]: ### labelArray: {
 black = "";
 blue = "";
 green = "";
 lime = "";
 orange = "";
 pink = "";
 purple = "";
 red = "";
 sky = "";
 yellow = "";
 }

 
 */

- (NSColor *)colorFromName
{
  //  NSLog(@"### name: %@", self);
    if ([[self lowercaseString] isEqualToString:@"black"]) return [NSColor blackColor];
    if ([[self lowercaseString] isEqualToString:@"blue"]) return [NSColor blueColor];
    if ([[self lowercaseString] isEqualToString:@"green"]) return [NSColor greenColor];
    if ([[self lowercaseString] isEqualToString:@"lime"]) return [NSColor limeColor];
    if ([[self lowercaseString] isEqualToString:@"orange"]) return [NSColor orangeColor];
    if ([[self lowercaseString] isEqualToString:@"pink"]) return [NSColor pinkColor];
    if ([[self lowercaseString] isEqualToString:@"purple"]) return [NSColor purpleColor];
    if ([[self lowercaseString] isEqualToString:@"red"]) return [NSColor redColor];
    if ([[self lowercaseString] isEqualToString:@"sky"]) return [NSColor skyColor];
    if ([[self lowercaseString] isEqualToString:@"yellow"]) return [NSColor yellowColor];

    return nil;
}

@end