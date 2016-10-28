//
//  XTTrelloCardView.m
//  XTrello
//
//  Created by Kevin Bradley on 7/10/14.
//  Copyright (c) 2014 Kevin Bradley. All rights reserved.
//

#import "XTTrelloCardView.h"
#import "XTTrelloWrapper.h"
#import "XTTagView.h"
#import "NSMenuItem+boardDict.h"

@implementation XTTrelloCardView

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {

    }
    return self;
}

- (void)showDeleteCardAlert
{
    NSAlert *deleteAlert = [NSAlert alertWithMessageText:@"Deletion Warning" defaultButton:@"Delete" alternateButton:@"Cancel" otherButton:nil informativeTextWithFormat:@"Are you sure you want to delete the card: %@? This cannot be undone!!", self.cardDict[@"name"]];
    
    NSModalResponse deleteResponse = [deleteAlert runModal];
    switch (deleteResponse) {
            
        case NSAlertDefaultReturn:
            
            [[XTTrelloWrapper sharedInstance] deleteCard:self.cardDict inBoardNamed:self.boardName];
            [self delegateRefreshList];
            break;
            
        case NSAlertAlternateReturn:
            
            break;
    }
}


- (IBAction)textfieldDidEndEditing:(NSTextField *)sender
{
    if (![[sender stringValue] isEqualToString:self.cardDict[@"name"]])
    {
        NSString *cardName = [sender stringValue];
        NSDictionary *boardDict = [[[[XTTrelloWrapper sharedInstance] updateLocalCard:self.cardDict withName:sender.stringValue inBoardNamed:self.boardName] objectForKey:@"boards"] objectForKey:self.boardName];
        NSDictionary *cardSearch = [[[boardDict objectForKey:@"cards"] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"(SELF.name == %@)", sender.stringValue]] lastObject];
        self.cardDict = cardSearch;
        
        CGRect nameFrame = sender.frame;
        NSFont *labelFont = [NSFont systemFontOfSize:12];
        CGFloat cardNameHeight = [cardName heightForStringWithFont:labelFont withWidth:280] + 10;
        CGFloat cardNameOriginY = (100.0 - cardNameHeight)/2;
        nameFrame.size.height = cardNameHeight;
        nameFrame.origin.y = cardNameOriginY;
        nameFrame.size.width = 290;
        sender.frame = nameFrame;
    }
    [sender setEditable:FALSE];
    [sender setBordered:FALSE];
    [sender  resignFirstResponder];
}

- (void)editText
{
    [self.titleView setEditable:TRUE];
    [self.titleView setBordered:TRUE];
    [[self window] makeFirstResponder:self.titleView];
}

- (void)moveCardToBoard:(NSMenuItem *)sender
{
    XTTrelloWrapper *apiWrapper = [XTTrelloWrapper sharedInstance];
    NSDictionary *boardDict = sender.boardDictionary;
    //NSLog(@"boardDict; %@", boardDict);
    //return;
    NSString *newBoardName = boardDict[@"boardName"];
    NSString *chosenListName = boardDict[@"listName"];
    
    NSLog(@"cardDict: %@", self.cardDict);
    [apiWrapper moveCard:self.cardDict fromBoardNamed:self.boardName toBoardNamed:newBoardName toListNamed:chosenListName];
    //[apiWrapper moveCard:self.cardDict toListWithID:listID inBoardNamed:self.boardName];
    [self delegateRefreshList];
    
}

- (IBAction)moveCard:(id)sender
{
    XTTrelloWrapper *apiWrapper = [XTTrelloWrapper sharedInstance];
    NSString *listName = [sender title];
    NSString *listID = [[apiWrapper listWithName:listName inBoardNamed:self.boardName] valueForKey:@"id"];
    [apiWrapper moveCard:self.cardDict toListWithID:listID inBoardNamed:self.boardName];
    [self delegateRefreshList];
}

- (IBAction)deleteCard:(id)sender
{
    [self showDeleteCardAlert];
}

- (NSArray *)usefulLabelArray:(NSArray *)labelArray
{
    NSMutableArray *newArray = [[NSMutableArray alloc] init];
    for (NSDictionary *labelDict in labelArray)
    {
        [newArray addObject:labelDict[@"color"]];
    }
    return newArray;
}

- (void)delegateRefreshList
{
    [self.delegate populateCardsFromListNamed:self.listName inBoard:self.boardName];

}

//1 = on, 0 = off
- (IBAction)setCardLabels:(id)sender
{
    XTMenuItem *menuItem = (XTMenuItem *)sender;
    NSString *realValue = [menuItem realValue];
    NSInteger state = menuItem.state;
    if (state == 0) //it was off and that particular label didnt exist yet
    {
        NSMutableArray *currentLabels = [[[self cardDict] valueForKey:@"labels"] mutableCopy];
       // NSDictionary *newLabel = @{@"color": realValue, @"name": menuItem.title};
        
        NSDictionary *newLabel = [[XTTrelloWrapper sharedInstance] labelDictionaryFromColor:realValue inBoardNamed:self.boardName];
        
        NSLog(@"newLabel: %@", newLabel);
        
        [currentLabels addObject:newLabel];
        
        
        
        [[XTTrelloWrapper sharedInstance] updateLocalCardLabels:self.cardDict withList:currentLabels inBoardNamed:self.boardName];
        [[XTTrelloWrapper sharedInstance] addLabelID:newLabel[@"id"] forCardWithID:self.cardDict[@"id"]];
        
        
    } else { //delete the label!
        
        NSMutableArray *currentLabels = [[[self cardDict] valueForKey:@"labels"] mutableCopy];
        NSDictionary *newLabel = [[XTTrelloWrapper sharedInstance] labelDictionaryFromColor:realValue inBoardNamed:self.boardName];
        // NSDictionary *newLabel = @{@"color": realValue, @"name": menuItem.title};
        [currentLabels removeObject:newLabel];
       [[XTTrelloWrapper sharedInstance] updateLocalCardLabels:self.cardDict withList:currentLabels inBoardNamed:self.boardName];
        [[XTTrelloWrapper sharedInstance] deleteLabelID:newLabel[@"id"] forCardWithID:self.cardDict[@"id"]];
    }
    
    if (state == 0) state = 1;
    if (state == 1) state = 0;
    [menuItem setState:state];
    
    [self delegateRefreshList];

}

- (BOOL)containsMemberId:(NSString *)memberID
{
    return [[[self cardDict] valueForKey:@"idMembers"] containsObject:memberID];
}


- (BOOL)containsMember:(NSString *)memberName
{
    BOOL containsBool = FALSE;
    
    NSDictionary *cardSearch = [[[[self cardDict] valueForKey:@"members"] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"(fullName == %@)",memberName]] lastObject];
    if (cardSearch != nil)
        containsBool = TRUE;
    else
        containsBool = FALSE;
    
    
    return containsBool;
    
}

- (BOOL)containsLabel:(NSString *)labelName
{
    BOOL containsBool = FALSE;
    
    NSDictionary *cardSearch = [[[[self cardDict] valueForKey:@"labels"] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"(color == %@)",labelName]] lastObject];
    if (cardSearch != nil)
        containsBool = TRUE;
    else
        containsBool = FALSE;
    
    
    return containsBool;
    
}

- (void)populateLists
{
    if ([[listsMenu itemArray] count] == 0)
    {
        NSArray *listsObjects = [[[XTTrelloWrapper sharedInstance] boardNamed:self.boardName] objectForKey:@"lists"];
        int itemTag = 0;
        for (NSDictionary *currentList in listsObjects)
        {
            NSString *listName = currentList[@"name"];
            NSMenuItem *currentItem = [[NSMenuItem alloc] initWithTitle:listName action:@selector(moveCard:) keyEquivalent:@""];
            [currentItem setTag:itemTag];
            itemTag++;
            [listsMenu addItem:currentItem];
        }
    }
    
    if ([[boardsMenu itemArray] count] == 0)
    {
        NSArray *boardObjects = [self.delegate boardArray];
        int itemTag = 0;
        for (NSDictionary *currentBoard in boardObjects)
        {
            NSMenuItem *currentItem = [[NSMenuItem alloc] initWithTitle:currentBoard[@"name"] action:@selector(moveCardToBoard:) keyEquivalent:@""];
            
            NSMenu *listsSubmenu = [[NSMenu alloc] initWithTitle:@""];
            
            for (NSDictionary *list in currentBoard[@"lists"])
            {
                
                NSMenuItem *currentSubItem = [[NSMenuItem alloc] initWithTitle:list[@"name"] action:@selector(moveCardToBoard:) keyEquivalent:@""];
                currentSubItem.boardDictionary = @{@"boardName": currentBoard[@"name"], @"listName": list[@"name"]};
                [listsSubmenu addItem:currentSubItem];
            }
            
            [currentItem setTag:itemTag];
            itemTag++;
            [currentItem setSubmenu:listsSubmenu];
            [boardsMenu addItem:currentItem];
        }
    }
    
    /*
    if ([[boardsMenu itemArray] count] == 0)
    {
        NSArray *boardObjects = [self.delegate boardNames];
        int itemTag = 0;
        for (NSString *currentBoard in boardObjects)
        {
            NSMenuItem *currentItem = [[NSMenuItem alloc] initWithTitle:currentBoard action:@selector(moveCardToBoard:) keyEquivalent:@""];
            [currentItem setTag:itemTag];
            itemTag++;
            [boardsMenu addItem:currentItem];
        }
    }
     */
}

- (void)setCardMember:(id)sender
{
    XTMenuItem *menuItem = (XTMenuItem *)sender;
    NSString *realValue = [menuItem realValue];
    NSInteger state = menuItem.state;
    if (state == 0)
    {
        NSMutableArray *currentLabels = [[[self cardDict] valueForKey:@"idMembers"] mutableCopy];
        [currentLabels addObject:realValue];
        
        [[XTTrelloWrapper sharedInstance] addMemberId:realValue toCard:self.cardDict inBoardNamed:self.boardName];
        
    } else {
        
        NSMutableArray *currentLabels = [[[self cardDict] valueForKey:@"labels"] mutableCopy];
        [currentLabels removeObject:realValue];
        
        [[XTTrelloWrapper sharedInstance] removeMemberId:realValue fromCard:self.cardDict inBoardNamed:self.boardName];
    }
    
    if (state == 0) state = 1;
    if (state == 1) state = 0;
    [menuItem setState:state];
    
    [self delegateRefreshList];
    
}

- (NSMenu *)memberSubmenu
{
    NSMenu *membersSubmenu = [[NSMenu alloc] initWithTitle:@""];
    NSArray *memberArray = [[[XTTrelloWrapper sharedInstance] boardNamed:self.boardName] valueForKey:@"members"];
    for (NSDictionary *currentMember in memberArray)
    {
        
        XTMenuItem *memberMenuItem = [[XTMenuItem alloc] initWithTitle:currentMember[@"fullName"] action:@selector(setCardMember:) keyEquivalent:@""];
        
        [memberMenuItem setRealValue:currentMember[@"id"]];
        
        if ([self containsMemberId:currentMember[@"id"]])
        {
            [memberMenuItem setState:1];
        }
        [membersSubmenu addItem:memberMenuItem];
        
    }
    return membersSubmenu;
    
}


- (NSMenu *)colorSubmenu
{
    NSMenu *labelsSubmenu = [[NSMenu alloc] initWithTitle:@""];
 //   NSDictionary *labelArray = [[[XTTrelloWrapper sharedInstance] boardNamed:self.boardName] valueForKey:@"labelNames"];
    NSArray *labelArray = [[[XTTrelloWrapper sharedInstance] boardNamed:self.boardName] valueForKey:@"labels"];
    //  NSLog(@"### labelArray: %@", labelArray);
    NSEnumerator *colorEnum = [labelArray objectEnumerator];
    id theColor = nil;
    int labelTag = 0;
    while(theColor = [colorEnum nextObject])
    {
        NSString *currentColor = theColor[@"color"];
        NSMutableDictionary *attrs = [[NSMutableDictionary alloc] init];
        NSColor *ourColor = [currentColor colorFromName];
        if (ourColor != nil)
            [attrs setObject:[currentColor colorFromName] forKey:NSForegroundColorAttributeName];
        else
            NSLog(@"why is this color nil??: %@", theColor);
        [attrs setObject:[NSColor blackColor] forKey:NSStrokeColorAttributeName];
        [attrs setObject:[NSString stringWithFormat:@"%f", -3.0f] forKey:NSStrokeWidthAttributeName];
        [attrs setObject:[NSFont menuFontOfSize:14] forKey:NSFontAttributeName];
        NSString *labelNamePlain = theColor[@"name"];
        //  NSString *labelNamePlain = [labelArray objectForKey:theColor];
        if (labelNamePlain.length == 0)
        {
            labelNamePlain = currentColor;
        }
        NSAttributedString *labelName = [[NSAttributedString alloc] initWithString:labelNamePlain attributes:attrs];
        XTMenuItem *currentLabel = [[XTMenuItem alloc] init];
        [currentLabel setAttributedTitle:labelName];
        [currentLabel setAction:@selector(setCardLabels:)];
        [currentLabel setRealValue:currentColor];
        [currentLabel setTag:labelTag];
        if ([self containsLabel:currentColor])
        {
            [currentLabel setState:1];
        }
        [labelsSubmenu addItem:currentLabel];
        labelTag++;
    }
    return labelsSubmenu;
    
}

- (void)jumpToCode:(id)sender
{
    [[self delegate] jumpToCode:self.cardDict];
}

- (void)setupMenu
{
    context = [[NSMenu alloc] initWithTitle:@""];
    listsMenu = [[NSMenu alloc] initWithTitle:@""];
    boardsMenu = [[NSMenu alloc] initWithTitle:@""];
    NSMenuItem *setLabelsMenu = [[NSMenuItem alloc] initWithTitle:@"Set Labels" action:nil keyEquivalent:@""];
    NSMenu *labelsSubmenu = [self colorSubmenu];
    [setLabelsMenu setSubmenu:labelsSubmenu];
    [context addItem:setLabelsMenu];
    
    NSMenuItem *setMembers = [[NSMenuItem alloc] initWithTitle:@"Set Members" action:nil keyEquivalent:@""];
    
    [setMembers setSubmenu:[self memberSubmenu]];
    
    [context addItem:setMembers];
    
    listsMenu = [[NSMenu alloc] initWithTitle:@""];
    [self populateLists];
    NSMenuItem *changeListMenu = [[NSMenuItem alloc] initWithTitle:@"Move to List" action:nil keyEquivalent:@""];
    [changeListMenu setSubmenu:listsMenu];
    [context addItem:changeListMenu];
    
    NSMenuItem *changeBoardMenu = [[NSMenuItem alloc] initWithTitle:@"Move to Board" action:nil keyEquivalent:@""];
    [changeBoardMenu setSubmenu:boardsMenu];
    [context addItem:changeBoardMenu];
    
    
    NSMenuItem *jumpToCode = [[NSMenuItem alloc] initWithTitle:@"Jump to code..." action:@selector(jumpToCode:) keyEquivalent:@""];
    [context addItem:jumpToCode];
    
    NSMenuItem *addCardItem = [[NSMenuItem alloc] initWithTitle:@"Add Card..." action:@selector(addCard:) keyEquivalent:@""];
    [context addItem:addCardItem];
    
    NSMenuItem *deleteCardItem = [[NSMenuItem alloc] initWithTitle:@"Delete Card..." action:@selector(deleteCard:) keyEquivalent:@""];
    [context addItem:deleteCardItem];
    
}

- (void)addCard:(id)sender
{
    [[self delegate] addNewCard:self];
}

- (void)rightMouseDown:(NSEvent *)theEvent
{
    [NSMenu popUpContextMenu:context withEvent:theEvent forView:self];
    
}

// Respond to clicks within text fields only, because other clicks will be duplicates of events passed to mouseDown
- (void)mouseDownForTextFields:(NSEvent *)theEvent {
    // If shift or command are being held, we're selecting rows, so ignore
    if ((NSCommandKeyMask | NSShiftKeyMask) & [theEvent modifierFlags]) return;
    if ( NSControlKeyMask & [theEvent modifierFlags])
    {
        [self rightMouseDown:theEvent];
        return;
    }
    
    NSPoint selfPoint = [self convertPoint:theEvent.locationInWindow fromView:nil];
    for (NSView *subview in [self subviews])
    {
        if ([subview isKindOfClass:[NSTextField class]])
        {
            if (NSPointInRect(selfPoint, [subview frame]))
            {
                [(NSTextField *)subview setEditable:TRUE];
                [(NSTextField *)subview setBordered:TRUE];
                [[self window] makeFirstResponder:subview];
                
            }
        }
    }
}

- (void)setupView
{
    if (_dividerView != nil)
    {
        [_dividerView removeFromSuperview];
        _dividerView = nil;
    }
    

    NSRect listItemFrame = self.frame;
    listItemFrame.origin.y = 0;
    listItemFrame.origin.x = -5;
    listItemFrame.size.width = listItemFrame.size.width + 10;
    listItemFrame.size.height = 5;
    
    _dividerView = [[XTTagView alloc] initWithFrame:listItemFrame andColor:[NSColor lightGrayColor]];
    [self addSubview:_dividerView];
    
    [self setupMenu];
    
}

- (void)setLabels:(NSArray *)theLabels {
    
    LOG_SELF;
}

@end
