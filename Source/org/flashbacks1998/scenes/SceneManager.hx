package org.flashbacks1998.scenes;

import openfl.events.Event;
import openfl.events.ProgressEvent;
import haxe.ds.StringMap;
import haxe.Exception;

import openfl.display.Sprite;
import openfl.Lib;
import openfl.utils.Future;
import openfl.utils.Promise;

import org.flashbacks1998.debugger.Debugger;

class SceneManager extends Sprite {

    public static var instance:SceneManager = new SceneManager();

    public static var scenes:StringMap<IScene> = new StringMap();
    public static var currentScene:IScene = null;
    public static var homescene:IScene = null;
 
    public static var loadingScreen:ILoadingScreen = null;
 
    public static var defaultTransition:ISceneTransition = null;

    public function new() {
        super();
    }

    private function addScene(scene:IScene) {
        addChild(scene.asSprite());
    }

    public function removeScene(scene:IScene) {
        if (scene == null) {
            Debugger.log("removeScene: scene is null, nothing to remove");
            return;
        }
        final s = scene.asSprite();
        if (s.parent == this) removeChild(s);
    }

    public function addLoadingScreen(?loadingScreen:ILoadingScreen) {
        final screen = loadingScreen ?? SceneManager.loadingScreen;
        if (screen != null)
            addChild(screen.asSprite());
    }

    public function removeLoadingScreen(?loadingScreen:ILoadingScreen) {
        final screen = loadingScreen ?? SceneManager.loadingScreen;
        if (screen != null) {
            final s = screen.asSprite();
            if (s.parent == this) removeChild(s);
        }
    }

    public static function registerScene(id:String, scene:IScene):Void {
        if (id == null || id == "") {
            Debugger.error("register: scene id must be non-empty");
            return;
        }
        if (scene == null) {
            Debugger.error('register("$id"): scene cannot be null');
            return;
        }
        if (scenes.exists(id)) {
            Debugger.error('register("$id"): scene with the same id already exists');
            return;
        }
        SceneManager.scenes.set(id, scene);
    }
 
    public static function gotoScene(id:String, ?transition:ISceneTransition):Void {
        final nextScene = scenes.get(id);
        final t = transition ?? defaultTransition;

        Debugger.log("SceneManager.gotoScene:", id, "(transition:", (t != null ? Type.getClassName(Type.getClass(t)) : "none") + ")");

        if (nextScene == null)
            throw new Exception('SceneManager.gotoScene: no scene registered with id "$id"');
 
        if (t != null) {
            t.coverOut(instance, () -> _loadScene(id, nextScene, t));
        } else {
            _loadScene(id, nextScene, null);
        }
    }

    private static function _loadScene(id:String, nextScene:IScene, transition:ISceneTransition):Void {
        final prevScene = currentScene;
 
        final disposeChain:Future<Dynamic> = (prevScene != null)
            ? prevScene.dispose()
            : Future.withValue(null);

        instance.addLoadingScreen();

        disposeChain 
            .onComplete(_ -> {
                if (prevScene != null) instance.removeScene(prevScene);
            }) 
            .then(_ -> nextScene.init()) 
            .onProgress((x, y) -> {
                final progress = (y > 0.0) ? x / y : 0.0;
                transition?.onLoadProgress(progress);
                SceneManager.loadingScreen?.onProgress(x, y);
                instance.dispatchEvent(new ProgressEvent(ProgressEvent.PROGRESS, false, false, x, y));
            }) 
            .onComplete(scene -> {
                Debugger.log("SceneManager: scene", id, "loaded successfully");

                SceneManager.loadingScreen?.onSceneReady();
                instance.removeLoadingScreen();
                instance.addScene(scene);

                // Fix: keep currentScene in sync with what is actually on screen.
                //pos
                currentScene = scene;

                instance.dispatchEvent(new Event(Event.COMPLETE));

                // Step 4 — Reveal transition (if any).
                if (transition != null) {
                    transition.revealIn(instance, () -> {
                        Debugger.log("SceneManager: reveal complete for scene", id);
                    });
                }
            });
    }

    public static function getSceneId(scene:IScene):Null<String> {
        for (id in scenes.keys()) {
            if (scenes.get(id) == scene) return id;
        }
        return null;
    }

    public static function gotoHomeScene():Void {
        gotoScene(getSceneId(homescene));
    }
}
