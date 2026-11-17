#!/usr/bin/env python3
"""Source of truth for the v1 drawings.

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


def content_json():
    def audio(stem):
        return {"en": f"{stem}_en.m4a", "ar": f"{stem}_ar.m4a"}

    return {
        "version": 1,
        "categories": [
            {"id": "fruits", "nameAudio": audio("category_fruits")},
            {"id": "vegetables", "nameAudio": audio("category_vegetables")},
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
    print(f"Wrote {len(ITEMS)} drawings and content.json")


if __name__ == "__main__":
    main()
