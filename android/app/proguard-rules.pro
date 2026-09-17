# CBTipul release R8 rules.
# Prefer dependency consumer rules; only keep what reflection/serialization needs.

# --- kotlinx.serialization ---
# Serializers are looked up by generated companion/INSTANCE members. Without
# these keeps, Json.decodeFromString/encodeToString fails at runtime for
# Supabase/AI/cache DTOs annotated with @Serializable.
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.AnnotationsKt

-keepclassmembers class kotlinx.serialization.json.** {
    *** Companion;
}
-keepclasseswithmembers class kotlinx.serialization.json.** {
    kotlinx.serialization.KSerializer serializer(...);
}

-if @kotlinx.serialization.Serializable class **
-keepclassmembers class <1> {
    static <1>$Companion Companion;
}

-if @kotlinx.serialization.Serializable class ** {
    static **$* *;
}
-keepclassmembers class <2>$<3> {
    kotlinx.serialization.KSerializer serializer(...);
}

-if @kotlinx.serialization.Serializable class ** {
    public static ** INSTANCE;
}
-keepclassmembers class <1> {
    public static <1> INSTANCE;
    kotlinx.serialization.KSerializer serializer(...);
}

# Custom DatabaseIdSerializer is referenced from @Serializable(with = ...).
-keep class com.cbtipul.app.model.DatabaseIdSerializer { *; }

# Stack traces in Play Console / crash reporting.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# Tink (via security-crypto) references optional Error Prone annotations at
# compile time only; they are not on the runtime classpath.
-dontwarn com.google.errorprone.annotations.CanIgnoreReturnValue
-dontwarn com.google.errorprone.annotations.CheckReturnValue
-dontwarn com.google.errorprone.annotations.Immutable
-dontwarn com.google.errorprone.annotations.RestrictedApi
