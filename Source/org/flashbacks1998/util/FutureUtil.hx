package org.flashbacks1998.util;

import openfl.utils.Future;
import openfl.utils.Promise;

/** Status for a completed Future used by allSettled */
enum FutureStatus<T> {
    Fulfilled(value:T);
    Rejected(error:Dynamic);
}

class FutureUtil {
    /** Sum helper */
    inline static function sum(a:Array<Int>):Int {
        var s = 0;
        for (v in a) s += v;
        return s;
    }

    /**
     * Wait for all futures to settle (either fulfill or reject).
     * Always fulfills with an array of per-future statuses in the same order.
     * Emits aggregate progress as (bytesLoaded, bytesTotal).
     */
    public static function allSettled<T>(futures:Array<Future<T>>):Future<Array<FutureStatus<T>>> {
        var p = new Promise<Array<FutureStatus<T>>>();
        var n = futures == null ? 0 : futures.length;

        if (n == 0) {
            // empty → done
            p.progress(1, 1);
            p.complete([]);
            return p.future;
        }

        var results:Array<FutureStatus<T>> = cast [for (_ in 0...n) null];
        var loaded  = [for (_ in 0...n) 0];
        var totals  = [for (_ in 0...n) 0];
        var done = 0;

        inline function emit() p.progress(sum(loaded), sum(totals));
        inline function finishIfReady() {
            if (done == n) {
                // ensure a sane final progress (avoid 0/0)
                var L = sum(loaded), T = sum(totals);
                if (T == 0) { L = n; T = n; } // n-of-n complete
                p.progress(L, T);
                p.complete(results);
            }
        }

        // initial tick
        emit();

        for (i in 0...n) {
            var f = futures[i];
            if (f == null) {
                results[i] = Rejected("FutureUtil.allSettled: null future at index " + i);
                // mark slot as done
                loaded[i] = 1; totals[i] = 1; emit();
                done++; finishIfReady();
                continue;
            }

            f.onProgress(function (bytesLoaded:Int, bytesTotal:Int) {
                // OpenFL passes Ints; keep them as-is
                loaded[i] = bytesLoaded < 0 ? 0 : bytesLoaded;
                totals[i] = bytesTotal  < 0 ? 0 : bytesTotal;
                if (totals[i] > 0 && loaded[i] > totals[i]) loaded[i] = totals[i]; // clamp
                emit();
            });

            f.onComplete(function (value:T) {
                results[i] = Fulfilled(value);
                // force “done” for this slot
                if (totals[i] < loaded[i]) totals[i] = loaded[i];
                if (totals[i] == 0) totals[i] = loaded[i] == 0 ? 1 : loaded[i];
                loaded[i] = totals[i];
                emit();
                done++; finishIfReady();
            });

            f.onError(function (e:Dynamic) {
                results[i] = Rejected(e);
                // also mark as done so aggregate advances
                if (totals[i] < loaded[i]) totals[i] = loaded[i];
                if (totals[i] == 0) totals[i] = loaded[i] == 0 ? 1 : loaded[i];
                loaded[i] = totals[i];
                emit();
                done++; finishIfReady();
            });
        }

        return p.future;
    }

    /**
     * Wait for all futures to fulfill, preserving order.
     * Fulfills with array of values, or rejects immediately on first error.
     * Emits aggregate progress as (bytesLoaded, bytesTotal).
     */
    public static function all<T>(futures:Array<Future<T>>):Future<Array<T>> {
        var p = new Promise<Array<T>>();
        var n = futures == null ? 0 : futures.length;

        if (n == 0) {
            p.progress(1, 1);
            p.complete([]);
            return p.future;
        }

        var values:Array<T> = cast [for (_ in 0...n) null];
        var loaded  = [for (_ in 0...n) 0];
        var totals  = [for (_ in 0...n) 0];
        var remaining = n;
        var failed = false;

        inline function emit() p.progress(sum(loaded), sum(totals));

        // initial tick
        emit();

        for (i in 0...n) {
            var f = futures[i];

            if (f == null) {
                if (!failed) {
                    // mark as done for visual consistency, then fail fast
                    loaded[i] = 1; totals[i] = 1; emit();
                    failed = true;
                    p.error("FutureUtil.all: null future at index " + i);
                }
                continue;
            }

            f.onProgress(function (bytesLoaded:Int, bytesTotal:Int) {
                if (failed) return;
                loaded[i] = bytesLoaded < 0 ? 0 : bytesLoaded;
                totals[i] = bytesTotal  < 0 ? 0 : bytesTotal;
                if (totals[i] > 0 && loaded[i] > totals[i]) loaded[i] = totals[i];
                emit();
            });

            f.onComplete(function (value:T) {
                if (failed) return;
                values[i] = value;

                if (totals[i] < loaded[i]) totals[i] = loaded[i];
                if (totals[i] == 0) totals[i] = loaded[i] == 0 ? 1 : loaded[i];
                loaded[i] = totals[i];
                emit();

                remaining--;
                if (remaining == 0) {
                    // final sane progress
                    var L = sum(loaded), T = sum(totals);
                    if (T == 0) { L = n; T = n; }
                    p.progress(L, T);
                    p.complete(values);
                }
            });

            f.onError(function (e:Dynamic) {
                if (failed) return;
                // finish this slot for display, then fail
                if (totals[i] < loaded[i]) totals[i] = loaded[i];
                if (totals[i] == 0) totals[i] = loaded[i] == 0 ? 1 : loaded[i];
                loaded[i] = totals[i];
                emit();

                failed = true;
                p.error(e);
            });
        }

        return p.future;
    }
}
