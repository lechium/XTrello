//
//  XTTagViewController.m
//  XTrello
//
//  Created by Kevin Bradley on 7/11/14.
//  Copyright (c) 2014 Kevin Bradley. All rights reserved.
//

#import "XTTagViewController.h"

@implementation XTTagViewController

- (id)initWithFrame:(NSRect)frame andLabels:(NSArray *)labelArray
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
        float offset = 0;
        for (NSString *colorString in labelArray)
        {
            NSColor *newColor = [self colorFromString:colorString];
            NSRect viewRect = NSMakeRect(offset, 0, 40, 10);
            XTTagView *newView = [[XTTagView alloc] initWithFrame:viewRect andColor:newColor];
            //  NSView *newView = [[NSView alloc] initWithFrame:viewRect];
            [self addSubview:newView];
            offset = offset + 44;
        }
        
    }
    return self;
}

- (NSColor *)colorFromString:(NSString *)theString
{
    if ([theString isEqualToString:@"green"]) return [NSColor greenColor];
    if ([theString isEqualToString:@"yellow"]) return [NSColor yellowColor];
    if ([theString isEqualToString:@"orange"]) return [NSColor orangeColor];
    if ([theString isEqualToString:@"red"]) return [NSColor redColor];
    if ([theString isEqualToString:@"purple"]) return [NSColor purpleColor];
    if ([theString isEqualToString:@"blue"]) return [NSColor blueColor];
    if ([theString isEqualToString:@"pink"]) return [NSColor pinkColor];
    if ([theString isEqualToString:@"sky"]) return [NSColor skyColor];
    if ([theString isEqualToString:@"lime"]) return [NSColor limeColor];
    return nil;
}

- (void)removeAllSubviews
{
    NSArray *subviews = [self subviews];
    int i = 0;
    for (i = 0; i < subviews.count; i++) {
        
        NSView *theView = [subviews objectAtIndex:i];
        [theView removeFromSuperview];
        
    }
}

- (NSArray *)reuseSubviews:(NSArray *)inputArray
{
    NSMutableArray *returnArray = [inputArray mutableCopy];
    int currentIndex = 0;
    for (XTTagView *theView in self.subviews)
    {
        NSString *colorString = [returnArray objectAtIndex:currentIndex];
        theView.backgroundColor = [self colorFromString:colorString];
        [returnArray removeObject:colorString];
    }
    return returnArray;
}

- (void)updateLabels:(NSArray *)theLabels
{
   [self removeAllSubviews];
  //  NSArray *finalArray = [self reuseSubviews:theLabels];
    float offset = 0;
//    if (finalArray.count != theLabels.count)
//    {
//        //update the offset
//      //  NSInteger arrayDiff = theLabels.count - finalArray.count;
//        offset = 44 * (finalArray.count+1);
//        NSLog(@"finalArray.count: %li offset: %f", finalArray.count, offset);
//    }
    for (NSString *colorString in theLabels)
    {
        NSColor *newColor = [self colorFromString:colorString];
        NSRect viewRect = NSMakeRect(offset, 0, 40, 10);
        XTTagView *newView = [[XTTagView alloc] initWithFrame:viewRect andColor:newColor];
        //  NSView *newView = [[NSView alloc] initWithFrame:viewRect];
        [self addSubview:newView];
        offset = offset + 44;
    }
    [self setNeedsDisplay:TRUE];
}

//- (void)drawRect:(NSRect)dirtyRect
//{
//    [super drawRect:dirtyRect];
//    
//    // Drawing code here.
//}

@end
