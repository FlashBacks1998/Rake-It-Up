package org.flashbacks1998.rake.ui;

import haxe.ui.containers.Absolute;
import haxe.ui.core.Screen;
import haxe.ui.events.MouseEvent;

/**
 * Compact status surface used as a workaround for the broken
 * NotificationManager. Lives inside the same Stack frame as
 * GnomeEditWindow and reports the outcome of upload / parse / run.
 *
 * Public API:
 *   showSuccess(message, ?details)
 *   showError(message, ?details)
 *
 * Both methods auto-show the window. Close (X) hides it again. The window
 * is draggable by clicking + dragging on the title-bar background.
 */
@:xml('
    <absolute>
        <vbox left="0" top="0" width="100%" height="100%" styleNames="window">
            <hbox id="titleBar" width="100%" styleNames="window-header" style="cursor: pointer;">
                <label
                    id="titleLabel"
                    text="Status"
                    width="100%"
                    styleNames="window-title" />
                <button
                    id="closeButton"
                    text="X"
                    styleNames="settings-close" />
            </hbox>

            <vbox width="100%" height="100%" styleNames="window-body">
                <vbox id="statusBox" width="100%" styleNames="gnome-status-box">
                    <label id="statusText" text="Idle" styleNames="gnome-status" />
                    <label id="subStatusText" text="" styleNames="gnome-substatus" />
                </vbox>
            </vbox>
        </vbox>
    </absolute>
')
class GnomeStatusWindow extends Absolute {
    // Drag state — set on title-bar MOUSE_DOWN, cleared on Screen MOUSE_UP.
    private var _dragging:Bool = false;
    private var _dragOffsetX:Float = 0;
    private var _dragOffsetY:Float = 0;

    public function new() {
        super();

        // Default close: just hide the window. Consumers (e.g. SceneTestSR01)
        // can override this to route somewhere else.
        closeButton.onClick = _ -> hide();

        // Start hidden — only appears when GnomeSystem reports a result.
        hide();

        // Title bar is the drag handle. We grab MOUSE_DOWN here, then track
        // MOUSE_MOVE / MOUSE_UP on Screen so the drag continues even if the
        // cursor leaves the title bar bounds (and works through any other
        // overlays sitting above the window).
        titleBar.registerEvent(MouseEvent.MOUSE_DOWN, onTitleBarMouseDown);
    }

    // -------------------------------------------------
    // Drag
    // -------------------------------------------------

    private function onTitleBarMouseDown(e:MouseEvent):Void {
        // The close button lives inside titleBar — don't start a drag if the
        // user clicked it. Lets X behave normally.
        if (e.target == closeButton) return;

        _dragging = true;

        // Capture the offset from the window's top-left to the click point so
        // the grab feels anchored: a 5-pixel cursor move produces a 5-pixel
        // window move (rather than snapping the title-bar to the cursor).
        _dragOffsetX = e.screenX - this.left;
        _dragOffsetY = e.screenY - this.top;

        Screen.instance.registerEvent(MouseEvent.MOUSE_MOVE, onScreenMouseMove);
        Screen.instance.registerEvent(MouseEvent.MOUSE_UP,   onScreenMouseUp);
    }

    private function onScreenMouseMove(e:MouseEvent):Void {
        if (!_dragging) return;
        this.left = e.screenX - _dragOffsetX;
        this.top  = e.screenY - _dragOffsetY;
    }

    private function onScreenMouseUp(e:MouseEvent):Void {
        if (!_dragging) return;
        _dragging = false;
        Screen.instance.unregisterEvent(MouseEvent.MOUSE_MOVE, onScreenMouseMove);
        Screen.instance.unregisterEvent(MouseEvent.MOUSE_UP,   onScreenMouseUp);
    }

    // -------------------------------------------------
    // Status surface
    // -------------------------------------------------

    /** Render a green-tinted "OK" status. Both args may be null. */
    public function showSuccess(message:String, ?details:String):Void {
        titleLabel.text   = "Success";
        statusText.text    = (message != null && message != "") ? message : "OK";
        subStatusText.text = (details != null) ? details : "";
        statusText.styleNames    = "gnome-status gnome-status-success";
        subStatusText.styleNames = "gnome-substatus";
        show();
    }

    /** Render a red-tinted error status with optional detail (e.g. an exception message). */
    public function showError(message:String, ?details:String):Void {
        titleLabel.text   = "Error";
        statusText.text    = (message != null && message != "") ? message : "Failed";
        subStatusText.text = (details != null) ? details : "";
        statusText.styleNames    = "gnome-status gnome-status-error";
        subStatusText.styleNames = "gnome-substatus gnome-substatus-error";
        show();
    }
}
