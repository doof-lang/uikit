#include "native_uikit.hpp"
#include <UIKit/UIKit.h>
#include <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#include <algorithm>
#include <condition_variable>
#include <mutex>

namespace doof_uikit {

static NSString* ns(const std::string& value) {
    return [[NSString alloc] initWithBytes:value.data() length:value.size() encoding:NSUTF8StringEncoding] ?: @"";
}
static std::string utf8(NSString* value) {
    const char* bytes = value.UTF8String;
    return bytes ? std::string(bytes) : std::string();
}
static void onMain(void (^work)(void)) {
    if (NSThread.isMainThread) work(); else dispatch_sync(dispatch_get_main_queue(), work);
}
static UIWindow* applicationWindow() {
    id delegate = UIApplication.sharedApplication.delegate;
    if ([delegate respondsToSelector:@selector(window)] && [delegate window]) return [delegate window];
    for (UIScene* scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        for (UIWindow* window in ((UIWindowScene*)scene).windows) if (window.isKeyWindow) return window;
        UIWindow* first = ((UIWindowScene*)scene).windows.firstObject;
        if (first) return first;
    }
    return nil;
}

} // namespace doof_uikit

using namespace doof_uikit;

#include "native_editor.inc"

@interface DoofActionTarget : NSObject
@property(nonatomic) doof::callback<void()> action;
- (void)pressed:(id)sender;
@end
@implementation DoofActionTarget
- (void)pressed:(id)sender {
    if (self.action) {
        doof::detail::ActiveActorScope active(&doof::detail::ApplicationDomain::shared());
        self.action.call();
    }
}
@end

namespace doof_uikit {

struct NativeView::Impl {
    UIView* view = nil;
    UIScrollView* scroll = nil;
    UIView* document = nil;
    id adapter = nil;
    std::vector<std::shared_ptr<NativeView>> children;
    bool disposed = false;
};

NativeView::NativeView() : impl_(std::make_shared<Impl>()) {}
NativeView::~NativeView() { dispose(); }

std::shared_ptr<NativeView> NativeView::container() {
    auto result = std::shared_ptr<NativeView>(new NativeView());
    onMain(^{ result->impl_->view = [UIView new]; });
    return result;
}
std::shared_ptr<NativeView> NativeView::scroll() {
    auto result = std::shared_ptr<NativeView>(new NativeView());
    onMain(^{
        result->impl_->scroll = [UIScrollView new];
        result->impl_->document = [UIView new];
        [result->impl_->scroll addSubview:result->impl_->document];
        result->impl_->view = result->impl_->scroll;
    });
    return result;
}
std::shared_ptr<NativeView> NativeView::spacer() { return container(); }
std::shared_ptr<NativeView> NativeView::text(const std::string& value) {
    auto result = std::shared_ptr<NativeView>(new NativeView());
    onMain(^{ UILabel* label = [UILabel new]; label.text = ns(value); label.numberOfLines = 0; result->impl_->view = label; });
    return result;
}
std::shared_ptr<NativeView> NativeView::button(
    const std::string& title, const std::string& symbol, doof::callback<void()> action) {
    auto result = std::shared_ptr<NativeView>(new NativeView());
    onMain(^{
        UIButton* button = [UIButton buttonWithType:UIButtonTypeSystem];
        [button setTitle:ns(title) forState:UIControlStateNormal];
        if (!symbol.empty()) [button setImage:[UIImage systemImageNamed:ns(symbol)] forState:UIControlStateNormal];
        DoofActionTarget* target = [DoofActionTarget new]; target.action = std::move(action);
        [button addTarget:target action:@selector(pressed:) forControlEvents:UIControlEventTouchUpInside];
        result->impl_->view = button; result->impl_->adapter = target;
    });
    return result;
}

std::shared_ptr<NativeView> NativeView::textEditor(
    const std::string& value, double fontSize, int32_t tabWidth, bool autoIndent,
    doof::callback<void(std::string)> change,
    doof::callback<void(int32_t, int32_t)> selectionChange,
    doof::callback<std::string(int32_t)> completions) {
    auto result = std::shared_ptr<NativeView>(new NativeView());
    onMain(^{
        DoofTextView* view = [DoofTextView new];
        view.text = ns(value); view.font = [UIFont monospacedSystemFontOfSize:fontSize weight:UIFontWeightRegular];
        view.backgroundColor = UIColor.secondarySystemBackgroundColor;
        view.textColor = UIColor.labelColor; view.alwaysBounceVertical = YES;
        view.autocapitalizationType = UITextAutocapitalizationTypeNone;
        view.autocorrectionType = UITextAutocorrectionTypeNo; view.spellCheckingType = UITextSpellCheckingTypeNo;
        view.smartQuotesType = UITextSmartQuotesTypeNo; view.smartDashesType = UITextSmartDashesTypeNo;
        view.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
        view.autoIndent = autoIndent; view.indentationWidth = tabWidth;
        DoofEditorAdapter* adapter = [DoofEditorAdapter new]; adapter.view = view;
        adapter.change = std::move(change); adapter.selectionChange = std::move(selectionChange); adapter.fontSize = fontSize;
        adapter.completions = std::move(completions);
        view.delegate = adapter; result->impl_->view = view; result->impl_->adapter = adapter;
    });
    return result;
}

void NativeView::append(std::shared_ptr<NativeView> child) {
    impl_->children.push_back(child);
    auto impl = impl_; auto childImpl = child->impl_;
    onMain(^{ [impl->document ?: impl->view addSubview:childImpl->view]; });
}

void NativeView::completeTextEditor() {
    auto impl = impl_;
    onMain(^{ if (!impl->disposed && impl->adapter) [(DoofEditorAdapter*)impl->adapter complete]; });
}
void NativeView::detach() { auto impl = impl_; onMain(^{ [impl->view removeFromSuperview]; }); }
void NativeView::dispose() {
    if (!impl_ || impl_->disposed) return;
    impl_->disposed = true;
    auto impl = impl_;
    onMain(^{
        if ([impl->adapter isKindOfClass:DoofEditorAdapter.class]) {
            DoofEditorAdapter* adapter = impl->adapter; adapter.change = {}; adapter.selectionChange = {}; adapter.completions = {};
        } else if ([impl->adapter isKindOfClass:DoofActionTarget.class]) {
            ((DoofActionTarget*)impl->adapter).action = {};
        }
        [impl->view removeFromSuperview]; impl->adapter = nil; impl->view = nil; impl->document = nil; impl->scroll = nil;
    });
    impl_->children.clear();
}
void NativeView::setFrame(double x, double y, double width, double height) {
    auto impl = impl_; onMain(^{ impl->view.frame = CGRectMake(x, y, MAX(0, width), MAX(0, height)); });
}
void NativeView::setDocumentSize(double width, double height) {
    auto impl = impl_; onMain(^{
        if (!impl->scroll || !impl->document) return;
        impl->document.frame = CGRectMake(0, 0, width, height); impl->scroll.contentSize = CGSizeMake(width, height);
    });
}
static CGSize measuredSize(UIView* view, const std::optional<double>& maxWidth, const std::optional<double>& maxHeight) {
    __block CGSize result = CGSizeMake(0.0, 0.0);
    onMain(^{ result = [view sizeThatFits:CGSizeMake(maxWidth.value_or(CGFLOAT_MAX), maxHeight.value_or(CGFLOAT_MAX))]; });
    return result;
}
double NativeView::measureWidth(const std::optional<double>& w, const std::optional<double>& h) { return measuredSize(impl_->view, w, h).width; }
double NativeView::measureHeight(const std::optional<double>& w, const std::optional<double>& h) { return measuredSize(impl_->view, w, h).height; }
void NativeView::setText(const std::string& value) { auto impl = impl_; onMain(^{
    if ([impl->view isKindOfClass:UILabel.class]) ((UILabel*)impl->view).text = ns(value);
    if ([impl->view isKindOfClass:UIButton.class]) [((UIButton*)impl->view) setTitle:ns(value) forState:UIControlStateNormal];
}); }
void NativeView::setEnabled(bool value) { auto impl = impl_; onMain(^{ if ([impl->view isKindOfClass:UIControl.class]) ((UIControl*)impl->view).enabled = value; }); }
void NativeView::setHidden(bool value) { auto impl = impl_; onMain(^{ impl->view.hidden = value; }); }
void NativeView::setAccessibility(const std::string& label, const std::string& hint, const std::string& identifier) {
    auto impl = impl_; onMain(^{ impl->view.accessibilityLabel = ns(label); impl->view.accessibilityHint = ns(hint); impl->view.accessibilityIdentifier = ns(identifier); });
}
void NativeView::setTextStyle(double size, bool semibold, bool secondary) { auto impl = impl_; onMain(^{
    if (![impl->view isKindOfClass:UILabel.class]) return;
    UILabel* label = (UILabel*)impl->view;
    label.font = [UIFont systemFontOfSize:size weight:semibold ? UIFontWeightSemibold : UIFontWeightRegular];
    label.textColor = secondary ? UIColor.secondaryLabelColor : UIColor.labelColor;
}); }

std::string NativeView::textEditorText() { __block std::string result; auto impl = impl_; onMain(^{ result = utf8(((UITextView*)impl->view).text ?: @""); }); return result; }
void NativeView::setTextEditorText(const std::string& value) { auto impl = impl_; onMain(^{
    DoofEditorAdapter* adapter = impl->adapter; UITextView* view = (UITextView*)impl->view;
    if ([view.text isEqualToString:ns(value)]) return; adapter.suppress = YES; view.text = ns(value); adapter.suppress = NO;
}); }
void NativeView::setTextEditorHighlights(
    const std::shared_ptr<std::vector<int32_t>>& starts,
    const std::shared_ptr<std::vector<int32_t>>& lengths,
    const std::shared_ptr<std::vector<int32_t>>& styles) {
    auto impl = impl_; onMain(^{
        DoofEditorAdapter* adapter = impl->adapter; UITextView* view = (UITextView*)impl->view;
        NSRange selection = view.selectedRange; NSString* value = view.text ?: @"";
        NSMutableAttributedString* text = [[NSMutableAttributedString alloc] initWithString:value attributes:@{
            NSFontAttributeName: [UIFont monospacedSystemFontOfSize:adapter.fontSize weight:UIFontWeightRegular],
            NSForegroundColorAttributeName: UIColor.labelColor,
        }];
        for (size_t i = 0; i < starts->size() && i < lengths->size() && i < styles->size(); ++i) {
            NSRange range = utf16Range(value, (*starts)[i], (*lengths)[i]); if (range.location == NSNotFound) continue;
            int32_t style = (*styles)[i]; [text addAttribute:NSForegroundColorAttributeName value:editorColor(style) range:range];
            if (style == 7 || style == 8) [text addAttributes:@{NSUnderlineStyleAttributeName: @(NSUnderlineStyleSingle), NSUnderlineColorAttributeName: editorColor(style)} range:range];
        }
        adapter.suppress = YES; view.attributedText = text;
        if (NSMaxRange(selection) <= value.length) view.selectedRange = selection; adapter.suppress = NO;
    });
}
int32_t NativeView::textEditorSelectionStart() { __block int32_t result = 0; auto impl = impl_; onMain(^{ UITextView* view = (UITextView*)impl->view; result = byteLength(view.text ?: @"", NSMakeRange(0, view.selectedRange.location)); }); return result; }
int32_t NativeView::textEditorSelectionLength() { __block int32_t result = 0; auto impl = impl_; onMain(^{ UITextView* view = (UITextView*)impl->view; result = byteLength(view.text ?: @"", view.selectedRange); }); return result; }
void NativeView::setTextEditorSelection(int32_t start, int32_t length, bool reveal) { auto impl = impl_; onMain(^{ UITextView* view = (UITextView*)impl->view; NSRange range = utf16Range(view.text ?: @"", start, length); if (range.location != NSNotFound) { view.selectedRange = range; if (reveal) [view scrollRangeToVisible:range]; } }); }

} // namespace doof_uikit

@interface DoofScreenController : UIViewController
@property(nonatomic) UIView* content;
@property(nonatomic) doof::callback<void(double, double)> layout;
@end
@implementation DoofScreenController
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    UIEdgeInsets insets = self.view.safeAreaInsets;
    CGRect bounds = UIEdgeInsetsInsetRect(self.view.bounds, insets);
    self.content.frame = bounds;
    if (self.layout) {
        doof::detail::ActiveActorScope active(&doof::detail::ApplicationDomain::shared());
        self.layout.call(bounds.size.width, bounds.size.height);
    }
}
@end

@interface DoofBarTarget : NSObject
@property(nonatomic) std::vector<doof::callback<void()>> actions;
- (void)pressed:(UIBarButtonItem*)sender;
@end
@implementation DoofBarTarget
- (void)pressed:(UIBarButtonItem*)sender {
    NSInteger index = sender.tag;
    if (index >= 0 && (size_t)index < self.actions.size() && self.actions[index]) {
        doof::detail::ActiveActorScope active(&doof::detail::ApplicationDomain::shared());
        self.actions[index].call();
    }
}
@end

@interface DoofDocumentDelegate : NSObject <UIDocumentPickerDelegate>
@property(nonatomic) doof::callback<void(std::optional<std::string>)> openHandler;
@property(nonatomic) doof::callback<void(bool)> exportHandler;
@end
@implementation DoofDocumentDelegate
- (void)documentPicker:(UIDocumentPickerViewController*)controller didPickDocumentsAtURLs:(NSArray<NSURL*>*)urls {
    NSURL* url = urls.firstObject;
    doof::detail::ActiveActorScope active(&doof::detail::ApplicationDomain::shared());
    if (self.openHandler) {
        if (!url) self.openHandler.call(std::nullopt);
        else {
            BOOL scoped = [url startAccessingSecurityScopedResource];
            self.openHandler.call(std::optional<std::string>(utf8(url.path)));
            if (scoped) [url stopAccessingSecurityScopedResource];
        }
        self.openHandler = {};
    } else if (self.exportHandler) {
        self.exportHandler.call(url != nil); self.exportHandler = {};
    }
}
- (void)documentPickerWasCancelled:(UIDocumentPickerViewController*)controller {
    doof::detail::ActiveActorScope active(&doof::detail::ApplicationDomain::shared());
    if (self.openHandler) { self.openHandler.call(std::nullopt); self.openHandler = {}; }
    if (self.exportHandler) { self.exportHandler.call(false); self.exportHandler = {}; }
}
@end


namespace doof_uikit {

struct NativeScreen::Impl {
    std::shared_ptr<NativeView> root;
    std::string title;
    std::vector<std::string> leadingTitles, leadingSymbols, trailingTitles, trailingSymbols;
    std::vector<doof::callback<void()>> leadingActions, trailingActions;
    doof::callback<void(double, double)> layout;
    DoofScreenController* controller = nil;
    DoofBarTarget* leadingTarget = nil;
    DoofBarTarget* trailingTarget = nil;
    DoofDocumentDelegate* documentDelegate = nil;
    std::mutex mutex;
    std::condition_variable lifetime;
};

NativeScreen::NativeScreen() : impl_(std::make_shared<Impl>()) {}
NativeScreen::~NativeScreen() = default;

static std::vector<std::string> copyStrings(const std::shared_ptr<std::vector<std::string>>& values) { return values ? *values : std::vector<std::string>(); }
static std::vector<doof::callback<void()>> copyActions(const std::shared_ptr<std::vector<doof::callback<void()>>>& values) { return values ? *values : std::vector<doof::callback<void()>>(); }

std::shared_ptr<NativeScreen> NativeScreen::create(
    const std::string& title, std::shared_ptr<NativeView> root,
    const std::shared_ptr<std::vector<std::string>>& leadingTitles,
    const std::shared_ptr<std::vector<std::string>>& leadingSymbols,
    const std::shared_ptr<std::vector<doof::callback<void()>>>& leadingActions,
    const std::shared_ptr<std::vector<std::string>>& trailingTitles,
    const std::shared_ptr<std::vector<std::string>>& trailingSymbols,
    const std::shared_ptr<std::vector<doof::callback<void()>>>& trailingActions,
    doof::callback<void(double, double)> layout) {
    auto result = std::shared_ptr<NativeScreen>(new NativeScreen()); auto impl = result->impl_;
    impl->title = title; impl->root = std::move(root); impl->layout = std::move(layout);
    impl->leadingTitles = copyStrings(leadingTitles); impl->leadingSymbols = copyStrings(leadingSymbols); impl->leadingActions = copyActions(leadingActions);
    impl->trailingTitles = copyStrings(trailingTitles); impl->trailingSymbols = copyStrings(trailingSymbols); impl->trailingActions = copyActions(trailingActions);
    return result;
}

static NSArray<UIBarButtonItem*>* makeBarItems(
    const std::vector<std::string>& titles, const std::vector<std::string>& symbols, DoofBarTarget* target) {
    NSMutableArray<UIBarButtonItem*>* items = [NSMutableArray array];
    for (size_t i = 0; i < titles.size(); ++i) {
        NSString* title = ns(titles[i]); NSString* symbol = i < symbols.size() ? ns(symbols[i]) : @"";
        UIImage* image = symbol.length ? [UIImage systemImageNamed:symbol] : nil;
        UIBarButtonItem* item = image
            ? [[UIBarButtonItem alloc] initWithImage:image style:UIBarButtonItemStylePlain target:target action:@selector(pressed:)]
            : [[UIBarButtonItem alloc] initWithTitle:title style:UIBarButtonItemStylePlain target:target action:@selector(pressed:)];
        item.tag = (NSInteger)i; item.accessibilityLabel = title; [items addObject:item];
    }
    return items;
}

void NativeScreen::run() {
    auto impl = impl_;
    onMain(^{
        UIWindow* window = applicationWindow();
        if (!window) return;
        DoofScreenController* controller = [DoofScreenController new];
        controller.title = ns(impl->title); controller.view.backgroundColor = UIColor.systemBackgroundColor;
        UIView* host = [UIView new];
        [host addSubview:impl->root->impl_->view];
        controller.content = host; controller.layout = impl->layout;
        [controller.view addSubview:host];
        DoofBarTarget* leading = [DoofBarTarget new]; leading.actions = impl->leadingActions;
        DoofBarTarget* trailing = [DoofBarTarget new]; trailing.actions = impl->trailingActions;
        controller.navigationItem.leftBarButtonItems = makeBarItems(impl->leadingTitles, impl->leadingSymbols, leading);
        controller.navigationItem.rightBarButtonItems = makeBarItems(impl->trailingTitles, impl->trailingSymbols, trailing);
        UINavigationController* navigation = [[UINavigationController alloc] initWithRootViewController:controller];
        window.rootViewController = navigation; [window makeKeyAndVisible];
        impl->controller = controller; impl->leadingTarget = leading; impl->trailingTarget = trailing;
    });
    std::unique_lock<std::mutex> lock(impl->mutex);
    impl->lifetime.wait(lock, [] { return false; });
}

void NativeScreen::presentAlert(const std::string& title, const std::string& message) { auto impl = impl_; onMain(^{
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:ns(title) message:ns(message) preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [impl->controller presentViewController:alert animated:YES completion:nil];
}); }

void NativeScreen::openDocument(
    const std::shared_ptr<std::vector<std::string>>& typeIdentifiers,
    doof::callback<void(std::optional<std::string>)> handler) { auto impl = impl_; onMain(^{
    NSMutableArray<UTType*>* types = [NSMutableArray array];
    for (const auto& identifier : *typeIdentifiers) { UTType* type = [UTType typeWithIdentifier:ns(identifier)]; if (type) [types addObject:type]; }
    if (!types.count) [types addObject:UTTypePlainText];
    DoofDocumentDelegate* delegate = [DoofDocumentDelegate new]; delegate.openHandler = std::move(handler);
    UIDocumentPickerViewController* picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:types asCopy:YES];
    picker.delegate = delegate; impl->documentDelegate = delegate;
    [impl->controller presentViewController:picker animated:YES completion:nil];
}); }

void NativeScreen::exportDocument(
    const std::string& path, const std::string& suggestedName, doof::callback<void(bool)> handler) { auto impl = impl_; onMain(^{
    (void)suggestedName;
    NSURL* url = [NSURL fileURLWithPath:ns(path)];
    DoofDocumentDelegate* delegate = [DoofDocumentDelegate new]; delegate.exportHandler = std::move(handler);
    UIDocumentPickerViewController* picker = [[UIDocumentPickerViewController alloc] initForExportingURLs:@[url] asCopy:YES];
    picker.delegate = delegate; impl->documentDelegate = delegate;
    [impl->controller presentViewController:picker animated:YES completion:nil];
}); }

} // namespace doof_uikit
