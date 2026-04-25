package org.flashbacks1998.workers;

import openfl.events.Event;
import openfl.Lib;
import openfl.utils.Future; // alias to lime.app.Future
import lime.app.Promise;
import openfl.Vector;

/**
 * WorkerStatus - returned by your chunk function
 *  - complete: Bool   -> did the whole job finish?
 *  - percent: Float   -> progress 0..100
 *  - data: Dynamic    -> optional result payload (on complete)
 *  - error: Dynamic   -> optional error (if non-null, worker is considered errored)
 */
typedef WorkerStatus = {
    var complete:Bool;
    var ?percent:Float;
    var ?data:Dynamic;
    var ?error:Dynamic;
}

class Worker {
    public static var ASYNC:Bool = false;
    public static var PERCENT:Int = 80;

    private static var _workers:Vector<Worker> = new Vector<Worker>();
    private static var _initialized:Bool = false;

    // exposed future for consumers
    public var future:Future<Dynamic>;
    // internal promise to resolve/reject
    private var _promise:Promise<Dynamic>;

    // the user-provided chunk function: do a slice of work and return WorkerStatus
    private var _func:Void->WorkerStatus;

    private var _progress:Float = 0;
    private var _completed:Bool = false;
    private var _errored:Bool = false;
    private var _canceled:Bool = false;
    private var _data:Dynamic = null;

    private static var i = 0;

    public function new(func:Void->WorkerStatus) {
        this._func = func;
        this._promise = new Promise<Dynamic>();
        this.future = this._promise.future;
 
    }

    /**
     * Execute one chunk. Returns the status returned by the chunk function.
     * This may set internal flags if an error or completion is reported.
     */
    public function execute():WorkerStatus {
        if (_canceled || _completed || _errored) {
            return { complete: _completed, percent: _progress, data: null, error: null };
        }

        try {
            var results = _func();
            if (results == null) results = { complete: false, percent: _progress, data: null, error: null };

            // normalize percent
            if (results.percent == null) results.percent = _progress;
            if (results.percent < 0) results.percent = 0;
            if (results.percent > 100) results.percent = 100;
            _progress = results.percent;

            // if an error was reported, mark errored and ensure promise is rejected (once)
            if (results.error != null) {
                _errored = true;
                if (!_promise.isError && !_promise.isComplete) _promise.error(results.error);
                // mark as "finished" so main loop removes it from active workers
                return results;
            }

            // if complete, resolve the promise (but don't call complete here; main loop dispatches)
            if (results.complete) {
                _completed = true;
                // we delay calling _promise.complete until dispatch, to keep dispatch path unified
                return results;
            }

            // not complete, not error -> continue
            return results;
        } catch (err:Dynamic) {
            // unexpected exception: mark errored and reject promise
            _errored = true;
            if (!_promise.isError && !_promise.isComplete) _promise.error(err);
            return { complete: false, percent: _progress, data: null, error: err };
        }
    }

    /**
     * Called from the main thread to dispatch progress/complete/error events to the Promise.
     * Accepts the last status object so callers can pass accurate data if desired.
     */
    public function dispatch(status:WorkerStatus) {
        // don't dispatch if promise already settled
        if (_promise.isComplete || _promise.isError) return;

        if (_canceled) {
            _promise.error("canceled");
            return;
        }

        // progress dispatch (promise.progress takes (value, total))
        _promise.progress(Std.int(_progress), 100);

        // If status has error, reject
        if (status != null && status.error != null) {
            if (!_promise.isError && !_promise.isComplete) _promise.error(status.error);
            return;
        }

        // If complete, resolve with data
        if (status != null && status.complete) {
            if (!_promise.isComplete && !_promise.isError) _promise.complete(status.data);
        }
    }

    public function cancel() {
        _canceled = true;
    }

    public function start():Future<Dynamic> {
        if (!_initialized) Worker.setup();
        _workers.push(this);
        return this.future;
    }

    public static function spawn(func:Void->WorkerStatus):Future<Dynamic> {
        return (new Worker(func)).start();
    }

    public static function setup() {
        if (_initialized) return;
        _initialized = true;
        Lib.current.stage.addEventListener(Event.ENTER_FRAME, workOnWorkers);
    }

    private static var _workersFinished:Vector<Worker> = new Vector<Worker>();

    /**
     * Main per-frame loop. Fits chunks into a frame time budget.
     */
    public static function workOnWorkers(?e:Event) {
        final start = Lib.getTimer();
        final frameMs = Std.int(1000 / Math.max(1, Lib.current.stage.frameRate));
        final expectedEnd = start + frameMs;

        _workersFinished.length = 0;
 

        // iterate and execute chunks until we run out of time
        while (Lib.getTimer() < expectedEnd) { 
            var i = _workers.length - 1;
            if (i < 0) break;
            while (i >= 0) {
                var w = _workers[i];
                var status = w.execute();

                // if worker reported error or completed, schedule it for final dispatch/removal
                if (status != null && (status.complete || status.error != null)) {
                    w._data = status.data;
                    _workersFinished.push(w);
                    _workers.removeAt(i);
                }
 

                i--;
                if (Lib.getTimer() >= expectedEnd) break;
            }
        }
 
        // dispatch progress for remaining workers
        //for (w in _workers) {
        i = _workers.length;
        while(i > 0) {
            i--;
            final w = _workers[i];
            w.dispatch({ complete: false, percent: w._progress, data: null, error: null });
        }

        // dispatch final messages (complete or error) for finished workers
        i = _workersFinished.length;
        while(i > 0) {
            i--;
            // Ideally we would keep the last status object returned by execute to pass
            // the exact data/error. For simplicity, call dispatch with a small status object:

            final w = _workersFinished[i];

            if (w._errored) {
                w.dispatch({ complete: false, percent: w._progress, data: null, error: "worker errored" });
            } else if (w._completed) {
                w.dispatch({ complete: true, percent: w._progress, data: w._data, error: null });
            } else if (w._canceled) {
                w.dispatch({ complete: false, percent: w._progress, data: null, error: "canceled" });
            } else {
                // fallback
                w.dispatch({ complete: false, percent: w._progress, data: null, error: null });
            }
        }
    }

    public static function activeCount():Int {
        return _workers.length;
    }
}
