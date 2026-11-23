# Typing cadence

[Dhakal et al., CHI 2018](https://research.aalto.fi/en/publications/observations-on-typing-from-136-million-keystrokes/) measured intervals, key-down duration, overlap and corrections across 168,960 volunteers. The study found wide differences between typists and effects from the particular letter pair. It also reports that substitutions account for many errors among slower typists.

[Fuchs and Krivokapić, Frontiers in Psychology 2016](https://doi.org/10.3389/fpsyg.2016.01678) measured longer pauses at stronger linguistic boundaries during an email-writing task. The app assigns extra time at word, sentence and paragraph boundaries. These are tendencies. The paper studies composition, and the app is transferring a fixed transcript.

The app schedules document edits using variable intervals, short runs of faster or slower edits, and optional adjacent-letter corrections. These are heuristics inspired by the studies. Word receives automation events, which contain document edits instead of physical key-down and key-up timing.

The conventional five-character word defines the WPM target. The timing budget covers scripted pauses and optional corrections. Word's response speed, especially on long documents and at high WPM, can lower the achieved speed.
