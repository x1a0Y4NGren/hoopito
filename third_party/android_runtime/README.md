# Android runtime dependency notices

`coordinates.txt` is the sorted release-runtime Maven graph emitted by:

```text
android/gradlew -p android :app:exportReleaseRuntimeCoordinates
```

CI compares the generated graph byte-for-byte with this file. Every listed
component is distributed under Apache License 2.0; the complete unmodified
license text is grouped into `THIRD_PARTY_NOTICES.md` by the deterministic
notice generator. Flutter engine artifacts are excluded because the Flutter SDK
license is already included there, and Flutter plugin project licenses are
collected from their Dart packages.

When the graph changes, verify the POM license metadata for every new coordinate,
update this manifest and regenerate `THIRD_PARTY_NOTICES.md`.

The notice generator emits every coordinate from this file in the Android/Maven
section; CI regenerates the file and fails if the checked-in notices differ.
The Apache-2.0 text in that section is complete, unmodified license text, not a
summary or an abridged replacement.

Removing the unused audio-player plugin also removes its Kotlin JDK 7
compatibility component from the exported runtime graph. The current graph,
rather than a historical plugin dependency, determines the coordinates and
notices retained here. CI continues to compare the complete graph.
