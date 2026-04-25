package org.flashbacks1998.ui.bars;

import org.flashbacks1998.ui.styles.ProgressBarStyle;
import org.flashbacks1998.util.StyleUtil;
import openfl.display.Sprite;
import openfl.display.Shape;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.text.TextFieldAutoSize;
import openfl.events.Event;
import openfl.geom.Matrix;
import openfl.filters.DropShadowFilter;
import openfl.display.Graphics;

/**
 * UIProgressBar - polished visuals similar to ButtonUI
 */
class ProgressBarUI extends Sprite {
    public var _width:Int;
    public var _height:Int;

    private var style:ProgressBarStyle;

    private var bg:Shape;        // optional background behind control (usually transparent)
    private var track:Shape;     // full track (gradient)
    private var fill:Shape;      // the filled portion (gradient)
    private var rim:Shape;       // rim / border stroke
    private var gloss:Shape;     // glossy overlay
    private var label:TextField;

    private var _progress:Float = 0.0;
    private var _text:String = "";

    /**
     * properties
     */
    public var progress(get, set):Float;
    public var text(get, set):String;

    public function new(w:Int = 300, h:Int = 28, ?style:ProgressBarStyle = null, ?initialText:String = null) {
        super();

        var ds = ProgressBarStyle.defaultStyle;
        if (style == null) {
            // copy defaults
            this.style = {
                width: ds.width, height: ds.height,
                bgColor: ds.bgColor, trackColor: ds.trackColor, barColor: ds.barColor,
                borderColor: ds.borderColor, borderThickness: ds.borderThickness, cornerRadius: ds.cornerRadius,
                glossAlpha: ds.glossAlpha,
                shadowDistance: ds.shadowDistance, shadowAngle: ds.shadowAngle, shadowColor: ds.shadowColor,
                shadowAlpha: ds.shadowAlpha, shadowBlurX: ds.shadowBlurX, shadowBlurY: ds.shadowBlurY,
                fontName: ds.fontName, fontSize: ds.fontSize, fontColor: ds.fontColor,
                textPosition: ds.textPosition, padding: ds.padding, showPercentage: ds.showPercentage
            };
        } else {
            // copy provided style
            this.style = {
                width: style.width, height: style.height,
                bgColor: style.bgColor, trackColor: style.trackColor, barColor: style.barColor,
                borderColor: style.borderColor, borderThickness: style.borderThickness, cornerRadius: style.cornerRadius,
                glossAlpha: style.glossAlpha,
                shadowDistance: style.shadowDistance, shadowAngle: style.shadowAngle, shadowColor: style.shadowColor,
                shadowAlpha: style.shadowAlpha, shadowBlurX: style.shadowBlurX, shadowBlurY: style.shadowBlurY,
                fontName: style.fontName, fontSize: style.fontSize, fontColor: style.fontColor,
                textPosition: style.textPosition, padding: style.padding, showPercentage: style.showPercentage
            };
        }

        _width = (w > 0) ? w : this.style.width;
        _height = (h > 0) ? h : this.style.height;

        bg = new Shape();
        track = new Shape();
        fill = new Shape();
        rim = new Shape();
        gloss = new Shape();

        // label
        label = new TextField();
        label.selectable = false;
        label.autoSize = TextFieldAutoSize.LEFT;
        label.embedFonts = false;
        label.defaultTextFormat = new TextFormat(this.style.fontName, this.style.fontSize, this.style.fontColor, true, null, null, null, null, "center");
        label.text = (initialText == null) ? "" : initialText;

        // add shapes in order (we'll rearrange as needed)
        addChild(bg);
        addChild(track);
        addChild(fill);
        addChild(rim);
        addChild(gloss);
        addChild(label);

        // drop shadow filter for subtle lift
        try {
            this.filters = [ new DropShadowFilter(style.shadowDistance, style.shadowAngle, style.shadowColor, style.shadowAlpha, style.shadowBlurX, style.shadowBlurY) ];
        } catch(_ : Dynamic) {}

        redraw();
        if (initialText != null) _text = initialText;
        updateLabel();
    }

    private function get_progress():Float {
        return _progress;
    }

    private function set_progress(v:Float):Float {
        if (v < 0) v = 0;
        if (v > 1) v = 1;
        if (Math.abs(_progress - v) < 0.0001) return _progress;
        _progress = v;
        redrawFill();
        updateLabel();
        return _progress;
    }

    private function get_text():String {
        return _text;
    }

    private function set_text(s:String):String {
        _text = (s == null) ? "" : s;
        updateLabel();
        return _text;
    }

    /**
     * Draw everything (track gradient, rim, gloss)
     */
    private function redraw():Void {
        // bg (not painted by default)
        var gbg:Graphics = bg.graphics;
        gbg.clear();

        // track gradient
        var tg:Graphics = track.graphics;
        tg.clear();
        var matrix:Matrix = new Matrix();
        matrix.createGradientBox(_width, _height, Math.PI / 2, 0, 0);
        var topTrack = StyleUtil.lighten(style.trackColor, 0.07);
        var bottomTrack = StyleUtil.darken(style.trackColor, 0.03);
        tg.beginGradientFill("linear", [topTrack, bottomTrack], [1, 1], [0, 255], matrix);
        tg.drawRoundRect(0, 0, _width, _height, style.cornerRadius);
        tg.endFill();

        // rim (stroke)
        var rg:Graphics = rim.graphics;
        rg.clear();
        if (style.borderThickness > 0) {
            rg.lineStyle(style.borderThickness, style.borderColor, 1, true);
            rg.drawRoundRect(style.borderThickness/2, style.borderThickness/2,
                            _width - style.borderThickness, _height - style.borderThickness,
                            style.cornerRadius);
        }

        // ---- gloss overlay aligned to inner area ----
        var innerX = style.borderThickness;
        var innerW = _width - style.borderThickness * 2;
        var innerH = _height - style.borderThickness * 2;
        if (innerW < 0) innerW = 0;
        if (innerH < 0) innerH = 0;

        var corner = Math.min(style.cornerRadius, Std.int(innerH/2));

        var hg:Graphics = gloss.graphics;
        hg.clear();
        if (innerW > 0 && innerH > 0) {
            var glossMatrix:Matrix = new Matrix();
            glossMatrix.createGradientBox(innerW, Std.int(innerH*0.5), Math.PI/2, innerX, style.borderThickness);

            hg.beginGradientFill("linear", [0xFFFFFF, 0xFFFFFF], [style.glossAlpha, 0], [0, 255], glossMatrix);
            var glossY:Int = style.borderThickness + Std.int(innerH*0.06);
            hg.drawRoundRect(innerX, glossY, innerW, Math.max(4, Std.int(innerH*0.45)), corner);
            hg.endFill();
        }

        redrawFill(); // draw fill
        updateLabel();

        // drawing order
        setChildIndex(track, 0);
        setChildIndex(fill, 1);
        setChildIndex(rim, 2);
        setChildIndex(gloss, 3);
        setChildIndex(label, 4);
    }


    /**
     * Draw the fill using a gentle gradient so it feels "button-ish"
     */
    private function redrawFill():Void {
        var fg = fill.graphics;
        fg.clear();

        var innerX = style.borderThickness;
        var innerW = _width - style.borderThickness * 2;
        var innerH = _height - style.borderThickness * 2;
        if (innerW < 0) innerW = 0;
        if (innerH < 0) innerH = 0;

        var fillW = Std.int(innerW * _progress);
        if (fillW <= 0) return;

        var corner = Math.min(style.cornerRadius, Std.int(innerH / 2));

        var fm:Matrix = new Matrix();
        fm.createGradientBox(fillW, innerH, 0, innerX, style.borderThickness);
        var topBar = StyleUtil.lighten(style.barColor, 0.06);
        var bottomBar = StyleUtil.darken(style.barColor, 0.03);
        fg.beginGradientFill("linear", [topBar, bottomBar], [1, 1], [0, 255], fm);
        fg.drawRoundRect(innerX, style.borderThickness, fillW, innerH, corner);
        fg.endFill();
    }


    /**
     * Update the label placement + content.
     */
    private function updateLabel():Void {
        var labelText:String = _text;
        if ((labelText == null || labelText.length == 0) && style.showPercentage) {
            var perc = Std.int(_progress * 100);
            labelText = perc + "%";
        }

        var tf = new TextFormat(style.fontName, style.fontSize, style.fontColor, true);
        label.defaultTextFormat = tf;
        label.setTextFormat(tf);
        label.text = labelText;

        // measure label
        var lw = Std.int(label.textWidth) + 4;
        var lh = Std.int(label.textHeight) + 4;

        switch (style.textPosition) {
            case "top":
                label.x = Std.int((_width - lw) / 2);
                label.y = - (lh + style.padding);
            case "bottom":
                label.x = Std.int((_width - lw) / 2);
                label.y = _height + style.padding;
            case "left":
                label.x = - (lw + style.padding);
                label.y = Std.int((_height - lh) / 2);
            case "right":
                label.x = _width + style.padding;
                label.y = Std.int((_height - lh) / 2);
            case "center":
                label.x = Std.int((_width - lw) / 2);
                label.y = Std.int((_height - lh) / 2);
            default:
                label.x = Std.int((_width - lw) / 2);
                label.y = Std.int((_height - lh) / 2);
        }
    }

    // ---- public API ----
    public function setSize(w:Int, h:Int):Void {
        _width = w;
        _height = h;
        redraw();
    }

    public function setStyle(s:ProgressBarStyle):Void {
        if (s == null) return;
        // shallow copy
        style = {
            width: s.width, height: s.height,
            bgColor: s.bgColor, trackColor: s.trackColor, barColor: s.barColor,
            borderColor: s.borderColor, borderThickness: s.borderThickness, cornerRadius: s.cornerRadius,
            glossAlpha: s.glossAlpha,
            shadowDistance: s.shadowDistance, shadowAngle: s.shadowAngle, shadowColor: s.shadowColor,
            shadowAlpha: s.shadowAlpha, shadowBlurX: s.shadowBlurX, shadowBlurY: s.shadowBlurY,
            fontName: s.fontName, fontSize: s.fontSize, fontColor: s.fontColor,
            textPosition: s.textPosition, padding: s.padding, showPercentage: s.showPercentage
        };
        _width = style.width;
        _height = style.height;
        // reapply shadow filter
        try { this.filters = [ new DropShadowFilter(style.shadowDistance, style.shadowAngle, style.shadowColor, style.shadowAlpha, style.shadowBlurX, style.shadowBlurY) ]; } catch(_ : Dynamic) {}
        redraw();
    }

    public function dispose():Void {
        try {
            while (numChildren > 0) removeChildAt(0);
        } catch (_:Dynamic) {}
    }
}
