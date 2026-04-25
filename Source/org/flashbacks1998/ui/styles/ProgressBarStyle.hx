package org.flashbacks1998.ui.styles;

/**
 * ProgressBarStyle - visual options for UIProgressBar
 */
@:structInit
class ProgressBarStyle {
    public var width:Int;
    public var height:Int;

    // colors
    public var bgColor:Int;       // background / container color (optional)
    public var trackColor:Int;    // empty track color (top gradient)
    public var barColor:Int;      // filled progress color (top gradient)
    public var borderColor:Int;
    public var borderThickness:Int;
    public var cornerRadius:Float;

    // gloss + shadow
    public var glossAlpha:Float;      // gloss overlay opacity (0..1)
    public var shadowDistance:Float;
    public var shadowAngle:Float;
    public var shadowColor:Int;
    public var shadowAlpha:Float;
    public var shadowBlurX:Float;
    public var shadowBlurY:Float;

    // text
    public var fontName:String;
    public var fontSize:Int;
    public var fontColor:Int;
    /**
     * textPosition: "top", "left", "bottom", "right", "center"
     */
    public var textPosition:String;
    public var padding:Int; // spacing between bar and text when textPosition != center
    public var showPercentage:Bool; // if true and text is empty, text displays percentage

    // defaults
    public static var defaultStyle:ProgressBarStyle = {
        width: 300,
        height: 28,

        // background / track / bar colors (warm, light brown tones)
        bgColor: 0x2E1C0F,        // dark brown container
        trackColor: 0x5C3A21,     // lighter brown track gradient
        barColor: 0xA6784E,       // warm brand accent brown
        borderColor: 0x3B2416,    // darker rim
        borderThickness: 1,
        cornerRadius: 8,

        // gloss + shadow
        glossAlpha: 0.55,         
        shadowDistance: 4,
        shadowAngle: 45,
        shadowColor: 0x000000,
        shadowAlpha: 0.18,
        shadowBlurX: 8,
        shadowBlurY: 8,

        // text
        fontName: "Arial",
        fontSize: 14,
        fontColor: 0xFFFFFF,      // white text for contrast
        textPosition: "center",
        padding: 6,
        showPercentage: true
    };


}
