//
//  PageController.m
//  wikilist
//
//  Created by Matthew Sachs on 2008-03-09.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PageController.h"


@implementation PageController

- (void)_updateFileName {
	[fileName release];
	fileName = [[directory stringByAppendingPathComponent:name] retain];
}

- (void)_save {
	[((UITextView *)self.view).text writeToFile:fileName atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

- (id)initWithName:(NSString *)_name directory:(NSString *)_directory
{
	if (self = [super init]) {
		name = [_name copy];
		directory = [_directory copy];
		[self _updateFileName];
		self.title = name;
	}
	return self;
}

- (void)loadView
{
	UITextView *view = [[UITextView alloc] initWithFrame:[[UIScreen mainScreen] applicationFrame]];
	view.autoresizingMask = UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleWidth;
	view.text = [NSString stringWithContentsOfFile:fileName encoding:NSUTF8StringEncoding error:nil];
	self.view = view;
	[view release];
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
	// Release anything that's not essential, such as cached data.
}

- (void)dealloc
{
	[self _save];
	[[NSUserDefaults standardUserDefaults] setObject:@"" forKey:@"Page"];
	[name release];
	[directory release];
	[fileName release];
	[super dealloc];
}


@end
