package org.flashbacks1998.rake.ui;

import haxe.ui.containers.Absolute;
import haxe.ui.components.Button;
import haxe.ui.components.CheckBox;
import haxe.ui.components.Link;
import haxe.ui.events.MouseEvent;
import haxe.ui.events.UIEvent;
import openfl.Lib;
import openfl.net.URLRequest;

@:xml('
<absolute>
    <tabview left="0" top="0" width="100%" height="100%">

        <vbox text="Visual" styleName="settings-panel">

            <vbox styleName="settings-section">
                <label text="Debug Settings" styleName="section-header" />
                <hbox styleName="settings-row">
                    <label text="Enable FPS Debug Window" styleName="settings-label" />
                    <checkbox id="enableFPSDebugWindow" text="Disabled" selected="false" styleName="settings-checkbox" />
                </hbox>
            </vbox>

            <vbox styleName="settings-section">
                <label text="Engine Settings" styleName="section-header" />
                <hbox styleName="settings-row">
                    <label text="Enable Hardware Rendering" styleName="settings-label" />
                    <checkbox id="enableHardwareRendering" text="Disabled" selected="false" styleName="settings-checkbox" />
                </hbox>
            </vbox>

            <vbox styleName="settings-section">
                <label text="Shader Settings" styleName="section-header" />
                <hbox styleName="settings-row">
                    <label text="Enable Tree Dithering Shader" styleName="settings-label" />
                    <checkbox id="enableTreeDitheringShader" text="Disabled" selected="false" styleName="settings-checkbox" />
                </hbox>
                <hbox styleName="settings-row">
                    <label text="Enable Leaves Pulsing Shader" styleName="settings-label" />
                    <checkbox id="enableLeavesPulsingShader" text="Disabled" selected="false" styleName="settings-checkbox" />
                </hbox>
            </vbox>

        </vbox>

        <vbox text="Audio" styleName="settings-panel">

            <vbox styleName="settings-section">
                <label text="Music" styleName="section-header" />
                <hbox styleName="settings-row">
                    <label text="Background Music Volume" styleName="settings-label" />
                    <horizontalslider id="sliderBgMusic" min="0" max="1" step="0.01" pos="1" width="180" styleName="settings-slider" />
                </hbox>
            </vbox>

            <vbox styleName="settings-section">
                <label text="Effects" styleName="section-header" />
                <hbox styleName="settings-row">
                    <label text="Sound Effects Volume" styleName="settings-label" />
                    <horizontalslider id="sliderSfx" min="0" max="1" step="0.01" pos="0.1" width="180" styleName="settings-slider" />
                </hbox>
            </vbox>

        </vbox>

        <vbox text="Credits" styleName="settings-panel">

            <vbox styleName="settings-section">
                <label text="Audio" styleName="section-header" />
                <vbox styleName="settings-row">
                    <label text="Creator Assets — 8-Bit Coin Sound Effect (Copyright Free)" styleName="settings-label" />
                    <link id="linkCoinSfx" text="https://www.youtube.com/watch?v=5v20ztxGvQ0" styleName="credit-url" />
                </vbox>
                <vbox styleName="settings-row">
                    <label text="Gravidi — Nat King Cole: Autumn Leaves Lofi Cover" styleName="settings-label" />
                    <link id="linkAutumnLeaves" text="https://www.newgrounds.com/audio/listen/911253" styleName="credit-url" />
                </vbox>
            </vbox>

            <vbox styleName="settings-section">
                <label text="3D Models" styleName="section-header" />
                <vbox styleName="settings-row">
                    <label text="TODO: Ive worked on this project for so long I cant even find where I got them from" styleName="settings-label" />
                </vbox>
            </vbox>

            <vbox styleName="settings-section">
                <label text="Fonts" styleName="section-header" />
                <vbox styleName="settings-row">
                    <label text="PixelTactical-AWOx" styleName="settings-label" />
                    <link id="linkPixelTactical" text="https://www.dafont.com/pixel-tactical.font" styleName="credit-url" />
                </vbox>
            </vbox>

        </vbox>

    </tabview>

    <button id="closeBtn" text="X" top="0" styleName="settings-close" />
</absolute>
')
class SettingsTabs extends Absolute {
    /** Fired when the [X] button is pressed. Host decides what to do (hide, pop a Stack page, etc.). */
    public var onClose:Void->Void;

    /** Fired when the Background Music volume slider changes. Value in [0,1]. */
    public dynamic function onBgMusicVolumeChange(volume:Float):Void {}

    /** Fired when the Sound Effects volume slider changes. Value in [0,1]. */
    public dynamic function onSfxVolumeChange(volume:Float):Void {}

    public function new() {
        super();

        enableFPSDebugWindow.registerEvent(UIEvent.CHANGE, onCheckboxChange);
        enableHardwareRendering.registerEvent(UIEvent.CHANGE, onCheckboxChange);
        enableTreeDitheringShader.registerEvent(UIEvent.CHANGE, onCheckboxChange);
        enableLeavesPulsingShader.registerEvent(UIEvent.CHANGE, onCheckboxChange);

        sliderBgMusic.registerEvent(UIEvent.CHANGE, function(_) onBgMusicVolumeChange(sliderBgMusic.pos));
        sliderSfx.registerEvent(UIEvent.CHANGE, function(_) onSfxVolumeChange(sliderSfx.pos));

        wireCreditLink(linkCoinSfx);
        wireCreditLink(linkAutumnLeaves);
        wireCreditLink(linkPixelTactical);

        closeBtn.registerEvent(MouseEvent.CLICK, onCloseClick);

        registerEvent(UIEvent.READY, onPanelReady);
    }

    private function onPanelReady(e:UIEvent):Void {
        positionCloseBtn();
        registerEvent(UIEvent.RESIZE, function(_) positionCloseBtn());
    }

    private function positionCloseBtn():Void {
        closeBtn.left = this.width - closeBtn.width - 2;
    }

    private function onCheckboxChange(e:UIEvent):Void {
        var cb:CheckBox = cast e.target;
        cb.text = cb.selected ? "Enabled" : "Disabled";
    }

    /**
     * Attach a click handler to a credit link that opens its `.text` URL in a
     * new browser window. Captures URL by value so later text changes don't
     * change where the link navigates.
     */
    private function wireCreditLink(link:Link):Void {
        final url = link.text;
        link.registerEvent(MouseEvent.CLICK, function(_) {
            Lib.navigateToURL(new URLRequest(url), "_blank");
        });
    }

    private function onCloseClick(e:MouseEvent):Void {
        if (onClose != null) onClose();
    }
}
