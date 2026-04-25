package org.flashbacks1998.debugger;

import openfl.display.Sprite;
import openfl.display.Shape;
import openfl.events.Event;
import openfl.events.MouseEvent;
import openfl.text.TextField;
import openfl.text.TextFieldAutoSize;
import openfl.text.TextFormat;
import openfl.geom.Rectangle;

class DebuggerConsole extends Sprite {
    private var tf:TextField;
    private var bg:Shape;

    // container-sized layout
    private var _w:Int = 100;
    private var _h:Int = 100;

    // runtime theme
    private var _textColor:Int = 0xFFFFFF;
    private var _bgColor:Int   = 0x000000;
    private var _bgAlpha:Float = 0.7;

    // optional: make the console follow stage size automatically
    public var followStage:Bool = false;

    // scrollbars
    private var vBar:Sprite;
    private var vThumb:Sprite;
    private var hBar:Sprite;
    private var hThumb:Sprite;
    private var _scrollBarSize:Int = 12;
    private var _draggingThumb:Sprite;

    public function new() {
        super();

        Debugger.log("New console created!");

        addEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
        addEventListener(Event.REMOVED_FROM_STAGE, onRemovedFromStage);
    }

    /** Let parent control our size */
    public function setSize(w:Int, h:Int):Void {
        _w = (w < 1 ? 1 : w);
        _h = (h < 1 ? 1 : h);
        layout();
    }

    /** Set only the text color (applies immediately) */
    public function setTextColor(color:Int):Void {
        _textColor = color;
        applyTextFormat();
    }

    /** Set only the background (applies immediately) */
    public function setBackground(color:Int, alpha:Float = 0.7):Void {
        _bgColor = color;
        _bgAlpha = alpha;
        layout(); // re-draw bg
    }

    /** Set both text + background at once (applies immediately) */
    public function setTheme(textColor:Int, bgColor:Int, bgAlpha:Float = 0.7):Void {
        Debugger.log("Theme set", textColor, bgColor, bgAlpha);

        _textColor = textColor;
        _bgColor   = bgColor;
        _bgAlpha   = bgAlpha;
        applyTextFormat();
        layout();
    }

    private function onAddedToStage(_:Event):Void {
        Debugger.log("New console added to the stage...");

        bg = new Shape();
        addChild(bg);

        tf = new TextField();
        tf.multiline = true;
        tf.wordWrap = false; // allow horizontal scroll
        tf.selectable = true;
        tf.border = true;
        tf.background = true; // let TF also show a background behind text (optional)
        tf.autoSize = TextFieldAutoSize.NONE;

        applyTextFormat();
        addChild(tf);

        // create scrollbars
        createScrollbars();

        var logs = Debugger.logs;
        tf.text = (logs != null && logs.length > 0) ? logs.join("\n") : "";
        tf.scrollV = tf.maxScrollV;

        Debugger.dispatcher.addEventListener(DebuggerEventNewLog.NEW_LOG, onNewLog);
        addEventListener(MouseEvent.MOUSE_WHEEL, onMouseWheel);

        // listen for stage resize to redraw (and optionally grow to fit stage)
        if (stage != null) {
            stage.addEventListener(Event.RESIZE, onResize);
        }

        layout(); // use current _w/_h (parent can call setSize too)
    }

    private function onRemovedFromStage(_:Event):Void {
        removeEventListener(MouseEvent.MOUSE_WHEEL, onMouseWheel);
        Debugger.dispatcher.removeEventListener(DebuggerEventNewLog.NEW_LOG, onNewLog);

        if (stage != null) {
            stage.removeEventListener(Event.RESIZE, onResize);
            stage.removeEventListener(MouseEvent.MOUSE_UP, onThumbUp);
            stage.removeEventListener(MouseEvent.MOUSE_MOVE, onThumbMove);
        }

        if (tf != null && tf.parent == this) removeChild(tf);
        if (bg != null && bg.parent == this) removeChild(bg);

        // cleanup scrollbars
        if (vThumb != null) vThumb.removeEventListener(MouseEvent.MOUSE_DOWN, onVThumbDown);
        if (hThumb != null) hThumb.removeEventListener(MouseEvent.MOUSE_DOWN, onHThumbDown);

        if (vBar != null && vBar.parent == this) removeChild(vBar);
        if (hBar != null && hBar.parent == this) removeChild(hBar);

        tf = null;
        bg = null;
        vBar = null;
        vThumb = null;
        hBar = null;
        hThumb = null;
        _draggingThumb = null;
    }

    /** Redraws background + positions TF using current size and theme */
    private function layout():Void {
        if (tf == null || bg == null) return;

        // honor followStage if enabled
        if (followStage && stage != null) {
            _w = stage.stageWidth;
            _h = stage.stageHeight;
        }

        // visible text area (leave room for scrollbars)
        var viewW = _w - _scrollBarSize;
        var viewH = _h - _scrollBarSize;
        if (viewW < 1) viewW = 1;
        if (viewH < 1) viewH = 1;

        // background
        bg.graphics.clear();
        bg.graphics.beginFill(_bgColor, _bgAlpha);
        bg.graphics.drawRect(0, 0, _w, _h);
        bg.graphics.endFill();

        // text field area
        tf.x = 0;
        tf.y = 0;
        tf.width  = viewW;
        tf.height = viewH;
        tf.backgroundColor = _bgColor;

        // vertical bar
        if (vBar != null) {
            vBar.x = viewW;
            vBar.y = 0;
            vBar.graphics.clear();
            vBar.graphics.beginFill(0x222222, _bgAlpha);
            vBar.graphics.drawRect(0, 0, _scrollBarSize, viewH);
            vBar.graphics.endFill();
        }

        // horizontal bar
        if (hBar != null) {
            hBar.x = 0;
            hBar.y = viewH;
            hBar.graphics.clear();
            hBar.graphics.beginFill(0x222222, _bgAlpha);
            hBar.graphics.drawRect(0, 0, viewW, _scrollBarSize);
            hBar.graphics.endFill();
        }

        updateScrollbars();
    }

    /** Applies the current text color to default + existing text */
    private function applyTextFormat():Void {
        if (tf == null) return;

        var fmt = new TextFormat("_typewriter", 12, _textColor);
        tf.defaultTextFormat = fmt;

        // Apply to existing content too
        if (tf.length > 0) {
            tf.setTextFormat(fmt, 0, tf.length);
        }
        // keep selection readability
        tf.textColor = _textColor;
    }

    private function createScrollbars():Void {
        _scrollBarSize = 12;

        // vertical bar
        vBar = new Sprite();
        addChild(vBar);

        vThumb = new Sprite();
        vThumb.graphics.beginFill(0xCCCCCC, 1);
        vThumb.graphics.drawRect(0, 0, _scrollBarSize, 20);
        vThumb.graphics.endFill();
        vBar.addChild(vThumb);

        // horizontal bar
        hBar = new Sprite();
        addChild(hBar);

        hThumb = new Sprite();
        hThumb.graphics.beginFill(0xCCCCCC, 1);
        hThumb.graphics.drawRect(0, 0, 20, _scrollBarSize);
        hThumb.graphics.endFill();
        hBar.addChild(hThumb);

        // drag listeners
        vThumb.addEventListener(MouseEvent.MOUSE_DOWN, onVThumbDown);
        hThumb.addEventListener(MouseEvent.MOUSE_DOWN, onHThumbDown);
    }

    private function updateScrollbars():Void {
        if (tf == null || vBar == null || hBar == null) return;

        // --- vertical ---
        var maxV = tf.maxScrollV;
        vBar.visible = (maxV > 1);
        if (vBar.visible) {
            var viewH = tf.height;
            var contentH = tf.textHeight + 4;
            if (contentH <= 0) contentH = viewH;

            var ratioVisible = Math.min(1.0, viewH / contentH);
            var barH = vBar.height;
            var minThumb = 20;

            vThumb.height = Math.max(minThumb, barH * ratioVisible);
            vThumb.width  = _scrollBarSize;

            var denom = maxV - 1;
            var scrollRatio:Float = (denom <= 0) ? 0 : (tf.scrollV - 1) / denom;
            if (scrollRatio < 0) scrollRatio = 0;
            if (scrollRatio > 1) scrollRatio = 1;

            vThumb.y = (barH - vThumb.height) * scrollRatio;
        }

        // --- horizontal ---
        var maxH = tf.maxScrollH;
        hBar.visible = (maxH > 0);
        if (hBar.visible) {
            var viewW = tf.width;
            var contentW = tf.textWidth + 4;
            if (contentW <= 0) contentW = viewW;

            var ratioVisibleH = Math.min(1.0, viewW / contentW);
            var barW = hBar.width;
            var minThumbW = 20;

            hThumb.width  = Math.max(minThumbW, barW * ratioVisibleH);
            hThumb.height = _scrollBarSize;

            var scrollRatioH:Float = (maxH <= 0) ? 0 : tf.scrollH / maxH;
            if (scrollRatioH < 0) scrollRatioH = 0;
            if (scrollRatioH > 1) scrollRatioH = 1;

            hThumb.x = (barW - hThumb.width) * scrollRatioH;
        }
    }

    private function onNewLog(e:DebuggerEventNewLog):Void {
        if (tf == null) return;
 
        var wasAtBottom:Bool = (tf.scrollV == tf.maxScrollV);
 
        var oldScrollH:Int   = tf.scrollH;
        var wasAtRight:Bool  = (tf.scrollH == tf.maxScrollH);
 
        if (tf.length > 0) tf.appendText("\n");
        tf.appendText(e.msg);
 
        if (wasAtBottom) {
            tf.scrollV = tf.maxScrollV;
        }
 
        if (wasAtRight) { 
            tf.scrollH = tf.maxScrollH;
        } else { 
            var newMaxH = tf.maxScrollH;
            if (oldScrollH > newMaxH) oldScrollH = newMaxH;
            tf.scrollH = oldScrollH;
        }

        updateScrollbars();
    }


    /** Stage resize: redraw with current size; optionally resize to stage if followStage is true */
    private function onResize(_:Event):Void {
        layout();
    }

    private function onMouseWheel(e:openfl.events.MouseEvent):Void {
        if (tf == null) return;
        if (e.shiftKey) {
            tf.scrollH = Std.int(Math.max(0, tf.scrollH - e.delta * 10));
        } else {
            var target = tf.scrollV - e.delta;
            if (target < 1) target = 1;
            if (target > tf.maxScrollV) target = tf.maxScrollV;
            tf.scrollV = target;
        }
        updateScrollbars();
    }

    private function onVThumbDown(e:MouseEvent):Void {
        if (stage == null || vBar == null) return;
        _draggingThumb = vThumb;

        var bounds = new Rectangle(
            0,
            0,
            0,
            vBar.height - vThumb.height
        );
        vThumb.startDrag(false, bounds);

        stage.addEventListener(MouseEvent.MOUSE_UP, onThumbUp);
        stage.addEventListener(MouseEvent.MOUSE_MOVE, onThumbMove);
    }

    private function onHThumbDown(e:MouseEvent):Void {
        if (stage == null || hBar == null) return;
        _draggingThumb = hThumb;

        var bounds = new Rectangle(
            0,
            0,
            hBar.width - hThumb.width,
            0
        );
        hThumb.startDrag(false, bounds);

        stage.addEventListener(MouseEvent.MOUSE_UP, onThumbUp);
        stage.addEventListener(MouseEvent.MOUSE_MOVE, onThumbMove);
    }

    private function onThumbMove(e:MouseEvent):Void {
        if (_draggingThumb == null || tf == null) return;

        if (_draggingThumb == vThumb && vBar != null) {
            var barH = vBar.height - vThumb.height;
            var ratio:Float = (barH <= 0) ? 0 : vThumb.y / barH;
            var maxV = tf.maxScrollV - 1;
            if (maxV < 0) maxV = 0;
            tf.scrollV = 1 + Std.int(maxV * ratio);
        } else if (_draggingThumb == hThumb && hBar != null) {
            var barW = hBar.width - hThumb.width;
            var ratioH:Float = (barW <= 0) ? 0 : hThumb.x / barW;
            var maxH = tf.maxScrollH;
            tf.scrollH = Std.int(maxH * ratioH);
        }
    }

    private function onThumbUp(e:MouseEvent):Void {
        if (stage != null) {
            stage.removeEventListener(MouseEvent.MOUSE_UP, onThumbUp);
            stage.removeEventListener(MouseEvent.MOUSE_MOVE, onThumbMove);
        }

        if (_draggingThumb != null) {
            _draggingThumb.stopDrag();
            _draggingThumb = null;
        }

        updateScrollbars();
    }
}
