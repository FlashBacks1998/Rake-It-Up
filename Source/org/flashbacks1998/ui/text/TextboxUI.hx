package org.flashbacks1998.ui.text;

import org.flashbacks1998.ui.styles.TextboxStyle;
import openfl.display.Sprite;
import openfl.display.Shape;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.text.TextFieldAutoSize;
import openfl.text.TextFieldType;
import openfl.events.Event;
import openfl.events.MouseEvent;
import openfl.events.TouchEvent;
import openfl.events.TextEvent;

/**
 * TextboxUI
 * - Simple text input / display box with rounded background, border and padding.
 * - Supports wrap (wordWrap) and overflowX/overflowY semantics
 * - Vertical scrolling handled via mouse wheel and touch-drag when content exceeds box
 * - readOnly/enabled flags supported
 * - autoScroll: when true, scrolls to bottom when text changes (useful for consoles)
 */
class TextboxUI extends Sprite {
    public var boxWidth:Int;
    public var boxHeight:Int;

    private var bg:Shape;
    private var border:Shape;
    private var clipMask:Shape;
    private var textField:TextField;
    private var contentContainer:Sprite;

    public var style:TextboxStyle;
 
    // scrolling state
    private var scrollY:Float = 0;
    private var minScroll:Float = 0;
    private var maxScroll:Float = 0;
    private var dragging:Bool = false;
    private var dragStartY:Float = 0;
    private var dragStartScroll:Float = 0;

    public var text(get, set):String;

    public function new(text:String = "", w:Int = 300, h:Int = 40, ?style:TextboxStyle = null) {
        super();

        this.boxWidth = w;
        this.boxHeight = h;
        this.style = style == null ? TextboxStyle.defaultStyle : style;

        bg = new Shape();
        border = new Shape();
        clipMask = new Shape();

        contentContainer = new Sprite();

        addChild(bg);
        addChild(border);
        addChild(contentContainer);

        textField = new TextField();
        textField.selectable = true;
        textField.multiline = true;
        textField.wordWrap = false;
        textField.embedFonts = false;

        textField.defaultTextFormat = new TextFormat(
            this.style.fontName,
            this.style.fontSize,
            this.style.fontColor
        );

        textField.text = text;

        // BONUS FIX: use this.style (not nullable ctor param)
        textField.type = this.style.readOnly ? TextFieldType.DYNAMIC : TextFieldType.INPUT;

        textField.autoSize = TextFieldAutoSize.NONE;
        textField.border = false;
        textField.background = false;
        textField.multiline = true;
        textField.cacheAsBitmap = true;

        contentContainer.addChild(textField);

        addChild(clipMask);
        contentContainer.mask = clipMask;

        addEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
        addEventListener(Event.REMOVED_FROM_STAGE, onRemovedFromStage);
    }

    private function onAddedToStage(e:Event):Void {
        removeEventListener(Event.ADDED_TO_STAGE, onAddedToStage);

        drawBackground();
        applyStyleToTextField();
        layoutTextField();
        refreshScrollLimits(); // will auto-scroll if enabled

        addEventListener(TextEvent.TEXT_INPUT, onTextInput);
        addEventListener(Event.CHANGE, onTextChange);
        addEventListener(MouseEvent.MOUSE_WHEEL, onMouseWheel);
        addEventListener(TouchEvent.TOUCH_BEGIN, onTouchBegin);
        addEventListener(TouchEvent.TOUCH_MOVE, onTouchMove);
        addEventListener(TouchEvent.TOUCH_END, onTouchEnd);

        setEnabled(style.enabled);
        setReadOnly(style.readOnly);
    }

    private function onRemovedFromStage(e:Event):Void {
        removeEventListener(Event.REMOVED_FROM_STAGE, onRemovedFromStage);

        try {
            removeEventListener(TextEvent.TEXT_INPUT, onTextInput);
            removeEventListener(Event.CHANGE, onTextChange);
            removeEventListener(MouseEvent.MOUSE_WHEEL, onMouseWheel);
            removeEventListener(TouchEvent.TOUCH_BEGIN, onTouchBegin);
            removeEventListener(TouchEvent.TOUCH_MOVE, onTouchMove);
            removeEventListener(TouchEvent.TOUCH_END, onTouchEnd);
        } catch (_:Dynamic) {}
    }

    private function drawBackground():Void {
        var r = style.cornerRadius;

        var a:Float = ((style.bgColor >>> 24) & 0xFF) / 255.0;
        var rgb:Int = style.bgColor & 0xFFFFFF;
        var g = bg.graphics;
        g.clear();
        g.beginFill(rgb, a);
        g.drawRoundRect(0, 0, boxWidth, boxHeight, r);
        g.endFill();

        var gb = border.graphics;
        gb.clear();
        if (style.borderThickness > 0) {
            gb.lineStyle(style.borderThickness, style.borderColor, 1, true);
            gb.drawRoundRect(
                Std.int(style.borderThickness / 2),
                Std.int(style.borderThickness / 2),
                boxWidth - style.borderThickness,
                boxHeight - style.borderThickness,
                r
            );
        }

        var gm = clipMask.graphics;
        gm.clear();
        gm.beginFill(0xFFFFFF);
        gm.drawRoundRect(0, 0, boxWidth, boxHeight, r);
        gm.endFill();
    }

    private function applyStyleToTextField():Void {
        if (style.wrap) {
            textField.wordWrap = true;
            textField.multiline = true;
        } else {
            textField.wordWrap = false;
            textField.multiline = style.overflowY;
        }

        var tf = new TextFormat(style.fontName, style.fontSize, style.fontColor);
        textField.defaultTextFormat = tf;
        textField.setTextFormat(tf);
    }

    private function layoutTextField():Void {
        var pad = style.padding;

        textField.x = pad;
        textField.y = pad - Std.int(scrollY);

        var availW = boxWidth - pad * 2;
        textField.width = availW;

        textField.height = Math.max(
            boxHeight - pad * 2,
            Std.int(textField.textHeight) + 8
        );

        if (clipMask.parent != this) addChild(clipMask);
        setChildIndex(clipMask, numChildren - 1);
    }

    /**
     * Recompute scroll bounds. If autoScroll is true, jump to bottom.
     */
    private function refreshScrollLimits():Void {
        var pad = style.padding;

        // TextField under-reports sometimes; a little extra helps
        var contentH = Std.int(textField.textHeight) + 8;
        var availH = boxHeight - pad * 2;

        if (contentH <= availH) {
            minScroll = 0;
            maxScroll = 0;
            scrollY = 0;
        } else {
            minScroll = 0;
            maxScroll = contentH - availH;

            if (style.autoScroll) {
                // KEY: stick to bottom when new text arrives
                scrollY = maxScroll;
            } else {
                // otherwise preserve/clamp whatever the user had
                if (scrollY < minScroll) scrollY = minScroll;
                if (scrollY > maxScroll) scrollY = maxScroll;
            }
        }

        layoutTextField();
    }

    private function onMouseWheel(e:MouseEvent):Void {
        if (!style.overflowY) return;

        var step = Math.max(4, style.fontSize / 2);
        scrollY -= e.delta * step;

        // Optional: if user scrolls manually, stop auto-follow
        // autoScroll = false;

        clampScrollAndApply();
    }

    private function onTouchBegin(e:TouchEvent):Void {
        if (!style.overflowY) return;
        dragging = true;
        dragStartY = e.stageY;
        dragStartScroll = scrollY;
    }

    private function onTouchMove(e:TouchEvent):Void {
        if (!dragging) return;

        var dy = e.stageY - dragStartY;
        scrollY = dragStartScroll - dy;

        // Optional: if user drags manually, stop auto-follow
        // autoScroll = false;

        clampScrollAndApply();
    }

    private function onTouchEnd(e:TouchEvent):Void {
        dragging = false;
    }

    private function clampScrollAndApply():Void {
        if (scrollY < minScroll) scrollY = minScroll;
        if (scrollY > maxScroll) scrollY = maxScroll;
        layoutTextField();
    }

    private function onTextInput(e:TextEvent):Void {}

    private function onTextChange(e:Event):Void {
        refreshScrollLimits(); // will jump to bottom if autoScroll = true
    }

    // ---- public API ----
    public function get_text():String {
        return textField.text;
    }

    public function set_text(text:String):String {
        textField.text = text;

        // Ensure layout/scroll updates even for programmatic changes
        refreshScrollLimits();

        return text;
    }

    public function setText(s:String):Void {
        textField.text = s;
        refreshScrollLimits();
    }

    public function getText():String {
        return textField.text;
    }

    public function setEnabled(v:Bool):Void {
        style.enabled = v;
        this.mouseEnabled = v;

        setReadOnly(!v || style.readOnly);

        textField.alpha = v ? 1 : 0.6;
        drawBackground();
    }

    public function setReadOnly(v:Bool):Void {
        style.readOnly = v;
        textField.type = v ? TextFieldType.DYNAMIC : TextFieldType.INPUT;
        textField.selectable = true;
    }

    public function setSize(w:Int, h:Int):Void {
        boxWidth = w;
        boxHeight = h;
        drawBackground();
        layoutTextField();
        refreshScrollLimits();
    }

    public function setStyle(s:TextboxStyle):Void {
        this.style = s;
        drawBackground();
        applyStyleToTextField();
        layoutTextField();
        refreshScrollLimits();
    }

    public function dispose():Void {
        try {
            removeEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
            removeEventListener(Event.REMOVED_FROM_STAGE, onRemovedFromStage);
        } catch (_:Dynamic) {}

        try {
            removeEventListener(TextEvent.TEXT_INPUT, onTextInput);
            removeEventListener(Event.CHANGE, onTextChange);
            removeEventListener(MouseEvent.MOUSE_WHEEL, onMouseWheel);
            removeEventListener(TouchEvent.TOUCH_BEGIN, onTouchBegin);
            removeEventListener(TouchEvent.TOUCH_MOVE, onTouchMove);
            removeEventListener(TouchEvent.TOUCH_END, onTouchEnd);
        } catch (_:Dynamic) {}

        while (numChildren > 0) removeChildAt(0);
    }
}