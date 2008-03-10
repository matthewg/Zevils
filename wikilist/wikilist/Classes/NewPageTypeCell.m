//
//  NewPageTypeCell.m
//  wikilist
//
//  Created by Matthew Sachs on 2008-03-09.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "NewPageTypeCell.h"


@implementation NewPageTypeCell

- (id)initWithFrame:(CGRect)frame target:(id)target action:(SEL)action {
    if (self = [super initWithFrame:frame]) {
        // Initialization code here.
		label = [[UILabel alloc] initWithFrame:CGRectMake(15.0, 8.0, 150.0, 30.0)];
		label.backgroundColor = [UIColor whiteColor];
		label.font = [UIFont boldSystemFontOfSize:17.0];
		label.textAlignment = UITextAlignmentLeft;
		label.text = @"To-Do List?";
		[self addSubview:label];
		[label release];
		
		theSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(200.0, 10.0, 94.0, frame.size.height)];
		[theSwitch addTarget:target action:action forControlEvents:UIControlEventValueChanged];
		theSwitch.on = NO;
		[self addSubview:theSwitch];
		[theSwitch release];
    }
    return self;
}

- (void)dealloc
{
    [super dealloc];
}

@end
