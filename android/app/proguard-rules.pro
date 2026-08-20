# WorkManager 2.7 creates its Room-generated database implementation by
# reflection during androidx.startup initialization. Keep the implementation
# name and its no-argument constructor in minified release builds.
-keep class androidx.work.impl.WorkDatabase_Impl {
    <init>();
}
