//
//  TVDViewController.m
//  KKTokenTextViewDemo
//
//  Created by Kolin Krewinkel on 8/11/13.
//  Copyright (c) 2013 Kolin Krewinkel. All rights reserved.
//

#import "TVDViewController.h"

@interface TVDViewController () <UIAlertViewDelegate>

@end

@implementation TVDViewController

#pragma mark - UIViewController

- (void)loadView
{
    [super loadView];

    self.textView = [[KKTokenTextView alloc] initWithFrame:self.view.bounds];
    self.textView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.textView.tokenizationDelegate = self;
    self.textView.contentInset = UIEdgeInsetsMake([[[UIDevice currentDevice] systemVersion] isEqualToString:@"7.0"] ? 20.f : 0.f, 0.f, 0.f, 0.f);
    [self.view addSubview:self.textView];

    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Protip", nil) message:NSLocalizedString(@"Tap/hit enter to \"make\" a token. In this demo, it's for URLs. In the future, I may make it so that the text view passively calls the delegate for matches so the return key can be switched to the \"Done\" type, which is a little more intuitive, like in editing mode.\nThis demo also showcases Dickens, another library of mine which handles autocorrecting punctuation to the correct type.", nil) delegate:self cancelButtonTitle:@"thx man" otherButtonTitles:nil];
    [alertView show];
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
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

- (NSArray *)textView:(KKTokenTextView *)textView menuItemsForSelectionWithRange:(NSRange)range
{
    return @[[[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"Create Link", @"Action menu text to linkify some text.") action:@selector(addURL:)]];
}

#pragma mark - UIResponder

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender
{
    return (action == @selector(editTokenURL:) || action == @selector(editTokenTitle:) || action == @selector(addURL:));
}

- (void)editTokenURL:(id)sender
{
    [self.textView beginEditingToken:self.textView.selectedToken keyPath:@"representedURL"];
}

- (void)editTokenTitle:(id)sender
{
    [self.textView beginEditingToken:self.textView.selectedToken keyPath:@"title"];
}

- (void)addURL:(id)sender
{
    KKTextToken *token = [self.textView tokenifyRangeOfString:self.textView.selectedRange keyPathToStoreExistingTextValue:@"title"];

    double delayInSeconds = 0.1;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [self.textView beginEditingToken:token keyPath:@"representedURL"];
    });
}

@end
