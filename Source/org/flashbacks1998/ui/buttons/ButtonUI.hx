package org.flashbacks1998.ui.buttons;

import org.flashbacks1998.ui.events.UIMouseEvent;
import org.flashbacks1998.util.StyleUtil;
import org.flashbacks1998.ui.styles.ButtonStyle;

import openfl.display.Sprite;
import openfl.display.Shape;
import openfl.display.DisplayObject;
import openfl.display.Graphics;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.geom.Matrix;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.text.TextFieldAutoSize;
import openfl.events.Event;
import openfl.events.MouseEvent;
import openfl.events.TouchEvent;
import openfl.filters.DropShadowFilter;

/**
 * ButtonUI (bitmap-plate optimized)
 * - Pre-renders 4 bitmap plates (normal/hover/down/disabled) and swaps them on state changes.
 * - Keeps label + content OUTSIDE the filtered/cached visuals so icons can animate without forcing recache.
 * - Still supports adding children directly (redirected into contentContainer).
 * - Cancels click if released outside the button (common button behavior).
 */
class ButtonUI extends Sprite {
    public var btnWidth:Int;
    public var btnHeight:Int;

    public var style:ButtonStyle;

    private var visuals:Sprite;           // only background visuals + shadow live here
    private var plate:Bitmap;             // the currently-shown plate bitmap
    private var labelField:TextField;
    private var contentContainer:Sprite;

    private var _enabled:Bool = true;
    private var isDown:Bool = false;
    private var isHover:Bool = false;

    // Shared plate cache across all buttons to avoid re-rendering identical styles/sizes
    private static var PLATE_CACHE:Map<String, Array<BitmapData>> = new Map();

    /**
     * Construct:
     * label - text shown on button
     * w,h  - dimensions
     * ?style - optional ButtonStyle
     * ?body  - optional DisplayObject to be added to the content container
     */
    public function new(label:String = "", w:Int = 200, h:Int = 64, ?style:ButtonStyle = null, ?body:DisplayObject = null) {
        super();

        this.btnWidth = w;
        this.btnHeight = h;
        this.style = (style == null) ? ButtonStyle.defaultStyle : style;

        // --- visuals container (cached due to filter) ---
        visuals = new Sprite();
        visuals.mouseEnabled = false;
        visuals.mouseChildren = false;
        super.addChild(visuals);

        // plate bitmap (we set bitmapData later after ADDED_TO_STAGE / build plates)
        plate = new Bitmap();
        plate.smoothing = true;
        visuals.addChild(plate);

        // apply shadow ONLY to visuals (so label/content changes don't force recache)
        applyVisualFilters();

        // --- content + label live outside the filtered visuals ---
        contentContainer = new Sprite();
        super.addChild(contentContainer);

        labelField = new TextField();
        labelField.selectable = false;
        labelField.autoSize = TextFieldAutoSize.CENTER;
        labelField.cacheAsBitmap = true; // label is usually static; caching helps text rendering
        var tf = new TextFormat(this.style.fontName, this.style.fontSize, this.style.fontColor, this.style.bold, null, null, null, null, "center");
        labelField.defaultTextFormat = tf;
        labelField.text = label;
        super.addChild(labelField);

        if (body != null) {
            contentContainer.addChild(body);
            centerBody();
        }

        // interactive hints
        this.buttonMode = true;
        this.mouseChildren = true;

        // safe lifecycle
        addEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
        addEventListener(Event.REMOVED_FROM_STAGE, onRemovedFromStage);
    }

    private function applyVisualFilters():Void {
        visuals.filters = [
            new DropShadowFilter(
                this.style.shadowDistance,
                this.style.shadowAngle,
                this.style.shadowColor,
                this.style.shadowAlpha,
                this.style.shadowBlurX,
                this.style.shadowBlurY
            )
        ];
        // filters auto-force cacheAsBitmap, but being explicit is fine:
        visuals.cacheAsBitmap = true;
    }

    private function onAddedToStage(e:Event):Void {
        removeEventListener(Event.ADDED_TO_STAGE, onAddedToStage);

        // build or reuse cached plates for this style/size
        ensurePlates();
        syncPlate();
        layoutLabel();
        centerBody();

        // pointer listeners
        addEventListener(MouseEvent.MOUSE_OVER, onOver);
        addEventListener(MouseEvent.MOUSE_OUT, onOut);
        addEventListener(MouseEvent.MOUSE_DOWN, onMouseDown);
        addEventListener(TouchEvent.TOUCH_BEGIN, onTouchBegin);
    }

    private function onRemovedFromStage(e:Event):Void {
        removeEventListener(Event.REMOVED_FROM_STAGE, onRemovedFromStage);

        removeEventListener(MouseEvent.MOUSE_OVER, onOver);
        removeEventListener(MouseEvent.MOUSE_OUT, onOut);
        removeEventListener(MouseEvent.MOUSE_DOWN, onMouseDown);
        removeEventListener(TouchEvent.TOUCH_BEGIN, onTouchBegin);

        // make sure stage-level listeners are cleared
        if (stage != null) {
            stage.removeEventListener(MouseEvent.MOUSE_UP, onStageMouseUp);
            stage.removeEventListener(TouchEvent.TOUCH_END, onStageTouchEnd);
        }
    }

    // ---------------------------
    // Plate caching / rendering
    // ---------------------------

    private function plateKey():String {
        // include everything that affects plate pixels (NOT the shadow filter, since that's applied to visuals)
        // Note: if you add new style fields that affect drawing, include them here.
        return
            btnWidth + "x" + btnHeight
            + "|ct:" + style.colorTop
            + "|cb:" + style.colorBottom
            + "|bc:" + style.borderColor
            + "|bt:" + style.borderThickness
            + "|cr:" + style.cornerRadius
            + "|ga:" + style.glossAlpha;
    }

    private function ensurePlates():Void {
        var key = plateKey();
        if (PLATE_CACHE.exists(key)) return;

        // Pre-render four states:
        // 0 normal, 1 hover, 2 down, 3 disabled
        var plates:Array<BitmapData> = [
            renderPlate(false, false, true),
            renderPlate(true,  false, true),
            renderPlate(false, true,  true),
            renderPlate(false, false, false)
        ];

        PLATE_CACHE.set(key, plates);
    }

    private function renderPlate(hover:Bool, down:Bool, enabled:Bool):BitmapData {
        // Draw into temporary vector shapes, then draw() into BitmapData once.
        var tmp = new Sprite();

        var sBg = new Shape();
        var sRim = new Shape();
        var sGloss = new Shape();

        tmp.addChild(sBg);
        tmp.addChild(sRim);
        tmp.addChild(sGloss);

        drawPlateInto(sBg, sRim, sGloss, hover, down, enabled);

        var bmd = new BitmapData(btnWidth, btnHeight, true, 0x00000000);
        bmd.draw(tmp, null, null, null, null, true);
        return bmd;
    }

    private function drawPlateInto(bg:Shape, rim:Shape, gloss:Shape, hover:Bool, down:Bool, enabled:Bool):Void {
        // background gradient
        var g:Graphics = bg.graphics;
        g.clear();

        var matrix:Matrix = new Matrix();
        matrix.createGradientBox(btnWidth, btnHeight, Math.PI / 2, 0, 0);

        var topColor:Int = style.colorTop;
        var bottomColor:Int = style.colorBottom;
        var borderColor:Int = style.borderColor;

        if (!enabled) {
            topColor = StyleUtil.fadeToGray(topColor, 0.6);
            bottomColor = StyleUtil.fadeToGray(bottomColor, 0.6);
            borderColor = StyleUtil.fadeToGray(borderColor, 0.6);
        } else if (down) {
            topColor = StyleUtil.darken(topColor, 0.10);
            bottomColor = StyleUtil.darken(bottomColor, 0.15);
        } else if (hover) {
            topColor = StyleUtil.lighten(topColor, 0.05);
            bottomColor = StyleUtil.lighten(bottomColor, 0.03);
        }

        g.beginGradientFill("linear", [topColor, bottomColor], [1, 1], [0, 255], matrix);
        g.drawRoundRect(0, 0, btnWidth, btnHeight, style.cornerRadius);
        g.endFill();

        // rim / border
        var r:Graphics = rim.graphics;
        r.clear();
        r.lineStyle(style.borderThickness, borderColor, 1, true, "normal", "none", "round");
        r.drawRoundRect(0.5, 0.5, btnWidth - 1, btnHeight - 1, style.cornerRadius);

        // gloss overlay
        var hg:Graphics = gloss.graphics;
        hg.clear();

        var glossMatrix:Matrix = new Matrix();
        glossMatrix.createGradientBox(btnWidth * 0.9, btnHeight * 0.5, Math.PI / 2, btnWidth * 0.05, 0);

        hg.beginGradientFill("linear", [0xFFFFFF, 0xFFFFFF], [style.glossAlpha * 0.9, 0.0], [0, 255], glossMatrix);
        var glossY:Int = Std.int(btnHeight * 0.06);
        hg.drawRoundRect(btnWidth * 0.05, glossY, btnWidth * 0.9, Math.max(4, btnHeight * 0.45), Std.int(style.cornerRadius * 0.8));
        hg.endFill();

        // If disabled, slightly fade gloss too (optional, matches "disabled" vibe)
        gloss.alpha = enabled ? 1.0 : 0.6;
    }

    private function currentPlateIndex():Int {
        return (!_enabled) ? 3 : (isDown ? 2 : (isHover ? 1 : 0));
    }

    private function syncPlate():Void {
        var key = plateKey();
        var plates = PLATE_CACHE.get(key);
        if (plates == null) {
            ensurePlates();
            plates = PLATE_CACHE.get(key);
        }

        plate.bitmapData = plates[currentPlateIndex()];

        // keep visuals aligned and sized
        plate.x = 0;
        plate.y = 0;

        // label alpha when disabled
        labelField.alpha = _enabled ? 1.0 : 0.6;
    }

    // ---------------------------
    // Layout
    // ---------------------------

    private function layoutLabel():Void {
        var tf = new TextFormat(this.style.fontName, this.style.fontSize, this.style.fontColor, this.style.bold, null, null, null, null, "center");
        labelField.defaultTextFormat = tf;
        labelField.setTextFormat(tf);

        labelField.x = Std.int((btnWidth - labelField.textWidth) / 2) - 2;
        labelField.y = Std.int((btnHeight - labelField.textHeight) / 2) - 2;
    }

    inline function centerBody():Void {
        contentContainer.x = (btnWidth - contentContainer.width) / 2;
        contentContainer.y = (btnHeight - contentContainer.height) / 2;
    }

    // ---------------------------
    // Pointer handlers
    // ---------------------------

    private function onOver(e:MouseEvent):Void {
        isHover = true;
        syncPlate();
    }

    private function onOut(e:MouseEvent):Void {
        isHover = false;
        syncPlate();
    }

    private function press():Void {
        if (!_enabled) return;
        if (isDown) return;

        isDown = true;
        this.y += style.pressMove;
        syncPlate();

        // stage-level up listeners (only while pressed)
        if (stage != null) {
            stage.addEventListener(MouseEvent.MOUSE_UP, onStageMouseUp);
            stage.addEventListener(TouchEvent.TOUCH_END, onStageTouchEnd);
        }
    }

    private function release(stageX:Float, stageY:Float):Void {
        if (!_enabled) return;
        if (!isDown) return;

        isDown = false;
        this.y -= style.pressMove;
        syncPlate();

        // click only if released over the button
        if (this.hitTestPoint(stageX, stageY, true)) {
            dispatchEvent(new UIMouseEvent(UIMouseEvent.CLICK, this));
        }
    }

    private function onMouseDown(e:MouseEvent):Void {
        press();
        e.stopPropagation();
    }

    private function onTouchBegin(e:TouchEvent):Void {
        press();
        e.stopPropagation();
    }

    private function onStageMouseUp(e:MouseEvent):Void {
        release(e.stageX, e.stageY);
        if (stage != null) stage.removeEventListener(MouseEvent.MOUSE_UP, onStageMouseUp);
    }

    private function onStageTouchEnd(e:TouchEvent):Void {
        release(e.stageX, e.stageY);
        if (stage != null) stage.removeEventListener(TouchEvent.TOUCH_END, onStageTouchEnd);
    }

    // ---------------------------
    // Public API
    // ---------------------------

    public function setEnabled(v:Bool):Void {
        _enabled = v;
        this.mouseEnabled = v;
        this.buttonMode = v;

        // reset press state if disabling mid-press
        if (!_enabled && isDown) {
            isDown = false;
            this.y -= style.pressMove;
        }

        syncPlate();
    }

    public function getEnabled():Bool {
        return _enabled;
    }

    public function getContentContainer():Sprite {
        return contentContainer;
    }

    public function setLabel(text:String):Void {
        labelField.text = text;
        layoutLabel();
    }

    /**
     * Optional: call if you change style fields at runtime and need to rebuild plates.
     */
    public function refreshStyle(?newStyle:ButtonStyle):Void {
        if (newStyle != null) this.style = newStyle;
        applyVisualFilters(); // shadow values may have changed
        ensurePlates();       // new key => new cached plates
        syncPlate();
        layoutLabel();
    }

    public function dispose():Void {
        try {
            removeEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
            removeEventListener(Event.REMOVED_FROM_STAGE, onRemovedFromStage);
        } catch(_) {}

        if (stage != null) {
            try {
                stage.removeEventListener(MouseEvent.MOUSE_UP, onStageMouseUp);
                stage.removeEventListener(TouchEvent.TOUCH_END, onStageTouchEnd);
            } catch(_) {}
        }
    }

    // Redirect external children into contentContainer (keeps your old API behavior)
    public override function addChild(child:DisplayObject):DisplayObject {
        contentContainer.addChild(child);
        centerBody();
        return child;
    }

    public override function removeChild(child:DisplayObject):DisplayObject {
        contentContainer.removeChild(child);
        centerBody();
        return child;
    }
}