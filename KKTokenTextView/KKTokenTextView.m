//
//  STRTokenTextView.m
//  KKTokenTextView
//
//  Created by Kolin Krewinkel on 8/2/13.
//  Copyright (c) 2013 Kolin Krewinkel. All rights reserved.
//

#import "KKTokenTextView.h"
#import <Dickens/NSString+KKPolishing.h>

#pragma mark - Convenience

static NSRange ShiftRange(NSRange range, NSInteger offset)
{
    return NSMakeRange(range.location + offset, range.length);
}

static NSInteger EndOfRange(NSRange range)
{
    return range.location + range.length;
}

typedef void(^STRTokenTextViewAttributedTextFinalizingBlock)(NSString *newText);

@interface KKTokenTextView () <UITextViewDelegate>

@property (nonatomic, strong) NSMutableSet *tokens;
@property (nonatomic, strong) NSMutableSet *selectedTokens;

@property (nonatomic, weak) KKTextToken *editingToken;
@property (nonatomic, copy) NSString *editingTokenKeyPath;

@end

@implementation KKTokenTextView

#pragma mark - Initialization

- (void)commonInitialization
{
    self.delegate = self;
    self.correctsPunctuation = YES;

    self.tokens = [[NSMutableSet alloc] init];
    self.selectedTokens = [[NSMutableSet alloc] init];

    self.font = [UIFont systemFontOfSize:15.f];
    self.typingFont = self.font;
    self.typingColor = [UIColor blackColor];
}

- (instancetype)init
{
    if ((self = [super init]))
    {
        [self commonInitialization];
    }

    return self;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame]))
    {
        [self commonInitialization];
    }

    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    if ((self = [super initWithCoder:aDecoder]))
    {
        [self commonInitialization];
    }

    return self;
}

#pragma mark - UITextViewDelegate

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
    __block NSUInteger offset = (text.length == 0 ? -range.length : text.length);
    NSString *newlineString = @"\n";
    BOOL isFinishingEditing = self.editingToken && [text isEqualToString:newlineString];

    if (self.editingToken && !isFinishingEditing)
    {
        NSMutableString *mutableDisplayText = [[self.editingToken stringValueForKeyPath:self.editingTokenKeyPath] mutableCopy];
        NSRange tokenRange = self.editingToken.range;
        NSRange translatedRange = NSMakeRange(range.location - tokenRange.location, range.length);

        [mutableDisplayText replaceCharactersInRange:translatedRange withString:text];

        [self.editingToken setValue:mutableDisplayText == nil ? @"" : [[NSString alloc] initWithString:mutableDisplayText] forKeyPath:self.editingTokenKeyPath];
        self.editingToken.range = NSMakeRange(tokenRange.location, mutableDisplayText.length);
    }
    else if (!isFinishingEditing)
    {
        NSSet *involvedTokens = [self tokensContainedInRange:range];
        [self deleteTokens:involvedTokens];

        for (KKTextToken *token in [self tokensAfterCharacterIndex:range.location])
        {
            token.range = NSMakeRange(token.range.location + offset, token.range.length);
        }
    }

    if ([text isEqualToString:newlineString])
    {
        if (self.editingToken)
        {
            [self endEditing];
            return NO;
        }

        return [self handleReturnAtLocation:range.location];
    }
    else if (text.length == 0 && textView.text.length > 0)
    {
        KKTextToken *token = [self tokenContainingCharacterIndex:range.location];

        if (token)
        {
            [self selectToken:token visiblySelectRange:YES];
            return NO;
        }
    }

    NSMutableString *mutableString = [[self mutableAttributedText].string mutableCopy];
    [mutableString replaceCharactersInRange:range withString:text];

    STRTokenTextViewAttributedTextFinalizingBlock finalizeBlock = ^(NSString *newText) {
        NSUInteger location = self.selectedRange.location + offset;

        self.attributedText = [[NSAttributedString alloc] initWithString:newText];
        self.selectedRange = NSMakeRange(location, 0);
    };

    if (self.correctsPunctuation)
    {
        __weak typeof(self) weakSelf = self;
        dispatch_async([NSString KK_sharedPolishQueue], ^{
            typeof(self) selfRef = weakSelf;

            NSDictionary *correctionTextCheckingResults = [mutableString KK_correctionTextCheckingResults];
            NSMutableString *string = correctionTextCheckingResults[KKOperatedString];

            for (NSTextCheckingResult *quoteResult in correctionTextCheckingResults[KKSingleQuoteCorrections]) {
                NSString *content = [string substringWithRange:NSMakeRange(quoteResult.range.location + 1, quoteResult.range.length - 2)]; // Quoted content
                [string replaceCharactersInRange:quoteResult.range withString:[NSString KK_wrapString:content withOpeningString:KKCharacterLeftSingleQuotationMark closingString:KKCharacterRightSingleQuotationMark]]; // Replace dumb single quotes.
            }

            for (NSTextCheckingResult *quoteResult in correctionTextCheckingResults[KKDoubleQuoteCorrections]) {
                NSString *content = [string substringWithRange:NSMakeRange(quoteResult.range.location + 1, quoteResult.range.length - 2)]; // Quoted content
                [string replaceCharactersInRange:quoteResult.range withString:[NSString KK_wrapString:content withOpeningString:KKCharacterLeftDoubleQuotationMark closingString:KKCharacterRightDoubleQuotationMark]]; // Replace dumb double quotes.
            }

            NSInteger charactersChanged = 0;
            for (NSTextCheckingResult *tripleDotResult in correctionTextCheckingResults[KKEllipsisCorrections]) {

                // Because we're actually mutating the string we used to find the ranges, we need to make sure that the ranges we use accumulate/are concious of the new positions.
                [string replaceCharactersInRange:NSMakeRange(tripleDotResult.range.location - charactersChanged, tripleDotResult.range.length) withString:KKCharacterEllipsis];

                // Increment! (... -> …)
                NSInteger change = tripleDotResult.range.length - KKCharacterEllipsis.length;
                charactersChanged += change;
                offset -= change;

                [selfRef shiftTokensForResult:tripleDotResult offset:-change];
            }

            for (NSTextCheckingResult *hyphenResult in correctionTextCheckingResults[KKEmDashCorrections]) {
                [string replaceCharactersInRange:hyphenResult.range withString:KKCharacterEmDash];
            }

            for (NSTextCheckingResult *hyphenResult in correctionTextCheckingResults[KKEnDashCorrections]) {
                [string replaceCharactersInRange:NSMakeRange(hyphenResult.range.location - charactersChanged, hyphenResult.range.length) withString:KKCharacterEnDash];
                NSInteger change = hyphenResult.range.length - KKCharacterEnDash.length;
                charactersChanged += change;
                offset -= change;

                [selfRef shiftTokensForResult:hyphenResult offset:-change];
            }

            for (NSTextCheckingResult *singleQuoteResult in correctionTextCheckingResults[KKApostropheCorrections]) {
                [string replaceCharactersInRange:singleQuoteResult.range withString:KKCharacterApostrophe];
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                finalizeBlock(string);
            });
        });
    }
    else
    {
        finalizeBlock(mutableString);
    }

    return NO;
}

#pragma mark - Input Handling

- (BOOL)handleReturnAtLocation:(NSInteger)location
{
    NSString *text = [self.attributedText.string substringToIndex:location];
    NSString *keyPath = nil;
    NSRange tokenRange = [self.tokenizationDelegate textView:self lastRangeOfStringToTokenize:text keyPathIntention:&keyPath];

    if (tokenRange.length > 0 && [self tokensContainedInRange:tokenRange].count == 0)
    {
        [self addTokenWithRange:tokenRange keyPathDerivation:keyPath];
    }
    else
    {
        [self insertStringIntoAttributedText:@"\n" atIndex:location moveCursor:YES];
    }

    return NO;
}

#pragma mark - Token Management

- (KKTextToken *)tokenContainingCharacterIndex:(NSInteger)index
{
    return [[self.tokens filteredSetUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(KKTextToken *token, NSDictionary *bindings) {
        return (index > token.range.location && index < (token.range.location + token.range.length));
    }]] anyObject];
}

- (KKTextToken *)firstTokenLyingInRange:(NSRange)range
{
    return [[self tokensContainedInRange:range] sortedArrayUsingDescriptors:@[[[NSSortDescriptor alloc] initWithKey:@"range.location" ascending:YES]]].lastObject;
}

- (NSSet *)tokensContainedInRange:(NSRange)range
{
    return [self.tokens filteredSetUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(KKTextToken *token, NSDictionary *bindings) {
        return (NSIntersectionRange(range, token.range).length > 1);
    }]];
}

- (NSSet *)tokensAfterCharacterIndex:(NSInteger)index
{
    return [self.tokens filteredSetUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(KKTextToken *token, NSDictionary *bindings) {
        return (token.range.location >= index);
    }]];
}

- (NSSet *)tokensBeforeCharacterIndex:(NSInteger)index
{
    return [self.tokens filteredSetUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(KKTextToken *token, NSDictionary *bindings) {
        return (index > token.range.location + token.range.length);
    }]];
}

- (void)addToken:(KKTextToken *)token
{
    [self.tokens addObject:token];

    if (token.range.location != NSNotFound)
    {
        NSMutableAttributedString *mutableAttributedString = [self mutableAttributedText];
        [mutableAttributedString insertAttributedString:[[NSAttributedString alloc] initWithString:[token stringValueForKeyPath:[self.tokenizationDelegate textView:self tokenKeyPathForTextInsertion:token]]] atIndex:token.range.location];
        self.attributedText = mutableAttributedString;
    }

    if ([self.tokenizationDelegate respondsToSelector:@selector(textView:didAddToken:mutationType:)])
    {
        [self.tokenizationDelegate textView:self didAddToken:token mutationType:KKTokenTextViewMutationTypeManual];
    }
}

- (void)addTokenWithRange:(NSRange)range keyPathDerivation:(NSString *)keyPath
{
    KKTextToken *token = [KKTextToken textTokenWithValue:[self.attributedText.string substringWithRange:range] forKeyPath:keyPath range:range];
    [self.tokens addObject:token];

    [self insertStringIntoAttributedText:@" " atIndex:EndOfRange(range) moveCursor:YES];

    if ([self.tokenizationDelegate respondsToSelector:@selector(textView:didAddToken:mutationType:)])
    {
        [self.tokenizationDelegate textView:self didAddToken:token mutationType:KKTokenTextViewMutationTypeRangeMatching];
    }
}

- (void)deleteTokens:(id<NSFastEnumeration>)tokens
{
    for (KKTextToken *token in tokens)
    {
        [self deleteToken:token];
    }
}

- (void)deleteToken:(KKTextToken *)token
{
    [self.tokens removeObject:token];
    [self.selectedTokens removeObject:token];

    if ([self.tokenizationDelegate respondsToSelector:@selector(textView:didRemoveToken:)])
    {
        [self.tokenizationDelegate textView:self didRemoveToken:token];
    }
}

- (void)shiftTokensForResult:(NSTextCheckingResult *)textCheckingResult offset:(NSInteger)offset
{
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        typeof(self) selfRef = weakSelf;

        for (KKTextToken *token in [selfRef tokensAfterCharacterIndex:textCheckingResult.range.location])
        {
            token.range = ShiftRange(token.range, offset);
        }
    });
}

#pragma mark - Text Manipulation

- (NSDictionary *)defaultAttributes
{
    return @{NSFontAttributeName: self.typingFont, NSForegroundColorAttributeName: self.typingColor};
}

- (void)insertStringIntoAttributedText:(NSString *)string atIndex:(NSInteger)index moveCursor:(BOOL)moveCursor
{
    NSAttributedString *stringToAppend = [[NSAttributedString alloc] initWithString:string attributes:[self defaultAttributes]];
    NSMutableAttributedString *mutableCurrentText = [self mutableAttributedText];

    [mutableCurrentText insertAttributedString:stringToAppend atIndex:index];

    self.attributedText = mutableCurrentText;

    if (moveCursor && self.selectedRange.length == 0)
    {
        self.selectedRange = NSMakeRange([self offsetFromPosition:self.beginningOfDocument toPosition:[self positionFromPosition:self.beginningOfDocument offset:index + 1]], 0);
    }
}

- (void)appendString:(NSString *)string
{
    [self appendString:string moveCursor:NO];
}

- (void)appendString:(NSString *)string moveCursor:(BOOL)moveCursor
{
    [self insertStringIntoAttributedText:string atIndex:self.attributedText.length - 1 moveCursor:moveCursor];
}

- (void)deleteCharactersInRange:(NSRange)range
{
    NSMutableAttributedString *mutableCurrentText = [self mutableAttributedText];
    [mutableCurrentText deleteCharactersInRange:range];

    self.attributedText = mutableCurrentText;
}

- (void)setTextAttributes:(NSDictionary *)attributes inRange:(NSRange)range
{
    NSMutableAttributedString *attributedString = [self mutableAttributedText];
    [attributedString setAttributes:attributes range:range];

    self.attributedText = attributedString;
}

- (NSMutableAttributedString *)mutableAttributedText
{
    NSMutableAttributedString *mutableAttributedString = [self.attributedText mutableCopy];
//    NSRange rangeOfNewline = [mutableAttributedString.string rangeOfString:@"\n" options:NSBackwardsSearch];
//
//    if (rangeOfNewline.location != NSNotFound)
//    {
//        [mutableAttributedString deleteCharactersInRange:rangeOfNewline];
//    }

    return mutableAttributedString;
}

#pragma mark - Getters

- (KKTextToken *)selectedToken
{
    return [self.selectedTokens anyObject];
}

#pragma mark - Setters

- (void)setAttributedText:(NSAttributedString *)attributedText
{
    NSRange selectedRange = self.selectedRange;

    NSMutableAttributedString *colorizedAttributedText = [attributedText mutableCopy];

    if (!self.editingToken)
    {
        [colorizedAttributedText setAttributes:[self defaultAttributes] range:NSMakeRange(0, attributedText.length)];

        for (KKTextToken *token in self.tokens)
        {
            [colorizedAttributedText setAttributes:[self.tokenizationDelegate textView:self attributesForToken:token] range:token.range];
        }
    }
    else
    {
        [colorizedAttributedText setAttributes:@{NSFontAttributeName: self.typingFont, NSForegroundColorAttributeName: [self.typingColor colorWithAlphaComponent:0.25f]} range:NSMakeRange(0, attributedText.length)];

        [colorizedAttributedText setAttributes:@{NSFontAttributeName: self.typingFont, NSForegroundColorAttributeName: self.typingColor} range:self.editingToken.range];
    }

    [super setAttributedText:colorizedAttributedText];

    if (self.attributedText.length > selectedRange.location + selectedRange.length)
    {
        self.selectedRange = selectedRange;
    }
}

- (void)setSelectedTextRange:(UITextRange *)selectedTextRange
{
    NSRange range = [self NSRangeFromTextRange:selectedTextRange];

    if (self.editingToken)
    {
        NSRange editingRange = self.editingToken.range;
        NSInteger location = MIN(MAX(editingRange.location, range.location), editingRange.location + editingRange.length);
        NSInteger length = range.length;
        NSInteger endOfToken = editingRange.location + editingRange.length;
        NSInteger prospectiveEnd = location + length;

        if (prospectiveEnd > endOfToken)
        {
            length -= prospectiveEnd - endOfToken;
        }

        NSRange selectedRange = NSMakeRange(location, length);
        [super setSelectedTextRange:[self textRangeFromNSRange:selectedRange]];
        self.selectedRange = selectedRange;
    }
    else
    {
        KKTextToken *token = [self tokenContainingCharacterIndex:range.location];
        if (token && ![self NSRange:[self NSRangeFromTextRange:selectedTextRange] isEqualToRange:token.range])
        {
            [self selectToken:token visiblySelectRange:YES];
            return;
        }

        [super setSelectedTextRange:selectedTextRange];
    }

    if (CGRectEqualToRect([UIMenuController sharedMenuController].menuFrame, CGRectZero)) // This didn't happen and should've
    {
        [[UIMenuController sharedMenuController] setTargetRect:[[self selectionRectsForRange:self.selectedTextRange].lastObject rect] inView:self];
    }
}

- (void)selectToken:(KKTextToken *)token visiblySelectRange:(BOOL)selectRange
{
    [self.selectedTokens removeAllObjects];
    [self.selectedTokens addObject:token];

    if (selectRange)
    {
        self.selectedRange = token.range;

        UIMenuController *menuController = [UIMenuController sharedMenuController];
        if ([self.tokenizationDelegate respondsToSelector:@selector(textView:menuItemsForToken:)])
        {
            [menuController setMenuItems:[self.tokenizationDelegate textView:self menuItemsForToken:token]];
        }

        if (CGRectEqualToRect([UIMenuController sharedMenuController].menuFrame, CGRectZero)) // This didn't happen and should've
        {
            [menuController setTargetRect:[[self selectionRectsForRange:self.selectedTextRange].lastObject rect] inView:self];
        }

        if (!menuController.menuVisible)
        {
            [[UIMenuController sharedMenuController] setMenuVisible:YES animated:YES];
        }
    }
}

#pragma mark - UIKeyInput Convenience

- (NSRange)NSRangeFromTextRange:(UITextRange *)textRange
{
    NSInteger location = [self offsetFromPosition:self.beginningOfDocument toPosition:textRange.start];
    NSInteger end = [self offsetFromPosition:self.beginningOfDocument toPosition:textRange.end];

    return NSMakeRange(location, end - location);
}

- (UITextRange *)textRangeFromNSRange:(NSRange)range
{
    return [self textRangeFromPosition:[self positionFromPosition:self.beginningOfDocument offset:range.location] toPosition:[self positionFromPosition:self.beginningOfDocument offset:range.length + range.location]];
}

- (BOOL)NSRange:(NSRange)range1 isEqualToRange:(NSRange)range2
{
    return (range1.location == range2.location && range1.length == range2.length);
}

#pragma mark - UIResponder

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender
{
    KKTextToken *firstTokenSelected = [self.selectedTokens anyObject];

    if (firstTokenSelected)
    {
        if (action == @selector(cut:))
        {
            return YES;
        }
        else if (action == @selector(paste:))
        {
            return YES;
        }

        return NO;
    }

    return [super canPerformAction:action withSender:sender];
}

#pragma mark - Tokens

- (void)beginEditingToken:(KKTextToken *)token keyPath:(NSString *)keyPath
{
    [self setEditingToken:token withKeyPath:keyPath];

    self.selectedRange = NSMakeRange(token.range.location, 0);
}

- (void)endEditing
{
    [self setEditingToken:nil withKeyPath:[self.tokenizationDelegate textView:self tokenKeyPathForTextInsertion:self.editingToken]];

    self.selectedTextRange = self.selectedTextRange;
}

- (void)setEditingToken:(KKTextToken *)newEditingToken withKeyPath:(NSString *)keyPath
{
    if (newEditingToken)
    {
        self.editingTokenKeyPath = keyPath;
    }
    else
    {
        self.editingTokenKeyPath = nil;
    }

    KKTextToken *oldEditingToken = self.editingToken;
    KKTextToken *tokenToModify = newEditingToken == nil ? oldEditingToken : newEditingToken;

    NSString *replacementValue = [tokenToModify stringValueForKeyPath:keyPath];

    if (replacementValue == nil)
    {
        replacementValue = @"";
    }

    NSMutableAttributedString *newAttributedText = [self mutableAttributedText];
    [newAttributedText replaceCharactersInRange:tokenToModify.range withAttributedString:[[NSAttributedString alloc] initWithString:replacementValue attributes:[self defaultAttributes]]];
    tokenToModify.range = NSMakeRange(tokenToModify.range.location, replacementValue.length);

    self.editingToken = newEditingToken;
    self.attributedText = newAttributedText;

    if (newEditingToken)
    {
        self.returnKeyType = UIReturnKeyDone;
    }
    else
    {
        self.returnKeyType = UIReturnKeyDefault;
    }

    // this makes the return key change
    [self resignFirstResponder];
    [self becomeFirstResponder];
}

@end

@implementation KKTextToken

#pragma mark - Initializers

- (instancetype)init
{
    if ((self = [super init]))
    {
        self.range = NSMakeRange(NSNotFound, 0);
    }

    return self;
}

#pragma mark - Designated Initializer

+ (instancetype)textTokenWithValue:(NSString *)value forKeyPath:(NSString *)keyPath range:(NSRange)range
{
    KKTextToken *textToken = [[KKTextToken alloc] init];
    [textToken setValue:value forKeyPath:keyPath];
    textToken.displayText = value;
    textToken.range = range;

    return textToken;
}

#pragma mark - KV

- (void)setRepresentedURL:(NSURL *)representedURL
{
    if ([representedURL isKindOfClass:[NSString class]])
    {
        [self setRepresentedURL:[NSURL URLWithString:(NSString *)representedURL]];
    }

    _representedURL = representedURL;
}

#pragma mark - Displaying

- (NSString *)stringValueForKeyPath:(NSString *)keyPath
{
    id object = [self valueForKey:keyPath];

    if ([object isKindOfClass:[NSURL class]])
    {
        return ((NSURL *)object).absoluteString;
    }
    else if ([object isKindOfClass:[NSString class]])
    {
        return object;
    }
    
    if (!object)
    {
        return @"";
    }
    
    return [object description];
}

@end
