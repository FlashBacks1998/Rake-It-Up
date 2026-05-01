package org.flashbacks1998.scenes;

import openfl.display.Sprite;

interface ILoadingScreen {

    /** Returns the Sprite to be added/removed from the display list. */
    function asSprite():Sprite;

    /** Called each time loading progress changes. loaded and total are raw byte counts. */
    function onProgress(loaded:Float, total:Float):Void;

    /** Called when the scene has finished loading, before the reveal transition begins. */
    function onSceneReady():Void;
}
