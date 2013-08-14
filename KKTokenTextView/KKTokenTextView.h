//
//  KKTokenTextField.h
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

@protocol KKTokenTextViewDelegate <NSObject>
@required

#pragma mark Token Management
- (NSRange)textView:(KKTokenTextView *)textView lastRangeOfStringToTokenize:(NSString *)string keyPathIntention:(NSString **)keyPath;
- (NSString *)textView:(KKTokenTextView *)textView tokenKeyPathForTextInsertion:(KKTextToken *)token;

#pragma mark Text Attributes
- (NSDictionary *)textView:(KKTokenTextView *)textView attributesForToken:(KKTextToken *)token;

@optional
#pragma mark Menu Items
- (NSArray *)textView:(KKTokenTextView *)textView menuItemsForToken:(KKTextToken *)token;
- (NSArray *)textView:(KKTokenTextView *)textView menuItemsForSelectionWithRange:(NSRange)range;

#pragma mark Probably Unimplemented
- (BOOL)textView:(KKTokenTextView *)textView canRemoveToken:(KKTextToken *)token;
- (void)textView:(KKTokenTextView *)textView didRemoveToken:(KKTextToken *)token;

- (void)textView:(KKTokenTextView *)textView didAddToken:(KKTextToken *)token mutationType:(KKTokenTextViewMutationType)mutationType;

@end

@interface KKTokenTextView : UITextView

#pragma mark - Properties

@property (nonatomic, weak) id <KKTokenTextViewDelegate> tokenizationDelegate;
@property (nonatomic) BOOL correctsPunctuation;

@property (nonatomic, copy) UIFont *typingFont;
@property (nonatomic, copy) UIColor *typingColor;

@property (nonatomic, readonly, getter = selectedToken) KKTextToken *selectedToken;
@property (nonatomic, readonly, getter = orderedTokens) NSArray *orderedTokens;

#pragma mark - Tokens

- (void)addToken:(KKTextToken *)token;
- (KKTextToken *)tokenifyRangeOfString:(NSRange)range keyPathToStoreExistingTextValue:(NSString *)keyPath;

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
