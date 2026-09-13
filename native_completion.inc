// Touch-accessible chooser; edits use UITextInput so typing and undo remain native.
- (void)complete {
    UITextView* view = self.view;
    if (!view || !self.completions || view.selectedRange.length != 0 || view.markedTextRange) return;
    NSRange selected = view.selectedRange;
    int32_t offset = byteLength(view.text, NSMakeRange(0, selected.location));
    doof::detail::ActiveActorScope active(&doof::detail::ApplicationDomain::shared());
    NSString* json = ns(self.completions.call(offset));
    id payload = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
    if (![payload isKindOfClass:NSDictionary.class] || ![payload[@"source"] isEqualToString:view.text]) return;
    NSArray* items = payload[@"items"];
    if (![items isKindOfClass:NSArray.class]) return;
    UIViewController* controller = view.window.rootViewController;
    while (controller.presentedViewController) controller = controller.presentedViewController;
    UIAlertController* chooser = [UIAlertController alertControllerWithTitle:@"Complete" message:items.count ? nil : @"No matching suggestions" preferredStyle:UIAlertControllerStyleAlert];
    __weak DoofEditorAdapter* weakAdapter = self;
    for (NSDictionary* item in items) {
        NSString* label = [item[@"detail"] length] ? [NSString stringWithFormat:@"%@ — %@", item[@"label"], item[@"detail"]] : item[@"label"];
        [chooser addAction:[UIAlertAction actionWithTitle:label style:UIAlertActionStyleDefault handler:^(UIAlertAction* action) {
            DoofEditorAdapter* adapter = weakAdapter;
            if (!adapter || !adapter.completions || ![adapter.view.text isEqualToString:payload[@"source"]] || !NSEqualRanges(adapter.view.selectedRange, selected)) return;
            [adapter applyCompletion:item];
        }]];
    }
    [chooser addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [controller presentViewController:chooser animated:YES completion:nil];
}

- (void)applyCompletion:(NSDictionary*)item {
    UITextView* view = self.view;
    NSString* original = view.text;
    NSMutableArray* edits = [NSMutableArray arrayWithArray:item[@"edits"] ?: @[]];
    [edits addObject:item];
    [edits sortUsingComparator:^NSComparisonResult(NSDictionary* a, NSDictionary* b) { return [b[@"start"] compare:a[@"start"]]; }];
    NSMutableArray* ranges = [NSMutableArray new];
    NSUInteger previous = original.length + 1;
    for (NSDictionary* edit in edits) {
        NSRange range = utf16Range(original, [edit[@"start"] intValue], [edit[@"end"] intValue] - [edit[@"start"] intValue]);
        if (range.location == NSNotFound || NSMaxRange(range) > original.length || NSMaxRange(range) > previous) return;
        previous = range.location;
        [ranges addObject:[NSValue valueWithRange:range]];
    }
    NSRange main = utf16Range(original, [item[@"start"] intValue], [item[@"end"] intValue] - [item[@"start"] intValue]);
    NSInteger caret = main.location + [item[@"text"] length];
    for (NSDictionary* edit in item[@"edits"]) {
        NSRange range = utf16Range(original, [edit[@"start"] intValue], [edit[@"end"] intValue] - [edit[@"start"] intValue]);
        if (range.location <= main.location) caret += (NSInteger)[edit[@"text"] length] - (NSInteger)range.length;
    }
    self.suppress = YES;
    [view.undoManager beginUndoGrouping];
    for (NSUInteger index = 0; index < edits.count; ++index) {
        NSRange range = [ranges[index] rangeValue];
        UITextPosition* start = [view positionFromPosition:view.beginningOfDocument offset:range.location];
        UITextPosition* end = [view positionFromPosition:start offset:range.length];
        [view replaceRange:[view textRangeFromPosition:start toPosition:end] withText:edits[index][@"text"]];
    }
    view.selectedRange = NSMakeRange(MAX(0, caret), 0);
    [view.undoManager endUndoGrouping];
    self.suppress = NO;
    [self textViewDidChange:view];
    [self textViewDidChangeSelection:view];
    [view becomeFirstResponder];
}
