# Emberwatch 0.3.1 playtest

This is a feedback build, not a finished release. Start with one mission; continue through the campaign if you want to test the full progression. No account is needed and nothing is uploaded automatically.

## Start here

On Android, open `Emberwatch-0.3.1-debug.apk` and allow installation from the app you used to download it if prompted. With USB debugging configured, use `adb install -r Emberwatch-0.3.1-debug.apk`. Keep an existing installation rather than uninstalling if testing saved-progress compatibility.

For desktop source review, extract the entire source ZIP and open `project.godot` in Godot 4.7 stable. Press F5. iPhone testing requires the separate Mac/Xcode handoff; the APK cannot run on iPhone.

## First mission: clarity and feel

Play once without reading a strategy walkthrough. Note where the game leaves you unsure what to do. Your archer moves with the stick and attacks automatically. Gold must be collected before it can be spent; nearby plots offer construction and upgrades. Only archer kills earn hero XP. Volley unlocks at level 2.

Report whether movement, gold collection, building costs, wall behavior, Smith upgrades and Volley are understandable. Note any idle stretches, purchases that feel useless, difficulty spikes or moments that feel satisfying. A loss is useful evidence; do not change the game files to make a run pass.

## Campaign progression

| Mission | Attempts | Win/loss | Battle time | Keep remaining | What helped or frustrated you? |
| --- | --- | --- | --- | --- | --- |
| Briarwood Crossing | | | | | |
| Amberfield Road | | | | | |
| Stonegate March | | | | | |
| Sunscar Bend | | | | | |
| Moonfen Causeway | | | | | |
| Emberfall Watch | | | | | |

Record the displayed results. In Sunscar, note your choice of Mine or Smith; in Moonfen, note whether the second Mine is worthwhile. After a victory, check the next mission unlocks and your best time appears on its campaign card. Replay an earlier mission and confirm a worse result does not replace the best stars/time.

## Phone checks

During a busy wave, hold movement while building or using Volley. Pause, switch apps, return and resume: held touches should clear. Return to the title, close and reopen the app, choose Continue defense and confirm it opens paused with the saved battle. Abrupt termination may lose actions since the last checkpoint (up to roughly five seconds), so record how you closed the app.

Try larger controls, reduced motion and sound off/on. Note clipped or overlapping text, blocked buttons, missed taps, stutter and noticeable heat during a longer session. Android Back should pause play, leave overlays one step at a time, and exit from the title.

## Send back

Copy this short report with your observations:

- Build: 0.3.1 (4)
- Phone/model and OS version, or desktop OS:
- New install or updated from 0.3.0:
- Missions played and results:
- Most confusing moment:
- Too easy, too hard or too slow, and where:
- Any stuck controls, save problems, crashes or heat:
- Exact steps to reproduce a problem:
- What you would most want improved:

These observations guide tuning. Automated winning playthroughs establish possible winning paths; they cannot establish how enjoyable or readable the game is for a new player.
