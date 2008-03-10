//
//  wikilistAppDelegate.m
//  wikilist
//
//  Created by Matthew Sachs on 2008-03-08.
//  Copyright __MyCompanyName__ 2008. All rights reserved.
//

//TODO:
//	Name pages
//  Reorder pages
//  Delete pages
//	Implement sync
//	Implement preferences
//	Branding stuff (icons, app name, etc.)

#import "wikilistAppDelegate.h"
#import "FileListController.h"
#import "PageController.h"
#import "NewPageController.h"

static wikilistAppDelegate *SharedAppController = nil;

@implementation wikilistAppDelegate

@synthesize window;

+ (wikilistAppDelegate *)sharedController { return SharedAppController; }

- init {
	if (self = [super init]) {
		SharedAppController = self;
	}
	return self;
}

- (void)applicationDidFinishLaunching:(UIApplication *)application {
    // Create window
    self.window = [[[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]] autorelease];
	
	/*NSMutableArray *toolbarItems = [[NSMutableArray alloc] initWithCapacity:3];
	UIToolbarItem *toolbarItem;

	toolbarItem = [[UIToolbarItem alloc] initWithSystemItem:UIToolbarSystemItemNew target:self action:@selector(makeNew:)];
	[toolbarItems addObject:toolbarItem];
	[toolbarItem release];*/

	/* Main panel:       (*prefs*) (*sync*) (*add*)
	      List of notes: UITableView
	   Note panel: (UIButtonTypeNavigationBack)   Title   (*sync*) (*add)
			UITextView
	*/
	
	[[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithObject:@"" forKey:@"Page"]];
	
	fileList = [[FileListController alloc] init];
	navController = [[UINavigationController alloc] initWithRootViewController:fileList];
	
	UISegmentedControl *buttons = [[UISegmentedControl alloc]
		initWithItems:[NSArray arrayWithObjects:@"*", @"@", @"+", nil]];
	buttons.segmentedControlStyle = UISegmentedControlStyleBar;
	buttons.momentary = YES;
	[buttons addTarget:self action:@selector(clickedButton:) forControlEvents:UIControlEventValueChanged];

	navController.topViewController.navigationItem.customRightView = buttons;

	//CGSize imageSize = CGSizeMake(100, 46);
	//fileListController.toolbarItem.image = ...;
	//[viewControllers addObject:fileList];
	
    // Show the window with table view
	//toolbar.items = toolbarItems;
	//[toolbarItems release];
	[window addSubview:navController.view];
    [window makeKeyAndVisible];
	[fileList reloadData];

	NSString *loadPage = [self pageLastViewed];
	NSLog(@"Got default page: %@", loadPage);
	if(![loadPage isEqualToString:@""]) {
		[fileList loadPage:loadPage];
	}
}

- (void)dealloc {
	[navController release];
    [window release];
    [super dealloc];
}

- (NSString *)pageLastViewed { return [[NSUserDefaults standardUserDefaults] objectForKey:@"Page"]; }
- (void)setPageLastViewed:(NSString *)page { [[NSUserDefaults standardUserDefaults] setObject:page forKey:@"Page"]; }

- (void)clickedButton:(id)sender {
	UISegmentedControl *buttons = sender;

	switch(buttons.selectedSegmentIndex) {
		case 0:
			//Prefs
			break;
		case 1:
			//Sync
			break;
		case 2:
			//Add
			[self addNewPage];
			
			break;
	}
}

- (BOOL)pageExists:(NSString *)pageName { return [fileList pageExists:pageName]; }

- (void)addNewPage {
	NewPageController *npc = [[NewPageController alloc] init];
	[navController pushViewController:npc animated:YES];
	[npc release];
}

- (void)cancelNewPage:(id)sender {
	[navController popViewControllerAnimated:YES];
}

- (void)createPage:(NSString *)pageName asToDoList:(BOOL)isToDoList {
	[navController popViewControllerAnimated:YES];
	[fileList addPageNamed:pageName asToDoList:isToDoList];
	[fileList loadPage:pageName];
}

@end
