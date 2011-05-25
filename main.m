//
//  main.m
//  wowchat
//
//  Created by jrk on 26/5/10.
//  Copyright 2010 flux forge. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Foundation/foundation.h>
#import <SecurityFoundation/SFAuthorization.h>
#import <Security/AuthorizationTags.h>

#define PGLog(...) ((![[[NSUserDefaults standardUserDefaults] objectForKey: @"SecurityDisableLogging"] boolValue]) ? NSLog(__VA_ARGS__) : NULL )

bool amIWorthy(void);
void authMe(char * FullPathToMe);



int acquireTaskportRight() 
{
	
	OSStatus stat;
	AuthorizationItem taskport_item[] = {{"system.privilege.taskport"}};
	AuthorizationRights rights = {1, taskport_item}, *out_rights = NULL;
	AuthorizationRef author;
	int retval = 0;
	
	AuthorizationFlags auth_flags =  kAuthorizationFlagExtendRights |  kAuthorizationFlagPreAuthorize | kAuthorizationFlagInteractionAllowed | ( 1 << 5); 
	
	stat = AuthorizationCreate (NULL, kAuthorizationEmptyEnvironment,auth_flags,&author);
	
	if (stat != errAuthorizationSuccess) {
		return 0;
	}
	
	stat = AuthorizationCopyRights ( author,  &rights,  kAuthorizationEmptyEnvironment, auth_flags,&out_rights);
	
	if (stat != errAuthorizationSuccess) {
		printf("fail");
		return 1;
	}
	return 0;
}



int main(int argc, char *argv[])
{
	int infoPid = 98943;
	kern_return_t kret;
	mach_port_t task;
	thread_act_port_array_t threadList;
	mach_msg_type_number_t threadCount;
	x86_thread_state32_t state;
	
	/*int uid = getuid();
	if (amIWorthy() || uid == 0) 
	{
		printf("It's go time.\n"); // signal back to close caller
        fflush(stdout);
		
		PGLog(@"lol ficken");
    } 
	else 
	{
    	authMe(argv[0]);
        return 0; 
    }*/

	if (acquireTaskportRight()!=0) 
	{
		printf("acquireTaskportRight() failed!\n");
		exit(0);
	}     
	

	kret = task_for_pid(mach_task_self(), infoPid, &task);
	if (kret!=KERN_SUCCESS) 
	{
		printf("task_for_pid() failed with message %s!\n",mach_error_string(kret));
		exit(0);
	}
	
	NSLog(@"the task id is: %i", task);
	
    return NSApplicationMain(argc,  (const char **) argv);
}


bool amIWorthy(void)
{
	// running as root?
	AuthorizationRef myAuthRef;
	OSStatus stat = AuthorizationCopyPrivilegedReference(&myAuthRef, kAuthorizationFlagDefaults);
    BOOL success = (stat == errAuthorizationSuccess);
	
	return success;
}

void authMe(char * FullPathToMe)
{
	// get authorization as root
	OSStatus myStatus;
	
	// set up Authorization Item
	AuthorizationItem myItems[1];
	myItems[0].name = kAuthorizationRightExecute;
	myItems[0].valueLength = 0;
	myItems[0].value = NULL;
	myItems[0].flags = 0;
	
	// Set up Authorization Rights
	AuthorizationRights myRights;
	myRights.count = sizeof (myItems) / sizeof (myItems[0]);
	myRights.items = myItems;
	
	// set up Authorization Flags
	AuthorizationFlags myFlags;
	myFlags =
	kAuthorizationFlagDefaults |
	kAuthorizationFlagInteractionAllowed |
	kAuthorizationFlagExtendRights;
	
	// Create an Authorization Ref using Objects above. NOTE: Login bod comes up with this call.
	AuthorizationRef myAuthorizationRef;
	myStatus = AuthorizationCreate (&myRights, kAuthorizationEmptyEnvironment, myFlags, &myAuthorizationRef);
	
	if (myStatus == errAuthorizationSuccess)
	{
		// prepare communication path - used to signal that process is loaded
		FILE *myCommunicationsPipe = NULL;
		char myReadBuffer[256];
        
		// run this app in GOD mode by passing authorization ref and comm pipe (asynchoronous call to external application)
		myStatus = AuthorizationExecuteWithPrivileges(myAuthorizationRef, FullPathToMe, kAuthorizationFlagDefaults, nil, &myCommunicationsPipe);
        
		// external app is running asynchronously - it will send to stdout when loaded
		if (myStatus == errAuthorizationSuccess)
		{
            
#ifdef PGLOGGING
            for(;;) { 
                int bytesRead = read(fileno(myCommunicationsPipe), myReadBuffer, sizeof(myReadBuffer)); 
                if (bytesRead < 1) { // < 1
                    break; 
                }
                write(fileno(stdout), myReadBuffer, bytesRead); 
                fflush(stdout);
            }
#else
			read(fileno(myCommunicationsPipe), myReadBuffer, sizeof(myReadBuffer));
#endif
            fclose(myCommunicationsPipe);
		}
		
		// release authorization reference
		myStatus = AuthorizationFree (myAuthorizationRef, kAuthorizationFlagDestroyRights);
	}
}

