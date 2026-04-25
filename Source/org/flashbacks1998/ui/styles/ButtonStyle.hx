package org.flashbacks1998.ui.styles;

/**
 * ButtonStyle: visual parameters
 */
@:structInit
class ButtonStyle {
    public var cornerRadius:Float;
    public var colorTop:Int;
    public var colorBottom:Int;
    public var borderColor:Int;
    public var borderThickness:Int;
    public var glossAlpha:Float;
    public var shadowDistance:Float;
    public var shadowAngle:Float;
    public var shadowColor:Int;
    public var shadowAlpha:Float;
    public var shadowBlurX:Float;
    public var shadowBlurY:Float;
    public var fontName:String;
    public var fontSize:Int;
    public var fontColor:Int;
    public var bold:Bool;
    public var pressMove:Float;

    //Taken from rake 
    //TODO: change
    public static var defaultStyle:ButtonStyle = {
        cornerRadius: 18,
        colorTop: 0xFF9A3C,
        colorBottom: 0xFF6B2E,
        borderColor: 0xFFB06A,
        borderThickness: 2,
        glossAlpha: 0.7,
        shadowDistance: 6,
        shadowAngle: 45,
        shadowColor: 0x000000,
        shadowAlpha: 0.25,
        shadowBlurX: 14,
        shadowBlurY: 14,
        fontName: "Arial",
        fontSize: 22,
        fontColor: 0xFFFFFF,
        bold: true,
        pressMove: 3
    };
}