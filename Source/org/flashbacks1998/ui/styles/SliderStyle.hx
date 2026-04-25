package org.flashbacks1998.ui.styles;

import org.flashbacks1998.ui.styles.ButtonStyle;
import org.flashbacks1998.util.StyleUtil;

/**
 * SliderStyle
 * - Track + thumb style values (button-like plate rendering)
 */
@:structInit
class SliderStyle {
    // Track (bar) look
    public var trackCornerRadius:Float;
    public var trackColorTop:Int;
    public var trackColorBottom:Int;
    public var trackBorderColor:Int;
    public var trackBorderThickness:Int;
    public var trackGlossAlpha:Float;

    // Thumb (handle) look
    public var thumbCornerRadius:Float;
    public var thumbColorTop:Int;
    public var thumbColorBottom:Int;
    public var thumbBorderColor:Int;
    public var thumbBorderThickness:Int;
    public var thumbGlossAlpha:Float;

    // Shared drop shadow (applied to track visuals + thumb visuals)
    public var shadowDistance:Float;
    public var shadowAngle:Float;
    public var shadowColor:Int;
    public var shadowAlpha:Float;
    public var shadowBlurX:Float;
    public var shadowBlurY:Float;

    // Thumb sizing (0 = auto from barHeight)
    public var thumbWidth:Int;
    public var thumbHeight:Int;

    // UX tweaks
    public var thumbPressMove:Float; // small Y nudge when pressed
    public var hitExtra:Int;         // extra pixels above/below bar for easier clicking
    public var smoothing:Bool;       // bitmap smoothing
    public var step:Float;           // 0 = continuous, otherwise snap step in VALUE units (not normalized)

    public static var defaultStyle:SliderStyle = {
        // Track: darker/recessed version of ButtonStyle.defaultStyle
        trackCornerRadius: 999, // clamped to barHeight at draw time
        trackColorTop: StyleUtil.darken(ButtonStyle.defaultStyle.colorTop, 0.25),
        trackColorBottom: StyleUtil.darken(ButtonStyle.defaultStyle.colorBottom, 0.30),
        trackBorderColor: StyleUtil.darken(ButtonStyle.defaultStyle.borderColor, 0.20),
        trackBorderThickness: 2,
        trackGlossAlpha: 0.25,

        // Thumb: basically the button plate
        thumbCornerRadius: ButtonStyle.defaultStyle.cornerRadius,
        thumbColorTop: ButtonStyle.defaultStyle.colorTop,
        thumbColorBottom: ButtonStyle.defaultStyle.colorBottom,
        thumbBorderColor: ButtonStyle.defaultStyle.borderColor,
        thumbBorderThickness: ButtonStyle.defaultStyle.borderThickness,
        thumbGlossAlpha: ButtonStyle.defaultStyle.glossAlpha,

        // Shadow: same as button
        shadowDistance: ButtonStyle.defaultStyle.shadowDistance,
        shadowAngle: ButtonStyle.defaultStyle.shadowAngle,
        shadowColor: ButtonStyle.defaultStyle.shadowColor,
        shadowAlpha: ButtonStyle.defaultStyle.shadowAlpha,
        shadowBlurX: ButtonStyle.defaultStyle.shadowBlurX,
        shadowBlurY: ButtonStyle.defaultStyle.shadowBlurY,

        // Sizes: 0 => auto
        thumbWidth: 0,
        thumbHeight: 0,

        thumbPressMove: 1,
        hitExtra: 10,
        smoothing: true,
        step: 0
    };
}