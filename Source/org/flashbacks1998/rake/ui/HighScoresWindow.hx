package org.flashbacks1998.rake.ui;

import haxe.ui.containers.Absolute;
import haxe.ui.data.ArrayDataSource;
import org.flashbacks1998.newgrounds.Newgrounds;

/*
 * Root is Absolute (not VBox) so the scene's runtime .left/.top/.width/.height
 * on this component behave the same as SettingsTabs — VBox as a root doesn't
 * honor .left the way Absolute does inside an Absolute parent. Inside this
 * Absolute, a filling VBox handles the vertical header+body layout.
 */
@:xml('
    <absolute>
        <vbox left="0" top="0" width="100%" height="100%" styleNames="window">
            <hbox id="titleBar" width="100%" styleNames="window-header">
                <label
                    id="titleLabel"
                    text="High Scores"
                    width="100%"
                    styleNames="window-title" />
                <button
                    id="closeButton"
                    text="X"
                    styleNames="settings-close" />
            </hbox>

            <vbox width="100%" height="100%" styleNames="window-body">
                <vbox id="statusBox" width="100%" styleNames="settings-row highscores-status-box">
                    <label id="statusText" text="Loading..." styleNames="highscores-status" />
                    <label id="subStatusText" text="Fetching leaderboard..." styleNames="highscores-substatus" />
                </vbox>

                <hbox id="boardBox" width="100%" height="100%" styleNames="highscores-board-box">
                    <tableview id="tv1" width="100%" height="100%" contentWidth="100%" styleNames="highscores-table">
                        <header width="100%">
                            <column id="usernames" text="Usernames" width="55%" />
                            <column id="highscore" text="High Score" width="45%" />
                        </header>
                        <data>
                            <item usernames="Loading..." highscore="-" />
                        </data>
                    </tableview>
                </hbox>
            </vbox>
        </vbox>
    </absolute>
')
class HighScoresWindow extends Absolute {
    public dynamic function onClose():Void {}

    public function new() {
        super();

        closeButton.onClick = _ -> {
            if (onClose != null) {
                onClose();
            } else {
                hide();
            }
        };

        showLoading("Loading...", "Fetching leaderboard...");
        boardBox.hide();

        update();
    }

    public function update() {
        showLoading("Loading...", "Fetching leaderboard...");
        boardBox.hide();

        Newgrounds.requestHighScores(
            10,
            scores -> {
                final ds = new ArrayDataSource<Dynamic>();

                if (scores == null || scores.length == 0) {
                    ds.add({
                        usernames: "(no scores yet)",
                        highscore: "-"
                    });
                } else { 
                    for (s in scores) {
                        final name = (s.user != null) ? s.user.name : "Unknown";
                        ds.add({
                            usernames: name,
                            highscore: s.formattedValue
                        });
                    }
                }

                tv1.dataSource = ds;
                showBoard();
            },
            error -> {
                showError("Error:", error);
            }
        );
    }

    private function showLoading(status:String, ?substatus:String) {
        statusText.text = status;
        subStatusText.text = substatus != null ? substatus : "";

        statusText.styleNames = "highscores-status";
        subStatusText.styleNames = "highscores-substatus";

        statusBox.show();
    }

    private function showError(status:String, reason:String) {
        statusText.text = status;
        subStatusText.text = reason;

        statusText.styleNames = "highscores-status highscores-status-error";
        subStatusText.styleNames = "highscores-substatus highscores-substatus-error";

        statusBox.show();
        boardBox.hide();
    }

    private function showBoard() {
        statusBox.hide();
        boardBox.show();
    }
}