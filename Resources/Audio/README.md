# Audio files

Voice lines are **not bundled yet**. Drop real recordings here using exactly these names.
Until a file exists, debug builds speak the text with `AVSpeechSynthesizer` as a development
fallback only; **release builds stay silent for missing files** (see `AudioCatalog` in `Core/Services/AudioService.swift`).

- Format: AAC `.m4a`, mono, 44.1 kHz, peak around -3 dB, trimmed silence.
- File names must be unique across folders (Xcode copies them flat into the app bundle).
- This list is generated from `content.json` by `scripts/drawings.py`'s data; keep them in sync.

Sound effects (`sfx_tap.m4a`, `sfx_pop.m4a`, `sfx_sparkle.m4a`, `sfx_cheer.m4a`, `sfx_crayon_loop.m4a`)
and music (`music_loop.m4a`) go in `Audio/` root.

| File | Says |
|---|---|
| `en/category_fruits_en.m4a` | Category name: fruits |
| `ar/category_fruits_ar.m4a` | Category name: fruits |
| `en/category_vegetables_en.m4a` | Category name: vegetables |
| `ar/category_vegetables_ar.m4a` | Category name: vegetables |
| `en/apple_en.m4a` | Apple |
| `en/apple_sentence_en.m4a` | Apples can be red! |
| `ar/apple_ar.m4a` | تفاحة |
| `ar/apple_sentence_ar.m4a` | التفاح يمكن أن يكون أحمر! |
| `en/banana_en.m4a` | Banana |
| `en/banana_sentence_en.m4a` | Bananas are yellow! |
| `ar/banana_ar.m4a` | موزة |
| `ar/banana_sentence_ar.m4a` | الموز لونه أصفر! |
| `en/orange_en.m4a` | Orange |
| `en/orange_sentence_en.m4a` | Oranges are orange! |
| `ar/orange_ar.m4a` | برتقالة |
| `ar/orange_sentence_ar.m4a` | البرتقال لونه برتقالي! |
| `en/strawberry_en.m4a` | Strawberry |
| `en/strawberry_sentence_en.m4a` | Strawberries are red! |
| `ar/strawberry_ar.m4a` | فراولة |
| `ar/strawberry_sentence_ar.m4a` | الفراولة لونها أحمر! |
| `en/grapes_en.m4a` | Grapes |
| `en/grapes_sentence_en.m4a` | Grapes can be purple! |
| `ar/grapes_ar.m4a` | عنب |
| `ar/grapes_sentence_ar.m4a` | العنب يمكن أن يكون بنفسجيًا! |
| `en/watermelon_en.m4a` | Watermelon |
| `en/watermelon_sentence_en.m4a` | Watermelons are red inside! |
| `ar/watermelon_ar.m4a` | بطيخ |
| `ar/watermelon_sentence_ar.m4a` | البطيخ أحمر من الداخل! |
| `en/pear_en.m4a` | Pear |
| `en/pear_sentence_en.m4a` | Pears can be green! |
| `ar/pear_ar.m4a` | كمثرى |
| `ar/pear_sentence_ar.m4a` | الكمثرى يمكن أن تكون خضراء! |
| `en/cherry_en.m4a` | Cherry |
| `en/cherry_sentence_en.m4a` | Cherries are red! |
| `ar/cherry_ar.m4a` | كرز |
| `ar/cherry_sentence_ar.m4a` | الكرز لونه أحمر! |
| `en/pineapple_en.m4a` | Pineapple |
| `en/pineapple_sentence_en.m4a` | Pineapples are yellow! |
| `ar/pineapple_ar.m4a` | أناناس |
| `ar/pineapple_sentence_ar.m4a` | الأناناس لونه أصفر! |
| `en/mango_en.m4a` | Mango |
| `en/mango_sentence_en.m4a` | Mangoes can be orange! |
| `ar/mango_ar.m4a` | مانجو |
| `ar/mango_sentence_ar.m4a` | المانجو يمكن أن يكون برتقاليًا! |
| `en/carrot_en.m4a` | Carrot |
| `en/carrot_sentence_en.m4a` | Carrots are orange! |
| `ar/carrot_ar.m4a` | جزرة |
| `ar/carrot_sentence_ar.m4a` | الجزر لونه برتقالي! |
| `en/tomato_en.m4a` | Tomato |
| `en/tomato_sentence_en.m4a` | Tomatoes are red! |
| `ar/tomato_ar.m4a` | طماطم |
| `ar/tomato_sentence_ar.m4a` | الطماطم لونها أحمر! |
| `en/broccoli_en.m4a` | Broccoli |
| `en/broccoli_sentence_en.m4a` | Broccoli is green! |
| `ar/broccoli_ar.m4a` | بروكلي |
| `ar/broccoli_sentence_ar.m4a` | البروكلي لونه أخضر! |
| `en/eggplant_en.m4a` | Eggplant |
| `en/eggplant_sentence_en.m4a` | Eggplants are purple! |
| `ar/eggplant_ar.m4a` | باذنجان |
| `ar/eggplant_sentence_ar.m4a` | الباذنجان لونه بنفسجي! |
| `en/corn_en.m4a` | Corn |
| `en/corn_sentence_en.m4a` | Corn is yellow! |
| `ar/corn_ar.m4a` | ذرة |
| `ar/corn_sentence_ar.m4a` | الذرة لونها أصفر! |
| `en/potato_en.m4a` | Potato |
| `en/potato_sentence_en.m4a` | Potatoes are brown! |
| `ar/potato_ar.m4a` | بطاطس |
| `ar/potato_sentence_ar.m4a` | البطاطس لونها بني! |
| `en/cucumber_en.m4a` | Cucumber |
| `en/cucumber_sentence_en.m4a` | Cucumbers are green! |
| `ar/cucumber_ar.m4a` | خيار |
| `ar/cucumber_sentence_ar.m4a` | الخيار لونه أخضر! |
| `en/pumpkin_en.m4a` | Pumpkin |
| `en/pumpkin_sentence_en.m4a` | Pumpkins are orange! |
| `ar/pumpkin_ar.m4a` | يقطين |
| `ar/pumpkin_sentence_ar.m4a` | اليقطين لونه برتقالي! |
| `en/onion_en.m4a` | Onion |
| `en/onion_sentence_en.m4a` | Onions can be purple! |
| `ar/onion_ar.m4a` | بصل |
| `ar/onion_sentence_ar.m4a` | البصل يمكن أن يكون بنفسجيًا! |
| `en/peas_en.m4a` | Peas |
| `en/peas_sentence_en.m4a` | Peas are green! |
| `ar/peas_ar.m4a` | بازلاء |
| `ar/peas_sentence_ar.m4a` | البازلاء لونها أخضر! |
