#import "quartz_helper.h"
#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>
#import <stdatomic.h>

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
