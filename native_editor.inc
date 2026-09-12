static NSRange utf16Range(NSString* value, int32_t byteStart, int32_t byteLength) {
    std::string bytes = utf8(value);
    size_t start = std::min(bytes.size(), static_cast<size_t>(std::max(0, byteStart)));
    size_t length = std::min(bytes.size() - start, static_cast<size_t>(std::max(0, byteLength)));
    NSString* prefix = [[NSString alloc] initWithBytes:bytes.data() length:start encoding:NSUTF8StringEncoding];
    NSString* token = [[NSString alloc] initWithBytes:bytes.data() + start length:length encoding:NSUTF8StringEncoding];
    if (!prefix || !token) return NSMakeRange(NSNotFound, 0);
    return NSMakeRange(prefix.length, token.length);
}

static int32_t byteLength(NSString* value, NSRange range) {
    if (range.location == NSNotFound || NSMaxRange(range) > value.length) return 0;
    return (int32_t)[[value substringWithRange:range] lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
}

static UIColor* editorColor(int32_t style) {
    switch (style) {
        case 1: return UIColor.systemPurpleColor;
        case 2: return UIColor.systemRedColor;
        case 3: return UIColor.systemBlueColor;
        case 4: return UIColor.systemGreenColor;
        case 5: return UIColor.systemTealColor;
        case 6: return UIColor.systemIndigoColor;
        case 7: return UIColor.systemRedColor;
        case 8: return UIColor.systemOrangeColor;
        default: return UIColor.labelColor;
    }
}

@interface DoofTextView : UITextView
@property(nonatomic) BOOL autoIndent;
@property(nonatomic) int32_t indentationWidth;
@end

@implementation DoofTextView
- (void)insertText:(NSString*)text {
    if (!self.autoIndent || ![text isEqualToString:@"\n"]) { [super insertText:text]; return; }
    NSString* value = self.text ?: @"";
    NSRange selection = self.selectedRange;
    if (selection.location == NSNotFound || selection.location > value.length) { [super insertText:text]; return; }
    NSRange line = [value lineRangeForRange:NSMakeRange(selection.location, 0)];
    NSString* prefix = [value substringWithRange:NSMakeRange(line.location, selection.location - line.location)];
    NSUInteger whitespace = 0;
    while (whitespace < prefix.length) {
        unichar character = [prefix characterAtIndex:whitespace];
        if (character != ' ' && character != '\t') break;
        whitespace += 1;
    }
    NSMutableString* insertion = [NSMutableString stringWithString:@"\n"];
    [insertion appendString:[prefix substringToIndex:whitespace]];
    NSString* trimmed = [[prefix substringFromIndex:whitespace]
        stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    if ([trimmed hasSuffix:@"{"] || [trimmed hasSuffix:@"["] || [trimmed hasSuffix:@"("]) {
        [insertion appendString:[@"" stringByPaddingToLength:MAX(1, self.indentationWidth)
            withString:@" " startingAtIndex:0]];
    }
    [super insertText:insertion];
}
@end

@interface DoofEditorAdapter : NSObject <UITextViewDelegate>
@property(nonatomic, weak) UITextView* view;
@property(nonatomic) doof::callback<void(std::string)> change;
@property(nonatomic) doof::callback<void(int32_t, int32_t)> selectionChange;
@property(nonatomic) BOOL suppress;
@property(nonatomic) double fontSize;
@end

@implementation DoofEditorAdapter
- (void)textViewDidChange:(UITextView*)textView {
    if (!self.suppress && self.change) {
        doof::detail::ActiveActorScope active(&doof::detail::ApplicationDomain::shared());
        self.change.call(utf8(textView.text ?: @""));
    }
}
- (void)textViewDidChangeSelection:(UITextView*)textView {
    if (self.suppress || !self.selectionChange) return;
    NSString* value = textView.text ?: @""; NSRange selected = textView.selectedRange;
    doof::detail::ActiveActorScope active(&doof::detail::ApplicationDomain::shared());
    self.selectionChange.call(
        byteLength(value, NSMakeRange(0, selected.location)),
        byteLength(value, selected));
}
@end
