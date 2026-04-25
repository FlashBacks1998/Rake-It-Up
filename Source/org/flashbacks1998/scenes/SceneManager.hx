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
    public static var loadingScreen:Sprite = null;

    public function new() {
        super();
    }

    private function addScene(scene:IScene) {
        addChild(scene.asSprite());
    }
    
    public function removeScene(scene:IScene) {
        if(scene == null) {
            Debugger.log("scene to remove is null");
            return;
        }

        removeChild(scene.asSprite());
    }
    
    public function addLoadingScreen(?loadingScreen:Sprite) {
        final screen = loadingScreen ?? SceneManager.loadingScreen;

        if(screen!=null)
            addChild(screen);
    }
    
    public function removeLoadingScreen(?loadingScreen:Sprite) {
        final screen = loadingScreen ?? SceneManager.loadingScreen;

        if(screen!=null)
            removeChild(screen);
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

    public static function gotoScene(id:String) {
        final nextScene = scenes.get(id);

        Debugger.log("Switching to scene", id, nextScene);

        if(nextScene == null)
            throw new Exception("No scene found with the id", id);

        final chain = currentScene?.dispose() ?? Future.withValue(null);

        instance.addLoadingScreen();

        final completeChain = chain
            .onProgress((x,y)-> {
                final e = new ProgressEvent(ProgressEvent.PROGRESS, false, false, x, y);
                instance.dispatchEvent(e);
                loadingScreen?.dispatchEvent(e);
            })
            .onComplete((scene)->instance.removeScene(scene))
        .then((_)->nextScene.init())
            .onProgress((x,y)-> {
                final e = new ProgressEvent(ProgressEvent.PROGRESS, false, false, x, y);
                instance.dispatchEvent(e);
                loadingScreen?.dispatchEvent(e);
            })
            .onComplete(scene->{
                Debugger.log("scene " + id + " has sucessfully been loaded, cleaning up...");
                instance.dispatchEvent(new Event(Event.COMPLETE));
                //TODO: dispatch complete to loading screen and have that prevent default or not
                instance.removeLoadingScreen();
                instance.addScene(scene);
            });

        return completeChain;
    }

    public static function getSceneId(scene:IScene):Null<String> {
        for (id in scenes.keys()) {
            if (scenes.get(id) == scene) {
                return id; // found
            }
        }
        return null; // not found
    }

    public static function gotoHomeScene() {
        return gotoScene(getSceneId(homescene));
    }
}
