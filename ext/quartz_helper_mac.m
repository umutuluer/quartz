#import "quartz_helper.h"
#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>
#import <stdatomic.h>
#import <stdio.h>

// ---------------------------------------------------------------------------
// Internal widget map: widget_id -> NSObject* (NSWindow or NSView)
// ---------------------------------------------------------------------------
static NSMutableDictionary<NSNumber*, id> *widgetMap = nil;

// ---------------------------------------------------------------------------
// Callback map: widget_id -> QuartzCallback (stored as NSValue pointer)
// ---------------------------------------------------------------------------
static NSMutableDictionary<NSNumber*, NSValue*> *callbackMap = nil;

// ---------------------------------------------------------------------------
// Thread-safe widget ID counter
// ---------------------------------------------------------------------------
static atomic_int nextWidgetId = 1;

static int32_t next_widget_id(void) {
    return atomic_fetch_add(&nextWidgetId, 1);
}

// ---------------------------------------------------------------------------
// Flipped NSView so (0,0) is top-left (Windows Forms convention)
// ---------------------------------------------------------------------------
@interface QuartzFlippedView : NSView
@end

@implementation QuartzFlippedView
- (BOOL)isFlipped { return YES; }
@end

// ---------------------------------------------------------------------------
// Target object for NSButton actions — bridges to our callback map
// ---------------------------------------------------------------------------
@interface ButtonTarget : NSObject
@property (nonatomic, assign) int32_t widgetId;
- (instancetype)initWithWidgetId:(int32_t)widgetId;
- (void)action:(id)sender;
@end

@implementation ButtonTarget
- (instancetype)initWithWidgetId:(int32_t)widgetId {
    self = [super init];
    if (self) {
        _widgetId = widgetId;
    }
    return self;
}

- (void)action:(id)sender {
    NSValue *val = callbackMap[@(self.widgetId)];
    if (val) {
        QuartzCallback cb = (QuartzCallback)[val pointerValue];
        if (cb) {
            cb(self.widgetId);
        }
    }
}
@end

// ---------------------------------------------------------------------------
// Target object for toggle (CheckBox / RadioButton) actions
// — bridges to our toggle change callback map (offset +300000)
// ---------------------------------------------------------------------------
@interface ToggleTarget : NSObject
@property (nonatomic, assign) int32_t widgetId;
- (instancetype)initWithWidgetId:(int32_t)widgetId;
- (void)toggleAction:(id)sender;
@end

@implementation ToggleTarget
- (instancetype)initWithWidgetId:(int32_t)widgetId {
    self = [super init];
    if (self) {
        _widgetId = widgetId;
    }
    return self;
}

- (void)toggleAction:(id)sender {
    NSValue *val = callbackMap[@(self.widgetId + 300000)];
    if (val) {
        QuartzCallback cb = (QuartzCallback)[val pointerValue];
        if (cb) {
            cb(self.widgetId);
        }
    }
}
@end

// ---------------------------------------------------------------------------
// Delegate for NSTextField text-change notifications (TextBox)
// ---------------------------------------------------------------------------
@interface TextBoxDelegate : NSObject <NSTextFieldDelegate>
@property (nonatomic, assign) int32_t widgetId;
- (instancetype)initWithWidgetId:(int32_t)widgetId;
@end

@implementation TextBoxDelegate
- (instancetype)initWithWidgetId:(int32_t)widgetId {
    self = [super init];
    if (self) {
        _widgetId = widgetId;
    }
    return self;
}

- (void)textDidChange:(NSNotification *)notification {
    // Look up the change callback (stored with a offset key to avoid collision with click callbacks)
    NSValue *val = callbackMap[@(self.widgetId + 100000)];
    if (val) {
        QuartzCallback cb = (QuartzCallback)[val pointerValue];
        if (cb) {
            cb(self.widgetId);
        }
    }
}
@end

// ---------------------------------------------------------------------------
// Delegate for NSTableView selection-change notifications (ListBox)
// ---------------------------------------------------------------------------
@interface ListBoxDelegate : NSObject <NSTableViewDelegate, NSTableViewDataSource>
@property (nonatomic, assign) int32_t widgetId;
@property (nonatomic, strong) NSMutableArray<NSString*> *items;
- (instancetype)initWithWidgetId:(int32_t)widgetId;
@end

@implementation ListBoxDelegate
- (instancetype)initWithWidgetId:(int32_t)widgetId {
    self = [super init];
    if (self) {
        _widgetId = widgetId;
        _items = [NSMutableArray array];
    }
    return self;
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return (NSInteger)[_items count];
}

- (id)tableView:(NSTableView *)tableView
    objectValueForTableColumn:(NSTableColumn *)tableColumn
                          row:(NSInteger)row {
    if (row >= 0 && row < (NSInteger)[_items count]) {
        return _items[(NSUInteger)row];
    }
    return @"";
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    NSValue *val = callbackMap[@(self.widgetId + 200000)];
    if (val) {
        QuartzCallback cb = (QuartzCallback)[val pointerValue];
        if (cb) {
            cb(self.widgetId);
        }
    }
}
@end

// ---------------------------------------------------------------------------
// Delegate for NSComboBox selection/text notifications (ComboBox)
// A single instance handles both channels; each notification method
// dispatches through its own offset key in callbackMap:
//   +400000 → selection changed     +500000 → text changed
// (isTextOnlyCallback is kept for parity with the spec; no gating is needed
// because each method already knows which event fired.)
// ---------------------------------------------------------------------------
@interface ComboBoxDelegate : NSObject <NSComboBoxDelegate>
@property (nonatomic, assign) int32_t widgetId;
@property (nonatomic, assign) BOOL isTextOnlyCallback;
- (instancetype)initWithWidgetId:(int32_t)widgetId;
@end

@implementation ComboBoxDelegate
- (instancetype)initWithWidgetId:(int32_t)widgetId {
    self = [super init];
    if (self) {
        _widgetId = widgetId;
        _isTextOnlyCallback = NO;
    }
    return self;
}

- (void)comboBoxSelectionDidChange:(NSNotification *)notification {
    NSValue *val = callbackMap[@(self.widgetId + 400000)];
    if (val) {
        QuartzCallback cb = (QuartzCallback)[val pointerValue];
        if (cb) {
            cb(self.widgetId);
        }
    }
}

- (void)controlTextDidChange:(NSNotification *)notification {
    NSValue *val = callbackMap[@(self.widgetId + 500000)];
    if (val) {
        QuartzCallback cb = (QuartzCallback)[val pointerValue];
        if (cb) {
            cb(self.widgetId);
        }
    }
}
@end

// ---------------------------------------------------------------------------
// NSApplication delegate
// ---------------------------------------------------------------------------
@interface AppDelegate : NSObject <NSApplicationDelegate>
@end

@implementation AppDelegate
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}
@end

// ===========================================================================
// Public API implementation
// ===========================================================================

void quartz_init(void) {
    if (widgetMap) return; // already initialised

    widgetMap   = [NSMutableDictionary dictionary];
    callbackMap = [NSMutableDictionary dictionary];

    NSApplication *app = [NSApplication sharedApplication];
    AppDelegate *delegate = [[AppDelegate alloc] init];
    [app setDelegate:delegate];
    [app setActivationPolicy:NSApplicationActivationPolicyRegular];
}

void quartz_run(void) {
    NSApplication *app = [NSApplication sharedApplication];
    [app activateIgnoringOtherApps:YES];
    [app run];
}

void quartz_terminate(void) {
    [[NSApplication sharedApplication] terminate:nil];
}

// ---------------------------------------------------------------------------
// Window
// ---------------------------------------------------------------------------
int32_t quartz_window_create(const char* title, int32_t width, int32_t height) {
    int32_t wid = next_widget_id();

    NSUInteger styleMask = NSWindowStyleMaskTitled
                         | NSWindowStyleMaskClosable
                         | NSWindowStyleMaskMiniaturizable
                         | NSWindowStyleMaskResizable;

    NSRect contentRect = NSMakeRect(0, 0, width, height);
    NSWindow *window = [[NSWindow alloc] initWithContentRect:contentRect
                                                   styleMask:styleMask
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];

    [window setTitle:[NSString stringWithUTF8String:title]];
    [window center]; // centre on screen

    // Use a flipped content view so coordinates start at top-left
    QuartzFlippedView *contentView = [[QuartzFlippedView alloc] initWithFrame:contentRect];
    [contentView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [window setContentView:contentView];

    widgetMap[@(wid)] = window;
    return wid;
}

void quartz_window_set_title(int32_t widget_id, const char* title) {
    id obj = widgetMap[@(widget_id)];
    if ([obj isKindOfClass:[NSWindow class]]) {
        [(NSWindow *)obj setTitle:[NSString stringWithUTF8String:title]];
    }
}

void quartz_window_show(int32_t widget_id) {
    id obj = widgetMap[@(widget_id)];
    if ([obj isKindOfClass:[NSWindow class]]) {
        NSWindow *window = (NSWindow *)obj;
        [window makeKeyAndOrderFront:nil];
    }
}

// ---------------------------------------------------------------------------
// Button
// ---------------------------------------------------------------------------
int32_t quartz_button_create(const char* title, int32_t x, int32_t y,
                              int32_t width, int32_t height) {
    int32_t wid = next_widget_id();

    NSRect frame = NSMakeRect(x, y, width, height);
    NSButton *button = [[NSButton alloc] initWithFrame:frame];

    [button setTitle:[NSString stringWithUTF8String:title]];
    [button setBezelStyle:NSBezelStyleRounded];
    [button setButtonType:NSButtonTypeMomentaryPushIn];
    [button setAutoresizingMask:NSViewNotSizable];

    widgetMap[@(wid)] = button;
    return wid;
}

// ---------------------------------------------------------------------------
// Label
// ---------------------------------------------------------------------------
int32_t quartz_label_create(const char* text, int32_t x, int32_t y,
                             int32_t width, int32_t height) {
    int32_t wid = next_widget_id();

    NSRect frame = NSMakeRect(x, y, width, height);
    NSTextField *label = [[NSTextField alloc] initWithFrame:frame];

    [label setStringValue:[NSString stringWithUTF8String:text]];
    [label setBezeled:NO];
    [label setDrawsBackground:NO];
    [label setEditable:NO];
    [label setSelectable:NO];
    [label setAutoresizingMask:NSViewNotSizable];

    widgetMap[@(wid)] = label;
    return wid;
}

// ---------------------------------------------------------------------------
// TextBox
// ---------------------------------------------------------------------------
int32_t quartz_textbox_create(const char* text, int32_t x, int32_t y,
                               int32_t width, int32_t height) {
    int32_t wid = next_widget_id();

    NSRect frame = NSMakeRect(x, y, width, height);
    NSTextField *textField = [[NSTextField alloc] initWithFrame:frame];

    [textField setStringValue:[NSString stringWithUTF8String:text]];
    [textField setEditable:YES];
    [textField setSelectable:YES];
    [textField setBezeled:YES];
    [textField setBezelStyle:NSTextFieldSquareBezel];
    [textField setDrawsBackground:YES];
    [textField setAutoresizingMask:NSViewNotSizable];

    widgetMap[@(wid)] = textField;
    return wid;
}

const char* quartz_textbox_get_text(int32_t widget_id) {
    id obj = widgetMap[@(widget_id)];
    if ([obj isKindOfClass:[NSTextField class]]) {
        return [[(NSTextField *)obj stringValue] UTF8String];
    }
    return "";
}

void quartz_textbox_set_max_length(int32_t widget_id, int32_t max_length) {
    id obj = widgetMap[@(widget_id)];
    if ([obj isKindOfClass:[NSTextField class]]) {
        NSTextField *tf = (NSTextField *)obj;
        // Use NSFormatter to limit input length
        NSNumberFormatter *existing = nil; // Not using number formatter
        // Create a custom text formatter that limits length
        if (max_length > 0) {
            NSTextFieldCell *cell = [tf cell];
            // We'll use the delegate to enforce max length at a higher level
            // For simplicity, we store the max_length as an associated object
            objc_setAssociatedObject(tf, "maxLength",
                                     @(max_length),
                                     OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
}

void quartz_textbox_set_read_only(int32_t widget_id, int32_t read_only) {
    id obj = widgetMap[@(widget_id)];
    if ([obj isKindOfClass:[NSTextField class]]) {
        [(NSTextField *)obj setEditable:read_only ? NO : YES];
    }
}

void quartz_textbox_set_placeholder(int32_t widget_id, const char* text) {
    id obj = widgetMap[@(widget_id)];
    if ([obj isKindOfClass:[NSTextField class]]) {
        [(NSTextField *)obj setPlaceholderString:[NSString stringWithUTF8String:text]];
    }
}

void quartz_textbox_set_password_char(int32_t widget_id, char ch) {
    // On macOS, we swap the NSTextField for an NSSecureTextField is complex.
    // Instead, we just mark it as a secure field by replacing the cell.
    // For v1, we note this is a simplified approach.
    id obj = widgetMap[@(widget_id)];
    if ([obj isKindOfClass:[NSTextField class]]) {
        NSTextField *tf = (NSTextField *)obj;
        // Create a new NSSecureTextField with the same frame
        NSRect frame = [tf frame];
        NSSecureTextField *secure = [[NSSecureTextField alloc] initWithFrame:frame];
        [secure setStringValue:[tf stringValue]];
        [secure setEditable:YES];
        [secure setSelectable:YES];
        [secure setBezeled:YES];
        [secure setDrawsBackground:YES];
        [secure setAutoresizingMask:NSViewNotSizable];

        // If the old field has a superview, swap them
        NSView *parent = [tf superview];
        if (parent) {
            [parent addSubview:secure];
            [tf removeFromSuperview];
        }

        widgetMap[@(widget_id)] = secure;
    }
}

void quartz_textbox_set_change_callback(int32_t widget_id, QuartzCallback callback) {
    id obj = widgetMap[@(widget_id)];

    if (callback) {
        // Store callback with offset key to avoid collision with button click callbacks
        callbackMap[@(widget_id + 100000)] = [NSValue valueWithPointer:(void *)callback];
    } else {
        [callbackMap removeObjectForKey:@(widget_id + 100000)];
    }

    if ([obj isKindOfClass:[NSTextField class]]) {
        NSTextField *tf = (NSTextField *)obj;
        TextBoxDelegate *delegate = [[TextBoxDelegate alloc] initWithWidgetId:widget_id];
        [tf setDelegate:delegate];

        // Retain the delegate so it stays alive
        objc_setAssociatedObject(tf, "textBoxDelegate", delegate,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);

        // Listen for text change notifications
        [[NSNotificationCenter defaultCenter] addObserver:delegate
                                                 selector:@selector(textDidChange:)
                                                     name:NSControlTextDidChangeNotification
                                                   object:tf];
    }
}

// ---------------------------------------------------------------------------
// Widget hierarchy
// ---------------------------------------------------------------------------
void quartz_widget_set_parent(int32_t child_id, int32_t parent_id) {
    id child  = widgetMap[@(child_id)];
    id parent = widgetMap[@(parent_id)];

    if (!child || !parent) return;

    NSView *container = nil;

    if ([parent isKindOfClass:[NSWindow class]]) {
        container = [(NSWindow *)parent contentView];
    } else if ([parent isKindOfClass:[NSView class]]) {
        container = (NSView *)parent;
    }

    if (container) {
        [container addSubview:(NSView *)child];
    }
}

// ---------------------------------------------------------------------------
// Widget properties
// ---------------------------------------------------------------------------
void quartz_widget_set_text(int32_t widget_id, const char* text) {
    id obj = widgetMap[@(widget_id)];
    NSString *nsText = [NSString stringWithUTF8String:text];

    if ([obj isKindOfClass:[NSButton class]]) {
        [(NSButton *)obj setTitle:nsText];
    } else if ([obj isKindOfClass:[NSTextField class]]) {
        [(NSTextField *)obj setStringValue:nsText];
    }
}

void quartz_widget_set_callback(int32_t widget_id, QuartzCallback callback) {
    id obj = widgetMap[@(widget_id)];

    if ([obj isKindOfClass:[NSButton class]]) {
        NSButton *button = (NSButton *)obj;
        ButtonTarget *target = [[ButtonTarget alloc] initWithWidgetId:widget_id];
        [button setTarget:target];
        [button setAction:@selector(action:)];

        // Retain the target so it stays alive (button weakly references target by default)
        // We attach it via objc_setAssociatedObject so it lives as long as the button
        objc_setAssociatedObject(button, (const void *)(uintptr_t)widget_id, target,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    // Always store the callback pointer
    if (callback) {
        callbackMap[@(widget_id)] = [NSValue valueWithPointer:(void *)callback];
    } else {
        [callbackMap removeObjectForKey:@(widget_id)];
    }
}

void quartz_widget_set_enabled(int32_t widget_id, int32_t enabled) {
    id obj = widgetMap[@(widget_id)];

    if ([obj respondsToSelector:@selector(setEnabled:)]) {
        [(NSControl *)obj setEnabled:enabled ? YES : NO];
    }
}
int32_t quartz_listbox_create(int32_t x, int32_t y,
                               int32_t width, int32_t height) {
    int32_t wid = next_widget_id();

    // Create NSScrollView (container with scrollbars)
    NSRect scrollFrame = NSMakeRect(x, y, width, height);
    NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:scrollFrame];
    [scrollView setHasVerticalScroller:YES];
    [scrollView setHasHorizontalScroller:NO];
    [scrollView setAutoresizingMask:NSViewNotSizable];
    [scrollView setBorderType:NSBezelBorder];

    // Create NSTableView (single column)
    NSTableView *tableView = [[NSTableView alloc] initWithFrame:scrollFrame];
    NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier:@"items"];
    [column setWidth:(CGFloat)width - 20.0f]; // leave room for scrollbar
    [tableView addTableColumn:column];
    [tableView setHeaderView:nil];           // no header row
    [tableView setAllowsMultipleSelection:NO];
    [tableView setAutoresizingMask:NSViewNotSizable];

    // Create delegate that also holds the data array
    ListBoxDelegate *delegate = [[ListBoxDelegate alloc] initWithWidgetId:wid];
    [tableView setDelegate:delegate];
    [tableView setDataSource:delegate];

    // Retain delegate via associated object on the tableView
    objc_setAssociatedObject(tableView, "listBoxDelegate", delegate,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    [scrollView setDocumentView:tableView];

    widgetMap[@(wid)] = scrollView;
    return wid;
}

static ListBoxDelegate* get_listbox_delegate(int32_t widget_id) {
    id obj = widgetMap[@(widget_id)];
    NSTableView *tableView = nil;

    if ([obj isKindOfClass:[NSScrollView class]]) {
        tableView = (NSTableView *)[(NSScrollView *)obj documentView];
    } else if ([obj isKindOfClass:[NSTableView class]]) {
        tableView = (NSTableView *)obj;
    }

    if (tableView) {
        ListBoxDelegate *delegate = (ListBoxDelegate *)[tableView delegate];
        if ([delegate isKindOfClass:[ListBoxDelegate class]]) {
            return delegate;
        }
    }
    return nil;
}

void quartz_listbox_add_item(int32_t widget_id, const char* text) {
    ListBoxDelegate *delegate = get_listbox_delegate(widget_id);
    if (delegate) {
        [delegate.items addObject:[NSString stringWithUTF8String:text]];
        NSTableView *tableView = (NSTableView *)[(NSScrollView *)widgetMap[@(widget_id)] documentView];
        if (tableView) {
            [tableView reloadData];
        }
    }
}

void quartz_listbox_remove_item(int32_t widget_id, int32_t index) {
    ListBoxDelegate *delegate = get_listbox_delegate(widget_id);
    if (delegate && index >= 0 && index < (int32_t)[delegate.items count]) {
        [delegate.items removeObjectAtIndex:(NSUInteger)index];
        NSTableView *tableView = (NSTableView *)[(NSScrollView *)widgetMap[@(widget_id)] documentView];
        if (tableView) {
            [tableView reloadData];
        }
    }
}

void quartz_listbox_clear(int32_t widget_id) {
    ListBoxDelegate *delegate = get_listbox_delegate(widget_id);
    if (delegate) {
        [delegate.items removeAllObjects];
        NSTableView *tableView = (NSTableView *)[(NSScrollView *)widgetMap[@(widget_id)] documentView];
        if (tableView) {
            [tableView reloadData];
        }
    }
}

int32_t quartz_listbox_get_selected_index(int32_t widget_id) {
    ListBoxDelegate *delegate = get_listbox_delegate(widget_id);
    if (delegate) {
        NSTableView *tableView = (NSTableView *)[(NSScrollView *)widgetMap[@(widget_id)] documentView];
        if (tableView) {
            NSInteger row = [tableView selectedRow];
            return (row >= 0 && row < (NSInteger)[delegate.items count]) ? (int32_t)row : -1;
        }
    }
    return -1;
}

const char* quartz_listbox_get_selected_text(int32_t widget_id) {
    ListBoxDelegate *delegate = get_listbox_delegate(widget_id);
    if (delegate) {
        NSTableView *tableView = (NSTableView *)[(NSScrollView *)widgetMap[@(widget_id)] documentView];
        if (tableView) {
            NSInteger row = [tableView selectedRow];
            if (row >= 0 && row < (NSInteger)[delegate.items count]) {
                return [[delegate.items objectAtIndex:(NSUInteger)row] UTF8String];
            }
        }
    }
    return NULL;
}

void quartz_listbox_set_selected_index(int32_t widget_id, int32_t index) {
    ListBoxDelegate *delegate = get_listbox_delegate(widget_id);
    if (delegate) {
        NSTableView *tableView = (NSTableView *)[(NSScrollView *)widgetMap[@(widget_id)] documentView];
        if (tableView && index >= -1 && index < (int32_t)[delegate.items count]) {
            if (index >= 0) {
                [tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)index]
                      byExtendingSelection:NO];
            } else {
                [tableView deselectAll:nil];
            }
        }
    }
}

int32_t quartz_listbox_get_item_count(int32_t widget_id) {
    ListBoxDelegate *delegate = get_listbox_delegate(widget_id);
    return delegate ? (int32_t)[delegate.items count] : 0;
}

const char* quartz_listbox_get_item_text(int32_t widget_id, int32_t index) {
    ListBoxDelegate *delegate = get_listbox_delegate(widget_id);
    if (delegate && index >= 0 && index < (int32_t)[delegate.items count]) {
        return [[delegate.items objectAtIndex:(NSUInteger)index] UTF8String];
    }
    return "";
}

void quartz_listbox_set_selection_callback(int32_t widget_id, QuartzCallback callback) {
    if (callback) {
        callbackMap[@(widget_id + 200000)] = [NSValue valueWithPointer:(void *)callback];
    } else {
        [callbackMap removeObjectForKey:@(widget_id + 200000)];
    }
}

// ---------------------------------------------------------------------------
// ComboBox
// ---------------------------------------------------------------------------
int32_t quartz_combobox_create(int32_t x, int32_t y, int32_t w, int32_t h,
                               int32_t editable) {
    int32_t wid = next_widget_id();

    NSRect frame = NSMakeRect(x, y, w, h);
    NSComboBox *comboBox = [[NSComboBox alloc] initWithFrame:frame];

    [comboBox setEditable:(editable ? YES : NO)];
    [comboBox setUsesDataSource:NO]; // simple string-based items
    [comboBox setAutoresizingMask:NSViewNotSizable];

    // Single delegate dispatches both selection (+400000) and text (+500000)
    ComboBoxDelegate *delegate = [[ComboBoxDelegate alloc] initWithWidgetId:wid];
    [comboBox setDelegate:delegate];

    // Retain the delegate so it stays alive (comboBox references it weakly)
    objc_setAssociatedObject(comboBox, "comboBoxDelegate", delegate,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    widgetMap[@(wid)] = comboBox;
    return wid;
}

static NSComboBox* get_combobox(int32_t widget_id) {
    id obj = widgetMap[@(widget_id)];
    if ([obj isKindOfClass:[NSComboBox class]]) {
        return (NSComboBox *)obj;
    }
    return nil;
}

void quartz_combobox_add_item(int32_t wid, const char* text) {
    NSComboBox *comboBox = get_combobox(wid);
    if (comboBox) {
        [comboBox addItemWithObjectValue:[NSString stringWithUTF8String:text]];
    }
}

void quartz_combobox_remove_item(int32_t wid, int32_t index) {
    NSComboBox *comboBox = get_combobox(wid);
    if (comboBox && index >= 0 && index < (int32_t)[comboBox numberOfItems]) {
        [comboBox removeItemAtIndex:index];
    }
}

void quartz_combobox_clear(int32_t wid) {
    NSComboBox *comboBox = get_combobox(wid);
    if (comboBox) {
        [comboBox removeAllItems];
    }
}

int32_t quartz_combobox_get_item_count(int32_t wid) {
    NSComboBox *comboBox = get_combobox(wid);
    return comboBox ? (int32_t)[comboBox numberOfItems] : 0;
}

const char* quartz_combobox_get_item_text(int32_t wid, int32_t index) {
    NSComboBox *comboBox = get_combobox(wid);
    if (comboBox && index >= 0 && index < (int32_t)[comboBox numberOfItems]) {
        return [[comboBox itemObjectValueAtIndex:index] UTF8String];
    }
    return "";
}

int32_t quartz_combobox_get_selected_index(int32_t wid) {
    NSComboBox *comboBox = get_combobox(wid);
    return comboBox ? (int32_t)[comboBox indexOfSelectedItem] : -1;
}

void quartz_combobox_set_selected_index(int32_t wid, int32_t index) {
    NSComboBox *comboBox = get_combobox(wid);
    if (comboBox && index >= -1 && index < (int32_t)[comboBox numberOfItems]) {
        if (index >= 0) {
            [comboBox selectItemAtIndex:index];
        } else {
            NSInteger current = [comboBox indexOfSelectedItem];
            if (current >= 0) {
                [comboBox deselectItemAtIndex:current];
            }
        }
    }
}

const char* quartz_combobox_get_text(int32_t wid) {
    NSComboBox *comboBox = get_combobox(wid);
    if (comboBox) {
        return [[comboBox stringValue] UTF8String];
    }
    return "";
}

void quartz_combobox_set_text(int32_t wid, const char* text) {
    NSComboBox *comboBox = get_combobox(wid);
    if (comboBox) {
        [comboBox setStringValue:[NSString stringWithUTF8String:text]];
    }
}

// macOS (AppKit) exposes no public API to read or write the popup's open
// state, so these are stubs returning 0 (Win32/Qt backends support them).
int32_t quartz_combobox_get_dropped_down(int32_t wid) {
    (void)wid;
    return 0;
}

void quartz_combobox_set_dropped_down(int32_t wid, int32_t dropped) {
    (void)wid;
    (void)dropped;
}

void quartz_combobox_set_selection_callback(int32_t wid, QuartzCallback cb) {
    if (cb) {
        callbackMap[@(wid + 400000)] = [NSValue valueWithPointer:(void *)cb];
    } else {
        [callbackMap removeObjectForKey:@(wid + 400000)];
    }
}

void quartz_combobox_set_text_callback(int32_t wid, QuartzCallback cb) {
    if (cb) {
        callbackMap[@(wid + 500000)] = [NSValue valueWithPointer:(void *)cb];
    } else {
        [callbackMap removeObjectForKey:@(wid + 500000)];
    }
}

// ---------------------------------------------------------------------------
// File dialogs
// ---------------------------------------------------------------------------
static NSArray<NSString*>* parseExtensionsFromFilter(const char* filter) {
    if (!filter || !*filter) return @[];

    NSString *str = [NSString stringWithUTF8String:filter];
    NSArray<NSString*> *parts = [str componentsSeparatedByString:@"|"];
    if (parts.count < 2) return @[];

    NSMutableArray<NSString*> *exts = [NSMutableArray array];
    // Çiftleri atla: display[0], pattern[1], display[2], pattern[3], ...
    for (NSUInteger i = 1; i < parts.count; i += 2) {
        NSString *pattern = parts[i];
        // Basit: "*" veya "*.*" ise boş array dön (tüm dosyalar)
        if ([pattern isEqualToString:@"*"] || [pattern isEqualToString:@"*.*"]) {
            return @[];
        }
        // "*.txt" → "txt"
        if ([pattern hasPrefix:@"*."]) {
            [exts addObject:[pattern substringFromIndex:2]];
        } else if ([pattern hasPrefix:@"."]) {
            [exts addObject:[pattern substringFromIndex:1]];
        } else {
            [exts addObject:pattern];
        }
    }
    return [exts copy];
}

static NSWindow* findOwnerWindow(int32_t owner_widget_id) {
    if (owner_widget_id < 0) return nil;
    id obj = widgetMap[@(owner_widget_id)];
    if ([obj isKindOfClass:[NSWindow class]]) return (NSWindow *)obj;
    // NSView ise: parent window'u bul
    if ([obj isKindOfClass:[NSView class]]) return [(NSView *)obj window];
    return nil;
}

const char* quartz_open_file_dialog(const char* title, const char* filter,
                                    const char* initial_directory, const char* default_ext,
                                    int32_t multiselect, int32_t owner_widget_id) {
    static char buffer[4096];
    buffer[0] = '\0';

    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.canChooseFiles = YES;
    panel.canChooseDirectories = NO;
    panel.allowsMultipleSelection = (multiselect != 0);

    if (title && *title) {
        // NSOpenPanel'da "title" için message kullanılır
        panel.message = [NSString stringWithUTF8String:title];
    }
    if (initial_directory && *initial_directory) {
        panel.directoryURL = [NSURL fileURLWithPath:[NSString stringWithUTF8String:initial_directory]];
    }
    NSArray<NSString*> *exts = parseExtensionsFromFilter(filter);
    if (exts.count > 0) {
        panel.allowedFileTypes = exts;
    }

    // Blocking modal; owner şimdilik ileride sheet kullanımı için saklanır
    NSWindow *owner = findOwnerWindow(owner_widget_id);
    (void)owner;
    NSModalResponse resp = [panel runModal];

    if (resp != NSModalResponseOK) return NULL;

    NSArray<NSURL*> *urls = panel.URLs;
    if (urls.count == 0) return NULL;

    // Multiselect MVP: ilk dosyayı dön (Win32 ile aynı sınırlama)
    NSString *path = [urls[0] path];
    snprintf(buffer, sizeof(buffer), "%s", [path UTF8String]);

    // default_ext: allowedFileTypes üzerinden zaten uygulandı
    (void)default_ext;

    return buffer;
}

const char* quartz_save_file_dialog(const char* title, const char* filter,
                                    const char* initial_directory, const char* default_ext,
                                    const char* file_name, int32_t overwrite_prompt,
                                    int32_t owner_widget_id) {
    static char buffer[4096];
    buffer[0] = '\0';

    NSSavePanel *panel = [NSSavePanel savePanel];

    if (title && *title) {
        panel.message = [NSString stringWithUTF8String:title];
    }
    if (initial_directory && *initial_directory) {
        panel.directoryURL = [NSURL fileURLWithPath:[NSString stringWithUTF8String:initial_directory]];
    }
    if (file_name && *file_name) {
        panel.nameFieldStringValue = [NSString stringWithUTF8String:file_name];
    }
    if (default_ext && *default_ext) {
        panel.allowedFileTypes = @[[NSString stringWithUTF8String:default_ext]];
    }
    // overwrite_prompt: NSSavePanel zaten dosya üzerine yazmayı doğruluyor
    (void)overwrite_prompt;

    // Blocking modal; owner şimdilik ileride sheet kullanımı için saklanır
    NSWindow *owner = findOwnerWindow(owner_widget_id);
    (void)owner;
    NSModalResponse resp = [panel runModal];

    if (resp != NSModalResponseOK) return NULL;

    NSURL *url = panel.URL;
    if (!url) return NULL;

    snprintf(buffer, sizeof(buffer), "%s", [[url path] UTF8String]);
    return buffer;
}

// ---------------------------------------------------------------------------
// CheckBox
// ---------------------------------------------------------------------------
int32_t quartz_checkbox_create(const char* text, int32_t x, int32_t y,
                                int32_t width, int32_t height) {
    int32_t wid = next_widget_id();

    NSRect frame = NSMakeRect(x, y, width, height);
    NSButton *button = [[NSButton alloc] initWithFrame:frame];

    [button setTitle:[NSString stringWithUTF8String:text]];
    [button setButtonType:NSButtonTypeSwitch];
    [button setAutoresizingMask:NSViewNotSizable];

    widgetMap[@(wid)] = button;
    return wid;
}

// ---------------------------------------------------------------------------
// RadioButton
// ---------------------------------------------------------------------------
int32_t quartz_radiobutton_create(const char* text, int32_t x, int32_t y,
                                   int32_t width, int32_t height) {
    int32_t wid = next_widget_id();

    NSRect frame = NSMakeRect(x, y, width, height);
    NSButton *button = [[NSButton alloc] initWithFrame:frame];

    [button setTitle:[NSString stringWithUTF8String:text]];
    [button setButtonType:NSButtonTypeRadio];
    [button setAutoresizingMask:NSViewNotSizable];

    widgetMap[@(wid)] = button;
    return wid;
}

// ---------------------------------------------------------------------------
// Toggle state (shared by CheckBox and RadioButton)
// ---------------------------------------------------------------------------
int32_t quartz_toggle_get_checked(int32_t widget_id) {
    id obj = widgetMap[@(widget_id)];
    if ([obj isKindOfClass:[NSButton class]]) {
        return [(NSButton *)obj state] == NSControlStateValueOn ? 1 : 0;
    }
    return 0;
}

void quartz_toggle_set_checked(int32_t widget_id, int32_t checked) {
    id obj = widgetMap[@(widget_id)];
    if ([obj isKindOfClass:[NSButton class]]) {
        NSButton *button = (NSButton *)obj;
        NSControlStateValue newState = checked ? NSControlStateValueOn : NSControlStateValueOff;
        if ([button state] != newState) {
            [button setState:newState];
            // AppKit does NOT fire the action when state is changed programmatically,
            // so we must manually dispatch the callback.
            NSValue *val = callbackMap[@(widget_id + 300000)];
            if (val) {
                QuartzCallback cb = (QuartzCallback)[val pointerValue];
                if (cb) {
                    cb(widget_id);
                }
            }
        }
    }
}

void quartz_toggle_set_change_callback(int32_t widget_id, QuartzCallback callback) {
    id obj = widgetMap[@(widget_id)];

    if (callback) {
        callbackMap[@(widget_id + 300000)] = [NSValue valueWithPointer:(void *)callback];
    } else {
        [callbackMap removeObjectForKey:@(widget_id + 300000)];
    }

    if ([obj isKindOfClass:[NSButton class]]) {
        NSButton *button = (NSButton *)obj;
        ToggleTarget *target = [[ToggleTarget alloc] initWithWidgetId:widget_id];
        [button setTarget:target];
        [button setAction:@selector(toggleAction:)];

        // Retain the target so it stays alive
        objc_setAssociatedObject(button, (const void *)(uintptr_t)(widget_id + 300000), target,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}
