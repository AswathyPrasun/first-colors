#!/usr/bin/env python3
"""Source of truth for all drawings (v1 fruits/vegetables, v1.1 vehicles, pups, heroes).

Generates Resources/Drawings/<id>.svg and Resources/Content/content.json.
Run from the repo root:  python3 scripts/drawings.py

Rules (CLAUDE.md §7):
- 300x300 viewBox, 3-6 closed fillable regions with stable ids.
- Regions are listed bottom -> top; a later region covers an earlier one where they overlap.
- Face/decoration goes in <g id="details"> (circles = filled dots, paths = stroked lines).
- Never reuse a region id for a redrawn item: create a new item id (e.g. apple_v2).
"""
import json
import os

RED, ORANGE, YELLOW, GREEN = "#E53935", "#FB8C00", "#FDD835", "#43A047"
BLUE, PURPLE, PINK, BROWN = "#1E88E5", "#8E24AA", "#F06292", "#6D4C41"


def circle(cx, cy, r):
    """Closed circle as path data (two arcs)."""
    return f"M{cx - r} {cy} A{r} {r} 0 1 0 {cx + r} {cy} A{r} {r} 0 1 0 {cx - r} {cy} Z"


def face(cx, cy, s=1.0):
    """Two eyes and a smile centred on (cx, cy). s scales the whole face."""
    dx, r = 30 * s, 10 * s
    sw, sy, sq = 24 * s, 30 * s, 51 * s
    return [
        ("circle", (cx - dx, cy, r)),
        ("circle", (cx + dx, cy, r)),
        ("path", f"M{cx - sw:g} {cy + sy:g} Q{cx:g} {cy + sq:g} {cx + sw:g} {cy + sy:g}"),
    ]


ITEMS = [
    # ---------------- Fruits ----------------
    dict(
        id="apple", category="fruits",
        name=("Apple", "تفاحة"), sentence=("Apples can be red!", "التفاح يمكن أن يكون أحمر!"),
        regions=[
            ("body", [RED, GREEN, YELLOW],
             "M150 96 C120 72 54 75 51 144 C45 216 99 270 150 255 C201 270 255 216 249 144 C246 75 180 72 150 96 Z"),
            ("stem", [BROWN], "M144 99 L147 48 L162 48 L159 99 Z"),
            ("leaf", [GREEN], "M159 69 C174 36 216 33 231 45 C219 75 186 84 159 69 Z"),
        ],
        details=[("circle", (120, 162, 10)), ("circle", (180, 162, 10)),
                 ("path", "M126 192 Q150 213 174 192")],
    ),
    dict(
        id="banana", category="fruits",
        name=("Banana", "موزة"), sentence=("Bananas are yellow!", "الموز لونه أصفر!"),
        regions=[
            ("body", [YELLOW, GREEN],
             "M70 78 C40 190 130 285 245 236 C262 228 260 206 242 204 C160 220 100 160 120 78 Z"),
            ("stem", [BROWN, GREEN], "M76 84 L76 40 L102 36 L114 84 Z"),
            ("tip", [BROWN], "M238 202 C254 196 274 204 276 220 C278 236 262 244 244 238 Z"),
        ],
        details=face(130, 196, 0.7),
    ),
    dict(
        id="orange", category="fruits",
        name=("Orange", "برتقالة"), sentence=("Oranges are orange!", "البرتقال لونه برتقالي!"),
        regions=[
            ("body", [ORANGE, YELLOW], circle(150, 170, 105)),
            ("stem", [BROWN], "M141 72 L143 28 L159 28 L161 72 Z"),
            ("leaf", [GREEN], "M156 50 C172 16 222 14 244 28 C226 62 184 70 156 50 Z"),
        ],
        details=face(150, 168),
    ),
    dict(
        id="strawberry", category="fruits",
        name=("Strawberry", "فراولة"), sentence=("Strawberries are red!", "الفراولة لونها أحمر!"),
        regions=[
            ("body", [RED, PINK],
             "M150 282 C88 252 40 180 54 124 C64 84 116 78 150 92 C184 78 236 84 246 124 C260 180 212 252 150 282 Z"),
            ("stem", [GREEN, BROWN], "M143 74 L145 30 L161 30 L159 74 Z"),
            ("leaves", [GREEN],
             "M70 104 C92 76 118 80 128 92 L150 58 L172 92 C182 80 208 76 230 104 "
             "C206 118 180 112 168 108 L150 126 L132 108 C120 112 94 118 70 104 Z"),
        ],
        details=face(150, 172, 0.9) + [
            ("circle", (96, 150, 4.5)), ("circle", (204, 150, 4.5)),
            ("circle", (112, 222, 4.5)), ("circle", (188, 222, 4.5)), ("circle", (150, 250, 4.5)),
        ],
    ),
    dict(
        id="grapes", category="fruits",
        name=("Grapes", "عنب"), sentence=("Grapes can be purple!", "العنب يمكن أن يكون بنفسجيًا!"),
        regions=[
            ("stem", [BROWN, GREEN], "M143 96 L139 40 L157 40 L159 96 Z"),
            ("leaf", [GREEN], "M156 62 C176 24 228 22 252 38 C232 72 186 80 156 62 Z"),
            ("topRow", [PURPLE, GREEN],
             circle(88, 122, 36) + " " + circle(150, 122, 36) + " " + circle(212, 122, 36)),
            ("middleRow", [PURPLE, GREEN], circle(119, 188, 36) + " " + circle(181, 188, 36)),
            ("bottom", [PURPLE, GREEN], circle(150, 252, 36)),
        ],
        details=face(150, 248, 0.45) + face(119, 184, 0.45) + face(181, 184, 0.45),
    ),
    dict(
        id="watermelon", category="fruits",
        name=("Watermelon", "بطيخ"), sentence=("Watermelons are red inside!", "البطيخ أحمر من الداخل!"),
        regions=[
            ("rind", [GREEN],
             "M14 100 L36 100 A114 114 0 0 0 264 100 L286 100 A136 136 0 0 1 14 100 Z"),
            ("whiteRind", [YELLOW, GREEN],
             "M36 100 L58 100 A92 92 0 0 0 242 100 L264 100 A114 114 0 0 1 36 100 Z"),
            ("flesh", [RED, PINK], "M58 100 L242 100 A92 92 0 0 1 58 100 Z"),
        ],
        details=face(150, 124, 0.7) + [
            ("ellipse", (96, 124, 4, 7)), ("ellipse", (204, 124, 4, 7)),
            ("ellipse", (118, 164, 4, 7)), ("ellipse", (182, 164, 4, 7)),
        ],
    ),
    dict(
        id="pear", category="fruits",
        name=("Pear", "كمثرى"), sentence=("Pears can be green!", "الكمثرى يمكن أن تكون خضراء!"),
        regions=[
            ("body", [GREEN, YELLOW],
             "M150 62 C116 62 108 94 108 118 C108 146 58 164 58 218 C58 264 100 284 150 284 "
             "C200 284 242 264 242 218 C242 164 192 146 192 118 C192 94 184 62 150 62 Z"),
            ("stem", [BROWN], "M142 66 L138 22 L156 22 L160 66 Z"),
            ("leaf", [GREEN], "M156 44 C176 12 222 10 244 24 C226 56 184 62 156 44 Z"),
        ],
        details=face(150, 204),
    ),
    dict(
        id="cherry", category="fruits",
        name=("Cherry", "كرز"), sentence=("Cherries are red!", "الكرز لونه أحمر!"),
        regions=[
            ("stems", [GREEN, BROWN],
             "M84 170 L146 46 L172 46 L224 170 L204 176 L158 74 L104 176 Z"),
            ("leaf", [GREEN], "M168 54 C190 18 242 16 266 32 C244 68 198 76 168 54 Z"),
            ("leftCherry", [RED], circle(90, 218, 58)),
            ("rightCherry", [RED], circle(212, 218, 58)),
        ],
        details=face(90, 214, 0.65) + face(212, 214, 0.65),
    ),
    dict(
        id="pineapple", category="fruits",
        name=("Pineapple", "أناناس"), sentence=("Pineapples are yellow!", "الأناناس لونه أصفر!"),
        regions=[
            ("leftLeaf", [GREEN], "M126 118 C100 100 74 74 64 40 C100 48 126 70 146 104 Z"),
            ("rightLeaf", [GREEN], "M174 118 C200 100 226 74 236 40 C200 48 174 70 154 104 Z"),
            ("middleLeaf", [GREEN], "M124 116 C120 74 134 38 150 12 C166 38 180 74 176 116 Z"),
            ("body", [YELLOW, ORANGE, BROWN],
             "M72 200 C72 140 108 108 150 108 C192 108 228 140 228 200 C228 256 194 288 150 288 "
             "C106 288 72 256 72 200 Z"),
        ],
        details=face(150, 196, 0.85) + [
            ("path", "M92 156 L112 140"), ("path", "M188 140 L208 156"),
            ("path", "M84 236 L106 254"), ("path", "M194 254 L216 236"),
            ("path", "M128 270 L150 280 L172 270"),
        ],
    ),
    dict(
        id="mango", category="fruits",
        name=("Mango", "مانجو"), sentence=("Mangoes can be orange!", "المانجو يمكن أن يكون برتقاليًا!"),
        regions=[
            ("body", [ORANGE, YELLOW, RED, GREEN],
             "M140 74 C214 62 270 120 262 190 C254 254 188 288 126 272 C78 260 50 222 62 188 "
             "C72 162 98 156 96 128 C94 100 106 80 140 74 Z"),
            ("stem", [BROWN], "M128 80 L120 42 L138 38 L146 78 Z"),
            ("leaf", [GREEN], "M136 54 C156 18 208 12 234 26 C214 62 166 72 136 54 Z"),
        ],
        details=face(172, 186, 0.9),
    ),
    # ---------------- Vegetables ----------------
    dict(
        id="carrot", category="vegetables",
        name=("Carrot", "جزرة"), sentence=("Carrots are orange!", "الجزر لونه برتقالي!"),
        regions=[
            ("leftLeaf", [GREEN], "M118 96 C94 66 82 40 90 14 C118 28 136 58 142 92 Z"),
            ("rightLeaf", [GREEN], "M158 92 C164 58 182 28 210 14 C218 40 206 66 182 96 Z"),
            ("middleLeaf", [GREEN], "M136 94 C130 60 136 34 150 6 C164 34 170 60 164 94 Z"),
            ("body", [ORANGE],
             "M90 104 C90 82 210 82 210 104 C210 156 174 252 150 288 C126 252 90 156 90 104 Z"),
        ],
        details=face(150, 140, 0.8) + [
            ("path", "M110 212 L130 214"), ("path", "M168 196 L188 194"), ("path", "M136 250 L150 252"),
        ],
    ),
    dict(
        id="tomato", category="vegetables",
        name=("Tomato", "طماطم"), sentence=("Tomatoes are red!", "الطماطم لونها أحمر!"),
        regions=[
            ("body", [RED, ORANGE, YELLOW, GREEN],
             "M150 86 C226 86 266 136 263 188 C259 248 210 278 150 278 C90 278 41 248 37 188 "
             "C34 136 74 86 150 86 Z"),
            ("stem", [GREEN, BROWN], "M142 82 L140 34 L158 34 L158 82 Z"),
            ("leaves", [GREEN],
             "M150 70 L170 94 L214 88 L186 112 L204 136 L164 122 L150 144 L136 122 L96 136 "
             "L114 112 L86 88 L130 94 Z"),
        ],
        details=face(150, 190),
    ),
    dict(
        id="broccoli", category="vegetables",
        name=("Broccoli", "بروكلي"), sentence=("Broccoli is green!", "البروكلي لونه أخضر!"),
        regions=[
            ("stalk", [GREEN, YELLOW], "M116 150 L184 150 L194 272 C172 286 128 286 106 272 Z"),
            ("leftTop", [GREEN], circle(88, 132, 60)),
            ("rightTop", [GREEN], circle(212, 132, 60)),
            ("middleTop", [GREEN], circle(150, 100, 70)),
        ],
        details=face(150, 214, 0.6),
    ),
    dict(
        id="eggplant", category="vegetables",
        name=("Eggplant", "باذنجان"), sentence=("Eggplants are purple!", "الباذنجان لونه بنفسجي!"),
        regions=[
            ("body", [PURPLE],
             "M150 88 C108 88 98 122 92 152 C78 222 92 284 150 286 C208 284 222 222 208 152 "
             "C202 122 192 88 150 88 Z"),
            ("stem", [GREEN, BROWN], "M141 92 L139 34 L159 34 L159 92 Z"),
            ("cap", [GREEN],
             "M92 112 C110 80 190 80 208 112 L184 106 L172 136 L150 108 L128 136 L116 106 Z"),
        ],
        details=face(150, 196),
    ),
    dict(
        id="corn", category="vegetables",
        name=("Corn", "ذرة"), sentence=("Corn is yellow!", "الذرة لونها أصفر!"),
        regions=[
            ("cob", [YELLOW, ORANGE],
             "M150 22 C186 22 204 80 204 140 C204 200 186 258 150 258 C114 258 96 200 96 140 "
             "C96 80 114 22 150 22 Z"),
            ("leftHusk", [GREEN], "M150 290 C82 276 46 196 60 108 C88 166 118 214 150 240 Z"),
            ("rightHusk", [GREEN], "M150 290 C218 276 254 196 240 108 C212 166 182 214 150 240 Z"),
        ],
        details=face(150, 142, 0.75) + [
            ("path", "M120 64 L180 64"), ("path", "M110 94 L190 94"),
            ("path", "M130 40 L130 106"), ("path", "M150 30 L150 106"), ("path", "M170 40 L170 106"),
        ],
    ),
    dict(
        id="potato", category="vegetables",
        name=("Potato", "بطاطس"), sentence=("Potatoes are brown!", "البطاطس لونها بني!"),
        regions=[
            ("body", [BROWN, YELLOW, ORANGE],
             "M150 76 C222 70 268 118 264 176 C260 242 204 274 144 272 C82 270 34 236 36 174 "
             "C38 112 82 80 150 76 Z"),
            ("leftSpot", [BROWN], "M60 150 A24 18 0 1 0 108 150 A24 18 0 1 0 60 150 Z"),
            ("rightSpot", [BROWN], "M196 222 A22 16 0 1 0 240 222 A22 16 0 1 0 196 222 Z"),
        ],
        details=face(158, 168),
    ),
    dict(
        id="cucumber", category="vegetables",
        name=("Cucumber", "خيار"), sentence=("Cucumbers are green!", "الخيار لونه أخضر!"),
        regions=[
            ("body", [GREEN, YELLOW],
             "M48 196 C10 234 66 290 104 252 L252 104 C290 66 234 10 196 48 Z"),
            ("leaf", [GREEN], "M226 70 C238 30 274 16 290 22 C288 52 262 82 226 70 Z"),
            ("flower", [YELLOW, ORANGE],
             "M48 244 C30 228 22 252 34 262 C18 268 26 292 44 282 C46 298 70 296 66 278 "
             "C84 284 92 262 74 254 C88 240 70 224 58 238 C56 222 40 224 48 244 Z"),
        ],
        details=face(150, 148, 0.7) + [("circle", (50, 260, 5))],
    ),
    dict(
        id="pumpkin", category="vegetables",
        name=("Pumpkin", "يقطين"), sentence=("Pumpkins are orange!", "اليقطين لونه برتقالي!"),
        regions=[
            ("leftSide", [ORANGE, YELLOW], "M108 104 C30 104 28 284 108 284 C150 284 150 104 108 104 Z"),
            ("rightSide", [ORANGE, YELLOW], "M192 104 C270 104 272 284 192 284 C150 284 150 104 192 104 Z"),
            ("stem", [BROWN, GREEN], "M136 108 C136 86 132 68 124 52 L152 44 C160 66 164 88 164 108 Z"),
            ("leaf", [GREEN], "M162 74 C182 42 230 40 252 56 C232 88 188 94 162 74 Z"),
            ("middle", [ORANGE, YELLOW], "M150 98 C82 98 82 290 150 290 C218 290 218 98 150 98 Z"),
        ],
        details=face(150, 188, 0.85),
    ),
    dict(
        id="onion", category="vegetables",
        name=("Onion", "بصل"), sentence=("Onions can be purple!", "البصل يمكن أن يكون بنفسجيًا!"),
        regions=[
            ("roots", [BROWN, YELLOW], "M110 256 C108 282 128 292 150 292 C172 292 192 282 190 256 Z"),
            ("leftShoot", [GREEN], "M140 84 C124 56 112 34 92 16 C124 18 148 44 156 76 Z"),
            ("rightShoot", [GREEN], "M146 76 C156 44 178 20 210 14 C192 36 174 58 164 86 Z"),
            ("bulb", [PURPLE, YELLOW, BROWN],
             "M150 62 C164 104 256 128 252 198 C248 250 202 272 150 272 C98 272 52 250 48 198 "
             "C44 128 136 104 150 62 Z"),
        ],
        details=face(150, 190, 0.85) + [
            ("path", "M92 150 C76 188 82 230 110 258"), ("path", "M208 150 C224 188 218 230 190 258"),
            ("path", "M132 278 L130 286"), ("path", "M150 280 L150 288"), ("path", "M168 278 L170 286"),
        ],
    ),
    dict(
        id="peas", category="vegetables",
        name=("Peas", "بازلاء"), sentence=("Peas are green!", "البازلاء لونها أخضر!"),
        regions=[
            ("stem", [GREEN, BROWN], "M248 132 C262 112 266 88 256 70 L274 64 C288 88 282 118 264 142 Z"),
            ("pod", [GREEN],
             "M20 168 C46 96 236 82 270 132 C252 222 66 246 20 168 Z"),
            ("leftPea", [GREEN, YELLOW], circle(84, 168, 34)),
            ("middlePea", [GREEN, YELLOW], circle(152, 160, 34)),
            ("rightPea", [GREEN, YELLOW], circle(218, 152, 32)),
        ],
        details=face(84, 164, 0.4) + face(152, 156, 0.4) + face(218, 148, 0.4),
    ),
]

# ===================== v1.1: Vehicles, Rescue Pups, Super Kids =====================
# Original characters only (CLAUDE.md §2.9): no franchise names, looks, badges or emblems.
# All multi-part shapes are drawn clockwise so overlapping parts merge; a hole is drawn
# counter-clockwise (oval(..., hole=True)).

SKY, GRAY = "#81D4FA", "#78909C"


def oval(cx, cy, rx, ry=None, hole=False):
    """Closed ellipse, clockwise on screen (counter-clockwise when hole=True)."""
    ry = rx if ry is None else ry
    sweep = 0 if hole else 1
    return (f"M{cx - rx:g} {cy:g} A{rx:g} {ry:g} 0 1 {sweep} {cx + rx:g} {cy:g} "
            f"A{rx:g} {ry:g} 0 1 {sweep} {cx - rx:g} {cy:g} Z")


def rrect(x, y, w, h, r):
    """Rounded rectangle, clockwise."""
    return (f"M{x + r:g} {y:g} L{x + w - r:g} {y:g} Q{x + w:g} {y:g} {x + w:g} {y + r:g} "
            f"L{x + w:g} {y + h - r:g} Q{x + w:g} {y + h:g} {x + w - r:g} {y + h:g} "
            f"L{x + r:g} {y + h:g} Q{x:g} {y + h:g} {x:g} {y + h - r:g} "
            f"L{x:g} {y + r:g} Q{x:g} {y:g} {x + r:g} {y:g} Z")


def star(cx, cy, outer, inner):
    """Five-pointed star, point up."""
    import math
    points = []
    for k in range(10):
        radius = outer if k % 2 == 0 else inner
        angle = -math.pi / 2 + k * math.pi / 5
        points.append((cx + radius * math.cos(angle), cy + radius * math.sin(angle)))
    return "M" + " L".join(f"{x:.1f} {y:.1f}" for x, y in points) + " Z"


def hubs(*centers):
    return [("circle", (x, y, 9)) for x, y in centers]


# ---------------- Rescue Pups template ----------------
PUP_EARS = {
    # Long ears hanging beside the head.
    "floppy": "M94 98 C60 92 36 132 44 180 C48 204 72 208 86 188 L104 120 Z "
              "M206 98 C240 92 264 132 256 180 C252 204 228 208 214 188 L196 120 Z",
    # Upright pointed ears (husky / shepherd types).
    "pointy": "M84 118 L44 46 L124 84 Z M176 84 L256 46 L216 118 Z",
    # Short ears folded out sideways (bulldog type).
    "folded": "M86 120 C54 106 30 122 36 148 C40 166 62 166 80 150 Z "
              "M214 120 C246 106 270 122 264 148 C260 166 238 166 220 150 Z",
}
PUP_FUR = oval(150, 140, 78, 66) + " M80 292 C80 226 110 200 150 200 C190 200 220 226 220 292 Z"
VEST = "M98 292 L98 238 C112 224 130 218 150 218 C170 218 188 224 202 238 L202 292 Z"


def pup_face(cy=136):
    return [("circle", (122, cy, 9)), ("circle", (178, cy, 9)),
            ("ellipse", (150, cy + 24, 14, 10)),
            ("path", f"M128 {cy + 36} Q139 {cy + 48} 150 {cy + 38} Q161 {cy + 48} 172 {cy + 36}")]


# ---------------- Super Kids template ----------------
HERO_CAPE = "M104 150 C84 200 64 246 50 284 C110 272 190 272 250 284 C236 246 216 200 196 150 Z"
HERO_SUIT = ("M110 146 L190 146 C202 146 208 154 210 164 L226 214 C228 224 216 228 210 220 L196 196 "
             "L196 262 L104 262 L104 196 L90 220 C84 228 72 224 74 214 L90 164 C92 154 98 146 110 146 Z")
HERO_BOOTS = ("M104 250 L146 250 L146 288 L98 288 C96 270 99 258 104 250 Z "
              "M154 250 L196 250 C201 258 204 270 202 288 L154 288 Z")
HERO_FACE = oval(150, 96, 52, 50)
HERO_MASK = ("M98 92 C104 72 196 72 202 92 C206 110 190 118 172 110 C162 106 156 102 150 102 "
             "C144 102 138 106 128 110 C110 118 94 110 98 92 Z")
HERO_EYES_SMILE = [("circle", (126, 93, 8)), ("circle", (174, 93, 8)), ("path", "M130 124 Q150 138 170 124")]
SKIN = [BROWN, ORANGE, PINK]

EMBLEMS = {
    "star": star(150, 196, 30, 13),
    "heart": "M150 226 C120 206 110 190 116 178 C122 166 142 166 150 182 C158 166 178 166 184 178 "
             "C190 190 180 206 150 226 Z",
    "sun": oval(150, 196, 22),
    "moon": "M162 166 C138 166 120 184 122 204 C124 224 144 234 166 228 C146 222 138 208 140 194 "
            "C142 180 150 170 162 166 Z",
    "flower": " ".join(oval(150 + dx, 196 + dy, 13) for dx, dy in
                       [(0, -15), (14, -5), (9, 12), (-9, 12), (-14, -5)]) + " " + oval(150, 196, 10),
    "rainbow": "M112 214 C112 164 188 164 188 214 L166 214 C166 188 134 188 134 214 Z",
    "note": "M134 224 C122 224 116 216 120 208 C124 200 138 198 146 204 L146 162 L178 152 L178 172 "
            "L158 178 L158 214 C158 222 146 226 134 224 Z",
    "drop": "M150 166 C164 186 174 198 174 210 C174 224 162 232 150 232 C138 232 126 224 126 210 "
            "C126 198 136 186 150 166 Z",
    "fish": "M114 196 C128 176 160 174 178 192 L198 178 L198 214 L178 200 C160 218 128 216 114 196 Z",
    "crown": "M118 214 L118 176 L134 192 L150 170 L166 192 L182 176 L182 214 Z",
}


HERO_EXTRA = {
    "sun": [("path", "M150 164 L150 170 M150 222 L150 228 M118 196 L124 196 M176 196 L182 196 "
                     "M128 174 L132 178 M168 214 L172 218 M172 174 L168 178 M128 218 L132 214")],
    "rainbow": [("path", "M124 214 C124 178 176 178 176 214")],
}


def hero(id, name, sentence, suit, cape, emblem_shape, emblem, hair, boots=True, cloud=None, skin=0):
    regions = [("cape", cape, HERO_CAPE), ("suit", suit, HERO_SUIT)]
    if cloud:
        regions.append(("cloud", cloud,
                        "M36 268 C24 238 64 224 84 242 C94 216 140 214 152 238 C168 214 214 218 218 244 "
                        "C246 232 276 252 264 276 C254 294 56 296 36 268 Z"))
    elif boots:
        regions.append(("boots", boots, HERO_BOOTS))
    skin_order = SKIN[skin % 3:] + SKIN[:skin % 3]   # vary who Magic colors which way
    regions += [("face", skin_order, HERO_FACE), ("mask", [BLUE, PURPLE, GREEN], HERO_MASK),
                ("emblem", emblem, EMBLEMS[emblem_shape])]
    return dict(id=id, category="super_kids", name=name, sentence=sentence,
                regions=regions, details=HERO_EYES_SMILE + hair + HERO_EXTRA.get(emblem_shape, []))


HAIR = {
    "pigtails": [("path", "M104 66 C114 40 186 40 196 66"), ("path", "M100 74 C80 66 70 80 78 96"),
                 ("path", "M200 74 C220 66 230 80 222 96")],
    "short": [("path", "M106 64 C116 42 184 42 194 64"), ("path", "M132 48 L140 60 L150 46 L160 60 L168 48")],
    "curly": [("path", "M104 70 C96 56 112 44 122 52 C126 38 146 38 150 50 C156 38 176 40 178 52 "
                       "C190 44 204 56 196 70")],
    "bun": [("path", "M108 62 C120 44 180 44 192 62"), ("path", "M138 44 C136 30 164 30 162 44")],
    "spiky": [("path", "M104 66 L112 46 L126 58 L136 40 L150 56 L164 40 L174 58 L188 46 L196 66")],
}


V11_ITEMS = [
    # ---------------- Vehicles (side view, facing right) ----------------
    dict(
        id="car", category="vehicles",
        name=("Car", "سيارة"), sentence=("Cars can be red!", "السيارات يمكن أن تكون حمراء!"),
        regions=[
            ("body", [RED, BLUE, YELLOW],
             "M36 212 C24 212 22 196 24 176 C26 150 44 140 70 138 L96 92 C102 82 110 78 122 78 L186 78 "
             "C204 78 214 88 226 108 L240 138 C266 142 278 154 278 178 C278 200 272 212 260 212 Z"),
            ("window", [SKY], "M114 96 L184 96 C194 96 200 100 206 110 L220 138 L96 138 Z"),
            ("backWheel", [GRAY], oval(84, 214, 32)),
            ("frontWheel", [GRAY], oval(218, 214, 32)),
        ],
        details=face(152, 166, 0.55) + hubs((84, 214), (218, 214)) + [("circle", (264, 166, 6))],
    ),
    dict(
        id="bus", category="vehicles",
        name=("Bus", "حافلة"), sentence=("Buses can be yellow!", "الحافلات يمكن أن تكون صفراء!"),
        regions=[
            ("body", [YELLOW, ORANGE], rrect(22, 64, 256, 158, 26)),
            ("windows", [SKY], rrect(42, 84, 64, 52, 10) + " " + rrect(118, 84, 64, 52, 10)),
            ("door", [SKY, GRAY], rrect(200, 84, 56, 108, 10)),
            ("backWheel", [GRAY], oval(80, 224, 28)),
            ("frontWheel", [GRAY], oval(222, 224, 28)),
        ],
        details=face(128, 162, 0.5) + hubs((80, 224), (222, 224)) + [("path", "M228 92 L228 184")],
    ),
    dict(
        id="fire_truck", category="vehicles",
        name=("Fire truck", "سيارة إطفاء"), sentence=("Fire trucks are red!", "سيارات الإطفاء حمراء!"),
        regions=[
            ("body", [RED],
             "M20 202 L20 120 L188 120 L188 90 C188 80 194 74 204 74 L240 74 C256 74 262 84 268 100 "
             "L282 140 L282 202 Z"),
            ("ladder", [GRAY, YELLOW], rrect(28, 90, 150, 26, 8)),
            ("window", [SKY], "M204 88 L240 88 C248 88 252 94 255 102 L264 132 L204 132 Z"),
            ("backWheel", [GRAY], oval(70, 208, 30)),
            ("frontWheel", [GRAY], oval(230, 208, 30)),
        ],
        details=face(110, 152, 0.55) + hubs((70, 208), (230, 208)) + [
            ("path", "M52 90 L52 116"), ("path", "M80 90 L80 116"), ("path", "M108 90 L108 116"),
            ("path", "M136 90 L136 116"), ("path", "M164 90 L164 116"), ("circle", (270, 160, 6))],
    ),
    dict(
        id="police_car", category="vehicles",
        name=("Police car", "سيارة شرطة"),
        sentence=("Police cars can be blue!", "سيارات الشرطة يمكن أن تكون زرقاء!"),
        regions=[
            ("light", [RED, BLUE], rrect(126, 62, 56, 34, 10)),
            ("body", [BLUE],
             "M22 210 L22 168 C22 154 30 148 48 146 L92 142 L118 100 C122 94 128 92 136 92 L182 92 "
             "C190 92 196 96 200 102 L226 142 L262 146 C274 148 280 156 280 168 L280 210 Z"),
            ("window", [SKY], "M134 106 L184 106 L208 142 L112 142 Z"),
            ("backWheel", [GRAY], oval(82, 212, 30)),
            ("frontWheel", [GRAY], oval(222, 212, 30)),
        ],
        details=face(152, 166, 0.5) + hubs((82, 212), (222, 212)) + [("circle", (268, 166, 6))],
    ),
    dict(
        id="ambulance", category="vehicles",
        name=("Ambulance", "سيارة إسعاف"),
        sentence=("Ambulances help people!", "سيارات الإسعاف تساعد الناس!"),
        regions=[
            ("body", [YELLOW, RED],
             "M20 212 L20 78 C20 68 26 62 36 62 L196 62 C206 62 212 68 212 78 L212 110 L248 110 "
             "C258 110 264 116 268 126 L282 166 L282 212 Z"),
            ("window", [SKY], "M220 122 L246 122 C252 122 256 126 258 132 L268 160 L220 160 Z"),
            ("stripe", [RED, BLUE], "M20 170 L282 170 L282 190 L20 190 Z"),
            ("heart", [RED], "M90 150 C62 130 54 114 60 102 C66 90 84 90 90 104 C96 90 114 90 120 102 "
                                   "C126 114 118 130 90 150 Z"),
            ("backWheel", [GRAY], oval(72, 216, 28)),
            ("frontWheel", [GRAY], oval(232, 216, 28)),
        ],
        details=face(166, 110, 0.5) + hubs((72, 216), (232, 216)),
    ),
    dict(
        id="train", category="vehicles",
        name=("Train", "قطار"), sentence=("Trains can be green!", "القطارات يمكن أن تكون خضراء!"),
        regions=[
            ("chimney", [GRAY], "M198 122 L192 74 L240 74 L234 122 Z"),
            ("engine", [GREEN, RED], "M100 118 L252 118 C266 118 276 128 276 142 L276 204 L100 204 Z"),
            ("cab", [BLUE], "M24 204 L24 78 C24 70 30 64 38 64 L120 64 C128 64 134 70 134 78 L134 204 Z"),
            ("wheels", [GRAY], oval(70, 216, 26) + " " + oval(152, 216, 26) + " " + oval(232, 216, 26)),
        ],
        details=face(212, 156, 0.55) + hubs((70, 216), (152, 216), (232, 216)) + [
            ("path", "M48 86 L110 86 L110 132 L48 132 Z")],
    ),
    dict(
        id="airplane", category="vehicles",
        name=("Airplane", "طائرة"),
        sentence=("Airplanes fly in the blue sky!", "الطائرات تطير في السماء الزرقاء!"),
        regions=[
            ("tail", [RED, YELLOW], "M30 142 L18 70 C16 58 26 54 34 60 L100 124 Z"),
            ("body", [BLUE, RED],
             "M28 150 C28 128 50 116 80 116 L220 116 C256 116 284 134 284 152 C284 170 256 184 220 184 "
             "L80 184 C54 184 28 172 28 150 Z"),
            ("wings", [GRAY, BLUE], "M108 160 L170 160 L132 252 C128 262 112 264 108 254 Z"),
            ("windows", [SKY], oval(76, 140, 12) + " " + oval(110, 140, 12) + " " + oval(196, 140, 12)),
        ],
        details=face(246, 150, 0.45),
    ),
    dict(
        id="boat", category="vehicles",
        name=("Boat", "قارب"), sentence=("Boats float on blue water!", "القوارب تطفو على الماء الأزرق!"),
        regions=[
            ("sail", [ORANGE, YELLOW], "M160 30 L252 150 L160 150 Z"),
            ("cabin", [YELLOW], rrect(64, 106, 84, 60, 12)),
            ("hull", [RED, BLUE], "M28 158 L272 158 L240 222 L60 222 Z"),
            ("water", [BLUE, SKY],
             "M8 230 Q38 210 68 230 T128 230 T188 230 T248 230 Q270 216 292 226 L292 276 L8 276 Z"),
        ],
        details=face(150, 180, 0.55) + [("path", "M154 26 L154 158"), ("circle", (90, 130, 6)),
                                       ("circle", (122, 130, 6))],
    ),
    dict(
        id="tractor", category="vehicles",
        name=("Tractor", "جرار"), sentence=("Tractors can be green!", "الجرارات يمكن أن تكون خضراء!"),
        regions=[
            ("body", [GREEN, RED], "M24 198 L24 142 C24 132 30 126 40 126 L164 126 L164 198 Z"),
            ("cab", [YELLOW], "M150 198 L150 70 C150 62 156 56 164 56 L238 56 C246 56 252 62 252 70 L252 198 Z"),
            ("bigWheel", [GRAY], oval(206, 210, 52)),
            ("smallWheel", [GRAY], oval(76, 224, 34)),
        ],
        details=face(96, 156, 0.5) + [("circle", (206, 210, 14)), ("circle", (76, 224, 10)),
                                      ("path", "M168 74 L234 74 L234 122 L168 122 Z"),
                                      ("path", "M52 126 L52 96")],
    ),
    dict(
        id="rocket", category="vehicles",
        name=("Rocket", "صاروخ"), sentence=("Rockets have orange flames!", "الصواريخ لها نار برتقالية!"),
        regions=[
            ("flame", [ORANGE, YELLOW, RED],
             "M116 226 C116 256 134 270 150 292 C166 270 184 256 184 226 Z"),
            ("fins", [RED, ORANGE], "M102 168 L54 238 L106 228 Z M194 168 L246 238 L194 228 Z"),
            ("body", [GRAY, RED, BLUE], "M150 18 C196 50 206 120 200 232 L100 232 C94 120 104 50 150 18 Z"),
            ("window", [SKY], oval(150, 104, 28)),
        ],
        details=face(150, 168, 0.5),
    ),

    # ---------------- Rescue Pups (original characters) ----------------
    dict(
        id="fire_pup", category="rescue_pups",
        name=("Fire Pup", "جرو الإطفاء"),
        sentence=("Fire Pup has a red helmet!", "جرو الإطفاء يلبس خوذة حمراء!"),
        regions=[
            ("ears", [BROWN], PUP_EARS["floppy"]),
            ("fur", [BROWN, YELLOW, GRAY], PUP_FUR),
            ("helmet", [RED], "M86 108 C86 50 214 50 214 108 Z " + rrect(64, 100, 172, 22, 10)),
            ("vest", [YELLOW, ORANGE], VEST),
        ],
        details=pup_face() + [("path", "M150 60 L150 98"), ("path", "M98 262 L202 262")],
    ),
    dict(
        id="doctor_pup", category="rescue_pups",
        name=("Doctor Pup", "جرو الطبيب"),
        sentence=("Doctor Pup has a red bag!", "جرو الطبيب معه حقيبة حمراء!"),
        regions=[
            ("ears", [BROWN], PUP_EARS["floppy"]),
            ("fur", [YELLOW, BROWN], PUP_FUR),
            ("coat", [BLUE, GREEN], VEST),
            ("bag", [RED], rrect(186, 236, 84, 54, 10)),
        ],
        details=pup_face() + [("path", "M138 80 Q150 64 162 80"), ("path", "M150 218 L150 292"),
                              ("path", "M210 236 C210 218 246 218 246 236"),
                              ("path", "M186 256 L270 256"), ("circle", (228, 256, 6))],
    ),
    dict(
        id="builder_pup", category="rescue_pups",
        name=("Builder Pup", "جرو البناء"),
        sentence=("Builder Pup has a hard hat!", "جرو البناء يلبس خوذة البناء!"),
        regions=[
            ("ears", [BROWN, YELLOW], PUP_EARS["floppy"]),
            ("fur", [YELLOW, BROWN], PUP_FUR),
            ("hat", [ORANGE, YELLOW], "M88 108 C88 48 212 48 212 108 Z " + rrect(70, 98, 160, 20, 8)),
            ("vest", [GREEN, ORANGE], VEST),
        ],
        details=pup_face() + [("path", "M150 54 L150 98"), ("path", "M124 222 L124 292"),
                              ("path", "M176 222 L176 292")],
    ),
    dict(
        id="swim_pup", category="rescue_pups",
        name=("Swim Pup", "جرو السباحة"),
        sentence=("Swim Pup loves blue water!", "جرو السباحة يحب الماء الأزرق!"),
        regions=[
            ("ears", [BROWN], PUP_EARS["floppy"]),
            ("fur", [YELLOW, BROWN], PUP_FUR),
            ("ring", [RED, YELLOW], oval(150, 228, 62, 52) + " " + oval(150, 228, 28, 22, hole=True)),
            ("water", [BLUE],
             "M8 262 Q38 244 68 262 T128 262 T188 262 T248 262 Q270 250 292 258 L292 292 L8 292 Z"),
        ],
        details=pup_face() + [("path", "M96 204 L120 214"), ("path", "M204 204 L180 214")],
    ),
    dict(
        id="farm_pup", category="rescue_pups",
        name=("Farm Pup", "جرو المزرعة"),
        sentence=("Farm Pup has an orange carrot!", "جرو المزرعة معه جزرة برتقالية!"),
        regions=[
            ("ears", [GRAY, BROWN], PUP_EARS["floppy"]),
            ("fur", [GRAY, BROWN], PUP_FUR),
            ("hat", [YELLOW], "M106 98 C106 46 194 46 194 98 Z M52 100 C52 84 248 84 248 100 "
                              "C248 116 52 116 52 100 Z"),
            ("scarf", [RED, BLUE], "M84 206 C118 224 182 224 216 206 L218 230 C182 248 118 248 82 230 Z"),
            ("carrot", [ORANGE], "M192 288 L236 206 C244 194 266 202 260 216 Z"),
        ],
        details=pup_face() + [("path", "M246 200 L258 176"), ("path", "M252 204 L276 190"),
                              ("path", "M108 80 L192 80")],
    ),
    dict(
        id="mail_pup", category="rescue_pups",
        name=("Mail Pup", "جرو البريد"),
        sentence=("Mail Pup brings the letters!", "جرو البريد يحمل الرسائل!"),
        regions=[
            ("ears", [BROWN, GRAY], PUP_EARS["folded"]),
            ("fur", [GRAY, BROWN], PUP_FUR),
            ("cap", [GREEN, RED], "M94 104 C96 54 204 54 206 104 Z M150 96 L246 96 C258 100 258 116 244 118 "
                            "L150 116 Z"),
            ("letter", [YELLOW], rrect(198, 198, 58, 44, 4)),
            ("bag", [BROWN, RED], rrect(180, 226, 92, 64, 12)),
        ],
        details=pup_face() + [("path", "M198 200 L227 220 L256 200"), ("path", "M96 206 L184 238"),
                              ("path", "M180 252 L272 252")],
    ),
    dict(
        id="garden_pup", category="rescue_pups",
        name=("Garden Pup", "جرو الحديقة"),
        sentence=("Garden Pup waters the flowers!", "جرو الحديقة يسقي الزهور!"),
        regions=[
            ("ears", [BROWN], PUP_EARS["floppy"]),
            ("fur", [YELLOW, BROWN], PUP_FUR),
            ("can", [GREEN, BLUE], "M30 230 L104 230 L98 290 L36 290 Z M100 244 L148 214 L156 226 L104 262 Z"),
            ("flower", [RED, PURPLE, YELLOW],
             " ".join(oval(234 + dx, 242 + dy, 17) for dx, dy in
                      [(0, -20), (19, -6), (12, 16), (-12, 16), (-19, -6)])),
        ],
        details=pup_face() + [("circle", (234, 242, 9)), ("path", "M44 230 C44 206 86 206 86 230")],
    ),
    dict(
        id="snow_pup", category="rescue_pups",
        name=("Snow Pup", "جرو الثلج"),
        sentence=("Snow Pup has a warm hat!", "جرو الثلج يلبس قبعة دافئة!"),
        regions=[
            ("ears", [BROWN], PUP_EARS["floppy"]),
            ("fur", [BROWN, YELLOW], PUP_FUR),
            ("hat", [RED, BLUE], "M84 110 C84 56 216 56 216 110 Z " + oval(150, 46, 20)),
            ("scarf", [GREEN, ORANGE], "M84 206 C118 224 182 224 216 206 L218 230 C182 248 118 248 82 230 Z "
                                       "M172 232 L206 232 L200 286 L176 286 Z"),
        ],
        details=pup_face() + [("path", "M84 98 L216 98")],
    ),
    dict(
        id="chef_pup", category="rescue_pups",
        name=("Chef Pup", "جرو الطاهي"),
        sentence=("Chef Pup made a cupcake!", "جرو الطاهي صنع كعكة صغيرة!"),
        regions=[
            ("ears", [BROWN], PUP_EARS["floppy"]),
            ("fur", [BROWN, YELLOW], PUP_FUR),
            ("hat", [GRAY, BLUE],
             "M96 104 L96 80 C68 76 64 38 98 38 C104 12 150 6 160 30 C178 8 228 20 214 52 "
             "C238 60 232 86 204 82 L204 104 Z"),
            ("apron", [BLUE, GREEN], VEST),
            ("cupcake", [PURPLE, RED],
             "M120 252 L180 252 L172 290 L128 290 Z M110 256 C106 222 194 222 190 256 Z"),
        ],
        details=pup_face() + [("circle", (150, 220, 8)), ("path", "M138 256 L136 288"),
                              ("path", "M162 256 L164 288")],
    ),
    dict(
        id="pilot_pup", category="rescue_pups",
        name=("Pilot Pup", "جرو الطيار"),
        sentence=("Pilot Pup flies a red plane!", "جرو الطيار يقود طائرة حمراء!"),
        regions=[
            ("ears", [BROWN], PUP_EARS["floppy"]),
            ("fur", [YELLOW, BROWN], PUP_FUR),
            ("goggles", [BLUE, GREEN], oval(122, 96, 20) + " " + oval(178, 96, 20)),
            ("plane", [RED, ORANGE], oval(150, 252, 114, 40)),
            ("wing", [GRAY, BLUE], rrect(14, 240, 272, 24, 12)),
        ],
        details=pup_face() + [("path", "M142 96 L158 96"), ("path", "M150 212 L150 232")],
    ),

    # ---------------- Super Kids (original characters) ----------------
    hero("little_star", ("Little Star", "النجمة الصغيرة"),
         ("Little Star has a yellow star!", "النجمة الصغيرة معها نجمة صفراء!"),
         suit=[PURPLE, BLUE], cape=[PINK, RED], emblem_shape="star", emblem=[YELLOW],
         hair=HAIR["pigtails"], boots=[YELLOW, PINK]),
    hero("heart_boy", ("Heart Boy", "فتى القلب"), ("Heart Boy has a red heart!", "فتى القلب معه قلب أحمر!"),
         suit=[GREEN, BLUE], cape=[RED], emblem_shape="heart", emblem=[RED, PINK],
         hair=HAIR["short"], boots=[YELLOW], skin=1),
    hero("sun_hero", ("Sun Hero", "بطل الشمس"), ("Sun Hero is bright yellow!", "بطل الشمس أصفر لامع!"),
         suit=[ORANGE, YELLOW], cape=[RED], emblem_shape="sun", emblem=[YELLOW],
         hair=HAIR["spiky"], boots=[ORANGE, RED], skin=2),
    hero("moon_hero", ("Moon Hero", "بطل القمر"), ("Moon Hero has a yellow moon!", "بطل القمر معه قمر أصفر!"),
         suit=[BLUE, PURPLE], cape=[PURPLE], emblem_shape="moon", emblem=[YELLOW],
         hair=HAIR["bun"], boots=[BLUE, PURPLE]),
    hero("cloud_kid", ("Cloud Kid", "طفل الغيمة"),
         ("Cloud Kid rides a fluffy cloud!", "طفل الغيمة يركب غيمة ناعمة!"),
         suit=[BLUE, GREEN], cape=[PINK], emblem_shape="drop", emblem=[BLUE],
         hair=HAIR["curly"], cloud=[PURPLE, PINK, BLUE], skin=1),
    hero("flower_hero", ("Flower Hero", "بطل الزهرة"), ("Flower Hero loves flowers!", "بطل الزهرة يحب الزهور!"),
         suit=[GREEN], cape=[PINK, PURPLE], emblem_shape="flower", emblem=[YELLOW, RED, PINK],
         hair=HAIR["pigtails"], boots=[GREEN, YELLOW], skin=2),
    hero("rainbow_hero", ("Rainbow Hero", "بطل قوس قزح"),
         ("Rainbow Hero has every color!", "بطل قوس قزح عنده كل الألوان!"),
         suit=[BLUE], cape=[RED, ORANGE], emblem_shape="rainbow", emblem=[YELLOW, RED, GREEN],
         hair=HAIR["curly"], boots=[PURPLE, RED]),
    dict(
        id="cape_kitty", category="super_kids",
        name=("Cape Kitty", "القطة البطلة"),
        sentence=("Cape Kitty has a red cape!", "القطة البطلة تلبس رداءً أحمر!"),
        regions=[
            ("cape", [RED, BLUE], HERO_CAPE),
            ("fur", [ORANGE, YELLOW, BROWN],
             oval(150, 104, 62, 54) + " M98 76 L96 28 L136 58 Z M164 58 L204 28 L202 76 Z "
             "M100 290 C100 220 116 156 150 156 C184 156 200 220 200 290 Z"),
            ("mask", [PURPLE, BLUE], "M96 98 C102 78 198 78 204 98 C208 116 192 122 174 116 "
                                     "C162 112 156 108 150 108 C144 108 138 112 126 116 C108 122 92 116 96 98 Z"),
            ("emblem", [YELLOW], EMBLEMS["fish"]),
        ],
        details=[("circle", (126, 99, 8)), ("circle", (174, 99, 8)), ("path", "M144 126 L156 126 L150 134 Z"),
                 ("path", "M150 134 Q140 146 130 138 M150 134 Q160 146 170 138"),
                 ("path", "M92 128 L120 132 M90 142 L120 140 M208 128 L180 132 M210 142 L180 140"),
                 ("path", "M124 290 L124 262 M176 290 L176 262")],
    ),
    dict(
        id="hero_bear", category="super_kids",
        name=("Hero Bear", "الدب البطل"),
        sentence=("Hero Bear has a yellow belt!", "الدب البطل يلبس حزامًا أصفر!"),
        regions=[
            ("cape", [BLUE, GREEN], HERO_CAPE),
            ("fur", [BROWN, ORANGE, YELLOW],
             oval(100, 58, 24) + " " + oval(200, 58, 24) + " " + oval(150, 108, 64, 56) +
             " M100 290 C100 220 116 160 150 160 C184 160 200 220 200 290 Z"),
            ("emblem", [RED, YELLOW], EMBLEMS["crown"]),
            ("belt", [YELLOW], "M102 234 L198 234 L200 256 L100 256 Z"),
        ],
        details=[("circle", (126, 98, 8)), ("circle", (174, 98, 8)),
                 ("path", oval(150, 128, 24, 18)), ("ellipse", (150, 122, 9, 6)),
                 ("path", "M138 136 Q150 146 162 136"), ("circle", (100, 58, 9)), ("circle", (200, 58, 9)),
                 ("path", "M124 290 L124 262 M176 290 L176 262")],
    ),
    hero("music_hero", ("Music Hero", "بطل الموسيقى"), ("Music Hero loves to sing!", "بطل الموسيقى يحب الغناء!"),
         suit=[PINK, PURPLE], cape=[BLUE], emblem_shape="note", emblem=[YELLOW],
         hair=HAIR["bun"], boots=[RED], skin=1),
]

ITEMS += V11_ITEMS


def svg_for(item):
    lines = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        f'<!-- {item["id"]}: generated by scripts/drawings.py. Edit there, not here. -->',
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 300" width="300" height="300"',
        '     fill="#FFFFFF" stroke="#1F1F1F" stroke-width="6.5" stroke-linejoin="round" stroke-linecap="round">',
    ]
    for rid, _, d in item["regions"]:
        lines.append(f'  <path id="{rid}" d="{d}"/>')
    lines.append('  <g id="details" fill="#1F1F1F" stroke="#1F1F1F" stroke-width="5.5">')
    for kind, value in item["details"]:
        if kind == "circle":
            cx, cy, r = value
            lines.append(f'    <circle cx="{cx:g}" cy="{cy:g}" r="{r:g}" stroke="none"/>')
        elif kind == "ellipse":
            cx, cy, rx, ry = value
            lines.append(f'    <ellipse cx="{cx:g}" cy="{cy:g}" rx="{rx:g}" ry="{ry:g}" stroke="none"/>')
        else:
            lines.append(f'    <path d="{value}" fill="none"/>')
    lines.append("  </g>")
    lines.append("</svg>")
    return "\n".join(lines) + "\n"


# Spoken category names (must match `CategoryDetails.spokenName` in the app).
CATEGORIES = [
    ("fruits", "Fruits", "فواكه"),
    ("vegetables", "Veggies", "خضروات"),
    ("vehicles", "Vehicles", "مركبات"),
    ("rescue_pups", "Rescue Pups", "جراء الإنقاذ"),
    ("super_kids", "Super Kids", "الأبطال الصغار"),
]

# Short sounds for finishing a picture, by category (synthesized by scripts/make_sounds.py).
CATEGORY_SOUNDS = {"vehicles": "sfx_vroom", "rescue_pups": "sfx_woof", "super_kids": "sfx_whoosh"}


def voice_readme():
    rows = []
    for cid, en, ar in CATEGORIES:
        rows.append(f"| `en/category_{cid}_en.m4a` | {en} |")
        rows.append(f"| `ar/category_{cid}_ar.m4a` | {ar} |")
    for item in ITEMS:
        i = item["id"]
        rows += [f"| `en/{i}_en.m4a` | {item['name'][0]} |",
                 f"| `en/{i}_sentence_en.m4a` | {item['sentence'][0]} |",
                 f"| `ar/{i}_ar.m4a` | {item['name'][1]} |",
                 f"| `ar/{i}_sentence_ar.m4a` | {item['sentence'][1]} |"]
    effects = ", ".join(f"`{n}.m4a`" for n in
                        ["sfx_tap", "sfx_pop", "sfx_sparkle", "sfx_cheer", "sfx_crayon_loop", *CATEGORY_SOUNDS.values()])
    by_category = {}
    for item in ITEMS:
        by_category.setdefault(item["category"], 0)
        by_category[item["category"]] += 1
    counts = ", ".join(f"{n} {c.replace('_', ' ')}" for c, n in by_category.items())
    return "\n".join([
        "# Audio files",
        "",
        "<!-- Generated by scripts/drawings.py. Edit the words there, not here. -->",
        "",
        "Voice lines are **not bundled yet**. Drop real recordings into `en/` and `ar/` using exactly",
        "these names. Until a file exists, debug builds speak the text with `AVSpeechSynthesizer` as a",
        "development fallback only; **release builds stay silent for missing files** (see `AudioCatalog`",
        "in `Core/Services/AudioService.swift`).",
        "",
        "- Format: AAC `.m4a`, mono, 44.1 kHz, peak around -3 dB, trimmed silence.",
        "- File names must be unique across folders (Xcode copies them flat into the app bundle).",
        "- Arabic lines need a native-speaker review before recording.",
        f"- Total: {len(rows)} voice files ({len(CATEGORIES) * 2} category names, then 4 per picture for "
        f"{len(ITEMS)} pictures: {counts}).",
        "",
        f"Sound effects ({effects}) and music (`music_loop.m4a`) are in `Audio/` root, synthesized by",
        "`scripts/make_sounds.py` (original, no licenses). No sounds or music from any TV show or film.",
        "",
        "| File | Says |",
        "|---|---|",
        *rows,
        "",
    ])


def content_json():
    def audio(stem):
        return {"en": f"{stem}_en.m4a", "ar": f"{stem}_ar.m4a"}

    return {
        "version": 1,
        "categories": [
            {"id": c, "nameAudio": audio(f"category_{c}")}
            for c, _, _ in CATEGORIES
        ],
        "items": [
            {
                "id": item["id"],
                "category": item["category"],
                "svg": f'{item["id"]}.svg',
                "name": {"en": item["name"][0], "ar": item["name"][1]},
                "colorSentence": {"en": item["sentence"][0], "ar": item["sentence"][1]},
                "nameAudio": audio(item["id"]),
                "colorSentenceAudio": audio(f'{item["id"]}_sentence'),
                "regions": [{"id": rid, "suggested": sug} for rid, sug, _ in item["regions"]],
            }
            for item in ITEMS
        ],
    }


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    drawings = os.path.join(root, "Resources", "Drawings")
    os.makedirs(drawings, exist_ok=True)
    for item in ITEMS:
        with open(os.path.join(drawings, f'{item["id"]}.svg'), "w", encoding="utf-8") as f:
            f.write(svg_for(item))
    with open(os.path.join(root, "Resources", "Content", "content.json"), "w", encoding="utf-8") as f:
        json.dump(content_json(), f, ensure_ascii=False, indent=2)
        f.write("\n")
    with open(os.path.join(root, "Resources", "Audio", "README.md"), "w", encoding="utf-8") as f:
        f.write(voice_readme())
    print(f"Wrote {len(ITEMS)} drawings and content.json")


if __name__ == "__main__":
    main()
