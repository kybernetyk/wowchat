//
//  wowchatAppDelegate.h
//  wowchat
//
//  Created by jrk on 26/5/10.
//  Copyright 2010 flux forge. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface wowchatAppDelegate : NSObject <NSApplicationDelegate> 
{
    NSWindow *window;
	IBOutlet NSTableView *tableView;
	int pass;
	
	
	NSMutableArray *chatLogToDisplay;
	
	NSMutableArray *guildLog;
	
	BOOL canAddToTwitterQueue;
}

@property (readwrite, copy) NSMutableArray *guildLog;
@property (readwrite, copy) NSMutableArray *chatLogToDisplay;

@property (assign) IBOutlet NSWindow *window;

- (IBAction) lolDo: (id) sender;

@end
