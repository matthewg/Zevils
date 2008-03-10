//
//  NewPageNameCell.m
//  wikilist
//
//  Created by Matthew Sachs on 2008-03-09.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "NewPageNameCell.h"


@implementation NewPageNameCell

- (id)initWithFrame:(CGRect)frame target:(id)target action:(SEL)action {
    if (self = [super initWithFrame:frame]) {
        // Initialization code here.
		label = [[UILabel alloc] initWithFrame:CGRectMake(15.0, 8.0, 150.0, 30.0)];
		label.backgroundColor = [UIColor whiteColor];
		label.font = [UIFont boldSystemFontOfSize:17.0];
		label.textAlignment = UITextAlignmentLeft;
		label.text = @"Title";
		[self addSubview:label];
		[label release];
		
		text = [[UITextField alloc] initWithFrame:CGRectMake(150.0, 10.0, 150.0, frame.size.height)];
		text.autocapitalizationType = UITextAutocapitalizationTypeSentences;
		text.autocorrectionType = UITextAutocorrectionTypeYes;
		text.enablesReturnKeyAutomatically = YES;
		text.returnKeyType = UIReturnKeyDone;
		text.font = [UIFont systemFontOfSize:18.0];
		text.placeholder = @"New Page Title";
		text.delegate = self;
		[text addTarget:target action:action forControlEvents:UIControlEventEditingChanged];
		[self addSubview:text];
		[text release];
    }
    return self;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
	[textField resignFirstResponder];
	return YES;
}

@end
