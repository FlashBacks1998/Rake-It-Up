package org.flashbacks1998.ui.views;

import org.flashbacks1998.ui.views.tab.TabHeaderUI;
import org.flashbacks1998.ui.views.tab.TabUI;
import org.flashbacks1998.ui.buttons.ButtonUI;
import org.flashbacks1998.ui.events.UIMouseEvent;
import org.flashbacks1998.ui.styles.ButtonStyle;
import org.flashbacks1998.ui.styles.TabStyle;

import openfl.display.Sprite;
import openfl.display.Shape;
import openfl.display.Graphics;
import openfl.geom.Matrix;
import openfl.events.Event;

class TabViewUI extends Sprite {
    public var viewWidth(default, null):Int;
    public var viewHeight(default, null):Int;

    public var autoSizeToActiveTab:Bool = false;

    private var minWidth:Int;
    private var minHeight:Int;

    private var tabStyle:TabStyle;

    private var tabBar:Sprite;
    private var contentLayer:Sprite;

    private var contentBg:Shape;
    private var contentMask:Shape;

    private var closeBtn:ButtonUI;

    private var tabs:Array<TabUI> = [];
    private var selectedIndex:Int = -1;

    // ---- Layout knobs ----
    // Make these 0 by default so things are truly flush.
    public var tabSpacing:Int = 8;

    public var tabBarPaddingLeft:Int = 0;
    public var tabBarPaddingRight:Int = 0;

    public var closePaddingRight:Int = 0;

    public var contentPadding:Int = 10;

    public var contentBgTop:Int = 0x2E1C0F;
    public var contentBgBottom:Int = 0x24150B;
    public var contentBorderColor:Int = 0x3B2416;
    public var contentBorderThickness:Int = 1;
    public var contentCornerRadius:Float = 10;
    public var contentGlossAlpha:Float = 0.22;

    // Gloss height ratio (top highlight height)
    public var glossHeightRatio:Float = 0.45;

    public function new(w:Int = 640, h:Int = 360, ?tabStyle:TabStyle = null) {
        super();

        this.viewWidth = w;
        this.viewHeight = h;
        this.minWidth = w;
        this.minHeight = h;

        this.tabStyle = (tabStyle == null) ? TabStyle.defaultStyle : tabStyle;

        contentBg = new Shape();
        addChild(contentBg);

        contentLayer = new Sprite();
        addChild(contentLayer);

        contentMask = new Shape();
        addChild(contentMask);
        contentLayer.mask = contentMask;

        tabBar = new Sprite();
        addChild(tabBar);

        closeBtn = makeCloseButton();
        addChild(closeBtn);
        closeBtn.addEventListener(UIMouseEvent.CLICK, onCloseClicked);

        // Initial layout
        layoutHeadersAndClose();
        layoutContent();
        redrawAll();
    }

    // ----------------------------
    // Tabs API
    // ----------------------------

    public function addTab(tab:TabUI):Void {
        tab.header = new TabHeaderUI(tab.title, tab.style);

        tabBar.addChild(tab.header);
        tabs.push(tab);

        tab.header.addEventListener(UIMouseEvent.CLICK, onHeaderClicked);

        if (selectedIndex < 0) {
            selectTab(0);
        } else {
            layoutHeadersAndClose();
            redrawAll();
        }
    }

    public function selectTab(index:Int):Void {
        if (index < 0 || index >= tabs.length) return;
        if (selectedIndex == index) return;

        // remove old content
        if (selectedIndex >= 0) {
            var prev = tabs[selectedIndex];
            if (prev.container.parent == contentLayer) contentLayer.removeChild(prev.container);
        }

        selectedIndex = index;

        // add new content
        var t = tabs[selectedIndex];
        contentLayer.addChild(t.container);

        // update header active states
        for (i in 0...tabs.length) tabs[i].header.setActive(i == selectedIndex);

        // If auto-size changes dimensions, emit RESIZE
        var oldW = viewWidth;
        var oldH = viewHeight;

        updateSizeFromActiveIfNeeded();

        if (viewWidth != oldW || viewHeight != oldH) {
            dispatchEvent(new Event(Event.RESIZE, true));
        }

        layoutHeadersAndClose();
        layoutContent();
        redrawAll();

        dispatchEvent(new Event(Event.CHANGE, true));
    }

    public function setSize(w:Int, h:Int):Void {
        var oldW = viewWidth;
        var oldH = viewHeight;

        viewWidth = w;
        viewHeight = h;

        minWidth = w;
        minHeight = h;

        autoSizeToActiveTab = false;

        layoutHeadersAndClose();
        layoutContent();
        redrawAll();

        if (viewWidth != oldW || viewHeight != oldH) {
            dispatchEvent(new Event(Event.RESIZE, true));
        }
    }

    public function refreshLayout():Void {
        var oldW = viewWidth;
        var oldH = viewHeight;

        updateSizeFromActiveIfNeeded();
        layoutHeadersAndClose();
        layoutContent();
        redrawAll();

        if (viewWidth != oldW || viewHeight != oldH) {
            dispatchEvent(new Event(Event.RESIZE, true));
        }
    }

    // ----------------------------
    // Input wiring
    // ----------------------------

    private function onHeaderClicked(e:UIMouseEvent):Void {
        for (i in 0...tabs.length) {
            if (tabs[i].header == e.currentTarget) {
                selectTab(i);
                return;
            }
        }
    }

    private function onCloseClicked(e:UIMouseEvent):Void {
        dispatchEvent(new Event(Event.CLOSE, true));
        e.stopPropagation();
    }

    // ----------------------------
    // Layout
    // ----------------------------

    private function layoutHeadersAndClose():Void {
        // tabs start flush-left
        var x:Float = tabBarPaddingLeft; // default 0

        for (t in tabs) {
            t.header.x = x;
            t.header.y = 0;
            x += Std.int(t.header.width) + tabSpacing;
        }

        // close button flush-right
        closeBtn.x = viewWidth - closeBtn.btnWidth - closePaddingRight; // default 0
        closeBtn.y = Std.int((tabStyle.height - closeBtn.btnHeight) * 0.5);
    }

    private function layoutContent():Void {
        var barH = tabStyle.height;

        contentLayer.x = 0;
        contentLayer.y = barH;

        var bodyH = viewHeight - barH;
        if (bodyH < 1) bodyH = 1;

        contentMask.x = 0;
        contentMask.y = barH;

        var mg = contentMask.graphics;
        mg.clear();
        mg.beginFill(0x000000, 1);
        mg.drawRect(0, 0, viewWidth, bodyH);
        mg.endFill();

        if (selectedIndex >= 0 && selectedIndex < tabs.length) {
            var c = tabs[selectedIndex].container;
            var b = c.getBounds(c);

            c.x = contentPadding - b.x;
            c.y = contentPadding - b.y;
        }
    }

    private function updateSizeFromActiveIfNeeded():Void {
        if (!autoSizeToActiveTab) return;
        if (selectedIndex < 0 || selectedIndex >= tabs.length) return;

        var barH = tabStyle.height;
        var c = tabs[selectedIndex].container;

        var b = c.getBounds(c);
        var contentW = Std.int(Math.max(0, b.width) + contentPadding * 2);
        var contentH = Std.int(Math.max(0, b.height) + contentPadding * 2);

        var headerNeedW = computeHeaderNeededWidth();

        var newW = Math.max(Math.max(minWidth, headerNeedW), contentW);
        var newH = Math.max(minHeight, barH + contentH);

        viewWidth = cast newW;
        viewHeight = cast newH;
    }

    private function computeHeaderNeededWidth():Int {
        // left padding + tabs + spacing + close button + right padding
        var w = tabBarPaddingLeft + tabBarPaddingRight + Std.int(closeBtn.width) + closePaddingRight;

        for (t in tabs) {
            w += Std.int(t.header.width) + tabSpacing;
        }

        return w;
    }

    // ----------------------------
    // Drawing
    // ----------------------------

    private function redrawAll():Void {
        drawBodyPanel();
    }

    private function drawBodyPanel():Void {
        var barH = tabStyle.height;
        var bodyH = viewHeight - barH;
        if (bodyH < 1) bodyH = 1;

        var g:Graphics = contentBg.graphics;
        g.clear();

        // background gradient
        var m = new Matrix();
        m.createGradientBox(viewWidth, bodyH, Math.PI / 2, 0, barH);

        g.beginGradientFill("linear", [contentBgTop, contentBgBottom], [1, 1], [0, 255], m);
        g.drawRoundRect(0, barH, viewWidth, bodyH, contentCornerRadius);
        g.endFill();

        // border
        g.lineStyle(contentBorderThickness, contentBorderColor, 1, true, "normal", "none", "round");
        g.drawRoundRect(0.5, barH + 0.5, viewWidth - 1, bodyH - 1, contentCornerRadius);

        // FULL-WIDTH gloss (no inset)
        var glossH:Float = Math.max(6, bodyH * glossHeightRatio);

        var gm = new Matrix();
        gm.createGradientBox(viewWidth, glossH, Math.PI / 2, 0, barH);

        g.beginGradientFill("linear", [0xFFFFFF, 0xFFFFFF], [contentGlossAlpha, 0.0], [0, 255], gm);
        g.drawRoundRect(0, barH, viewWidth, glossH, Std.int(contentCornerRadius * 0.9));
        g.endFill();
    }

    // ----------------------------
    // Close button
    // ----------------------------

    private function makeCloseButton():ButtonUI {
        var s:ButtonStyle = {
            cornerRadius: 10,
            colorTop: 0x7A2B2B,
            colorBottom: 0x5A1F1F,
            borderColor: 0x3B2416,
            borderThickness: 1,
            glossAlpha: 0.35,
            shadowDistance: 4,
            shadowAngle: 45,
            shadowColor: 0x000000,
            shadowAlpha: 0.18,
            shadowBlurX: 8,
            shadowBlurY: 8,
            fontName: "Arial",
            fontSize: 18,
            fontColor: 0xFFFFFF,
            bold: true,
            pressMove: 2
        };

        var btn = new ButtonUI("x", 34, 34, s);
        btn.mouseChildren = false;
        return btn;
    }
}