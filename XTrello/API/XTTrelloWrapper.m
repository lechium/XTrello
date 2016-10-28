//
//  XTTrelloWrapper.m
//  XTrello
//
//  Created by Kevin Bradley on 7/10/14.
//  Copyright (c) 2014 Kevin Bradley. All rights reserved.
//

/*
 
 brain food
 
 http://www.sqlservercentral.com/blogs/rocks/2012/03/14/creating-cards-in-trello-via-the-rest-api-and-parsing-the-returned-json-all-in-a-sql-clr/
 
 http://www.trello.org/help.html
 
 https://trello.com/docs/index.html
 
 
 this initial datamodel setup is admittedly an ugly hack and not my best code. i initially put this together as a POC
 project that i was potentially only planning on using internally with other developers that i work directly with
 
 the data is kept track of in here AND in the XTrello.m main class (which is obviously dumb)
 there are some wonky issues with reloading data in the window controller which lead me to create two different methods
 for initial load and updating the data, the "reasoning" behind this decision was we don't want it to reload
 the initial data and choose the first index board/list every time a refresh occurs. this could be very annoying 
 for the end user, but then there could be a new board / list / whatever created on the trello web side or other native
 apps so that needs to be accounted for without quitting and re-opening.
 
 in the end a lot of the datamodel concept should be scrapped in favor of something more robust like core data.
 
 
 */

#import "XTTrelloWrapper.h"
#import "NSDate+trelloAdditions.h"

@implementation XTTrelloWrapper

@synthesize trelloData, apiKey, sessionToken, baseURL, delegate, dataReady, reloading;

+ (id)sharedInstance
{
    static XTTrelloWrapper *sharedManager = nil;
    if (sharedManager == nil)
    {
        sharedManager = [[XTTrelloWrapper alloc] init];
        sharedManager.reloading = FALSE;
        sharedManager.dataReady = FALSE;
    }
    return sharedManager;
}


//https://api.trello.com/1/members/me/boards?key=KEY&token=TOKEN
//https://trello.com/1/members/me?key=KEY&token=TOKEN
//https://trello.com/1/members/my/cards?key=KEY&token=TOKEN

/**
 
 currently the trello local data is stored in a plist file in ~/Library/Application Support/XTrello/trelloBoards.plist
 
 this should only be called upon initial launch to load this prior data while we are 
 fetching the latest data from trello API directly.
 
 
 */

- (void)loadPreviousData
{
    if ([[NSFileManager defaultManager] fileExistsAtPath:[XTModel boardsDataStoreFile]])
    {
        NSDictionary *cachedData = [NSDictionary dictionaryWithContentsOfFile:[XTModel boardsDataStoreFile]];
        trelloData = [cachedData mutableCopy];
        [delegate setInitialData:trelloData];
    }
}

#pragma mark convenience data fetching methods

/*
 
 when fetching JSON data the trello API fills any empty keys with "null" which converts to <null> ([NSNull null])
 this cycles through an array of dictionaries and creates a new array free from nulls, if we don't do this
 we can't save the dictionary representation of the JSON output into a plist file.
 
 */

- (NSArray *)nullReplacedArray:(NSArray *)inputArray
{
    NSMutableArray *newArray = [[NSMutableArray alloc] init];
    for (NSDictionary *currentDictionary in inputArray)
    {
        NSDictionary *newDict = [currentDictionary dictionaryByReplacingNullsWithStrings];
        [newArray addObject:newDict];
    }
    return newArray;
}

/**
 
 99% of the time (with most of the API that i've wrapped natively) trello returns a JSON response. we take 
 this response and conver it into a useful NSDictionary / NSArray. for the most part
 this response is never processed to check for errors or anything. put it on the TODO list!
 
 */


- (NSDictionary *)dictionaryFromJSONStringResponse:(NSString *)theString
{
    //idiot proofing from when i wasn't changing this to a dict
    if ([theString respondsToSelector:@selector(allKeys)]) return (NSDictionary *)theString;
    
    
    id newJSONObject = [NSJSONSerialization JSONObjectWithData:[theString dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
    id returnObject = newJSONObject;
    if ([newJSONObject respondsToSelector:@selector(allKeys)]) //dealing with a dictionary
    {
        returnObject = [newJSONObject dictionaryByReplacingNullsWithStrings];
        
        if (returnObject == nil)
        {
            returnObject = newJSONObject;
        }
        
    } else if ([theString respondsToSelector:@selector(count)]){ //otherwise it SHOULD be an array...
        
        returnObject = [self nullReplacedArray:newJSONObject];
    }
    return returnObject;
    
}

/*
 
 meat and potatoes, it takes in a URL string, gets it as raw UTF8 string data, converts to JSON, strips out NSNull from all
 dictionaries and arrays, and returns the results NSArray or NSDictionary
 
 */

- (NSDictionary *)dictionaryFromURLString:(NSString *)theString
{
    id newJSONObject = [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfURL:[NSURL URLWithString:theString]] options:0 error:nil];
    id returnObject = newJSONObject;
    if ([newJSONObject respondsToSelector:@selector(allKeys)]) //dealing with a dictionary
    {
        returnObject = [newJSONObject dictionaryByReplacingNullsWithStrings];
        
        if (returnObject == nil)
        {
            returnObject = newJSONObject;
        }
        
    } else { //otherwise it SHOULD be an array...
        
        returnObject = [self nullReplacedArray:newJSONObject];
    }
    return returnObject;
    
}



#pragma mark trelloData convenience methods

//obsolete, the label code setup has changed drastically on trellos end to support more custom colors.

- (NSArray *)usefulLabelArray:(NSArray *)labelArray
{
    NSMutableArray *newArray = [[NSMutableArray alloc] init];
    for (NSDictionary *labelDict in labelArray)
    {
        [newArray addObject:labelDict[@"color"]];
    }
    return newArray;
}


/*
 
 most of the methods in this area are our convenience methods for handling the local data, each 
 one of these are the only ones we generally ever call directly, inside each method that uses 
 ID's rather than names it generally interacts directly with the trello API after updating our
 local datamodel.
 
 most of the method names should be self explanatory so im not going to document each one unless i think
 it is merited
 
 */

- (NSDictionary *)addCardToBoard:(NSString *)boardName inList:(NSString *)listName withName:(NSString *)cardName
{
    return [self addCardToBoard:boardName inList:listName withName:cardName inPosition:nil];
}


- (NSDictionary *)deleteCard:(NSDictionary *)theCard inBoardNamed:(NSString *)boardName
{
    NSMutableDictionary *boardDict = [[self boardNamed:boardName] mutableCopy];
    NSMutableArray *cards = [[boardDict valueForKey:@"cards"] mutableCopy];
    NSString *cardID = theCard[@"id"];
    
    [self deleteCardWithID:cardID]; //trello API call
    
    //local data update
    
    [cards removeObject:theCard];
    [boardDict setObject:cards forKey:@"cards"];
    [[self.trelloData objectForKey:@"boards"] setObject:boardDict forKey:boardName];
    
    [self.trelloData writeToFile:[XTModel boardsDataStoreFile] atomically:TRUE];
    
    return trelloData;
}

- (NSDictionary *)moveCard:(NSDictionary *)theCard fromBoardNamed:(NSString *)oldBoardName toBoardNamed:(NSString *)boardName toListNamed:(NSString *)listName
{
    NSLog(@"move card: %@ from board: %@ to board: %@ in list: %@", theCard[@"name"], oldBoardName, boardName, listName );
    NSMutableDictionary *oldBoardDict = [[self boardNamed:oldBoardName] mutableCopy];
    NSMutableDictionary *newBoardDict = [[self boardNamed:boardName] mutableCopy];

    NSPredicate *filterPredicate = [NSPredicate predicateWithFormat:@"(SELF.name == %@)", listName];
    NSDictionary *newList = [[[newBoardDict valueForKey:@"lists"] filteredArrayUsingPredicate:filterPredicate] lastObject];
    
  //  NSLog(@"newList: %@", newList);
    
    
    NSMutableArray *cards = [[oldBoardDict valueForKey:@"cards"] mutableCopy];
    NSMutableArray *newCards = [[newBoardDict valueForKey:@"cards"] mutableCopy];
    NSInteger cardIndex = [cards indexOfObject:theCard];
    NSMutableDictionary *updatedCard = [theCard mutableCopy];
    [updatedCard setObject:newBoardDict[@"id"] forKey:@"idBoard"];
    [updatedCard setObject:newList[@"id"] forKey:@"idList"];
    [cards removeObjectAtIndex:cardIndex];
    [newCards addObject:updatedCard];
    //[cards replaceObjectAtIndex:cardIndex withObject:updatedCard];
    [oldBoardDict setObject:cards forKey:@"cards"];
    [newBoardDict setObject:newCards forKey:@"cards"];
    [[self.trelloData objectForKey:@"boards"] setObject:oldBoardDict forKey:oldBoardName];
     [[self.trelloData objectForKey:@"boards"] setObject:newBoardDict forKey:boardName];
    [self.trelloData writeToFile:[XTModel boardsDataStoreFile] atomically:TRUE];
    
    [self moveCardWithID:updatedCard[@"id"] toListWithID:newList[@"id"]  inBoardWithID:newBoardDict[@"id"]];
    //[self moveCardWithID:theCard[@"id"] toListWithID:listID];
    return trelloData;
}

- (NSDictionary *)moveCard:(NSDictionary *)theCard toListWithID:(NSString *)listID inBoardNamed:(NSString *)boardName
{
    NSMutableDictionary *boardDict = [[self boardNamed:boardName] mutableCopy];
    NSMutableArray *cards = [[boardDict valueForKey:@"cards"] mutableCopy];
    NSInteger cardIndex = [cards indexOfObject:theCard];
    NSMutableDictionary *updatedCard = [theCard mutableCopy];
    [updatedCard setObject:listID forKey:@"idList"];
    [cards replaceObjectAtIndex:cardIndex withObject:updatedCard];
    [boardDict setObject:cards forKey:@"cards"];
    [[self.trelloData objectForKey:@"boards"] setObject:boardDict forKey:boardName];
    [self.trelloData writeToFile:[XTModel boardsDataStoreFile] atomically:TRUE];
    
    [self moveCardWithID:theCard[@"id"] toListWithID:listID];
    return trelloData;
}

- (NSDictionary *)addCardToBoard:(NSString *)boardName inList:(NSString *)listName withName:(NSString *)cardName withDescription:(NSString *)theDescription
{
    NSMutableDictionary *boardDict = [[self boardNamed:boardName] mutableCopy];
    NSMutableArray *cards = [[boardDict valueForKey:@"cards"] mutableCopy];
    NSDictionary *newCard = [[[self createCardWithName:cardName toListWithName:listName inBoardNamed:boardName] objectForKey:@"response"] mutableCopy];
    [newCard setValue:theDescription forKey:@"desc"];
    NSString *cardID = newCard[@"id"];
    [self setDescription:theDescription forCardWithID:cardID];
    [cards addObject:newCard];
    [boardDict setObject:cards forKey:@"cards"];
    [[self.trelloData objectForKey:@"boards"] setObject:boardDict forKey:boardName];
    [self.trelloData writeToFile:[XTModel boardsDataStoreFile] atomically:TRUE];
    
    
    return trelloData;
}

- (NSDictionary *)addCardToBoard:(NSString *)boardName inList:(NSString *)listName withName:(NSString *)cardName inPosition:(NSString *)thePosition
{

    NSMutableDictionary *boardDict = [[self boardNamed:boardName] mutableCopy];
    
    if (boardDict == nil) return nil;
    
    NSMutableArray *cards = [[boardDict valueForKey:@"cards"] mutableCopy];
    NSDictionary *newCard = [[self createCardWithName:cardName toListWithName:listName inBoardNamed:boardName] objectForKey:@"response"];
    if (thePosition == nil || [thePosition isEqualToString:@"bottom"])
    {
        [cards addObject:newCard];
    
    } else {
        
        if ([thePosition isEqualToString:@"top"])
        {
            [cards insertObject:newCard atIndex:0];
        
        } else { //should only be a number value here
            
            [cards insertObject:newCard atIndex:[thePosition integerValue]];
            
        }
        
        /*
         
         only if its top or some other index do we need to update trello one more time with index change, should probably just update
         createCardWithName to accept an index as well..
         
        */
        
        [self changeCardWithID:newCard[@"id"] toPosition:@"top"];
        
        
    }
    
    [boardDict setObject:cards forKey:@"cards"];
    [[self.trelloData objectForKey:@"boards"] setObject:boardDict forKey:boardName];
    [self.trelloData writeToFile:[XTModel boardsDataStoreFile] atomically:TRUE];
    
    
    return trelloData;
}

- (NSDictionary *)removeMemberId:(NSString *)memberID fromCard:(NSDictionary *)theCard inBoardNamed:(NSString *)boardName
{
    NSMutableDictionary *boardDict = [[self boardNamed:boardName] mutableCopy];
    NSMutableArray *cards = [[boardDict valueForKey:@"cards"] mutableCopy];
    NSInteger objectIndex = [[boardDict valueForKey:@"cards"] indexOfObject:theCard];
    
    if (objectIndex > [cards count])
    {
        NSLog(@"dictionary not found!");
        //  NSLog(@"theCard: %@", theCard);
        
        NSDictionary *cardSearch = [[cards filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"(SELF.name == %@)", theCard[@"name"]]] lastObject];
        //NSLog(@"cardSearch: %@", cardSearch);
        objectIndex = [cards indexOfObject:cardSearch];
        NSLog(@"new object index: %li", (long)objectIndex);
    }
    
    NSMutableDictionary *newCard = [theCard mutableCopy];
    [[newCard objectForKey:@"idMembers"] removeObject:memberID];
    // NSLog(@"replacing: %@ with: %@", [cards objectAtIndex:objectIndex], newCard);
    [cards replaceObjectAtIndex:objectIndex withObject:newCard];
    [boardDict setObject:cards forKey:@"cards"];
    [[self.trelloData objectForKey:@"boards"] setObject:boardDict forKey:boardName];
    [self.trelloData writeToFile:[XTModel boardsDataStoreFile] atomically:TRUE];
    
    //now update on trello side!!
    
    NSString *cardID = theCard[@"id"];
 //   [self addMemberID:memberID toCardWithID:cardID];
    [self removeMemberWithID:memberID fromCardID:cardID];
    return trelloData;
}

- (NSDictionary *)addMemberId:(NSString *)memberID toCard:(NSDictionary *)theCard inBoardNamed:(NSString *)boardName
{
    NSMutableDictionary *boardDict = [[self boardNamed:boardName] mutableCopy];
    NSMutableArray *cards = [[boardDict valueForKey:@"cards"] mutableCopy];
    NSInteger objectIndex = [[boardDict valueForKey:@"cards"] indexOfObject:theCard];
    
    if (objectIndex > [cards count])
    {
        NSLog(@"dictionary not found!");
        //  NSLog(@"theCard: %@", theCard);
        
        NSDictionary *cardSearch = [[cards filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"(SELF.name == %@)", theCard[@"name"]]] lastObject];
        //NSLog(@"cardSearch: %@", cardSearch);
        objectIndex = [cards indexOfObject:cardSearch];
        NSLog(@"new object index: %li", (long)objectIndex);
    }
    
    NSMutableDictionary *newCard = [theCard mutableCopy];
    NSMutableArray *idMembers = [[newCard objectForKey:@"idMembers"] mutableCopy];
    [idMembers addObject:memberID];
    [newCard setObject:idMembers forKey:@"idMembers"];
    [cards replaceObjectAtIndex:objectIndex withObject:newCard];
    [boardDict setObject:cards forKey:@"cards"];
    [[self.trelloData objectForKey:@"boards"] setObject:boardDict forKey:boardName];
    [self.trelloData writeToFile:[XTModel boardsDataStoreFile] atomically:TRUE];
    
    //now update on trello side!!
    
    NSString *cardID = theCard[@"id"];
    [self addMemberID:memberID toCardWithID:cardID];
    return trelloData;
}

- (NSDictionary *)updateLocalCard:(NSDictionary *)theCard withName:(NSString *)theName inBoardNamed:(NSString *)boardName
{
    NSMutableDictionary *boardDict = [[self boardNamed:boardName] mutableCopy];
    NSMutableArray *cards = [[boardDict valueForKey:@"cards"] mutableCopy];
    NSInteger objectIndex = [[boardDict valueForKey:@"cards"] indexOfObject:theCard];
    
    if (objectIndex > [cards count])
    {
        NSLog(@"dictionary not found!");
      //  NSLog(@"theCard: %@", theCard);
        
       NSDictionary *cardSearch = [[cards filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"(SELF.name == %@)", theCard[@"name"]]] lastObject];
       //NSLog(@"cardSearch: %@", cardSearch);
        objectIndex = [cards indexOfObject:cardSearch];
        NSLog(@"new object index: %li", (long)objectIndex);
         if (objectIndex > [cards count])
         {
             NSLog(@"######## WHAT'D U DO?!?!?!?!?!?!?");
             return nil;
         }
    }
    
    NSMutableDictionary *newCard = [theCard mutableCopy];
    [newCard setObject:theName forKey:@"name"];
    //  NSLog(@"replacing: %@ with: %@", [cards objectAtIndex:objectIndex], newCard);
    [cards replaceObjectAtIndex:objectIndex withObject:newCard];
    [boardDict setObject:cards forKey:@"cards"];
    [[self.trelloData objectForKey:@"boards"] setObject:boardDict forKey:boardName];
    [self.trelloData writeToFile:[XTModel boardsDataStoreFile] atomically:TRUE];
    
    //now update on trello side!!
    
    NSString *cardID = theCard[@"id"];
    [self setName:theName forCardWithID:cardID];
    return trelloData;
}


- (NSDictionary *)updateLocalCardLabels:(NSDictionary *)theCard withList:(NSArray *)theList inBoardNamed:(NSString *)boardName
{
    NSMutableDictionary *boardDict = [[self boardNamed:boardName] mutableCopy];
    NSMutableArray *cards = [[boardDict valueForKey:@"cards"] mutableCopy];
    NSInteger objectIndex = [[boardDict valueForKey:@"cards"] indexOfObject:theCard];
    NSMutableDictionary *newCard = [theCard mutableCopy];
    [newCard setObject:theList forKey:@"labels"];
    NSMutableArray *labelIds = [NSMutableArray new];
    for(NSDictionary *labelDictionary in theList)
    {
        NSString *labelID = labelDictionary[@"id"];
        [labelIds addObject:labelID];
    }
    if (labelIds.count > 0)
    {
        [newCard setObject:labelIds forKey:@"idLabels"];
    }
    // NSLog(@"replacing: %@ with: %@", [cards objectAtIndex:objectIndex], newCard);
    [cards replaceObjectAtIndex:objectIndex withObject:newCard];
    [boardDict setObject:cards forKey:@"cards"];
    [[self.trelloData objectForKey:@"boards"] setObject:boardDict forKey:boardName];
    [self.trelloData writeToFile:[XTModel boardsDataStoreFile] atomically:TRUE];
    
    //stuff below is obsolete, the labels are updated directly in XTTrelloCardView
   /*
    
    NSArray *labelArray = [self usefulLabelArray:theList];
    NSString *cardID = theCard[@"id"];
    NSLog(@"setting labels: %@ forCard: %@", labelArray, cardID);
   
    [self setLabels:labelArray forCardWithID:cardID];
    */
    
    return trelloData;
}

/*
 
 all of these are to make interacting with trello as painless as possible, making it possible to do any
 standard task just based on names of cards, lists, boards, etc.
 
 */

- (NSDictionary *)cardWithName:(NSString *)cardName inBoardNamed:(NSString *)boardName
{
    NSDictionary *boardDict = [self boardNamed:boardName];
    NSArray *cards = [boardDict valueForKey:@"cards"];
    return [[cards filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"(SELF.name == %@)", cardName]] lastObject];
}

- (NSDictionary *)listWithName:(NSString *)listName inBoardNamed:(NSString *)boardName
{
    NSDictionary *boardDict = [self boardNamed:boardName];
    NSArray *lists = [boardDict valueForKey:@"lists"];
    NSPredicate *filterPredicate = [NSPredicate predicateWithFormat:@"(SELF.name == %@)", listName];
    return [[lists filteredArrayUsingPredicate:filterPredicate] lastObject];
}

- (NSArray *)cardsFromListWithName:(NSString *)listName inBoard:(NSString *)boardName
{
    NSDictionary *boardDict = [self boardNamed:boardName];
    NSDictionary *listDict = [self listWithName:listName inBoardNamed:boardName];
    NSString *listID = listDict[@"id"];
    NSArray *cards = [boardDict valueForKey:@"cards"];
    NSPredicate *filterPredicate = [NSPredicate predicateWithFormat:@"(idList == %@)", listID];
    NSSortDescriptor *sortDesc = [[NSSortDescriptor alloc] initWithKey:@"pos" ascending:TRUE];
    NSArray *filteredArray =[cards filteredArrayUsingPredicate:filterPredicate];
    
    return [filteredArray sortedArrayUsingDescriptors:@[sortDesc]];

}

- (NSDictionary *)boardNamed:(NSString *)boardName
{
    return [[trelloData objectForKey:@"boards"] objectForKey:boardName];
}

#pragma mark trello API convenience methods


/** 
 
 these label ids are based on what we personally used for label ids, 
 you may decide to use something different.

 a lot of these label methods are potentially deprecated.
 
 */

- (NSString *)colorStringFromLabel:(NSString *)theLabel
{
    NSString *colorString = nil;
    
    if ([[theLabel lowercaseString] isEqualToString:@"improvement"]) colorString = @"green";
    if ([[theLabel lowercaseString] isEqualToString:@"investigation"]) colorString = @"yellow";
    if ([[theLabel lowercaseString] isEqualToString:@"tool"]) colorString = @"orange";
    if ([[theLabel lowercaseString] isEqualToString:@"bug"]) colorString = @"red";
    if ([[theLabel lowercaseString] isEqualToString:@"testing"]) colorString = @"purple";
    if ([[theLabel lowercaseString] isEqualToString:@"feature"]) colorString = @"blue";
    
    if(colorString == nil) colorString = theLabel; //maybe its already a color?
    
    return colorString;
}

- (NSArray *)closedCardsInBoard:(NSString *)boardName
{
    NSDictionary *boardDict = [self boardNamed:boardName];
    NSArray *cards = [boardDict valueForKey:@"cards"];
    return [cards filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"closed = NO"]];
}

- (NSArray *)colorArray
{
   return [NSArray arrayWithObjects:@"green", @"yellow", @"orange", @"red", @"purple", @"blue", nil];
}

- (NSString *)colorLabelFromName:(NSString *)colorName
{
    NSString *labelString = nil;
    
    if ([[colorName lowercaseString] isEqualToString:@"green"]) labelString = @"Improvement";
    if ([[colorName lowercaseString] isEqualToString:@"yellow"]) labelString = @"Investigation";
    if ([[colorName lowercaseString] isEqualToString:@"orange"]) labelString = @"Tool";
    if ([[colorName lowercaseString] isEqualToString:@"red"]) labelString = @"Bug";
    if ([[colorName lowercaseString] isEqualToString:@"purple"]) labelString = @"Testing";
    if ([[colorName lowercaseString] isEqualToString:@"blue"]) labelString = @"Feature";
    
    if(labelString == nil)
    {
     //   NSLog(@"labelString was nil, set it to original color!");
        labelString = colorName; //maybe its already a color?
        
       // NSLog(@"labelString: %@", labelString);
    }
    
    
    return labelString;
}

//shouldnt be used anymore
- (NSString *)colorStringFromLabelArray:(NSArray *)labelArray
{
    NSMutableArray *newArray = [[NSMutableArray alloc] init];
    
    for (NSString *currentLabel in labelArray)
    {
        NSString *newString = [self colorStringFromLabel:currentLabel];
        if (newString != nil)
        {
            [newArray addObject:newString];
        }
    }
    return [newArray componentsJoinedByString:@","];
}


#pragma mark member manipulation

- (void)addMemberNamed:(NSString *)memberName toCardWithName:(NSString *)cardName inBoardNamed:(NSString *)boardName
{
    NSDictionary *boardDict = [[trelloData objectForKey:@"boards"] objectForKey:boardName];
    NSArray *members = [boardDict valueForKey:@"members"];
    NSPredicate *filterPredicate = [NSPredicate predicateWithFormat:@"(SELF.username == %@)", memberName];
    NSDictionary *memberItem = [[members filteredArrayUsingPredicate:filterPredicate] lastObject];
    NSString *memberID = [memberItem objectForKey:@"id"];
    NSArray *cards = [boardDict valueForKey:@"cards"];
    NSDictionary *cardItem = [[cards filteredArrayUsingPredicate:
                               [NSPredicate predicateWithFormat:@"(SELF.name == %@)", cardName]] lastObject];
    NSString *cardID = [cardItem objectForKey:@"id"];
    if (cardID != nil && memberItem != nil)
    {
        [self addMemberID:memberID toCardWithID:cardID];
    }
}


- (void)addMemberID:(NSString *)memberID toCardWithID:(NSString *)cardID
{
    //%@/cards/%@/idMembers?key=%@&token=%@&value=%@
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    NSString *newURL = [NSString stringWithFormat:@"%@/cards/%@/idMembers?key=%@&token=%@&value=%@", baseURL, cardID, apiKey, sessionToken, memberID];
    //NSLog(@"newURL: %@", newURL);
    [request setURL:[NSURL URLWithString:newURL]];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    [self performSynchronousConnectionFromURLRequest:request];
}

- (void)removeMemberNamed:(NSString *)memberName fromCardNamed:(NSString *)cardName inBoard:(NSString *)boardName
{
    NSDictionary *boardDict = [[trelloData objectForKey:@"boards"] objectForKey:boardName];
    NSArray *members = [boardDict valueForKey:@"members"];
    NSPredicate *filterPredicate = [NSPredicate predicateWithFormat:@"(SELF.username == %@)", memberName];
    NSDictionary *memberItem = [[members filteredArrayUsingPredicate:filterPredicate] lastObject];
    NSString *memberID = [memberItem objectForKey:@"id"];
    NSArray *cards = [boardDict valueForKey:@"cards"];
    NSDictionary *cardItem = [[cards filteredArrayUsingPredicate:
                               [NSPredicate predicateWithFormat:@"(SELF.name == %@)", cardName]] lastObject];
    NSString *cardID = [cardItem objectForKey:@"id"];
    if (cardID != nil && memberItem != nil)
    {
        [self removeMemberWithID:memberID fromCardID:cardID];
    }
}

- (void)removeMemberWithID:(NSString *)memberID fromCardID:(NSString *)cardID
{
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    NSString *newURL = [NSString stringWithFormat:@"%@/cards/%@/idMembers/%@?key=%@&token=%@", baseURL, cardID, memberID, apiKey, sessionToken];
    //NSLog(@"newURL: %@", newURL);
    [request setURL:[NSURL URLWithString:newURL]];
    [request setHTTPMethod:@"DELETE"];
	[request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    [self performSynchronousConnectionFromURLRequest:request];
    
}

#pragma mark card manipulation

- (void)deleteCardWithID:(NSString *)cardID
{
    //%@/cards/%@/actions/comments?key=%@&token=%@&text=%@"
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    NSString *newURL = [NSString stringWithFormat:@"%@/cards/%@?key=%@&token=%@", baseURL, cardID, apiKey, sessionToken];
    //NSLog(@"newURL: %@", newURL);
    [request setURL:[NSURL URLWithString:newURL]];
    [request setHTTPMethod:@"DELETE"];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    [self performSynchronousConnectionFromURLRequest:request];
}

- (void)moveCardNamed:(NSString *)cardName toListWithName:(NSString *)listName inBoardNamed:(NSString *)boardName
{
    // NSLog(@"trelloData: %@", trelloData);
    NSDictionary *boardDict = [[trelloData objectForKey:@"boards"] objectForKey:boardName];
    NSArray *lists = [boardDict valueForKey:@"lists"];
    NSPredicate *filterPredicate = [NSPredicate predicateWithFormat:@"(SELF.name == %@)", listName];
    NSDictionary *listItem = [[lists filteredArrayUsingPredicate:filterPredicate] lastObject];
    NSString *listId = [listItem objectForKey:@"id"];
    NSArray *cards = [boardDict valueForKey:@"cards"];
    NSDictionary *cardItem = [[cards filteredArrayUsingPredicate:
                               [NSPredicate predicateWithFormat:@"(SELF.name == %@)", cardName]] lastObject];
    NSString *cardID = [cardItem objectForKey:@"id"];
    if (cardID != nil && listItem != nil)
    {
        [self moveCardWithID:cardID toListWithID:listId];
    }
}

//actually moves the card to a new board entirely

- (void)moveCardWithID:(NSString *)cardID toListWithID:(NSString *)theList inBoardWithID:(NSString *)boardID

{
    ///PUT %@/cards/%@/idBoard?key=%@&token=%@value=%@&idList=%@
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    NSString *newURL = [NSString stringWithFormat:@"%@/cards/%@/idBoard?key=%@&token=%@&value=%@&idList=%@", baseURL, cardID, apiKey, sessionToken, boardID, theList];
    NSLog(@"newURL: %@", newURL);
    [request setURL:[NSURL URLWithString:newURL]];
    [request setHTTPMethod:@"PUT"];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    [self performSynchronousConnectionFromURLRequest:request];
}

- (void)moveCardWithID:(NSString *)cardID toListWithID:(NSString *)theList
{
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    NSString *newURL = [NSString stringWithFormat:@"%@/cards/%@/idList?key=%@&token=%@&value=%@", baseURL, cardID, apiKey, sessionToken, theList];
    //NSLog(@"newURL: %@", newURL);
    [request setURL:[NSURL URLWithString:newURL]];
    [request setHTTPMethod:@"PUT"];
	[request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    [self performSynchronousConnectionFromURLRequest:request];
}

- (NSDictionary *)createCardWithName:(NSString *)cardName toListWithName:(NSString *)listName inBoardNamed:(NSString *)boardName
{
    // NSLog(@"trelloData: %@", trelloData);
    NSDictionary *boardDict = [[trelloData objectForKey:@"boards"] objectForKey:boardName];
    NSArray *lists = [boardDict valueForKey:@"lists"];
    NSPredicate *filterPredicate = [NSPredicate predicateWithFormat:@"(SELF.name == %@)", listName];
    NSDictionary *listItem = [[lists filteredArrayUsingPredicate:filterPredicate] lastObject];
    NSString *listId = [listItem objectForKey:@"id"];
    if (listItem != nil)
    {
       return  [self createCardWithName:cardName toListWithID:listId];
    }
    
    return nil;
}

- (NSDictionary *)createCardWithName:(NSString *)cardName toListWithID:(NSString *)listID
{
   // NSString *updatedName =  [cardName stringByReplacingOccurrencesOfString:@" " withString:@"+"];
    NSString *updatedName = [cardName stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    NSString *newURL = [NSString stringWithFormat:@"%@/cards?idList=%@&name=%@&key=%@&token=%@", baseURL, listID, updatedName, apiKey, sessionToken];
    //NSLog(@"newURL: %@", newURL);
    [request setURL:[NSURL URLWithString:newURL]];
    [request setHTTPMethod:@"POST"];
	[request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    return [self performSynchronousConnectionFromURLRequest:request];
}


//https://api.trello.com/1/cards/4eea503d91e31d174600008f?fields=name,idList&member_fields=fullName&key=[application_key]&token=[optional_auth_token]

- (void)setDescription:(NSString *)theDesc forCardNamed:(NSString *)cardName inBoardNamed:(NSString *)boardName
{
    NSDictionary *boardDict = [[trelloData objectForKey:@"boards"] objectForKey:boardName];
    NSArray *cards = [boardDict valueForKey:@"cards"];
    NSDictionary *cardItem = [[cards filteredArrayUsingPredicate:
                               [NSPredicate predicateWithFormat:@"(SELF.name == %@)", cardName]] lastObject];
    NSString *cardID = [cardItem objectForKey:@"id"];
    if (cardID != nil)
    {
        [self setDescription:theDesc forCardWithID:cardID];
    }
}

- (void)setDescription:(NSString *)theDesc forCardWithID:(NSString *)theCard
{
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
   // NSString *newDesc = [theDesc stringByReplacingOccurrencesOfString:@" " withString:@"+"];
    NSString *newDesc = [theDesc stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSString *newURL = [NSString stringWithFormat:@"%@/cards/%@/desc?key=%@&token=%@&value=%@", baseURL, theCard, apiKey, sessionToken, newDesc];
    //NSLog(@"newURL: %@", newURL);
	[request setURL:[NSURL URLWithString:newURL]];
    [request setHTTPMethod:@"PUT"];
	[request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    
    [self performSynchronousConnectionFromURLRequest:request];
    
}

- (void)setName:(NSString *)theName forCardWithID:(NSString *)theCard
{
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    //NSString *updatedName =  [theName stringByReplacingOccurrencesOfString:@" " withString:@"+"];
    NSString *updatedName = [theName stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSString *newURL = [NSString stringWithFormat:@"%@/cards/%@/name?key=%@&token=%@&value=%@", baseURL, theCard, apiKey, sessionToken, updatedName];
    //NSLog(@"newURL: %@", newURL);
    [request setURL:[NSURL URLWithString:newURL]];
    [request setHTTPMethod:@"PUT"];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    
    [self performSynchronousConnectionFromURLRequest:request];
    
}

- (void)changeCardWithID:(NSString *)cardID toPosition:(NSString *)newPosition
{
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    NSString *newURL = [NSString stringWithFormat:@"%@/cards/%@/pos?key=%@&token=%@&value=%@", baseURL, cardID, apiKey, sessionToken, newPosition];
    //NSLog(@"newURL: %@", newURL);
    [request setURL:[NSURL URLWithString:newURL]];
    [request setHTTPMethod:@"PUT"];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    
    [self performSynchronousConnectionFromURLRequest:request];
}

- (void)moveCardNamed:(NSString *)cardName inBoardNamed:(NSString *)boardName toPosition:(NSString *)newPosition
{
    NSString *cardID = [[self cardWithName:cardName inBoardNamed:boardName] objectForKey:@"id"];
    [self changeCardWithID:cardID toPosition:newPosition];
}


#pragma mark label manipulation

- (void)setLabels:(NSArray *)theLabels forCardNamed:(NSString *)cardName inBoardNamed:(NSString *)boardName
{
    NSDictionary *boardDict = [[trelloData objectForKey:@"boards"] objectForKey:boardName];
    NSArray *cards = [boardDict valueForKey:@"cards"];
    NSDictionary *cardItem = [[cards filteredArrayUsingPredicate:
                               [NSPredicate predicateWithFormat:@"(SELF.name == %@)", cardName]] lastObject];
    NSString *cardID = [cardItem objectForKey:@"id"];
    if (cardID != nil)
    {
        [self setLabels:theLabels forCardWithID:cardID];
    }
}


- (void)deleteLabelID:(NSString *)labelID forCardWithID:(NSString *)theCard
{
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    NSString *newURL = [NSString stringWithFormat:@"%@/cards/%@/idLabels/%@?key=%@&token=%@", baseURL, theCard, labelID,apiKey, sessionToken];
   //  NSLog(@"newURL: %@", newURL);
    [request setURL:[NSURL URLWithString:newURL]];
    [request setHTTPMethod:@"DELETE"];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    
    [self performSynchronousConnectionFromURLRequest:request];
    
}

- (void)addLabelID:(NSString *)labelID forCardWithID:(NSString *)theCard
{
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    NSString *newURL = [NSString stringWithFormat:@"%@/cards/%@/idLabels?key=%@&token=%@&value=%@", baseURL, theCard, apiKey, sessionToken, labelID];
  //  NSLog(@"newURL: %@", newURL);
    [request setURL:[NSURL URLWithString:newURL]];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    
    [self performSynchronousConnectionFromURLRequest:request];
    
}

//PUT /1/boards/[board_id]/labelNames/yellow

- (void)setLabelName:(NSString *)labelName forColor:(NSString *)colorName inBoardWithID:(NSString *)boardID
{
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    NSString *newURL = [NSString stringWithFormat:@"%@/boards/%@/labelNames/%@?key=%@&token=%@&value=%@", baseURL, boardID, colorName, apiKey, sessionToken, labelName];
    //NSLog(@"newURL: %@", newURL);
    [request setURL:[NSURL URLWithString:newURL]];
    [request setHTTPMethod:@"PUT"];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    
    [self performSynchronousConnectionFromURLRequest:request];
    
}

//get the associated dictionary of a color from its name in a particular board, part of the new label changes.

- (NSDictionary *)labelDictionaryFromColor:(NSString *)colorName inBoardNamed:(NSString *)boardName
{
    NSLog(@"colorName: %@", colorName);
    NSDictionary *currentBoard = [self boardNamed:boardName];
    NSArray *labels = [currentBoard valueForKey:@"labels"];
    NSDictionary *theLabel = [[labels filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"(SELF.color == %@)", colorName]] lastObject];
    return theLabel;
    
}


//obsolete method, dont use it! wont support new colors
- (void)setLabels:(NSArray *)theLabels forCardWithID:(NSString *)theCard
{
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    // NSString *labelsString = [theLabels componentsJoinedByString:@","];
    NSString *labelsString = [self colorStringFromLabelArray:theLabels];
    NSString *newURL = [NSString stringWithFormat:@"%@/cards/%@/labels?key=%@&token=%@&value=%@", baseURL, theCard, apiKey, sessionToken, labelsString];
    //NSLog(@"newURL: %@", newURL);
	[request setURL:[NSURL URLWithString:newURL]];
    [request setHTTPMethod:@"PUT"];
	[request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    
    [self performSynchronousConnectionFromURLRequest:request];
    
}

#pragma mark list manipulation

/*
 
 PUT /1/lists/[idList]/name
 Required permissions: write
 Arguments
 value (required)
 Valid Values: a string with a length from 1 to 16384
 
 */

- (void)changeListName:(NSString *)theList toName:(NSString *)listName inBoardNamed:(NSString *)boardName
{
    NSString *listID = [[self listWithName:theList inBoardNamed:boardName] objectForKey:@"id"];
    [self changeListWithID:listID toName:listName];
}

- (void)changeListWithID:(NSString *)listID toName:(NSString *)listName
{
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    NSString *newURL = [NSString stringWithFormat:@"%@/lists/%@/name?value=%@&key=%@&token=%@", baseURL, listID, listName, apiKey, sessionToken];
    //NSLog(@"newURL: %@", newURL);
	[request setURL:[NSURL URLWithString:newURL]];
    [request setHTTPMethod:@"PUT"];
	[request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    
    [self performSynchronousConnectionFromURLRequest:request];
}

- (void)changeListWithID:(NSString *)listID toPosition:(NSString *)newPosition
{
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    NSString *newURL = [NSString stringWithFormat:@"%@/lists/%@/pos?value=%@&key=%@&token=%@", baseURL, listID, newPosition, apiKey, sessionToken];
    //NSLog(@"newURL: %@", newURL);
	[request setURL:[NSURL URLWithString:newURL]];
    [request setHTTPMethod:@"PUT"];
	[request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    
    [self performSynchronousConnectionFromURLRequest:request];
}

- (void)changeListNamed:(NSString *)theListName inBoard:(NSString *)boardName toPosition:(NSString *)newPosition
{
    NSString *listID = [[self listWithName:theListName inBoardNamed:boardName] objectForKey:@"id"];
    [self changeListWithID:listID toPosition:newPosition];
}


/*
 
 POST /1/lists
 Required permissions: write
 Arguments
 name (required)
 Valid Values: a string with a length from 1 to 16384
 idBoard
 
 */

- (void)createListWithName:(NSString *)listName inBoardWithID:(NSString *)boardID inLocation:(NSString *)location
{
    if (location == nil)
        location = @"top";
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    NSString *newURL = [NSString stringWithFormat:@"%@/lists?name=%@&idBoard=%@&key=%@&token=%@&pos=%@", baseURL, listName, boardID, apiKey, sessionToken, location];
    //NSLog(@"newURL: %@", newURL);
	[request setURL:[NSURL URLWithString:newURL]];
    [request setHTTPMethod:@"POST"];
	[request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    
    [self performSynchronousConnectionFromURLRequest:request];
}

- (void)createListWithName:(NSString *)listName inBoardNamed:(NSString *)boardName
{
    [self createListWithName:listName inBoardNamed:boardName inLocation:@"top"];
}

- (void)createListWithName:(NSString *)listName inBoardNamed:(NSString *)boardName inLocation:(NSString *)location
{
    if (location == nil)
        location = @"top";
    
    NSDictionary *boardDict = [[trelloData objectForKey:@"boards"] objectForKey:boardName];
    NSString *boardID = boardDict[@"id"];
    [self createListWithName:listName inBoardWithID:boardID inLocation:location];
}

#pragma mark board manipulation

- (NSDictionary *)createBoardWithName:(NSString *)boardName inOrganization:(NSString *)orgName
{
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    NSString *newURL = nil;
    if (orgName != nil)
    {
        newURL = [NSString stringWithFormat:@"%@/boards?name=%@&idOrganization=%@&key=%@&token=%@&prefs_permissionLevel=org", baseURL, boardName,orgName, apiKey, sessionToken];
    } else {
        newURL = [NSString stringWithFormat:@"%@/boards?name=%@&key=%@&token=%@&prefs_permissionLevel=private", baseURL, boardName, apiKey, sessionToken];
    }
    // NSString *newURL = [NSString stringWithFormat:@"%@/boards?name=%@&idOrganization=%@&key=%@&token=%@&prefs_permissionLevel=org", baseURL, boardName,orgName, apiKey, sessionToken];
    NSLog(@"newURL: %@", newURL);
	[request setURL:[NSURL URLWithString:newURL]];
    [request setHTTPMethod:@"POST"];
	[request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    
    return [self performSynchronousConnectionFromURLRequest:request];
    
}
//https://trello.com/1/organizations/ORGID?members=all&key=KEY&token=TOKEN

- (NSDictionary *)organizationWithNameOrID:(NSString *)organizationName
{
    if (organizationName.length == 0) return nil;
    NSString *newURL = [NSString stringWithFormat:@"%@/organizations/%@?&key=%@&token=%@", baseURL, organizationName, apiKey, sessionToken];
    //NSLog(@"newURL: %@", newURL);
    return [self dictionaryFromURLString:newURL];
}

//PUT /1/boards/[board_id]/idOrganization

- (void)changeBoard:(NSString *)boardName toOrganizationWithNameOrID:(NSString *)organizationName
{
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    NSDictionary *boardDict = [[trelloData objectForKey:@"boards"] objectForKey:boardName];
    NSString *boardID = boardDict[@"id"];
    NSString *newURL = [NSString stringWithFormat:@"%@/boards/%@/idOrganization?key=%@&token=%@&value=%@", baseURL, boardID, apiKey, sessionToken, organizationName];
    //NSLog(@"newURL: %@", newURL);
    [request setURL:[NSURL URLWithString:newURL]];
    [request setHTTPMethod:@"PUT"];
	[request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    
    [self performSynchronousConnectionFromURLRequest:request];
    
}

//every API call goes through here, feed in a URLRequest, and get back a NSDictionary or NSArray (or in one instance an NSString)

- (NSDictionary *)performSynchronousConnectionFromURLRequest:(NSMutableURLRequest *)request
{
    NSHTTPURLResponse *theResponse = nil;
    NSData *returnData = [NSURLConnection sendSynchronousRequest:request returningResponse:&theResponse error:nil];
    NSString *datString = [[NSString alloc] initWithData:returnData  encoding:NSUTF8StringEncoding];
  //  NSLog(@"response: %@", datString);
    NSDictionary *responseDict = [self dictionaryFromJSONStringResponse:datString];
    
    //in only ONE instance (that i've found) JUST a string is returned rather than a JSON string
    
    if (responseDict == nil){
        responseDict = datString;
    }
    NSDictionary *returnDict = @{@"response": responseDict, @"statusCode": [NSString stringWithFormat:@"%li", (long)[theResponse statusCode]]};
   // NSLog(@"returnDict: %@", returnDict);
    if ([theResponse statusCode] != 200)
    {
        NSLog(@"response: %@ withStatus Code: %li", datString, (long)[theResponse statusCode]);
        
    }
    return returnDict;
}




#pragma mark fetching data

- (void)fetchTrelloData
{
    if (self.apiKey == nil || self.sessionToken == nil) return;
    startDate = [NSDate date];
    [NSThread detachNewThreadSelector:@selector(fetchTrelloDataThreaded) toTarget:self withObject:nil];
}


- (void)fetchTrelloDataThreaded
{
    @autoreleasepool {
        LOG_SELF;
      
        NSMutableDictionary *trelloDict = [[NSMutableDictionary alloc] init];
   
        //url for getting our boards
        NSString *boards = [NSString stringWithFormat:@"%@/members/me/boards?key=%@&token=%@", baseURL, apiKey, sessionToken];
        
        //url for getting our data about our user
        NSString *me = [NSString stringWithFormat:@"%@/members/me?key=%@&token=%@", baseURL, apiKey, sessionToken];
       // NSString *myCards = [NSString stringWithFormat:@"%@/members/my/cards?key=%@&token=%@", baseURL, apiKey, sessionToken];
       // NSLog(@"boards: %@", boards);
        NSArray *jsonBoards = (NSArray *)[self dictionaryFromURLString:boards];
        NSDictionary *jsonMe = [self dictionaryFromURLString:me];
        
        NSArray *myOrgs = jsonMe[@"idOrganizations"];
  
        //un-used example of fetching an avatar for your user.
        
        //NSString *myAvatar = jsonMe[@"avatarHash"];
        //NSImage *myBigAvatar = [self bigAvatarFromHash:myAvatar];
        
        //[[myBigAvatar TIFFRepresentation] writeToFile:[NSHomeDirectory() stringByAppendingPathComponent:@"Desktop/me.png"] atomically:TRUE];
        
        
        NSMutableArray *orgArray = [[NSMutableArray alloc] init];
        for (NSString *org in myOrgs)
        {
            NSDictionary *orgDict = [self organizationWithNameOrID:org];
            [orgArray addObject:orgDict];
        }
        NSMutableDictionary *meEditable = [jsonMe mutableCopy];
      
        NSMutableArray *boardNames = [NSMutableArray new];
        
        //its possible there are no organizations, if there isn't certain functionality wont work.
        if ([orgArray count] > 0)
        {
            [meEditable setObject:orgArray forKey:@"organizations"];
            
            NSMutableArray *moreBoards = [jsonBoards mutableCopy];
            
            
            for (NSDictionary *org in orgArray)
            {
                NSString *orgID = org[@"id"];
             //   NSString *displayName = org[@"displayName"];
                NSString *boards2 = [NSString stringWithFormat:@"%@/organizations/%@/boards?filter=all&key=%@&token=%@", baseURL,orgID, apiKey, sessionToken];
               // NSLog(@"boards2: %@", boards2);
                NSArray *jsonBoards2 = (NSArray *)[self dictionaryFromURLString:boards2];
                //NSLog(@"jsonBoards2: %@ for org: %@", jsonBoards2,displayName);
                [moreBoards addObjectsFromArray:jsonBoards2];
                
            }
            jsonBoards = moreBoards;
            
        }
        
        //the fetch for boards above will get ALL of them, open AND closed, we want to only add the open ones
        
        NSMutableDictionary *updatedBoards = [[NSMutableDictionary alloc] init];
        for (NSDictionary *currentBoard in jsonBoards)
        {
            //ignore any closed boards.
            
            NSString *name = [currentBoard objectForKey:@"name"];
            
            
            if ([currentBoard[@"closed"] boolValue] == FALSE && ![boardNames containsObject:name])
            {
                NSMutableDictionary *newBoard = [currentBoard mutableCopy];
                NSString *boardID = [currentBoard objectForKey:@"id"];
                [boardNames addObject:name];
                NSString *currentLabelNamesURL = [NSString stringWithFormat:@"%@/boards/%@/labelNames?key=%@&token=%@", baseURL, boardID, apiKey, sessionToken];
             
                //the board data fetch above USED to get all our label info, doesn't appear to fetch it properly anymore
                //so we need to manually fetch label names / colors / data for each board
                
                NSString *currentLabelsURL = [NSString stringWithFormat:@"%@/boards/%@/labels?key=%@&token=%@", baseURL, boardID, apiKey, sessionToken];
                NSDictionary *labelsDict = [self dictionaryFromURLString:currentLabelsURL];
                if (labelsDict != nil)
                    [newBoard setObject:labelsDict forKey:@"labels"];
                
                NSDictionary *labelNamesDict = [self dictionaryFromURLString:currentLabelNamesURL];
                if (labelNamesDict != nil)
                    [newBoard setObject:labelNamesDict forKey:@"labelNames"];
                
                NSString *currentCardURL = [NSString stringWithFormat:@"%@/board/%@/cards?key=%@&token=%@", baseURL, boardID, apiKey, sessionToken];
                NSArray *currentCards = (NSArray *)[self dictionaryFromURLString:currentCardURL];
                if (currentCards != nil)
                {
                    //only get cards that aren't archived / closed.
                    [newBoard setObject:[currentCards filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"closed = NO"]] forKey:@"cards"];
                }
                NSString *currentListsURL = [NSString stringWithFormat:@"%@/board/%@/lists?key=%@&token=%@", baseURL, boardID, apiKey, sessionToken];
                NSArray *currentLists = (NSArray *)[self dictionaryFromURLString:currentListsURL];
                if (currentLists != nil)
                    [newBoard setObject:[currentLists filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"closed = NO"]] forKey:@"lists"];
                
                NSArray *memberArray = [currentBoard objectForKey:@"memberships"];
                NSMutableArray *properMemberArray = [[NSMutableArray alloc] init];
                for (NSDictionary *member in memberArray)
                {
                    NSString *memberID = member[@"idMember"];
                    NSString *currentMemberURL = [NSString stringWithFormat:@"%@/members/%@?key=%@&token=%@", baseURL, memberID, apiKey, sessionToken];
                    NSDictionary *currentMember = [self dictionaryFromURLString:currentMemberURL];
                    [properMemberArray addObject:currentMember];
                    
                }
                if ([properMemberArray count] > 0)
                {
                    [newBoard setObject:properMemberArray forKey:@"members"];
                }
                
                
                //get board organization
                
                NSDictionary *boardOrg = [self organizationWithNameOrID:currentBoard[@"idOrganization"]];
                if (boardOrg != nil)
                    [newBoard setObject:boardOrg forKey:@"organization"];
                
                [updatedBoards setObject:newBoard forKey:name];

            }
        }
        
       // NSSortDescriptor *sortDesc = [[NSSortDescriptor alloc] initWithKey:@"name" ascending:TRUE];
        
       // return [filteredArray sortedArrayUsingDescriptors:@[sortDesc]];
        
        [trelloDict setObject:updatedBoards forKey:@"boards"];
        [trelloDict setObject:meEditable forKey:@"me"];
        
        [trelloDict writeToFile:[XTModel boardsDataStoreFile] atomically:TRUE];
        
        self.trelloData = trelloDict;
       
        if (reloading == FALSE)
        {
            NSLog(@"initial load, call the delegate");
            [delegate trelloDataFetched:trelloDict];
        } else {
            NSLog(@"reloaded, call different delegate method");
            [delegate trelloDataUpdated:trelloDict];
        }
        
        self.reloading = FALSE;
        self.dataReady = TRUE;
        
        NSLog(@"fetch finished in: %@", [startDate timeStringFromCurrentDate]);
    }
    
}

- (void)reloadTrelloData
{
     startDate = [NSDate date];
    self.reloading = TRUE;
    self.dataReady = FALSE;
    if (self.apiKey == nil)
        self.apiKey = [UD valueForKey:kXTrelloAPIKey];
    if (self.sessionToken == nil)
        self.sessionToken = [UD valueForKey:kXTrelloAuthToken];
    
    if (self.sessionToken == nil || self.apiKey == nil)
    {
        NSLog(@"either session token or api key is nil! bail!");
        return;
    }
    
    [NSThread detachNewThreadSelector:@selector(fetchTrelloDataThreaded) toTarget:self withObject:nil];
}

#pragma mark creating template boards

- (void)setDefaultLabelsForBoardNamed:(NSString *)boardName
{
    NSDictionary *boardNamed = [self boardNamed:boardName];
    NSString *boardID = boardNamed[@"id"];
    [self setDefaultLabelsForBoardID:boardID];
}

- (void)setDefaultLabelsForBoardID:(NSString *)boardID
{
    for (NSString *colorName in [self colorArray])
    {
        NSString *labelString = [self colorLabelFromName:colorName];
        [self setLabelName:labelString forColor:colorName inBoardWithID:boardID];
    }
}


//kind of a kludge used for the template board creation below.

- (NSString *)firstOrganizationName
{
    NSArray *orgs = [[trelloData objectForKey:@"me"] objectForKey:@"organizations"];
    if (orgs != nil)
    {
        NSDictionary *firstOrg = [[[trelloData objectForKey:@"me"] objectForKey:@"organizations"] firstObject];
        NSString *orgName = firstOrg[@"name"];
        return orgName;
    }
    return nil;
}

- (NSString *)initialNoteForType:(XTInitialNoteType)noteType
{
    NSString *initialNote = nil;
    
    switch (noteType) {
            
        case XTToDoType:
            
            initialNote = @"NOTE: Cards in this list represent new features, improvements, or generic tasks that are upcoming but not in active development.";
            
            break;
            
        case XTBugsType:
            
            initialNote = @"NOTE: Cards in this list represent known bugs that need to be addressed, but are not in active development.";
            break;
            
        case XTActiveType:
            
            initialNote = @"NOTE: Cards in this list represent items in active development. They should have a user or users associated with them.";
            break;
            
        case XTBlockedType:
            
            initialNote = @"NOTE: Cards in this list represent items that are blocked by an issue outside the responsibility of the primary dev.";
            break;
            
        case XTDoneType:
            
            initialNote = @"NOTE: Cards in this list represent items that have recently been completed, but are kept here before archiving for visibility.";
            break;
            
        case XTBacklogType:
            
            initialNote = @"NOTE: Cards in this list represent bugs, features, or generic tasks that may happen someday, but that day isn't coming very soon.";
            break;
            
    }
    
    return initialNote;
}

/*
 {"id":"ORGID","name":"XTrelloTest","desc":"","descData":null,"closed":false,"idOrganization":"ORGID","pinned":true,"url":"https://trello.com/b/peenlU3U/xtrellotest","shortUrl":"https://trello.com/b/peenlU3U","prefs":{"permissionLevel":"org","voting":"disabled","comments":"members","invitations":"members","selfJoin":false,"cardCovers":true,"cardAging":"regular","calendarFeedEnabled":false,"background":"blue","backgroundColor":"#23719F","backgroundImage":null,"backgroundImageScaled":null,"backgroundTile":false,"backgroundBrightness":"unknown","canBePublic":true,"canBeOrg":true,"canBePrivate":true,"canInvite":true},"labelNames":{"red":"","orange":"","yellow":"","green":"","blue":"","purple":""}} withStatus Code: 200
 */

- (void)createNewTemplateBoardWithName:(NSString *)boardName inOrganization:(NSString *)orgName
{
    if ([self boardNamed:boardName] != nil)
    {
        NSLog(@"board already exists!!");
        return;
    }
    NSDictionary *newBoard = [self createBoardWithName:boardName inOrganization:orgName];
    NSDictionary *convertedDict = [self dictionaryFromJSONStringResponse:newBoard[@"response"]];
    NSString *boardID = convertedDict[@"id"];
  
    [self createListWithName:@"Bugs" inBoardWithID:boardID inLocation:@"2"];
    [self createListWithName:@"Blocked" inBoardWithID:boardID inLocation:@"4"];
    [self createListWithName:@"Backlog" inBoardWithID:boardID inLocation:@"bottom"];
    
    NSString *currentListsURL = [NSString stringWithFormat:@"%@/board/%@/lists?key=%@&token=%@", baseURL, boardID, apiKey, sessionToken];
    NSArray *lists = (NSArray *)[self dictionaryFromURLString:currentListsURL];
    NSPredicate *filterPredicate = [NSPredicate predicateWithFormat:@"(SELF.name == %@)", @"Doing"];
    NSDictionary *newList = [[lists filteredArrayUsingPredicate:filterPredicate] lastObject];
    NSString *toDoID = [[[lists filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"(SELF.name == %@)", @"To Do"]] lastObject] objectForKey:@"id"];
    NSString *bugsID = [[[lists filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"(SELF.name == %@)", @"Bugs"]] lastObject] objectForKey:@"id"];
    NSString *blockedID = [[[lists filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"(SELF.name == %@)", @"Blocked"]] lastObject] objectForKey:@"id"];
    NSString *backlogID = [[[lists filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"(SELF.name == %@)", @"Backlog"]] lastObject] objectForKey:@"id"];
    NSString *doneID = [[[lists filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"(SELF.name == %@)", @"Done"]] lastObject] objectForKey:@"id"];
    
    [self changeListWithID:newList[@"id"] toName:@"Active"];
    [self changeListWithID:toDoID toPosition:@"top"];
    
    NSString *activeID = newList[@"id"];
    
    [self createCardWithName:[self initialNoteForType:XTToDoType] toListWithID:toDoID];
    [self createCardWithName:[self initialNoteForType:XTBugsType] toListWithID:bugsID];
    [self createCardWithName:[self initialNoteForType:XTBlockedType] toListWithID:blockedID];
    [self createCardWithName:[self initialNoteForType:XTDoneType] toListWithID:doneID];
    [self createCardWithName:[self initialNoteForType:XTBacklogType] toListWithID:backlogID];
    [self createCardWithName:[self initialNoteForType:XTActiveType] toListWithID:activeID];
    
    [self setDefaultLabelsForBoardID:boardID];
}

#pragma mark unused API methods

//both of these methods are how you fetch avatars for users.

- (NSImage *)bigAvatarFromHash:(NSString *)theHash
{
    NSString *urlString = [NSString stringWithFormat:@"https://trello-avatars.s3.amazonaws.com/%@/170.png", theHash];
    NSData *imageData = [NSData dataWithContentsOfURL:[NSURL URLWithString:urlString]];
    return [[NSImage alloc] initWithData:imageData];
    //https://trello-avatars.s3.amazonaws.com/0884b97b48236c3d08514e0735ffd73f/170.png
    
}

- (NSImage *)smallAvatarFromHash:(NSString *)theHash
{
    NSString *urlString = [NSString stringWithFormat:@"https://trello-avatars.s3.amazonaws.com/%@/30.png", theHash];
    NSData *imageData = [NSData dataWithContentsOfURL:[NSURL URLWithString:urlString]];
    return [[NSImage alloc] initWithData:imageData];
    //https://trello-avatars.s3.amazonaws.com/0884b97b48236c3d08514e0735ffd73f/30.png
    
}


- (void)closeBoardWithName:(NSString *)boardName
{
    NSString *boardID = [[self boardNamed:boardName] valueForKey:@"id"];
    [self closeBoardWithID:boardID];
}

- (void)closeListWithName:(NSString *)theList inBoardNamed:(NSString *)boardName
{
    NSString *listID = [[self listWithName:theList inBoardNamed:boardName] valueForKey:@"id"];
    [self closeListWithID:listID];
}

/*
 
 PUT /1/boards/[board_id]/closed
 Required permissions: own, write
 Arguments
 value (required)
 Valid Values:
 true
 false
 
 */

- (void)closeBoardWithID:(NSString *)boardID
{
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    NSString *newURL = [NSString stringWithFormat:@"%@/boards/%@/closed?key=%@&token=%@&value=%@", baseURL, boardID, apiKey, sessionToken, @"true"];
    //NSLog(@"newURL: %@", newURL);
    [request setURL:[NSURL URLWithString:newURL]];
    [request setHTTPMethod:@"PUT"];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    
    [self performSynchronousConnectionFromURLRequest:request];
}

- (void)closeListWithID:(NSString *)listID
{
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    NSString *newURL = [NSString stringWithFormat:@"%@/lists/%@/closed?key=%@&token=%@&value=%@", baseURL, listID, apiKey, sessionToken, @"true"];
    //NSLog(@"newURL: %@", newURL);
    [request setURL:[NSURL URLWithString:newURL]];
    [request setHTTPMethod:@"PUT"];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    
    [self performSynchronousConnectionFromURLRequest:request];
}

/*
 
 currently there is no native support in the plugin for adding card comments, wanted to have these
 in here just to be thorough in case i ever decided to implement these natively.
 
 */

- (void)postComment:(NSString *)theComment toCardNamed:(NSString *)cardName inBoardNamed:(NSString *)boardName
{
    NSDictionary *boardDict = [[trelloData objectForKey:@"boards"] objectForKey:boardName];
    NSArray *cards = [boardDict valueForKey:@"cards"];
    NSDictionary *cardItem = [[cards filteredArrayUsingPredicate:
                               [NSPredicate predicateWithFormat:@"(SELF.name == %@)", cardName]] lastObject];
    NSString *cardID = [cardItem objectForKey:@"id"];
    if (cardID != nil)
    {
        [self postComment:theComment toCardWithID:cardID];;
    }
}

- (void)postComment:(NSString *)theComment toCardWithID:(NSString *)cardID
{
    //%@/cards/%@/actions/comments?key=%@&token=%@&text=%@"
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    //NSString *updatedComment =  [theComment stringByReplacingOccurrencesOfString:@" " withString:@"+"];
    NSString *updatedComment = [theComment stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSString *newURL = [NSString stringWithFormat:@"%@/cards/%@/actions/comments?key=%@&token=%@&text=%@", baseURL, cardID, apiKey, sessionToken, updatedComment];
    //NSLog(@"newURL: %@", newURL);
    [request setURL:[NSURL URLWithString:newURL]];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    [self performSynchronousConnectionFromURLRequest:request];
}

- (NSArray *)cardCommentsFromCardNamed:(NSString *)cardName inBoard:(NSString *)boardName
{
    NSArray *commentArray = nil;
    NSDictionary *boardDict = [[trelloData objectForKey:@"boards"] objectForKey:boardName];
    NSArray *cards = [boardDict valueForKey:@"cards"];
    NSDictionary *cardItem = [[cards filteredArrayUsingPredicate:
                               [NSPredicate predicateWithFormat:@"(SELF.name == %@)", cardName]] lastObject];
    NSString *cardID = [cardItem objectForKey:@"id"];
    if (cardID != nil)
    {
        commentArray = [self cardCommentsFromCardID:cardID];
    }
    return commentArray;
}

- (NSArray *)cardCommentsFromCardID:(NSString *)cardID
{
    NSString *cardCommentURL = [NSString stringWithFormat:@"%@/cards/%@/actions?filter=commentCard&key=%@&token=%@", baseURL, cardID, apiKey, sessionToken];
    return (NSArray *)[self dictionaryFromURLString:cardCommentURL];
}

+ (NSString *)UTCDateFromDate:(NSDate *)theDate
{
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    [df setTimeZone:[NSTimeZone timeZoneWithName:@"UTC"]];
    [df setDateFormat:NEW_DATE_FORMAT];
    NSString *dayFormatted = [df stringFromDate:theDate];
    [df setDateFormat:HOUR_FORMAT];
    NSString *hourFormatted = [df stringFromDate:theDate];
    NSString *formatString = [NSString stringWithFormat:@"%@T%@.000Z", dayFormatted, hourFormatted];
    return formatString;
}

- (void)setDueDate:(NSString *)dueDate forCardWithName:(NSString *)cardName inBoardNamed:(NSString *)boardName
{
    NSString *cardID = [[self cardWithName:cardName inBoardNamed:boardName] valueForKey:@"id"];
    NSLog(@"cardID: %@", cardID);
    [self setDueDate:dueDate forCardWithID:cardID];
}

- (void)setDueDate:(NSString *)dueDate forCardWithID:(NSString *)theCard
{
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    NSString *newURL = [NSString stringWithFormat:@"%@/cards/%@/due?key=%@&token=%@&value=%@", baseURL, theCard, apiKey, sessionToken, dueDate];
    //NSLog(@"newURL: %@", newURL);
    [request setURL:[NSURL URLWithString:newURL]];
    [request setHTTPMethod:@"PUT"];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    
    [self performSynchronousConnectionFromURLRequest:request];
    
}



@end
