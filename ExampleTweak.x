// ExampleTweak.x
// Drop your own .x file here and delete this one.
// The workflow will auto-detect whichever .x file is present.

#import <UIKit/UIKit.h>

// Example: adds a red border to all UIViews (harmless demo)
%hook UIView

- (void)didMoveToWindow {
    %orig;
    if (self.window) {
        self.layer.borderColor = [UIColor redColor].CGColor;
        self.layer.borderWidth = 1.0f;
    }
}

%end
