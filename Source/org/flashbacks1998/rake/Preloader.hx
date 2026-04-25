package org.flashbacks1998.rake;

import org.flashbacks1998.ui.bars.ProgressBarUI;
import org.flashbacks1998.debugger.Debugger;
import org.flashbacks1998.scenes.SceneManager;

import openfl.display.Sprite;
import openfl.display.Shape;
import openfl.display.Bitmap;
import openfl.display.BitmapData;

import openfl.events.Event;
import openfl.events.ProgressEvent;
import openfl.Lib;
import openfl.geom.Matrix;
import openfl.geom.Rectangle;

import org.flashbacks1998.ui.styles.ProgressBarStyle;
import org.flashbacks1998.ui.styles.TextboxStyle;
import org.flashbacks1998.debugger.DebuggerConsole;

class Preloader extends Sprite {
    private static final bgcolor:Int = 0xE39A5A;

    // Live UI (vector/text) is here
    private var contentLayer:Sprite;

    // Snapshot fade layer is here
    private var fadeLayer:Sprite;
    private var fadeBmp:Bitmap;
    private var fadeBmd:BitmapData;

    private var bg:Shape;
    private var bar:ProgressBarUI;

    private var console:DebuggerConsole;
    private var consoleStyle:TextboxStyle;

    private var padding:Int = 10;

    // Fade state (ENTER_FRAME)
    private var fadeDurationMs:Int = 2000;
    private var fadeStartMs:Float = 0;
    private var fading:Bool = false;

    public function new() {
        super();

        addEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
        addEventListener(Event.COMPLETE, onComplete);
        addEventListener(ProgressEvent.PROGRESS, onProgress);
    }

    private function onAddedToStage(e:Event):Void {
        removeEventListener(Event.ADDED_TO_STAGE, onAddedToStage);

        // Layers
        contentLayer = new Sprite();
        addChild(contentLayer);

        fadeLayer = new Sprite();
        fadeLayer.visible = false;
        fadeLayer.mouseEnabled = false;
        fadeLayer.mouseChildren = false;
        addChild(fadeLayer);

        // Background first (behind everything)
        bg = new Shape();
        contentLayer.addChild(bg);

        // Create loading bar
        var style = ProgressBarStyle.defaultStyle;
        style.width = cast(Lib.current.stage.stageWidth * 0.75);
        style.height = 30;
        style.textPosition = "center";
        style.showPercentage = false;

        bar = new ProgressBarUI(style.width, style.height, style);
        bar.progress = 0;
        bar.text = "0%";
        contentLayer.addChild(bar);

        // Initial layout + listen for resize
        layout();
        stage.addEventListener(Event.RESIZE, onResize);
    }

    private function onResize(e:Event):Void {
        layout();

        // Optional: If you *can* resize mid-fade and want correctness, rebuild snapshot.
        // If you don't care about that edge-case, delete this block.
        if (fading) buildFadeSnapshot();
    }

    private function layout():Void {
        if (stage == null) return;

        drawBackground(stage.stageWidth, stage.stageHeight);

        if (bar != null) {
            var newBarW = Std.int(stage.stageWidth * 0.75);
            var newBarH = 30;

            try {
                bar.setSize(newBarW, newBarH);
            } catch (_:Dynamic) {
                bar.width = newBarW;
                bar.height = newBarH;
            }

            bar.x = (stage.stageWidth - bar.width) / 2;
            bar.y = (stage.stageHeight - bar.height) / 2;
        }

        if (console != null) {
            var consoleW = (bar != null) ? Std.int(bar.width) : Std.int(stage.stageWidth * 0.75);
            var consoleH = Std.int(stage.stageHeight * 0.30);

            console.setSize(consoleW, consoleH);

            console.x = (bar != null) ? bar.x : Std.int((stage.stageWidth - consoleW) / 2);
            console.y = (bar != null) ? (bar.y + bar.height + padding) : padding;
        }
    }

    private function drawBackground(w:Int, h:Int):Void {
        if (bg == null) return;

        var g = bg.graphics;
        g.clear();
        g.beginFill(bgcolor, 1);
        g.drawRect(0, 0, w, h);
        g.endFill();
    }

    private function update(percent:Float):Void {
        if (bar == null) return;

        if (percent < 0) percent = 0;
        if (percent > 1) percent = 1;

        bar.progress = percent;

        var pct = Std.int(percent * 100);
        bar.text = pct + "%";
    }

    public function addDebugConsole():Void {
        if (stage == null || bar == null) return;
        if (console != null) return;

        consoleStyle = new TextboxStyle();
        consoleStyle.readOnly = true;
        consoleStyle.overflowX = true;
        consoleStyle.overflowY = true;
        consoleStyle.wrap = false;
        consoleStyle.autoScroll = true;

        consoleStyle.width = Std.int(bar.width);
        consoleStyle.height = Std.int(stage.stageHeight * 0.30);

        console = new DebuggerConsole(consoleStyle);

        // IMPORTANT: add to contentLayer (so snapshot captures it)
        contentLayer.addChild(console);

        layout();
    }

    // -------------------------
    // Snapshot fade optimization
    // -------------------------

    private function buildFadeSnapshot():Void {
        if (contentLayer == null) return;

        // Hide fade layer while drawing so we don't include it
        fadeLayer.visible = false;

        var bounds:Rectangle = contentLayer.getBounds(contentLayer);
        var w:Int = Std.int(Math.ceil(bounds.width));
        var h:Int = Std.int(Math.ceil(bounds.height));
        if (w < 1) w = 1;
        if (h < 1) h = 1;

        if (fadeBmd != null) {
            fadeBmd.dispose();
            fadeBmd = null;
        }

        fadeBmd = new BitmapData(w, h, true, 0x00000000);

        var m = new Matrix();
        m.translate(-bounds.x, -bounds.y);
        fadeBmd.draw(contentLayer, m, null, null, null, true);

        if (fadeBmp == null) {
            fadeBmp = new Bitmap(fadeBmd);
            fadeBmp.smoothing = true;
            fadeLayer.addChild(fadeBmp);
        } else {
            fadeBmp.bitmapData = fadeBmd;
        }

        fadeBmp.x = contentLayer.x + bounds.x;
        fadeBmp.y = contentLayer.y + bounds.y;

        fadeLayer.alpha = 1;
        fadeLayer.visible = true;

        // Hide live UI so text stops getting re-rasterized during fade
        contentLayer.visible = false;
    }

    private function startFadeout():Void {
        if (fading) return;
        fading = true;

        // Stop console from doing string building / text updates during fade
        //if (console != null) console.pause();

        // Snapshot once
        buildFadeSnapshot();

        // Start time
        fadeStartMs = Lib.getTimer();

        // Fade via ENTER_FRAME (no Timer allocations / dispatch)
        addEventListener(Event.ENTER_FRAME, onFadeFrame);

        this.mouseEnabled = false;
    }

    private function onFadeFrame(e:Event):Void {
        var now = Lib.getTimer();
        var t:Float = (now - fadeStartMs) / fadeDurationMs;
        if (t < 0) t = 0;
        if (t > 1) t = 1;

        if (fadeLayer != null) fadeLayer.alpha = 1 - t;

        if (t >= 1) finishFadeout();
    }

    private function finishFadeout():Void {
        removeEventListener(Event.ENTER_FRAME, onFadeFrame);

        if (fadeLayer != null) fadeLayer.alpha = 0;
        fading = false;

        // Cleanup snapshot resources
        if (fadeBmp != null) {
            if (fadeBmp.parent != null) fadeBmp.parent.removeChild(fadeBmp);
            fadeBmp.bitmapData = null;
            fadeBmp = null;
        }
        if (fadeBmd != null) {
            fadeBmd.dispose();
            fadeBmd = null;
        }

        // Remove from stage if still present
        if (Lib.current != null && Lib.current.stage != null && this.parent != null) {
            this.parent.removeChild(this);
        }
    }

    // -------------------------
    // Load events
    // -------------------------

    private function onComplete(event:Event):Void {
        update(1);

        Lib.current.stage.addChild(this);

        addDebugConsole();

        SceneManager.instance.addEventListener(ProgressEvent.PROGRESS, (e:ProgressEvent) -> {
            update(e.bytesTotal > 0 ? (e.bytesLoaded / e.bytesTotal) : 0);
        });

        SceneManager.instance.addEventListener(Event.COMPLETE, (e) -> {
            Debugger.log("Preloader is done");
            startFadeout();
        });
    }

    private function onProgress(event:ProgressEvent):Void {
        if (event.bytesTotal <= 0) update(0);
        else update(event.bytesLoaded / event.bytesTotal);
    }
}