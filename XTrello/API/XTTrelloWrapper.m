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


- (void)loadPreviousData
{
    if ([[NSFileManager defaultManager] fileExistsAtPath:[XTModel boardsDataStoreFile]])
    {
        NSDictionary *cachedData = [NSDictionary dictionaryWithContentsOfFile:[XTModel boardsDataStoreFile]];
        //NSLog(@"cachedData: %@", cachedData);
        //[delegate trelloDataFetched:cachedData];
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

/*
 
 meat and potatoes, it takes in a URL string, gets it as raw UTF8 string data, converts to JSON, strips out NSNull from all
 dictionaries and arrays, and returns the results NSArray or NSDictionary
 
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

/*
 
 these 4 methods are all predicated on us already having the trello data
 
 */

- (NSArray *)usefulLabelArray:(NSArray *)labelArray
{
    NSMutableArray *newArray = [[NSMutableArray alloc] init];
    for (NSDictionary *labelDict in labelArray)
    {
        [newArray addObject:labelDict[@"color"]];
    }
    return newArray;
}

- (NSDictionary *)addCardToBoard:(NSString *)boardName inList:(NSString *)listName withName:(NSString *)cardName
{
    return [self addCardToBoard:boardName inList:listName withName:cardName inPosition:nil];
}

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


- (NSDictionary *)deleteCard:(NSDictionary *)theCard inBoardNamed:(NSString *)boardName
{
    NSMutableDictionary *boardDict = [[self boardNamed:boardName] mutableCopy];
    NSMutableArray *cards = [[boardDict valueForKey:@"cards"] mutableCopy];
    NSString *cardID = theCard[@"id"];
    
    [self deleteCardWithID:cardID];
    
    [cards removeObject:theCard];
    [boardDict setObject:cards forKey:@"cards"];
    [[self.trelloData objectForKey:@"boards"] setObject:boardDict forKey:boardName];
    
    [self.trelloData writeToFile:[XTModel boardsDataStoreFile] atomically:TRUE];
    
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
     NSLog(@"replacing: %@ with: %@", [cards objectAtIndex:objectIndex], newCard);
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
    // [[newCard objectForKey:@"idMembers"] addObject:memberID];
     NSLog(@"replacing: %@ with: %@", [cards objectAtIndex:objectIndex], newCard);
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
    
    //stuff below is deprecated, the labels are updated directly in XTTrelloCardView
   /*
    

    
    NSArray *labelArray = [self usefulLabelArray:theList];
    NSString *cardID = theCard[@"id"];
    NSLog(@"setting labels: %@ forCard: %@", labelArray, cardID);
   
    [self setLabels:labelArray forCardWithID:cardID];
    */
    
    return trelloData;
}

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

/*
 
 all of these are to make interacting with trello as painless as possible, making it possible to do any
 standard task just based on names of cards, lists, boards, etc.
 
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
        NSLog(@"labelString was nil, set it to original color!");
        labelString = colorName; //maybe its already a color?
        
        NSLog(@"labelString: %@", labelString);
    }
    
    
    return labelString;
}



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

//card id: 53bdbee3ff37f89db20605dd memberID:53bc57917e03ddc07178eff8

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
    //https://trello.com/1/cards/53be23b72a746fdf45de45b3/actions?filter=commentCard&key=KEY&token=TOKEN
    NSString *cardCommentURL = [NSString stringWithFormat:@"%@/cards/%@/actions?filter=commentCard&key=%@&token=%@", baseURL, cardID, apiKey, sessionToken];
    return (NSArray *)[self dictionaryFromURLString:cardCommentURL];
}

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

//["54713df774d650d567621195","54713df774d650d567621194","54713df774d650d567621196"]

- (void)deleteLabelID:(NSString *)labelID forCardWithID:(NSString *)theCard
{
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    NSString *newURL = [NSString stringWithFormat:@"%@/cards/%@/idLabels/%@?key=%@&token=%@", baseURL, theCard, labelID,apiKey, sessionToken];
     NSLog(@"newURL: %@", newURL);
    [request setURL:[NSURL URLWithString:newURL]];
    [request setHTTPMethod:@"DELETE"];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    
    [self performSynchronousConnectionFromURLRequest:request];
    
}

- (void)addLabelID:(NSString *)labelID forCardWithID:(NSString *)theCard
{
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    NSString *newURL = [NSString stringWithFormat:@"%@/cards/%@/idLabels?key=%@&token=%@&value=%@", baseURL, theCard, apiKey, sessionToken, labelID];
    NSLog(@"newURL: %@", newURL);
    [request setURL:[NSURL URLWithString:newURL]];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    
    [self performSynchronousConnectionFromURLRequest:request];
    
}

- (void)setLabels:(NSArray *)theLabels forCardWithID:(NSString *)theCard
{
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    // NSString *labelsString = [theLabels componentsJoinedByString:@","];
    NSString *labelsString = [self colorStringFromLabelArray:theLabels];
    NSString *newURL = [NSString stringWithFormat:@"%@/cards/%@/labels?key=%@&token=%@&value=%@", baseURL, theCard, apiKey, sessionToken, labelsString];
    NSLog(@"newURL: %@", newURL);
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


//due

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

- (NSDictionary *)createBoardWithName:(NSString *)boardName inOrganization:(NSString *)orgName
{
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    NSString *newURL = [NSString stringWithFormat:@"%@/boards?name=%@&idOrganization=%@&key=%@&token=%@&prefs_permissionLevel=org", baseURL, boardName,orgName, apiKey, sessionToken];
    //NSLog(@"newURL: %@", newURL);
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

- (NSDictionary *)performSynchronousConnectionFromURLRequest:(NSMutableURLRequest *)request
{
    NSHTTPURLResponse *theResponse = nil;
    NSData *returnData = [NSURLConnection sendSynchronousRequest:request returningResponse:&theResponse error:nil];
    NSString *datString = [[NSString alloc] initWithData:returnData  encoding:NSUTF8StringEncoding];
  //  NSLog(@"response: %@", datString);
    NSDictionary *responseDict = [self dictionaryFromJSONStringResponse:datString];
    if (responseDict == nil){
        responseDict = datString;
    }
    NSDictionary *returnDict = @{@"response": responseDict, @"statusCode": [NSString stringWithFormat:@"%li", (long)[theResponse statusCode]]};
    NSLog(@"returnDict: %@", returnDict);
    if ([theResponse statusCode] != 200)
    {
        NSLog(@"response: %@ withStatus Code: %li", datString, (long)[theResponse statusCode]);
        
    }
    return returnDict;
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


- (void)fetchTrelloData
{
    if (self.apiKey == nil || self.sessionToken == nil) return;
    startDate = [NSDate date];
    [NSThread detachNewThreadSelector:@selector(fetchTrelloDataThreaded) toTarget:self withObject:nil];
}

- (NSDictionary *)labelDictionaryFromColor:(NSString *)colorName inBoardNamed:(NSString *)boardName
{
    NSLog(@"colorName: %@", colorName);
    NSDictionary *currentBoard = [self boardNamed:boardName];
    NSArray *labels = [currentBoard valueForKey:@"labels"];
    NSDictionary *theLabel = [[labels filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"(SELF.color == %@)", colorName]] lastObject];
    return theLabel;
    
}

- (void)fetchTrelloDataThreaded
{
    @autoreleasepool {
        //NSArray *commentTest = [self cardCommentsFromCardID:@"53be23b72a746fdf45de45b3"];
        //NSLog(@"comments test: %@", commentTest);
        NSMutableDictionary *trelloDict = [[NSMutableDictionary alloc] init];
        NSString *boards = [NSString stringWithFormat:@"%@/members/me/boards?key=%@&token=%@", baseURL, apiKey, sessionToken];
        NSString *me = [NSString stringWithFormat:@"%@/members/me?key=%@&token=%@", baseURL, apiKey, sessionToken];
       // NSString *myCards = [NSString stringWithFormat:@"%@/members/my/cards?key=%@&token=%@", baseURL, apiKey, sessionToken];
        //NSLog(@"boards: %@", boards);
        NSArray *jsonBoards = (NSArray *)[self dictionaryFromURLString:boards];
        NSDictionary *jsonMe = [self dictionaryFromURLString:me];
        
        NSArray *myOrgs = jsonMe[@"idOrganizations"];
        
        NSString *myAvatar = jsonMe[@"avatarHash"];
        NSImage *myBigAvatar = [self bigAvatarFromHash:myAvatar];
        
        [[myBigAvatar TIFFRepresentation] writeToFile:[NSHomeDirectory() stringByAppendingPathComponent:@"Desktop/kevin.png"] atomically:TRUE];
        
        
        NSMutableArray *orgArray = [[NSMutableArray alloc] init];
        for (NSString *org in myOrgs)
        {
            NSDictionary *orgDict = [self organizationWithNameOrID:org];
            [orgArray addObject:orgDict];
        }
        NSMutableDictionary *meEditable = [jsonMe mutableCopy];
        if ([orgArray count] > 0)
        {
            [meEditable setObject:orgArray forKey:@"organizations"];
        }
        
      //  NSDictionary *jsonCards = [self dictionaryFromURLString:myCards];
        NSMutableDictionary *updatedBoards = [[NSMutableDictionary alloc] init];
        for (NSDictionary *currentBoard in jsonBoards)
        {
            if ([currentBoard[@"closed"] boolValue] == FALSE)
            {
                NSMutableDictionary *newBoard = [currentBoard mutableCopy];
                NSString *boardID = [currentBoard objectForKey:@"id"];
                NSString *name = [currentBoard objectForKey:@"name"];
                NSString *currentLabelNamesURL = [NSString stringWithFormat:@"%@/boards/%@/labelNames?key=%@&token=%@", baseURL, boardID, apiKey, sessionToken];
                
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
                    //https://trello.com/1/members/53bb7a84bc95e5f6e6afcaa5?key=KEY&token=TOKEN
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
        [trelloDict setObject:updatedBoards forKey:@"boards"];
        [trelloDict setObject:meEditable forKey:@"me"];
     //   [trelloDict setObject:jsonCards forKey:@"cards"];
      //  NSString *sampleDictPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Desktop/Sciencely.plist"];
        
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
    [NSThread detachNewThreadSelector:@selector(fetchTrelloDataThreaded) toTarget:self withObject:nil];
}


/*
 {"id":"ORGID","name":"XTrelloTest","desc":"","descData":null,"closed":false,"idOrganization":"ORGID","pinned":true,"url":"https://trello.com/b/peenlU3U/xtrellotest","shortUrl":"https://trello.com/b/peenlU3U","prefs":{"permissionLevel":"org","voting":"disabled","comments":"members","invitations":"members","selfJoin":false,"cardCovers":true,"cardAging":"regular","calendarFeedEnabled":false,"background":"blue","backgroundColor":"#23719F","backgroundImage":null,"backgroundImageScaled":null,"backgroundTile":false,"backgroundBrightness":"unknown","canBePublic":true,"canBeOrg":true,"canBePrivate":true,"canInvite":true},"labelNames":{"red":"","orange":"","yellow":"","green":"","blue":"","purple":""}} withStatus Code: 200
 */

- (void)createNewTemplateBoardWithName:(NSString *)boardName
{
    NSDictionary *newBoard = [self createBoardWithName:boardName inOrganization:@""];
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
    
    [self createCardWithName:[self initialNoteForType:XTToDoType] toListWithID:toDoID];
    [self createCardWithName:[self initialNoteForType:XTBugsType] toListWithID:bugsID];
    [self createCardWithName:[self initialNoteForType:XTBlockedType] toListWithID:blockedID];
    [self createCardWithName:[self initialNoteForType:XTDoneType] toListWithID:doneID];
    [self createCardWithName:[self initialNoteForType:XTBacklogType] toListWithID:backlogID];
    
    [self setDefaultLabelsForBoardID:boardID];
}

@end
