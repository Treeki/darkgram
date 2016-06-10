#include <UIKit/UIKit.h>
@protocol TGDialogListCellAssetsSource <NSObject>
@end
typedef UIImage *(^TGImageProcessor)(UIImage *);
typedef UIImage *(^TGImageUniversalProcessor)(NSString *, UIImage *);

UIColor *TGColorWithHex(int hex) {
	return [[UIColor alloc] initWithRed:(((hex >> 16) & 0xff) / 255.0f) green:(((hex >> 8) & 0xff) / 255.0f) blue:(((hex) & 0xff) / 255.0f) alpha:1.0f];
}

UIColor *TGColorWithHexAndAlpha(int hex, CGFloat alpha) {
	return [[UIColor alloc] initWithRed:(((hex >> 16) & 0xff) / 255.0f) green:(((hex >> 8) & 0xff) / 255.0f) blue:(((hex) & 0xff) / 255.0f) alpha:alpha];
}

// HEADER SET
static struct { UIColor *bg, *text, *subText; } nvcHeader;
static struct { UIColor *bg, *text, *subText, *selItem; } nvcBody;


enum ColourKludge {
	CKNone = 0,
	CKDialogListTextViewDrawRect,
	CKDialogListCellResetView
};
static ColourKludge colourKludge = CKNone;

%hook UIColor
+(UIColor *)blackColor {
	if (colourKludge == CKDialogListTextViewDrawRect)
		// Hijacks title colour and author name colour in
		// TGDialogListTextView.drawRect
		return nvcBody.text;
	else
		return %orig;
}

-(UIColor *)initWithRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue alpha:(CGFloat)alpha {
	if (colourKludge == CKDialogListTextViewDrawRect)
		// Hijacks encrypted title colour in
		// TGDialogListTextView.drawRect
		return nvcBody.text;
	else if (colourKludge == CKDialogListCellResetView)
		// Hijacks message/action colour in
		// TGDialogListCell.resetView
		return nvcBody.subText;
	else
		return %orig;
}
%end


%hook TGAppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
	// Here we fuckin go

	nvcHeader.bg = TGColorWithHex(0x333333);
	nvcHeader.text = TGColorWithHex(0xeaeaea);
	nvcHeader.subText = TGColorWithHex(0xb0b0b0);
	nvcBody.bg = TGColorWithHex(0x555555);
	nvcBody.text = TGColorWithHex(0xf3f3f3);
	nvcBody.subText = TGColorWithHex(0xc7c7c7);
	nvcBody.selItem = TGColorWithHex(0x888888);

	UINavigationBar *nb = [UINavigationBar appearance];
	nb.barStyle = UIBarStyleBlack;

	return %orig;
}
%end

@interface TGBackdropView : UIView
@end

%hook TGBackdropView
// Changes background of app header and footer (inc. navbars)
+ (TGBackdropView *)viewWithLightNavigationBarStyle {
	TGBackdropView *view = [[%c(TGBackdropView) alloc] init];
	view.backgroundColor = nvcHeader.bg;
	return view;
}
%end

%hook TGViewController
// Changes status bar text to white
- (UIStatusBarStyle)preferredStatusBarStyle {
	return UIStatusBarStyleLightContent;
}
%end

%hook TGDialogListController
- (void)loadView {
	%orig;

	UILabel *label = MSHookIvar<UILabel *>(self, "_titleLabel");
	if (label != nil)
		label.textColor = nvcHeader.text;
}
- (void)loadStatusViews {
	%orig;

	UILabel *label = MSHookIvar<UILabel *>(self, "_titleStatusLabel");
	if (label != nil)
		label.textColor = nvcHeader.text;
}
%end


/* CONVERSATION LIST */
@interface TGDialogListCell : UITableViewCell
@end
@interface TGDialogListTextView : UIView
@end

%hook TGDialogListCell
- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier assetsSource:(id<TGDialogListCellAssetsSource>)assetsSource {
	if ((self = %orig)) {
		self.backgroundColor = nvcBody.bg;

		TGDialogListTextView *textView = MSHookIvar<TGDialogListTextView *>(self, "_textView");
		textView.backgroundColor = nvcBody.bg;

		UIView *selView = MSHookIvar<UIView *>(self, "_selectedBackgroundView");
		selView.backgroundColor = nvcBody.selItem;

		CALayer *sepLayer = MSHookIvar<CALayer *>(self, "_separatorLayer");
		sepLayer.backgroundColor = [UIColor clearColor].CGColor;
	}
	return self;
}
- (void)resetView:(bool)keepState {
	colourKludge = CKDialogListCellResetView;
	%orig;
	colourKludge = CKNone;
}
%end

%hook TGDialogListTextView
- (void)drawRect:(CGRect)rect {
	colourKludge = CKDialogListTextViewDrawRect;
	%orig;
	colourKludge = CKNone;
}
%end

/* CONVERSATIONS */

%hook TGModernConversationTitleView
- (UILabel *)titleLabel {
	UILabel *label = %orig;
	label.textColor = nvcHeader.text;
	return label;
}
- (UILabel *)statusLabel {
	UILabel *label = %orig;
	label.textColor = nvcHeader.subText;
	return label;
}
- (UILabel *)toggleLabel {
	UILabel *label = %orig;
	label.textColor = nvcHeader.subText;
	return label;
}
%end


@interface TGModernConversationInputTextPanel
-(UIButton *)sendButton;
@end

%hook TGModernConversationInputTextPanel
- (instancetype)initWithFrame:(CGRect)frame accessoryView:(UIView *)panelAccessoryView {
	if ((self = %orig)) {
		UIView *bg = MSHookIvar<UIView *>(self, "_backgroundView");
		bg.backgroundColor = nvcHeader.bg;

		[[self sendButton] setTitleColor:nvcHeader.text forState:UIControlStateNormal];
	}
	return self;
}
%end

%hook TGTelegraphConversationMessageAssetsSource
/*- (UIColor *)messageTextColor {
	static UIColor *color = nil;
	if (color == nil)
		color = TGColorWithHex(0xFF00FF);
	return color;
}*/
%end


/* DISABLE ROUND AVATARS */
@interface TGRemoteImageView : UIView
+ (NSMutableDictionary *)universalImageProcessors;
@end

static bool roundAvKludge = false;
%hookf(void, CGContextAddArcToPoint, CGContextRef c, CGFloat x1, CGFloat y1, CGFloat x2, CGFloat y2, CGFloat radius) {
	if (roundAvKludge)
		radius = 1/3.0;
	%orig;
}

%hook TGRemoteImageView
+ (TGImageProcessor)imageProcessorForName:(NSString *)name {
	if ([name hasPrefix:@"circle:"]) {
		TGImageUniversalProcessor proc = [[%c(TGRemoteImageView) universalImageProcessors] objectForKey:@"circle"];
		return [^UIImage *(UIImage *source)
		{
			roundAvKludge = true;
			UIImage *result = proc(name, source);
			roundAvKludge = false;
			return result;
		} copy];
	} else
		return %orig;
}
%end

