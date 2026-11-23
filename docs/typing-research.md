# Typing cadence

[Dhakal et al., CHI 2018](https://research.aalto.fi/en/publications/observations-on-typing-from-136-million-keystrokes/) measured intervals, key-down duration, overlap and corrections across 168,960 volunteers. The study found wide differences between typists and effects from the particular letter pair. It also reports that substitutions account for many errors among slower typists.

[Michel Lange et al., Frontiers in Psychology 2016](https://pmc.ncbi.nlm.nih.gov/articles/PMC5116534/) measured longer pauses at stronger linguistic boundaries during an email-writing task. The app assigns extra time at word, sentence and paragraph boundaries. These are tendencies. The paper studies composition, and the app is transferring a fixed transcript.

The app schedules document edits using variable intervals, short runs of faster or slower edits, and optional adjacent-letter corrections. The implementation uses heuristics inspired by the studies. It has no biometric target or universal human cadence. Background Word edits are Apple events and can be distinguished from physical keyboard input. They do not have key-down duration or key overlap.

The conventional five-character word defines the WPM target. The timing budget covers scripted pauses and optional corrections. Word's response speed, especially on long documents and at high WPM, can lower the achieved speed.
