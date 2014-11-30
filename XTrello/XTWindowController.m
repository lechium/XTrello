//
//  XTWindowController.m
//  XTrello
//
//  Created by Kevin Bradley on 7/14/14.
//  Copyright (c) 2014 Kevin Bradley. All rights reserved.
//

#import "XTWindowController.h"
#import "XTModel.h"
#import <AppKit/NSApplication.h>
@interface XTWindowController ()

@end

@implementation XTWindowController

@synthesize currentBoard, windowTwo;


- (void)windowWillClose:(NSNotification *)notification
{
  //  NSLog(@"windowWillClose: %@", notification);
    NSWindow *closedWindow = [notification object];
    NSInteger windowTag = 0;
    if (closedWindow == self.window)
    {
        windowTag = 1;
    }
    
    if (closedWindow == windowTwo)
    {
        windowTag = 2;
    }
    
    if (closedWindow == prefWindow)
    {
        windowTag = 3;
    }
    
    [[self delegate] removeItemForWindowTag:windowTag];
}

- (void)awakeFromNib
{
    [listTableView setTarget:self];
    [listTableView setDoubleAction:@selector(doubleClick:)];
}

- (void)doubleClick:(id)object {
  
    NSInteger rowNumber = [listTableView clickedRow];

    NSDictionary *cardDict = [currentCardList objectAtIndex:rowNumber];
    NSURLRequest *theRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:cardDict[@"shortUrl"]]];
    [[webView mainFrame] loadRequest:theRequest];
    [windowTwo makeKeyAndOrderFront:nil];
    [[self delegate] addItemForWindowTag:2];
    
}

//open any links in default browser

- (void)webView:(WebView *)webView decidePolicyForNewWindowAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request newFrameName:(NSString *)frameName decisionListener:(id<WebPolicyDecisionListener>)listener
{
    LOG_SELF;
    NSLog(@"actionInfo: %@ request: %@", actionInformation, request);
    [listener use];
    [[NSWorkspace sharedWorkspace] openURL:request.URL];
    /*
     NSHTTPURLResponse *theResponse = nil;
     NSData *returnData = [NSURLConnection sendSynchronousRequest:request returningResponse:&theResponse error:nil];
     NSString *datString = [[NSString alloc] initWithData:returnData  encoding:NSUTF8StringEncoding];
     
     */
}

/*
 
 tried to implement this to control linnks being clicked to open in a new default browser window (rather than in our custom browser window) 
 everything registers as "other" for nav type
 
 7/16/14 2:15:00.219 PM Xcode[21593]: actionInfo: {
 WebActionModifierFlagsKey = 0;
 WebActionNavigationTypeKey = 5; //other... absolutely USELESS.
 WebActionOriginalURLKey = "https://github.com/bnickel/KIFBackgrounding";
 } request: <NSMutableURLRequest: 0x7fc6286e6240> { URL: https://github.com/bnickel/KIFBackgrounding }
*/


- (void)webView:(WebView *)aWebView
decidePolicyForNavigationAction:(NSDictionary *)actionInformation
        request:(NSURLRequest *)request
          frame:(WebFrame *)frame
decisionListener:(id < WebPolicyDecisionListener >)listener
{
    LOG_SELF;// WebNavigationTypeFormSubmitted
    WebNavigationType typeKey = [actionInformation[@"WebActionNavigationTypeKey"] intValue];
    if (typeKey == WebNavigationTypeFormSubmitted)
    {
        NSHTTPURLResponse *theResponse = nil;
        NSData *returnData = [NSURLConnection sendSynchronousRequest:request returningResponse:&theResponse error:nil];
        NSString *datString = [[NSString alloc] initWithData:returnData  encoding:NSUTF8StringEncoding];
      //  NSLog(@"datString: %@", datString);
        NSError *error = nil;
        NSXMLDocument *document = [[NSXMLDocument alloc] initWithXMLString:datString options:NSXMLDocumentTidyHTML error:&error];
        NSXMLElement *root = [document rootElement];
       // NSLog(@"root: %@", root);
        NSString *token=[[[[root objectsForXQuery:@"//pre" error:&error]objectAtIndex:0] stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (token.length != 0)
        {
            [UD setObject:token forKey:kXTrelloAuthToken];
        }
        // NSLog(@"token: -%@-", token);
    }
    
    //check to see if we are trying to generate / fetch API key.
    
    NSURL *key = actionInformation[@"WebActionOriginalURLKey"];
    if ([[key absoluteString] isEqualToString:@"https://trello.com/1/appKey/generate"])
    {
        NSHTTPURLResponse *theResponse = nil;
        NSData *returnData = [NSURLConnection sendSynchronousRequest:request returningResponse:&theResponse error:nil];
        NSString *datString = [[NSString alloc] initWithData:returnData  encoding:NSUTF8StringEncoding];
       //   NSLog(@"datString: %@", datString);
        NSError *error = nil;
        NSXMLDocument *document = [[NSXMLDocument alloc] initWithXMLString:datString options:NSXMLDocumentTidyHTML error:&error];
        NSXMLElement *root = [document rootElement];
        NSArray *inputNodes = [root nodesForXPath:@"//div[@class='account-content clearfix']/p/input[1]" error:nil];
        //NSLog(@"inputNodeS: %@", inputNodes);
        if (inputNodes.count > 0)
        {
            NSXMLElement *inputNode = [inputNodes objectAtIndex:0];
            ;
            NSString *apiKey = [[inputNode attributeForName:@"value"] stringValue];
            NSLog(@"apikey: %@", apiKey);
            if (apiKey.length > 0)
            {
                [UD setObject:apiKey forKey:kXTrelloAPIKey];
            }
        }
        
    }
    
  //  NSLog(@"actionInfo: %@ request: %@", actionInformation, request);
    [listener use];
}
 

//- (WebView *)webView:(WebView *)sender createWebViewWithRequest:(NSURLRequest *)request
//{
//    //tried to make it open in default browser here, but URL is nul... so dumb.
//   // LOG_SELF;
//   // NSLog(@"request: %@", request);
//    //[[NSWorkspace sharedWorkspace] openURL:request.URL];
//    return webView;
//}
//- (void)webViewShow:(WebView *)sender
//{
//    LOG_SELF;
//    NSLog(@"initialRequest: %@", sender.mainFrame.dataSource.initialRequest);
//    NSLog(@"request: %@", sender.mainFrame.dataSource.request);
//}
//- (void)webViewRunModal:(WebView *)sender
//{
//    LOG_SELF;
//}
//- (void)webViewClose:(WebView *)sender
//{
//    LOG_SELF;
//}
//- (void)webViewFocus:(WebView *)sender
//{
//    LOG_SELF;
//}
//
//- (void)webViewUnfocus:(WebView *)sender
//{
//    LOG_SELF;
//}
////- (NSResponder *)webViewFirstResponder:(WebView *)sender
//- (void)webView:(WebView *)sender makeFirstResponder:(NSResponder *)responder
//{
//    LOG_SELF;
//}
//- (void)webView:(WebView *)sender setStatusText:(NSString *)text
//{
//    LOG_SELF;
//}
////- (NSString *)webViewStatusText:(WebView *)sender
////- (BOOL)webViewAreToolbarsVisible:(WebView *)sender
//
//- (void)webView:(WebView *)sender setToolbarsVisible:(BOOL)visible
//{
//    LOG_SELF;
//}
//- (void)webView:(WebView *)sender setFrame:(NSRect)frame
//{
//    LOG_SELF;
//}
//- (void)webView:(WebView *)sender mouseDidMoveOverElement:(NSDictionary *)elementInformation modifierFlags:(NSUInteger)modifierFlags
//{
//    //LOG_SELF;
//}
//- (void)webView:(WebView *)sender didStartProvisionalLoadForFrame:(WebFrame *)frame
//{
//    LOG_SELF;
//}
//
//-(void)webView:(WebView *)sender didFailProvisionalLoadWithError:(NSError *)error forFrame:(WebFrame *)frame
//{
//        LOG_SELF;
//}
//
//- (void)webView:(WebView *)sender didReceiveTitle:(NSString *)title forFrame:(WebFrame *)frame
//{
//        LOG_SELF;
//}
//- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
//{
//        LOG_SELF;
//}


- (NSString *)firstListName
{
    NSArray *lists = [[[XTTrelloWrapper sharedInstance] boardNamed:currentBoard] objectForKey:@"lists"];
    return [[lists objectAtIndex:0] valueForKey:@"name"];
}

- (int)boardCount
{
    return [[boardArrayController arrangedObjects] count];
}

- (void)setBoardArrayContent:(NSArray *)boardArray
{
    [boardArrayController setContent:boardArray];
    NSArray *lists = [[[XTTrelloWrapper sharedInstance] boardNamed:currentBoard] objectForKey:@"lists"];
    [boardListController setContent:lists];
}

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        // Initialization code here.
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    NSColor *greyColor = [NSColor lightGrayColor];
    self.window.backgroundColor = greyColor;
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kXTrelloFloatingWindow] == TRUE)
    {
        self.window.level = NSFloatingWindowLevel;
    } else {
        self.window.level = NSNormalWindowLevel;
    }
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

- (void)windowDidBecomeKey:(NSNotification *)notification
{
    NSWindow *keyWindow = [notification object];
    if (keyWindow == self.window)
    {
        if ([[NSUserDefaults standardUserDefaults] boolForKey:kXTrelloFloatingWindow] == TRUE)
        {
            self.window.level = NSFloatingWindowLevel;
        } else {
            self.window.level = NSNormalWindowLevel;
        }
    }
}


- (void)rowChanged:(NSNotification *)n
{
    NSLog(@"rowChanged: %@", [n object]);
  //  NSInteger selectedRow = [(NSTableView *)[n object] selectedRow];
    //NSDictionary *cardDict = [currentCardList objectAtIndex:selectedRow];

}

- (void)dataReloaded
{
    [self populateCardsFromListNamed:currentList inBoard:currentBoard];
}

- (IBAction)helpButtonPressed:(id)sender
{
    NSAlert *missingAPIKeyAlert = [NSAlert alertWithMessageText:@"Trello API Key" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"To get the trello API key you need to generate it on trellos website. If it isn't set automatically you will need to copy any paste it from the next screen."];
    [missingAPIKeyAlert runModal];
    NSURLRequest *theRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:@"https://trello.com/1/appKey/generate"]];
    [[webView mainFrame] loadRequest:theRequest];
    [windowTwo makeKeyAndOrderFront:nil];
    [[self delegate] addItemForWindowTag:2];
    
   // [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://trello.com/1/appKey/generate"]];
    //[apiKeyField becomeFirstResponder];
}

- (IBAction)refresh:(id)sender
{
    [[XTTrelloWrapper sharedInstance] reloadTrelloData];
}

- (void)selectBoardNamed:(NSString *)boardName
{
    NSLog(@"boardName: %@", boardName);
    
    NSArray *lists = [[[XTTrelloWrapper sharedInstance] boardNamed:boardName] objectForKey:@"lists"];
    
    if (lists == nil) return;
    
    currentBoard = boardName;

   // NSLog(@"lists: %@", lists);
    NSString *firstListName = [[lists objectAtIndex:0] valueForKey:@"name"];
    currentList = firstListName;
    [boardListController setContent:lists];
    [self populateCardsFromListNamed:firstListName inBoard:boardName];
    [boardPopup selectItemWithTitle:boardName];
}

- (IBAction)boardSelected:(id)sender
{
    NSString *theTitle = [[(NSPopUpButton *)sender selectedItem] title];
    currentBoard = theTitle;
    [self selectBoardNamed:currentBoard];
}

- (IBAction)listSelected:(id)sender
{
    NSString *theTitle = [[(NSPopUpButton *)sender selectedItem] title];
    currentList = theTitle;
    [self populateCardsFromListNamed:theTitle inBoard:currentBoard];
}

- (void)populateCardsFromListNamed:(NSString *)listName inBoard:(NSString *)boardName
{
    XTTrelloWrapper *wrapper = [XTTrelloWrapper sharedInstance];
    currentCardList = [wrapper cardsFromListWithName:listName inBoard:boardName];
    [listTableView reloadData];
    [listTableView setNeedsDisplay];
    
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row
{
    return 100.0;
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

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    NSFont *labelFont = [NSFont systemFontOfSize:12];
   // NSFont *labelFont = [NSFont fontWithName:@"Helvetica" size:12];
    NSString *cardName = [[currentCardList objectAtIndex:row] valueForKey:@"name"];
    CGFloat cardNameHeight = [cardName heightForStringWithFont:labelFont withWidth:280] + 10;
    CGFloat cardNameOriginY = (100.0 - cardNameHeight)/2;
  //  NSLog(@"card Size: %f", cardNameHeight);
    XTTrelloCardView *listItem = [tableView makeViewWithIdentifier:@"trelloCardView" owner:self];
    NSInteger tagNumber = row;
    NSRect listItemFrame = listItem.frame;
    listItemFrame.origin.y = 0;
    listItemFrame.origin.x = -5;
    listItemFrame.size.width = listItemFrame.size.width + 10;
    listItemFrame.size.height = 5;
    NSArray *labels = [[currentCardList objectAtIndex:row] valueForKey:@"labels"];
    if (listItem.tagViewController != nil)
    {
        [listItem.tagViewController removeFromSuperview];
    }
    listItem.tagViewController = [[XTTagViewController alloc] initWithFrame:NSMakeRect(4, 90, 264, 10) andLabels:[self usefulLabelArray:labels]];
    listItem.boardName = currentBoard;
    [listItem addSubview:listItem.tagViewController];
    CGRect nameFrame = listItem.titleView.frame;
    listItem.titleView.tag = tagNumber;
    listItem.titleView.stringValue = cardName;
    nameFrame.size.height = cardNameHeight;
    nameFrame.origin.y = cardNameOriginY;
    nameFrame.size.width = 290;
    listItem.titleView.frame = nameFrame;
    listItem.listName = currentList;
    listItem.cardDict = [currentCardList objectAtIndex:row];
    listItem.delegate = self;
    [listItem setupView];
    if (editingRow == row)
    {
        [listItem performSelector:@selector(editText) withObject:nil afterDelay:0.1];
        editingRow = -1;
        
    }
  
    return listItem;
}

- (void)delayedResignFirstResponder
{
    [self performSelector:@selector(rfr:) withObject:nil afterDelay:.1];
}

- (void)rfr:(id)sender
{
    [listTableView resignFirstResponder];
    //id firstResponder = self.window.firstResponder;
    //NSLog(@"firstResponder: %@", firstResponder);
   // [firstResponder performSelectorOnMainThread:@selector(resignFirstResponder) withObject:nil waitUntilDone:false];
    // [self.window.firstResponder resignFirstResponder];
}



+ (void)highlightItem:(XTrelloItem*)item inTextView:(NSTextView*)textView
{
    
    NSUInteger lineNumber = item.lineNumber - 1;
    NSString* text = [textView string];
    
    //NSString *itemContents = item.content;
    
    
//    NSRange rangeOfString = [text rangeOfString:itemContents];
//    NSRange newRange = [text lineRangeForRange:NSMakeRange(location, 0)];
//    
//    [textView scrollRangeToVisible:range];
//    
//    [textView setSelectedRange:range];
//    
//    
//    return;
//    
    
    NSRegularExpression* re =
    [NSRegularExpression regularExpressionWithPattern:@"\n"
                                              options:0
                                                error:nil];
    
    NSArray* result = [re matchesInString:text
                                  options:NSMatchingReportCompletion
                                    range:NSMakeRange(0, text.length)];
    
 //   NSLog(@"%@", result);
    
    if (result.count <= lineNumber) {
        return;
    }
    
    NSUInteger location = 0;
    NSTextCheckingResult* aim = result[lineNumber];
    location = aim.range.location;
    
    NSRange range = [text lineRangeForRange:NSMakeRange(location, 0)];
    
    [textView scrollRangeToVisible:range];
    
    [textView setSelectedRange:range];
}

+ (BOOL)openItem:(XTrelloItem *)item
{
    if (item.filePath == nil) return FALSE;
   // NSWindowController* currentWindowController = [[NSApp mainWindow] windowController];
    
   // NSLog(@"currentWindowController %@",[currentWindowController description]);
    
   // if ([currentWindowController
     //    isKindOfClass:NSClassFromString(@"IDEWorkspaceWindowController")]) {
        
        // NSLog(@"Open in current Xcode");
        id<NSApplicationDelegate> appDelegate = (id<NSApplicationDelegate>)[NSApp delegate];
        if ([appDelegate application:NSApp openFile:item.filePath]) {
    //    if ([[NSApp delegate] application:NSApp openFile:item.filePath]) {
            
            IDESourceCodeEditor* editor = [XTModel currentEditor];
            if ([editor isKindOfClass:NSClassFromString(@"IDESourceCodeEditor")]) {
                NSTextView* textView = editor.textView;
                if (textView) {
                    
                    [self highlightItem:item inTextView:textView];
                    
                    return YES;
                }
            }
        }
    //}
    
    // open the file
    BOOL result = [[NSWorkspace sharedWorkspace] openFile:item.filePath
                                          withApplication:@"Xcode"];
    
    // open the line
    if (result) {
        
        // pretty slow to open file with applescript
        
        NSString* theSource = [NSString
                               stringWithFormat:
                               @"do shell script \"xed --line %ld \" & quoted form of \"%@\"",
                               item.lineNumber, item.filePath];
        NSAppleScript* theScript = [[NSAppleScript alloc] initWithSource:theSource];
        [theScript performSelectorInBackground:@selector(executeAndReturnError:)
                                    withObject:nil];
        
        return NO;
    }
    
    return result;
}

- (void)jumpToCode:(NSDictionary *)codeDict
{
    NSLog(@"codeDict desc: %@", codeDict[@"desc"]);
    if ([codeDict[@"desc"] length] == 0)
        return;
    XTrelloItem *newItem = [[XTrelloItem alloc] initWithString:codeDict[@"desc"]];
    [XTWindowController openItem:newItem];
}

/**
 
 generates the session token we use to access trello data.
 
 */

- (IBAction)generateToken:(id)sender
{
    NSString *apiKey = [UD objectForKey:kXTrelloAPIKey];
    if (apiKey != nil) {
        NSString *generateString = [NSString stringWithFormat:@"https://trello.com/1/authorize?key=%@&name=XTrello&expiration=never&response_type=token&scope=read,write", apiKey];
      
        NSURLRequest *theRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:generateString]];
        [[webView mainFrame] loadRequest:theRequest];
        [windowTwo makeKeyAndOrderFront:nil];
        [[self delegate] addItemForWindowTag:2];
        //  [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:generateString]];
    } else {
        NSLog(@"MISSING API KEY!");
        NSAlert *missingAPIKeyAlert = [NSAlert alertWithMessageText:@"Missing Trello API Key" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"You are missing a Trello API key, this needs to be set before you can generate a new session token!"];
        [missingAPIKeyAlert runModal];
        NSURLRequest *theRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:@"https://trello.com/1/appKey/generate"]];
        [[webView mainFrame] loadRequest:theRequest];
        [windowTwo makeKeyAndOrderFront:nil];
        [[self delegate] addItemForWindowTag:2];
        //[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://trello.com/1/appKey/generate"]];
        //[apiKeyField becomeFirstResponder];
    }
}

- (IBAction)showPreferences:(id)sender
{
    NSLog(@"show prefs: %@", prefWindow);
    [prefWindow makeKeyAndOrderFront:nil];
}

- (IBAction)addNewCard:(id)sender
{
    NSInteger newCardCount = [currentCardList count];
    editingRow = newCardCount;
    [[XTTrelloWrapper sharedInstance] addCardToBoard:currentBoard inList:currentList withName:@"New Note"];
    [self populateCardsFromListNamed:currentList inBoard:currentBoard];
    float y =  listTableView.frame.size.height - [[listTableView enclosingScrollView] contentView].frame.size.height ;
    [[[listTableView enclosingScrollView] verticalScroller] setFloatValue:0.0];
    [[[listTableView enclosingScrollView] contentView] scrollToPoint:NSMakePoint(0.0, y)];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return [currentCardList count];
}

- (NSString *)currentSourceFileName
{
    IDESourceCodeDocument *currentDoc = [XTModel currentSourceCodeDocument];
    Xcode3FileReference *knownFileRef = [[currentDoc knownFileReferences] lastObject];
    if ([knownFileRef respondsToSelector:@selector(fileReference)])
    {
        PBXFileReference *fileRef = [knownFileRef fileReference];
        if ([fileRef respondsToSelector:@selector(name)])
        {
            return [fileRef name];
        }
    }
    return nil;
}


- (PBXFileReference *)currentSourceFile
{
    IDESourceCodeDocument *currentDoc = [XTModel currentSourceCodeDocument];
    Xcode3FileReference *knownFileRef = [[currentDoc knownFileReferences] lastObject];
    if ([knownFileRef respondsToSelector:@selector(fileReference)])
    {
        PBXFileReference *fileRef = [knownFileRef fileReference];
        if ([fileRef respondsToSelector:@selector(name)])
        {
            return fileRef;
        }
    }
    return nil;
}



- (NSString *)currentProjectName
{
    return [XTModel currentProjectName];
}

- (void)newCardFromMenu:(id)sender
{
    NSString *fileName = [self currentSourceFileName];
    NSString *fileDesc = [NSString stringWithFormat:@"%@:%li", fileName, self.selectedLineNumber];
    PBXFileReference *currentSourceFile = [self currentSourceFile];
    NSString *theBoard = [XTModel currentProjectName];
    NSLog(@"theBoard: %@", theBoard);
    NSLog(@"currentSourceFile: %@", currentSourceFile);
    
    if (theBoard == nil || currentSourceFile == nil)
    {
        NSLog(@"DEM CATZ BE NIL, TRY AGAIN!!");
        return;
    }
    // NSLog(@"path: %@ absPath: %@", currentSourceFile.path, currentSourceFile.absolutePath );
    NSString *currentBranch = [XTModel currentGITBranch];
    if (currentBranch == nil)
        currentBranch = @"";
    
  
    
    NSString *newDesc = [NSString stringWithFormat:@"%@\nbranch:%@\nline:%li\n%@", [currentSourceFile.absolutePath tildePath], currentBranch, self.selectedLineNumber, self.focalText];
 
    
    [[XTTrelloWrapper sharedInstance] addCardToBoard:theBoard inList:[self firstListName] withName:fileDesc withDescription:newDesc];
    [self populateCardsFromListNamed:currentList inBoard:currentBoard];
    if(!self.window.isVisible)
    {
        [self.window makeKeyAndOrderFront:nil];
    }
    
    [self selectBoardNamed:theBoard];

    float y =  listTableView.frame.size.height - [[listTableView enclosingScrollView] contentView].frame.size.height ;
    [[[listTableView enclosingScrollView] verticalScroller] setFloatValue:0.0];
    [[[listTableView enclosingScrollView] contentView] scrollToPoint:NSMakePoint(0.0, y)];
    

    NSInteger newRowIndex = currentCardList.count - 1;
    
    NSLog(@"tag: %li theView: %@", newRowIndex, [listTableView viewWithTag:newRowIndex]  );
    NSView *textView = [listTableView viewWithTag:newRowIndex];
    if ([textView respondsToSelector:@selector(setEditable:)])
    {
       // NSLog(@"textView string: %@", [(NSTextField *)textView stringValue]);
        [(NSTextField *)textView setEditable:TRUE];
        [(NSTextField *)textView setBordered:TRUE];
        [[self window] makeFirstResponder:textView];
    }
   
}

/*
 
 2014-07-14T19:00:00.000Z
 
 07-04-2014T12 oclock
 
 */

- (NSString *)dateTest
{
    NSDate *theDate = [NSDate date];
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    [df setTimeZone:[NSTimeZone timeZoneWithName:@"UTC"]];
    [df setDateFormat:NEW_DATE_FORMAT];
    NSString *dayFormatted = [df stringFromDate:theDate];
    [df setDateFormat:HOUR_FORMAT];
    NSString *hourFormatted = [df stringFromDate:theDate];
    NSString *formatString = [NSString stringWithFormat:@"%@T%@.000Z", dayFormatted, hourFormatted];
    NSLog(@"dateTest: %@", formatString);
    return formatString;
}



@end
