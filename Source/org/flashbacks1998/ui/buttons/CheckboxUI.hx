package org.flashbacks1998.ui.buttons;

import org.flashbacks1998.ui.events.ValueChangeEvent;
import org.flashbacks1998.ui.styles.ButtonStyle;
import org.flashbacks1998.ui.styles.CheckboxStyle;
import org.flashbacks1998.util.StyleUtil;

import openfl.display.Sprite;
import openfl.display.Shape;
import openfl.display.Graphics;
import openfl.events.Event;
import openfl.events.MouseEvent;
import openfl.events.TouchEvent;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.text.TextFieldAutoSize;

/**
 * CheckboxUI (Sprite)
 * - Uses a ButtonUI as the square checkbox VISUAL (mouse disabled).
 * - Label text is a TextField to the right.
 * - Transparent hit overlay catches ALL clicks/touches reliably.
 * - Uses CAPTURE-phase stage mouse/touch up so other stopPropagation() won't break it.
 * - boundsPad uses alpha=0 object (fill alpha=1) so it contributes to bounds on all targets.
 * - Dispatches ValueChangeEvent.CHANGE + Event.CHANGE when checked changes.
 */
class CheckboxUI extends Sprite {
    public var style(default, null):CheckboxStyle;

    public var box(default, null):ButtonUI;
    public var labelField(default, null):TextField;

    public var checked(get, set):Bool;
    private var _checked:Bool = false;

    private var _enabled:Bool = true;

    // Overlay hit area (TOPMOST)
    private var hit:Shape;

    // Inside box content container
    private var boundsPad:Shape; // forces contentContainer bounds to boxSize
    private var check:Shape;     // the checkmark

    // cached size
    private var _w:Int = 0;
    private var _h:Int = 0;

    // press state
    private var pressing:Bool = false;

    // for a tiny press feedback (without needing ButtonUI internals)
    private var _boxBaseY:Float = 0;

    public function new(
        text:String = "Checkbox",
        ?checked:Bool = false,
        ?boxStyle:ButtonStyle = null,
        ?style:CheckboxStyle = null
    ) {
        super();

        this.style = (style == null) ? CheckboxStyle.defaultStyle : style;

        // --- box VISUAL only ---
        var bs = (boxStyle == null) ? ButtonStyle.defaultStyle : boxStyle;
        box = new ButtonUI("", this.style.boxSize, this.style.boxSize, bs);
        box.mouseEnabled = false;     // IMPORTANT: we handle interaction ourselves
        box.mouseChildren = false;
        addChild(box);

        // content container inside ButtonUI
        var cc = box.getContentContainer();
        cc.mouseEnabled = false;
        cc.mouseChildren = false;

        // boundsPad must affect bounds even on targets that ignore alpha=0 fills:
        boundsPad = new Shape();
        var pg:Graphics = boundsPad.graphics;
        pg.clear();
        pg.beginFill(0x000000, 1.0);              // fill is opaque...
        pg.drawRect(0, 0, this.style.boxSize, this.style.boxSize);
        pg.endFill();
        boundsPad.alpha = 0.0;                    // ...but the object is invisible
        cc.addChild(boundsPad);

        check = new Shape();
        cc.addChild(check);

        // --- label ---
        labelField = new TextField();
        labelField.selectable = false;
        labelField.autoSize = TextFieldAutoSize.LEFT;
        labelField.cacheAsBitmap = true;
        labelField.mouseEnabled = false; // let the hit overlay receive clicks
        addChild(labelField);

        // --- hit overlay (topmost) ---
        hit = new Shape(); 
        addChild(hit);

        setText(text);
        _checked = checked;
        redrawCheckmark();
        layoutAndRedrawHit();

        setEnabled(true);

        // Input (mouse + touch) — listeners on `this`, not `hit` (Shape can't receive mouse events)
        this.addEventListener(MouseEvent.MOUSE_DOWN, onHitMouseDown);
        this.addEventListener(TouchEvent.TOUCH_BEGIN, onHitTouchBegin);

        this.buttonMode = true;
    }

    // -----------------------
    // Public API
    // -----------------------

    public function setText(text:String):Void {
        var tf = new TextFormat(style.fontName, style.fontSize, style.fontColor, style.bold);
        labelField.defaultTextFormat = tf;
        labelField.text = text;
        labelField.setTextFormat(tf);
        layoutAndRedrawHit();
    }

    public function setEnabled(v:Bool):Void {
        _enabled = v;
        this.mouseEnabled = v;
        this.buttonMode = v;

        // dim label when disabled
        labelField.alpha = v ? 1.0 : 0.6;

        redrawCheckmark();
    }

    public function getEnabled():Bool return _enabled;

    private function get_checked():Bool return _checked;

    private function set_checked(v:Bool):Bool {
        setChecked(v, true);
        return _checked;
    }

    public function setChecked(v:Bool, dispatch:Bool = true):Void {
        if (_checked == v) return;

        var old = _checked;
        _checked = v;

        redrawCheckmark();

        if (dispatch) {
            // Your SettingsTabView listens for ValueChangeEvent.CHANGE
            dispatchEvent(new ValueChangeEvent(ValueChangeEvent.CHANGE, old, _checked, this));
            // also dispatch vanilla change for compatibility
            dispatchEvent(new Event(Event.CHANGE, true));
        }
    }

    // -----------------------
    // Input (CAPTURE SAFE)
    // -----------------------

    private function onHitMouseDown(e:MouseEvent):Void {
        if (!_enabled) return;
        beginPress();
        // optional: prevent clicks leaking to world/3d controls
        e.stopPropagation();
    }

    private function onHitTouchBegin(e:TouchEvent):Void {
        if (!_enabled) return;
        beginPress();
        e.stopPropagation();
    }

    private function beginPress():Void {
        if (pressing) return;
        pressing = true;

        // small feedback: nudge the box down a bit
        box.y = _boxBaseY + 1;

        if (stage != null) {
            // CAPTURE PHASE so other stopPropagation() can't block us
            stage.addEventListener(MouseEvent.MOUSE_UP, onStageMouseUp, true);
            stage.addEventListener(TouchEvent.TOUCH_END, onStageTouchEnd, true);
        }
    }

    private function endPress(stageX:Float, stageY:Float):Void {
        if (!pressing) return;
        pressing = false;

        box.y = _boxBaseY;

        // toggle only if released over this component
        if (this.hitTestPoint(stageX, stageY, true)) {
            checked = !checked;
        }

        clearStageUp();
    }

    private function onStageMouseUp(e:MouseEvent):Void {
        endPress(e.stageX, e.stageY);
    }

    private function onStageTouchEnd(e:TouchEvent):Void {
        endPress(e.stageX, e.stageY);
    }

    private function clearStageUp():Void {
        if (stage == null) return;
        stage.removeEventListener(MouseEvent.MOUSE_UP, onStageMouseUp, true);
        stage.removeEventListener(TouchEvent.TOUCH_END, onStageTouchEnd, true);
    }

    // -----------------------
    // Layout + drawing
    // -----------------------

    private function layoutAndRedrawHit():Void {
        // compute size
        var labelW = Std.int(labelField.textWidth) + 4;
        var labelH = Std.int(labelField.textHeight) + 4;

        _h = Std.int(Math.max(style.boxSize, labelH) + style.paddingY * 2);
        _w = Std.int(style.paddingX * 2 + style.boxSize + style.spacing + labelW);

        // position box and label
        box.x = style.paddingX;
        _boxBaseY = Std.int((_h - style.boxSize) * 0.5);
        box.y = _boxBaseY;

        labelField.x = box.x + style.boxSize + style.spacing;
        labelField.y = Std.int((_h - labelField.textHeight) * 0.5) - 2;

        // draw hit overlay (IMPORTANT: fill alpha=1, object alpha=0)
        var g:Graphics = hit.graphics;
        g.clear();
        g.beginFill(0x000000, 1.0);
        g.drawRect(0, 0, _w, _h);
        g.endFill();
        hit.alpha = 0.0;

        redrawCheckmark();
    }

    private function redrawCheckmark():Void {
        var g:Graphics = check.graphics;
        g.clear();

        if (!_checked) return;

        var s = style.boxSize;

        // checkmark is WHITE (dim when disabled)
        var c = 0xFFFFFF;
        if (!_enabled) c = StyleUtil.fadeToGray(c, 0.6);

        g.lineStyle(style.checkThickness, c, 1, true, "normal", "none", "round");

        g.moveTo(s * 0.24, s * 0.55);
        g.lineTo(s * 0.42, s * 0.72);
        g.lineTo(s * 0.78, s * 0.30);
    }

    // -----------------------
    // Cleanup
    // -----------------------

    public function dispose():Void {
        clearStageUp();

        try { this.removeEventListener(MouseEvent.MOUSE_DOWN, onHitMouseDown); } catch (_:Dynamic) {}
        try { this.removeEventListener(TouchEvent.TOUCH_BEGIN, onHitTouchBegin); } catch (_:Dynamic) {}

        while (numChildren > 0) removeChildAt(0);
    }
}