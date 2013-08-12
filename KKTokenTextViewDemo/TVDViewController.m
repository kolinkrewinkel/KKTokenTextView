//
//  TVDViewController.m
//  KKTokenTextViewDemo
//
//  Created by Kolin Krewinkel on 8/11/13.
//  Copyright (c) 2013 Kolin Krewinkel. All rights reserved.
//

#import "TVDViewController.h"

@interface TVDViewController ()

@end

@implementation TVDViewController

#pragma mark - UIViewController

- (void)loadView
{
    [super loadView];

    self.textView = [[KKTokenTextView alloc] init];
    self.textView.tokenizationDelegate = self;
    self.textView.contentInset = UIEdgeInsetsMake(20.f, 0.f, 0.f, 0.f);
    self.view = self.textView;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    [self.textView becomeFirstResponder];
}

#pragma mark this is all copypasta from Stream
#pragma mark - KKTokenTextViewDelegate

- (NSRange)textView:(KKTokenTextView *)textView lastRangeOfStringToTokenize:(NSString *)string keyPathIntention:(NSString *__autoreleasing *)keyPath
{
    NSError *error = nil;
    NSDataDetector *URLDetector = [[NSDataDetector alloc] initWithTypes:NSTextCheckingTypeLink error:&error];

    if (error)
    {
        NSLog(@"%@", error);
    }

    __block NSRange range = NSMakeRange(0, 0);
    [URLDetector enumerateMatchesInString:string options:NSMatchingReportCompletion range:NSMakeRange(0, string.length) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
        if (result)
        {
            range = result.range;
            *keyPath = @"representedURL";
        }
    }];

    return range;
}

- (NSDictionary *)textView:(KKTokenTextView *)textView attributesForToken:(KKTextToken *)token
{
    return @{NSFontAttributeName : textView.font, NSForegroundColorAttributeName : [UIColor colorWithRed:0.114f green:0.651f blue:0.875f alpha:1.f]};
}

- (NSArray *)textView:(KKTokenTextView *)textView menuItemsForToken:(KKTextToken *)token
{
    UIMenuItem *URLItem = [[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"Edit URL", @"Action menu text for editing URL tokens.") action:@selector(editTokenURL:)];

    NSString *titleItemTitle = nil;
    if (token.title)
    {
        titleItemTitle = NSLocalizedString(@"Edit Title", @"Action menu text for manipulating a URL.");
    }
    else
    {
        titleItemTitle = NSLocalizedString(@"Add Title", @"Action menu text for manipulating a URL.");
    }

    UIMenuItem *titleItem = [[UIMenuItem alloc] initWithTitle:titleItemTitle action:@selector(editTokenTitle:)];

    return @[URLItem, titleItem];
}

- (NSString *)textView:(KKTokenTextView *)textView tokenKeyPathForTextInsertion:(KKTextToken *)token
{
    if (token.title)
    {
        return @"title";
    }

    return @"representedURL";
}

#pragma mark - UIResponder

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender
{
    return (action == @selector(editTokenURL:) || action == @selector(editTokenTitle:));
}

- (void)editTokenURL:(id)sender
{
    [self.textView beginEditingToken:self.textView.selectedToken keyPath:@"representedURL"];
}

- (void)editTokenTitle:(id)sender
{
    [self.textView beginEditingToken:self.textView.selectedToken keyPath:@"title"];
}

@end
