//
//  KKTokentextField.h
//  KKTokenTextView
//
//  Created by Kolin Krewinkel on 8/2/13.
//  Copyright (c) 2013 Kolin Krewinkel. All rights reserved.
//

@class KKTextToken, KKTokenTextView;

typedef NS_ENUM(NSInteger, KKTokenTextViewMutationType) {
    KKTokenTextViewMutationTypeRangeMatching,
    KKTokenTextViewMutationTypeManual
};

@protocol STRTokenTextViewDelegate <NSObject>

@required
- (NSRange)textView:(KKTokenTextView *)textView lastRangeOfStringToTokenize:(NSString *)string keyPathIntention:(NSString **)keyPath;
- (NSDictionary *)textView:(KKTokenTextView *)textView attributesForToken:(KKTextToken *)token;
- (NSArray *)textView:(KKTokenTextView *)textView menuItemsForToken:(KKTextToken *)token;
- (NSString *)textView:(KKTokenTextView *)textView tokenKeyPathForTextInsertion:(KKTextToken *)token;

@optional
- (BOOL)textView:(KKTokenTextView *)textView canRemoveToken:(KKTextToken *)token;
- (void)textView:(KKTokenTextView *)textView didRemoveToken:(KKTextToken *)token;

- (void)textView:(KKTokenTextView *)textView didAddToken:(KKTextToken *)token mutationType:(KKTokenTextViewMutationType)mutationType;

@end

@interface KKTokenTextView : UITextView

#pragma mark - Properties

@property (nonatomic, weak) id <STRTokenTextViewDelegate> tokenizationDelegate;
@property (nonatomic) BOOL correctsGrammar;

@property (nonatomic, copy) UIFont *typingFont;
@property (nonatomic, copy) UIColor *typingColor;

@property (nonatomic, readonly, getter = selectedToken) KKTextToken *selectedToken;

#pragma mark - Tokens

- (void)addToken:(KKTextToken *)token;

#pragma mark Editing

- (void)beginEditingToken:(KKTextToken *)token keyPath:(NSString *)keyPath;
- (void)endEditing;

#pragma mark - Text Manipulation

- (void)appendString:(NSString *)string;
- (void)appendString:(NSString *)string moveCursor:(BOOL)moveCursor;

- (void)insertStringIntoAttributedText:(NSString *)string atIndex:(NSInteger)index moveCursor:(BOOL)moveCursor;

@end

@interface KKTextToken : NSObject

#pragma mark - Designated Initializer

+ (instancetype)textTokenWithValue:(NSString *)value forKeyPath:(NSString *)keyPath range:(NSRange)range;

#pragma mark - Properties

@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSURL *representedURL;

@property (nonatomic, copy) NSString *displayText;
@property (nonatomic) NSRange range;

@property (nonatomic, copy) NSString *representedString;
@property (nonatomic, strong) id representedObject;

#pragma mark - Displaying

- (NSString *)stringValueForKeyPath:(NSString *)keyPath;

@end
