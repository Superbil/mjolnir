#import "helpers.h"

/// === hydra.menu ===
///
/// Control Hydra's menu-bar icon.
///
/// Here's a simple example:
///
///     hydra.menu.show(function()
///       return {
///         {title = 'About Hydra', fn = hydra.showabout},
///         {title = '-'},
///         {title = 'Quit', fn = os.exit},
///       }
///     end)



@interface PHMenuItemDelegator : NSObject
@property (copy) dispatch_block_t handler;
@property BOOL disabled;
@end

@implementation PHMenuItemDelegator

- (BOOL) respondsToSelector:(SEL)aSelector {
    if (aSelector == @selector(callCustomHydraMenuItemDelegator:))
        return !self.disabled;
    else
        return [super respondsToSelector:aSelector];
}

- (void) callCustomHydraMenuItemDelegator:(id)sender {
    self.handler();
}

@end


@interface PHMenuDelegate : NSObject <NSMenuDelegate>
@property (copy) dispatch_block_t handler;
@end

@implementation PHMenuDelegate

- (void) menuNeedsUpdate:(NSMenu *)menu {
    self.handler();
}

@end


static NSStatusItem *statusItem;
static PHMenuDelegate* menuDelegate;

static int show_closureref;

static NSImage* menu_icon(NSString* icon_name) {
    NSImage* img = [NSImage imageNamed:icon_name];
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [img setTemplate:YES];
    });
    return img;
}

/// hydra.menu.show(fn() -> itemstable)
/// Shows Hyra's menubar icon. The function should return a table of tables with keys: title, fn, checked (optional), disabled (optional)
static int menu_show(lua_State* L) {
    if (!statusItem) {
        luaL_checktype(L, 1, LUA_TFUNCTION);
        show_closureref = luaL_ref(L, LUA_REGISTRYINDEX);
        
        statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
        [statusItem setHighlightMode:YES];
        [statusItem setImage:menu_icon(@"menu")];
        
        NSMenu* menu = [[NSMenu alloc] init];
        
        menuDelegate = [[PHMenuDelegate alloc] init];
        menuDelegate.handler = ^{
            [menu removeAllItems];
            
            lua_rawgeti(L, LUA_REGISTRYINDEX, show_closureref);
            
            if (lua_pcall(L, 0, 1, 0) == LUA_OK) {
                // table is at top; enumerate each row
                lua_pushvalue(L, -1);
                int tableref = luaL_ref(L, LUA_REGISTRYINDEX);
                
                int menuitem_index = 0;
                
                lua_pushnil(L);
                while (lua_next(L, -2) != 0) {
                    // table is at top; enumerate each k/v pair
                    
                    lua_getfield(L, -1, "title");
                    if (!lua_isstring(L, -1)) luaL_error(L, "error in menu module: expected title to be string.");
                    NSString* title = [NSString stringWithUTF8String: lua_tostring(L, -1)];
                    lua_pop(L, 1);
                    
                    
                    ++menuitem_index;
                    
                    if ([title isEqualToString: @"-"]) {
                        [menu addItem:[NSMenuItem separatorItem]];
                    }
                    else {
                        lua_getfield(L, -1, "checked");
                        BOOL checked = lua_toboolean(L, -1);
                        lua_pop(L, 1);
                        
                        lua_getfield(L, -1, "disabled");
                        BOOL disabled = lua_toboolean(L, -1);
                        lua_pop(L, 1);
                        
                        NSMenuItem* item = [[NSMenuItem alloc] init];
                        PHMenuItemDelegator* delegator = [[PHMenuItemDelegator alloc] init];
                        delegator.disabled = disabled;
                        
                        item.title = title;
                        item.state = checked ? NSOnState : NSOffState;
                        item.action = @selector(callCustomHydraMenuItemDelegator:);
                        item.target = delegator;
                        item.representedObject = delegator;
                        
                        delegator.handler = ^{
                            // get clicked menu item
                            lua_rawgeti(L, LUA_REGISTRYINDEX, tableref);
                            lua_pushnumber(L, menuitem_index);
                            lua_gettable(L, -2);
                            
                            // call function
                            lua_getfield(L, -1, "fn");
                            if (lua_pcall(L, 0, 0, 0))
                                hydra_handle_error(L);
                            
                            // pop menu items table and menu item
                            lua_pop(L, 2);
                            luaL_unref(L, LUA_REGISTRYINDEX, tableref);
                        };
                        
                        [menu addItem:item];
                    }
                    
                    
                    
                    
                    
                    lua_pop(L, 1);
                }
            }
            else {
                hydra_handle_error(L);
            }
        };
        menu.delegate = menuDelegate;
        [statusItem setMenu: menu];
    }
    
    return 0;
}

/// hydra.menu.hide()
/// Hides Hydra's menubar icon.
static int menu_hide(lua_State* L) {
    if (statusItem) {
        luaL_unref(L, LUA_REGISTRYINDEX, show_closureref);
        
        [[statusItem statusBar] removeStatusItem: statusItem];
        statusItem = nil;
    }
    return 0;
}

/// hydra.menu.highlight()
/// Swaps the menubar icon to indicate that Hydra is "active"
/// (for example, because a modal key has been pressed.)
static int menu_highlight() {
    if (statusItem) {
        [statusItem setImage:menu_icon(@"menu_highlight")];
    }
    return 0;
}

/// hydra.menu.unhighlight()
/// Reverts the menubar icon to its normal state.
static int menu_unhighlight() {
    if (statusItem) {
        [statusItem setImage:menu_icon(@"menu")];
    }
    return 0;
}

static const luaL_Reg menulib[] = {
    {"show", menu_show},
    {"hide", menu_hide},
    {"highlight", menu_highlight},
    {"unhighlight", menu_unhighlight},
    {NULL, NULL}
};

int luaopen_hydra_menu(lua_State* L) {
    luaL_newlib(L, menulib);
    return 1;
}
