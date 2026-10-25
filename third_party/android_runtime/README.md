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

## Kotlin JDK 7 compatibility component

The locked `audioplayers_android` 5.2.1 plugin requests
`org.jetbrains.kotlin:kotlin-stdlib-jdk7:1.7.10`. Gradle's
`releaseRuntimeClasspath` resolves it to `1.8.0` under the constraint from
`kotlin-stdlib:2.2.20`, so the exported graph includes
`org.jetbrains.kotlin:kotlin-stdlib-jdk7:1.8.0`. Its published
[Maven Central POM](https://repo.maven.apache.org/maven2/org/jetbrains/kotlin/kotlin-stdlib-jdk7/1.8.0/kotlin-stdlib-jdk7-1.8.0.pom)
declares The Apache License, Version 2.0. Keep this resolved coordinate in the
manifest and generated notices; the graph comparison remains required in CI.

To inspect the dependency path:

```text
android/gradlew -p android :app:dependencyInsight --dependency kotlin-stdlib-jdk7 --configuration releaseRuntimeClasspath
```
