//
//  AppDelegate.m
//  OCRuntime
//
//  Created by Nicolas Seriot on 6/14/13.
//  Copyright (c) 2013 Nicolas Seriot. All rights reserved.
//

#import "RTBAppDelegate.h"

#include <sys/types.h>
#include <sys/sysctl.h>

#import "RTBClassDisplayVC.h"
#import "ClassDisplay.h"
#import "ClassStub.h"
#import "HTTPServer.h"
#import "HTTPDataResponse.h"
#import "RTBMyIP.h"
#import "AllClasses.h"
#import "RTBObjectsTVC.h"

@implementation RTBAppDelegate

//- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
//{
//    // Override point for customization after application launch.
//    return YES;
//}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

//- (void)applicationWillTerminate:(UIApplication *)application
//{
//    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
//}


//- (RTBClassDisplayVC *)classDisplayVC {
//	if(_classDisplayVC == nil) {
//		self.classDisplayVC = [[RTBClassDisplayVC alloc] initWithNibName:@"RTBClassDisplayVC" bundle:nil];
//	}
//	return _classDisplayVC;
//}

- (void)useClass:(NSString *)className {
	
	[_objectsTVC.navigationController popToRootViewControllerAnimated:NO];
    
	Class klass = NSClassFromString(className);
	_objectsTVC.object = klass;
	
	//NSLog(@"-- objectViewController %@", objectViewController);
	
	_tabBarController.selectedIndex = 4;
}

- (NSString *)myIPAddress {
	NSString *myIP = [[[RTBMyIP sharedInstance] ipsForInterfaces] objectForKey:@"en0"];
	
#if TARGET_IPHONE_SIMULATOR
	if(!myIP) {
		myIP = [[[RTBMyIP sharedInstance] ipsForInterfaces] objectForKey:@"en1"];
	}
#endif
	
	return myIP;
}

- (NSObject<HTTPResponse> *)htmlIndex {
	NSMutableString *xhtml = [[NSMutableString alloc] init];
	
	[xhtml appendString:@"<HTML>\n<HEAD>\n<TITLE>iPhone OS Runtime Browser</TITLE>\n</HEAD>\n<BODY>\n"];
	
	NSArray *classes = [_allClasses sortedClassStubs];
	for(ClassStub *cs in classes) {
		[xhtml appendFormat:@"<A HREF=\"%@.h\">%@.h</A><BR />\n", cs.stubClassname, cs.stubClassname];
	}
    
	[xhtml appendString:@"</BODY>\n</HTML>\n"];
    
	NSData *data = [xhtml dataUsingEncoding:NSISOLatin1StringEncoding];
	
	return [[HTTPDataResponse alloc] initWithData:data];
}

- (NSObject<HTTPResponse> *)responseForPath:(NSString *)path {
	if([path isEqualToString:@"/"]) {
		return [self htmlIndex];
	}
	
	NSString *fileName = [path length] ? [path substringFromIndex:1] : @"";
	NSString *className = [fileName stringByDeletingPathExtension];
	
	ClassDisplay *cd = [ClassDisplay classDisplayWithClass:NSClassFromString(className)];
	
	NSString *header = [cd header];
	
	NSData *data = [header dataUsingEncoding:NSISOLatin1StringEncoding];
	
	return [[HTTPDataResponse alloc] initWithData:data];
}

- (void)startWebServer {
	NSDictionary *ips = [[RTBMyIP sharedInstance] ipsForInterfaces];
	BOOL isConnectedThroughWifi = [ips objectForKey:@"en0"] != nil;
	
	if(isConnectedThroughWifi || TARGET_IPHONE_SIMULATOR) {
		self.httpServer = [[HTTPServer alloc] init];
		[_httpServer setType:@"_http._tcp."];
		[_httpServer setPort:10000];
		
		NSError *error;
		BOOL success = [_httpServer start:&error];
		
		if(success == NO) {
			NSLog(@"Error starting HTTP Server.");
			
			if(error) {
				UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error starting HTTP Server"
																message:[error localizedDescription]
															   delegate:nil
													  cancelButtonTitle:@"OK"
													  otherButtonTitles:nil];
				[alert show];
			}
			[_httpServer stop];
			self.httpServer = nil;
		} else {
			[UIApplication sharedApplication].idleTimerDisabled = YES; // prevent sleep
		}
	} else {
		// TODO: allow USB connection..
		NSLog(@"Not connected through wifi, don't start web server.");
	}
}

/*
 + (NSString *)hardwareModel
 {
 static NSString *hardwareModel = nil;
 if (!hardwareModel) {
 char buffer[128];
 size_t length = sizeof(buffer);
 if (sysctlbyname("hw.model", &buffer, &length, NULL, 0) == 0) {
 hardwareModel = [[NSString allocWithZone:NULL] initWithCString:buffer encoding:NSASCIIStringEncoding];
 }
 if (!hardwareModel || [hardwareModel length] == 0) {
 hardwareModel = @"Unknown";
 }
 }
 return hardwareModel;
 }
 
 + (NSString *)computerModel
 {
 static NSString *computerModel = nil;
 if (!computerModel) {
 NSString *path, *hardwareModel = [self hardwareModel];
 if ((path = [[NSBundle mainBundle] pathForResource:@"Macintosh" ofType:@"dict"])) {
 computerModel = [[[NSDictionary dictionaryWithContentsOfFile:path] objectForKey:hardwareModel] copy];
 }
 if (!computerModel) {
 char buffer[128];
 size_t length = sizeof(buffer);
 if (sysctlbyname("hw.machine", &buffer, &length, NULL, 0) == 0) {
 computerModel = [[NSString allocWithZone:NULL] initWithCString:buffer encoding:NSASCIIStringEncoding];
 }
 }
 if (!computerModel || [computerModel length] == 0) {
 computerModel = [[NSString allocWithZone:NULL] initWithFormat:@"%@ computer model", hardwareModel];
 }
 }
 return computerModel;
 }
 */

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
//    [self.window setFrame:[[UIScreen mainScreen] bounds]];
	
	NSString *defaultsPath = [[NSBundle mainBundle] pathForResource:@"Defaults" ofType:@"plist"];
	NSDictionary *defaults = [NSDictionary dictionaryWithContentsOfFile:defaultsPath];
	[[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
	
	self.allClasses = [AllClasses sharedInstance];
	
	BOOL startWebServer = [[NSUserDefaults standardUserDefaults] boolForKey:@"StartWebServer"];
	
	if(startWebServer) {
		[self startWebServer];
	}
    
//    self.window.rootViewController = _tabBarController;
//    [self.window makeKeyAndVisible];
    
    return YES;
}

- (UInt16)serverPort {
	return [_httpServer port];
}

- (void)showHeaderForClassName:(NSString *)className {
//	[self classDisplayVC].className = className;
    
    UIStoryboard *sb = [UIStoryboard storyboardWithName:@"Main" bundle:[NSBundle mainBundle]];
    RTBClassDisplayVC *classDisplayVC = (RTBClassDisplayVC *)[sb instantiateViewControllerWithIdentifier:@"RTBClassDisplayVC"];
    classDisplayVC.className = className;
    
    UITabBarController *tabBarController = (UITabBarController *)self.window.rootViewController;
	[tabBarController presentViewController:classDisplayVC animated:YES completion:^{
        //
    }];
}

- (IBAction)dismissModalView:(id)sender {
	[_tabBarController dismissViewControllerAnimated:YES completion:^{
        //
    }];
}

/*
 // Optional UITabBarControllerDelegate method
 - (void)tabBarController:(UITabBarController *)tabBarController didSelectViewController:(UIViewController *)viewController {
 }
 */

/*
 // Optional UITabBarControllerDelegate method
 - (void)tabBarController:(UITabBarController *)tabBarController didEndCustomizingViewControllers:(NSArray *)viewControllers changed:(BOOL)changed {
 }
 */

- (void)applicationWillTerminate:(UIApplication *)application {
	if(_httpServer) {
		[_httpServer stop];
	}
}

@end
