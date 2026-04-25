package org.flashbacks1998.ui.styles;

@:structInit
class TabViewStyle {
    public var tabSpacing:Int;
    public var tabBarPaddingLeft:Int;
    public var tabBarPaddingRight:Int;

    public var contentPadding:Int;

    public var contentBgTop:Int;
    public var contentBgBottom:Int;
    public var contentBorderColor:Int;
    public var contentBorderThickness:Int;
    public var contentCornerRadius:Float;
    public var contentGlossAlpha:Float;

    // close button (top-right)
    public var closeSize:Int;
    public var closePaddingRight:Int;

    public var closeColorTop:Int;
    public var closeColorBottom:Int;
    public var closeBorderColor:Int;
    public var closeBorderThickness:Int;
    public var closeCornerRadius:Float;
    public var closeGlossAlpha:Float;

    public var closeFontName:String;
    public var closeFontSize:Int;
    public var closeFontColor:Int;
    public var closeBold:Bool;

    public static var defaultStyle:TabViewStyle = {
        tabSpacing: 8,
        tabBarPaddingLeft: 6,
        tabBarPaddingRight: 6,

        contentPadding: 10,

        contentBgTop: 0x2E1C0F,
        contentBgBottom: 0x24150B,
        contentBorderColor: 0x3B2416,
        contentBorderThickness: 1,
        contentCornerRadius: 10,
        contentGlossAlpha: 0.25,

        closeSize: 34,
        closePaddingRight: 6,

        closeColorTop: 0x7A2B2B,
        closeColorBottom: 0x5A1F1F,
        closeBorderColor: 0x3B2416,
        closeBorderThickness: 1,
        closeCornerRadius: 10,
        closeGlossAlpha: 0.35,

        closeFontName: "Arial",
        closeFontSize: 18,
        closeFontColor: 0xFFFFFF,
        closeBold: true
    };
}