package org.flashbacks1998.ui.views.tab;

import org.flashbacks1998.ui.buttons.ButtonUI;
import org.flashbacks1998.ui.styles.ButtonStyle;
import org.flashbacks1998.ui.styles.TabStyle;

import openfl.text.TextField;
import openfl.text.TextFormat;

class TabHeaderUI extends ButtonUI {
    private var tabStyle:TabStyle;
    private var normalBtnStyle:ButtonStyle;
    private var activeBtnStyle:ButtonStyle;

    public function new(title:String, tabStyle:TabStyle) {
        this.tabStyle = tabStyle;

        var w = measureWidth(title, tabStyle);
        var h = tabStyle.height;

        normalBtnStyle = tabToButtonStyle(tabStyle, false);
        activeBtnStyle = tabToButtonStyle(tabStyle, true);

        super(title, w, h, normalBtnStyle);

        // avoid hover flicker from children
        this.mouseChildren = false;
    }

    public function setActive(v:Bool):Void {
        refreshStyle(v ? activeBtnStyle : normalBtnStyle);
    }

    private static function measureWidth(text:String, s:TabStyle):Int {
        var tf = new TextField();
        tf.defaultTextFormat = new TextFormat(s.fontName, s.fontSize, s.fontColor, s.bold);
        tf.text = text;
        var w = Std.int(tf.textWidth + 4 + s.paddingX * 2);
        if (w < 40) w = 40;
        return w;
    }

    private static function tabToButtonStyle(s:TabStyle, active:Bool):ButtonStyle {
        return {
            cornerRadius: s.cornerRadius,
            colorTop: active ? s.activeColorTop : s.colorTop,
            colorBottom: active ? s.activeColorBottom : s.colorBottom,
            borderColor: s.borderColor,
            borderThickness: s.borderThickness,
            glossAlpha: s.glossAlpha,

            // you can tune these separately for tabs if desired
            shadowDistance: 4,
            shadowAngle: 45,
            shadowColor: 0x000000,
            shadowAlpha: 0.18,
            shadowBlurX: 8,
            shadowBlurY: 8,

            fontName: s.fontName,
            fontSize: s.fontSize,
            fontColor: s.fontColor,
            bold: s.bold,
            pressMove: s.pressMove
        };
    }
}