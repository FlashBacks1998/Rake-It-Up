package org.flashbacks1998.ui.sliders;

import haxe.ds.StringMap;

import org.flashbacks1998.util.StyleUtil;
import org.flashbacks1998.ui.styles.SliderStyle;

import openfl.display.Sprite;
import openfl.display.Shape;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.Graphics;
import openfl.display.DisplayObject;
import openfl.geom.Matrix;
import openfl.geom.Point;
import openfl.events.Event;
import openfl.events.MouseEvent;
import openfl.events.TouchEvent;
import openfl.filters.DropShadowFilter;

/**
 * SliderUI (bitmap-plate optimized)
 * - Track is cached as bitmap (normal/disabled).
 * - Thumb is cached as bitmap plates (normal/hover/down/disabled).
 * - Thumb moves by x translation only => track never recaches.
 * - Thumb content is NOT inside the filtered cached visuals => animating icon doesn't force recache.
 *
 * Dispatches Event.CHANGE when value changes.
 */
class SliderUI extends Sprite {
    public var barWidth(default, null):Int;
    public var barHeight(default, null):Int;

    public var style(default, null):SliderStyle;

    // Track visuals (cached)
    private var trackVisuals:Sprite;
    private var trackBmp:Bitmap;

    // Separate hit shape (so track visuals can have filters without affecting hit testing)
    private var trackHit:Shape;

    // Thumb that moves
    private var thumbContainer:Sprite;   // moved in x
    private var thumbVisuals:Sprite;     // filtered + cached visuals only
    private var thumbBmp:Bitmap;
    private var thumbContent:Sprite;     // unfiltered content/icon

    // State
    private var _enabled:Bool = true;
    private var _hover:Bool = false;
    private var _down:Bool = false;
    private var _dragging:Bool = false;
    private var _dragOffsetX:Float = 0.0; // local offset inside thumb while dragging

    // Value
    public var minValue:Float = 0.0;
    public var maxValue:Float = 1.0;

    private var _value:Float = 0.0;
    public var value(get, set):Float;

    // Snap step in VALUE units (0 = continuous)
    public var step:Float = 0.0;

    // Effective thumb size
    private var _thumbW:Int;
    private var _thumbH:Int;

    // Reused Point to avoid allocations while dragging
    private var _tmpPt:Point = new Point();

    // Caches (shared across all sliders)
    // Track plates: [0]=normal, [1]=disabled
    private static var TRACK_CACHE:StringMap<Array<BitmapData>> = new StringMap();
    // Thumb plates: [0]=normal, [1]=hover, [2]=down, [3]=disabled
    private static var THUMB_CACHE:StringMap<Array<BitmapData>> = new StringMap();

    public function new(
        barWidth:Int = 240,
        barHeight:Int = 18,
        ?style:SliderStyle = null,
        ?thumbBody:DisplayObject = null
    ) {
        super();

        this.barWidth = barWidth;
        this.barHeight = barHeight;
        this.style = (style == null) ? SliderStyle.defaultStyle : style;

        // adopt step from style by default
        this.step = this.style.step;

        computeThumbSize();

        // ---------- Track ----------
        trackVisuals = new Sprite();
        trackVisuals.mouseEnabled = false;
        trackVisuals.mouseChildren = false;
        addChild(trackVisuals);

        trackBmp = new Bitmap();
        trackBmp.smoothing = this.style.smoothing;
        trackVisuals.addChild(trackBmp);

        // Hit rect (transparent) - easier to click than thin bar
        trackHit = new Shape();
        addChild(trackHit);

        applyTrackShadow();

        // ---------- Thumb ----------
        thumbContainer = new Sprite();
        thumbContainer.mouseChildren = false;
        thumbContainer.buttonMode = true;
        addChild(thumbContainer);

        // visuals-only cached layer (shadow lives here)
        thumbVisuals = new Sprite();
        thumbVisuals.mouseEnabled = false;
        thumbVisuals.mouseChildren = false;
        thumbContainer.addChild(thumbVisuals);

        thumbBmp = new Bitmap();
        thumbBmp.smoothing = this.style.smoothing;
        thumbVisuals.addChild(thumbBmp);

        applyThumbShadow();

        // unfiltered content/icon layer (won't force thumb recache if animated)
        thumbContent = new Sprite();
        thumbContent.mouseEnabled = false;
        thumbContent.mouseChildren = false;
        thumbContainer.addChild(thumbContent);

        if (thumbBody != null) {
            thumbContent.addChild(thumbBody);
        }

        // lifecycle
        addEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
        addEventListener(Event.REMOVED_FROM_STAGE, onRemovedFromStage);
    }

    // -------------------------------------------------
    // Setup / lifecycle
    // -------------------------------------------------

    private function onAddedToStage(e:Event):Void {
        removeEventListener(Event.ADDED_TO_STAGE, onAddedToStage);

        ensurePlates();
        syncTrackPlate();
        syncThumbPlate();

        redrawHitArea();
        layout();

        // input
        trackHit.addEventListener(MouseEvent.MOUSE_DOWN, onTrackMouseDown);
        trackHit.addEventListener(TouchEvent.TOUCH_BEGIN, onTrackTouchBegin);

        thumbContainer.addEventListener(MouseEvent.MOUSE_DOWN, onThumbMouseDown);
        thumbContainer.addEventListener(TouchEvent.TOUCH_BEGIN, onThumbTouchBegin);

        thumbContainer.addEventListener(MouseEvent.MOUSE_OVER, onThumbOver);
        thumbContainer.addEventListener(MouseEvent.MOUSE_OUT, onThumbOut);
    }

    private function onRemovedFromStage(e:Event):Void {
        removeEventListener(Event.REMOVED_FROM_STAGE, onRemovedFromStage);

        // local listeners
        try {
            trackHit.removeEventListener(MouseEvent.MOUSE_DOWN, onTrackMouseDown);
            trackHit.removeEventListener(TouchEvent.TOUCH_BEGIN, onTrackTouchBegin);

            thumbContainer.removeEventListener(MouseEvent.MOUSE_DOWN, onThumbMouseDown);
            thumbContainer.removeEventListener(TouchEvent.TOUCH_BEGIN, onThumbTouchBegin);

            thumbContainer.removeEventListener(MouseEvent.MOUSE_OVER, onThumbOver);
            thumbContainer.removeEventListener(MouseEvent.MOUSE_OUT, onThumbOut);
        } catch (_:Dynamic) {}

        stopDragInternal();
    }

    private function computeThumbSize():Void {
        _thumbW = (style.thumbWidth > 0) ? style.thumbWidth : Std.int(barHeight * 1.7);
        _thumbH = (style.thumbHeight > 0) ? style.thumbHeight : Std.int(barHeight * 1.7);

        if (_thumbW < barHeight) _thumbW = barHeight;
        if (_thumbH < barHeight) _thumbH = barHeight;
    }

    private function applyTrackShadow():Void {
        trackVisuals.filters = [
            new DropShadowFilter(
                style.shadowDistance,
                style.shadowAngle,
                style.shadowColor,
                style.shadowAlpha,
                style.shadowBlurX,
                style.shadowBlurY
            )
        ];
        trackVisuals.cacheAsBitmap = true;
    }

    private function applyThumbShadow():Void {
        thumbVisuals.filters = [
            new DropShadowFilter(
                style.shadowDistance,
                style.shadowAngle,
                style.shadowColor,
                style.shadowAlpha,
                style.shadowBlurX,
                style.shadowBlurY
            )
        ];
        thumbVisuals.cacheAsBitmap = true;
    }

    private function redrawHitArea():Void {
        // Make the bar easier to grab by adding vertical padding
        var extra = style.hitExtra;
        var h = barHeight + extra;
        var y = -Std.int(extra / 2);

        var g = trackHit.graphics;
        g.clear();
        g.beginFill(0x000000, 0.0);
        g.drawRect(0, y, barWidth, h);
        g.endFill();
    }

    private function layout():Void {
        // Track at (0,0)
        trackVisuals.x = 0;
        trackVisuals.y = 0;
        trackBmp.x = 0;
        trackBmp.y = 0;

        // Center thumb vertically on the bar
        thumbContainer.y = Std.int((barHeight - _thumbH) * 0.5);

        // Center content inside thumb
        centerThumbContent();

        // Place thumb based on current value
        updateThumbFromValue();
    }

    private function centerThumbContent():Void {
        thumbContent.x = Std.int((_thumbW - thumbContent.width) * 0.5);
        thumbContent.y = Std.int((_thumbH - thumbContent.height) * 0.5);
    }

    // -------------------------------------------------
    // Caching keys
    // -------------------------------------------------

    private inline function clampCorner(cr:Float, h:Int):Float {
        return Math.min(cr, h);
    }

    private function trackKey():String {
        final cr = clampCorner(style.trackCornerRadius, barHeight);
        return "track|"
            + barWidth + "x" + barHeight
            + "|ct:" + style.trackColorTop
            + "|cb:" + style.trackColorBottom
            + "|bc:" + style.trackBorderColor
            + "|bt:" + style.trackBorderThickness
            + "|cr:" + cr
            + "|ga:" + style.trackGlossAlpha;
    }

    private function thumbKey():String {
        final cr = clampCorner(style.thumbCornerRadius, _thumbH);
        return "thumb|"
            + _thumbW + "x" + _thumbH
            + "|ct:" + style.thumbColorTop
            + "|cb:" + style.thumbColorBottom
            + "|bc:" + style.thumbBorderColor
            + "|bt:" + style.thumbBorderThickness
            + "|cr:" + cr
            + "|ga:" + style.thumbGlossAlpha;
    }

    private function ensurePlates():Void {
        // Track plates
        final tKey = trackKey();
        if (!TRACK_CACHE.exists(tKey)) {
            var arr:Array<BitmapData> = [
                renderTrackPlate(true),
                renderTrackPlate(false)
            ];
            TRACK_CACHE.set(tKey, arr);
        }

        // Thumb plates
        final hKey = thumbKey();
        if (!THUMB_CACHE.exists(hKey)) {
            var arr2:Array<BitmapData> = [
                renderThumbPlate(false, false, true),  // normal
                renderThumbPlate(true,  false, true),  // hover
                renderThumbPlate(false, true,  true),  // down
                renderThumbPlate(false, false, false)  // disabled
            ];
            THUMB_CACHE.set(hKey, arr2);
        }
    }

    // -------------------------------------------------
    // Plate rendering (one-time per key)
    // -------------------------------------------------

    private function renderTrackPlate(enabled:Bool):BitmapData {
        var tmp = new Sprite();
        var sBg = new Shape();
        var sRim = new Shape();
        var sGloss = new Shape();
        tmp.addChild(sBg);
        tmp.addChild(sRim);
        tmp.addChild(sGloss);

        drawTrackInto(sBg, sRim, sGloss, enabled);

        var bmd = new BitmapData(barWidth, barHeight, true, 0x00000000);
        bmd.draw(tmp, null, null, null, null, true);
        return bmd;
    }

    private function drawTrackInto(bg:Shape, rim:Shape, gloss:Shape, enabled:Bool):Void {
        var g:Graphics = bg.graphics;
        g.clear();

        var topColor = style.trackColorTop;
        var bottomColor = style.trackColorBottom;
        var borderColor = style.trackBorderColor;

        if (!enabled) {
            topColor = StyleUtil.fadeToGray(topColor, 0.6);
            bottomColor = StyleUtil.fadeToGray(bottomColor, 0.6);
            borderColor = StyleUtil.fadeToGray(borderColor, 0.6);
        }

        var cr = clampCorner(style.trackCornerRadius, barHeight);

        var m = new Matrix();
        m.createGradientBox(barWidth, barHeight, Math.PI / 2, 0, 0);

        g.beginGradientFill("linear", [topColor, bottomColor], [1, 1], [0, 255], m);
        g.drawRoundRect(0, 0, barWidth, barHeight, cr);
        g.endFill();

        var r:Graphics = rim.graphics;
        r.clear();
        r.lineStyle(style.trackBorderThickness, borderColor, 1, true, "normal", "none", "round");
        r.drawRoundRect(0.5, 0.5, barWidth - 1, barHeight - 1, cr);

        // -------- FULL-WIDTH GLOSS (FIX) --------
        var hg:Graphics = gloss.graphics;
        hg.clear();

        var gm = new Matrix();
        gm.createGradientBox(barWidth, barHeight * 0.9, Math.PI / 2, 0, 0);

        hg.beginGradientFill("linear", [0xFFFFFF, 0xFFFFFF], [style.trackGlossAlpha * 0.6, 0.0], [0, 255], gm);
        hg.drawRoundRect(0, barHeight * 0.10, barWidth, barHeight * 0.8, cr * 0.8);
        hg.endFill();

        gloss.alpha = enabled ? 1.0 : 0.6;
    }

    private function renderThumbPlate(hover:Bool, down:Bool, enabled:Bool):BitmapData {
        var tmp = new Sprite();
        var sBg = new Shape();
        var sRim = new Shape();
        var sGloss = new Shape();
        tmp.addChild(sBg);
        tmp.addChild(sRim);
        tmp.addChild(sGloss);

        drawThumbInto(sBg, sRim, sGloss, hover, down, enabled);

        var bmd = new BitmapData(_thumbW, _thumbH, true, 0x00000000);
        bmd.draw(tmp, null, null, null, null, true);
        return bmd;
    }

    private function drawThumbInto(bg:Shape, rim:Shape, gloss:Shape, hover:Bool, down:Bool, enabled:Bool):Void {
        var g:Graphics = bg.graphics;
        g.clear();

        var topColor = style.thumbColorTop;
        var bottomColor = style.thumbColorBottom;
        var borderColor = style.thumbBorderColor;

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

        var cr = clampCorner(style.thumbCornerRadius, _thumbH);

        var m = new Matrix();
        m.createGradientBox(_thumbW, _thumbH, Math.PI / 2, 0, 0);

        g.beginGradientFill("linear", [topColor, bottomColor], [1, 1], [0, 255], m);
        g.drawRoundRect(0, 0, _thumbW, _thumbH, cr);
        g.endFill();

        var r:Graphics = rim.graphics;
        r.clear();
        r.lineStyle(style.thumbBorderThickness, borderColor, 1, true, "normal", "none", "round");
        r.drawRoundRect(0.5, 0.5, _thumbW - 1, _thumbH - 1, cr);

        // -------- FULL-WIDTH THUMB GLOSS (FIX) --------
        var hg:Graphics = gloss.graphics;
        hg.clear();

        var gm = new Matrix();
        gm.createGradientBox(_thumbW, _thumbH * 0.5, Math.PI / 2, 0, 0);

        hg.beginGradientFill("linear", [0xFFFFFF, 0xFFFFFF], [style.thumbGlossAlpha * 0.9, 0.0], [0, 255], gm);
        var glossY:Int = Std.int(_thumbH * 0.08);
        hg.drawRoundRect(0, glossY, _thumbW, Math.max(4, _thumbH * 0.45), Std.int(cr * 0.8));
        hg.endFill();

        gloss.alpha = enabled ? 1.0 : 0.6;
    }

    // -------------------------------------------------
    // Plate sync
    // -------------------------------------------------

    private function syncTrackPlate():Void {
        var plates = TRACK_CACHE.get(trackKey());
        if (plates == null) {
            ensurePlates();
            plates = TRACK_CACHE.get(trackKey());
        }
        trackBmp.bitmapData = plates[_enabled ? 0 : 1];
        trackBmp.x = 0;
        trackBmp.y = 0;
    }

    private inline function thumbPlateIndex():Int {
        return (!_enabled) ? 3 : (_down ? 2 : (_hover ? 1 : 0));
    }

    private function syncThumbPlate():Void {
        var plates = THUMB_CACHE.get(thumbKey());
        if (plates == null) {
            ensurePlates();
            plates = THUMB_CACHE.get(thumbKey());
        }
        thumbBmp.bitmapData = plates[thumbPlateIndex()];
        thumbBmp.x = 0;
        thumbBmp.y = 0;
    }

    // -------------------------------------------------
    // Value mapping
    // -------------------------------------------------

    private inline function clamp(v:Float, lo:Float, hi:Float):Float {
        return (v < lo) ? lo : (v > hi) ? hi : v;
    }

    private function normalizeValue(v:Float):Float {
        final r = maxValue - minValue;
        if (r <= 0) return 0;
        return clamp((v - minValue) / r, 0, 1);
    }

    private function denormalizeValue(t:Float):Float {
        return minValue + t * (maxValue - minValue);
    }

    private function applyStep(v:Float):Float {
        if (step <= 0) return v;
        final s = step;
        return minValue + Math.round((v - minValue) / s) * s;
    }

    private function thumbMinX():Float return 0;
    private function thumbMaxX():Float {
        final mx = barWidth - _thumbW;
        return (mx < 0) ? 0 : mx;
    }

    private function updateThumbFromValue():Void {
        final t = normalizeValue(_value);
        final x = thumbMinX() + t * (thumbMaxX() - thumbMinX());
        thumbContainer.x = x;
    }

    private function setValueFromThumbX(x:Float, dispatch:Bool):Void {
        final minX = thumbMinX();
        final maxX = thumbMaxX();
        final clampedX = clamp(x, minX, maxX);

        final denom = (maxX - minX);
        final t = (denom <= 0) ? 0 : ((clampedX - minX) / denom);

        var v = denormalizeValue(t);
        v = applyStep(v);

        if (Math.abs(v - _value) > 1e-7) {
            _value = v;
            updateThumbFromValue();
            if (dispatch) dispatchEvent(new Event(Event.CHANGE));
        } else {
            updateThumbFromValue();
        }
    }

    // -------------------------------------------------
    // Input
    // -------------------------------------------------

    private function onThumbOver(e:MouseEvent):Void {
        _hover = true;
        syncThumbPlate();
    }

    private function onThumbOut(e:MouseEvent):Void {
        _hover = false;
        syncThumbPlate();
    }

    // Mouse fast path: use local mouseX/mouseY (no globalToLocal)
    private function onTrackMouseDown(e:MouseEvent):Void {
        startDragFromLocal(this.mouseX, this.mouseY, false);
        e.stopPropagation();
    }

    private function onThumbMouseDown(e:MouseEvent):Void {
        startDragFromLocal(this.mouseX, this.mouseY, true);
        e.stopPropagation();
    }

    // Touch path: convert stage coords -> local using RETURN VALUE of globalToLocal
    private function onTrackTouchBegin(e:TouchEvent):Void {
        startDragFromStageTouch(e.stageX, e.stageY, false);
        e.stopPropagation();
    }

    private function onThumbTouchBegin(e:TouchEvent):Void {
        startDragFromStageTouch(e.stageX, e.stageY, true);
        e.stopPropagation();
    }

    private function startDragFromLocal(localX:Float, localY:Float, fromThumb:Bool):Void {
        if (!_enabled) return;

        _dragging = true;
        _down = true;

        if (fromThumb) {
            _dragOffsetX = localX - thumbContainer.x;
            if (_dragOffsetX < 0) _dragOffsetX = 0;
            if (_dragOffsetX > _thumbW) _dragOffsetX = _thumbW;
        } else {
            _dragOffsetX = _thumbW * 0.5;
            setValueFromThumbX(localX - _dragOffsetX, true);
        }

        thumbContainer.y = Std.int((barHeight - _thumbH) * 0.5 + style.thumbPressMove);
        syncThumbPlate();

        if (stage != null) {
            stage.addEventListener(MouseEvent.MOUSE_MOVE, onStageMouseMove);
            stage.addEventListener(MouseEvent.MOUSE_UP, onStageMouseUp);

            stage.addEventListener(TouchEvent.TOUCH_MOVE, onStageTouchMove);
            stage.addEventListener(TouchEvent.TOUCH_END, onStageTouchEnd);
        }
    }

    private inline function updateTmpLocalFromStage(stageX:Float, stageY:Float):Void {
        _tmpPt.x = stageX;
        _tmpPt.y = stageY;

        // IMPORTANT: use returned point (OpenFL may return a new Point)
        var p = globalToLocal(_tmpPt);
        _tmpPt.x = p.x;
        _tmpPt.y = p.y;
    }

    private function startDragFromStageTouch(stageX:Float, stageY:Float, fromThumb:Bool):Void {
        if (!_enabled) return;

        _dragging = true;
        _down = true;

        updateTmpLocalFromStage(stageX, stageY);

        if (fromThumb) {
            _dragOffsetX = _tmpPt.x - thumbContainer.x;
            if (_dragOffsetX < 0) _dragOffsetX = 0;
            if (_dragOffsetX > _thumbW) _dragOffsetX = _thumbW;
        } else {
            _dragOffsetX = _thumbW * 0.5;
            setValueFromThumbX(_tmpPt.x - _dragOffsetX, true);
        }

        thumbContainer.y = Std.int((barHeight - _thumbH) * 0.5 + style.thumbPressMove);
        syncThumbPlate();

        if (stage != null) {
            stage.addEventListener(MouseEvent.MOUSE_MOVE, onStageMouseMove);
            stage.addEventListener(MouseEvent.MOUSE_UP, onStageMouseUp);

            stage.addEventListener(TouchEvent.TOUCH_MOVE, onStageTouchMove);
            stage.addEventListener(TouchEvent.TOUCH_END, onStageTouchEnd);
        }
    }

    private function onStageMouseMove(e:MouseEvent):Void {
        if (!_dragging) return;
        setValueFromThumbX(this.mouseX - _dragOffsetX, true);
    }

    private function onStageTouchMove(e:TouchEvent):Void {
        if (!_dragging) return;
        updateTmpLocalFromStage(e.stageX, e.stageY);
        setValueFromThumbX(_tmpPt.x - _dragOffsetX, true);
    }

    private function onStageMouseUp(e:MouseEvent):Void endDrag();
    private function onStageTouchEnd(e:TouchEvent):Void endDrag();

    private function endDrag():Void {
        if (!_dragging) return;

        _dragging = false;
        _down = false;

        thumbContainer.y = Std.int((barHeight - _thumbH) * 0.5);
        syncThumbPlate();
        stopDragInternal();
    }

    private function stopDragInternal():Void {
        if (stage == null) return;
        stage.removeEventListener(MouseEvent.MOUSE_MOVE, onStageMouseMove);
        stage.removeEventListener(MouseEvent.MOUSE_UP, onStageMouseUp);
        stage.removeEventListener(TouchEvent.TOUCH_MOVE, onStageTouchMove);
        stage.removeEventListener(TouchEvent.TOUCH_END, onStageTouchEnd);
    }

    // -------------------------------------------------
    // Public API
    // -------------------------------------------------

    public function setEnabled(v:Bool):Void {
        _enabled = v;
        this.mouseEnabled = v;

        if (!v) {
            _dragging = false;
            _down = false;
            stopDragInternal();
        }

        syncTrackPlate();
        syncThumbPlate();
    }

    public function getEnabled():Bool return _enabled;

    public function getThumbContentContainer():Sprite return thumbContent;

    public function setThumbBody(body:DisplayObject):Void {
        while (thumbContent.numChildren > 0) thumbContent.removeChildAt(0);
        if (body != null) thumbContent.addChild(body);
        centerThumbContent();
    }

    public function setSize(newBarWidth:Int, newBarHeight:Int):Void {
        barWidth = newBarWidth;
        barHeight = newBarHeight;

        computeThumbSize();
        ensurePlates();
        syncTrackPlate();
        syncThumbPlate();

        redrawHitArea();
        layout();
    }

    public function refreshStyle(?newStyle:SliderStyle):Void {
        if (newStyle != null) style = newStyle;

        step = style.step;
        computeThumbSize();

        applyTrackShadow();
        applyThumbShadow();

        ensurePlates();
        syncTrackPlate();
        syncThumbPlate();

        redrawHitArea();
        layout();
    }

    private function get_value():Float return _value;

    private function set_value(v:Float):Float {
        v = clamp(v, minValue, maxValue);
        v = applyStep(v);

        if (Math.abs(v - _value) > 1e-7) {
            _value = v;
            updateThumbFromValue();
            dispatchEvent(new Event(Event.CHANGE));
        } else {
            updateThumbFromValue();
        }
        return _value;
    }
}