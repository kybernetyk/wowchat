//
//  wowchatAppDelegate.m
//  wowchat
//
//  Created by jrk on 26/5/10.
//  Copyright 2010 flux forge. All rights reserved.
//

#import "wowchatAppDelegate.h"
#import "ChatLogEntry.h"

#include <mach/vm_map.h>
#include <mach/mach_traps.h>

#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netdb.h>
#include <string.h>
#include <unistd.h>
#include <stdio.h>

#define WOW_PID 98943
#define CHATLOG_OFFSET 0xD388BC

#define ChatLog_CounterOffset       0x8
#define ChatLog_TimestampOffset     0xC
#define ChatLog_UnitGUIDOffset      0x10
#define ChatLog_UnitNameOffset      0x1C
#define ChatLog_UnitNameLength      0x30
#define ChatLog_DescriptionOffset   0x4C
#define ChatLog_NextEntryOffset     0x17BC
#define ChatLog_TextOffset 0xBB8

#define NS_DURING		@try {
#define NS_HANDLER		} @catch (NSException *localException) {
#define NS_ENDHANDLER		}
#define NS_VALUERETURN(v,t)	return (v)
#define NS_VOIDRETURN		return

#define LEN 400

#define SERVER @"funblog.me"
#define PORT 0x9000
#define SOCKET_ERROR        -1
#define BUFFER_SIZE 1024

#import "MGTwitterEngine.h"

@implementation wowchatAppDelegate

@synthesize window;
@synthesize chatLogToDisplay;
@synthesize guildLog;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification 
{
	pass = 0;
	
	NSLog(@"hi!");
}

- (BOOL) sendUpdateToSocketServer: (NSString *) updateString server:(NSString *)server port: (unsigned short) port
{
	int hSocket;                 /* handle to socket */
    struct hostent* pHostInfo;   /* holds info about a machine */
    struct sockaddr_in Address;  /* Internet socket address stuct */
    long nHostAddress;
    char pBuffer[BUFFER_SIZE];
    unsigned nReadAmount;
    char *strHostName = [server cStringUsingEncoding: NSUTF8StringEncoding];
    int nHostPort = port;
	
	
    printf("\nMaking a socket");
    /* make a socket */
    hSocket=socket(AF_INET,SOCK_STREAM,IPPROTO_TCP);
	
    if(hSocket == SOCKET_ERROR)
    {
        printf("\nCould not make a socket\n");
        return NO;
    }
	
    /* get IP address from name */
    pHostInfo=gethostbyname(strHostName);
    /* copy address into long */
    memcpy(&nHostAddress,pHostInfo->h_addr,pHostInfo->h_length);
	
    /* fill address struct */
    Address.sin_addr.s_addr=nHostAddress;
    Address.sin_port=htons(nHostPort);
    Address.sin_family=AF_INET;
	
    printf("\nConnecting to %s on port %d",strHostName,nHostPort);
	
    /* connect to host */
    if(connect(hSocket,(struct sockaddr*)&Address,sizeof(Address)) == SOCKET_ERROR)
    {
        printf("\nCould not connect to host\n");
        return NO;
    }
	
    /* read from socket into buffer
	 ** number returned by read() and write() is the number of bytes
	 ** read or written, with -1 being that an error occured */
    nReadAmount=read(hSocket,pBuffer,BUFFER_SIZE);
    printf("\nReceived \"%s\" from server\n",pBuffer);
    /* write what we received back to the server */

    
	memset(pBuffer,0x00,BUFFER_SIZE);
	strcpy(pBuffer, [updateString cStringUsingEncoding: NSUTF8StringEncoding]);
	
	write(hSocket,pBuffer,strlen(pBuffer));
    printf("\nWriting \"%s\" to server",pBuffer);
	
    printf("\nClosing socket\n");
    /* close socket */                       
    if(close(hSocket) == SOCKET_ERROR)
    {
        printf("\nCould not close socket\n");
        return NO;
    }
	
	return YES;
}

- (IBAction) lolDo: (id) sender
{
    mach_port_t wowTask;
	task_for_pid(current_task(), WOW_PID, &wowTask);
	
	NSMutableArray *chatLogArray = [[NSMutableArray alloc] initWithCapacity: 60];
	
	UInt32 i;
	UInt32 highestSequence = 0, foundAt = 0, finishedAt = 0;
	for (i = 0; i < 60; i++)
	{
         finishedAt = i;
		char *buffer = malloc(LEN);
		memset(buffer,0x00,LEN);
		vm_size_t length = LEN-1;
		vm_size_t bytesRead = 0;

		UInt32 logStart = CHATLOG_OFFSET + ChatLog_NextEntryOffset*i;
		//NSLog(@"%i: %i",i, logStart);
		//printf("%i: %i",i,logStart);
		bool memSuccess = false;
		
		
		memSuccess = ((KERN_SUCCESS == vm_read_overwrite(wowTask, logStart, length, buffer, &bytesRead)) && (bytesRead == length) );

		if(memSuccess) 
		{
			UInt32 sequence = *(UInt32*)(buffer + ChatLog_CounterOffset);
			
			// track highest sequence number
			if(sequence > highestSequence) 
			{
				highestSequence = sequence;
				foundAt = i;
			}
			
			
		/*	//lol creating a data will give us fucked up utf strings with escaped control chars :[
			CFDataRef memoryContents = CFDataCreate(NULL, buffer, length);
			if(memoryContents) 
			{
				NSData *data = memoryContents;
				//NSString *str = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
				NSString *str = [NSString stringWithUTF8String: data];*/
		
			NSString *str = [NSString stringWithUTF8String: buffer];
			
			if (str)
			{
				if (str)
				{
				//	NSLog(@"str[len=%i]:%@",[str length],str);
					
					NSMutableDictionary *chatComponents = [NSMutableDictionary dictionary];
                    for(NSString *component in [str componentsSeparatedByString: @"], "]) 
					{
                        NSArray *keyValue = [component componentsSeparatedByString: @": ["];
                        // "Text: [blah blah blah]"
                        if([keyValue count] == 2) 
						{
                            // now we have "key" and "[value]"
                            NSString *key = [keyValue objectAtIndex: 0];
                            NSString *value = [keyValue objectAtIndex: 1];  //[[keyValue objectAtIndex: 1] stringByTrimmingCharactersInSet: [NSCharacterSet characterSetWithCharactersInString: @"[]"]];
							
							NSString *trimmedValue = [value stringByTrimmingCharactersInSet: [NSCharacterSet characterSetWithCharactersInString: @"[]"]];
                            [chatComponents setObject: trimmedValue forKey: key];
							
							
							//NSLog(@"key: %@, value[len=%i]: %@",key,[value length],value);
//							NSLog(@"trimmed value[len=%i]: %@",[trimmedValue length],trimmedValue);
                        } 
						else 
						{
                            // bad data
                            //log(LOG_GENERAL, @"Throwing out bad data: \"%@\"", component);
                        }
                    }
                    if([chatComponents count]) 
					{
                        ChatLogEntry *newEntry = [ChatLogEntry entryWithSequence: i timeStamp: sequence attributes: chatComponents];
                        if(newEntry) 
						{
       						[chatLogArray addObject: newEntry];
                        }
//						[chatComponents setObject: [NSNumber numberWithInteger: i] forKey: @"sequence"];
//						[chatComponents setObject: [NSNumber numberWithInteger: sequence] forKey: @"timestamp"];
//						[chatLogArray addObject: chatComponents];
                    }
				}
				else 
				{
					//break;	
				}

					
			//	NSLog(@"we got memory!");
			//	NSLog(@"data length %i",[data length]);
			//	NSLog(@"string we got: %@",str);
				
		//		[str release];
		//		CFRelease(memoryContents);
			}
		}
		else 
		{
			NSLog(@"we wanted %i bytes but only got %i", length, bytesRead);	
			break;
		}
		
		free(buffer);
	}
	
	//NSLog(@"got total awesome %i entries ...", i);
//	NSLog(@"%@",chatLogArray);
	
	for(ChatLogEntry *entry in chatLogArray) 
	{
		[entry setPassNumber: 0];
		NSUInteger sequence = [[entry sequence] unsignedIntegerValue];
		if(sequence >= foundAt) 
		{
			[entry setRelativeOrder: sequence - foundAt];
		}
		else 
		{
			[entry setRelativeOrder: 60 - foundAt + sequence];
		}
	}
	//[chatLogArray sortUsingDescriptors: [NSArray arrayWithObject: _relativeOrderSortDescriptor]];
	
	
/*	for(NSMutableDictionary *entry in chatLogArray) 
	{
		//[entry setPassNumber: passNumber];
		//[entry setObject: [NSNumber numberWithInteger: passNumber] forKey: @"passNumber"];
		
		NSUInteger sequence = [[entry objectForKey: @"sequence"] unsignedIntegerValue];
		if(sequence >= foundAt) 
		{
			[entry setObject: [NSNumber numberWithInteger: (sequence - foundAt)] forKey: @"relativeOrder"];
			
		} else 
		{
			[entry setObject: [NSNumber numberWithInteger: (60 - foundAt + sequence)] forKey: @"relativeOrder"];
		}
	}*/
	
	
 	NSSortDescriptor *sortDesc = [[NSSortDescriptor alloc] initWithKey: @"relativeOrder" ascending: YES];
	
	[chatLogArray sortUsingDescriptors: [NSArray arrayWithObject: sortDesc]];
	
	NSMutableArray *outArray = [NSMutableArray array];
	
	for(ChatLogEntry *entry in chatLogArray) 
	{
		NSString *lol = [entry description];
		[outArray addObject: entry];
	}
	
	//[outArray writeToFile: @"/bla.plist" atomically: YES];
	
	
//	NSMutableArray *diff = [NSMutableArray arrayWithArray: [self currentChatlog]];
//	[diff removeObjectsInArray: [self previousChatlog]];
	
//	NSLog(@"diff: %@",diff);
	
	if (![self chatLogToDisplay])
		chatLogToDisplay = [[NSMutableArray alloc] initWithCapacity: 60];
	
	if (![self guildLog])
		guildLog = [[NSMutableArray alloc] initWithCapacity: 60];
	
	for (ChatLogEntry *entry in outArray)
	{
		if (![[self chatLogToDisplay] containsObject: entry])
		{
			[[self chatLogToDisplay] addObject: entry];
			
			
			
			

			//if ([[entry type] integerValue] == 4) //GUILD!
			if ([entry isChannel])
			{
				if (pass > 0) //don't add the old trash entries!
				{	
					
					NSLog(@"adding: %@ %@ %@", [entry type],[entry playerName],[entry text]);
					[guildLog addObject: entry];
					
				}
			}

		}
	}
	
	
//	NSArray *newDisplayLog = [[self chatLogToDisplay] arrayByAddingObjectsFromArray: diff];
	
//	[self setChatLogToDisplay: newDisplayLog];

//	NSLog(@"guild log: %@",guildLog);
	
	[tableView reloadData];
	
	[tableView scrollRowToVisible: [chatLogToDisplay count] - 1];
	
	[chatLogArray release];
	
	pass ++;
	
	//dispatch guild chat to twitter
	if ([guildLog count] > 0)
	{
		NSLog(@"dispatching to twitter: %@", [guildLog objectAtIndex: 0] );
		
		for (ChatLogEntry *entry in guildLog)
		{
			NSString *update = [NSString stringWithFormat: @"<%@> [%@] [%@]: %@\n",[entry dateStamp], [entry channel] ,[entry playerName],[entry text]];
			[self sendUpdateToSocketServer: update server: SERVER port: PORT];
		}
		
		[guildLog removeAllObjects];
		
		/*ChatLogEntry *entry = [guildLog objectAtIndex: 0];
		
		// Create a TwitterEngine and set our login details.
		MGTwitterEngine *twitterEngine = [[MGTwitterEngine alloc] initWithDelegate:self];
		[twitterEngine setClearsCookies: YES];
		[twitterEngine setUsesSecureConnection: YES];
		[twitterEngine setClientName:@"µTweet" version:@"0.1" URL:@"http://www.fluxforge.com" token:@"mutweet"];
		
		[twitterEngine setUsername: @"heretic_gchat" password: @"warbird"];
		
		
		NSString *update = [NSString stringWithFormat: @"<%@> [%@] %@\n",[entry dateStamp] ,[entry playerName],[entry text]];
		[guildLog removeObjectAtIndex: 0];
		
		//[twitterEngine sendUpdate: update];
		
		
		//the server
		[self sendUpdateToSocketServer: update server: SERVER port: PORT];
		[self performSelector: @selector(lolDo:) withObject: nil afterDelay: 1.0];
		
		[twitterEngine autorelease];*/
		
	}
	else 
	{
		
	}
	
	[self performSelector: @selector(lolDo:) withObject: nil afterDelay: 2.0];

}

#pragma mark -
#pragma mark MGTwitterEngineDelegate methods
- (void)requestSucceeded:(NSString *)connectionIdentifier
{
	NSLog(@"twitter shit sent ... let's get another one!");
	[self performSelector: @selector(lolDo:) withObject: nil afterDelay: 2.0];
}


- (void)requestFailed:(NSString *)connectionIdentifier withError:(NSError *)error
{
	NSLog(@"twitter shit failed with error %@ ...",[error localizedDescription]);
	[self performSelector: @selector(lolDo:) withObject: nil afterDelay: 2.0];
}


- (void)statusesReceived:(NSArray *)statuses forRequest:(NSString *)connectionIdentifier
{
}


- (void)directMessagesReceived:(NSArray *)messages forRequest:(NSString *)connectionIdentifier
{
	//	  NSLog(@"Got direct messages for %@:\r%@", connectionIdentifier, messages);
}


- (void)userInfoReceived:(NSArray *)userInfo forRequest:(NSString *)connectionIdentifier
{
	//  NSLog(@"Got user info for %@:\r%@", connectionIdentifier, userInfo);
}


- (void)miscInfoReceived:(NSArray *)miscInfo forRequest:(NSString *)connectionIdentifier
{
	//	NSLog(@"Got misc info for %@:\r%@", connectionIdentifier, miscInfo);
}

- (void)searchResultsReceived:(NSArray *)searchResults forRequest:(NSString *)connectionIdentifier
{
	//	NSLog(@"Got search results for %@:\r%@", connectionIdentifier, searchResults);
}


- (void)imageReceived:(NSImage *)image forRequest:(NSString *)connectionIdentifier
{
	// NSLog(@"Got an image for %@: %@", connectionIdentifier, image);
    
    // Save image to the Desktop.
    //NSString *path = [[NSString stringWithFormat:@"~/Desktop/%@.tiff", connectionIdentifier] stringByExpandingTildeInPath];
    //[[image TIFFRepresentation] writeToFile:path atomically:NO];
}

- (void)connectionFinished
{
/*	if ([twitterEngine numberOfConnections] == 0)
	{
		//NSLog(@"connection finished. %i open connections left ...",[twitterEngine numberOfConnections]);
		//[NSApp terminate:self];
	}*/
}


#pragma mark -
#pragma mark tableview stuff
- (int)numberOfRowsInTableView:(NSTableView *)aTableView 
{
//	NSLog(@"lol penis: %i",[[self chatLogToDisplay] count]);
	return [[self chatLogToDisplay] count];
}


- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex 
{
	ChatLogEntry *entry = [chatLogToDisplay objectAtIndex: rowIndex];
//	NSLog(@"printing[len = %i]: %@", [[entry text] length],[entry text]);
	
	return [NSString stringWithFormat: @"[%@] %@ %i", [entry dateStamp], [entry wellFormattedText], [[entry wellFormattedText] length]];
	
}

- (BOOL)tableView:(NSTableView *)aTableView shouldEditTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex 
{
    return NO;
}

@end
