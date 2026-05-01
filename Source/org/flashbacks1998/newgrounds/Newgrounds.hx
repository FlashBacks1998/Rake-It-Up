package org.flashbacks1998.newgrounds;

import haxe.Json;
import io.newgrounds.NG;
import io.newgrounds.NGLite;
import io.newgrounds.NGLite.LoginCancel;
import io.newgrounds.NGLite.LoginFail;
import io.newgrounds.NGLite.LoginOutcome;
import io.newgrounds.components.ScoreBoardComponent.Period;
import io.newgrounds.objects.SaveSlot;
import io.newgrounds.objects.Score;
import io.newgrounds.objects.ScoreBoard;
import io.newgrounds.utils.ObjectList.ListState;
import org.flashbacks1998.debugger.Debugger;

typedef CloudScoreData = {
    var score:Int;
}

class Newgrounds {
    public static inline var API = "61960:LuVJfMjl";
    public static inline var ENCRYPTION_KEY = "8wPX0derWr65jzPMwy4w2Q==";

    public static inline var SCOREBOARD_ID = 15835;
    public static inline var DEFAULT_SAVE_SLOT_ID = 1;
    /** Cloud slot used to persist the GnomeSystem hscript source. */
    public static inline var GNOME_SOURCE_SLOT_ID = 2;

    // ------------------------------------------------------------------
    // MEDAL IDs
    // ------------------------------------------------------------------
    /** "Passed the starting line." — 10k points reached. */
    public static inline var MEDAL_PASSED_STARTING_LINE = 89946;
    /** "Gnome modification" — user-modified hscript ran successfully. */
    public static inline var MEDAL_GNOME_MODIFICATION = 89947;

    /**
     * Bootstraps NG.core. If `sessionId` isn't explicitly passed, picks up
     * `ngio_session_id` from the flash player's FlashVars (or JS URL params
     * on html5) via the library's own `NGLite.getSessionId()`. When a session
     * is provided the library automatically kicks off a session-validation
     * call in the background; `login()` waits for that if needed.
     */
    public static function init(?sessionId:String) {
        if (sessionId == null) {
            // Wrap: on local Flash/Ruffle runs `loaderInfo.parameters` may be
            // null and the lib's `Reflect.hasField(params, "...")` can throw,
            // which would otherwise propagate up and block scene loading.
            try {
                sessionId = NGLite.getSessionId();
                if (sessionId != null) {
                    Debugger.log("Newgrounds.init: picked up ngio_session_id from player params");
                }
            } catch (e:Dynamic) {
                Debugger.log("Newgrounds.init: getSessionId threw, treating as no-session:", e);
                sessionId = null;
            }
        }
        Debugger.log("Newgrounds.init sessionId=", sessionId);
        try {
            NG.create(API, sessionId);
            NG.core.setupEncryption(ENCRYPTION_KEY, AES_128, BASE_64);
            Debugger.log("Newgrounds.init complete (attemptingLogin=" + NG.core.attemptingLogin + ")");
        } catch (e:Dynamic) {
            Debugger.log("Newgrounds.init: NG.create/setupEncryption threw:", e);
        }
    }

    /**
     * Resolve the logged-in state of NG.core. Three paths:
     *
     *   1. Already logged in (session validated or previous requestLogin succeeded)
     *      → `callback(SUCCESS)` immediately.
     *   2. Session validation from `init()` is still in flight (`attemptingLogin`)
     *      → defer: attach a one-shot `onLogin` listener and re-check when it fires.
     *   3. Neither — caller decides via `ask`:
     *        - `ask = true`  → prompt via `requestLogin` (opens Newgrounds passport).
     *        - `ask = false` → `callback(FAIL(CANCELLED(MANUAL)))` (don't interrupt the user).
     *
     * This ensures `Newgrounds.login(false, cb)` works correctly when a session
     * was passed via FlashVars — the caller gets SUCCESS once the server has
     * validated it, without any popup.
     */
    public static function login(ask:Bool = true, callback:LoginOutcome->Void) {
        if (NG.core.loggedIn) {
            Debugger.log("Newgrounds.login: already logged in, skipping");
            callback(SUCCESS);
            return;
        }
        if (NG.core.attemptingLogin) {
            Debugger.log("Newgrounds.login: session check in progress — deferring");
            NG.core.onLogin.addOnce(function() {
                if (NG.core.loggedIn) {
                    Debugger.log("Newgrounds.login (deferred): session validated");
                    callback(SUCCESS);
                } else if (ask) {
                    Debugger.log("Newgrounds.login (deferred): session invalid, prompting");
                    NG.core.requestLogin(callback);
                } else {
                    Debugger.log("Newgrounds.login (deferred): session invalid, ask=false → CANCELLED");
                    callback(FAIL(CANCELLED(MANUAL)));
                }
            });
            return;
        }
        if (!ask) {
            Debugger.log("Newgrounds.login: not logged in, ask=false → CANCELLED");
            callback(FAIL(CANCELLED(MANUAL)));
            return;
        }
        Debugger.log("Newgrounds.login: requesting login...");
        NG.core.requestLogin(callback);
    }

    /**
     * Convenience reader for FlashVars / URL params passed by the player.
     * Returns null on non-flash targets or when the key is absent.
     * Exposed so UI can display the user's name before NG.core's session
     * check completes.
     */
    public static function getPlayerParam(name:String):String {
        #if flash
        try {
            final li = flash.Lib.current.stage.loaderInfo;
            if (li != null && Reflect.hasField(li.parameters, name)) {
                return Std.string(Reflect.field(li.parameters, name));
            }
        } catch (_:Dynamic) {}
        #end
        return null;
    }

    /** Shortcut: `ng_username` or `NewgroundsAPI_UserName`, whichever is present. **/
    public static function getPlayerUsername():String {
        var u = getPlayerParam("ng_username");
        if (u != null) return u;
        return getPlayerParam("NewgroundsAPI_UserName");
    }

    /** Shortcut: `NewgroundsAPI_UserID` as a string, or null. **/
    public static function getPlayerUserId():String {
        return getPlayerParam("NewgroundsAPI_UserID");
    }

    //------------------------------------------------------------------
    // STATUS HELPERS — cheap field reads, safe to call every frame
    // (used by DebuggerStats overlay).
    //------------------------------------------------------------------

    /** True after `init()` has successfully created the NG core. **/
    public static function isConnected():Bool {
        return NG.core != null;
    }

    /** True once the server has validated the active session. **/
    public static function isLoggedIn():Bool {
        return NG.core != null && NG.core.loggedIn;
    }

    /** True while the session handshake from init() is still in flight. **/
    public static function isAttemptingLogin():Bool {
        return NG.core != null && NG.core.attemptingLogin;
    }

    /**
     * Username to display in diagnostics. Prefers the validated NG user,
     * falls back to the FlashVars `ng_username` / `NewgroundsAPI_UserName`
     * if the session hasn't been validated yet. Returns null if neither.
     */
    public static function getActiveUsername():String {
        if (NG.core != null && NG.core.loggedIn && NG.core.user != null) {
            return NG.core.user.name;
        }
        return getPlayerUsername();
    }

    /** One-line summary string for overlays. **/
    public static function getStatusLine():String {
        if (!isConnected()) return "offline";
        if (isLoggedIn()) {
            final u = getActiveUsername();
            return (u != null) ? 'logged in as $u' : "logged in";
        }
        if (isAttemptingLogin()) return "checking session…";
        final hinted = getPlayerUsername();
        return (hinted != null) ? 'not logged in (hint: $hinted)' : "not logged in";
    }

    /**
     * Returns the cached contents of save slot #DEFAULT_SAVE_SLOT_ID,
     * re-serialized via `haxe.Json.stringify` so overlays can show the
     * structured payload. Null-safe: returns null if NG isn't ready, the
     * slot list hasn't loaded, the slot is empty, contents aren't valid
     * JSON, or the library throws internally (same `_map`-is-null window
     * that bit `getBoard()`).
     */
    public static function getLoadedCloudSaveJson():String {
        final slot = safeSaveSlot(DEFAULT_SAVE_SLOT_ID);
        if (slot == null) return null;
        if (slot.isEmpty()) return null;
        if (slot.contents == null) return null;
        try {
            final parsed = Json.parse(slot.contents);
            return Json.stringify(parsed);
        } catch (e:Dynamic) {
            Debugger.log("Newgrounds.getLoadedCloudSaveJson: failed", e);
            return null;
        }
    }

    /**
     * Call this once after login/session is ready.
     * It populates NG.core.saveSlots and NG.core.scoreBoards.
     *
     * If `onReady` is provided it fires once BOTH lists have transitioned to
     * Loaded. `onLoad` only fires on success — if a list fails to load the
     * callback may never fire. That's acceptable: the game has nothing to
     * render without data anyway, and callers route through null-safe
     * accessors (`safeSaveSlot`, `getBoard`) for ongoing access.
     */
    public static function loadCoreData(?onReady:Void->Void):Void {
        Debugger.log("Newgrounds.loadCoreData: loading save slots + scoreboards + medals");
        NG.core.saveSlots.loadList();
        NG.core.scoreBoards.loadList();
        NG.core.medals.loadList();
        if (onReady == null) return;

        var remaining = 0;
        function bump() {
            remaining--;
            if (remaining == 0) onReady();
        }
        if (NG.core.saveSlots.state != Loaded)   { remaining++; NG.core.saveSlots.onLoad.addOnce(bump); }
        if (NG.core.scoreBoards.state != Loaded) { remaining++; NG.core.scoreBoards.onLoad.addOnce(bump); }
        if (NG.core.medals.state != Loaded)      { remaining++; NG.core.medals.onLoad.addOnce(bump); }
        if (remaining == 0) onReady();
    }

    /**
     * Null-safe board accessor. Returns null if NG isn't initialized, if
     * `loadCoreData()` hasn't completed, if the board id isn't registered,
     * or if the library throws internally. Same proactive `state` guard as
     * `safeSaveSlot` — the inlined `ObjectList.get()` NPE doesn't reliably
     * unwind through try/catch on Flash/Ruffle.
     */
    public static function getBoard():ScoreBoard {
        try {
            if (NG.core == null) return null;
            final boards = NG.core.scoreBoards;
            if (boards == null) return null;
            if (boards.state != Loaded) return null;
            return boards.get(SCOREBOARD_ID);
        } catch (e:Dynamic) {
            Debugger.log("Newgrounds.getBoard: library threw", e);
            return null;
        }
    }

    /**
     * Null-safe save-slot accessor. Returns null if NG isn't initialized,
     * if `loadCoreData()` hasn't completed, if the slot id isn't registered,
     * or if the library throws internally.
     *
     * IMPORTANT: the state check (`Loaded`) is required, not just defensive.
     * `ObjectList.get()` is defined as `inline return _map.get(id)` with no
     * null guard. The Haxe compiler inlines it at our callsite, so an NPE
     * from `_map.get()` when `_map` is null is thrown out of the inlined
     * library bytecode. Flash/Ruffle does not reliably unwind that throw
     * back through our `try/catch`, so we must avoid calling `.get()` at all
     * unless the list has actually finished loading.
     */
    private static function safeSaveSlot(id:Int):SaveSlot {
        try {
            if (NG.core == null) return null;
            final slots = NG.core.saveSlots;
            if (slots == null) return null;
            // Proactive guard: only call .get() once saveSlots.loadList()
            // has resolved (state transitions Empty → Loading → Loaded).
            if (slots.state != Loaded) return null;
            return slots.get(id);
        } catch (e:Dynamic) {
            Debugger.log("Newgrounds.safeSaveSlot: library threw", e);
            return null;
        }
    }

    /**
     * Returns the current cached best score if the slot has already been loaded.
     * Returns 0 if the slot system isn't ready, the slot is empty, or the
     * cached JSON can't be parsed.
     */
    public static function getLoadedCloudScore():Int {
        var slot = safeSaveSlot(DEFAULT_SAVE_SLOT_ID);
        if (slot == null || slot.isEmpty() || slot.contents == null) {
            Debugger.log("Newgrounds.getLoadedCloudScore: slot empty or not loaded, returning 0");
            return 0;
        }
        try {
            var data:CloudScoreData = Json.parse(slot.contents);
            var result = data != null ? data.score : 0;
            Debugger.log("Newgrounds.getLoadedCloudScore:", result);
            return result;
        } catch (e:Dynamic) {
            Debugger.log("Newgrounds.getLoadedCloudScore: parse failed", e);
            return 0;
        }
    }

    /**
     * Saves the user's score JSON into Cloud Save slot 1. No-op (with log)
     * if the slot system isn't ready yet.
     */
    public static function saveCloudScore(score:Int):Void {
        if (NG.core == null || NG.core.saveSlots == null) {
            Debugger.log("Newgrounds.saveCloudScore: NG not initialized, cannot save");
            return;
        }
        if (NG.core.saveSlots.state != Loaded) {
            // Skip rather than defer: if we save before knowing the existing
            // cloud value we risk overwriting a higher server-side best with
            // an in-session score that hasn't been compared against it.
            Debugger.log("Newgrounds.saveCloudScore: slots not loaded, skipping to avoid overwrite");
            return;
        }
        var slot = safeSaveSlot(DEFAULT_SAVE_SLOT_ID);
        if (slot == null) {
            Debugger.log("Newgrounds.saveCloudScore: slot unavailable, cannot save");
            return;
        }
        Debugger.log("Newgrounds.saveCloudScore:", score);
        try {
            var payload = Json.stringify({ score: score });
            slot.save(payload);
        } catch (e:Dynamic) {
            Debugger.log("Newgrounds.saveCloudScore: save threw", e);
        }
    }

    /**
     * Loads slot 1 contents and calls onLoaded(score) when ready.
     * Always calls onLoaded exactly once: 0 if the slot is unavailable/empty
     * or if the library throws during load dispatch; otherwise the score.
     *
     * Safe to call before `saveSlots.loadList()` has resolved — in that
     * window `safeSaveSlot()` returns null and we fire `onLoaded(0)` rather
     * than propagating an NPE up to Ruffle's event-dispatch layer.
     */
    public static function loadCloudScoreWithCallback(onLoaded:Int->Void):Void {
        if (NG.core == null || NG.core.saveSlots == null) {
            Debugger.log("Newgrounds.loadCloudScoreWithCallback: NG not initialized, returning 0");
            onLoaded(0);
            return;
        }
        if (NG.core.saveSlots.state != Loaded) {
            Debugger.log("Newgrounds.loadCloudScoreWithCallback: slots not loaded yet, deferring");
            NG.core.saveSlots.onLoad.addOnce(function() loadCloudScoreWithCallback(onLoaded));
            return;
        }
        var slot = safeSaveSlot(DEFAULT_SAVE_SLOT_ID);
        if (slot == null || slot.isEmpty()) {
            Debugger.log("Newgrounds.loadCloudScoreWithCallback: slot null or empty, returning 0");
            onLoaded(0);
            return;
        }
        Debugger.log("Newgrounds.loadCloudScoreWithCallback: loading slot", DEFAULT_SAVE_SLOT_ID);
        try {
            slot.load(outcome -> switch outcome {
                case SUCCESS(_):
                    final s = getLoadedCloudScore();
                    Debugger.log("Newgrounds.loadCloudScoreWithCallback: loaded score", s);
                    onLoaded(s);
                case FAIL(e):
                    Debugger.log("Newgrounds.loadCloudScoreWithCallback: load failed", e);
                    onLoaded(0);
            });
        } catch (e:Dynamic) {
            Debugger.log("Newgrounds.loadCloudScoreWithCallback: slot.load threw", e);
            onLoaded(0);
        }
    }

    /**
     * Saves arbitrary text (e.g. the GnomeSystem hscript source) to its own
     * cloud slot. No-op (with log) if NG isn't ready or the slot list hasn't
     * loaded yet — same guards as `saveCloudScore`.
     */
    public static function saveCloudGnomeSource(source:String):Void {
        if (NG.core == null || NG.core.saveSlots == null) {
            Debugger.log("Newgrounds.saveCloudGnomeSource: NG not initialized, cannot save");
            return;
        }
        if (NG.core.saveSlots.state != Loaded) {
            Debugger.log("Newgrounds.saveCloudGnomeSource: slots not loaded, skipping");
            return;
        }
        var slot = safeSaveSlot(GNOME_SOURCE_SLOT_ID);
        if (slot == null) {
            Debugger.log("Newgrounds.saveCloudGnomeSource: slot unavailable, cannot save");
            return;
        }
        Debugger.log("Newgrounds.saveCloudGnomeSource:", (source != null ? source.length : 0), "chars");
        try {
            slot.save(source != null ? source : "");
        } catch (e:Dynamic) {
            Debugger.log("Newgrounds.saveCloudGnomeSource: save threw", e);
        }
    }

    /**
     * Loads the cached GnomeSystem source (slot #GNOME_SOURCE_SLOT_ID) and
     * calls onLoaded with the string (or null if unavailable / empty / errored).
     */
    public static function loadCloudGnomeSourceWithCallback(onLoaded:String->Void):Void {
        if (NG.core == null || NG.core.saveSlots == null) {
            Debugger.log("Newgrounds.loadCloudGnomeSourceWithCallback: NG not initialized");
            onLoaded(null);
            return;
        }
        if (NG.core.saveSlots.state != Loaded) {
            Debugger.log("Newgrounds.loadCloudGnomeSourceWithCallback: slots not loaded yet, deferring");
            NG.core.saveSlots.onLoad.addOnce(function() loadCloudGnomeSourceWithCallback(onLoaded));
            return;
        }
        var slot = safeSaveSlot(GNOME_SOURCE_SLOT_ID);
        if (slot == null || slot.isEmpty()) {
            Debugger.log("Newgrounds.loadCloudGnomeSourceWithCallback: slot null or empty");
            onLoaded(null);
            return;
        }
        try {
            slot.load(outcome -> switch outcome {
                case SUCCESS(_):
                    Debugger.log("Newgrounds.loadCloudGnomeSourceWithCallback: loaded",
                        (slot.contents != null ? slot.contents.length : 0), "chars");
                    onLoaded(slot.contents);
                case FAIL(e):
                    Debugger.log("Newgrounds.loadCloudGnomeSourceWithCallback: load failed", e);
                    onLoaded(null);
            });
        } catch (e:Dynamic) {
            Debugger.log("Newgrounds.loadCloudGnomeSourceWithCallback: slot.load threw", e);
            onLoaded(null);
        }
    }

    /**
     * Saves only if this score is better than what is already loaded, and
     * on a new best also posts to the Newgrounds scoreboard so the run
     * shows up on the leaderboard. Defers the whole comparison if slots
     * aren't loaded — otherwise `getLoadedCloudScore` would read 0 and
     * we'd wrongly treat every early-game tick as a new best.
     */
    public static function saveBestCloudScore(score:Int):Void {
        if (NG.core == null || NG.core.saveSlots == null) {
            Debugger.log("Newgrounds.saveBestCloudScore: NG not initialized, skipping");
            return;
        }
        if (NG.core.saveSlots.state != Loaded) {
            // Skip rather than defer: until the existing save is loaded we
            // can't tell if `score` would be a new best or an overwrite of
            // something higher.
            Debugger.log("Newgrounds.saveBestCloudScore: slots not loaded, skipping to avoid overwrite");
            return;
        }
        final best = getLoadedCloudScore();
        if (score > best) {
            Debugger.log("Newgrounds.saveBestCloudScore: new best", score, "> previous", best);
            saveCloudScore(score);
            postHighScore(score);
        } else {
            Debugger.log("Newgrounds.saveBestCloudScore: not a new best", score, "<= current", best);
        }
    }

    /**
     * Unlocks the medal with the given id. No-op if:
     *   - NG hasn't been initialized,
     *   - the medal list hasn't loaded yet (defers via `onLoad`),
     *   - the medal id isn't registered for this app,
     *   - the medal is already unlocked server-side.
     *
     * Callers should still gate their own call sites on a local flag to avoid
     * looking up the medal map every frame — this method is the SECOND line of
     * defense, not the only one.
     */
    public static function unlockMedal(id:Int):Void {
        if (NG.core == null || NG.core.medals == null) {
            Debugger.log("Newgrounds.unlockMedal: NG not initialized, cannot unlock", id);
            return;
        }
        if (NG.core.medals.state != Loaded) {
            Debugger.log("Newgrounds.unlockMedal: medals not loaded yet, deferring", id);
            NG.core.medals.onLoad.addOnce(function() unlockMedal(id));
            return;
        }
        try {
            final medal = NG.core.medals.get(id);
            if (medal == null) {
                Debugger.log("Newgrounds.unlockMedal: medal", id, "not registered for this app");
                return;
            }
            if (medal.unlocked) {
                Debugger.log("Newgrounds.unlockMedal: medal", id, "already unlocked, skipping");
                return;
            }
            Debugger.log("Newgrounds.unlockMedal: unlocking", id, "(" + medal.name + ")");
            medal.sendUnlock();
        } catch (e:Dynamic) {
            Debugger.log("Newgrounds.unlockMedal: threw for", id, e);
        }
    }

    /**
     * Posts a score to board #15835.
     */
    public static function postHighScore(score:Int):Void {
        var board = getBoard();
        if (board == null) {
            Debugger.log("Newgrounds.postHighScore: board null, cannot post");
            return;
        }
        Debugger.log("Newgrounds.postHighScore:", score);
        board.postScore(score);
    }

    /**
     * Requests top scores for board #15835.
     *
     * - `onLoaded(scores)` fires on success with the fresh `Array<Score>`.
     *   Each Score: `.user.name`, `.user.id`, `.value:Int`, `.formattedValue:String`.
     * - `onError(message)` fires on any failure: NG not initialized, board
     *   unavailable (typical pre-login), API-level failure, or a thrown
     *   exception (e.g. sandbox / security). If `onError` is omitted, errors
     *   fall through to `onLoaded([])` so the caller still gets a response.
     *
     * All synchronous exceptions are caught and reported via `onError` —
     * this method cannot throw.
     */
    public static function requestHighScores(limit:Int = 20, ?onLoaded:Array<Score>->Void, ?onError:String->Void):Void {
        inline function fail(msg:String) {
            Debugger.log("Newgrounds.requestHighScores:", msg);
            if (onError != null) onError(msg);
            else if (onLoaded != null) onLoaded([]);
        }

        if (NG.core == null) {
            fail("Newgrounds not initialized (call Newgrounds.init() first)");
            return;
        }
        var board = getBoard();
        if (board == null) {
            fail('Scoreboard #$SCOREBOARD_ID unavailable (loadCoreData not complete?)');
            return;
        }

        Debugger.log("Newgrounds.requestHighScores limit=", limit);
        try {
            board.requestScores(limit, 0, Period.ALL, false, null, null, outcome -> switch outcome {
                case SUCCESS:
                    final scores = board.scores != null ? board.scores : [];
                    Debugger.log("Newgrounds.requestHighScores: loaded", scores.length, "scores");
                    if (onLoaded != null) onLoaded(scores);
                case FAIL(err):
                    fail("Scoreboard request failed: " + Std.string(err));
            });
        } catch (e:Dynamic) {
            fail("Exception during requestScores: " + Std.string(e));
        }
    }
}