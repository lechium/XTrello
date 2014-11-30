XTrello
=======

Xcode plugin for native Trello board access.

The initial setup process is a bit cumbersome, depending on the interest garnered in this plugin it will potentially be refined in the future.

Setup Process.

1. Create trello account (if you don't have one already) at trello.com
2. Open this project in Xcode and build (it will build into the proper location)
3. Quit and Re-Open XCode
4. View -> Trello -> Show Trello Boards (this will show the preferences window if API Key / Session Token is missing)
5. Click "Fetch Key"
6. This will open up https://trello.com/1/appKey/generate in the native XTrello browser window and SHOULD copy your API key automatically, if it does not you will need to copy and paste it manually
7. (only needed if step 6 fails) Copy and paste your API Key into the second text field in the XTrello preferences window (Trello Key)
8. Click "Generate Token" again
9. This will open the built in browser window in XTrello and ask you for permission for XTrello to access your trello boards
10. Click "Allow"
11. This should automatically populate the session token in the top text field (Trello Token) if it does not, copy and paste the session token (without the spaces) in the Trello Token text field.
12. View -> Trello -> Show Trello boards will now show your trello boards.
13. Enjoy!


Adding card labels

![alt text](add_labels.png "Editing card labels")

Creating cards referencing sections of source code

![alt text](create_source_card.png "Creating cards from source")

Double clicking a card native browser window

![alt text](browser_window.png "Browser window from card double click")
