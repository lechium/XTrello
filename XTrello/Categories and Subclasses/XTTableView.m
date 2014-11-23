//
//  XTTableView.m
//  XTrello
//
//  Created by Kevin Bradley on 7/11/14.
//  Copyright (c) 2014 Kevin Bradley. All rights reserved.
//

#import "XTTableView.h"

@implementation XTTableView

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
    }
    return self;
}

-(void)mouseDown:(NSEvent *)theEvent {
    [super mouseDown:theEvent];
    
    // Forward the click to the row's cell view
    NSPoint selfPoint = [self convertPoint:theEvent.locationInWindow fromView:nil];
    NSInteger row = [self rowAtPoint:selfPoint];
    if (row>=0) [(XTTrelloCardView *)[self viewAtColumn:0 row:row makeIfNecessary:NO]
                 mouseDownForTextFields:theEvent];
}

//- (void)drawRect:(NSRect)dirtyRect
//{
//    [super drawRect:dirtyRect];
//    
//    // Drawing code here.
//}

@end
