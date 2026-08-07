# ============================================================
# THIX ID — Règles ProGuard/R8
# ============================================================

# ML Kit Text Recognition — options de langue (chargées dynamiquement,
# non détectées automatiquement par R8)
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

-keep class com.google.mlkit.vision.text.chinese.** { *; }
-keep class com.google.mlkit.vision.text.devanagari.** { *; }
-keep class com.google.mlkit.vision.text.japanese.** { *; }
-keep class com.google.mlkit.vision.text.korean.** { *; }

# ML Kit — classes génériques (précaution pour d'autres modules ML Kit
# comme genai_image_description, barcode, face, etc.)
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# Google Play Core (requis par certains plugins Flutter en mode release)
-dontwarn com.google.android.play.core.**
