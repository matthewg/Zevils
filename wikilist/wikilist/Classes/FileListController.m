//
//  FileListController.m
//  wikilist
//
//  Created by Matthew Sachs on 2008-03-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "FileListController.h"
#import "PageController.h"
#import "wikilistAppDelegate.h"

@implementation FileListController

- (NSString *)_getNoteDir {
	return [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0]
				stringByAppendingPathComponent:@"wikilist"];
}

- (NSString *)_getPListFile {
	return [[self _getNoteDir] stringByAppendingPathComponent:@"pages.plist"];
}

- (void)_savePList {
	NSData *data = [NSPropertyListSerialization
		dataFromPropertyList:pagesAndProperties 
		format:NSPropertyListBinaryFormat_v1_0
		errorDescription:nil];
	[data writeToFile:[self _getPListFile] atomically:YES];
}

- (void)_getNotes {
	pages = nil;
	pageProperties = nil;
	[pagesAndProperties release];
	pagesAndProperties = nil;
	
	NSString *dir = [self _getNoteDir];
	if(![[NSFileManager defaultManager] fileExistsAtPath:dir])
		[[NSFileManager defaultManager]
			createDirectoryAtPath:dir
			withIntermediateDirectories:YES
			attributes:nil
			error:nil];
			
	NSData *savedData = [[NSData alloc] initWithContentsOfFile:[self _getPListFile]];
	if(savedData) {
		pagesAndProperties = [NSPropertyListSerialization
			propertyListFromData:savedData
			mutabilityOption:YES
			format:nil
			errorDescription:nil];
		[savedData release];
		if(pagesAndProperties) {
			[pagesAndProperties retain];

			pageProperties = [pagesAndProperties objectForKey:@"PageProperties"];
			if(!pageProperties) {
				pageProperties = [[NSMutableDictionary alloc] init];
				[pagesAndProperties setObject:pageProperties forKey:@"PageProperties"];
				[pageProperties release];
			}
			
			pages = [pagesAndProperties objectForKey:@"Pages"];
			if(!pages) {
				pages = [[NSMutableArray alloc] init];
				[pagesAndProperties setObject:pages forKey:@"Pages"];
				[pages release];
			}
		}
	}
	if(!pagesAndProperties) {
		pages = [[NSMutableArray alloc] init];
		pageProperties = [[NSMutableDictionary alloc] init];
		pagesAndProperties = [[NSMutableDictionary alloc] initWithObjectsAndKeys:pages, @"Pages", pageProperties, @"PageProperties", nil];
		[pageProperties release];
		[pages release];
	}
}

- (id)init
{
	if (self = [super init]) {
		self.title = @"Pages";
		[self _getNotes];
	}
	return self;
}


- (void)loadView
{
	// Set up table view
    tableView = [[UITableView alloc] initWithFrame:[[UIScreen mainScreen] applicationFrame] style:UITableViewStylePlain];
	tableView.delegate = self;
	tableView.dataSource = self;
	tableView.autoresizingMask = UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleWidth;
	self.view = tableView;
	[tableView release];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	// Return YES for supported orientations.
	return YES;
	//return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)didReceiveMemoryWarning
{
	[super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview.
	[pagesAndProperties release];
	pages = nil;
	pageProperties = nil;
	pagesAndProperties = nil;
}

- (void)dealloc
{
	[pagesAndProperties release];
	[super dealloc];
}

- (BOOL)pageExists:(NSString *)page {
	return [pageProperties objectForKey:page] ? YES : NO;
}

- (void)addPageNamed:(NSString *)name asToDoList:(BOOL)isToDoList {
	[pages addObject:name];
	[pageProperties setObject:[NSDictionary dictionaryWithObject:(isToDoList ? @"YES" : @"NO") forKey:@"ToDo"] forKey:name];

	[@"" writeToFile:[[self _getNoteDir] stringByAppendingPathComponent:name] atomically:NO];
	[self _savePList];
	[tableView reloadData];
}
- (void)reloadData { [tableView reloadData]; }
- (PageController *)pageControllerForPage:(NSString *)page {
	if(![self pageExists:page]) return nil;
	return [[[PageController alloc] initWithName:page directory:[self _getNoteDir]] autorelease];
}
- (void)loadPage:(NSString *)page {
	PageController *pageController = [self pageControllerForPage:page];
	if(pageController) {
		[[wikilistAppDelegate sharedController] setPageLastViewed:page];
		[[self navigationController] pushViewController:pageController animated:YES];
	}
}



- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if(!pages) [self _getNotes];
	return [pages count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath withAvailableCell:(UITableViewCell *)availableCell {
	UISimpleTableViewCell *cell = nil;

	if (availableCell != nil) {
		cell = (UISimpleTableViewCell *)availableCell;
	} else {
		CGRect frame = CGRectMake(0, 0, 300, 44);
		cell = [[[UISimpleTableViewCell alloc] initWithFrame:frame] autorelease];
	}
	if(!pages) [self _getNotes];
	cell.text = [pages objectAtIndex:[indexPath row]];
	return cell;
}

- (void)tableView:(UITableView *)theTableView selectionDidChangeToIndexPath:(NSIndexPath *)newIndexPath fromIndexPath:(NSIndexPath *)oldIndexPath {
	[tableView selectRowAtIndexPath:[NSIndexPath indexPathWithIndex:-1] animated:NO scrollPosition:UITableViewScrollPositionNone];
	[self loadPage:[pages objectAtIndex:newIndexPath.row]];
}

- (UITableViewCellAccessoryType)tableView:(UITableView *)tableView accessoryTypeForRowWithIndexPath:(NSIndexPath *)indexPath {
	return UITableViewCellAccessoryDisclosureIndicator;
}

@end
