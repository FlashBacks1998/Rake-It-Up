package org.flashbacks1998.scenes;

import openfl.display.Sprite;

interface ISceneTransition {

    /**
     * Animate a cover over the current scene (e.g. fade to black).
     * SceneManager will NOT start disposing/loading until onComplete fires.
     */
    function coverOut(container:Sprite, onComplete:Void->Void):Void;

    /**
     * Called repeatedly during scene loading with a normalized progress value (0.0–1.0).
     * Allows the transition overlay to optionally display a loading indicator.
     */
    function onLoadProgress(progress:Float):Void;

    /**
     * Animate the cover away to reveal the new scene.
     * Only called after init() fully resolves.
     * SceneManager considers the transition done when onComplete fires.
     */
    function revealIn(container:Sprite, onComplete:Void->Void):Void;
}
