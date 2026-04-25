package org.flashbacks1998.rake.scenes.tests;

import org.flashbacks1998.world3d.engine.software.BasicSoftwareEngine;
import haxe.ds.ObjectMap;

import openfl.Vector;
import openfl.Lib;
import openfl.Assets;
import openfl.events.Event;
import openfl.display.Stage;
import openfl.utils.Future;

import org.flashbacks1998.debugger.Debugger;
import org.flashbacks1998.scenes.Scene;

import org.flashbacks1998.world3d.parsers.ObjParser;
import org.flashbacks1998.world3d.optimizers.Entity3DOptimizer;

import org.flashbacks1998.world3d.entity.IEntity3D;
import org.flashbacks1998.world3d.entity.Entity3D;

import org.flashbacks1998.world3d.geom.Mesh3D;
import org.flashbacks1998.world3d.geom.Position3D;

import org.flashbacks1998.world3d.camera.ThirdPersonCamera3D;
import org.flashbacks1998.world3d.camera.controllers.ThirdPersonCamera3DScreenController;

import org.flashbacks1998.util.FutureUtil;

class SceneTestSR01 extends Scene {
    var engine:BasicSoftwareEngine;
    var eTree:Entity3D;

    public final cameraDistanceMin:Float = 5;
    public final cameraDistanceMax:Float = 35;
    public var cameraDistance:Float = 10;
    public var cameraController:ThirdPersonCamera3DScreenController;
    public var camera:ThirdPersonCamera3D;

    public function new() {
        super();
    }

    public function initWorld():Future<Any> {
        camera = new ThirdPersonCamera3D(new Position3D(0, 1, 0), cameraDistance, cameraDistance, cameraDistance);
        cameraController = new ThirdPersonCamera3DScreenController(camera);
        cameraController.enabled = true;
        camera.lookAt(0, 0, 0);

        engine = new BasicSoftwareEngine(Lib.current.stage.stageWidth, Lib.current.stage.stageHeight, camera);
        addChild(engine.container);


		// Pile of leaves
		final meshObjPOL:Mesh3DAndShaderPair = {
			mesh: new SphereMesh3D(2, 1, 100, 50),
			shader: new MtlShader({bmpData: Assets.getBitmapData("assets/textures/pileovleaves.png")})
		}; 
		cast(meshObjPOL.shader, ShaderPipeline).parts.push(_spDithering);
        _spDitheredPileOfLeavesShader = cast meshObjPOL.shader;

		ePileOfLeaves = new Entity3D({meshes: Vector.ofArray([meshObjPOL])});
		ePileOfLeaves.position.scaleX = ePileOfLeaves.position.scaleZ = 4;
		ePileOfLeaves.position.x = -8.5;
		ePileOfLeaves.position.z = 8.5;
		engine.entities.push(ePileOfLeaves);

		// Floor
		final mFloor = new PlaneMeshXZ3D();
		final eFloor = new Entity3D({
			meshes: Vector.ofArray(cast [
				{
					mesh: mFloor,
					shader: new TextureShader({
						bmpData: Assets.getBitmapData("assets/textures/floor.png")
					})
				}
			])
		});

		eFloor.position.scaleX = eFloor.position.scaleZ = 15;
		engine.entities.push(eFloor);

        Debugger.log("Loading Treed.obj...");
        final fTreePipeline = Assets.loadText("assets/objects/Treed.obj").then(c -> {
            Debugger.log("Treed.obj loaded ", (c != null ? c.length : -1));
            var parserTree = new ObjParser(c);
            Debugger.log("ObjParser created for Treed.obj, starting parse");
            parserTree.start();
            return parserTree.future;
        }).then(e -> {
            final entities:Vector<IEntity3D> = cast e;

            final eOpt = Entity3DOptimizer.optimizeEntity3Ds(entities, { combineEntity3DMeshes: true });
            eTree = cast eOpt[0];
            engine.entities.push(eTree);

            //return Future.withValue(eTree);
        });

        return FutureUtil.all([fTreePipeline]).then(_ -> Future.withValue(0));
    }

    public function initPhysics():Future<Any> {
        return Future.withValue(0);
    }

    public function initStage():Future<Stage> {
        addEventListener(Event.ENTER_FRAME, onEnterFrame);
        return Future.withValue(Lib.current.stage);
    }

    public override function init() {
        Debugger.log("Setting up the rake game thingy i havent named it yet");

        final futureWorld = initWorld();
        final futurePhysics = initPhysics();
        final futureStage = initStage();
        final futures:Array<Future<Any>> = [super.init(), futureWorld, futurePhysics, futureStage];

        return FutureUtil.all(futures).then(_ -> Future.withValue(cast this));
    } 

    public function onEnterFrame(e:Event) {
        camera.updateMatrices();
        engine.render();
    }
}