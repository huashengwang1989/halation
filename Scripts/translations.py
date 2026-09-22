# -*- coding: utf-8 -*-
"""Source of truth for UI translations.

Keys are semantic, not English text, so a word can differ by context — a "Rate"
button and a rate measurement are not the same word in most languages.

Technical terms stay in English on purpose: model names, bfloat16, ComfyUI, MLX,
HEVC, LoRA, VAE, seed values. Translating them would make the app harder to use,
not easier, because that is how the surrounding ecosystem names them.

Run Scripts/build_strings.py to regenerate the .lproj files.
"""

# The languages the app ships. Adding one means adding it here and then filling
# it in wherever it is ready — every other language keeps working meanwhile,
# because anything absent falls back to English when the files are built.
#
# Order matters only for presentation: it sets the column order in
# Debug ▸ Localisations (i18n).
LANGS = ["en", "zh-Hant", "zh-Hans", "de", "ar", "ja", "ko", "th",
         "yue-Hant", "en-SG"]

SOURCE_LANG = "en"

# Note levels, shown in Debug ▸ Localisations (i18n):
#
#   info     context a translator needs — which sense of an ambiguous word is
#            meant, and where it appears. Short strings are the ones that need
#            it: "Working" beside the runtime state means "not broken", not "in
#            progress", and a translator cannot see the screen. Where two keys
#            share their English, each note says which is which, so a developer
#            reusing one because the English matched is warned.
#
#   warning  the key is translatable into the languages shipped today, but the
#            *way* it is built will not survive some language we may add. Three
#            causes account for all of them: a count where the language needs
#            more plural forms than English has; a noun injected into a sentence
#            whose surrounding words must agree with it; and a sentence
#            assembled from fragments in Swift, which nobody can reorder. A
#            warning is not a bug report — the notes say where something is
#            genuinely broken today and where it is merely waiting to be.
INFO = "info"
WARNING = "warning"

T = {}


def add(key, values, note=None):
    """Define a key.

    `values` is keyed by language, and only SOURCE_LANG is required:

        add("common.save", {"en": "Save", "de": "Sichern"})

    A language that is missing or not yet approved falls back to English when
    the .strings files are built. That is the point of the shape. A new language
    can be added to LANGS and filled in a screen at a time, and a translation
    can be held back without blocking anything. It also means the order of the
    languages stops mattering: the positional form this replaced needed all four
    hundred calls edited to add a sixth language, and a value in the wrong
    position was a silent mistranslation rather than an error.

    `note` is for whoever translates this — a plain string, which is info level:

        note="Imperative verb on a button, not the noun."

    or a dict when it needs to say more:

        note={"content": "Takes a count …", "level": WARNING}

    The dict is what to extend if notes ever need another field — a maximum
    display width, say, or a reference screenshot — without touching the call
    sites that do not need it.
    """
    if SOURCE_LANG not in values or not values[SOURCE_LANG]:
        raise ValueError(f"{key}: {SOURCE_LANG!r} is required")
    unknown = set(values) - set(LANGS)
    if unknown:
        raise ValueError(f"{key}: not a language in LANGS: {sorted(unknown)}")
    if key in T:
        raise ValueError(f"{key}: defined twice")

    if note is None:
        note = {"content": "", "level": INFO}
    elif isinstance(note, str):
        note = {"content": note, "level": INFO}
    elif isinstance(note, dict):
        if "content" not in note:
            raise ValueError(f"{key}: a note dict needs a 'content' key")
        note = {"content": note["content"], "level": note.get("level", INFO)}
    else:
        raise TypeError(f"{key}: note must be a string or a dict")
    if note["level"] not in (INFO, WARNING):
        raise ValueError(f"{key}: unknown note level {note['level']!r}")

    T[key] = {"values": dict(values), "note": note}


def value(key, lang):
    """The translation, falling back to English where one is not ready."""
    values = T[key]["values"]
    return values.get(lang) or values[SOURCE_LANG]


def note_of(key):
    """(content, level). Content is "" when the key has no note."""
    note = T[key]["note"]
    return note["content"], note["level"]


# ── Navigation ───────────────────────────────────────────────────────────────
add("section.compose", {
    "en": "Compose",
    "zh-Hant": "編寫",
    "zh-Hans": "编写",
    "de": "Erstellen",
    "ar": "إنشاء",
    "ja": "作成",
    "ko": "작성",
    "th": "เรียบเรียง",
    "yue-Hant": "編寫",
    "en-SG": "New Video",
}, note="The Compose tab: the screen where a render is set up. Not the verb. Distinct "
        "from settings.remember.section, which is the name of a group of settings "
        "*about* that screen.")
add("section.queue", {
    "en": "Queue",
    "zh-Hant": "佇列",
    "zh-Hans": "队列",
    "de": "Warteschlange",
    "ar": "قائمة الانتظار",
    "ja": "キュー",
    "ko": "대기열",
    "th": "คิว",
    "yue-Hant": "佇列",
    "en-SG": "Queue",
})
add("section.library", {
    "en": "Library",
    "zh-Hant": "媒體庫",
    "zh-Hans": "媒体库",
    "de": "Mediathek",
    "ar": "المكتبة",
    "ja": "ライブラリ",
    "ko": "라이브러리",
    "th": "คลัง",
    "yue-Hant": "媒體庫",
    "en-SG": "My Videos",
}, note="Collection of finished videos — not a code library.")
add("section.models", {
    "en": "Models",
    "zh-Hant": "模型",
    "zh-Hans": "模型",
    "de": "Modelle",
    "ar": "النماذج",
    "ja": "モデル",
    "ko": "모델",
    "th": "โมเดล",
    "yue-Hant": "模型",
    "en-SG": "Models",
}, note="The Models tab in the sidebar. Distinct from settings.folder.models (a "
        "folder on disk) and summary.models (the weights a particular render will "
        "load).")

# ── Status bar ───────────────────────────────────────────────────────────────
add("status.ready", {
    "en": "Ready",
    "zh-Hant": "就緒",
    "zh-Hans": "就绪",
    "de": "Bereit",
    "ar": "جاهز",
    "ja": "準備完了",
    "ko": "준비됨",
    "th": "พร้อม",
    "yue-Hant": "Ready",
    "en-SG": "Can Already",
})
add("status.checking", {
    "en": "Checking…",
    "zh-Hant": "檢查中…",
    "zh-Hans": "检查中…",
    "de": "Wird geprüft …",
    "ar": "جارٍ التحقق…",
    "ja": "確認中…",
    "ko": "확인 중…",
    "th": "กำลังตรวจสอบ…",
    "yue-Hant": "查緊…",
    "en-SG": "Checking…",
})
add("status.runtime.incomplete", {
    "en": "Runtime incomplete",
    "zh-Hant": "執行環境不完整",
    "zh-Hans": "运行环境不完整",
    "de": "Laufzeitumgebung unvollständig",
    "ar": "بيئة التشغيل غير مكتملة",
    "ja": "実行環境が不完全",
    "ko": "런타임 불완전",
    "th": "Runtime ไม่สมบูรณ์",
    "yue-Hant": "執行環境唔齊",
    "en-SG": "Runtime not complete",
})
add("status.runtime.error", {
    "en": "Runtime error",
    "zh-Hant": "執行環境錯誤",
    "zh-Hans": "运行环境错误",
    "de": "Laufzeitfehler",
    "ar": "خطأ في بيئة التشغيل",
    "ja": "実行環境のエラー",
    "ko": "런타임 오류",
    "th": "Runtime ผิดพลาด",
    "yue-Hant": "執行環境出錯",
    "en-SG": "Runtime got error",
})
add("status.runtime.missing", {
    "en": "Runtime not installed",
    "zh-Hant": "尚未安裝執行環境",
    "zh-Hans": "尚未安装运行环境",
    "de": "Laufzeitumgebung nicht installiert",
    "ar": "بيئة التشغيل غير مثبتة",
    "ja": "実行環境が未インストール",
    "ko": "런타임 미설치",
    "th": "ยังไม่ได้ติดตั้ง runtime",
    "yue-Hant": "仲未裝執行環境",
    "en-SG": "Runtime never install",
})
add("status.queued.count", {
    "en": "%@ queued",
    "zh-Hant": "佇列中 %@",
    "zh-Hans": "队列中 %@",
    "de": "%@ in Warteschlange",
    "ar": "%@ في قائمة الانتظار",
    "ja": "%@ 件待機中",
    "ko": "%@ 개 대기 중",
    "th": "%@ รายการในคิว",
    "yue-Hant": "佇列中 %@",
    "en-SG": "%@ in queue",
}, note={
    "content": "Takes a count of queued jobs. Safer than the other counts because no noun "
               "follows the number in English, but languages that inflect the verb or add a "
               "classifier still need the count itself.",
    "level": WARNING,
})
add("status.label", {
    "en": "Status",
    "zh-Hant": "狀態",
    "zh-Hans": "状态",
    "de": "Status",
    "ar": "الحالة",
    "ja": "状態",
    "ko": "상태",
    "th": "สถานะ",
    "yue-Hant": "狀態",
    "en-SG": "Status",
}, note="Labels the health indicator in the status bar along the bottom of the "
        "window. Distinct from settings.status, which heads a whole section, and from "
        "settings.state.")
add("status.step", {
    "en": "step %1$@/%2$@",
    "zh-Hant": "步驟 %1$@/%2$@",
    "zh-Hans": "步骤 %1$@/%2$@",
    "de": "Schritt %1$@/%2$@",
    "ar": "الخطوة %1$@/%2$@",
    "ja": "ステップ %1$@/%2$@",
    "ko": "스텝 %1$@/%2$@",
    "th": "step %1$@/%2$@",
    "yue-Hant": "步 %1$@/%2$@",
    "en-SG": "step %1$@/%2$@",
}, note={
    "content": "Positional, so the two numbers can be reordered — Arabic in particular may want "
               "the total first. Still a warning because it is joined to status.remaining with \" "
               "· \" in StatusBar: the halves are translated separately and assembled in a fixed "
               "order, which no translator can change.",
    "level": WARNING,
})
add("status.remaining", {
    "en": "%@ left",
    "zh-Hant": "剩餘 %@",
    "zh-Hans": "剩余 %@",
    "de": "noch %@",
    "ar": "%@ متبقٍ",
    "ja": "残り %@",
    "ko": "%@ 남음",
    "th": "เหลือ %@",
    "yue-Hant": "仲爭 %@",
    "en-SG": "%@ more",
}, note={
    "content": "Joined to status.step with \" · \" in StatusBar, so the two halves are translated "
               "apart and assembled in a fixed order. The duration inside is already localized.",
    "level": WARNING,
})

# ── Built-in presets ─────────────────────────────────────────────────────────
# Named for what they are for, not for a setting: "Fast preview" is a draft you
# look at, not a speed. Translations follow the purpose rather than the words.
add("preset.fastPreview", {
    "en": "Fast preview",
    "zh-Hant": "快速預覽",
    "zh-Hans": "快速预览",
    "de": "Schnelle Vorschau",
    "ar": "معاينة سريعة",
    "ja": "高速プレビュー",
    "ko": "빠른 미리보기",
    "th": "พรีวิวเร็ว",
    "yue-Hant": "快手預覽",
    "en-SG": "Fast Look-See",
})
add("preset.quality", {
    "en": "Quality — overnight",
    "zh-Hant": "高品質——整夜算圖",
    "zh-Hans": "高质量——整夜渲染",
    "de": "Hohe Qualität – über Nacht",
    "ar": "جودة عالية — طوال الليل",
    "ja": "高品質 — 一晩",
    "ko": "고품질 — 밤새",
    "th": "คุณภาพสูง — ข้ามคืน",
    "yue-Hant": "靚仔——過夜算",
    "en-SG": "Best quality — overnight one",
})
add("preset.vertical", {
    "en": "Vertical social",
    "zh-Hant": "直式社群影片",
    "zh-Hans": "竖屏社交视频",
    "de": "Hochformat für Social Media",
    "ar": "فيديو رأسي للتواصل الاجتماعي",
    "ja": "縦型 SNS",
    "ko": "세로형 소셜",
    "th": "แนวตั้งสำหรับโซเชียล",
    "yue-Hant": "直度社交片",
    "en-SG": "Tall One For Social",
})

# ── Settings: language ───────────────────────────────────────────────────────
# The English name rides along in every language. Someone who switches to a
# script they cannot read has to be able to find their way back, and "Language"
# is the one label that has to stay recognisable for that to work.
add("settings.language.section", {
    "en": "Language",
    "zh-Hant": "語言 (Language)",
    "zh-Hans": "语言 (Language)",
    "de": "Sprache (Language)",
    "ar": "اللغة ⁨(Language)⁩",
    "ja": "言語",
    "ko": "언어",
    "th": "ภาษา",
    "yue-Hant": "語言 (Language)",
    "en-SG": "Language",
})
add("settings.language.label", {
    "en": "Interface language",
    "zh-Hant": "介面語言 (Interface Language)",
    "zh-Hans": "界面语言 (Interface Language)",
    "de": "Sprache der Benutzeroberfläche (Interface Language)",
    "ar": "لغة الواجهة ⁨(Interface Language)⁩",
    "ja": "表示言語",
    "ko": "인터페이스 언어",
    "th": "ภาษาของส่วนติดต่อ",
    "yue-Hant": "介面語言 (Interface Language)",
    "en-SG": "Interface language",
})
add("settings.language.system", {
    "en": "Follow system (%@)",
    "zh-Hant": "跟隨系統（%@）",
    "zh-Hans": "跟随系统（%@）",
    "de": "Systemsprache (%@)",
    "ar": "اتّباع النظام (%@)",
    "ja": "システムに合わせる（%@）",
    "ko": "시스템 설정에 따름(%@)",
    "th": "ตามระบบ (%@)",
    "yue-Hant": "跟系統（%@）",
    "en-SG": "Follow system (%@)",
})

# Two notes, chosen by whether the writing direction actually changes. Telling
# someone moving between two left-to-right languages about mirroring only
# invents a worry; most people have never needed the word.
add("settings.language.restart", {
    "en": "Text changes immediately. The menu bar at the top of the screen follows when you "
          "restart the app.",
    "zh-Hant": "文字會立即切換。畫面上方的選單列則需重新啟動 App 後才會跟著改變。",
    "zh-Hans": "文字会立即切换。屏幕顶部的菜单栏需重新启动 App 后才会跟着改变。",
    "de": "Texte wechseln sofort. Die Menüleiste am oberen Bildschirmrand folgt, sobald Sie "
          "die App neu starten.",
    "ar": "تتغيّر النصوص فورًا. أمّا شريط القوائم أعلى الشاشة فيتبعها عند إعادة تشغيل "
          "التطبيق.",
    "ja": "文言はすぐ切り替わります。画面上部のメニューバーはアプリを再起動すると追随します。",
    "ko": "본문은 즉시 바뀝니다. 화면 위쪽 메뉴 막대는 앱을 다시 실행하면 따라갑니다.",
    "th": "ข้อความเปลี่ยนทันที ส่วนแถบเมนูด้านบนจอจะเปลี่ยนตามเมื่อเปิดแอปใหม่",
    "yue-Hant": "啲字即刻轉。畫面頂嗰條選單列就要重開 App 先跟住轉。",
    "en-SG": "The words change straight away. The menu bar on top only follow after you restart the app.",
})
add("settings.language.restart.direction", {
    "en": "Text changes immediately. This language reads in the other direction, so the "
          "window swaps sides to match — that, and the menu bar at the top of the screen, "
          "follow when you restart the app.",
    "zh-Hant": "文字會立即切換。此語言的閱讀方向相反，因此整個視窗的左右會對調——這項變更與畫面上方的選單列，都需重新啟動 App 後才會套用。",
    "zh-Hans": "文字会立即切换。此语言的阅读方向相反，因此整个窗口的左右会对调——这项变更与屏幕顶部的菜单栏，都需重新启动 App 后才会生效。",
    "de": "Texte wechseln sofort. Diese Sprache wird in der anderen Richtung gelesen, daher "
          "tauscht das Fenster die Seiten. Das und die Menüleiste am oberen Bildschirmrand "
          "folgen, sobald Sie die App neu starten.",
    "ar": "تتغيّر النصوص فورًا. تُقرأ هذه اللغة في الاتجاه المعاكس، لذا تتبادل عناصر "
          "النافذة جانبيها. يحدث ذلك، مع شريط القوائم أعلى الشاشة، عند إعادة تشغيل التطبيق.",
    "ja": "文言はすぐ切り替わります。この言語は書字方向が逆なので、ウィンドウの左右も入れ替わります。それと画面上部のメニューバーは、アプリを再起動すると追随します。",
    "ko": "본문은 즉시 바뀝니다. 이 언어는 읽는 방향이 반대라 창의 좌우도 뒤바뀝니다. 그 점과 화면 위쪽 메뉴 막대는 앱을 다시 실행하면 따라갑니다.",
    "th": "ข้อความเปลี่ยนทันที ภาษานี้อ่านจากอีกทิศทางหนึ่ง หน้าต่างจึงสลับด้านให้เข้ากัน ทั้งสองอย่างนี้และแถบเมนูด้านบนจอจะเปลี่ยนตามเมื่อเปิดแอปใหม่",
    "yue-Hant": "啲字即刻轉。呢隻語言由另一邊讀起，所以成個視窗會左右調轉——呢樣同畫面頂嗰條選單列，都要重開 App 先套用。",
    "en-SG": "The words change straight away. This language reads from the other side, so the whole window swap sides to match — that one, and the menu bar on top, only follow after you restart the app.",
})
add("settings.language.relaunch", {
    "en": "Relaunch now",
    "zh-Hant": "立即重新啟動",
    "zh-Hans": "立即重新启动",
    "de": "Jetzt neu starten",
    "ar": "أعِد التشغيل الآن",
    "ja": "今すぐ再起動",
    "ko": "지금 다시 실행",
    "th": "เปิดใหม่ตอนนี้",
    "yue-Hant": "即刻重開",
    "en-SG": "Restart now",
})

# ── Generation modes ─────────────────────────────────────────────────────────
# TW and CN diverge on core vocabulary: 影片/视频 for video, 影格/帧 for frame,
# 解析度/分辨率 for resolution, 預設/默认 for default. Applied throughout.
add("mode.t2v", {
    "en": "Text to video",
    "zh-Hant": "文字轉影片",
    "zh-Hans": "文字转视频",
    "de": "Text zu Video",
    "ar": "نص إلى فيديو",
    "ja": "テキストから動画",
    "ko": "텍스트로 비디오",
    "th": "ข้อความเป็นวิดีโอ",
    "yue-Hant": "文字轉片",
    "en-SG": "Text to video",
})
add("mode.first", {
    "en": "First frame",
    "zh-Hant": "首格",
    "zh-Hans": "首帧",
    "de": "Erstes Bild",
    "ar": "الإطار الأول",
    "ja": "先頭フレーム",
    "ko": "첫 프레임",
    "th": "เฟรมแรก",
    "yue-Hant": "首格",
    "en-SG": "First frame",
}, note="The name of the first-frame mode in the mode picker: the render continues "
        "from a supplied image. Distinct from refs.slot.first, which labels the slot "
        "that image goes in.")
add("mode.firstlast", {
    "en": "First & last frame",
    "zh-Hant": "首尾格",
    "zh-Hans": "首尾帧",
    "de": "Erstes & letztes Bild",
    "ar": "الإطار الأول والأخير",
    "ja": "先頭と末尾のフレーム",
    "ko": "첫 프레임과 마지막 프레임",
    "th": "เฟรมแรกและเฟรมสุดท้าย",
    "yue-Hant": "首尾格",
    "en-SG": "First & last frame",
})
add("mode.reference", {
    "en": "References",
    "zh-Hant": "參考素材",
    "zh-Hans": "参考素材",
    "de": "Referenzen",
    "ar": "مراجع",
    "ja": "参考素材",
    "ko": "참조 자료",
    "th": "ไฟล์อ้างอิง",
    "yue-Hant": "參考素材",
    "en-SG": "References",
}, note="The name of the reference mode in the mode picker — the mode that conditions "
        "on supplied images or video. Distinct from refs.title.references, which "
        "heads the list of the files themselves.")
add("mode.t2v.detail", {
    "en": "Generate purely from a written description.",
    "zh-Hant": "僅依文字描述生成。",
    "zh-Hans": "仅依文字描述生成。",
    "de": "Ausschließlich aus einer Beschreibung erzeugen.",
    "ar": "التوليد من وصف نصي فقط.",
    "ja": "文章による説明だけから生成します。",
    "ko": "글로 쓴 설명만으로 생성합니다.",
    "th": "สร้างจากคำบรรยายที่เขียนเพียงอย่างเดียว",
    "yue-Hant": "淨係靠文字描述生成。",
    "en-SG": "Generate from your written description only.",
})
add("mode.first.detail", {
    "en": "Animate outward from a still image you supply.",
    "zh-Hant": "以你提供的靜態圖片為起點延伸動態。",
    "zh-Hans": "以你提供的静态图片为起点延伸动态。",
    "de": "Ausgehend von einem Standbild animieren.",
    "ar": "تحريك انطلاقًا من صورة ثابتة تقدّمها.",
    "ja": "用意した静止画から動きを広げていきます。",
    "ko": "제공한 정지 이미지에서 바깥으로 움직임을 만듭니다.",
    "th": "สร้างการเคลื่อนไหวต่อจากภาพนิ่งที่คุณใส่",
    "yue-Hant": "由你俾嘅一張靜態圖開始郁。",
    "en-SG": "Start from one still image you give, then let it move.",
})
add("mode.firstlast.detail", {
    "en": "Supply both ends of the shot; the model fills in the motion between them.",
    "zh-Hant": "提供鏡頭的起點與終點，模型補出中間的動態。",
    "zh-Hans": "提供镜头的起点与终点，模型补出中间的动态。",
    "de": "Beide Enden der Einstellung vorgeben; das Modell erzeugt die Bewegung "
          "dazwischen.",
    "ar": "قدّم بداية اللقطة ونهايتها، ويولّد النموذج الحركة بينهما.",
    "ja": "ショットの両端を指定すると、モデルがその間の動きを補います。",
    "ko": "장면의 양 끝을 제공하면 모델이 그 사이의 움직임을 채웁니다.",
    "th": "ใส่ภาพทั้งต้นและท้ายช็อต แล้วโมเดลจะเติมการเคลื่อนไหวระหว่างกลางให้",
    "yue-Hant": "俾鏡頭嘅頭同尾，中間嘅郁動由個模型補。",
    "en-SG": "Give the start and the end, the model fill in the middle movement.",
})
add("mode.reference.detail", {
    "en": "Supply reference images, clips or audio to pin down a subject, style or voice.",
    "zh-Hant": "提供參考圖片、片段或音訊，用來固定主體、風格或聲音。",
    "zh-Hans": "提供参考图片、片段或音频，用来固定主体、风格或声音。",
    "de": "Referenzbilder, -clips oder -audio vorgeben, um Motiv, Stil oder Stimme "
          "festzulegen.",
    "ar": "قدّم صورًا أو مقاطع أو أصواتًا مرجعية لتثبيت الموضوع أو الأسلوب أو الصوت.",
    "ja": "参考画像・クリップ・音声を渡して、被写体やスタイル、声を固定します。",
    "ko": "참조 이미지, 클립, 오디오를 제공해 인물, 스타일, 목소리를 고정합니다.",
    "th": "ใส่ภาพ คลิป หรือเสียงอ้างอิง เพื่อกำหนดตัวแบบ สไตล์ หรือน้ำเสียง",
    "yue-Hant": "俾參考圖片、片段或者聲，用嚟定住個主體、風格或者把聲。",
    "en-SG": "Give reference images, clips or audio, then it will lock down the subject, style or voice for you.",
})

# ── Job states ───────────────────────────────────────────────────────────────
add("state.queued", {
    "en": "Queued",
    "zh-Hant": "等待中",
    "zh-Hans": "等待中",
    "de": "In Warteschlange",
    "ar": "في الانتظار",
    "ja": "待機中",
    "ko": "대기 중",
    "th": "อยู่ในคิว",
    "yue-Hant": "排緊隊",
    "en-SG": "Waiting Turn",
})
add("state.preparing", {
    "en": "Loading model",
    "zh-Hant": "載入模型中",
    "zh-Hans": "加载模型中",
    "de": "Modell wird geladen",
    "ar": "جارٍ تحميل النموذج",
    "ja": "モデルを読み込み中",
    "ko": "모델 불러오는 중",
    "th": "กำลังโหลดโมเดล",
    "yue-Hant": "載入緊模型",
    "en-SG": "Loading model",
})
add("state.generating", {
    "en": "Generating",
    "zh-Hant": "生成中",
    "zh-Hans": "生成中",
    "de": "Wird erzeugt",
    "ar": "جارٍ التوليد",
    "ja": "生成中",
    "ko": "생성 중",
    "th": "กำลังสร้าง",
    "yue-Hant": "生成緊",
    "en-SG": "Generating",
})
add("state.decoding", {
    "en": "Decoding",
    "zh-Hant": "解碼中",
    "zh-Hans": "解码中",
    "de": "Wird dekodiert",
    "ar": "جارٍ فك الترميز",
    "ja": "デコード中",
    "ko": "디코딩 중",
    "th": "กำลังถอดรหัส",
    "yue-Hant": "解碼緊",
    "en-SG": "Decoding",
})
add("state.encoding", {
    "en": "Encoding",
    "zh-Hant": "編碼中",
    "zh-Hans": "编码中",
    "de": "Wird kodiert",
    "ar": "جارٍ الترميز",
    "ja": "エンコード中",
    "ko": "인코딩 중",
    "th": "กำลังเข้ารหัส",
    "yue-Hant": "編碼緊",
    "en-SG": "Encoding",
})
add("state.finished", {
    "en": "Finished",
    "zh-Hant": "已完成",
    "zh-Hans": "已完成",
    "de": "Fertig",
    "ar": "اكتمل",
    "ja": "完了",
    "ko": "완료",
    "th": "เสร็จแล้ว",
    "yue-Hant": "搞掂",
    "en-SG": "Done liao",
})
add("state.failed", {
    "en": "Failed",
    "zh-Hant": "失敗",
    "zh-Hans": "失败",
    "de": "Fehlgeschlagen",
    "ar": "فشل",
    "ja": "失敗",
    "ko": "실패",
    "th": "ล้มเหลว",
    "yue-Hant": "失敗咗",
    "en-SG": "Fail liao",
})
add("state.cancelled", {
    "en": "Cancelled",
    "zh-Hant": "已取消",
    "zh-Hans": "已取消",
    "de": "Abgebrochen",
    "ar": "أُلغي",
    "ja": "キャンセル済み",
    "ko": "취소됨",
    "th": "ยกเลิกแล้ว",
    "yue-Hant": "取消咗",
    "en-SG": "Cancelled",
})

# ── Engines ──────────────────────────────────────────────────────────────────
# "MLX" and "ComfyUI" are product names and stay as they are.
add("backend.mlx.detail", {
    "en": "Apple's own framework, running the model natively. Text-to-video and keyframes "
          "only — the port has no reference conditioning.",
    "zh-Hant": "Apple 自家的框架，原生執行模型。僅支援文字轉影片與關鍵格，移植版沒有參考素材條件化。",
    "zh-Hans": "Apple 自家的框架，原生运行模型。仅支持文字转视频与关键帧，移植版没有参考素材条件化。",
    "de": "Apples eigenes Framework, das Modell läuft nativ. Nur Text-zu-Video und "
          "Keyframes — die Portierung kennt keine Referenzkonditionierung.",
    "ar": "إطار عمل Apple، يشغّل النموذج أصليًا. يدعم النص إلى فيديو والإطارات المفتاحية "
          "فقط، إذ لا يتضمّن النقل شرطنة المراجع.",
    "ja": "Apple 自社のフレームワークで、モデルをネイティブに実行します。テキストからの生成とキーフレームのみ対応で、移植版に参考素材の条件付けはありません。",
    "ko": "Apple 자체 프레임워크로 모델을 네이티브로 실행합니다. 텍스트-비디오와 키프레임만 지원하며, 이식판에는 참조 조건화가 없습니다.",
    "th": "เฟรมเวิร์กของ Apple เองที่รันโมเดลแบบเนทีฟ รองรับเฉพาะข้อความเป็นวิดีโอและ keyframe เพราะพอร์ตนี้ไม่มีการกำหนดเงื่อนไขจากไฟล์อ้างอิง",
    "yue-Hant": "Apple 自己嘅框架，原生咁跑個模型。淨係做到文字轉片同關鍵格——移植版冇參考素材條件化。",
    "en-SG": "Apple ownself make one, run the model natively. Text-to-video and keyframes only — this port bo reference conditioning, so don't expect.",
})
add("backend.comfy.detail", {
    "en": "PyTorch on Metal. The only backend that supports references, and the only one "
          "that can load the 4-step turbo LoRAs.",
    "zh-Hant": "以 Metal 執行 PyTorch。唯一支援參考素材的後端，也是唯一能載入 4 步 turbo LoRA 的。",
    "zh-Hans": "以 Metal 运行 PyTorch。唯一支持参考素材的后端，也是唯一能加载 4 步 turbo LoRA 的。",
    "de": "PyTorch auf Metal. Das einzige Backend mit Referenzen und das einzige, das die "
          "4-Schritt-Turbo-LoRAs laden kann.",
    "ar": "PyTorch على Metal. الواجهة الخلفية الوحيدة التي تدعم المراجع، والوحيدة القادرة "
          "على تحميل نماذج turbo LoRA ذات الأربع خطوات.",
    "ja": "Metal 上の PyTorch。参考素材に対応する唯一のバックエンドで、4 ステップの turbo LoRA を読み込めるのもこれだけです。",
    "ko": "Metal 기반 PyTorch. 참조 자료를 지원하는 유일한 백엔드이며, 4스텝 turbo LoRA를 불러올 수 있는 것도 이것뿐입니다.",
    "th": "PyTorch บน Metal เป็น backend เดียวที่รองรับไฟล์อ้างอิง และเป็นตัวเดียวที่โหลด turbo LoRA แบบ 4 step ได้",
    "yue-Hant": "喺 Metal 上面跑 PyTorch。得佢一個支援參考素材，亦都得佢載入到 4 步嘅 turbo LoRA。",
    "en-SG": "PyTorch on Metal. Only this one can do references, and only this one can load the 4-step turbo LoRA. The other one cannot.",
})

# ── Compose: buttons and chrome ──────────────────────────────────────────────
add("compose.generate", {
    "en": "Generate",
    "zh-Hant": "生成",
    "zh-Hans": "生成",
    "de": "Erzeugen",
    "ar": "توليد",
    "ja": "生成",
    "ko": "생성",
    "th": "สร้าง",
    "yue-Hant": "生成",
    "en-SG": "Generate Lah",
}, note="Imperative verb on the main action button: start the render. Not the noun, "
        "and not \"generation\" in the sense of a cohort.")
add("compose.generate.help.ready", {
    "en": "Add this render to the queue",
    "zh-Hant": "將這次算圖加入佇列",
    "zh-Hans": "将这次渲染加入队列",
    "de": "Diesen Render der Warteschlange hinzufügen",
    "ar": "أضف هذا التصيير إلى قائمة الانتظار",
    "ja": "このレンダリングをキューに追加します",
    "ko": "이 렌더링을 대기열에 추가합니다",
    "th": "เพิ่มการเรนเดอร์นี้เข้าคิว",
    "yue-Hant": "將呢次算圖加入佇列",
    "en-SG": "Put this render inside the queue",
})
add("compose.generate.why", {
    "en": "Why is this disabled?",
    "zh-Hant": "為什麼無法使用？",
    "zh-Hans": "为什么无法使用？",
    "de": "Warum ist das deaktiviert?",
    "ar": "لماذا هذا معطّل؟",
    "ja": "なぜ使えないのか",
    "ko": "왜 사용할 수 없나요?",
    "th": "ทำไมจึงใช้ไม่ได้",
    "yue-Hant": "點解㩒唔到？",
    "en-SG": "Why cannot press?",
})
add("compose.generate.blocked.runtime", {
    "en": "The Python runtime is not ready. Open Settings › Runtime.",
    "zh-Hant": "Python 執行環境尚未就緒。請開啟「設定 › Runtime」。",
    "zh-Hans": "Python 运行环境尚未就绪。请打开“设置 › Runtime”。",
    "de": "Die Python-Laufzeitumgebung ist nicht bereit. Öffne „Einstellungen › Runtime“.",
    "ar": "بيئة تشغيل Python غير جاهزة. افتح «الإعدادات › Runtime».",
    "ja": "Python 実行環境が準備できていません。「設定 › 実行環境」を開いてください。",
    "ko": "Python 런타임이 준비되지 않았습니다. 설정 › 런타임을 여세요.",
    "th": "Runtime Python ยังไม่พร้อม เปิด การตั้งค่า › runtime",
    "yue-Hant": "Python 執行環境未 ready。開「設定 › 執行環境」。",
    "en-SG": "Python runtime not ready. Go Settings › Runtime.",
})
add("compose.generate.blocked.generic", {
    "en": "Resolve the issues listed under “Before you generate”.",
    "zh-Hant": "請先處理「生成前請確認」列出的問題。",
    "zh-Hans": "请先处理“生成前请确认”列出的问题。",
    "de": "Behebe die unter „Vor dem Erzeugen“ aufgeführten Punkte.",
    "ar": "عالِج المشكلات المذكورة تحت «قبل التوليد».",
    "ja": "「生成する前に」に挙がっている問題を解決してください。",
    "ko": "'생성하기 전에'에 나열된 문제를 해결하세요.",
    "th": "แก้ปัญหาที่แสดงไว้ใต้ “ก่อนเริ่มสร้าง” ให้เรียบร้อยก่อน",
    "yue-Hant": "先搞掂「生成前睇下」入面列嘅嘢。",
    "en-SG": "Settle the things under “Check First Leh” first.",
})
add("compose.presets", {
    "en": "Presets",
    "zh-Hant": "預設組合",
    "zh-Hans": "预设组合",
    "de": "Vorlagen",
    "ar": "إعدادات محفوظة",
    "ja": "プリセット",
    "ko": "프리셋",
    "th": "Preset",
    "yue-Hant": "預設組合",
    "en-SG": "Saved Recipes",
}, note="Saved combinations of settings — not 'default' in the factory sense.")
add("compose.presets.help", {
    "en": "Apply a saved combination of settings",
    "zh-Hant": "套用已儲存的設定組合",
    "zh-Hans": "应用已保存的设置组合",
    "de": "Eine gespeicherte Einstellungskombination anwenden",
    "ar": "تطبيق مجموعة إعدادات محفوظة",
    "ja": "保存した設定の組み合わせを適用します",
    "ko": "저장해 둔 설정 조합을 적용합니다",
    "th": "ใช้ชุดการตั้งค่าที่บันทึกไว้",
    "yue-Hant": "套用已儲存嘅設定組合",
    "en-SG": "Use a set of settings you kept before",
})
add("compose.preset.delete", {
    "en": "Delete Custom Preset",
    "zh-Hant": "刪除自訂預設組合",
    "zh-Hans": "删除自定义预设组合",
    "de": "Eigene Vorlage löschen",
    "ar": "حذف إعداد مخصّص",
    "ja": "カスタムプリセットを削除",
    "ko": "사용자 프리셋 삭제",
    "th": "ลบ preset ที่สร้างเอง",
    "yue-Hant": "刪除自訂預設組合",
    "en-SG": "Throw Away My Recipe",
})
add("compose.preset.save", {
    "en": "Save as Preset…",
    "zh-Hant": "另存為預設組合…",
    "zh-Hans": "另存为预设组合…",
    "de": "Als Vorlage sichern …",
    "ar": "حفظ كإعداد محفوظ…",
    "ja": "プリセットとして保存…",
    "ko": "프리셋으로 저장…",
    "th": "บันทึกเป็น preset …",
    "yue-Hant": "另存為預設組合…",
    "en-SG": "Keep as Recipe…",
})
add("compose.preset.save.title", {
    "en": "Save preset",
    "zh-Hant": "儲存預設組合",
    "zh-Hans": "保存预设组合",
    "de": "Vorlage sichern",
    "ar": "حفظ الإعداد",
    "ja": "プリセットを保存",
    "ko": "프리셋 저장",
    "th": "บันทึก preset",
    "yue-Hant": "儲存預設組合",
    "en-SG": "Keep recipe",
})
add("compose.preset.save.message", {
    "en": "Saves the current settings as a reusable recipe. The prompt, seed and attached "
          "files are not included.",
    "zh-Hant": "將目前設定存成可重複使用的配方。不包含提示詞、種子與附加檔案。",
    "zh-Hans": "将当前设置存为可重复使用的配方。不包含提示词、种子与附加文件。",
    "de": "Sichert die aktuellen Einstellungen als wiederverwendbares Rezept. Prompt, Seed "
          "und angehängte Dateien sind nicht enthalten.",
    "ar": "يحفظ الإعدادات الحالية كوصفة قابلة لإعادة الاستخدام. لا يشمل الموجّه أو قيمة "
          "seed أو الملفات المرفقة.",
    "ja": "現在の設定を再利用できるレシピとして保存します。プロンプト・シード・添付ファイルは含まれません。",
    "ko": "현재 설정을 다시 쓸 수 있는 조합으로 저장합니다. 프롬프트와 시드, 첨부 파일은 포함되지 않습니다.",
    "th": "บันทึกการตั้งค่าปัจจุบันเป็นสูตรที่นำกลับมาใช้ได้ โดยไม่รวม prompt seed และไฟล์แนบ",
    "yue-Hant": "將而家嘅設定存做可以重用嘅配方。唔包提示詞、種子同附加檔案。",
    "en-SG": "Keeps your settings now as a recipe, next time can use again. Prompt, seed and attached files all not included one.",
})
add("common.name", {
    "en": "Name",
    "zh-Hant": "名稱",
    "zh-Hans": "名称",
    "de": "Name",
    "ar": "الاسم",
    "ja": "名前",
    "ko": "이름",
    "th": "ชื่อ",
    "yue-Hant": "名",
    "en-SG": "Name",
}, note="Noun: the name of a preset or a file. A field label, not the verb \"to name\".")
add("common.cancel", {
    "en": "Cancel",
    "zh-Hant": "取消",
    "zh-Hans": "取消",
    "de": "Abbrechen",
    "ar": "إلغاء",
    "ja": "キャンセル",
    "ko": "취소",
    "th": "ยกเลิก",
    "yue-Hant": "取消",
    "en-SG": "Never Mind",
})
add("common.save", {
    "en": "Save",
    "zh-Hant": "儲存",
    "zh-Hans": "保存",
    "de": "Sichern",
    "ar": "حفظ",
    "ja": "保存",
    "ko": "저장",
    "th": "บันทึก",
    "yue-Hant": "儲存",
    "en-SG": "Keep",
}, note="Imperative verb on a button: write to disk. Not the sense of rescuing or of "
        "saving money.")
add("common.done", {
    "en": "Done",
    "zh-Hant": "完成",
    "zh-Hans": "完成",
    "de": "Fertig",
    "ar": "تم",
    "ja": "完了",
    "ko": "완료",
    "th": "เสร็จสิ้น",
    "yue-Hant": "搞掂",
    "en-SG": "Okay Liao",
})
add("common.delete", {
    "en": "Delete",
    "zh-Hant": "刪除",
    "zh-Hans": "删除",
    "de": "Löschen",
    "ar": "حذف",
    "ja": "削除",
    "ko": "삭제",
    "th": "ลบ",
    "yue-Hant": "刪除",
    "en-SG": "Throw Away",
})
add("common.download", {
    "en": "Download",
    "zh-Hant": "下載",
    "zh-Hans": "下载",
    "de": "Laden",
    "ar": "تنزيل",
    "ja": "ダウンロード",
    "ko": "다운로드",
    "th": "ดาวน์โหลด",
    "yue-Hant": "下載",
    "en-SG": "Download",
})
add("common.reveal", {
    "en": "Reveal",
    "zh-Hant": "顯示",
    "zh-Hans": "显示",
    "de": "Anzeigen",
    "ar": "إظهار",
    "ja": "表示",
    "ko": "표시",
    "th": "แสดง",
    "yue-Hant": "顯示",
    "en-SG": "Show Me",
}, note="Imperative verb: show this file in the Finder, selected in its folder. "
        "Follow whatever the platform calls it — it is a Finder idiom, not a general "
        "\"show\".")
add("common.refresh", {
    "en": "Refresh",
    "zh-Hant": "重新整理",
    "zh-Hans": "刷新",
    "de": "Aktualisieren",
    "ar": "تحديث",
    "ja": "更新",
    "ko": "새로 고침",
    "th": "รีเฟรช",
    "yue-Hant": "重新整理",
    "en-SG": "Refresh",
})
add("common.copy", {
    "en": "Copy",
    "zh-Hant": "拷貝",
    "zh-Hans": "复制",
    "de": "Kopieren",
    "ar": "نسخ",
    "ja": "コピー",
    "ko": "복사",
    "th": "คัดลอก",
    "yue-Hant": "拷貝",
    "en-SG": "Copy",
}, note="Imperative verb on a button — copy this to the clipboard. Never the noun \"a "
        "copy\". macOS uses 拷貝 in Traditional Chinese, 复制 in Simplified.")

# ── Compose: prompt ──────────────────────────────────────────────────────────
add("compose.prompt.title", {
    "en": "Prompt",
    "zh-Hant": "提示詞",
    "zh-Hans": "提示词",
    "de": "Prompt",
    "ar": "الموجّه",
    "ja": "プロンプト",
    "ko": "프롬프트",
    "th": "พรอมต์ (Prompt)",
    "yue-Hant": "提示詞",
    "en-SG": "Prompt",
})
add("compose.prompt.hint", {
    "en": "Describe the shot. Press Tab to move on, Option-Tab to insert a tab.",
    "zh-Hant": "描述這個鏡頭。按 Tab 跳到下一項，Option-Tab 插入定位字元。",
    "zh-Hans": "描述这个镜头。按 Tab 跳到下一项，Option-Tab 插入制表符。",
    "de": "Beschreibe die Einstellung. Tab wechselt weiter, Wahl-Tab fügt einen Tabulator "
          "ein.",
    "ar": "صِف اللقطة. اضغط Tab للانتقال، وOption-Tab لإدراج علامة جدولة.",
    "ja": "ショットを説明してください。Tab で次へ、Option-Tab でタブを入力します。",
    "ko": "장면을 설명하세요. Tab으로 다음으로 이동하고, Option-Tab으로 탭 문자를 넣습니다.",
    "th": "บรรยายช็อตที่ต้องการ กด Tab เพื่อไปต่อ กด Option-Tab เพื่อแทรกแท็บ",
    "yue-Hant": "描述下呢個鏡頭。㩒 Tab 去下一項，Option-Tab 入定位字元。",
    "en-SG": "Describe the shot. Press Tab to move on, Option-Tab to put in a tab.",
})
add("compose.prompt.footnote", {
    "en": "H3 responds well to camera language — shot size, lens, movement, lighting — and "
          "to a described soundscape, since it generates audio in the same pass. There is "
          "no negative prompt: the released weights are CFG-distilled, so guidance controls "
          "would do nothing.",
    "zh-Hant": "H3 對鏡頭語言反應良好，例如景別、鏡頭、運動與打光；也能理解對聲音場景的描述，因為它在同一次運算中生成音訊。沒有負面提示詞：釋出的權重經過 CFG "
               "蒸餾，引導強度的設定不會有任何作用。",
    "zh-Hans": "H3 对镜头语言反应良好，例如景别、镜头、运动与打光；也能理解对声音场景的描述，因为它在同一次运算中生成音频。没有负面提示词：发布的权重经过 CFG "
               "蒸馏，引导强度的设置不会有任何作用。",
    "de": "H3 reagiert gut auf Kamerasprache — Einstellungsgröße, Objektiv, Bewegung, Licht "
          "— und auf beschriebene Klangbilder, da Audio im selben Durchgang entsteht. Es "
          "gibt keinen Negativ-Prompt: die veröffentlichten Gewichte sind CFG-destilliert, "
          "Guidance-Regler hätten keine Wirkung.",
    "ar": "يستجيب H3 جيدًا للغة الكاميرا — حجم اللقطة والعدسة والحركة والإضاءة — وكذلك لوصف "
          "المشهد الصوتي، لأنه يولّد الصوت في المسار نفسه. لا يوجد موجّه سلبي: الأوزان "
          "المنشورة مقطّرة بأسلوب CFG، لذا لن يكون لعناصر التوجيه أي أثر.",
    "ja": "H3 はカメラ用語（画角・レンズ・カメラワーク・照明）によく反応し、音を同じパスで生成するため、音の情景描写にも反応します。ネガティブプロンプトはありません。公開された重みは CFG 蒸留済みで、ガイダンス系の操作は何も起こさないからです。",
    "ko": "H3는 카메라 언어(샷 크기, 렌즈, 움직임, 조명)에 잘 반응하고, 소리를 같은 패스에서 만들기 때문에 묘사된 소리 풍경에도 반응합니다. 네거티브 프롬프트는 없습니다. 공개된 가중치가 CFG 증류를 거쳐 가이던스 조절이 아무 일도 하지 않기 때문입니다.",
    "th": "H3 ตอบสนองดีกับภาษาของกล้อง — ขนาดภาพ เลนส์ การเคลื่อนกล้อง แสง — และกับการบรรยายบรรยากาศเสียง เพราะสร้างเสียงในรอบเดียวกัน ไม่มี prompt เชิงลบ เพราะน้ำหนักที่เผยแพร่ผ่านการกลั่นแบบ CFG แล้ว การปรับ guidance จึงไม่มีผลใด ๆ",
    "yue-Hant": "H3 對鏡頭語言好受落——景別、鏡頭、運動、打光——亦聽得明你對聲音場景嘅描述，因為佢喺同一次運算入面出埋聲。冇負面提示詞：釋出嘅權重經過 CFG 蒸餾，所以調引導強度係唔會有作用嘅。",
    "en-SG": "H3 damn good with camera language — shot size, lens, movement, lighting — and with sound you describe also, because it makes the audio in the same pass. No negative prompt: the released weights are CFG-distilled, so guidance controls do nothing one. Don't waste time.",
})

# ── Compose: mode card ───────────────────────────────────────────────────────
add("compose.mode.title", {
    "en": "Mode",
    "zh-Hant": "模式",
    "zh-Hans": "模式",
    "de": "Modus",
    "ar": "الوضع",
    "ja": "モード",
    "ko": "모드",
    "th": "โหมด",
    "yue-Hant": "模式",
    "en-SG": "Mode",
}, note="Labels the picker choosing between text-to-video and reference modes. A "
        "choice the user makes. Distinct from library.mode, which reports what a "
        "finished render used.")
add("compose.mode.task.fl2va", {
    "en": " Uses the FL2VA checkpoint.",
    "zh-Hant": "　使用 FL2VA 檢查點。",
    "zh-Hans": "　使用 FL2VA 检查点。",
    "de": " Verwendet den FL2VA-Checkpoint.",
    "ar": " يستخدم نقطة التحقق FL2VA.",
    "ja": "　FL2VA のチェックポイントを使います。",
    "ko": "　FL2VA 체크포인트를 사용합니다.",
    "th": " ใช้ checkpoint FL2VA",
    "yue-Hant": "　用 FL2VA 檢查點。",
    "en-SG": " Uses the FL2VA checkpoint.",
}, note={
    "content": "Begins with a space because it is appended to the sentence before it — U+3000 "
               "for Chinese. Runtime concatenation: the two halves cannot be reordered, and a "
               "language needing the clause first cannot have it.",
    "level": WARNING,
})
add("compose.mode.task.ref2va", {
    "en": " Uses the Ref2VA checkpoint.",
    "zh-Hant": "　使用 Ref2VA 檢查點。",
    "zh-Hans": "　使用 Ref2VA 检查点。",
    "de": " Verwendet den Ref2VA-Checkpoint.",
    "ar": " يستخدم نقطة التحقق Ref2VA.",
    "ja": "　Ref2VA のチェックポイントを使います。",
    "ko": "　Ref2VA 체크포인트를 사용합니다.",
    "th": " ใช้ checkpoint Ref2VA",
    "yue-Hant": "　用 Ref2VA 檢查點。",
    "en-SG": " Uses the Ref2VA checkpoint.",
}, note={
    "content": "See compose.mode.task.fl2va — same leading space, same concatenation.",
    "level": WARNING,
})
add("compose.engine.label", {
    "en": "Engine",
    "zh-Hant": "引擎",
    "zh-Hans": "引擎",
    "de": "Engine",
    "ar": "المحرّك",
    "ja": "エンジン",
    "ko": "엔진",
    "th": "เอนจิน (Engine)",
    "yue-Hant": "引擎",
    "en-SG": "Engine",
}, note="Which backend runs the model — MLX or ComfyUI. Not a motor, and not a game "
        "engine. Usually kept in English.")
add("compose.engine.mlx.note", {
    "en": "Runs natively on MLX. No server, and the default. Its weights are undistilled, "
          "so low step counts are off-distribution — use the port's 16 steps or more for "
          "quality.",
    "zh-Hant": "以 MLX 原生執行，不需伺服器，也是預設選項。其權重未經蒸餾，步數太低會偏離訓練分布；要求品質請用移植版預設的 16 步以上。",
    "zh-Hans": "以 MLX 原生运行，不需服务器，也是默认选项。其权重未经蒸馏，步数太低会偏离训练分布；要求质量请用移植版默认的 16 步以上。",
    "de": "Läuft nativ auf MLX. Kein Server, und die Voreinstellung. Die Gewichte sind "
          "nicht destilliert, niedrige Schrittzahlen liegen daher außerhalb der Verteilung "
          "— für Qualität die 16 Schritte der Portierung oder mehr.",
    "ar": "يعمل أصليًا على MLX. بلا خادم، وهو الخيار الافتراضي. أوزانه غير مقطّرة، لذا فإن "
          "أعداد الخطوات المنخفضة تخرج عن التوزيع — استخدم 16 خطوة أو أكثر للجودة.",
    "ja": "MLX 上でネイティブに動作します。サーバー不要で、こちらが既定です。重みは未蒸留のため、ステップ数が少ないと分布から外れます。品質を求めるなら移植版の 16 ステップ以上を使ってください。",
    "ko": "MLX에서 네이티브로 실행됩니다. 서버가 필요 없으며 기본값입니다. 가중치가 비증류라 스텝 수가 적으면 분포를 벗어나므로, 품질을 원하면 이식판의 16스텝 이상을 쓰세요.",
    "th": "ทำงานแบบเนทีฟบน MLX ไม่ต้องใช้เซิร์ฟเวอร์ และเป็นค่าเริ่มต้น น้ำหนักยังไม่ผ่านการกลั่น step น้อยจึงหลุดจากการกระจายที่ฝึกมา ถ้าต้องการคุณภาพให้ใช้ 16 step ขึ้นไปตามพอร์ตนี้",
    "yue-Hant": "喺 MLX 上面原生跑，唔使伺服器，亦係預設。佢啲權重未蒸餾，步數太少就會偏離訓練分佈——想靚啲就用移植版嘅 16 步或以上。",
    "en-SG": "Runs natively on MLX. No server needed, and this is the default one. Its weights never distil, so too few steps will go off-distribution — use the port's 16 steps or more if you want it to come out nice.",
})
add("compose.engine.comfy.note", {
    "en": "Runs through ComfyUI on PyTorch/Metal, which can load the 4-step turbo LoRA. "
          "Four distilled steps take about as long as five undistilled ones on MLX, and are "
          "what the LoRA was trained for.",
    "zh-Hant": "透過 ComfyUI 以 PyTorch/Metal 執行，可載入 4 步 turbo LoRA。四個蒸餾步驟所需時間與 MLX "
               "上五個未蒸餾步驟相當，而這正是該 LoRA 訓練的目標。",
    "zh-Hans": "通过 ComfyUI 以 PyTorch/Metal 运行，可加载 4 步 turbo LoRA。四个蒸馏步骤所需时间与 MLX "
               "上五个未蒸馏步骤相当，而这正是该 LoRA 训练的目标。",
    "de": "Läuft über ComfyUI auf PyTorch/Metal und kann die 4-Schritt-Turbo-LoRA laden. "
          "Vier destillierte Schritte dauern etwa so lange wie fünf undestillierte auf MLX "
          "— und genau dafür wurde die LoRA trainiert.",
    "ar": "يعمل عبر ComfyUI على PyTorch/Metal، ويستطيع تحميل turbo LoRA ذات الأربع خطوات. "
          "أربع خطوات مقطّرة تستغرق زمنًا قريبًا من خمس خطوات غير مقطّرة على MLX، وهي ما "
          "دُرّبت عليه الـ LoRA.",
    "ja": "PyTorch/Metal 上の ComfyUI で動作し、4 ステップの turbo LoRA を読み込めます。蒸留された 4 ステップは MLX の未蒸留 5 ステップとほぼ同じ時間で、LoRA はそのために学習されています。",
    "ko": "PyTorch/Metal 기반 ComfyUI로 실행되며 4스텝 turbo LoRA를 불러올 수 있습니다. 증류된 4스텝은 MLX의 비증류 5스텝과 비슷한 시간이 걸리며, LoRA는 바로 그 스텝 수에 맞춰 학습되었습니다.",
    "th": "ทำงานผ่าน ComfyUI บน PyTorch/Metal ซึ่งโหลด turbo LoRA แบบ 4 step ได้ สี่ step ที่กลั่นแล้วใช้เวลาพอ ๆ กับห้า step ที่ยังไม่กลั่นบน MLX และเป็นจำนวนที่ LoRA ถูกฝึกมา",
    "yue-Hant": "透過 ComfyUI 喺 PyTorch/Metal 上面跑，載入到 4 步嘅 turbo LoRA。四個蒸餾步用嘅時間，同 MLX 上面五個未蒸餾嘅步差唔多，而呢個 LoRA 就係為咗呢個步數而訓練。",
    "en-SG": "Goes through ComfyUI on PyTorch/Metal, so it can load the 4-step turbo LoRA. Four distilled steps take about the same time as five undistilled ones on MLX — and that is exactly what the LoRA trained for. Quite steady.",
})

# ── Output format vocabulary ─────────────────────────────────────────────────
add("format.res.native", {
    "en": "768p — native",
    "zh-Hant": "768p — 原生",
    "zh-Hans": "768p — 原生",
    "de": "768p — nativ",
    "ar": "‏768p — أصلي",
    "ja": "768p — ネイティブ",
    "ko": "768p — 네이티브",
    "th": "768p — ดั้งเดิม",
    "yue-Hant": "768p — 原生",
    "en-SG": "768p — original",
})
add("format.res.1080", {
    "en": "1080p — upscaled",
    "zh-Hant": "1080p — 放大",
    "zh-Hans": "1080p — 放大",
    "de": "1080p — hochskaliert",
    "ar": "‏1080p — مُكبَّر",
    "ja": "1080p — アップスケール",
    "ko": "1080p — 업스케일",
    "th": "1080p — ขยายขนาด",
    "yue-Hant": "1080p — 放大",
    "en-SG": "1080p — blow up",
})
add("format.res.1440", {
    "en": "1440p — upscaled",
    "zh-Hant": "1440p — 放大",
    "zh-Hans": "1440p — 放大",
    "de": "1440p — hochskaliert",
    "ar": "‏1440p — مُكبَّر",
    "ja": "1440p — アップスケール",
    "ko": "1440p — 업스케일",
    "th": "1440p — ขยายขนาด",
    "yue-Hant": "1440p — 放大",
    "en-SG": "1440p — blow up",
})
add("format.res.native.detail", {
    "en": "Exactly what the model produces, with no resampling. Recommended.",
    "zh-Hant": "模型的原始輸出，不做重新取樣。建議使用。",
    "zh-Hans": "模型的原始输出，不做重新采样。建议使用。",
    "de": "Genau das, was das Modell erzeugt, ohne Resampling. Empfohlen.",
    "ar": "ما ينتجه النموذج تمامًا، دون إعادة أخذ عيّنات. موصى به.",
    "ja": "モデルの出力そのままで、リサンプルしません。おすすめです。",
    "ko": "모델이 만든 그대로이며 리샘플링하지 않습니다. 권장합니다.",
    "th": "ตรงตามที่โมเดลสร้างโดยไม่ปรับขนาด แนะนำให้ใช้ค่านี้",
    "yue-Hant": "完全係模型出嘅嘢,唔再取樣。建議用呢個。",
    "en-SG": "Exactly what the model gives, no resampling. Use this one.",
})
add("format.res.1080.detail", {
    "en": "Resampled after generation to fit a 1080p delivery pipeline. No detail is added.",
    "zh-Hant": "生成後重新取樣以符合 1080p 交付流程，不會增加細節。",
    "zh-Hans": "生成后重新采样以符合 1080p 交付流程，不会增加细节。",
    "de": "Nach der Erzeugung auf eine 1080p-Auslieferung resampelt. Es kommen keine "
          "Details hinzu.",
    "ar": "يُعاد أخذ العيّنات بعد التوليد ليلائم مسار تسليم 1080p. لا تُضاف أي تفاصيل.",
    "ja": "生成後に 1080p の納品フローに合わせてリサンプルします。ディテールが増えるわけではありません。",
    "ko": "생성 후 1080p 납품 파이프라인에 맞춰 리샘플링합니다. 디테일이 늘어나지는 않습니다.",
    "th": "ปรับขนาดหลังสร้างเสร็จให้เข้ากับงานส่งมอบแบบ 1080p โดยไม่ได้เพิ่มรายละเอียด",
    "yue-Hant": "生成之後再取樣,啱 1080p 嘅交付流程。唔會多咗細節。",
    "en-SG": "Resample after generate, just to fit a 1080p pipeline. No extra detail one, don't expect miracle.",
})
add("format.res.1440.detail", {
    "en": "Resampled to 1440p. Larger files for the same real detail; useful only if a "
          "downstream tool demands this size.",
    "zh-Hant": "重新取樣為 1440p。檔案更大但實際細節不變；只有下游工具要求此尺寸時才有意義。",
    "zh-Hans": "重新采样为 1440p。文件更大但实际细节不变；只有下游工具要求此尺寸时才有意义。",
    "de": "Auf 1440p resampelt. Größere Dateien bei gleichem echten Detail; nur sinnvoll, "
          "wenn ein nachgelagertes Werkzeug diese Größe verlangt.",
    "ar": "يُعاد أخذ العيّنات إلى 1440p. ملفات أكبر بالتفاصيل الحقيقية نفسها؛ مفيد فقط إذا "
          "طلبت أداة لاحقة هذا الحجم.",
    "ja": "1440p にリサンプルします。実際のディテールは同じままファイルだけ大きくなるので、後工程がこのサイズを要求する場合にだけ使ってください。",
    "ko": "1440p로 리샘플링합니다. 실제 디테일은 그대로인데 파일만 커지므로, 후속 도구가 이 크기를 요구할 때만 쓰세요.",
    "th": "ปรับขนาดเป็น 1440p ไฟล์ใหญ่ขึ้นโดยรายละเอียดจริงเท่าเดิม ใช้เมื่อเครื่องมือปลายทางต้องการขนาดนี้เท่านั้น",
    "yue-Hant": "取樣成 1440p。檔案大咗但實際細節一樣;淨係有下游工具指定要呢個尺寸先有用。",
    "en-SG": "Resample to 1440p. File bigger, detail same same. Only useful if some downstream tool must have this size.",
})
add("format.fps.native", {
    "en": "24 fps — native",
    "zh-Hant": "24 fps — 原生",
    "zh-Hans": "24 fps — 原生",
    "de": "24 fps — nativ",
    "ar": "‏24 fps — أصلي",
    "ja": "24 fps — ネイティブ",
    "ko": "24 fps — 네이티브",
    "th": "24 fps — ดั้งเดิม",
    "yue-Hant": "24 fps — 原生",
    "en-SG": "24 fps — original",
})
add("format.fps.conformed", {
    "en": "%@ fps — conformed",
    "zh-Hant": "%@ fps — 轉換",
    "zh-Hans": "%@ fps — 转换",
    "de": "%@ fps — angepasst",
    "ar": "‏%@ fps — مُوائَم",
    "ja": "%@ fps — 変換",
    "ko": "%@ fps — 변환됨",
    "th": "%@ fps — ปรับแล้ว",
    "yue-Hant": "%@ fps — 轉換",
    "en-SG": "%@ fps — converted",
})
add("format.fps.native.detail", {
    "en": "The model's own cadence. No frames are invented or dropped.",
    "zh-Hant": "模型本身的節奏，不會憑空產生或丟棄影格。",
    "zh-Hans": "模型本身的节奏，不会凭空产生或丢弃帧。",
    "de": "Die eigene Kadenz des Modells. Es werden keine Bilder erfunden oder verworfen.",
    "ar": "إيقاع النموذج نفسه. لا تُختلق إطارات ولا تُحذف.",
    "ja": "モデル本来のテンポです。フレームの生成も間引きもありません。",
    "ko": "모델 본래의 박자입니다. 프레임을 만들지도 버리지도 않습니다.",
    "th": "จังหวะดั้งเดิมของโมเดล ไม่มีการสร้างหรือตัดเฟรมทิ้ง",
    "yue-Hant": "模型本身嘅節奏,唔會生多啲又唔會掉走影格。",
    "en-SG": "The model's own pace. No frames invented, none thrown away.",
})
add("format.fps.30.detail", {
    "en": "Frames are duplicated to a 30 fps timeline. Motion may judder slightly.",
    "zh-Hant": "影格會複製到 30 fps 時間軸，動態可能略為頓挫。",
    "zh-Hans": "帧会复制到 30 fps 时间轴，动态可能略为顿挫。",
    "de": "Bilder werden auf eine 30-fps-Zeitleiste dupliziert. Die Bewegung kann leicht "
          "ruckeln.",
    "ar": "تُكرَّر الإطارات على خط زمني بمعدل 30 fps. قد تبدو الحركة متقطّعة قليلًا.",
    "ja": "フレームを複製して 30 fps のタイムラインに合わせます。動きがわずかにぎこちなくなることがあります。",
    "ko": "프레임을 복제해 30 fps 타임라인에 맞춥니다. 움직임이 약간 끊겨 보일 수 있습니다.",
    "th": "ทำซ้ำเฟรมให้เข้ากับ timeline 30 fps การเคลื่อนไหวอาจสะดุดเล็กน้อย",
    "yue-Hant": "影格會複製到 30 fps 嘅時間軸,郁起上嚟可能有少少窒。",
    "en-SG": "Frames get copied onto a 30 fps timeline. Movement may jerk a bit.",
})
add("format.fps.60.detail", {
    "en": "Frames are duplicated to a 60 fps timeline. No new motion is synthesised.",
    "zh-Hant": "影格會複製到 60 fps 時間軸，不會合成新的動態。",
    "zh-Hans": "帧会复制到 60 fps 时间轴，不会合成新的动态。",
    "de": "Bilder werden auf eine 60-fps-Zeitleiste dupliziert. Es wird keine neue Bewegung "
          "erzeugt.",
    "ar": "تُكرَّر الإطارات على خط زمني بمعدل 60 fps. لا تُصطنَع حركة جديدة.",
    "ja": "フレームを複製して 60 fps のタイムラインに合わせます。新しい動きは作られません。",
    "ko": "프레임을 복제해 60 fps 타임라인에 맞춥니다. 새로운 움직임을 만들어 내지는 않습니다.",
    "th": "ทำซ้ำเฟรมให้เข้ากับ timeline 60 fps โดยไม่สร้างการเคลื่อนไหวใหม่",
    "yue-Hant": "影格會複製到 60 fps 嘅時間軸,唔會生出新嘅郁動。",
    "en-SG": "Frames get copied onto a 60 fps timeline. No new movement is made up.",
})
add("format.codec.h264.detail", {
    "en": "What the model produces. Delivered as rendered, with no second encode, and plays "
          "everywhere.",
    "zh-Hant": "模型的原生輸出。依算圖結果直接交付，不做二次編碼，相容性最廣。",
    "zh-Hans": "模型的原生输出。依渲染结果直接交付，不做二次编码，兼容性最广。",
    "de": "Was das Modell erzeugt. Wird unverändert ausgeliefert, ohne zweite Kodierung, "
          "und läuft überall.",
    "ar": "ما ينتجه النموذج. يُسلَّم كما صُيِّر، دون ترميز ثانٍ، ويعمل في كل مكان.",
    "ja": "モデルが出力するそのままの形式です。再エンコードせずに書き出され、どこでも再生できます。",
    "ko": "모델이 만들어 내는 그대로입니다. 다시 인코딩하지 않고 내보내며 어디서나 재생됩니다.",
    "th": "เป็นสิ่งที่โมเดลสร้างออกมาโดยตรง ส่งออกตามที่เรนเดอร์โดยไม่เข้ารหัสซ้ำ และเล่นได้ทุกที่",
    "yue-Hant": "模型原本出嘅嘢。點算就點交,唔再編多次,邊度都播到。",
    "en-SG": "Whatever the model gives you, straight away. No second encode, and can play anywhere one.",
})
add("format.codec.av1.detail", {
    "en": "About half the size for the same quality. Encoded in software, since Apple "
          "silicon has no AV1 encoder — but SVT-AV1 handles a five-second clip in a second "
          "or two, so the cost is negligible next to generation.",
    "zh-Hant": "同等品質下檔案約為一半大小。因為 Apple 晶片沒有 AV1 編碼器，改以軟體編碼；但 SVT-AV1 處理五秒片段只要一兩秒，相較生成時間可以忽略。",
    "zh-Hans": "同等质量下文件约为一半大小。因为 Apple 芯片没有 AV1 编码器，改以软件编码；但 SVT-AV1 处理五秒片段只要一两秒，相较生成时间可以忽略。",
    "de": "Etwa halb so groß bei gleicher Qualität. Wird in Software kodiert, da Apple "
          "Silicon keinen AV1-Encoder hat — SVT-AV1 schafft einen Fünf-Sekunden-Clip aber "
          "in ein bis zwei Sekunden, gegenüber der Erzeugung also vernachlässigbar.",
    "ar": "نحو نصف الحجم بالجودة نفسها. يُرمَّز برمجيًا لأن معالجات Apple لا تتضمّن مرمِّز "
          "AV1 — غير أن SVT-AV1 ينهي مقطعًا من خمس ثوانٍ في ثانية أو اثنتين، وهو زمن ضئيل "
          "مقارنةً بالتوليد.",
    "ja": "同じ画質でおよそ半分のサイズです。Apple シリコンに AV1 エンコーダがないためソフトウェアで符号化しますが、SVT-AV1 なら 5 秒のクリップを 1〜2 秒で処理するので、生成時間に比べれば無視できます。",
    "ko": "같은 품질에 크기는 약 절반입니다. Apple 실리콘에 AV1 인코더가 없어 소프트웨어로 인코딩하지만, SVT-AV1은 5초 클립을 1~2초에 처리하므로 생성 시간에 비하면 무시할 만합니다.",
    "th": "ขนาดราวครึ่งเดียวที่คุณภาพเท่ากัน เข้ารหัสด้วยซอฟต์แวร์เพราะ Apple silicon ไม่มีตัวเข้ารหัส AV1 แต่ SVT-AV1 จัดการคลิปห้าวินาทีได้ในหนึ่งถึงสองวินาที จึงน้อยมากเมื่อเทียบกับเวลาสร้าง",
    "yue-Hant": "同等質素之下,檔案細一半左右。因為 Apple 晶片冇 AV1 編碼器,所以用軟件編;不過 SVT-AV1 處理五秒片得一兩秒,同生成時間比根本唔算數。",
    "en-SG": "About half the size, same quality. Software encode because Apple silicon bo AV1 encoder — but SVT-AV1 clears a five-second clip in one, two seconds only, so compared to generating, never mind lah.",
})
add("format.audio.muxed", {
    "en": "Muxed into the video",
    "zh-Hant": "混流至影片中",
    "zh-Hans": "混流至视频中",
    "de": "In das Video gemuxt",
    "ar": "مدمج داخل الفيديو",
    "ja": "動画に多重化",
    "ko": "비디오에 다중화",
    "th": "รวมไว้ในวิดีโอ",
    "yue-Hant": "混流入條片度",
    "en-SG": "Inside the video",
})
add("format.audio.wav", {
    "en": "Muxed, plus a separate WAV",
    "zh-Hant": "混流，並另存 WAV",
    "zh-Hans": "混流，并另存 WAV",
    "de": "Gemuxt, plus separate WAV-Datei",
    "ar": "مدمج، مع ملف WAV منفصل",
    "ja": "多重化に加えて WAV を別途出力",
    "ko": "다중화에 더해 별도 WAV 파일",
    "th": "รวมในวิดีโอ พร้อมไฟล์ WAV แยก",
    "yue-Hant": "混流，再另外存個 WAV",
    "en-SG": "Inside the video, plus one separate WAV",
})

# ── Compose: output card ─────────────────────────────────────────────────────
add("compose.output.title", {
    "en": "Output",
    "zh-Hant": "輸出",
    "zh-Hans": "输出",
    "de": "Ausgabe",
    "ar": "الإخراج",
    "ja": "出力",
    "ko": "출력",
    "th": "เอาต์พุต (Output)",
    "yue-Hant": "輸出",
    "en-SG": "Output",
}, note="Heads the card for how the video is encoded — codec, resolution, frame rate. "
        "Output as in the result of a render. Distinct from settings.folder.output, a "
        "folder.")
add("compose.output.footnote", {
    "en": "The model always renders 24 fps at a 768 px short edge. Anything else on this "
          "card is applied afterwards, during encoding.",
    "zh-Hant": "模型固定以 24 fps、短邊 768 px 算圖。此卡片上的其他設定都是事後在編碼階段套用。",
    "zh-Hans": "模型固定以 24 fps、短边 768 px 渲染。此卡片上的其他设置都是事后在编码阶段应用。",
    "de": "Das Modell rendert immer 24 fps mit 768 px kurzer Kante. Alles andere auf dieser "
          "Karte wird erst beim Kodieren angewandt.",
    "ar": "يصيّر النموذج دائمًا بمعدل 24 fps وبحافة قصيرة قدرها 768 بكسل. وكل ما عدا ذلك في "
          "هذه البطاقة يُطبَّق لاحقًا أثناء الترميز.",
    "ja": "モデルは常に短辺 768 px・24 fps でレンダリングします。このカードのそれ以外の設定は、あとからエンコード時に適用されます。",
    "ko": "모델은 항상 짧은 변 768 px, 24 fps로 렌더링합니다. 이 카드의 나머지 설정은 그 뒤 인코딩 단계에서 적용됩니다.",
    "th": "โมเดลเรนเดอร์ที่ 24 fps และด้านสั้น 768 px เสมอ ค่าอื่นในการ์ดนี้จะถูกนำไปใช้ภายหลังตอนเข้ารหัส",
    "yue-Hant": "個模型固定用 24 fps、短邊 768 px 嚟算。呢張卡上面其他設定，都係之後編碼嗰陣先套用。",
    "en-SG": "The model always render 24 fps at 768 px short edge, fixed one. Everything else on this card only apply after, during encoding.",
})
add("compose.aspect", {
    "en": "Aspect ratio",
    "zh-Hant": "長寬比",
    "zh-Hans": "宽高比",
    "de": "Seitenverhältnis",
    "ar": "نسبة العرض إلى الارتفاع",
    "ja": "アスペクト比",
    "ko": "화면 비율",
    "th": "อัตราส่วนภาพ",
    "yue-Hant": "長寬比",
    "en-SG": "Shape",
})
add("compose.aspect.help", {
    "en": "%1$@ — renders at %2$@",
    "zh-Hant": "%1$@ — 以 %2$@ 算圖",
    "zh-Hans": "%1$@ — 以 %2$@ 渲染",
    "de": "%1$@ — rendert mit %2$@",
    "ar": "%1$@ — يُصيَّر بمقاس %2$@",
    "ja": "%1$@ — %2$@ でレンダリング",
    "ko": "%1$@ — %2$@ 로 렌더링",
    "th": "%1$@ — เรนเดอร์ที่ %2$@",
    "yue-Hant": "%1$@ — 用 %2$@ 算",
    "en-SG": "%1$@ — render at %2$@",
})
add("compose.aspect.accessibility", {
    "en": "%@ aspect ratio",
    "zh-Hant": "%@ 長寬比",
    "zh-Hans": "%@ 宽高比",
    "de": "Seitenverhältnis %@",
    "ar": "نسبة عرض إلى ارتفاع %@",
    "ja": "アスペクト比 %@",
    "ko": "%@ 화면 비율",
    "th": "อัตราส่วนภาพ %@",
    "yue-Hant": "%@ 長寬比",
    "en-SG": "%@ shape",
})
add("compose.aspect.pixels", {
    "en": "%1$@ by %2$@ pixels",
    "zh-Hant": "%1$@ 乘 %2$@ 像素",
    "zh-Hans": "%1$@ 乘 %2$@ 像素",
    "de": "%1$@ mal %2$@ Pixel",
    "ar": "%1$@ في %2$@ بكسل",
    "ja": "%1$@ × %2$@ ピクセル",
    "ko": "%1$@ × %2$@ 픽셀",
    "th": "%1$@ × %2$@ พิกเซล",
    "yue-Hant": "%1$@ 乘 %2$@ 像素",
    "en-SG": "%1$@ by %2$@ pixels",
})
add("compose.resolution", {
    "en": "Resolution",
    "zh-Hant": "解析度",
    "zh-Hans": "分辨率",
    "de": "Auflösung",
    "ar": "الدقة",
    "ja": "解像度",
    "ko": "해상도",
    "th": "ความละเอียด",
    "yue-Hant": "解析度",
    "en-SG": "Resolution",
}, note="Pixel dimensions of the output. Not resolution in the sense of resolving a "
        "dispute or a decision.")
add("compose.framerate", {
    "en": "Frame rate",
    "zh-Hant": "影格率",
    "zh-Hans": "帧率",
    "de": "Bildrate",
    "ar": "معدل الإطارات",
    "ja": "フレームレート",
    "ko": "프레임 레이트",
    "th": "อัตราเฟรม",
    "yue-Hant": "影格率",
    "en-SG": "Frame rate",
})
add("compose.codec", {
    "en": "Codec",
    "zh-Hant": "編碼格式",
    "zh-Hans": "编码格式",
    "de": "Codec",
    "ar": "الترميز",
    "ja": "コーデック",
    "ko": "코덱",
    "th": "ตัวแปลงสัญญาณ",
    "yue-Hant": "編碼格式",
    "en-SG": "Codec",
})
add("compose.audio", {
    "en": "Audio",
    "zh-Hant": "音訊",
    "zh-Hans": "音频",
    "de": "Audio",
    "ar": "الصوت",
    "ja": "オーディオ",
    "ko": "오디오",
    "th": "เสียง",
    "yue-Hant": "音訊",
    "en-SG": "Audio",
}, note="Labels the switch for whether the render produces sound. A property of the "
        "output. Distinct from refs.kind.audio, which names a kind of file the user "
        "attaches.")
add("compose.audio.footnote", {
    "en": "H3 generates 32 kHz stereo audio in the same pass as the picture; there is no "
          "silent mode that renders faster.",
    "zh-Hant": "H3 會在生成畫面的同一次運算中產生 32 kHz 立體聲音訊；沒有更快的無聲模式。",
    "zh-Hans": "H3 会在生成画面的同一次运算中产生 32 kHz 立体声音频；没有更快的静音模式。",
    "de": "H3 erzeugt 32-kHz-Stereo-Audio im selben Durchgang wie das Bild; einen "
          "schnelleren stummen Modus gibt es nicht.",
    "ar": "يولّد H3 صوتًا ستيريو بتردد 32 kHz في المسار نفسه الذي يولّد فيه الصورة؛ ولا "
          "يوجد وضع صامت أسرع.",
    "ja": "H3 は映像と同じパスで 32 kHz ステレオ音声を生成します。音声を切って速くするモードはありません。",
    "ko": "H3는 영상과 같은 패스에서 32 kHz 스테레오 오디오를 생성합니다. 소리를 끄고 더 빨리 렌더링하는 모드는 없습니다.",
    "th": "H3 สร้างเสียง stereo 32 kHz ไปพร้อมกับภาพในรอบเดียวกัน จึงไม่มีโหมดเงียบที่เรนเดอร์เร็วกว่า",
    "yue-Hant": "H3 喺算畫面嘅同一次運算入面一齊出 32 kHz 立體聲；冇話靜音就算快啲嘅模式。",
    "en-SG": "H3 bao ka liao — it makes 32 kHz stereo audio in the same pass as the picture. Got no silent mode that render faster one, don't go and find.",
})

# ── Sampling card ────────────────────────────────────────────────────────────
add("sampling.title", {
    "en": "Sampling",
    "zh-Hant": "取樣",
    "zh-Hans": "采样",
    "de": "Sampling",
    "ar": "المعاينة",
    "ja": "サンプリング",
    "ko": "샘플링",
    "th": "การสุ่มตัวอย่าง",
    "yue-Hant": "取樣",
    "en-SG": "Sampling",
})
add("sampling.duration", {
    "en": "Duration",
    "zh-Hant": "長度",
    "zh-Hans": "时长",
    "de": "Dauer",
    "ar": "المدة",
    "ja": "長さ",
    "ko": "길이",
    "th": "ความยาว",
    "yue-Hant": "長度",
    "en-SG": "How Long",
}, note="How long the finished clip will be, in the Sampling card. A length the user "
        "is choosing. Distinct from library.duration, which reports the length of a "
        "video already made.")
add("sampling.steps", {
    "en": "Steps",
    "zh-Hant": "步數",
    "zh-Hans": "步数",
    "de": "Schritte",
    "ar": "الخطوات",
    "ja": "ステップ数",
    "ko": "스텝 수",
    "th": "จำนวน step",
    "yue-Hant": "步數",
    "en-SG": "How Many Steps",
}, note="Denoising steps — iterations of the sampler. Not stairs, and not steps in a "
        "set of instructions.")
add("sampling.seed.fixed", {
    "en": "Fixed seed",
    "zh-Hant": "固定種子",
    "zh-Hans": "固定种子",
    "de": "Fester Seed",
    "ar": "بذرة ثابتة",
    "ja": "シード固定",
    "ko": "시드 고정",
    "th": "ล็อก seed",
    "yue-Hant": "固定種子",
    "en-SG": "Lock Seed",
}, note="'Seed' is kept in English; the qualifier is translated.")
add("sampling.seed.randomise", {
    "en": "Randomise",
    "zh-Hant": "隨機",
    "zh-Hans": "随机",
    "de": "Zufällig",
    "ar": "عشوائي",
    "ja": "ランダム",
    "ko": "무작위",
    "th": "สุ่ม",
    "yue-Hant": "隨機",
    "en-SG": "Anyhow",
})
add("sampling.seed.note", {
    "en": "A fixed seed makes a render repeatable. Change any other setting and the result "
          "changes anyway.",
    "zh-Hant": "固定種子可讓算圖結果重現。但只要更動其他設定，結果仍然會變。",
    "zh-Hans": "固定种子可让渲染结果重现。但只要改动其他设置，结果仍然会变。",
    "de": "Ein fester Seed macht einen Render wiederholbar. Ändert man eine andere "
          "Einstellung, ändert sich das Ergebnis trotzdem.",
    "ar": "تجعل البذرة الثابتة التصيير قابلًا للتكرار. لكن تغيير أي إعداد آخر يغيّر النتيجة "
          "على أي حال.",
    "ja": "シードを固定すると同じ結果を再現できます。ほかの設定を変えれば、いずれにせよ結果は変わります。",
    "ko": "시드를 고정하면 같은 결과를 다시 낼 수 있습니다. 다른 설정을 바꾸면 결과는 어차피 달라집니다.",
    "th": "การล็อก seed ทำให้เรนเดอร์ซ้ำได้ผลเดิม แต่ถ้าเปลี่ยนค่าอื่นผลลัพธ์ก็เปลี่ยนอยู่ดี",
    "yue-Hant": "固定種子可以令同一次算圖重現。不過你改咗其他設定，個結果一樣會變。",
    "en-SG": "Lock the seed, then the same render can come out again. But you change any other setting, the result still will change anyway.",
})
add("sampling.snapped.exact", {
    "en": "Renders %1$@ frames — exactly %2$@ s at 24 fps.",
    "zh-Hant": "算出 %1$@ 格 — 在 24 fps 下正好 %2$@ 秒。",
    "zh-Hans": "渲染 %1$@ 帧 — 在 24 fps 下正好 %2$@ 秒。",
    "de": "Rendert %1$@ Bilder — exakt %2$@ s bei 24 fps.",
    "ar": "يُصيَّر %1$@ إطارًا — أي %2$@ ثانية بالضبط عند 24 fps.",
    "ja": "%1$@ フレームをレンダリング — 24 fps でちょうど %2$@ 秒です。",
    "ko": "%1$@ 프레임 렌더링 — 24 fps에서 정확히 %2$@ 초입니다.",
    "th": "เรนเดอร์ %1$@ เฟรม — เท่ากับ %2$@ วินาทีพอดีที่ 24 fps",
    "yue-Hant": "算 %1$@ 格 — 24 fps 下啱啱好 %2$@ 秒。",
    "en-SG": "Renders %1$@ frames — exactly %2$@ s at 24 fps.",
})
add("sampling.snapped.inexact", {
    "en": "Renders %1$@ frames — %2$@ s at 24 fps, the nearest length the video VAE can "
          "encode.",
    "zh-Hant": "算出 %1$@ 格 — 在 24 fps 下為 %2$@ 秒，是 video VAE 能編碼的最接近長度。",
    "zh-Hans": "渲染 %1$@ 帧 — 在 24 fps 下为 %2$@ 秒，是 video VAE 能编码的最接近长度。",
    "de": "Rendert %1$@ Bilder — %2$@ s bei 24 fps, die nächstliegende Länge, die die "
          "Video-VAE kodieren kann.",
    "ar": "يُصيَّر %1$@ إطارًا — أي %2$@ ثانية عند 24 fps، وهي أقرب مدة يستطيع video VAE "
          "ترميزها.",
    "ja": "%1$@ フレームをレンダリング — 24 fps で %2$@ 秒。動画 VAE がエンコードできる最も近い長さです。",
    "ko": "%1$@ 프레임 렌더링 — 24 fps에서 %2$@ 초로, 비디오 VAE가 인코딩할 수 있는 가장 가까운 길이입니다.",
    "th": "เรนเดอร์ %1$@ เฟรม — %2$@ วินาทีที่ 24 fps ซึ่งเป็นความยาวใกล้ที่สุดที่ VAE ของวิดีโอเข้ารหัสได้",
    "yue-Hant": "算 %1$@ 格 — 24 fps 下係 %2$@ 秒，係 video VAE 編碼得到最接近嘅長度。",
    "en-SG": "Renders %1$@ frames — %2$@ s at 24 fps, the closest length the video VAE can encode. Cannot be exact one.",
})

# ── Compose summary ──────────────────────────────────────────────────────────
add("summary.render", {
    "en": "This render",
    "zh-Hant": "本次算圖",
    "zh-Hans": "本次渲染",
    "de": "Dieser Render",
    "ar": "هذا التصيير",
    "ja": "このレンダリング",
    "ko": "이번 렌더링",
    "th": "การเรนเดอร์นี้",
    "yue-Hant": "今次算圖",
    "en-SG": "This One",
})
add("summary.task", {
    "en": "Task",
    "zh-Hant": "任務",
    "zh-Hans": "任务",
    "de": "Aufgabe",
    "ar": "المهمة",
    "ja": "タスク",
    "ko": "작업",
    "th": "งาน",
    "yue-Hant": "任務",
    "en-SG": "Task",
}, note="The particular job a checkpoint was trained for — first-frame continuation "
        "or reference conditioning. A machine-learning sense, not a to-do item or a "
        "queued job.")
add("summary.generates", {
    "en": "Generates at",
    "zh-Hant": "生成解析度",
    "zh-Hans": "生成分辨率",
    "de": "Erzeugt mit",
    "ar": "يُولَّد بمقاس",
    "ja": "生成",
    "ko": "생성",
    "th": "สร้างที่",
    "yue-Hant": "生成解析度",
    "en-SG": "Generates at",
})
add("summary.delivers", {
    "en": "Delivered at",
    "zh-Hant": "輸出解析度",
    "zh-Hans": "输出分辨率",
    "de": "Ausgeliefert mit",
    "ar": "يُسلَّم بمقاس",
    "ja": "書き出し",
    "ko": "출력",
    "th": "ส่งออกที่",
    "yue-Hant": "輸出解析度",
    "en-SG": "Delivered at",
})
add("summary.length", {
    "en": "Length",
    "zh-Hant": "長度",
    "zh-Hans": "时长",
    "de": "Länge",
    "ar": "الطول",
    "ja": "長さ",
    "ko": "길이",
    "th": "ความยาว",
    "yue-Hant": "長度",
    "en-SG": "Length",
}, note="The duration of the clip in time. Not physical length, and not the length of "
        "a list. Compare sampling.duration.")
add("summary.bitrate", {
    "en": "Target bitrate",
    "zh-Hant": "目標位元率",
    "zh-Hans": "目标码率",
    "de": "Ziel-Bitrate",
    "ar": "معدل البت المستهدف",
    "ja": "目標ビットレート",
    "ko": "목표 비트레이트",
    "th": "Bitrate เป้าหมาย",
    "yue-Hant": "目標位元率",
    "en-SG": "Target bitrate",
})
add("summary.eta", {
    "en": "Estimated time",
    "zh-Hant": "預估時間",
    "zh-Hans": "预计时间",
    "de": "Geschätzte Dauer",
    "ar": "الوقت المقدَّر",
    "ja": "予想時間",
    "ko": "예상 시간",
    "th": "เวลาโดยประมาณ",
    "yue-Hant": "預估時間",
    "en-SG": "Estimated time",
})
add("summary.eta.noModel", {
    "en": "Select a model",
    "zh-Hant": "請選擇模型",
    "zh-Hans": "请选择模型",
    "de": "Modell wählen",
    "ar": "اختر نموذجًا",
    "ja": "モデルを選択してください",
    "ko": "모델을 선택하세요",
    "th": "เลือกโมเดล",
    "yue-Hant": "揀個模型先",
    "en-SG": "Choose model first lah",
})
add("summary.problems", {
    "en": "Before you generate",
    "zh-Hant": "生成前請確認",
    "zh-Hans": "生成前请确认",
    "de": "Vor dem Erzeugen",
    "ar": "قبل التوليد",
    "ja": "生成する前に",
    "ko": "생성하기 전에",
    "th": "ก่อนเริ่มสร้าง",
    "yue-Hant": "生成前睇下",
    "en-SG": "Check First Leh",
})
add("summary.models", {
    "en": "Models",
    "zh-Hant": "模型",
    "zh-Hans": "模型",
    "de": "Modelle",
    "ar": "النماذج",
    "ja": "モデル",
    "ko": "모델",
    "th": "โมเดล",
    "yue-Hant": "模型",
    "en-SG": "Models",
}, note="Heads the list of weights a render will load, in the Compose summary. Means "
        "these specific files, not the tab and not the folder.")
add("summary.transformer", {
    "en": "Transformer",
    "zh-Hant": "Transformer",
    "zh-Hans": "Transformer",
    "de": "Transformer",
    "ar": "Transformer",
    "ja": "トランスフォーマー",
    "ko": "트랜스포머",
    "th": "Transformer",
    "yue-Hant": "Transformer",
    "en-SG": "Transformer",
}, note="Architecture name; left in English.")
add("summary.textEncoder", {
    "en": "Text encoder",
    "zh-Hant": "文字編碼器",
    "zh-Hans": "文本编码器",
    "de": "Text-Encoder",
    "ar": "مُرمِّز النص",
    "ja": "テキストエンコーダ",
    "ko": "텍스트 인코더",
    "th": "ตัวเข้ารหัสข้อความ",
    "yue-Hant": "文字編碼器",
    "en-SG": "Text encoder",
}, note="Names the encoder chosen for this render, in the Compose summary. A "
        "particular file; role.textEncoder is the category.")
add("summary.notSelected", {
    "en": "Not selected",
    "zh-Hant": "未選擇",
    "zh-Hans": "未选择",
    "de": "Nicht gewählt",
    "ar": "لم يُحدَّد",
    "ja": "未選択",
    "ko": "선택 안 됨",
    "th": "ยังไม่ได้เลือก",
    "yue-Hant": "未揀",
    "en-SG": "Never Choose",
})
add("summary.chooseInModels", {
    "en": "Choose in Models…",
    "zh-Hant": "在「模型」中選擇…",
    "zh-Hans": "在“模型”中选择…",
    "de": "Unter „Modelle“ wählen …",
    "ar": "اختر من «النماذج»…",
    "ja": "「モデル」で選択…",
    "ko": "모델에서 선택…",
    "th": "เลือกในโมเดล…",
    "yue-Hant": "喺「模型」度揀…",
    "en-SG": "Go Models and choose…",
})
add("summary.engineNotReady", {
    "en": "Engine not ready",
    "zh-Hant": "引擎尚未就緒",
    "zh-Hans": "引擎尚未就绪",
    "de": "Engine nicht bereit",
    "ar": "المحرّك غير جاهز",
    "ja": "エンジンが未準備",
    "ko": "엔진 준비 안 됨",
    "th": "Engine ยังไม่พร้อม",
    "yue-Hant": "引擎未 ready",
    "en-SG": "Engine not ready yet",
})

# ── Queue ────────────────────────────────────────────────────────────────────
add("queue.empty.title", {
    "en": "Nothing queued",
    "zh-Hant": "佇列是空的",
    "zh-Hans": "队列是空的",
    "de": "Nichts in der Warteschlange",
    "ar": "لا شيء في قائمة الانتظار",
    "ja": "キューは空です",
    "ko": "대기열이 비어 있음",
    "th": "ไม่มีรายการในคิว",
    "yue-Hant": "佇列空空如也",
    "en-SG": "Queue empty leh",
})
add("queue.empty.detail", {
    "en": "Renders you start from Compose appear here. They keep running while you work, "
          "and survive quitting the app.",
    "zh-Hant": "從「編寫」開始的算圖會出現在這裡。它們會在你工作時持續執行，即使結束 App 也不會中斷。",
    "zh-Hans": "从“编写”开始的渲染会出现在这里。它们会在你工作时持续运行，即使退出 App 也不会中断。",
    "de": "Renders, die du unter „Erstellen“ startest, erscheinen hier. Sie laufen weiter, "
          "während du arbeitest, und überstehen das Beenden der App.",
    "ar": "تظهر هنا عمليات التصيير التي تبدأها من «إنشاء». تستمر أثناء عملك، وتبقى حتى بعد "
          "إغلاق التطبيق.",
    "ja": "「作成」から始めたレンダリングがここに並びます。作業中も動き続け、アプリを終了しても残ります。",
    "ko": "작성 화면에서 시작한 렌더링이 여기 나타납니다. 다른 작업을 하는 동안에도 계속 돌아가며, 앱을 종료해도 남습니다.",
    "th": "การเรนเดอร์ที่เริ่มจากหน้าเรียบเรียงจะมาอยู่ที่นี่ ทำงานต่อไปขณะคุณใช้งานอย่างอื่น และยังอยู่แม้ปิดแอป",
    "yue-Hant": "你喺「編寫」度開始嘅算圖會喺呢度出現。你做緊嘢佢照跑,收咗 App 都仲喺度。",
    "en-SG": "Renders you start from New Video will appear here. They keep running while you go and do other things, and even after you quit the app they still there.",
})
add("queue.goCompose", {
    "en": "Go to Compose",
    "zh-Hant": "前往「編寫」",
    "zh-Hans": "前往“编写”",
    "de": "Zu „Erstellen“",
    "ar": "الانتقال إلى «إنشاء»",
    "ja": "「作成」へ",
    "ko": "작성으로 이동",
    "th": "ไปที่หน้าเรียบเรียง",
    "yue-Hant": "去「編寫」",
    "en-SG": "Go New Video",
})
add("queue.clearFinished", {
    "en": "Clear Finished",
    "zh-Hant": "清除已完成",
    "zh-Hans": "清除已完成",
    "de": "Fertige entfernen",
    "ar": "مسح المكتملة",
    "ja": "完了分を消去",
    "ko": "완료 항목 지우기",
    "th": "ล้างรายการที่เสร็จแล้ว",
    "yue-Hant": "清走完成嘅",
    "en-SG": "Clear Finish One",
}, note="Removes finished jobs from the render queue. The English matches "
        "models.clearFinished exactly but the object differs — jobs, not downloads — "
        "and languages that inflect the verb for its object will need different "
        "wording.")
add("queue.clearFinished.help", {
    "en": "Remove finished, failed and cancelled renders from this list",
    "zh-Hant": "從清單移除已完成、失敗與已取消的算圖",
    "zh-Hans": "从列表移除已完成、失败与已取消的渲染",
    "de": "Fertige, fehlgeschlagene und abgebrochene Renders aus dieser Liste entfernen",
    "ar": "إزالة عمليات التصيير المكتملة والفاشلة والملغاة من هذه القائمة",
    "ja": "完了・失敗・キャンセルされたレンダリングをこの一覧から取り除きます",
    "ko": "완료, 실패, 취소된 렌더링을 이 목록에서 제거합니다",
    "th": "เอาการเรนเดอร์ที่เสร็จ ล้มเหลว และถูกยกเลิกออกจากรายการนี้",
    "yue-Hant": "將完成、失敗同取消咗嘅算圖喺呢個清單度移走",
    "en-SG": "Take the finished, failed and cancelled renders off this list",
})
add("queue.runtimeWarning", {
    "en": "The Python runtime is not ready, so queued renders cannot start.",
    "zh-Hant": "Python 執行環境尚未就緒，佇列中的算圖無法開始。",
    "zh-Hans": "Python 运行环境尚未就绪，队列中的渲染无法开始。",
    "de": "Die Python-Laufzeitumgebung ist nicht bereit, daher können wartende Renders "
          "nicht starten.",
    "ar": "بيئة تشغيل Python غير جاهزة، لذا لا يمكن بدء عمليات التصيير المنتظرة.",
    "ja": "Python 実行環境が準備できていないため、待機中のレンダリングを開始できません。",
    "ko": "Python 런타임이 준비되지 않아 대기 중인 렌더링을 시작할 수 없습니다.",
    "th": "Runtime Python ยังไม่พร้อม การเรนเดอร์ในคิวจึงเริ่มไม่ได้",
    "yue-Hant": "Python 執行環境未 ready,所以排緊隊嘅算圖開唔到。",
    "en-SG": "Python runtime not ready, so the renders waiting inside the queue all cannot start.",
})
add("queue.openSettings", {
    "en": "Open Settings",
    "zh-Hant": "開啟設定",
    "zh-Hans": "打开设置",
    "de": "Einstellungen öffnen",
    "ar": "فتح الإعدادات",
    "ja": "設定を開く",
    "ko": "설정 열기",
    "th": "เปิดการตั้งค่า",
    "yue-Hant": "開設定",
    "en-SG": "Open Settings",
})
add("queue.hold", {
    "en": "Hold",
    "zh-Hant": "暫緩",
    "zh-Hans": "暂缓",
    "de": "Zurückstellen",
    "ar": "تعليق",
    "ja": "保留",
    "ko": "보류",
    "th": "พักไว้",
    "yue-Hant": "暫緩",
    "en-SG": "Hold First",
}, note="Imperative verb on a button: keep this job in the queue but do not start it. "
        "The opposite of queue.release. Not the noun \"a hold\", and not \"hold\" as in "
        "grip.")
add("queue.release", {
    "en": "Release",
    "zh-Hant": "恢復",
    "zh-Hans": "恢复",
    "de": "Freigeben",
    "ar": "استئناف",
    "ja": "再開",
    "ko": "해제",
    "th": "ปล่อย",
    "yue-Hant": "恢復",
    "en-SG": "Let It Go",
}, note="Imperative verb: let a held job run again. The opposite of queue.hold. NOT a "
        "software release or version — a common and damaging mistranslation.")
add("queue.hold.help", {
    "en": "Hold this render back",
    "zh-Hant": "暫緩這次算圖",
    "zh-Hans": "暂缓这次渲染",
    "de": "Diesen Render zurückstellen",
    "ar": "تعليق هذا التصيير",
    "ja": "このレンダリングの開始を止めておきます",
    "ko": "이 렌더링을 시작하지 않도록 붙잡아 둡니다",
    "th": "หน่วงการเรนเดอร์นี้ไว้ก่อน",
    "yue-Hant": "暫緩呢次算圖",
    "en-SG": "Hold this render back first",
})
add("queue.release.help", {
    "en": "Allow this render to start",
    "zh-Hant": "允許這次算圖開始",
    "zh-Hans": "允许这次渲染开始",
    "de": "Diesen Render starten lassen",
    "ar": "السماح ببدء هذا التصيير",
    "ja": "このレンダリングの開始を許可します",
    "ko": "이 렌더링이 시작되도록 허용합니다",
    "th": "อนุญาตให้การเรนเดอร์นี้เริ่มได้",
    "yue-Hant": "俾呢次算圖開始",
    "en-SG": "Let this render start",
})
add("queue.moveToFront", {
    "en": "Move to Front",
    "zh-Hant": "移到最前",
    "zh-Hans": "移到最前",
    "de": "Nach vorne verschieben",
    "ar": "نقل إلى المقدمة",
    "ja": "先頭へ移動",
    "ko": "맨 앞으로 이동",
    "th": "ย้ายไปต้นคิว",
    "yue-Hant": "插隊到最前",
    "en-SG": "Cut Queue to Front",
})
add("queue.stop", {
    "en": "Stop",
    "zh-Hant": "停止",
    "zh-Hans": "停止",
    "de": "Anhalten",
    "ar": "إيقاف",
    "ja": "停止",
    "ko": "정지",
    "th": "หยุด",
    "yue-Hant": "停止",
    "en-SG": "Stop",
}, note="Imperative verb: cancel the render that is running. Not \"pause\"; the work is "
        "discarded.")
add("queue.stop.help", {
    "en": "Stop this render. Progress is lost — a render cannot be resumed.",
    "zh-Hant": "停止這次算圖。進度會遺失，算圖無法續算。",
    "zh-Hans": "停止这次渲染。进度会丢失，渲染无法续算。",
    "de": "Diesen Render anhalten. Der Fortschritt geht verloren — ein Render lässt sich "
          "nicht fortsetzen.",
    "ar": "إيقاف هذا التصيير. سيضيع التقدّم، إذ لا يمكن استئناف التصيير.",
    "ja": "このレンダリングを停止します。途中経過は失われ、再開はできません。",
    "ko": "이 렌더링을 정지합니다. 진행분은 사라지며 이어서 할 수 없습니다.",
    "th": "หยุดการเรนเดอร์นี้ ความคืบหน้าจะหายไปและเริ่มต่อไม่ได้",
    "yue-Hant": "停止呢次算圖。進度會冇咗,算圖係續唔到嘅。",
    "en-SG": "Stop this render. Progress all gone one — cannot sambung after that. Think first ah.",
})
add("queue.renderAgain", {
    "en": "Render Again",
    "zh-Hant": "重新算圖",
    "zh-Hans": "重新渲染",
    "de": "Erneut rendern",
    "ar": "إعادة التصيير",
    "ja": "もう一度レンダリング",
    "ko": "다시 렌더링",
    "th": "เรนเดอร์อีกครั้ง",
    "yue-Hant": "再算一次",
    "en-SG": "Render Again",
})
add("queue.renderAgain.help", {
    "en": "Queue this again with a new seed",
    "zh-Hant": "以新的種子重新排入佇列",
    "zh-Hans": "以新的种子重新排入队列",
    "de": "Erneut mit neuem Seed einreihen",
    "ar": "إعادة الإدراج ببذرة جديدة",
    "ja": "新しいシードでもう一度キューに入れます",
    "ko": "새 시드로 다시 대기열에 넣습니다",
    "th": "เข้าคิวอีกครั้งด้วย seed ใหม่",
    "yue-Hant": "換個新種子再排入佇列",
    "en-SG": "Queue this again with a new seed",
})
add("queue.reproduce", {
    "en": "Reproduce Exactly",
    "zh-Hant": "完全重現",
    "zh-Hans": "完全重现",
    "de": "Exakt reproduzieren",
    "ar": "إعادة إنتاج مطابقة",
    "ja": "まったく同じに再現",
    "ko": "똑같이 재현",
    "th": "ทำซ้ำให้เหมือนเดิม",
    "yue-Hant": "一模一樣咁再算",
    "en-SG": "Same Same Exactly",
})
add("queue.editCopy", {
    "en": "Edit a Copy",
    "zh-Hant": "編輯副本",
    "zh-Hans": "编辑副本",
    "de": "Kopie bearbeiten",
    "ar": "تحرير نسخة",
    "ja": "複製して編集",
    "ko": "복사본 편집",
    "th": "แก้ไขสำเนา",
    "yue-Hant": "改個副本",
    "en-SG": "Edit a Copy",
})
add("queue.showLog", {
    "en": "Show Log",
    "zh-Hant": "顯示記錄",
    "zh-Hans": "显示日志",
    "de": "Protokoll anzeigen",
    "ar": "عرض السجل",
    "ja": "ログを表示",
    "ko": "로그 보기",
    "th": "ดูบันทึก",
    "yue-Hant": "睇記錄",
    "en-SG": "See Log",
})
add("queue.log.help", {
    "en": "Show this render's log",
    "zh-Hant": "顯示這次算圖的記錄",
    "zh-Hans": "显示这次渲染的日志",
    "de": "Protokoll dieses Renders anzeigen",
    "ar": "عرض سجل هذا التصيير",
    "ja": "このレンダリングのログを表示します",
    "ko": "이 렌더링의 로그를 봅니다",
    "th": "ดูบันทึกของการเรนเดอร์นี้",
    "yue-Hant": "睇呢次算圖嘅記錄",
    "en-SG": "See this render's log",
})
add("queue.revealInFinder", {
    "en": "Reveal in Finder",
    "zh-Hant": "在 Finder 中顯示",
    "zh-Hans": "在 Finder 中显示",
    "de": "Im Finder zeigen",
    "ar": "إظهار في Finder",
    "ja": "Finder に表示",
    "ko": "Finder에서 보기",
    "th": "แสดงใน Finder",
    "yue-Hant": "喺 Finder 度顯示",
    "en-SG": "Show in Finder",
})
add("queue.remove", {
    "en": "Remove from Queue",
    "zh-Hant": "從佇列移除",
    "zh-Hans": "从队列移除",
    "de": "Aus Warteschlange entfernen",
    "ar": "إزالة من قائمة الانتظار",
    "ja": "キューから削除",
    "ko": "대기열에서 제거",
    "th": "เอาออกจากคิว",
    "yue-Hant": "喺佇列度移走",
    "en-SG": "Take Out From Queue",
})
add("queue.held", {
    "en": "Held — will not start until released",
    "zh-Hant": "已暫緩，恢復後才會開始",
    "zh-Hans": "已暂缓，恢复后才会开始",
    "de": "Zurückgestellt — startet erst nach Freigabe",
    "ar": "معلّق — لن يبدأ حتى يُستأنف",
    "ja": "保留中 — 解除するまで開始しません",
    "ko": "보류됨 — 해제할 때까지 시작하지 않습니다",
    "th": "พักไว้ — จะยังไม่เริ่มจนกว่าจะปล่อย",
    "yue-Hant": "暫緩咗 — 恢復先會開始",
    "en-SG": "On hold — won't start until you release",
})
add("queue.nextUp", {
    "en": "Next up",
    "zh-Hant": "下一個",
    "zh-Hans": "下一个",
    "de": "Als Nächstes",
    "ar": "التالي",
    "ja": "次はこれ",
    "ko": "다음 차례",
    "th": "ลำดับถัดไป",
    "yue-Hant": "下一個",
    "en-SG": "Next one",
})
add("queue.ahead", {
    "en": "Queued — %@ ahead",
    "zh-Hant": "等待中 — 前面還有 %@",
    "zh-Hans": "等待中 — 前面还有 %@",
    "de": "In Warteschlange — %@ davor",
    "ar": "في الانتظار — %@ قبله",
    "ja": "待機中 — 前に %@ 件",
    "ko": "대기 중 — 앞에 %@ 개",
    "th": "อยู่ในคิว — มีอีก %@ รายการก่อนหน้า",
    "yue-Hant": "排緊隊 — 前面仲有 %@",
    "en-SG": "Waiting — %@ in front",
}, note={
    "content": "Takes a count of jobs waiting in front of this one. The count is 1 whenever a "
               "single job is ahead, which is the common case, so plural-sensitive languages "
               "will read wrongly here.",
    "level": WARNING,
})
add("queue.took", {
    "en": "Took %@",
    "zh-Hant": "耗時 %@",
    "zh-Hans": "耗时 %@",
    "de": "Dauerte %@",
    "ar": "استغرق %@",
    "ja": "所要 %@",
    "ko": "%@ 걸림",
    "th": "ใช้เวลา %@",
    "yue-Hant": "用咗 %@",
    "en-SG": "Took %@",
})
add("queue.step", {
    "en": "step %1$@ of %2$@",
    "zh-Hant": "第 %1$@ 步，共 %2$@ 步",
    "zh-Hans": "第 %1$@ 步，共 %2$@ 步",
    "de": "Schritt %1$@ von %2$@",
    "ar": "الخطوة %1$@ من %2$@",
    "ja": "ステップ %2$@ 中 %1$@",
    "ko": "%2$@ 스텝 중 %1$@",
    "th": "step ที่ %1$@ จาก %2$@",
    "yue-Hant": "第 %1$@ 步，共 %2$@ 步",
    "en-SG": "step %1$@ of %2$@",
})
add("queue.perStep", {
    "en": "%@/step",
    "zh-Hant": "%@/步",
    "zh-Hans": "%@/步",
    "de": "%@/Schritt",
    "ar": "%@/خطوة",
    "ja": "%@/ステップ",
    "ko": "%@/스텝",
    "th": "%@/ step",
    "yue-Hant": "%@/步",
    "en-SG": "%@/step",
})
add("queue.peak", {
    "en": "%@ peak",
    "zh-Hant": "尖峰 %@",
    "zh-Hans": "峰值 %@",
    "de": "%@ Spitze",
    "ar": "الذروة %@",
    "ja": "ピーク %@",
    "ko": "최대 %@",
    "th": "สูงสุด %@",
    "yue-Hant": "最高 %@",
    "en-SG": "%@ highest",
})
add("queue.remaining", {
    "en": "%@ remaining",
    "zh-Hant": "剩餘 %@",
    "zh-Hans": "剩余 %@",
    "de": "noch %@",
    "ar": "يتبقى %@",
    "ja": "残り %@",
    "ko": "%@ 남음",
    "th": "เหลือ %@",
    "yue-Hant": "仲爭 %@",
    "en-SG": "%@ more",
})
add("queue.remainingUnknown", {
    "en": "remaining unknown until generation starts",
    "zh-Hant": "開始生成前無法估算剩餘時間",
    "zh-Hans": "开始生成前无法估算剩余时间",
    "de": "Restzeit erst ab Beginn der Erzeugung bekannt",
    "ar": "الوقت المتبقي غير معروف حتى يبدأ التوليد",
    "ja": "生成が始まるまで残り時間は不明です",
    "ko": "생성이 시작되기 전까지는 남은 시간을 알 수 없습니다",
    "th": "ยังไม่ทราบเวลาที่เหลือจนกว่าการสร้างจะเริ่ม",
    "yue-Hant": "未開始生成之前估唔到仲要幾耐",
    "en-SG": "Cannot say how long more until it starts generating — see how lah",
})
add("queue.log.title", {
    "en": "Render log",
    "zh-Hant": "算圖記錄",
    "zh-Hans": "渲染日志",
    "de": "Render-Protokoll",
    "ar": "سجل التصيير",
    "ja": "レンダリングログ",
    "ko": "렌더링 로그",
    "th": "บันทึกการเรนเดอร์",
    "yue-Hant": "算圖記錄",
    "en-SG": "Render log",
})
add("queue.log.copyAll", {
    "en": "Copy All",
    "zh-Hant": "全部拷貝",
    "zh-Hans": "全部复制",
    "de": "Alles kopieren",
    "ar": "نسخ الكل",
    "ja": "すべてコピー",
    "ko": "전체 복사",
    "th": "คัดลอกทั้งหมด",
    "yue-Hant": "全部拷貝",
    "en-SG": "Copy All",
})
add("queue.log.empty.title", {
    "en": "No log yet",
    "zh-Hant": "尚無記錄",
    "zh-Hans": "尚无日志",
    "de": "Noch kein Protokoll",
    "ar": "لا يوجد سجل بعد",
    "ja": "ログはまだありません",
    "ko": "아직 로그가 없음",
    "th": "ยังไม่มีบันทึก",
    "yue-Hant": "暫時未有記錄",
    "en-SG": "No log yet",
})
add("queue.log.empty.detail", {
    "en": "Output appears here once this render starts. Logs are kept for the current "
          "session.",
    "zh-Hant": "算圖開始後輸出會顯示在這裡。記錄只保留本次工作階段。",
    "zh-Hans": "渲染开始后输出会显示在这里。日志只保留本次会话。",
    "de": "Sobald dieser Render startet, erscheint die Ausgabe hier. Protokolle gelten nur "
          "für die aktuelle Sitzung.",
    "ar": "يظهر الإخراج هنا فور بدء التصيير. تُحفظ السجلات للجلسة الحالية فقط.",
    "ja": "このレンダリングが始まると、ここに出力が表示されます。ログは今回のセッション中だけ保持されます。",
    "ko": "이 렌더링이 시작되면 출력이 여기에 표시됩니다. 로그는 현재 세션 동안만 보관됩니다.",
    "th": "ผลลัพธ์จะปรากฏที่นี่เมื่อการเรนเดอร์เริ่มขึ้น บันทึกจะเก็บไว้เฉพาะเซสชันนี้",
    "yue-Hant": "呢次算圖開始咗就會喺呢度出輸出。記錄淨係留到今次開住嘅時間。",
    "en-SG": "Output only show here after this render starts. Logs keep for this session only.",
})

# ── Library ──────────────────────────────────────────────────────────────────
add("library.empty.title", {
    "en": "No videos yet",
    "zh-Hant": "還沒有影片",
    "zh-Hans": "还没有视频",
    "de": "Noch keine Videos",
    "ar": "لا توجد مقاطع بعد",
    "ja": "動画はまだありません",
    "ko": "아직 비디오가 없음",
    "th": "ยังไม่มีวิดีโอ",
    "yue-Hant": "仲未有片",
    "en-SG": "No video yet",
})
add("library.empty.detail", {
    "en": "Finished renders are saved to %@, each with a JSON file recording the exact "
          "settings that produced it.",
    "zh-Hant": "完成的算圖會存到 %@，每支影片都附一個 JSON 檔，記下產生它的完整設定。",
    "zh-Hans": "完成的渲染会保存到 %@，每个视频都附一个 JSON 文件，记录生成它的完整设置。",
    "de": "Fertige Renderings werden unter %@ gesichert, jeweils mit einer JSON-Datei, die "
          "die genauen Einstellungen festhält.",
    "ar": "تُحفظ عمليات التصيير المنجزة في %@، مع ملف JSON لكل منها يسجّل الإعدادات التي "
          "أنتجته بالضبط.",
    "ja": "完了したレンダリングは %@ に保存され、生成時の設定を記録した JSON ファイルが一緒に付きます。",
    "ko": "완료된 렌더링은 %@ 에 저장되며, 생성 당시 설정을 기록한 JSON 파일이 함께 붙습니다.",
    "th": "งานที่เรนเดอร์เสร็จจะถูกบันทึกไว้ที่ %@ พร้อมไฟล์ JSON ที่บันทึกการตั้งค่าที่ใช้สร้างไว้ด้วย",
    "yue-Hant": "算好嘅片會存去 %@,每條都附個 JSON 檔,記低整佢出嚟嗰陣嘅完整設定。",
    "en-SG": "Finish already, then the render go inside %@, each one with a JSON file recording the exact settings that made it.",
})
add("library.search", {
    "en": "Search prompts",
    "zh-Hant": "搜尋提示詞",
    "zh-Hans": "搜索提示词",
    "de": "Prompts durchsuchen",
    "ar": "البحث في الموجّهات",
    "ja": "プロンプトを検索",
    "ko": "프롬프트 검색",
    "th": "ค้นหา prompt",
    "yue-Hant": "搵提示詞",
    "en-SG": "Search prompts",
})
add("library.revealFolder", {
    "en": "Reveal Folder",
    "zh-Hant": "顯示資料夾",
    "zh-Hans": "显示文件夹",
    "de": "Ordner anzeigen",
    "ar": "إظهار المجلد",
    "ja": "フォルダを表示",
    "ko": "폴더 보기",
    "th": "แสดงโฟลเดอร์",
    "yue-Hant": "顯示資料夾",
    "en-SG": "Show Folder",
})
add("library.open", {
    "en": "Open",
    "zh-Hant": "打開",
    "zh-Hans": "打开",
    "de": "Öffnen",
    "ar": "فتح",
    "ja": "開く",
    "ko": "열기",
    "th": "เปิด",
    "yue-Hant": "打開",
    "en-SG": "Open",
}, note="Imperative verb: open the finished video in another app. Not the adjective.")
add("library.useSettings", {
    "en": "Use These Settings",
    "zh-Hant": "沿用這些設定",
    "zh-Hans": "沿用这些设置",
    "de": "Diese Einstellungen übernehmen",
    "ar": "استخدام هذه الإعدادات",
    "ja": "この設定を使う",
    "ko": "이 설정 사용",
    "th": "ใช้การตั้งค่านี้",
    "yue-Hant": "沿用呢啲設定",
    "en-SG": "Use These Settings",
})
add("library.moveToTrash", {
    "en": "Move to Trash",
    "zh-Hant": "移到垃圾桶",
    "zh-Hans": "移到废纸篓",
    "de": "In den Papierkorb legen",
    "ar": "نقل إلى المهملات",
    "ja": "ゴミ箱に入れる",
    "ko": "휴지통으로 옮기기",
    "th": "ย้ายไปถังขยะ",
    "yue-Hant": "掉入垃圾桶",
    "en-SG": "Throw Into Trash",
}, note="macOS calls it 垃圾桶 in TW, 废纸篓 in CN.")
add("library.revealWav", {
    "en": "Reveal WAV",
    "zh-Hant": "顯示 WAV",
    "zh-Hans": "显示 WAV",
    "de": "WAV anzeigen",
    "ar": "إظهار ملف WAV",
    "ja": "WAV を表示",
    "ko": "WAV 보기",
    "th": "แสดงไฟล์ WAV",
    "yue-Hant": "顯示 WAV",
    "en-SG": "Show WAV",
})
add("library.settings", {
    "en": "Settings",
    "zh-Hant": "設定",
    "zh-Hans": "设置",
    "de": "Einstellungen",
    "ar": "الإعدادات",
    "ja": "設定",
    "ko": "설정",
    "th": "การตั้งค่า",
    "yue-Hant": "設定",
    "en-SG": "Settings",
})
add("library.duration", {
    "en": "Duration",
    "zh-Hant": "長度",
    "zh-Hans": "时长",
    "de": "Dauer",
    "ar": "المدة",
    "ja": "再生時間",
    "ko": "재생 시간",
    "th": "ความยาว",
    "yue-Hant": "長度",
    "en-SG": "How Long",
}, note="A Library column giving the length of a finished video. Reports a fact; "
        "sampling.duration sets a target.")
add("library.seed", {
    "en": "Seed",
    "zh-Hant": "種子",
    "zh-Hans": "种子",
    "de": "Seed",
    "ar": "البذرة",
    "ja": "シード",
    "ko": "시드",
    "th": "Seed",
    "yue-Hant": "種子",
    "en-SG": "Seed",
}, note="The random seed that determines a render's noise. A number, not a plant "
        "seed. Most languages keep the English term or transliterate it.")
add("library.filesize", {
    "en": "File size",
    "zh-Hant": "檔案大小",
    "zh-Hans": "文件大小",
    "de": "Dateigröße",
    "ar": "حجم الملف",
    "ja": "ファイルサイズ",
    "ko": "파일 크기",
    "th": "ขนาดไฟล์",
    "yue-Hant": "檔案大細",
    "en-SG": "File size",
})
add("library.renderTime", {
    "en": "Render time",
    "zh-Hant": "算圖時間",
    "zh-Hans": "渲染时间",
    "de": "Renderdauer",
    "ar": "زمن التصيير",
    "ja": "レンダリング時間",
    "ko": "렌더링 시간",
    "th": "เวลาที่ใช้เรนเดอร์",
    "yue-Hant": "算圖時間",
    "en-SG": "Render time",
})
add("library.mode", {
    "en": "Mode",
    "zh-Hant": "模式",
    "zh-Hans": "模式",
    "de": "Modus",
    "ar": "الوضع",
    "ja": "モード",
    "ko": "모드",
    "th": "โหมด",
    "yue-Hant": "模式",
    "en-SG": "Mode",
}, note="A column in the Library listing which mode produced a finished video. "
        "Reporting a past fact, where compose.mode.title is a control. Some languages "
        "prefer different words for the two.")
add("library.missing", {
    "en": "This file is no longer on disk",
    "zh-Hant": "這個檔案已不在磁碟上",
    "zh-Hans": "这个文件已不在磁盘上",
    "de": "Diese Datei ist nicht mehr auf dem Volume",
    "ar": "لم يعد هذا الملف موجودًا على القرص",
    "ja": "このファイルはディスク上にもうありません",
    "ko": "이 파일은 디스크에 더 이상 없습니다",
    "th": "ไม่มีไฟล์นี้อยู่บนดิสก์แล้ว",
    "yue-Hant": "呢個檔案已經唔喺碟度",
    "en-SG": "This file not on the disk anymore",
})
add("library.copySeed", {
    "en": "Copy %@",
    "zh-Hant": "拷貝%@",
    "zh-Hans": "复制%@",
    "de": "%@ kopieren",
    "ar": "نسخ %@",
    "ja": "%@ をコピー",
    "ko": "%@ 복사",
    "th": "คัดลอก %@",
    "yue-Hant": "拷貝%@",
    "en-SG": "Copy %@",
}, note={
    "content": "Injects a name into a sentence. Languages that inflect a noun for case, choose "
               "an article by gender, or attach a vowel-harmonising suffix cannot do it without "
               "knowing the word, and it is only known at runtime. Prefer wording that sets the "
               "name apart — quoted, or on its own line.",
    "level": WARNING,
})
add("library.copied", {
    "en": "Copied",
    "zh-Hant": "已拷貝",
    "zh-Hans": "已复制",
    "de": "Kopiert",
    "ar": "تم النسخ",
    "ja": "コピーしました",
    "ko": "복사됨",
    "th": "คัดลอกแล้ว",
    "yue-Hant": "拷貝咗",
    "en-SG": "Copied already",
})
add("library.seconds", {
    "en": "%@ seconds",
    "zh-Hant": "%@ 秒",
    "zh-Hans": "%@ 秒",
    "de": "%@ Sekunden",
    "ar": "%@ ثانية",
    "ja": "%@ 秒",
    "ko": "%@ 초",
    "th": "%@ วินาที",
    "yue-Hant": "%@ 秒",
    "en-SG": "%@ seconds",
}, note={
    "content": "Takes a count. English offers only two forms and this string supplies one, so \"1 "
               "seconds\" is already wrong; Arabic needs six categories and settles for a single "
               "compromise form. Any language with Slavic-style plurals will need a .stringsdict "
               "before this can be translated correctly.",
    "level": WARNING,
})

# ── Models ───────────────────────────────────────────────────────────────────
add("models.folder.title", {
    "en": "Shared models folder",
    "zh-Hant": "共用模型資料夾",
    "zh-Hans": "共享模型文件夹",
    "de": "Gemeinsamer Modellordner",
    "ar": "مجلد النماذج المشترك",
    "ja": "共有モデルフォルダ",
    "ko": "공유 모델 폴더",
    "th": "โฟลเดอร์โมเดลที่ใช้ร่วมกัน",
    "yue-Hant": "共用模型資料夾",
    "en-SG": "Shared models folder",
})
add("models.folder.footnote", {
    "en": "Downloads go into the Hugging Face cache inside this folder. Any other project "
          "pointed at the same folder reuses them instead of downloading a second copy.",
    "zh-Hant": "下載內容會放進這個資料夾裡的 Hugging Face 快取。任何指向同一資料夾的其他專案都能直接重用，不必再下載一份。",
    "zh-Hans": "下载内容会放进这个文件夹里的 Hugging Face 缓存。任何指向同一文件夹的其他项目都能直接重用，不必再下载一份。",
    "de": "Downloads landen im Hugging-Face-Cache in diesem Ordner. Jedes andere Projekt, "
          "das auf denselben Ordner zeigt, verwendet sie weiter, statt eine zweite Kopie zu "
          "laden.",
    "ar": "تُحفظ التنزيلات في ذاكرة Hugging Face المؤقتة داخل هذا المجلد. وأي مشروع آخر "
          "موجَّه إلى المجلد نفسه يعيد استخدامها بدل تنزيل نسخة ثانية.",
    "ja": "ダウンロードはこのフォルダ内の Hugging Face キャッシュに入ります。同じフォルダを指す他のプロジェクトは、二重にダウンロードせずそれを再利用します。",
    "ko": "다운로드는 이 폴더 안의 Hugging Face 캐시에 들어갑니다. 같은 폴더를 가리키는 다른 프로젝트는 다시 내려받지 않고 그대로 씁니다.",
    "th": "ไฟล์ที่ดาวน์โหลดจะไปอยู่ใน cache Hugging Face ภายในโฟลเดอร์นี้ โปรเจกต์อื่นที่ชี้มาที่โฟลเดอร์เดียวกันจะใช้ซ้ำแทนการดาวน์โหลดอีกชุด",
    "yue-Hant": "下載嘅嘢會入呢個資料夾裡面嘅 Hugging Face 快取。任何指住同一個資料夾嘅專案都會直接用返,唔使再下載多份。",
    "en-SG": "Downloads go inside the Hugging Face cache in this folder. Any other project pointing at the same folder just tompang the same files, no need download a second copy.",
})
add("models.change", {
    "en": "Change…",
    "zh-Hant": "更改…",
    "zh-Hans": "更改…",
    "de": "Ändern …",
    "ar": "تغيير…",
    "ja": "変更…",
    "ko": "변경…",
    "th": "เปลี่ยน…",
    "yue-Hant": "改…",
    "en-SG": "Change…",
})
add("models.installed", {
    "en": "Installed",
    "zh-Hant": "已安裝",
    "zh-Hans": "已安装",
    "de": "Installiert",
    "ar": "مثبَّت",
    "ja": "インストール済み",
    "ko": "설치됨",
    "th": "ติดตั้งแล้ว",
    "yue-Hant": "裝咗",
    "en-SG": "Install already",
})
add("models.freeSpace", {
    "en": "Free space",
    "zh-Hant": "可用空間",
    "zh-Hans": "可用空间",
    "de": "Freier Speicher",
    "ar": "المساحة الحرة",
    "ja": "空き容量",
    "ko": "남은 공간",
    "th": "พื้นที่ว่าง",
    "yue-Hant": "可用空間",
    "en-SG": "Space left",
})
add("models.found", {
    "en": "Models found",
    "zh-Hant": "找到的模型",
    "zh-Hans": "找到的模型",
    "de": "Gefundene Modelle",
    "ar": "النماذج المعثور عليها",
    "ja": "見つかったモデル",
    "ko": "찾은 모델",
    "th": "โมเดลที่พบ",
    "yue-Hant": "搵到嘅模型",
    "en-SG": "Models found",
})
add("models.spaceWarning", {
    "en": "The recommended set needs about %@, plus scratch space while rendering.",
    "zh-Hant": "建議的組合約需 %@，算圖時還需要額外的暫存空間。",
    "zh-Hans": "建议的组合约需 %@，渲染时还需要额外的暂存空间。",
    "de": "Der empfohlene Satz benötigt etwa %@, zuzüglich Arbeitsspeicherplatz beim "
          "Rendern.",
    "ar": "تحتاج المجموعة الموصى بها نحو %@، إضافةً إلى مساحة مؤقتة أثناء التصيير.",
    "ja": "推奨セットには約 %@ に加えて、レンダリング中の作業用領域が必要です。",
    "ko": "권장 세트에는 약 %@ 에 더해 렌더링 중 임시 공간이 필요합니다.",
    "th": "ชุดที่แนะนำต้องใช้ราว %@ บวกกับพื้นที่ทำงานชั่วคราวขณะเรนเดอร์",
    "yue-Hant": "建議嗰 set 大概要 %@，算圖嗰陣仲要額外暫存空間。",
    "en-SG": "The recommended set needs about %@, then still got working space while rendering. Better check your disk first.",
})
add("models.downloads", {
    "en": "Downloads",
    "zh-Hant": "下載",
    "zh-Hans": "下载",
    "de": "Downloads",
    "ar": "التنزيلات",
    "ja": "ダウンロード",
    "ko": "다운로드",
    "th": "การดาวน์โหลด",
    "yue-Hant": "下載",
    "en-SG": "Downloads",
})
add("models.downloads.footnote", {
    "en": "This list covers the current session. A finished download stays here until "
          "cleared; what is installed is shown against each model below.",
    "zh-Hant": "此清單只涵蓋本次工作階段。已完成的下載會留在這裡直到清除；實際安裝狀態顯示在下方各模型旁。",
    "zh-Hans": "此列表只涵盖本次会话。已完成的下载会留在这里直到清除；实际安装状态显示在下方各模型旁。",
    "de": "Diese Liste gilt für die aktuelle Sitzung. Ein abgeschlossener Download bleibt "
          "hier, bis er entfernt wird; was installiert ist, steht unten bei jedem Modell.",
    "ar": "تغطي هذه القائمة الجلسة الحالية. يبقى التنزيل المكتمل هنا حتى يُمسح؛ أما ما هو "
          "مثبَّت فيظهر بجانب كل نموذج أدناه.",
    "ja": "この一覧は今回のセッション分です。完了したダウンロードは消去するまで残ります。実際に入っているものは下の各モデルの欄に表示されます。",
    "ko": "이 목록은 현재 세션의 것입니다. 완료된 다운로드는 지울 때까지 남아 있으며, 실제 설치 여부는 아래 각 모델 옆에 표시됩니다.",
    "th": "รายการนี้ครอบคลุมเฉพาะเซสชันปัจจุบัน รายการที่ดาวน์โหลดเสร็จจะอยู่จนกว่าจะล้าง ส่วนสิ่งที่ติดตั้งแล้วจะแสดงไว้ข้างโมเดลแต่ละตัวด้านล่าง",
    "yue-Hant": "呢個清單淨係包今次開住嘅時間。下載完嘅會留喺度直到你清走;實際裝咗啲乜,喺下面每個模型旁邊睇。",
    "en-SG": "This list only covers this session. Finish already still stay here until you clear it. What actually installed, see beside each model below.",
})
add("models.cancelAll", {
    "en": "Cancel All",
    "zh-Hant": "全部取消",
    "zh-Hans": "全部取消",
    "de": "Alle abbrechen",
    "ar": "إلغاء الكل",
    "ja": "すべてキャンセル",
    "ko": "모두 취소",
    "th": "ยกเลิกทั้งหมด",
    "yue-Hant": "全部取消",
    "en-SG": "Cancel All",
})
add("models.clearFinished", {
    "en": "Clear Finished",
    "zh-Hant": "清除已完成",
    "zh-Hans": "清除已完成",
    "de": "Fertige entfernen",
    "ar": "مسح المكتملة",
    "ja": "完了分を消去",
    "ko": "완료 항목 지우기",
    "th": "ล้างรายการที่เสร็จแล้ว",
    "yue-Hant": "清走完成嘅",
    "en-SG": "Clear Finish One",
}, note="Removes completed downloads from the transfer list in Models. Same English "
        "as queue.clearFinished, different object — see it.")
add("models.rescan", {
    "en": "Rescan",
    "zh-Hant": "重新掃描",
    "zh-Hans": "重新扫描",
    "de": "Neu einlesen",
    "ar": "إعادة الفحص",
    "ja": "再スキャン",
    "ko": "다시 검사",
    "th": "สแกนใหม่",
    "yue-Hant": "重新掃描",
    "en-SG": "Scan Again",
})
add("models.rescan.help", {
    "en": "Re-read the shared models folder",
    "zh-Hant": "重新讀取共用模型資料夾",
    "zh-Hans": "重新读取共享模型文件夹",
    "de": "Den gemeinsamen Modellordner neu einlesen",
    "ar": "إعادة قراءة مجلد النماذج المشترك",
    "ja": "共有モデルフォルダを読み直します",
    "ko": "공유 모델 폴더를 다시 읽습니다",
    "th": "อ่านโฟลเดอร์โมเดลที่ใช้ร่วมกันอีกครั้ง",
    "yue-Hant": "重新讀共用模型資料夾",
    "en-SG": "Read the shared models folder again",
})
add("models.showIncompatible", {
    "en": "Show Incompatible",
    "zh-Hant": "顯示不相容項目",
    "zh-Hans": "显示不兼容项目",
    "de": "Inkompatible anzeigen",
    "ar": "إظهار غير المتوافق",
    "ja": "非対応も表示",
    "ko": "호환되지 않는 항목도 표시",
    "th": "แสดงตัวที่ใช้ไม่ได้",
    "yue-Hant": "顯示唔啱嘅",
    "en-SG": "Show Cannot Use One",
})
add("models.showIncompatible.help", {
    "en": "Include checkpoints in formats this Mac cannot run",
    "zh-Hant": "一併顯示本機無法執行之格式的檢查點",
    "zh-Hans": "一并显示本机无法运行之格式的检查点",
    "de": "Auch Checkpoints in Formaten zeigen, die dieser Mac nicht ausführen kann",
    "ar": "تضمين نقاط التحقق بصيغ لا يستطيع هذا الـ Mac تشغيلها",
    "ja": "この Mac で実行できない形式のチェックポイントも含めます",
    "ko": "이 Mac에서 실행할 수 없는 형식의 체크포인트도 포함합니다",
    "th": "รวม checkpoint ในรูปแบบที่ Mac เครื่องนี้รันไม่ได้ด้วย",
    "yue-Hant": "連本機跑唔到嘅格式一齊顯示",
    "en-SG": "Also show checkpoints in formats this Mac cannot run",
})
add("models.installRecommended", {
    "en": "Install Recommended",
    "zh-Hant": "安裝建議組合",
    "zh-Hans": "安装建议组合",
    "de": "Empfohlene installieren",
    "ar": "تثبيت الموصى به",
    "ja": "推奨セットを導入",
    "ko": "권장 모델 설치",
    "th": "ติดตั้งชุดที่แนะนำ",
    "yue-Hant": "裝建議嗰set",
    "en-SG": "Install Recommended",
})
add("models.installRecommended.title", {
    "en": "Install the recommended models?",
    "zh-Hant": "要安裝建議的模型嗎？",
    "zh-Hans": "要安装建议的模型吗？",
    "de": "Die empfohlenen Modelle installieren?",
    "ar": "هل تريد تثبيت النماذج الموصى بها؟",
    "ja": "推奨モデルをインストールしますか？",
    "ko": "권장 모델을 설치할까요?",
    "th": "ติดตั้งโมเดลที่แนะนำหรือไม่",
    "yue-Hant": "要裝建議嘅模型？",
    "en-SG": "Install the recommended models?",
})
add("models.willDownload", {
    "en": "Will download:",
    "zh-Hant": "即將下載：",
    "zh-Hans": "即将下载：",
    "de": "Wird geladen:",
    "ar": "سيتم تنزيل:",
    "ja": "ダウンロードするもの：",
    "ko": "다운로드할 항목:",
    "th": "จะดาวน์โหลด:",
    "yue-Hant": "將會下載：",
    "en-SG": "Will download:",
})
add("models.alreadyInstalled", {
    "en": "Already installed, and skipped:",
    "zh-Hant": "已安裝，將略過：",
    "zh-Hans": "已安装，将跳过：",
    "de": "Bereits installiert, wird übersprungen:",
    "ar": "مثبَّت مسبقًا، وسيُتخطّى:",
    "ja": "インストール済みのためスキップ：",
    "ko": "이미 설치되어 있어 건너뜀:",
    "th": "ติดตั้งอยู่แล้ว จึงข้ามไป:",
    "yue-Hant": "已經裝咗，會略過：",
    "en-SG": "Install already, so skip:",
})
add("models.savingTo", {
    "en": "Saving to %1$@, with %2$@ free.",
    "zh-Hant": "儲存至 %1$@，可用空間 %2$@。",
    "zh-Hans": "保存至 %1$@，可用空间 %2$@。",
    "de": "Wird in %1$@ gesichert, %2$@ frei.",
    "ar": "سيُحفظ في %1$@، والمساحة الحرة %2$@.",
    "ja": "%1$@ に保存します。空き %2$@。",
    "ko": "%1$@ 에 저장합니다. 남은 공간 %2$@.",
    "th": "บันทึกไปที่ %1$@ เหลือพื้นที่ว่าง %2$@",
    "yue-Hant": "存去 %1$@，可用空間 %2$@。",
    "en-SG": "Saving into %1$@, %2$@ space left.",
})
add("models.downloadAmount", {
    "en": "Download %@",
    "zh-Hant": "下載 %@",
    "zh-Hans": "下载 %@",
    "de": "%@ laden",
    "ar": "تنزيل %@",
    "ja": "%@ をダウンロード",
    "ko": "%@ 다운로드",
    "th": "ดาวน์โหลด %@",
    "yue-Hant": "下載 %@",
    "en-SG": "Download %@",
})
add("models.other.title", {
    "en": "Other models in this folder",
    "zh-Hant": "此資料夾中的其他模型",
    "zh-Hans": "此文件夹中的其他模型",
    "de": "Weitere Modelle in diesem Ordner",
    "ar": "نماذج أخرى في هذا المجلد",
    "ja": "このフォルダ内の他のモデル",
    "ko": "이 폴더의 다른 모델",
    "th": "โมเดลอื่นในโฟลเดอร์นี้",
    "yue-Hant": "呢個資料夾入面其他模型",
    "en-SG": "Other models inside this folder",
})
add("models.other.footnote", {
    "en": "These belong to other projects. This app leaves them alone.",
    "zh-Hant": "這些屬於其他專案，本 App 不會動它們。",
    "zh-Hans": "这些属于其他项目，本 App 不会动它们。",
    "de": "Diese gehören zu anderen Projekten. Diese App rührt sie nicht an.",
    "ar": "هذه تخص مشاريع أخرى، ولا يمسّها هذا التطبيق.",
    "ja": "これらは他のプロジェクトのものです。このアプリは手を触れません。",
    "ko": "이것들은 다른 프로젝트의 파일입니다. 이 앱은 건드리지 않습니다.",
    "th": "ไฟล์เหล่านี้เป็นของโปรเจกต์อื่น แอปนี้จะไม่ไปยุ่งด้วย",
    "yue-Hant": "呢啲係其他專案嘅,呢個 App 唔會郁佢哋。",
    "en-SG": "These belong to other projects. This app never touch them.",
})
add("models.inUse", {
    "en": "In use",
    "zh-Hant": "使用中",
    "zh-Hans": "使用中",
    "de": "In Verwendung",
    "ar": "قيد الاستخدام",
    "ja": "使用中",
    "ko": "사용 중",
    "th": "กำลังใช้",
    "yue-Hant": "用緊",
    "en-SG": "Using now",
})
add("models.notRunnable", {
    "en": "Not runnable here",
    "zh-Hant": "此裝置無法執行",
    "zh-Hans": "此设备无法运行",
    "de": "Hier nicht lauffähig",
    "ar": "غير قابل للتشغيل هنا",
    "ja": "ここでは実行できません",
    "ko": "여기서는 실행할 수 없음",
    "th": "รันที่นี่ไม่ได้",
    "yue-Hant": "呢部機跑唔到",
    "en-SG": "This Mac cannot run one",
})
add("models.use", {
    "en": "Use",
    "zh-Hant": "使用",
    "zh-Hans": "使用",
    "de": "Verwenden",
    "ar": "استخدام",
    "ja": "使用",
    "ko": "사용",
    "th": "ใช้",
    "yue-Hant": "用呢個",
    "en-SG": "Use This",
}, note="Imperative verb on a button — select these weights for the next render. Not "
        "the noun \"usage\".")
add("models.selected", {
    "en": "Selected",
    "zh-Hant": "已選擇",
    "zh-Hans": "已选择",
    "de": "Ausgewählt",
    "ar": "محدَّد",
    "ja": "選択済み",
    "ko": "선택됨",
    "th": "เลือกแล้ว",
    "yue-Hant": "揀咗",
    "en-SG": "Chosen",
}, note="Adjective describing a model the user has picked for a render. Not a verb, "
        "and not a count.")
add("models.use.help.download", {
    "en": "Download this first",
    "zh-Hant": "請先下載",
    "zh-Hans": "请先下载",
    "de": "Zuerst laden",
    "ar": "نزّله أولًا",
    "ja": "先にダウンロードしてください",
    "ko": "먼저 다운로드하세요",
    "th": "ดาวน์โหลดก่อน",
    "yue-Hant": "下載咗先",
    "en-SG": "Download first lah",
})
add("models.use.help.inUse", {
    "en": "Already in use for the current render",
    "zh-Hant": "目前的算圖已在使用",
    "zh-Hans": "当前的渲染已在使用",
    "de": "Wird für den aktuellen Render bereits verwendet",
    "ar": "مستخدَم بالفعل في التصيير الحالي",
    "ja": "現在のレンダリングで既に使用中です",
    "ko": "현재 렌더링에서 이미 쓰고 있습니다",
    "th": "ใช้กับการเรนเดอร์ปัจจุบันอยู่แล้ว",
    "yue-Hant": "今次算圖已經用緊",
    "en-SG": "Already using for this render",
})
add("models.use.help.select", {
    "en": "Use this for the current render",
    "zh-Hant": "用於目前的算圖",
    "zh-Hans": "用于当前的渲染",
    "de": "Für den aktuellen Render verwenden",
    "ar": "استخدامه في التصيير الحالي",
    "ja": "これを現在のレンダリングに使います",
    "ko": "이것을 현재 렌더링에 사용합니다",
    "th": "ใช้ตัวนี้กับการเรนเดอร์ปัจจุบัน",
    "yue-Hant": "用嚟做今次算圖",
    "en-SG": "Use this one for this render",
})
add("models.delete.title", {
    "en": "Delete %@?",
    "zh-Hant": "要刪除%@嗎？",
    "zh-Hans": "要删除%@吗？",
    "de": "%@ löschen?",
    "ar": "هل تريد حذف %@؟",
    "ja": "%@ を削除しますか？",
    "ko": "%@ 을(를) 삭제할까요?",
    "th": "ลบ %@ หรือไม่",
    "yue-Hant": "刪除%@？",
    "en-SG": "Throw away %@?",
}, note={
    "content": "Injects a name into a sentence. Languages that inflect a noun for case, choose "
               "an article by gender, or attach a vowel-harmonising suffix cannot do it without "
               "knowing the word, and it is only known at runtime. Prefer wording that sets the "
               "name apart — quoted, or on its own line.",
    "level": WARNING,
})
add("models.delete.message", {
    "en": "Frees about %1$@ from the shared models folder, which other projects on this Mac "
          "may also be using — anything relying on %2$@ would have to download it again. "
          "The files go to the Trash, so this can be undone until you empty it.",
    "zh-Hant": "可釋出約 %1$@ 的共用模型資料夾空間；本機其他專案可能也在使用，任何依賴 %2$@ 的程式都得重新下載。檔案會移到垃圾桶，清空前都還能還原。",
    "zh-Hans": "可释出约 %1$@ 的共享模型文件夹空间；本机其他项目可能也在使用，任何依赖 %2$@ 的程序都得重新下载。文件会移到废纸篓，清空前都还能还原。",
    "de": "Gibt etwa %1$@ im gemeinsamen Modellordner frei, den andere Projekte auf diesem "
          "Mac ebenfalls nutzen könnten — alles, was auf %2$@ angewiesen ist, müsste es "
          "erneut laden. Die Dateien wandern in den Papierkorb und lassen sich bis zum "
          "Leeren wiederherstellen.",
    "ar": "يحرّر نحو %1$@ من مجلد النماذج المشترك، وقد تستخدمه مشاريع أخرى على هذا الـ Mac "
          "— وأي شيء يعتمد على %2$@ سيحتاج إلى تنزيله مجددًا. تنتقل الملفات إلى المهملات، "
          "فيمكن التراجع حتى تفريغها.",
    "ja": "共有モデルフォルダから約 %1$@ を解放します。このフォルダはこの Mac の他のプロジェクトも使っている可能性があり、%2$@ に依存しているものは再ダウンロードが必要になります。ファイルはゴミ箱に入るので、空にするまでは取り消せます。",
    "ko": "공유 모델 폴더에서 약 %1$@ 을(를) 확보합니다. 이 Mac의 다른 프로젝트도 이 폴더를 쓸 수 있으며, %2$@ 에 의존하는 것은 다시 내려받아야 합니다. 파일은 휴지통으로 가므로 비우기 전까지는 되돌릴 수 있습니다.",
    "th": "คืนพื้นที่ราว %1$@ จากโฟลเดอร์โมเดลที่ใช้ร่วมกัน ซึ่งโปรเจกต์อื่นบน Mac เครื่องนี้อาจใช้อยู่ด้วย สิ่งที่พึ่งพา %2$@ จะต้องดาวน์โหลดใหม่ ไฟล์จะไปอยู่ในถังขยะ จึงกู้คืนได้จนกว่าจะล้างถังขยะ",
    "yue-Hant": "可以喺共用模型資料夾度騰返大概 %1$@ 空間;本機其他專案可能都用緊,任何靠 %2$@ 嘅嘢都要再下載過。啲檔案會入垃圾桶,未清空之前都仲可以還原。",
    "en-SG": "Frees about %1$@ from the shared models folder, which other projects on this Mac maybe also using — anything that depends on %2$@ must download all over again, sibeh mafan. The files go into the Trash, so still can undo until you empty it.",
})
add("models.delete.help.running", {
    "en": "Not while a render is running",
    "zh-Hant": "算圖進行中無法刪除",
    "zh-Hans": "渲染进行中无法删除",
    "de": "Nicht während ein Render läuft",
    "ar": "غير ممكن أثناء تشغيل تصيير",
    "ja": "レンダリング中はできません",
    "ko": "렌더링이 실행 중일 때는 할 수 없습니다",
    "th": "ทำไม่ได้ขณะกำลังเรนเดอร์",
    "yue-Hant": "算緊圖唔得",
    "en-SG": "Cannot, render is running",
})
add("models.delete.help.inUse", {
    "en": "In use for the current render — choose another first",
    "zh-Hant": "目前的算圖正在使用，請先改選其他",
    "zh-Hans": "当前的渲染正在使用，请先改选其他",
    "de": "Wird für den aktuellen Render verwendet — zuerst ein anderes wählen",
    "ar": "مستخدَم في التصيير الحالي — اختر غيره أولًا",
    "ja": "現在のレンダリングで使用中です。先に別のものを選んでください",
    "ko": "현재 렌더링에서 쓰는 중입니다. 먼저 다른 것을 고르세요",
    "th": "กำลังใช้กับการเรนเดอร์ปัจจุบัน เลือกตัวอื่นก่อน",
    "yue-Hant": "今次算圖用緊 — 揀過第二個先",
    "en-SG": "This render is using it — choose another one first",
})
add("models.delete.help.ok", {
    "en": "Move this model to the Trash",
    "zh-Hant": "將此模型移到垃圾桶",
    "zh-Hans": "将此模型移到废纸篓",
    "de": "Dieses Modell in den Papierkorb legen",
    "ar": "نقل هذا النموذج إلى المهملات",
    "ja": "このモデルをゴミ箱に移動します",
    "ko": "이 모델을 휴지통으로 옮깁니다",
    "th": "ย้ายโมเดลนี้ไปถังขยะ",
    "yue-Hant": "將呢個模型掉入垃圾桶",
    "en-SG": "Throw this model into the Trash",
})
add("models.delete.freed", {
    "en": "Moved %@ to the Trash.",
    "zh-Hant": "已將 %@ 移到垃圾桶。",
    "zh-Hans": "已将 %@ 移到废纸篓。",
    "de": "%@ in den Papierkorb gelegt.",
    "ar": "نُقل %@ إلى المهملات.",
    "ja": "%@ をゴミ箱に移動しました。",
    "ko": "%@ 을(를) 휴지통으로 옮겼습니다.",
    "th": "ย้าย %@ ไปที่ถังขยะแล้ว",
    "yue-Hant": "已經將 %@ 掉咗入垃圾桶。",
    "en-SG": "Threw %@ into the Trash already.",
})
add("models.inMemory", {
    "en": "%@ in memory",
    "zh-Hant": "記憶體 %@",
    "zh-Hans": "内存 %@",
    "de": "%@ im Arbeitsspeicher",
    "ar": "%@ في الذاكرة",
    "ja": "メモリ上 %@",
    "ko": "메모리 %@",
    "th": "ในหน่วยความจำ %@",
    "yue-Hant": "記憶體 %@",
    "en-SG": "%@ in memory",
})
add("models.downloaded", {
    "en": "Downloaded",
    "zh-Hant": "已下載",
    "zh-Hans": "已下载",
    "de": "Geladen",
    "ar": "تم التنزيل",
    "ja": "ダウンロード済み",
    "ko": "다운로드됨",
    "th": "ดาวน์โหลดแล้ว",
    "yue-Hant": "下載咗",
    "en-SG": "Download already",
})
add("models.downloadFailed", {
    "en": "Download failed",
    "zh-Hant": "下載失敗",
    "zh-Hans": "下载失败",
    "de": "Download fehlgeschlagen",
    "ar": "فشل التنزيل",
    "ja": "ダウンロードに失敗",
    "ko": "다운로드 실패",
    "th": "ดาวน์โหลดล้มเหลว",
    "yue-Hant": "下載失敗",
    "en-SG": "Download fail",
})
add("models.cancelDownload", {
    "en": "Cancel download of %@",
    "zh-Hant": "取消下載 %@",
    "zh-Hans": "取消下载 %@",
    "de": "Download von %@ abbrechen",
    "ar": "إلغاء تنزيل %@",
    "ja": "%@ のダウンロードをキャンセル",
    "ko": "%@ 다운로드 취소",
    "th": "ยกเลิกการดาวน์โหลด %@",
    "yue-Hant": "取消下載 %@",
    "en-SG": "Cancel download of %@",
}, note={
    "content": "Injects a name into a sentence. Languages that inflect a noun for case, choose "
               "an article by gender, or attach a vowel-harmonising suffix cannot do it without "
               "knowing the word, and it is only known at runtime. Prefer wording that sets the "
               "name apart — quoted, or on its own line.",
    "level": WARNING,
})
add("models.progress", {
    "en": "Download progress",
    "zh-Hant": "下載進度",
    "zh-Hans": "下载进度",
    "de": "Download-Fortschritt",
    "ar": "تقدّم التنزيل",
    "ja": "ダウンロードの進捗",
    "ko": "다운로드 진행률",
    "th": "ความคืบหน้าการดาวน์โหลด",
    "yue-Hant": "下載進度",
    "en-SG": "Download progress",
})
add("models.notInstalled", {
    "en": "Not installed",
    "zh-Hant": "未安裝",
    "zh-Hans": "未安装",
    "de": "Nicht installiert",
    "ar": "غير مثبَّت",
    "ja": "未インストール",
    "ko": "설치되지 않음",
    "th": "ยังไม่ได้ติดตั้ง",
    "yue-Hant": "未裝",
    "en-SG": "Never install",
})

# ── Model roles and provenance ───────────────────────────────────────────────
add("role.transformer", {
    "en": "Diffusion transformer",
    "zh-Hant": "擴散 Transformer",
    "zh-Hans": "扩散 Transformer",
    "de": "Diffusion-Transformer",
    "ar": "مُحوِّل الانتشار",
    "ja": "拡散トランスフォーマー",
    "ko": "디퓨전 트랜스포머",
    "th": "Diffusion transformer",
    "yue-Hant": "擴散 Transformer",
    "en-SG": "Diffusion transformer",
})
add("role.textEncoder", {
    "en": "Text encoder",
    "zh-Hant": "文字編碼器",
    "zh-Hans": "文本编码器",
    "de": "Text-Encoder",
    "ar": "مُرمِّز النص",
    "ja": "テキストエンコーダ",
    "ko": "텍스트 인코더",
    "th": "ตัวเข้ารหัสข้อความ",
    "yue-Hant": "文字編碼器",
    "en-SG": "Text encoder",
}, note="Names the text-encoder role in the model catalogue — a kind of model file. "
        "Distinct from summary.textEncoder, which names the specific encoder a render "
        "will use.")
add("role.support", {
    "en": "VAEs & processors",
    "zh-Hant": "VAE 與前處理器",
    "zh-Hans": "VAE 与预处理器",
    "de": "VAEs & Prozessoren",
    "ar": "‏VAE والمعالِجات",
    "ja": "VAE とプロセッサ",
    "ko": "VAE 및 프로세서",
    "th": "VAE และตัวประมวลผล",
    "yue-Hant": "VAE 同前處理器",
    "en-SG": "VAEs & processors",
})
add("role.accelerator", {
    "en": "Acceleration LoRAs",
    "zh-Hant": "加速 LoRA",
    "zh-Hans": "加速 LoRA",
    "de": "Beschleunigungs-LoRAs",
    "ar": "نماذج LoRA للتسريع",
    "ja": "高速化 LoRA",
    "ko": "가속 LoRA",
    "th": "LoRA เร่งความเร็ว",
    "yue-Hant": "加速 LoRA",
    "en-SG": "Acceleration LoRAs",
})
add("provenance.official", {
    "en": "Official",
    "zh-Hant": "官方",
    "zh-Hans": "官方",
    "de": "Offiziell",
    "ar": "رسمي",
    "ja": "公式",
    "ko": "공식",
    "th": "ทางการ",
    "yue-Hant": "官方",
    "en-SG": "Official",
}, note="Marks a model published by the original authors, as opposed to "
        "provenance.community. About who released the weights, not about approval or "
        "certification.")
add("provenance.port", {
    "en": "MLX port",
    "zh-Hant": "MLX 移植",
    "zh-Hans": "MLX 移植",
    "de": "MLX-Portierung",
    "ar": "نقل MLX",
    "ja": "MLX 移植版",
    "ko": "MLX 이식판",
    "th": "พอร์ต MLX",
    "yue-Hant": "MLX 移植",
    "en-SG": "MLX port",
})
add("provenance.community", {
    "en": "Community",
    "zh-Hant": "社群",
    "zh-Hans": "社区",
    "de": "Community",
    "ar": "المجتمع",
    "ja": "コミュニティ",
    "ko": "커뮤니티",
    "th": "ชุมชน",
    "yue-Hant": "社群",
    "en-SG": "Community",
}, note="Marks a model published by someone other than the original authors — a "
        "conversion or a fine-tune. Neutral: it describes origin, not quality. See "
        "provenance.official.")
add("task.fl2va", {
    "en": "FL2VA — text & keyframes",
    "zh-Hant": "FL2VA — 文字與關鍵格",
    "zh-Hans": "FL2VA — 文字与关键帧",
    "de": "FL2VA — Text & Keyframes",
    "ar": "‏FL2VA — نص وإطارات مفتاحية",
    "ja": "FL2VA — テキストとキーフレーム",
    "ko": "FL2VA — 텍스트와 키프레임",
    "th": "FL2VA — ข้อความและ keyframe",
    "yue-Hant": "FL2VA — 文字同關鍵格",
    "en-SG": "FL2VA — text & keyframes",
})
add("task.ref2va", {
    "en": "Ref2VA — references",
    "zh-Hant": "Ref2VA — 參考素材",
    "zh-Hans": "Ref2VA — 参考素材",
    "de": "Ref2VA — Referenzen",
    "ar": "‏Ref2VA — مراجع",
    "ja": "Ref2VA — 参考素材",
    "ko": "Ref2VA — 참조 자료",
    "th": "Ref2VA — ไฟล์อ้างอิง",
    "yue-Hant": "Ref2VA — 參考素材",
    "en-SG": "Ref2VA — references",
})

# ── Onboarding ───────────────────────────────────────────────────────────────
add("onboarding.skip", {
    "en": "Skip setup",
    "zh-Hant": "略過設定",
    "zh-Hans": "跳过设置",
    "de": "Einrichtung überspringen",
    "ar": "تخطّي الإعداد",
    "ja": "セットアップをスキップ",
    "ko": "설치 건너뛰기",
    "th": "ข้ามการตั้งค่า",
    "yue-Hant": "略過設定",
    "en-SG": "Skip setup",
})
add("onboarding.back", {
    "en": "Back",
    "zh-Hant": "上一步",
    "zh-Hans": "上一步",
    "de": "Zurück",
    "ar": "رجوع",
    "ja": "戻る",
    "ko": "뒤로",
    "th": "ย้อนกลับ",
    "yue-Hant": "上一步",
    "en-SG": "Go Back",
}, note="Navigates to the previous onboarding step. The direction, not the body part "
        "— and specifically \"previous\", which some languages word differently from "
        "\"backwards\".")
add("onboarding.continue", {
    "en": "Continue",
    "zh-Hant": "繼續",
    "zh-Hans": "继续",
    "de": "Fortfahren",
    "ar": "متابعة",
    "ja": "続ける",
    "ko": "계속",
    "th": "ดำเนินการต่อ",
    "yue-Hant": "繼續",
    "en-SG": "Continue",
})
add("onboarding.welcome.title", {
    "en": "Generate video on this Mac",
    "zh-Hant": "在這台 Mac 上生成影片",
    "zh-Hans": "在这台 Mac 上生成视频",
    "de": "Video auf diesem Mac erzeugen",
    "ar": "توليد الفيديو على هذا الـ Mac",
    "ja": "この Mac で動画を生成",
    "ko": "이 Mac에서 비디오 생성",
    "th": "สร้างวิดีโอบน Mac เครื่องนี้",
    "yue-Hant": "喺呢部 Mac 度生成影片",
    "en-SG": "Make video on this Mac",
})
add("onboarding.licence.title", {
    "en": "Model licence",
    "zh-Hant": "模型授權",
    "zh-Hans": "模型许可",
    "de": "Modelllizenz",
    "ar": "ترخيص النموذج",
    "ja": "モデルのライセンス",
    "ko": "모델 라이선스",
    "th": "สัญญาอนุญาตของโมเดล",
    "yue-Hant": "模型授權",
    "en-SG": "Model licence",
})
add("onboarding.runtime.title", {
    "en": "Python runtime",
    "zh-Hant": "Python 執行環境",
    "zh-Hans": "Python 运行环境",
    "de": "Python-Laufzeitumgebung",
    "ar": "بيئة تشغيل Python",
    "ja": "Python 実行環境",
    "ko": "Python 런타임",
    "th": "Runtime Python",
    "yue-Hant": "Python 執行環境",
    "en-SG": "Python runtime",
})
add("onboarding.models.title", {
    "en": "Model weights",
    "zh-Hant": "模型權重",
    "zh-Hans": "模型权重",
    "de": "Modellgewichte",
    "ar": "أوزان النموذج",
    "ja": "モデルの重み",
    "ko": "모델 가중치",
    "th": "ไฟล์น้ำหนักโมเดล",
    "yue-Hant": "模型權重",
    "en-SG": "Model weights",
})
add("onboarding.installRuntime", {
    "en": "Install Runtime",
    "zh-Hant": "安裝執行環境",
    "zh-Hans": "安装运行环境",
    "de": "Laufzeitumgebung installieren",
    "ar": "تثبيت بيئة التشغيل",
    "ja": "実行環境をインストール",
    "ko": "런타임 설치",
    "th": "ติดตั้ง runtime",
    "yue-Hant": "裝執行環境",
    "en-SG": "Install Runtime",
})
add("onboarding.installing", {
    "en": "Installing…",
    "zh-Hant": "安裝中…",
    "zh-Hans": "安装中…",
    "de": "Wird installiert …",
    "ar": "جارٍ التثبيت…",
    "ja": "インストール中…",
    "ko": "설치 중…",
    "th": "กำลังติดตั้ง…",
    "yue-Hant": "裝緊…",
    "en-SG": "Installing…",
})
add("onboarding.startDownload", {
    "en": "Start Download",
    "zh-Hant": "開始下載",
    "zh-Hans": "开始下载",
    "de": "Download starten",
    "ar": "بدء التنزيل",
    "ja": "ダウンロードを開始",
    "ko": "다운로드 시작",
    "th": "เริ่มดาวน์โหลด",
    "yue-Hant": "開始下載",
    "en-SG": "Start Download",
})
add("onboarding.slowTitle", {
    "en": "Renders take hours, not seconds",
    "zh-Hant": "算圖需要數小時，而非數秒",
    "zh-Hans": "渲染需要数小时，而非数秒",
    "de": "Renders dauern Stunden, nicht Sekunden",
    "ar": "يستغرق التصيير ساعات لا ثوانٍ",
    "ja": "レンダリングは秒ではなく時間の単位です",
    "ko": "렌더링은 초가 아니라 시간 단위입니다",
    "th": "การเรนเดอร์ใช้เวลาเป็นชั่วโมง ไม่ใช่วินาที",
    "yue-Hant": "算一條片要幾個鐘，唔係幾秒",
    "en-SG": "Render takes hours, not seconds one",
})
add("onboarding.diskTitle", {
    "en": "Setup is a large download",
    "zh-Hant": "初始設定的下載量很大",
    "zh-Hans": "初始设置的下载量很大",
    "de": "Die Einrichtung lädt viel herunter",
    "ar": "الإعداد يتطلّب تنزيلًا كبيرًا",
    "ja": "セットアップは大きなダウンロードです",
    "ko": "설치에는 큰 다운로드가 필요합니다",
    "th": "การตั้งค่าต้องดาวน์โหลดขนาดใหญ่",
    "yue-Hant": "初次設定要下載好多嘢",
    "en-SG": "Setup got a lot to download",
})
add("onboarding.licence.acknowledge", {
    "en": "I have read the licence and I am entitled to use these weights where I am",
    "zh-Hant": "我已閱讀授權條款，並確認在我所在地有權使用這些權重",
    "zh-Hans": "我已阅读许可条款，并确认在我所在地有权使用这些权重",
    "de": "Ich habe die Lizenz gelesen und bin berechtigt, diese Gewichte hier zu verwenden",
    "ar": "لقد قرأت الترخيص وأنا مخوَّل باستخدام هذه الأوزان في موقعي",
    "ja": "ライセンスを読み、自分のいる地域でこの重みを使う資格があることを確認しました",
    "ko": "라이선스를 읽었으며, 내가 있는 지역에서 이 가중치를 쓸 자격이 있음을 확인합니다",
    "th": "ข้าพเจ้าได้อ่านสัญญาอนุญาตแล้ว และมีสิทธิ์ใช้ไฟล์น้ำหนักเหล่านี้ในพื้นที่ที่ข้าพเจ้าอยู่",
    "yue-Hant": "我睇咗授權條款，亦確認喺我所在地有權用呢啲權重",
    "en-SG": "I read the licence already, and where I stay I am allowed to use these weights",
})
add("onboarding.licence.readFull", {
    "en": "Read the full licence on Hugging Face",
    "zh-Hant": "在 Hugging Face 閱讀完整授權",
    "zh-Hans": "在 Hugging Face 阅读完整许可",
    "de": "Vollständige Lizenz auf Hugging Face lesen",
    "ar": "اقرأ الترخيص كاملًا على Hugging Face",
    "ja": "Hugging Face で全文を読む",
    "ko": "Hugging Face에서 전문 읽기",
    "th": "อ่านสัญญาอนุญาตฉบับเต็มบน Hugging Face",
    "yue-Hant": "喺 Hugging Face 睇完整授權",
    "en-SG": "Read the full licence on Hugging Face",
})
add("onboarding.total", {
    "en": "Total",
    "zh-Hant": "總計",
    "zh-Hans": "总计",
    "de": "Gesamt",
    "ar": "الإجمالي",
    "ja": "合計",
    "ko": "합계",
    "th": "รวม",
    "yue-Hant": "總共",
    "en-SG": "Total",
}, note="The combined download size of the recommended model set. A sum of bytes, not "
        "a count of files.")
add("onboarding.freeOnDisk", {
    "en": "Free on disk",
    "zh-Hant": "磁碟可用空間",
    "zh-Hans": "磁盘可用空间",
    "de": "Frei auf dem Volume",
    "ar": "المساحة الحرة على القرص",
    "ja": "ディスクの空き",
    "ko": "디스크 여유 공간",
    "th": "พื้นที่ว่างบนดิสก์",
    "yue-Hant": "磁碟可用空間",
    "en-SG": "Space left on disk",
})
add("onboarding.savingTo", {
    "en": "Saving to %@",
    "zh-Hant": "儲存至 %@",
    "zh-Hans": "保存至 %@",
    "de": "Wird gesichert in %@",
    "ar": "سيُحفظ في %@",
    "ja": "%@ に保存",
    "ko": "%@ 에 저장",
    "th": "บันทึกไปที่ %@",
    "yue-Hant": "存去 %@",
    "en-SG": "Saving into %@",
})

# ── Sidebar / window chrome ──────────────────────────────────────────────────
add("sidebar.show", {
    "en": "Show Sidebar",
    "zh-Hant": "顯示側邊欄",
    "zh-Hans": "显示边栏",
    "de": "Seitenleiste einblenden",
    "ar": "إظهار الشريط الجانبي",
    "ja": "サイドバーを表示",
    "ko": "사이드바 보기",
    "th": "แสดงแถบด้านข้าง",
    "yue-Hant": "顯示側邊欄",
    "en-SG": "Show Sidebar",
})
add("sidebar.hide", {
    "en": "Hide Sidebar",
    "zh-Hant": "隱藏側邊欄",
    "zh-Hans": "隐藏边栏",
    "de": "Seitenleiste ausblenden",
    "ar": "إخفاء الشريط الجانبي",
    "ja": "サイドバーを隠す",
    "ko": "사이드바 가리기",
    "th": "ซ่อนแถบด้านข้าง",
    "yue-Hant": "收埋側邊欄",
    "en-SG": "Hide Sidebar",
})
add("menu.newRender", {
    "en": "New Render",
    "zh-Hant": "新增算圖",
    "zh-Hans": "新建渲染",
    "de": "Neuer Render",
    "ar": "تصيير جديد",
    "ja": "新規レンダリング",
    "ko": "새 렌더링",
    "th": "เรนเดอร์ใหม่",
    "yue-Hant": "新算一條",
    "en-SG": "New Video",
})
add("menu.rescanModels", {
    "en": "Rescan Models Folder",
    "zh-Hant": "重新掃描模型資料夾",
    "zh-Hans": "重新扫描模型文件夹",
    "de": "Modellordner neu einlesen",
    "ar": "إعادة فحص مجلد النماذج",
    "ja": "モデルフォルダを再スキャン",
    "ko": "모델 폴더 다시 검사",
    "th": "สแกนโฟลเดอร์โมเดลอีกครั้ง",
    "yue-Hant": "重新掃描模型資料夾",
    "en-SG": "Scan Models Folder Again",
})
add("menu.revealModels", {
    "en": "Reveal Models Folder in Finder",
    "zh-Hant": "在 Finder 中顯示模型資料夾",
    "zh-Hans": "在 Finder 中显示模型文件夹",
    "de": "Modellordner im Finder zeigen",
    "ar": "إظهار مجلد النماذج في Finder",
    "ja": "モデルフォルダを Finder に表示",
    "ko": "Finder에서 모델 폴더 보기",
    "th": "แสดงโฟลเดอร์โมเดลใน Finder",
    "yue-Hant": "喺 Finder 度顯示模型資料夾",
    "en-SG": "Show Models Folder in Finder",
})
add("menu.licenses", {
    "en": "Licenses",
    "zh-Hant": "授權",
    "zh-Hans": "许可",
    "de": "Lizenzen",
    "ar": "التراخيص",
    "ja": "ライセンス",
    "ko": "라이선스",
    "th": "สัญญาอนุญาต",
    "yue-Hant": "授權",
    "en-SG": "Licences",
}, note="Help menu item opening the licence window. The window's own text is English "
        "only — see LicensesView.")

# ── References card ──────────────────────────────────────────────────────────
add("refs.title.keyframes", {
    "en": "Keyframes",
    "zh-Hant": "關鍵格",
    "zh-Hans": "关键帧",
    "de": "Keyframes",
    "ar": "الإطارات المفتاحية",
    "ja": "キーフレーム",
    "ko": "키프레임",
    "th": "Keyframe",
    "yue-Hant": "關鍵格",
    "en-SG": "Keyframes",
})
add("refs.title.references", {
    "en": "References",
    "zh-Hant": "參考素材",
    "zh-Hans": "参考素材",
    "de": "Referenzen",
    "ar": "المراجع",
    "ja": "参考素材",
    "ko": "참조 자료",
    "th": "ไฟล์อ้างอิง",
    "yue-Hant": "參考素材",
    "en-SG": "References",
}, note="Heads the card listing the reference files the user has attached. The files, "
        "not the mode — see mode.reference.")
add("refs.addFiles", {
    "en": "Add Files…",
    "zh-Hant": "加入檔案…",
    "zh-Hans": "添加文件…",
    "de": "Dateien hinzufügen …",
    "ar": "إضافة ملفات…",
    "ja": "ファイルを追加…",
    "ko": "파일 추가…",
    "th": "เพิ่มไฟล์…",
    "yue-Hant": "加檔案…",
    "en-SG": "Add Files…",
})
add("refs.removeAll", {
    "en": "Remove All",
    "zh-Hant": "全部移除",
    "zh-Hans": "全部移除",
    "de": "Alle entfernen",
    "ar": "إزالة الكل",
    "ja": "すべて削除",
    "ko": "모두 제거",
    "th": "เอาออกทั้งหมด",
    "yue-Hant": "全部移除",
    "en-SG": "Take Out All",
})
add("refs.drop", {
    "en": "Drop files here",
    "zh-Hant": "把檔案拖到這裡",
    "zh-Hans": "把文件拖到这里",
    "de": "Dateien hierher ziehen",
    "ar": "أفلِت الملفات هنا",
    "ja": "ここにファイルをドロップ",
    "ko": "여기에 파일을 놓으세요",
    "th": "วางไฟล์ที่นี่",
    "yue-Hant": "將檔案拖到呢度",
    "en-SG": "Drop files here",
})
add("refs.insertTag", {
    "en": "Insert Tag",
    "zh-Hant": "插入標記",
    "zh-Hans": "插入标记",
    "de": "Tag einfügen",
    "ar": "إدراج وسم",
    "ja": "タグを挿入",
    "ko": "태그 삽입",
    "th": "แทรกแท็ก",
    "yue-Hant": "插入標記",
    "en-SG": "Put In Tag",
})
add("refs.insertTags", {
    "en": "Insert Tags",
    "zh-Hant": "插入標記",
    "zh-Hans": "插入标记",
    "de": "Tags einfügen",
    "ar": "إدراج وسوم",
    "ja": "タグを挿入",
    "ko": "태그 삽입",
    "th": "แทรกแท็ก",
    "yue-Hant": "插入標記",
    "en-SG": "Put In Tags",
})
add("refs.insertTags.help", {
    "en": "Append %@ to the prompt",
    "zh-Hant": "將 %@ 附加到提示詞",
    "zh-Hans": "将 %@ 附加到提示词",
    "de": "%@ an den Prompt anhängen",
    "ar": "إلحاق %@ بالموجّه",
    "ja": "プロンプトに %@ を追記します",
    "ko": "프롬프트에 %@ 을(를) 덧붙입니다",
    "th": "เพิ่ม %@ ต่อท้าย prompt",
    "yue-Hant": "將 %@ 加落提示詞後面",
    "en-SG": "Add %@ behind the prompt",
})
add("refs.remove", {
    "en": "Remove %@",
    "zh-Hant": "移除 %@",
    "zh-Hans": "移除 %@",
    "de": "%@ entfernen",
    "ar": "إزالة %@",
    "ja": "%@ を削除",
    "ko": "%@ 제거",
    "th": "เอา %@ ออก",
    "yue-Hant": "移除 %@",
    "en-SG": "Take out %@",
}, note={
    "content": "Injects a name into a sentence. Languages that inflect a noun for case, choose "
               "an article by gender, or attach a vowel-harmonising suffix cannot do it without "
               "knowing the word, and it is only known at runtime. Prefer wording that sets the "
               "name apart — quoted, or on its own line.",
    "level": WARNING,
})
add("refs.choose.image", {
    "en": "Choose a keyframe image",
    "zh-Hant": "選擇關鍵格圖片",
    "zh-Hans": "选择关键帧图片",
    "de": "Keyframe-Bild wählen",
    "ar": "اختر صورة إطار مفتاحي",
    "ja": "キーフレーム画像を選択",
    "ko": "키프레임 이미지 선택",
    "th": "เลือกภาพ keyframe",
    "yue-Hant": "揀張關鍵格圖",
    "en-SG": "Choose a keyframe image",
})
add("refs.choose.any", {
    "en": "Choose reference images, videos or audio",
    "zh-Hant": "選擇參考圖片、影片或音訊",
    "zh-Hans": "选择参考图片、视频或音频",
    "de": "Referenzbilder, -videos oder -audio wählen",
    "ar": "اختر صورًا أو مقاطع فيديو أو صوتًا مرجعية",
    "ja": "参考用の画像・動画・音声を選択",
    "ko": "참조용 이미지, 비디오 또는 오디오 선택",
    "th": "เลือกภาพ วิดีโอ หรือเสียงสำหรับอ้างอิง",
    "yue-Hant": "揀參考圖片、影片或者音訊",
    "en-SG": "Choose reference images, videos or audio",
})
add("refs.slot.first", {
    "en": "First frame",
    "zh-Hant": "首格",
    "zh-Hans": "首帧",
    "de": "Erstes Bild",
    "ar": "الإطار الأول",
    "ja": "先頭フレーム",
    "ko": "첫 프레임",
    "th": "เฟรมแรก",
    "yue-Hant": "首格",
    "en-SG": "First frame",
}, note="Labels the drop target for the first-frame image. A place to put a file, "
        "where mode.first is a mode — see it.")
add("refs.slot.last", {
    "en": "Last frame",
    "zh-Hant": "末格",
    "zh-Hans": "末帧",
    "de": "Letztes Bild",
    "ar": "الإطار الأخير",
    "ja": "末尾フレーム",
    "ko": "마지막 프레임",
    "th": "เฟรมสุดท้าย",
    "yue-Hant": "末格",
    "en-SG": "Last frame",
})
add("refs.slot.reference", {
    "en": "Reference",
    "zh-Hant": "參考",
    "zh-Hans": "参考",
    "de": "Referenz",
    "ar": "مرجع",
    "ja": "参考素材",
    "ko": "참조 자료",
    "th": "ไฟล์อ้างอิง",
    "yue-Hant": "參考",
    "en-SG": "Reference",
})
add("refs.kind.image", {
    "en": "Image",
    "zh-Hant": "圖片",
    "zh-Hans": "图片",
    "de": "Bild",
    "ar": "صورة",
    "ja": "画像",
    "ko": "이미지",
    "th": "ภาพ",
    "yue-Hant": "圖片",
    "en-SG": "Image",
}, note="Names the still-image kind in the reference list, beside Video and Audio. A "
        "file category.")
add("refs.kind.video", {
    "en": "Video",
    "zh-Hant": "影片",
    "zh-Hans": "视频",
    "de": "Video",
    "ar": "فيديو",
    "ja": "動画",
    "ko": "비디오",
    "th": "วิดีโอ",
    "yue-Hant": "影片",
    "en-SG": "Video",
}, note="Names the video kind in the reference list, beside Image and Audio. A file "
        "category.")
add("refs.kind.audio", {
    "en": "Audio",
    "zh-Hant": "音訊",
    "zh-Hans": "音频",
    "de": "Audio",
    "ar": "صوت",
    "ja": "オーディオ",
    "ko": "오디오",
    "th": "เสียง",
    "yue-Hant": "音訊",
    "en-SG": "Audio",
}, note="Names the audio *file* kind in the reference list, beside Image and Video. A "
        "category of attachment — see compose.audio.")
add("refs.footnote.first", {
    "en": "One image, used as the opening frame. The clip animates outward from it.",
    "zh-Hant": "一張圖片，作為開場影格，片段會由此延伸動態。",
    "zh-Hans": "一张图片，作为开场帧，片段会由此延伸动态。",
    "de": "Ein Bild als Anfangsbild. Der Clip animiert von dort aus.",
    "ar": "صورة واحدة تُستخدم كإطار افتتاحي، وينطلق منها تحريك المقطع.",
    "ja": "最初のフレームとして使う画像を 1 枚。クリップはそこから動き出します。",
    "ko": "첫 프레임으로 쓸 이미지 한 장. 클립은 거기서부터 움직이기 시작합니다.",
    "th": "ภาพหนึ่งภาพใช้เป็นเฟรมเปิด คลิปจะเคลื่อนไหวต่อออกไปจากภาพนั้น",
    "yue-Hant": "一張圖,做開場嗰格,條片由佢開始郁出去。",
    "en-SG": "One image, used as the opening frame. The clip moves outward from it.",
})
add("refs.footnote.firstlast", {
    "en": "Two images. The first becomes frame one, the second the final frame, and H3 "
          "generates the motion between them.",
    "zh-Hant": "兩張圖片：第一張為第一格，第二張為最後一格，H3 生成兩者之間的動態。",
    "zh-Hans": "两张图片：第一张为第一帧，第二张为最后一帧，H3 生成两者之间的动态。",
    "de": "Zwei Bilder. Das erste wird Bild eins, das zweite das Schlussbild; H3 erzeugt "
          "die Bewegung dazwischen.",
    "ar": "صورتان: الأولى تصبح الإطار الأول والثانية الإطار الأخير، ويولّد H3 الحركة "
          "بينهما.",
    "ja": "画像を 2 枚。1 枚目が最初のフレーム、2 枚目が最後のフレームになり、H3 がその間の動きを生成します。",
    "ko": "이미지 두 장. 첫 장이 첫 프레임, 둘째 장이 마지막 프레임이 되고 H3가 그 사이의 움직임을 만듭니다.",
    "th": "ภาพสองภาพ ภาพแรกเป็นเฟรมที่หนึ่ง ภาพที่สองเป็นเฟรมสุดท้าย แล้ว H3 จะสร้างการเคลื่อนไหวระหว่างกลาง",
    "yue-Hant": "兩張圖:第一張做第一格,第二張做最後一格,中間嘅郁動由 H3 生成。",
    "en-SG": "Two images. First one become frame one, second one become the last frame, then H3 makes the movement in between.",
})
add("refs.footnote.reference", {
    "en": "Up to 9 images, 3 videos and 3 audio clips, 12 files in total. Refer to them "
          "from the prompt as <Picture 1>, <Video 1>, <Audio 1> — H3 conditions on them "
          "through those tags, so an unmentioned reference has little effect.",
    "zh-Hant": "最多 9 張圖片、3 段影片與 3 段音訊，合計 12 個檔案。在提示詞中以 <Picture 1>、<Video 1>、<Audio 1> 指稱它們；H3 "
               "透過這些標記做條件化，沒有被提到的參考素材幾乎不起作用。",
    "zh-Hans": "最多 9 张图片、3 段视频与 3 段音频，合计 12 个文件。在提示词中以 <Picture 1>、<Video 1>、<Audio 1> 指称它们；H3 "
               "通过这些标记做条件化，没有被提到的参考素材几乎不起作用。",
    "de": "Bis zu 9 Bilder, 3 Videos und 3 Audioclips, insgesamt 12 Dateien. Im Prompt als "
          "<Picture 1>, <Video 1>, <Audio 1> ansprechen — H3 konditioniert über diese Tags, "
          "eine nicht erwähnte Referenz wirkt kaum.",
    "ar": "حتى 9 صور و3 مقاطع فيديو و3 مقاطع صوتية، بمجموع 12 ملفًا. أشِر إليها في الموجّه "
          "بصيغة <Picture 1> و<Video 1> و<Audio 1> — إذ يشترط H3 عليها عبر هذه الوسوم، "
          "فالمرجع غير المذكور يكاد لا يؤثّر.",
    "ja": "画像は最大 9 枚、動画 3 本、音声 3 本、合わせて 12 ファイルまで。プロンプトからは <Picture 1>、<Video 1>、<Audio 1> のように参照します。H3 はこのタグを通して条件付けするので、言及されていない参考素材はほとんど効きません。",
    "ko": "이미지 최대 9개, 비디오 3개, 오디오 3개로 모두 12개까지. 프롬프트에서는 <Picture 1>, <Video 1>, <Audio 1> 처럼 가리킵니다. H3가 그 태그를 통해 조건화하므로, 언급하지 않은 참조는 거의 영향이 없습니다.",
    "th": "ภาพได้สูงสุด 9 ภาพ วิดีโอ 3 คลิป และเสียง 3 คลิป รวม 12 ไฟล์ อ้างถึงใน prompt ว่า <Picture 1>, <Video 1>, <Audio 1> เพราะ H3 กำหนดเงื่อนไขผ่านแท็กเหล่านี้ ไฟล์อ้างอิงที่ไม่ได้เอ่ยถึงจึงแทบไม่มีผล",
    "yue-Hant": "最多 9 張圖、3 段片同 3 段聲,合共 12 個檔。喺提示詞度用 <Picture 1>、<Video 1>、<Audio 1> 嚟叫佢哋;H3 就係靠呢啲標記做條件,冇提過嘅參考素材幾乎唔起作用。",
    "en-SG": "Up to 9 images, 3 videos and 3 audio clips, 12 files all together. Call them inside the prompt as <Picture 1>, <Video 1>, <Audio 1> — H3 conditions on them through those tags, so any reference you never mention almost bo effect one.",
})

# ── Validation messages ──────────────────────────────────────────────────────
add("problem.prompt.empty", {
    "en": "Write a prompt describing the shot.",
    "zh-Hant": "請寫一段描述鏡頭的提示詞。",
    "zh-Hans": "请写一段描述镜头的提示词。",
    "de": "Schreibe einen Prompt, der die Einstellung beschreibt.",
    "ar": "اكتب موجّهًا يصف اللقطة.",
    "ja": "ショットを説明するプロンプトを書いてください。",
    "ko": "장면을 설명하는 프롬프트를 쓰세요.",
    "th": "เขียน prompt บรรยายช็อตที่ต้องการ",
    "yue-Hant": "寫段提示詞描述下個鏡頭。",
    "en-SG": "Write a prompt describing the shot lah.",
})
add("problem.duration", {
    "en": "H3 only generates 4–15 second clips.",
    "zh-Hant": "H3 只能生成 4–15 秒的片段。",
    "zh-Hans": "H3 只能生成 4–15 秒的片段。",
    "de": "H3 erzeugt nur Clips von 4–15 Sekunden.",
    "ar": "يولّد H3 مقاطع مدتها 4–15 ثانية فقط.",
    "ja": "H3 が生成できるのは 4〜15 秒のクリップだけです。",
    "ko": "H3는 4~15초 길이의 클립만 생성합니다.",
    "th": "H3 สร้างได้เฉพาะคลิปยาว 4–15 วินาทีเท่านั้น",
    "yue-Hant": "H3 淨係生成到 4–15 秒嘅片。",
    "en-SG": "H3 only can make 4–15 second clips.",
})
add("problem.t2v.extraFiles", {
    "en": "Text-to-video ignores attached files. Switch modes to use them.",
    "zh-Hant": "文字轉影片會忽略附加檔案。若要使用，請切換模式。",
    "zh-Hans": "文字转视频会忽略附加文件。若要使用，请切换模式。",
    "de": "Text-zu-Video ignoriert angehängte Dateien. Wechsle den Modus, um sie zu nutzen.",
    "ar": "يتجاهل وضع النص إلى فيديو الملفات المرفقة. بدّل الوضع لاستخدامها.",
    "ja": "テキストから動画では添付ファイルは無視されます。使うにはモードを切り替えてください。",
    "ko": "텍스트-비디오는 첨부 파일을 무시합니다. 쓰려면 모드를 바꾸세요.",
    "th": "โหมดข้อความเป็นวิดีโอจะไม่สนใจไฟล์แนบ ให้สลับโหมดหากต้องการใช้",
    "yue-Hant": "文字轉片會唔理附加檔案。想用就轉個模式。",
    "en-SG": "Text-to-video bo chup about attached files. Want to use them, switch mode first.",
})
add("problem.needFirst", {
    "en": "Add a first-frame image.",
    "zh-Hant": "請加入首格圖片。",
    "zh-Hans": "请添加首帧图片。",
    "de": "Füge ein Bild für das erste Bild hinzu.",
    "ar": "أضف صورة للإطار الأول.",
    "ja": "最初のフレームになる画像を追加してください。",
    "ko": "첫 프레임이 될 이미지를 추가하세요.",
    "th": "เพิ่มภาพสำหรับเฟรมแรก",
    "yue-Hant": "加張首格圖。",
    "en-SG": "Add a first-frame image.",
})
add("problem.needLast", {
    "en": "Add a last-frame image.",
    "zh-Hant": "請加入末格圖片。",
    "zh-Hans": "请添加末帧图片。",
    "de": "Füge ein Bild für das letzte Bild hinzu.",
    "ar": "أضف صورة للإطار الأخير.",
    "ja": "最後のフレームになる画像を追加してください。",
    "ko": "마지막 프레임이 될 이미지를 추가하세요.",
    "th": "เพิ่มภาพสำหรับเฟรมสุดท้าย",
    "yue-Hant": "加張末格圖。",
    "en-SG": "Add a last-frame image.",
})
add("problem.needReference", {
    "en": "Ref2VA needs at least one reference file.",
    "zh-Hant": "Ref2VA 至少需要一個參考檔案。",
    "zh-Hans": "Ref2VA 至少需要一个参考文件。",
    "de": "Ref2VA benötigt mindestens eine Referenzdatei.",
    "ar": "يتطلّب Ref2VA ملف مرجع واحدًا على الأقل.",
    "ja": "Ref2VA には参考ファイルが少なくとも 1 つ必要です。",
    "ko": "Ref2VA에는 참조 파일이 최소 하나 필요합니다.",
    "th": "Ref2VA ต้องมีไฟล์อ้างอิงอย่างน้อยหนึ่งไฟล์",
    "yue-Hant": "Ref2VA 至少要一個參考檔案。",
    "en-SG": "Ref2VA needs at least one reference file.",
})
add("problem.tooManyTotal", {
    "en": "Ref2VA accepts %@ reference files in total.",
    "zh-Hant": "Ref2VA 總共最多接受 %@ 個參考檔案。",
    "zh-Hans": "Ref2VA 总共最多接受 %@ 个参考文件。",
    "de": "Ref2VA akzeptiert insgesamt %@ Referenzdateien.",
    "ar": "يقبل Ref2VA %@ ملف مرجع بالإجمال.",
    "ja": "Ref2VA が受け付ける参考ファイルは合計 %@ 件までです。",
    "ko": "Ref2VA는 참조 파일을 모두 합쳐 %@ 개까지 받습니다.",
    "th": "Ref2VA รับไฟล์อ้างอิงได้รวมทั้งหมด %@ ไฟล์",
    "yue-Hant": "Ref2VA 總共最多收 %@ 個參考檔案。",
    "en-SG": "Ref2VA takes %@ reference files in total only.",
}, note={
    "content": "Takes a count of reference files, though the value is always "
               "ReferenceAsset.totalFileLimit, which is 12. A placeholder that only ever holds "
               "one constant: the plural risk is theoretical, and the number could as easily be "
               "written into each translation, which would let every language inflect around it.",
    "level": WARNING,
})
add("problem.notInstalled", {
    "en": "The selected checkpoint isn't installed yet.",
    "zh-Hant": "所選的檢查點尚未安裝。",
    "zh-Hans": "所选的检查点尚未安装。",
    "de": "Der gewählte Checkpoint ist noch nicht installiert.",
    "ar": "نقطة التحقق المحددة غير مثبتة بعد.",
    "ja": "選択したチェックポイントはまだインストールされていません。",
    "ko": "선택한 체크포인트가 아직 설치되지 않았습니다.",
    "th": "ยังไม่ได้ติดตั้ง checkpoint ที่เลือก",
    "yue-Hant": "揀咗嘅檢查點仲未裝。",
    "en-SG": "The checkpoint you chose never install yet.",
})
add("problem.chooseCheckpoint", {
    "en": "Choose a %@ checkpoint in Models.",
    "zh-Hant": "請在「模型」中選擇 %@ 檢查點。",
    "zh-Hans": "请在“模型”中选择 %@ 检查点。",
    "de": "Wähle unter „Modelle“ einen %@-Checkpoint.",
    "ar": "اختر نقطة تحقق %@ من «النماذج».",
    "ja": "「モデル」で %@ のチェックポイントを選んでください。",
    "ko": "모델에서 %@ 체크포인트를 고르세요.",
    "th": "เลือก checkpoint %@ ในหน้าโมเดล",
    "yue-Hant": "去「模型」度揀個 %@ 檢查點。",
    "en-SG": "Go Models and choose a %@ checkpoint.",
}, note={
    "content": "Injects a task name into the noun phrase \"a %@ checkpoint\". The English article "
               "is fixed as \"a\", so a name beginning with a vowel sound already reads \"a FL2VA\" "
               "wrongly, and gendered languages cannot choose their article at all.",
    "level": WARNING,
})
add("problem.lowSteps", {
    "en": "Below 8 steps the model tends to produce soft, unstable motion.",
    "zh-Hant": "低於 8 步時，模型容易產生模糊、不穩定的動態。",
    "zh-Hans": "低于 8 步时，模型容易产生模糊、不稳定的动态。",
    "de": "Unter 8 Schritten erzeugt das Modell eher weiche, instabile Bewegung.",
    "ar": "دون 8 خطوات يميل النموذج إلى حركة ناعمة غير مستقرة.",
    "ja": "8 ステップを下回ると、動きが眠く不安定になりがちです。",
    "ko": "8스텝 아래에서는 움직임이 흐릿하고 불안정해지는 경향이 있습니다.",
    "th": "ต่ำกว่า 8 step โมเดลมักให้การเคลื่อนไหวที่เบลอและไม่นิ่ง",
    "yue-Hant": "低過 8 步，個模型好容易出鬆散又唔穩嘅動態。",
    "en-SG": "Below 8 steps, the model tends to give soft, unstable movement.",
})
add("problem.longOvernight", {
    "en": "Long clips at high step counts can run overnight. Consider a short test first.",
    "zh-Hant": "長片段搭配高步數可能需要整夜。建議先做一次短測試。",
    "zh-Hans": "长片段搭配高步数可能需要整夜。建议先做一次短测试。",
    "de": "Lange Clips mit hoher Schrittzahl können über Nacht laufen. Erst einen kurzen "
          "Test erwägen.",
    "ar": "قد تستغرق المقاطع الطويلة بأعداد خطوات كبيرة ليلة كاملة. جرّب اختبارًا قصيرًا "
          "أولًا.",
    "ja": "ステップ数の多い長いクリップは一晩かかることがあります。まず短いテストを試すことをおすすめします。",
    "ko": "스텝 수가 많은 긴 클립은 밤새 걸릴 수 있습니다. 먼저 짧게 시험해 보세요.",
    "th": "คลิปยาวที่ใช้ step มากอาจกินเวลาข้ามคืน ลองทดสอบสั้น ๆ ก่อนดีกว่า",
    "yue-Hant": "長片再加高步數，可能要成晚。不如先試條短嘅。",
    "en-SG": "Long clip plus high step count, can chiong whole night one. Test a short one first lah, don't anyhow whack.",
})
add("problem.upscale", {
    "en": "%@ is a resample of the model's 768p output. H3's true 2K mode is not "
          "open-sourced and cannot run locally.",
    "zh-Hant": "%@ 只是模型 768p 輸出的重新取樣。H3 真正的 2K 模式未開源，無法在本機執行。",
    "zh-Hans": "%@ 只是模型 768p 输出的重新采样。H3 真正的 2K 模式未开源，无法在本机运行。",
    "de": "%@ ist ein Resampling der 768p-Ausgabe des Modells. Der echte 2K-Modus von H3 "
          "ist nicht quelloffen und läuft nicht lokal.",
    "ar": "‏%@ مجرد إعادة أخذ عيّنات لإخراج النموذج بدقة 768p. أما وضع 2K الحقيقي في H3 "
          "فليس مفتوح المصدر ولا يمكن تشغيله محليًا.",
    "ja": "%@ はモデルの 768p 出力をリサンプルしたものです。H3 本来の 2K モードは公開されておらず、ローカルでは動きません。",
    "ko": "%@ 은(는) 모델의 768p 출력을 리샘플링한 것입니다. H3의 진짜 2K 모드는 공개되지 않았고 로컬에서는 돌릴 수 없습니다.",
    "th": "%@ เป็นการปรับขนาดจาก output 768p ของโมเดล โหมด 2K จริงของ H3 ไม่ได้เปิดซอร์สและรันในเครื่องไม่ได้",
    "yue-Hant": "%@ 只係將個模型 768p 嘅輸出重新取樣。H3 真正嘅 2K 模式冇開源，本機跑唔到。",
    "en-SG": "%@ is just a resample of the model's 768p output. H3's real 2K mode never open-source, so locally cannot run one.",
}, note={
    "content": "Injects a name into a sentence. Languages that inflect a noun for case, choose "
               "an article by gender, or attach a vowel-harmonising suffix cannot do it without "
               "knowing the word, and it is only known at runtime. Prefer wording that sets the "
               "name apart — quoted, or on its own line. Sentence-initial, as in "
               "problem.noMetalKernel.",
    "level": WARNING,
})
add("problem.refUntagged", {
    "en": "The prompt never mentions %@. H3 conditions on references through those tags — "
          "untagged ones have much less influence.",
    "zh-Hant": "提示詞中沒有提到 %@。H3 透過這些標記對參考素材做條件化，沒被標記的影響力小得多。",
    "zh-Hans": "提示词中没有提到 %@。H3 通过这些标记对参考素材做条件化，没被标记的影响力小得多。",
    "de": "Der Prompt erwähnt %@ nie. H3 konditioniert Referenzen über diese Tags — ohne "
          "Tag ist der Einfluss deutlich geringer.",
    "ar": "لا يذكر الموجّه %@ إطلاقًا. يشترط H3 على المراجع عبر هذه الوسوم، وما لا يُذكر "
          "يكون تأثيره أضعف بكثير.",
    "ja": "プロンプトが %@ に触れていません。H3 はこのタグを通して参考素材を条件付けするため、言及のないものは影響がずっと小さくなります。",
    "ko": "프롬프트가 %@ 을(를) 전혀 언급하지 않습니다. H3는 그 태그를 통해 참조를 조건화하므로, 언급되지 않은 참조는 영향이 훨씬 작습니다.",
    "th": "Prompt ไม่ได้เอ่ยถึง %@ เลย H3 กำหนดเงื่อนไขจากไฟล์อ้างอิงผ่านแท็กเหล่านั้น ไฟล์ที่ไม่ถูกเอ่ยถึงจึงมีผลน้อยกว่ามาก",
    "yue-Hant": "提示詞入面完全冇提過 %@。H3 就係靠呢啲標記對參考素材做條件，冇提到嘅影響細好多。",
    "en-SG": "Your prompt never mention %@ at all leh. H3 conditions on references through those tags, so the ones you never mention got very little influence.",
}, note={
    "content": "Injects a name into a sentence. Languages that inflect a noun for case, choose "
               "an article by gender, or attach a vowel-harmonising suffix cannot do it without "
               "knowing the word, and it is only known at runtime. Prefer wording that sets the "
               "name apart — quoted, or on its own line.",
    "level": WARNING,
})
add("problem.refSlow", {
    "en": "Reference mode runs through ComfyUI rather than MLX, which is slower per step. "
          "The 4-step turbo LoRA is what keeps it to minutes rather than hours.",
    "zh-Hant": "參考模式透過 ComfyUI 而非 MLX 執行，每步較慢。4 步 turbo LoRA 正是把時間控制在數分鐘而非數小時的關鍵。",
    "zh-Hans": "参考模式通过 ComfyUI 而非 MLX 运行，每步较慢。4 步 turbo LoRA 正是把时间控制在数分钟而非数小时的关键。",
    "de": "Der Referenzmodus läuft über ComfyUI statt MLX und ist pro Schritt langsamer. "
          "Die 4-Schritt-Turbo-LoRA hält es bei Minuten statt Stunden.",
    "ar": "يعمل وضع المراجع عبر ComfyUI بدل MLX، وهو أبطأ لكل خطوة. ونموذج turbo LoRA ذو "
          "الأربع خطوات هو ما يبقي الزمن بالدقائق لا بالساعات.",
    "ja": "参考素材モードは MLX ではなく ComfyUI を通るため、1 ステップあたりは遅くなります。4 ステップの turbo LoRA があるおかげで、何時間もではなく数十分で済んでいます。",
    "ko": "참조 모드는 MLX가 아니라 ComfyUI를 거치므로 스텝당 속도가 느립니다. 4스텝 turbo LoRA 덕분에 몇 시간이 아니라 수십 분으로 끝납니다.",
    "th": "โหมดไฟล์อ้างอิงทำงานผ่าน ComfyUI แทน MLX จึงช้ากว่าต่อ step turbo LoRA แบบ 4 step คือสิ่งที่ทำให้ใช้เวลาเป็นนาทีแทนที่จะเป็นชั่วโมง",
    "yue-Hant": "參考模式係透過 ComfyUI 而唔係 MLX 跑，每步慢啲。4 步 turbo LoRA 就係令佢維持喺幾分鐘而唔係幾個鐘嘅關鍵。",
    "en-SG": "Reference mode goes through ComfyUI, not MLX, so each step slower. The 4-step turbo LoRA is what keeps it to minutes instead of hours — if not, sian half.",
})
add("problem.blocking", {
    "en": "Blocking issue. %@",
    "zh-Hant": "阻擋問題：%@",
    "zh-Hans": "阻塞问题：%@",
    "de": "Blockierendes Problem. %@",
    "ar": "مشكلة مانعة. %@",
    "ja": "解決が必要です。%@",
    "ko": "해결해야 할 문제입니다. %@",
    "th": "ปัญหาที่ต้องแก้ก่อน %@",
    "yue-Hant": "阻住嘅問題：%@",
    "en-SG": "Cannot proceed. %@",
}, note={
    "content": "Wraps another translated sentence as \"Blocking issue. %@\". Two sentences glued "
               "together; the inner one was translated without knowing it would be prefixed.",
    "level": WARNING,
})
add("problem.note", {
    "en": "Note. %@",
    "zh-Hant": "提醒：%@",
    "zh-Hans": "提醒：%@",
    "de": "Hinweis. %@",
    "ar": "ملاحظة. %@",
    "ja": "補足。%@",
    "ko": "참고. %@",
    "th": "หมายเหตุ %@",
    "yue-Hant": "提提你：%@",
    "en-SG": "Just so you know. %@",
}, note={
    "content": "See problem.blocking — the same prefix-plus-sentence construction.",
    "level": WARNING,
})

# ── Settings ─────────────────────────────────────────────────────────────────
add("settings.general", {
    "en": "General",
    "zh-Hant": "一般",
    "zh-Hans": "通用",
    "de": "Allgemein",
    "ar": "عام",
    "ja": "一般",
    "ko": "일반",
    "th": "ทั่วไป",
    "yue-Hant": "一般",
    "en-SG": "General",
})
add("settings.runtime", {
    "en": "Runtime",
    "zh-Hant": "執行環境",
    "zh-Hans": "运行时",
    "de": "Laufzeitumgebung",
    "ar": "بيئة التشغيل",
    "ja": "実行環境",
    "ko": "런타임",
    "th": "Runtime",
    "yue-Hant": "執行環境",
    "en-SG": "Runtime",
}, note="The Python environment the app manages, not a term of art: TW says 執行環境, "
        "mainland 运行时.")
add("settings.advanced", {
    "en": "Advanced",
    "zh-Hant": "進階",
    "zh-Hans": "高级",
    "de": "Erweitert",
    "ar": "متقدّم",
    "ja": "詳細",
    "ko": "고급",
    "th": "ขั้นสูง",
    "yue-Hant": "進階",
    "en-SG": "Advanced",
})
add("settings.log.clear", {
    "en": "Clear",
    "zh-Hant": "清除",
    "zh-Hans": "清除",
    "de": "Leeren",
    "ar": "مسح",
    "ja": "消去",
    "ko": "지우기",
    "th": "ล้าง",
    "yue-Hant": "清走",
    "en-SG": "Clear",
}, note="Imperative verb: empty the log. Not the adjective \"clear\" meaning legible or "
        "transparent.")
add("settings.log.accessibility", {
    "en": "Installation log",
    "zh-Hant": "安裝記錄",
    "zh-Hans": "安装日志",
    "de": "Installationsprotokoll",
    "ar": "سجل التثبيت",
    "ja": "インストールログ",
    "ko": "설치 로그",
    "th": "บันทึกการติดตั้ง",
    "yue-Hant": "安裝記錄",
    "en-SG": "Installation log",
})
add("settings.runtime.rebuild.note", {
    "en": "Rebuilding deletes and recreates the Python environment. It does not touch "
          "downloaded weights.",
    "zh-Hant": "完全重建會刪除並重新建立 Python 執行環境，不會動到已下載的模型權重。",
    "zh-Hans": "完全重建会删除并重新创建 Python 运行时，不会影响已下载的模型权重。",
    "de": "Beim vollständigen Neuaufbau wird die Python-Umgebung gelöscht und neu erstellt. "
          "Geladene Gewichte bleiben unberührt.",
    "ar": "تؤدي إعادة البناء إلى حذف بيئة Python وإنشائها من جديد. ولا تمسّ الأوزان التي "
          "جرى تنزيلها.",
    "ja": "作り直すと Python 環境を削除して作成し直します。ダウンロード済みの重みには触れません。",
    "ko": "다시 만들면 Python 환경을 지우고 새로 만듭니다. 내려받은 가중치는 건드리지 않습니다.",
    "th": "การสร้างใหม่จะลบและสร้างสภาพแวดล้อม Python ขึ้นใหม่ โดยไม่แตะไฟล์น้ำหนักที่ดาวน์โหลดไว้",
    "yue-Hant": "完全重建會刪咗再重新整個 Python 執行環境，唔會郁已經下載咗嘅權重。",
    "en-SG": "Rebuild means delete then make the Python environment again. It never touch the weights you download already.",
})
add("settings.advanced.support.note", {
    "en": "Holds the Python environment, the render queue, and scratch files for in-flight "
          "renders.",
    "zh-Hant": "存放 Python 執行環境、算圖佇列，以及算圖進行中的暫存檔案。",
    "zh-Hans": "存放 Python 运行时、渲染队列，以及渲染进行中的临时文件。",
    "de": "Enthält die Python-Umgebung, die Renderwarteschlange und temporäre Dateien "
          "laufender Rendervorgänge.",
    "ar": "يحتوي على بيئة Python وقائمة انتظار التصيير والملفات المؤقتة لعمليات التصيير "
          "الجارية.",
    "ja": "Python 環境、レンダリングのキュー、進行中レンダリングの作業ファイルが入っています。",
    "ko": "Python 환경과 렌더링 대기열, 진행 중인 렌더링의 임시 파일이 들어 있습니다.",
    "th": "เก็บสภาพแวดล้อม Python คิวการเรนเดอร์ และไฟล์ชั่วคราวของงานที่กำลังเรนเดอร์",
    "yue-Hant": "放住 Python 執行環境、算圖佇列，同埋算緊嗰陣嘅暫存檔。",
    "en-SG": "Holds the Python environment, the render queue, and working files for renders still running.",
})
add("settings.folders", {
    "en": "Folders",
    "zh-Hant": "資料夾",
    "zh-Hans": "文件夹",
    "de": "Ordner",
    "ar": "المجلدات",
    "ja": "フォルダ",
    "ko": "폴더",
    "th": "โฟลเดอร์",
    "yue-Hant": "資料夾",
    "en-SG": "Folders",
})
add("settings.folder.models", {
    "en": "Models",
    "zh-Hant": "模型",
    "zh-Hans": "模型",
    "de": "Modelle",
    "ar": "النماذج",
    "ja": "モデル",
    "ko": "모델",
    "th": "โมเดล",
    "yue-Hant": "模型",
    "en-SG": "Models",
}, note="Labels the folder on disk where weights are stored, in Settings ▸ Folders. A "
        "location, not the tab — see section.models.")
add("settings.folder.output", {
    "en": "Output",
    "zh-Hant": "輸出",
    "zh-Hans": "输出",
    "de": "Ausgabe",
    "ar": "الإخراج",
    "ja": "出力",
    "ko": "출력",
    "th": "Output",
    "yue-Hant": "輸出",
    "en-SG": "Output",
}, note="Labels the folder finished videos are written to, in Settings ▸ Folders. A "
        "location — see compose.output.title.")
add("settings.queue.note", {
    "en": "Renders hold tens of gigabytes of weights in memory, so only one runs at a time. "
          "Hold or stop an individual render from its own row in the Queue.",
    "zh-Hant": "算圖會在記憶體中保留數十 GB 的權重，因此一次只執行一個。要暫緩或停止個別算圖，請在「佇列」中該列操作。",
    "zh-Hans": "渲染会在内存中保留数十 GB 的权重，因此一次只运行一个。要暂缓或停止单个渲染，请在“队列”中该行操作。",
    "de": "Renders halten zig Gigabyte an Gewichten im Speicher, daher läuft immer nur "
          "einer. Einzelne Renders lassen sich in ihrer Zeile in der Warteschlange "
          "zurückstellen oder anhalten.",
    "ar": "يحتفظ التصيير بعشرات الغيغابايتات من الأوزان في الذاكرة، لذا يعمل واحد فقط في كل "
          "مرة. يمكنك تعليق أو إيقاف أي تصيير من صفّه في قائمة الانتظار.",
    "ja": "レンダリングは数十 GB の重みをメモリに保持するため、同時に走るのは 1 件だけです。個々のレンダリングの保留や停止は、キューの各行から行えます。",
    "ko": "렌더링은 수십 GB의 가중치를 메모리에 올리므로 한 번에 하나만 돌아갑니다. 개별 렌더링의 보류나 정지는 대기열의 각 행에서 할 수 있습니다.",
    "th": "การเรนเดอร์ต้องเก็บไฟล์น้ำหนักหลายสิบกิกะไบต์ไว้ในหน่วยความจำ จึงทำได้ครั้งละหนึ่งงาน สั่งพักหรือหยุดแต่ละงานได้จากแถวของงานนั้นในคิว",
    "yue-Hant": "算圖會喺記憶體度攞住幾十 GB 權重，所以一次得一個跑。想暫緩或者停某一個，喺「佇列」入面嗰行做。",
    "en-SG": "Renders hold tens of gigabytes of weights inside memory, so only one can run at a time. Want to hold or stop one particular render, use its own row inside the Queue.",
})
add("settings.status", {
    "en": "Status",
    "zh-Hant": "狀態",
    "zh-Hans": "状态",
    "de": "Status",
    "ar": "الحالة",
    "ja": "ステータス",
    "ko": "상태",
    "th": "สถานะ",
    "yue-Hant": "狀態",
    "en-SG": "Status",
}, note="Heads the runtime status section in Settings. A section heading, not the "
        "status-bar label — see status.label.")
add("settings.python", {
    "en": "Python",
    "zh-Hant": "Python",
    "zh-Hans": "Python",
    "de": "Python",
    "ar": "Python",
    "ja": "Python",
    "ko": "Python",
    "th": "Python",
    "yue-Hant": "Python",
    "en-SG": "Python",
})
add("settings.architecture", {
    "en": "Architecture",
    "zh-Hant": "架構",
    "zh-Hans": "架构",
    "de": "Architektur",
    "ar": "البنية",
    "ja": "アーキテクチャ",
    "ko": "아키텍처",
    "th": "สถาปัตยกรรม",
    "yue-Hant": "架構",
    "en-SG": "Architecture",
})
add("settings.mlxMetal", {
    "en": "MLX on Metal",
    "zh-Hant": "MLX on Metal",
    "zh-Hans": "MLX on Metal",
    "de": "MLX auf Metal",
    "ar": "‏MLX على Metal",
    "ja": "Metal 上の MLX",
    "ko": "Metal 기반 MLX",
    "th": "MLX บน Metal",
    "yue-Hant": "MLX on Metal",
    "en-SG": "MLX on Metal",
})
add("settings.working", {
    "en": "Working",
    "zh-Hant": "正常",
    "zh-Hans": "正常",
    "de": "Funktioniert",
    "ar": "يعمل",
    "ja": "正常",
    "ko": "정상",
    "th": "ทำงานปกติ",
    "yue-Hant": "正常",
    "en-SG": "Steady",
}, note="Means the runtime is functioning correctly — NOT \"in progress\". The value "
        "shown beside settings.state when nothing is wrong. Translate as \"OK\" or "
        "\"functioning\", never as \"busy\".")
add("settings.notWorking", {
    "en": "Not working",
    "zh-Hant": "異常",
    "zh-Hans": "异常",
    "de": "Funktioniert nicht",
    "ar": "لا يعمل",
    "ja": "動作していません",
    "ko": "작동하지 않음",
    "th": "ใช้งานไม่ได้",
    "yue-Hant": "唔正常",
    "en-SG": "Not working",
})
add("settings.notFound", {
    "en": "Not found",
    "zh-Hant": "找不到",
    "zh-Hans": "未找到",
    "de": "Nicht gefunden",
    "ar": "غير موجود",
    "ja": "見つかりません",
    "ko": "찾을 수 없음",
    "th": "ไม่พบ",
    "yue-Hant": "搵唔到",
    "en-SG": "Cannot find",
})
add("settings.h3Pipeline", {
    "en": "H3 pipeline",
    "zh-Hant": "H3 管線",
    "zh-Hans": "H3 管线",
    "de": "H3-Pipeline",
    "ar": "خط معالجة H3",
    "ja": "H3 パイプライン",
    "ko": "H3 파이프라인",
    "th": "ไปป์ไลน์ H3",
    "yue-Hant": "H3 管線",
    "en-SG": "H3 pipeline",
})
add("settings.detected", {
    "en": "Detected",
    "zh-Hant": "已偵測",
    "zh-Hans": "已检测",
    "de": "Erkannt",
    "ar": "تم الكشف",
    "ja": "検出済み",
    "ko": "감지됨",
    "th": "ตรวจพบแล้ว",
    "yue-Hant": "偵測到",
    "en-SG": "Detected",
}, note="Adjective: the app found this component on the machine by itself. Reports a "
        "discovery, not an action available.")
add("settings.notDetected", {
    "en": "Not detected",
    "zh-Hant": "未偵測到",
    "zh-Hans": "未检测到",
    "de": "Nicht erkannt",
    "ar": "لم يُكتشف",
    "ja": "未検出",
    "ko": "감지되지 않음",
    "th": "ไม่พบ",
    "yue-Hant": "偵測唔到",
    "en-SG": "Cannot detect",
})
add("settings.recheck", {
    "en": "Re-check",
    "zh-Hant": "重新檢查",
    "zh-Hans": "重新检查",
    "de": "Erneut prüfen",
    "ar": "إعادة الفحص",
    "ja": "再確認",
    "ko": "다시 확인",
    "th": "ตรวจสอบอีกครั้ง",
    "yue-Hant": "再查一次",
    "en-SG": "Check Again",
})
add("settings.repair", {
    "en": "Repair",
    "zh-Hant": "修復",
    "zh-Hans": "修复",
    "de": "Reparieren",
    "ar": "إصلاح",
    "ja": "修復",
    "ko": "복구",
    "th": "ซ่อมแซม",
    "yue-Hant": "修復",
    "en-SG": "Repair",
}, note="Imperative verb on a button: reinstall the broken parts of the runtime. Not "
        "a noun.")
add("settings.rebuild", {
    "en": "Rebuild from Scratch",
    "zh-Hant": "完全重建",
    "zh-Hans": "完全重建",
    "de": "Komplett neu aufbauen",
    "ar": "إعادة البناء من الصفر",
    "ja": "一から作り直す",
    "ko": "처음부터 다시 만들기",
    "th": "สร้างใหม่ทั้งหมด",
    "yue-Hant": "完全重建",
    "en-SG": "Rebuild Everything",
})
add("settings.log", {
    "en": "Log",
    "zh-Hant": "記錄",
    "zh-Hans": "日志",
    "de": "Protokoll",
    "ar": "السجل",
    "ja": "ログ",
    "ko": "로그",
    "th": "บันทึก",
    "yue-Hant": "記錄",
    "en-SG": "Log",
}, note="Noun: the record of what the runtime printed. Not the verb \"to log\", and not "
        "a logarithm.")
add("settings.notInstalled", {
    "en": "Not installed.",
    "zh-Hant": "尚未安裝。",
    "zh-Hans": "尚未安装。",
    "de": "Nicht installiert.",
    "ar": "غير مثبَّت.",
    "ja": "未インストールです。",
    "ko": "설치되지 않았습니다.",
    "th": "ยังไม่ได้ติดตั้ง",
    "yue-Hant": "仲未裝。",
    "en-SG": "Never install.",
})
add("settings.state", {
    "en": "State",
    "zh-Hant": "狀態",
    "zh-Hans": "状态",
    "de": "Zustand",
    "ar": "الحالة",
    "ja": "状態",
    "ko": "상태",
    "th": "สภาพ",
    "yue-Hant": "狀態",
    "en-SG": "State",
}, note="Labels one row reporting the runtime's condition. German separates this "
        "(Zustand) from Status; English does not. If a language has only one word, "
        "using it for both is fine.")
add("settings.comfy.server", {
    "en": "Server",
    "zh-Hant": "伺服器",
    "zh-Hans": "服务器",
    "de": "Server",
    "ar": "الخادم",
    "ja": "サーバー",
    "ko": "서버",
    "th": "เซิร์ฟเวอร์",
    "yue-Hant": "伺服器",
    "en-SG": "Server",
})
add("settings.comfy.running", {
    "en": "running on port %@",
    "zh-Hant": "執行中，連接埠 %@",
    "zh-Hans": "运行中，端口 %@",
    "de": "läuft auf Port %@",
    "ar": "يعمل على المنفذ %@",
    "ja": "ポート %@ で稼働中",
    "ko": "포트 %@ 에서 실행 중",
    "th": "ทำงานอยู่ที่พอร์ต %@",
    "yue-Hant": "跑緊，連接埠 %@",
    "en-SG": "running on port %@",
})
add("settings.comfy.notRunning", {
    "en": "not running",
    "zh-Hant": "未執行",
    "zh-Hans": "未运行",
    "de": "läuft nicht",
    "ar": "لا يعمل",
    "ja": "停止中",
    "ko": "실행 중 아님",
    "th": "ไม่ได้ทำงาน",
    "yue-Hant": "冇跑緊",
    "en-SG": "not running",
})
add("settings.comfy.weights", {
    "en": "Weights",
    "zh-Hant": "權重",
    "zh-Hans": "权重",
    "de": "Gewichte",
    "ar": "الأوزان",
    "ja": "重み",
    "ko": "가중치",
    "th": "ไฟล์น้ำหนัก",
    "yue-Hant": "權重",
    "en-SG": "Weights",
}, note="Model weights — the trained parameters of a neural network. Never the sense "
        "of heaviness or of weighting a value. Many languages keep the English term.")
add("settings.comfy.install", {
    "en": "Install",
    "zh-Hant": "安裝",
    "zh-Hans": "安装",
    "de": "Installieren",
    "ar": "تثبيت",
    "ja": "インストール",
    "ko": "설치",
    "th": "ติดตั้ง",
    "yue-Hant": "安裝",
    "en-SG": "Install",
}, note="Imperative verb on a button. Not the noun \"installation\", which is a "
        "different word in most languages.")
add("settings.comfy.stop", {
    "en": "Stop Server",
    "zh-Hant": "停止伺服器",
    "zh-Hans": "停止服务器",
    "de": "Server anhalten",
    "ar": "إيقاف الخادم",
    "ja": "サーバーを停止",
    "ko": "서버 정지",
    "th": "หยุดเซิร์ฟเวอร์",
    "yue-Hant": "停伺服器",
    "en-SG": "Stop Server",
})
add("settings.comfy.why", {
    "en": "Reference mode runs here rather than on MLX, whose pipeline accepts keyframes "
          "only. ComfyUI also loads the 4-step turbo LoRAs, which is what makes reference "
          "renders practical at all.",
    "zh-Hant": "參考模式在此執行，而非 MLX，因為 MLX 的管線只接受關鍵格。ComfyUI 還能載入 4 步 turbo LoRA，這正是參考模式算圖得以可行的原因。",
    "zh-Hans": "参考模式在此运行，而非 MLX，因为 MLX 的管线只接受关键帧。ComfyUI 还能加载 4 步 turbo LoRA，这正是参考模式渲染得以可行的原因。",
    "de": "Der Referenzmodus läuft hier statt auf MLX, dessen Pipeline nur Keyframes "
          "annimmt. ComfyUI lädt zudem die 4-Schritt-Turbo-LoRAs — erst dadurch werden "
          "Referenz-Renders überhaupt praktikabel.",
    "ar": "يعمل وضع المراجع هنا بدل MLX، إذ لا تقبل منظومته سوى الإطارات المفتاحية. كما "
          "يحمّل ComfyUI نماذج turbo LoRA ذات الأربع خطوات، وهو ما يجعل التصيير المرجعي "
          "عمليًا أصلًا.",
    "ja": "参考素材モードは、キーフレームしか受け付けない MLX ではなくこちらで動きます。ComfyUI は 4 ステップの turbo LoRA も読み込め、それが参考素材のレンダリングを現実的にしています。",
    "ko": "참조 모드는 키프레임만 받는 MLX가 아니라 여기서 돌아갑니다. ComfyUI는 4스텝 turbo LoRA도 불러올 수 있는데, 그것이 참조 렌더링을 현실적으로 만들어 줍니다.",
    "th": "โหมดไฟล์อ้างอิงทำงานที่นี่แทน MLX ซึ่งไปป์ไลน์รับได้เฉพาะ keyframe ComfyUI ยังโหลด turbo LoRA แบบ 4 step ได้ ซึ่งเป็นสิ่งที่ทำให้การเรนเดอร์ด้วยไฟล์อ้างอิงเป็นไปได้จริง",
    "yue-Hant": "參考模式喺呢度跑，唔喺 MLX，因為 MLX 個管線淨係收關鍵格。ComfyUI 仲載入到 4 步 turbo LoRA，呢樣嘢先令到參考素材算圖做得過。",
    "en-SG": "Reference mode runs here, not on MLX, because the MLX pipeline only takes keyframes. ComfyUI also loads the 4-step turbo LoRAs — that one is what makes reference renders practical at all.",
})
add("settings.comfy.note", {
    "en": "The app's own headless ComfyUI, kept apart from any you have installed yourself. "
          "The server starts on demand and stops with the app.",
    "zh-Hant": "這是 App 自帶的無介面 ComfyUI，與你自行安裝的版本互不干擾。伺服器會在需要時啟動，並隨 App 結束。",
    "zh-Hans": "这是 App 自带的无界面 ComfyUI，与你自行安装的版本互不干扰。服务器会在需要时启动，并随 App 退出。",
    "de": "Das eigene headless ComfyUI der App, getrennt von jedem selbst installierten. "
          "Der Server startet bei Bedarf und endet mit der App.",
    "ar": "نسخة ComfyUI الخاصة بالتطبيق بلا واجهة، منفصلة عن أي نسخة ثبّتها بنفسك. يبدأ "
          "الخادم عند الحاجة ويتوقف مع إغلاق التطبيق.",
    "ja": "このアプリ専用のヘッドレス ComfyUI で、自分で入れたものとは分けて管理されます。サーバーは必要なときに起動し、アプリの終了と一緒に止まります。",
    "ko": "이 앱 전용 헤드리스 ComfyUI로, 직접 설치한 것과는 따로 둡니다. 서버는 필요할 때 시작되고 앱과 함께 종료됩니다.",
    "th": "ComfyUI แบบไม่มีหน้าจอของแอปนี้เอง แยกจากตัวที่คุณติดตั้งไว้เอง เซิร์ฟเวอร์จะเริ่มเมื่อต้องใช้ และหยุดพร้อมกับแอป",
    "yue-Hant": "呢個係 App 自己嗰個無介面 ComfyUI，同你自己裝嗰個分開。個伺服器要用嗰陣先開，收 App 就一齊收。",
    "en-SG": "This is the app's own headless ComfyUI, keep separate from whichever one you install yourself. The server only start when need, and stop together with the app.",
})
add("settings.advanced.port", {
    "en": "MiniMax-H3 port",
    "zh-Hant": "MiniMax-H3 移植版",
    "zh-Hans": "MiniMax-H3 移植版",
    "de": "MiniMax-H3-Portierung",
    "ar": "نقل MiniMax-H3",
    "ja": "MiniMax-H3 移植版",
    "ko": "MiniMax-H3 이식판",
    "th": "พอร์ต MiniMax-H3",
    "yue-Hant": "MiniMax-H3 移植版",
    "en-SG": "MiniMax-H3 port",
})
add("settings.advanced.checkout", {
    "en": "Checkout path",
    "zh-Hant": "簽出路徑",
    "zh-Hans": "检出路径",
    "de": "Checkout-Pfad",
    "ar": "مسار النسخة",
    "ja": "チェックアウトのパス",
    "ko": "체크아웃 경로",
    "th": "Path ของ checkout",
    "yue-Hant": "簽出路徑",
    "en-SG": "Checkout path",
})
add("settings.advanced.checkout.hint", {
    "en": "Leave empty to use the installed package",
    "zh-Hant": "留空則使用已安裝的套件",
    "zh-Hans": "留空则使用已安装的包",
    "de": "Leer lassen, um das installierte Paket zu verwenden",
    "ar": "اتركه فارغًا لاستخدام الحزمة المثبتة",
    "ja": "空欄のままならインストール済みパッケージを使います",
    "ko": "비워 두면 설치된 패키지를 사용합니다",
    "th": "เว้นว่างไว้เพื่อใช้แพ็กเกจที่ติดตั้งไว้",
    "yue-Hant": "留空就用已經裝咗嘅套件",
    "en-SG": "Leave empty to use the installed package",
})
add("settings.advanced.reveal", {
    "en": "Reveal Application Support Folder",
    "zh-Hant": "顯示 Application Support 資料夾",
    "zh-Hans": "显示 Application Support 文件夹",
    "de": "Ordner „Application Support“ zeigen",
    "ar": "إظهار مجلد Application Support",
    "ja": "Application Support フォルダを表示",
    "ko": "Application Support 폴더 보기",
    "th": "แสดงโฟลเดอร์ Application Support",
    "yue-Hant": "顯示 Application Support 資料夾",
    "en-SG": "Show Application Support Folder",
})

# ── Remaining onboarding / runtime prose ─────────────────────────────────────
add("onboarding.licence.heading", {
    "en": "MiniMax H3 Community License",
    "zh-Hant": "MiniMax H3 社群授權條款",
    "zh-Hans": "MiniMax H3 社区许可协议",
    "de": "MiniMax H3 Community License",
    "ar": "ترخيص مجتمع MiniMax H3",
    "ja": "MiniMax H3 コミュニティライセンス",
    "ko": "MiniMax H3 커뮤니티 라이선스",
    "th": "สัญญาอนุญาตชุมชน MiniMax H3",
    "yue-Hant": "MiniMax H3 社群授權條款",
    "en-SG": "MiniMax H3 Community Licence",
}, note="The licence's proper name stays in English; TW/CN gloss it.")
add("runtime.ready", {
    "en": "Runtime ready — Python %1$@, MLX on Metal",
    "zh-Hant": "執行環境就緒 — Python %1$@，MLX on Metal",
    "zh-Hans": "运行环境就绪 — Python %1$@，MLX on Metal",
    "de": "Laufzeitumgebung bereit — Python %1$@, MLX auf Metal",
    "ar": "بيئة التشغيل جاهزة — Python %1$@، وMLX على Metal",
    "ja": "実行環境の準備完了 — Python %1$@、Metal 上の MLX",
    "ko": "런타임 준비 완료 — Python %1$@, Metal 기반 MLX",
    "th": "Runtime พร้อมแล้ว — Python %1$@, MLX บน Metal",
    "yue-Hant": "執行環境 ready 喇 — Python %1$@，MLX on Metal",
    "en-SG": "Runtime ready — Python %1$@, MLX on Metal",
})
add("runtime.installedNotUsable", {
    "en": "Installed, but not usable yet",
    "zh-Hant": "已安裝，但尚無法使用",
    "zh-Hans": "已安装，但尚无法使用",
    "de": "Installiert, aber noch nicht nutzbar",
    "ar": "مثبَّت، لكنه غير قابل للاستخدام بعد",
    "ja": "インストール済みですが、まだ使えません",
    "ko": "설치되었지만 아직 사용할 수 없음",
    "th": "ติดตั้งแล้ว แต่ยังใช้งานไม่ได้",
    "yue-Hant": "裝咗，但係仲未用得",
    "en-SG": "Install already, but still cannot use",
})
add("runtime.notInstalledYet", {
    "en": "Not installed yet.",
    "zh-Hant": "尚未安裝。",
    "zh-Hans": "尚未安装。",
    "de": "Noch nicht installiert.",
    "ar": "غير مثبَّت بعد.",
    "ja": "まだインストールされていません。",
    "ko": "아직 설치되지 않았습니다.",
    "th": "ยังไม่ได้ติดตั้ง",
    "yue-Hant": "仲未裝。",
    "en-SG": "Never install yet.",
})
add("models.revealInFinder", {
    "en": "Reveal %@ in Finder",
    "zh-Hant": "在 Finder 中顯示 %@",
    "zh-Hans": "在 Finder 中显示 %@",
    "de": "%@ im Finder zeigen",
    "ar": "إظهار %@ في Finder",
    "ja": "%@ を Finder に表示",
    "ko": "Finder에서 %@ 보기",
    "th": "แสดง %@ ใน Finder",
    "yue-Hant": "喺 Finder 度顯示 %@",
    "en-SG": "Show %@ in Finder",
}, note={
    "content": "Injects a name into a sentence. Languages that inflect a noun for case, choose "
               "an article by gender, or attach a vowel-harmonising suffix cannot do it without "
               "knowing the word, and it is only known at runtime. Prefer wording that sets the "
               "name apart — quoted, or on its own line.",
    "level": WARNING,
})

# ── Duration formatting ──────────────────────────────────────────────────────
add("format.seconds", {
    "en": "%@ s",
    "zh-Hant": "%@ 秒",
    "zh-Hans": "%@ 秒",
    "de": "%@ s",
    "ar": "%@ ث",
    "ja": "%@ 秒",
    "ko": "%@ 초",
    "th": "%@ วินาที",
    "yue-Hant": "%@ 秒",
    "en-SG": "%@ s",
})
add("format.minutes", {
    "en": "%@ min",
    "zh-Hant": "%@ 分",
    "zh-Hans": "%@ 分",
    "de": "%@ Min.",
    "ar": "%@ د",
    "ja": "%@ 分",
    "ko": "%@ 분",
    "th": "%@ นาที",
    "yue-Hant": "%@ 分",
    "en-SG": "%@ min",
})
add("format.hours", {
    "en": "%@ h",
    "zh-Hant": "%@ 小時",
    "zh-Hans": "%@ 小时",
    "de": "%@ Std.",
    "ar": "%@ س",
    "ja": "%@ 時間",
    "ko": "%@ 시간",
    "th": "%@ ชั่วโมง",
    "yue-Hant": "%@ 個鐘",
    "en-SG": "%@ h",
})
add("format.hoursMinutes", {
    "en": "%1$@ h %2$@ min",
    "zh-Hant": "%1$@ 小時 %2$@ 分",
    "zh-Hans": "%1$@ 小时 %2$@ 分",
    "de": "%1$@ Std. %2$@ Min.",
    "ar": "%1$@ س %2$@ د",
    "ja": "%1$@ 時間 %2$@ 分",
    "ko": "%1$@ 시간 %2$@ 분",
    "th": "%1$@ ชั่วโมง %2$@ นาที",
    "yue-Hant": "%1$@ 個鐘 %2$@ 分",
    "en-SG": "%1$@ h %2$@ min",
})

# ── Models: roles and tasks ──────────────────────────────────────────────────
add("role.transformer.detail", {
    "en": "The model itself. Pick one quantization; higher precision costs disk, memory and "
          "time.",
    "zh-Hant": "模型本體。擇一量化版本；精度越高，佔用的磁碟、記憶體與時間也越多。",
    "zh-Hans": "模型本体。择一量化版本；精度越高，占用的磁盘、内存与时间也越多。",
    "de": "Das Modell selbst. Wählen Sie eine Quantisierung; höhere Präzision kostet "
          "Speicherplatz, Arbeitsspeicher und Zeit.",
    "ar": "النموذج نفسه. اختر تكميمًا واحدًا؛ فكلما ارتفعت الدقة زاد استهلاك القرص والذاكرة "
          "والوقت.",
    "ja": "モデル本体です。量子化をひとつ選びます。精度を上げるほどディスク・メモリ・時間を使います。",
    "ko": "모델 본체입니다. 양자화를 하나 고르세요. 정밀도가 높을수록 디스크와 메모리, 시간을 더 씁니다.",
    "th": "ตัวโมเดลเอง เลือก quantization หนึ่งแบบ ยิ่งความแม่นยำสูง ยิ่งกินพื้นที่ หน่วยความจำ และเวลา",
    "yue-Hant": "模型本體。揀一個量化版本；精度越高，佔嘅碟、記憶體同時間就越多。",
    "en-SG": "The model itself. Choose one quantization — higher precision means more disk, more memory, more time. Cannot have everything one.",
})
add("role.textEncoder.detail", {
    "en": "H3 conditions on Qwen3-VL-32B. This is the largest single download and is shared "
          "by both tasks.",
    "zh-Hant": "H3 以 Qwen3-VL-32B 作為條件輸入。這是單一檔案中最大的下載項目，兩種任務共用。",
    "zh-Hans": "H3 以 Qwen3-VL-32B 作为条件输入。这是单个文件中最大的下载项，两种任务共用。",
    "de": "H3 wird auf Qwen3-VL-32B konditioniert. Das ist der größte Einzeldownload und "
          "wird von beiden Aufgaben genutzt.",
    "ar": "يعتمد H3 على Qwen3-VL-32B. وهو أكبر تنزيل مفرد، وتشترك فيه المهمتان.",
    "ja": "H3 は Qwen3-VL-32B を条件に使います。単体では最大のダウンロードで、両方のタスクで共有されます。",
    "ko": "H3는 Qwen3-VL-32B를 조건으로 사용합니다. 단일 항목으로는 가장 큰 다운로드이며 두 작업이 공유합니다.",
    "th": "H3 ใช้ Qwen3-VL-32B เป็นเงื่อนไข เป็นไฟล์ดาวน์โหลดเดี่ยวที่ใหญ่ที่สุด และใช้ร่วมกันทั้งสองงาน",
    "yue-Hant": "H3 攞 Qwen3-VL-32B 做條件。單一檔案入面佢最大,兩個任務共用。",
    "en-SG": "H3 conditions on Qwen3-VL-32B. Biggest single download, and both tasks tompang the same one.",
})
add("role.support.detail", {
    "en": "Small, mandatory, and shared by everything. Install once.",
    "zh-Hant": "檔案小、必要，且所有項目共用。安裝一次即可。",
    "zh-Hans": "文件小、必需，且所有项目共用。安装一次即可。",
    "de": "Klein, zwingend erforderlich und von allem gemeinsam genutzt. Einmal "
          "installieren.",
    "ar": "صغيرة وإلزامية ومشتركة بين كل شيء. تُثبَّت مرة واحدة.",
    "ja": "小さく、必須で、すべてで共有されます。一度入れれば十分です。",
    "ko": "작고, 필수이며, 모든 곳에서 공유됩니다. 한 번만 설치하면 됩니다.",
    "th": "ขนาดเล็ก จำเป็น และใช้ร่วมกันทั้งหมด ติดตั้งครั้งเดียวพอ",
    "yue-Hant": "細、一定要有，而且大家共用。裝一次就夠。",
    "en-SG": "Small, must have, and everything share the same one. Install once can already, no need repeat.",
})
add("role.accelerator.detail", {
    "en": "Optional LoRAs trained to produce usable video in around 4 steps instead of 50.",
    "zh-Hant": "選用的 LoRA，經訓練後約 4 步即可產出可用影片，而非 50 步。",
    "zh-Hans": "可选的 LoRA，经训练后约 4 步即可产出可用视频，而非 50 步。",
    "de": "Optionale LoRAs, trainiert für brauchbares Video in etwa 4 statt 50 Schritten.",
    "ar": "نماذج LoRA اختيارية مدرَّبة لإنتاج فيديو صالح في نحو 4 خطوات بدل 50.",
    "ja": "50 ステップではなく約 4 ステップで使える映像を出すために学習された、任意の LoRA です。",
    "ko": "50스텝 대신 약 4스텝만으로 쓸 만한 영상을 내도록 학습된 선택적 LoRA입니다.",
    "th": "LoRA เสริมที่ฝึกมาให้ได้วิดีโอที่ใช้งานได้ในราว 4 step แทนที่จะเป็น 50",
    "yue-Hant": "可揀可唔揀嘅 LoRA，訓練成大概 4 步就出到可以用嘅片，唔使 50 步。",
    "en-SG": "Optional LoRAs, trained to give usable video in about 4 steps instead of 50. Damn big time saver.",
})
add("task.fl2va.detail", {
    "en": "Text-to-video, plus optional first and/or last frame images. Use this for most "
          "work.",
    "zh-Hant": "文字轉影片，並可選擇性指定首張與／或末張影格圖片。多數情況用這個。",
    "zh-Hans": "文字转视频，并可选择性指定首帧与/或末帧图片。多数情况用这个。",
    "de": "Text zu Video, dazu optional Bilder für das erste und/oder letzte Bild. Für die "
          "meisten Arbeiten geeignet.",
    "ar": "من نص إلى فيديو، مع إمكانية تحديد صورة للإطار الأول و/أو الأخير. استخدم هذا في "
          "معظم الأعمال.",
    "ja": "テキストからの生成に加えて、先頭・末尾の画像を任意で指定できます。通常はこちらを使います。",
    "ko": "텍스트-비디오에 더해 첫 프레임과 마지막 프레임 이미지를 선택적으로 쓸 수 있습니다. 대부분의 작업에는 이것을 쓰세요.",
    "th": "สร้างวิดีโอจากข้อความ พร้อมใส่ภาพเฟรมแรกและ/หรือเฟรมสุดท้ายได้ตามต้องการ ใช้ตัวนี้กับงานส่วนใหญ่",
    "yue-Hant": "文字轉片，仲可以隨意加首格同／或者尾格嘅圖。大部分情況用呢個。",
    "en-SG": "Text-to-video, and if you want can add first and/or last frame images. Use this one for most things lah.",
})
add("task.ref2va.detail", {
    "en": "Conditions on up to 9 reference images, 3 reference videos and 3 reference audio "
          "clips.",
    "zh-Hant": "最多可依據 9 張參考圖片、3 段參考影片與 3 段參考音訊生成。",
    "zh-Hans": "最多可依据 9 张参考图片、3 段参考视频与 3 段参考音频生成。",
    "de": "Konditioniert auf bis zu 9 Referenzbilder, 3 Referenzvideos und 3 "
          "Referenz-Audioclips.",
    "ar": "يعتمد على ما يصل إلى 9 صور و3 مقاطع فيديو و3 مقاطع صوتية مرجعية.",
    "ja": "参考画像を最大 9 枚、参考動画を 3 本、参考音声を 3 本まで条件に使えます。",
    "ko": "참조 이미지 최대 9개, 참조 비디오 3개, 참조 오디오 3개까지 조건으로 씁니다.",
    "th": "กำหนดเงื่อนไขได้สูงสุด ภาพอ้างอิง 9 ภาพ วิดีโออ้างอิง 3 คลิป และเสียงอ้างอิง 3 คลิป",
    "yue-Hant": "最多可以跟 9 張參考圖、3 段參考片同 3 段參考聲嚟生成。",
    "en-SG": "Can condition on up to 9 reference images, 3 reference videos and 3 reference audio clips. Quite a lot already.",
})

# ── Models: per-entry summaries ──────────────────────────────────────────────
# Model, repository and format names stay as they are; only the prose around
# them is translated.
add("model.support.mlx", {
    "en": "Video VAE (10.4 GB), audio VAE, processor and tokenizer, taken from the FL2VA "
          "task directory the pipeline loads as a unit. Required by every run.",
    "zh-Hant": "video VAE（10.4 GB）、audio VAE、處理器與 tokenizer，取自 pipeline 整包載入的 FL2VA "
               "任務目錄。每次算圖都需要。",
    "zh-Hans": "video VAE（10.4 GB）、audio VAE、处理器与 tokenizer，取自 pipeline 整包加载的 FL2VA "
               "任务目录。每次渲染都需要。",
    "de": "Video-VAE (10,4 GB), Audio-VAE, Prozessor und Tokenizer aus dem "
          "FL2VA-Aufgabenverzeichnis, das die Pipeline als Einheit lädt. Für jeden Lauf "
          "erforderlich.",
    "ar": "‏video VAE (10.4 GB) و‏audio VAE والمعالج و‏tokenizer، مأخوذة من مجلد مهمة FL2VA "
          "الذي تحمّله المنظومة ككتلة واحدة. مطلوبة في كل تشغيل.",
    "ja": "動画 VAE（10.4 GB）、音声 VAE、プロセッサ、トークナイザで、パイプラインがひとまとまりで読み込む FL2VA のタスクディレクトリから取得します。すべての実行に必要です。",
    "ko": "비디오 VAE(10.4 GB), 오디오 VAE, 프로세서, 토크나이저로, 파이프라인이 한 덩어리로 불러오는 FL2VA 작업 디렉터리에서 가져옵니다. 모든 실행에 필요합니다.",
    "th": "VAE วิดีโอ (10.4 GB), VAE เสียง, ตัวประมวลผล และ tokenizer นำมาจากไดเรกทอรีงาน FL2VA ที่ไปป์ไลน์โหลดเป็นชุดเดียว จำเป็นต่อการรันทุกครั้ง",
    "yue-Hant": "video VAE(10.4 GB)、audio VAE、處理器同 tokenizer,由 pipeline 整包載入嘅 FL2VA 任務目錄度攞。每次算都要。",
    "en-SG": "Video VAE (10.4 GB), audio VAE, processor and tokenizer — bao ka liao, taken from the FL2VA task directory that the pipeline loads as one unit. Every run also need.",
})
add("model.textEncoder.mlx", {
    "en": "Qwen3-VL-32B in bfloat16 — H3 reads its 50th-layer hidden states. The largest "
          "single download, and currently the only text encoder the MLX pipeline can load. "
          "At about 34 GB resident it, not the transformer, decides whether this app runs "
          "on a given Mac: with the smallest transformer that is roughly 46 GB, so about 64 "
          "GB of unified memory is the practical floor. It installs beside the VAEs in "
          "FL2VA/.",
    "zh-Hant": "bfloat16 版的 Qwen3-VL-32B——H3 讀取其第 50 層的隱藏狀態。單一檔案中最大的下載項目，目前也是 MLX pipeline "
               "唯一能載入的文字編碼器。常駐約 34 GB，因此決定本 App 能否在某台 Mac 上執行的是它而非 transformer：搭配最小的 transformer "
               "約需 46 GB，實務上統一記憶體約 64 GB 是門檻。會與 VAE 一同安裝在 FL2VA/ 之下。",
    "zh-Hans": "bfloat16 版的 Qwen3-VL-32B——H3 读取其第 50 层的隐藏状态。单个文件中最大的下载项，目前也是 MLX pipeline "
               "唯一能加载的文本编码器。常驻约 34 GB，因此决定本 App 能否在某台 Mac 上运行的是它而非 transformer：搭配最小的 transformer "
               "约需 46 GB，实际上统一内存约 64 GB 是门槛。会与 VAE 一同安装在 FL2VA/ 之下。",
    "de": "Qwen3-VL-32B in bfloat16 – H3 liest dessen Hidden States aus Schicht 50. Der "
          "größte Einzeldownload und derzeit der einzige Text-Encoder, den die MLX-Pipeline "
          "laden kann. Mit rund 34 GB resident entscheidet er, nicht der Transformer, ob "
          "die App auf einem Mac läuft: mit dem kleinsten Transformer sind das etwa 46 GB, "
          "praktisch also rund 64 GB Unified Memory als Untergrenze. Wird neben den VAEs "
          "unter FL2VA/ installiert.",
    "ar": "‏Qwen3-VL-32B بدقة bfloat16 — يقرأ H3 الحالات المخفية من طبقته الخمسين. أكبر "
          "تنزيل مفرد، وهو حاليًا مشفّر النص الوحيد الذي تستطيع منظومة MLX تحميله. وبإشغاله "
          "نحو 34 غيغابايت، فهو — لا المحوّل — ما يحدّد إمكانية تشغيل التطبيق على جهاز "
          "بعينه: مع أصغر محوّل يبلغ المجموع نحو 46 غيغابايت، أي أن الحدّ العملي هو ذاكرة "
          "موحّدة بنحو 64 غيغابايت. يُثبَّت بجانب الـ VAE داخل ‎FL2VA/‎.",
    "ja": "bfloat16 の Qwen3-VL-32B。H3 はその第 50 層の隠れ状態を読みます。単体では最大のダウンロードで、現在 MLX パイプラインが読み込める唯一のテキストエンコーダです。常駐約 34 GB で、このアプリがその Mac で動くかどうかを決めるのはトランスフォーマーではなくこちらです。最小のトランスフォーマーと合わせて約 46 GB になるため、実質的な下限はユニファイドメモリ 64 GB ほどです。VAE と同じ FL2VA/ に入ります。",
    "ko": "bfloat16 Qwen3-VL-32B — H3는 이 모델의 50번째 층 은닉 상태를 읽습니다. 단일 항목으로 가장 큰 다운로드이며, 현재 MLX 파이프라인이 불러올 수 있는 유일한 텍스트 인코더입니다. 상주 약 34 GB로, 이 앱이 특정 Mac에서 돌아가는지를 정하는 것은 트랜스포머가 아니라 이것입니다. 가장 작은 트랜스포머와 합치면 약 46 GB이므로 통합 메모리 64 GB 정도가 현실적인 하한입니다. VAE와 나란히 FL2VA/ 에 설치됩니다.",
    "th": "Qwen3-VL-32B แบบ bfloat16 — H3 อ่านสถานะซ่อนของชั้นที่ 50 เป็นไฟล์ดาวน์โหลดเดี่ยวที่ใหญ่ที่สุด และตอนนี้เป็นตัวเข้ารหัสข้อความเพียงตัวเดียวที่ไปป์ไลน์ MLX โหลดได้ ด้วยหน่วยความจำราว 34 GB สิ่งที่ตัดสินว่าแอปนี้รันบน Mac เครื่องใดได้คือตัวนี้ ไม่ใช่ transformer เมื่อรวมกับ transformer ตัวเล็กที่สุดจะราว 46 GB ขีดล่างที่ใช้ได้จริงจึงอยู่ราวหน่วยความจำรวม 64 GB และติดตั้งไว้ข้าง VAE ใน FL2VA/",
    "yue-Hant": "bfloat16 版嘅 Qwen3-VL-32B——H3 讀佢第 50 層嘅隱藏狀態。單一檔案入面最大嘅下載,亦係而家 MLX pipeline 唯一載入到嘅文字編碼器。常駐大概 34 GB,所以決定呢個 App 喺部 Mac 跑唔跑到嘅係佢,唔係 transformer:配最細嗰個 transformer 大概 46 GB,所以實際門檻大概係 64 GB 統一記憶體。佢會同 VAE 一齊裝喺 FL2VA/ 入面。",
    "en-SG": "Qwen3-VL-32B in bfloat16 — H3 reads its 50th-layer hidden states. Biggest single download, and right now the only text encoder the MLX pipeline can load. About 34 GB resident, so this one — not the transformer — decides whether this app can run on your Mac: with the smallest transformer already about 46 GB, so 64 GB unified memory is the real floor. Anything less, buay tahan. It installs beside the VAEs inside FL2VA/.",
})
add("model.fl2va.q4", {
    "en": "4-bit, group size 64. The fastest of these and about 12 GB resident. Loses some "
          "fine texture. The best place to start — but the text encoder, not this, is what "
          "sets the memory floor.",
    "zh-Hant": "4-bit，group size 64。這些選項中最快，常駐約 12 GB。細節質感會有所損失。建議從這個開始——不過決定記憶體門檻的是文字編碼器，而不是它。",
    "zh-Hans": "4-bit，group size 64。这些选项中最快，常驻约 12 GB。细节质感会有所损失。建议从这个开始——不过决定内存门槛的是文本编码器，而不是它。",
    "de": "4 Bit, Gruppengröße 64. Die schnellste dieser Varianten und rund 12 GB resident. "
          "Verliert etwas Feintextur. Der beste Einstieg – die Speicheruntergrenze setzt "
          "allerdings der Text-Encoder, nicht diese Datei.",
    "ar": "‏4-bit بحجم مجموعة 64. الأسرع بينها ويشغل نحو 12 غيغابايت. يفقد بعض التفاصيل "
          "الدقيقة. أفضل نقطة للبدء — غير أن الحدّ الأدنى للذاكرة يفرضه مشفّر النص لا هذا "
          "الملف.",
    "ja": "4 ビット、グループサイズ 64。この中で最も速く、常駐は約 12 GB です。細かな質感は多少失われます。まずはこれから。ただしメモリの下限を決めるのはこれではなく、テキストエンコーダのほうです。",
    "ko": "4비트, 그룹 크기 64. 이 중 가장 빠르고 상주 약 12 GB입니다. 미세한 질감은 다소 잃습니다. 여기서 시작하는 것이 좋지만, 메모리 하한을 정하는 것은 이것이 아니라 텍스트 인코더입니다.",
    "th": "4 บิต กลุ่มขนาด 64 เร็วที่สุดในกลุ่มนี้ และกินหน่วยความจำราว 12 GB เสียรายละเอียดพื้นผิวไปบ้าง เป็นจุดเริ่มที่ดีที่สุด แต่สิ่งที่กำหนดขีดล่างของหน่วยความจำคือตัวเข้ารหัสข้อความ ไม่ใช่ตัวนี้",
    "yue-Hant": "4-bit，group size 64。呢幾個入面最快,常駐大概 12 GB。細緻質感會蝕啲。由呢個開始最好——不過定記憶體門檻嘅係文字編碼器,唔係佢。",
    "en-SG": "4-bit, group size 64. Fastest of the lot and about 12 GB resident. Fine texture sure lose some. Best one to start — but the text encoder, not this one, is what decides your memory floor.",
})
add("model.fl2va.q6", {
    "en": "6-bit. A middle point if 4-bit looks soft and 8-bit is too slow.",
    "zh-Hant": "6-bit。若覺得 4-bit 太鬆散、8-bit 又太慢，這是折衷選擇。",
    "zh-Hans": "6-bit。若觉得 4-bit 太软、8-bit 又太慢，这是折中选择。",
    "de": "6 Bit. Ein Mittelweg, wenn 4 Bit zu weich wirkt und 8 Bit zu langsam ist.",
    "ar": "‏6-bit. حل وسط إذا بدا 4-bit ناعمًا أكثر من اللازم وكان 8-bit بطيئًا.",
    "ja": "6 ビット。4 ビットが眠く見え、8 ビットが遅すぎるときの中間点です。",
    "ko": "6비트. 4비트가 흐릿해 보이고 8비트는 너무 느릴 때의 중간 지점입니다.",
    "th": "6 บิต เป็นทางสายกลางเมื่อ 4 บิตดูเบลอและ 8 บิตช้าเกินไป",
    "yue-Hant": "6-bit。如果 4-bit 太鬆、8-bit 又太慢,呢個係中間落墨。",
    "en-SG": "6-bit. The middle ground if 4-bit looks soft and 8-bit too slow.",
})
add("model.fl2va.q8", {
    "en": "The quality-per-gigabyte sweet spot — visually very close to bf16.",
    "zh-Hant": "每 GB 畫質的最佳平衡點——視覺上非常接近 bf16。",
    "zh-Hans": "每 GB 画质的最佳平衡点——视觉上非常接近 bf16。",
    "de": "Das beste Verhältnis von Qualität zu Gigabyte – optisch sehr nah an bf16.",
    "ar": "أفضل توازن بين الجودة وحجم التخزين — قريب بصريًا جدًا من bf16.",
    "ja": "容量あたりの品質が最も良く、見た目は bf16 にきわめて近いです。",
    "ko": "용량 대비 품질이 가장 좋고, 보기에는 bf16에 아주 가깝습니다.",
    "th": "จุดคุ้มค่าที่สุดระหว่างคุณภาพกับขนาด ดูแล้วใกล้เคียง bf16 มาก",
    "yue-Hant": "每 GB 質素最抵嗰點——睇落好接近 bf16。",
    "en-SG": "Best quality per gigabyte — looks very close to bf16.",
})
add("model.fl2va.bf16", {
    "en": "Reference precision, validated against the diffusers implementation. The slowest "
          "option, and about 41 GB resident on its own — with the text encoder loaded as "
          "well, plan on 128 GB of unified memory.",
    "zh-Hant": "參考精度，已對照 diffusers 實作驗證。速度最慢，單是本體常駐就約 41 GB——再加上文字編碼器，建議使用 128 GB 統一記憶體的機器。",
    "zh-Hans": "参考精度，已对照 diffusers 实现验证。速度最慢，单是本体常驻就约 41 GB——再加上文本编码器，建议使用 128 GB 统一内存的机器。",
    "de": "Referenzpräzision, gegen die diffusers-Implementierung validiert. Die langsamste "
          "Option und allein schon rund 41 GB resident – zusammen mit dem Text-Encoder "
          "sollten es 128 GB Unified Memory sein.",
    "ar": "دقة مرجعية، جرى التحقق منها مقابل تنفيذ diffusers. الخيار الأبطأ، ويشغل وحده نحو "
          "41 غيغابايت — ومع تحميل مشفّر النص أيضًا، يُنصح بذاكرة موحّدة سعتها 128 "
          "غيغابايت.",
    "ja": "基準となる精度で、diffusers の実装と突き合わせて検証されています。最も遅く、これだけで常駐 41 GB ほど。テキストエンコーダも載せるなら 128 GB のユニファイドメモリを見込んでください。",
    "ko": "기준 정밀도이며 diffusers 구현과 대조해 검증했습니다. 가장 느리고 이것만으로 상주 41 GB 정도입니다. 텍스트 인코더까지 올린다면 통합 메모리 128 GB를 잡으세요.",
    "th": "ความแม่นยำอ้างอิง ตรวจสอบเทียบกับการพัฒนาแบบ diffusers ช้าที่สุด และกินหน่วยความจำราว 41 GB เพียงตัวเดียว หากโหลดตัวเข้ารหัสข้อความด้วย ควรเผื่อหน่วยความจำรวม 128 GB",
    "yue-Hant": "參考精度,已經同 diffusers 實作對過。最慢,單係佢常駐就大概 41 GB——再加文字編碼器,就要諗住 128 GB 統一記憶體。",
    "en-SG": "Reference precision, checked against the diffusers implementation. Slowest one, and about 41 GB resident by itself — load the text encoder also, then you better got 128 GB unified memory, if not confirm jialat.",
})
add("model.ref2va.bf16", {
    "en": "Upstream bf16 Ref2VA checkpoint. Listed so the option is visible, but the MLX "
          "port's pipeline accepts keyframes only — it has no reference conditioning path — "
          "so this cannot be driven from this app yet.",
    "zh-Hant": "上游的 bf16 Ref2VA 檢查點。列出是為了讓選項可見，但 MLX 移植版的 pipeline 只接受關鍵影格——沒有參考條件的路徑——因此目前無法從本 "
               "App 驅動。",
    "zh-Hans": "上游的 bf16 Ref2VA 检查点。列出是为了让选项可见，但 MLX 移植版的 pipeline 只接受关键帧——没有参考条件的通路——因此目前无法从本 "
               "App 驱动。",
    "de": "Upstream-bf16-Checkpoint für Ref2VA. Nur aufgeführt, damit die Option sichtbar "
          "ist: Die Pipeline der MLX-Portierung akzeptiert ausschließlich Keyframes und "
          "kennt keinen Pfad für Referenzkonditionierung, lässt sich also aus dieser App "
          "noch nicht ansteuern.",
    "ar": "نقطة تحقّق Ref2VA الأصلية بدقة bf16. مُدرجة ليظهر الخيار فحسب، لكن منظومة نسخة "
          "MLX لا تقبل سوى الإطارات المفتاحية ولا تملك مسارًا للاشتراط المرجعي، لذا لا يمكن "
          "تشغيلها من هذا التطبيق بعد.",
    "ja": "上流の bf16 Ref2VA チェックポイントです。選択肢として見えるように載せていますが、MLX 移植版のパイプラインはキーフレームしか受け付けず参考素材の条件付け経路がないため、現時点ではこのアプリから動かせません。",
    "ko": "업스트림 bf16 Ref2VA 체크포인트입니다. 선택지가 보이도록 실어 두었지만, MLX 이식판 파이프라인은 키프레임만 받고 참조 조건화 경로가 없어 아직 이 앱에서는 구동할 수 없습니다.",
    "th": "Checkpoint Ref2VA แบบ bf16 จากต้นทาง แสดงไว้ให้เห็นเป็นตัวเลือก แต่ไปป์ไลน์ของพอร์ต MLX รับได้เฉพาะ keyframe และไม่มีเส้นทางกำหนดเงื่อนไขจากไฟล์อ้างอิง จึงยังสั่งงานจากแอปนี้ไม่ได้",
    "yue-Hant": "上游嘅 bf16 Ref2VA 檢查點。列出嚟係想個選項見得到,但 MLX 移植版個 pipeline 淨係收關鍵格——冇參考條件嘅路——所以暫時喺呢個 App 度驅動唔到。",
    "en-SG": "Upstream bf16 Ref2VA checkpoint. Put here so you can see got this option, but the MLX port's pipeline only takes keyframes — bo reference conditioning path — so cannot drive it from this app yet.",
})
add("model.ref2va.bf16.blocked", {
    "en": "The MLX port does not implement reference conditioning. Ref2VA currently needs "
          "the CUDA stack (SGLang, vLLM or ComfyUI).",
    "zh-Hant": "MLX 移植版尚未實作參考條件。Ref2VA 目前需要 CUDA 環境（SGLang、vLLM 或 ComfyUI）。",
    "zh-Hans": "MLX 移植版尚未实现参考条件。Ref2VA 目前需要 CUDA 环境（SGLang、vLLM 或 ComfyUI）。",
    "de": "Die MLX-Portierung implementiert keine Referenzkonditionierung. Ref2VA benötigt "
          "derzeit den CUDA-Stack (SGLang, vLLM oder ComfyUI).",
    "ar": "لا تنفّذ نسخة MLX الاشتراط المرجعي. يحتاج Ref2VA حاليًا إلى منظومة CUDA ‏(SGLang "
          "أو vLLM أو ComfyUI).",
    "ja": "MLX 移植版は参考素材の条件付けを実装していません。Ref2VA には現在 CUDA スタック（SGLang、vLLM、ComfyUI）が必要です。",
    "ko": "MLX 이식판은 참조 조건화를 구현하지 않았습니다. Ref2VA는 현재 CUDA 스택(SGLang, vLLM 또는 ComfyUI)이 필요합니다.",
    "th": "พอร์ต MLX ไม่ได้รองรับการกำหนดเงื่อนไขจากไฟล์อ้างอิง ขณะนี้ Ref2VA ต้องใช้ชุด CUDA (SGLang, vLLM หรือ ComfyUI)",
    "yue-Hant": "MLX 移植版未實作參考條件。Ref2VA 而家要 CUDA 嗰套(SGLang、vLLM 或者 ComfyUI)。",
    "en-SG": "The MLX port never implement reference conditioning. Ref2VA now still need the CUDA stack (SGLang, vLLM or ComfyUI).",
})
add("model.lora.fl2va.mlx", {
    "en": "A 4-step distillation LoRA for FL2VA at 768p — the single biggest speed win "
          "available for this model. The MLX port has no LoRA loader yet, so it is listed "
          "here to watch rather than to install.",
    "zh-Hant": "針對 768p FL2VA 的 4 步蒸餾 LoRA——本模型目前最大的一項加速。MLX 移植版尚無 LoRA 載入器，因此這裡只是列出供關注，還不能安裝。",
    "zh-Hans": "针对 768p FL2VA 的 4 步蒸馏 LoRA——本模型目前最大的一项加速。MLX 移植版尚无 LoRA 加载器，因此这里只是列出供关注，还不能安装。",
    "de": "Eine 4-Schritt-Destillations-LoRA für FL2VA bei 768p – der größte verfügbare "
          "Geschwindigkeitsgewinn für dieses Modell. Die MLX-Portierung hat noch keinen "
          "LoRA-Loader, daher steht sie hier zum Beobachten, nicht zum Installieren.",
    "ar": "نموذج LoRA مُقطَّر بأربع خطوات لـ FL2VA بدقة 768p — أكبر مكسب في السرعة متاح "
          "لهذا النموذج. لا تملك نسخة MLX محمِّل LoRA بعد، لذا يُدرج هنا للمتابعة لا "
          "للتثبيت.",
    "ja": "768p の FL2VA 向け 4 ステップ蒸留 LoRA で、このモデルで得られる最大の高速化です。MLX 移植版にはまだ LoRA ローダーがないため、導入用ではなく様子見として掲載しています。",
    "ko": "768p FL2VA용 4스텝 증류 LoRA로, 이 모델에서 얻을 수 있는 가장 큰 속도 향상입니다. MLX 이식판에는 아직 LoRA 로더가 없어 설치용이 아니라 지켜보기 위해 실어 둡니다.",
    "th": "LoRA กลั่นแบบ 4 step สำหรับ FL2VA ที่ 768p เป็นการเร่งความเร็วที่ได้ผลที่สุดของโมเดลนี้ พอร์ต MLX ยังไม่มีตัวโหลด LoRA จึงแสดงไว้ให้ติดตาม ไม่ใช่ให้ติดตั้ง",
    "yue-Hant": "768p FL2VA 嘅 4 步蒸餾 LoRA——呢個模型可以有嘅最大加速。MLX 移植版仲未有 LoRA 載入器,所以列喺度係俾你留意,唔係俾你裝。",
    "en-SG": "A 4-step distillation LoRA for FL2VA at 768p — biggest speed-up this model can get. But the MLX port still bo LoRA loader, so listed here for you to watch only, cannot install.",
})
add("model.lora.fl2va.mlx.blocked", {
    "en": "The MLX port has no LoRA loader yet. Fusing this would need a merged checkpoint "
          "rather than the LoRA on its own.",
    "zh-Hant": "MLX 移植版尚無 LoRA 載入器。要套用它得改用已合併的檢查點，而非單獨的 LoRA。",
    "zh-Hans": "MLX 移植版尚无 LoRA 加载器。要套用它得改用已合并的检查点，而非单独的 LoRA。",
    "de": "Die MLX-Portierung hat noch keinen LoRA-Loader. Zum Einbinden wäre ein "
          "zusammengeführter Checkpoint nötig, nicht die LoRA allein.",
    "ar": "لا تملك نسخة MLX محمِّل LoRA بعد. ودمجه يتطلب نقطة تحقّق مدموجة بدل ملف LoRA "
          "وحده.",
    "ja": "MLX 移植版にはまだ LoRA ローダーがありません。これを使うには LoRA 単体ではなく、統合済みのチェックポイントが必要です。",
    "ko": "MLX 이식판에는 아직 LoRA 로더가 없습니다. 이것을 쓰려면 LoRA 단독이 아니라 병합된 체크포인트가 필요합니다.",
    "th": "พอร์ต MLX ยังไม่มีตัวโหลด LoRA การหลอมรวมตัวนี้ต้องใช้ checkpoint ที่ผสานไว้แล้ว ไม่ใช่ LoRA เดี่ยว ๆ",
    "yue-Hant": "MLX 移植版仲未有 LoRA 載入器。要用就要一個已經合併嘅檢查點,唔可以淨係個 LoRA。",
    "en-SG": "The MLX port still bo LoRA loader. To fuse this you need a merged checkpoint, cannot use the LoRA by itself.",
})
add("model.comfy.ref2va", {
    "en": "Ref2VA transformer for ComfyUI. Required for reference mode, which the MLX port "
          "cannot do at all.",
    "zh-Hant": "ComfyUI 用的 Ref2VA transformer。參考素材模式必備，而 MLX 移植版完全無法處理該模式。",
    "zh-Hans": "ComfyUI 用的 Ref2VA transformer。参考素材模式必备，而 MLX 移植版完全无法处理该模式。",
    "de": "Ref2VA-Transformer für ComfyUI. Erforderlich für den Referenzmodus, den die "
          "MLX-Portierung überhaupt nicht beherrscht.",
    "ar": "محوّل Ref2VA الخاص بـ ComfyUI. لازم لوضع المراجع، وهو ما لا تستطيعه نسخة MLX "
          "إطلاقًا.",
    "ja": "ComfyUI 用の Ref2VA トランスフォーマー。参考素材モードに必須で、MLX 移植版では一切できません。",
    "ko": "ComfyUI용 Ref2VA 트랜스포머. 참조 모드에 필수이며, MLX 이식판으로는 아예 할 수 없습니다.",
    "th": "Transformer Ref2VA สำหรับ ComfyUI จำเป็นต่อโหมดไฟล์อ้างอิง ซึ่งพอร์ต MLX ทำไม่ได้เลย",
    "yue-Hant": "ComfyUI 用嘅 Ref2VA transformer。參考素材模式一定要,而 MLX 移植版根本做唔到。",
    "en-SG": "Ref2VA transformer for ComfyUI. Must have for reference mode, which the MLX port cannot do at all one.",
})
add("model.comfy.fl2va", {
    "en": "FL2VA transformer for ComfyUI. Only needed if you want to run text-to-video or "
          "keyframes through ComfyUI instead of MLX.",
    "zh-Hant": "ComfyUI 用的 FL2VA transformer。只有當你想改用 ComfyUI（而非 MLX）執行文字轉影片或關鍵影格時才需要。",
    "zh-Hans": "ComfyUI 用的 FL2VA transformer。只有当你想改用 ComfyUI（而非 MLX）执行文字转视频或关键帧时才需要。",
    "de": "FL2VA-Transformer für ComfyUI. Nur nötig, wenn Sie Text-zu-Video oder Keyframes "
          "über ComfyUI statt über MLX laufen lassen wollen.",
    "ar": "محوّل FL2VA الخاص بـ ComfyUI. لا يلزم إلا إذا أردت تشغيل التحويل من نص إلى فيديو "
          "أو الإطارات المفتاحية عبر ComfyUI بدل MLX.",
    "ja": "ComfyUI 用の FL2VA トランスフォーマー。MLX ではなく ComfyUI でテキストからの生成やキーフレームを回す場合にだけ必要です。",
    "ko": "ComfyUI용 FL2VA 트랜스포머. MLX 대신 ComfyUI로 텍스트-비디오나 키프레임을 돌릴 때만 필요합니다.",
    "th": "Transformer FL2VA สำหรับ ComfyUI จำเป็นเฉพาะเมื่อต้องการรันข้อความเป็นวิดีโอหรือ keyframe ผ่าน ComfyUI แทน MLX",
    "yue-Hant": "ComfyUI 用嘅 FL2VA transformer。淨係當你想用 ComfyUI(而唔係 MLX)跑文字轉片或者關鍵格先要。",
    "en-SG": "FL2VA transformer for ComfyUI. Only need it if you want to run text-to-video or keyframes through ComfyUI instead of MLX. If not, skip lah.",
})
add("model.comfy.textEncoder", {
    "en": "Qwen3-VL-32B for ComfyUI. Shared by both tasks — download once.",
    "zh-Hant": "ComfyUI 用的 Qwen3-VL-32B。兩種任務共用——下載一次即可。",
    "zh-Hans": "ComfyUI 用的 Qwen3-VL-32B。两种任务共用——下载一次即可。",
    "de": "Qwen3-VL-32B für ComfyUI. Von beiden Aufgaben genutzt – einmal laden.",
    "ar": "‏Qwen3-VL-32B الخاص بـ ComfyUI. تشترك فيه المهمتان — نزّله مرة واحدة.",
    "ja": "ComfyUI 用の Qwen3-VL-32B。両方のタスクで共有するので、一度だけダウンロードすれば十分です。",
    "ko": "ComfyUI용 Qwen3-VL-32B. 두 작업이 공유하므로 한 번만 내려받으면 됩니다.",
    "th": "Qwen3-VL-32B สำหรับ ComfyUI ใช้ร่วมกันทั้งสองงาน ดาวน์โหลดครั้งเดียวพอ",
    "yue-Hant": "ComfyUI 用嘅 Qwen3-VL-32B。兩種任務共用——下載一次就得。",
    "en-SG": "Qwen3-VL-32B for ComfyUI. Both tasks share it — download once can already, no need twice.",
})
add("model.comfy.videoVAE", {
    "en": "Video VAE in fp16. Chosen over the INT8 build: it is small, and decode quality "
          "is visible.",
    "zh-Hant": "fp16 的 video VAE。相較 INT8 版更建議這個：體積小，而且解碼品質看得出差別。",
    "zh-Hans": "fp16 的 video VAE。相较 INT8 版更建议这个：体积小，而且解码质量看得出差别。",
    "de": "Video-VAE in fp16. Dem INT8-Build vorgezogen: klein, und die Decodier-Qualität "
          "ist sichtbar.",
    "ar": "‏video VAE بدقة fp16. فُضّل على نسخة INT8: حجمه صغير وجودة فك الترميز ملحوظة.",
    "ja": "fp16 の動画 VAE。INT8 版ではなくこちらを選んでいます。小さいうえに、デコード品質の差が見えるからです。",
    "ko": "fp16 비디오 VAE. INT8 빌드 대신 이것을 택했습니다. 작기도 하고, 디코딩 품질 차이가 눈에 보이기 때문입니다.",
    "th": "VAE วิดีโอแบบ fp16 เลือกตัวนี้แทนรุ่น INT8 เพราะขนาดเล็กและคุณภาพการถอดรหัสเห็นความต่างได้",
    "yue-Hant": "fp16 嘅 video VAE。揀佢唔揀 INT8 版:細,而且解碼質素分得出。",
    "en-SG": "Video VAE in fp16. Choose this over the INT8 one: small, and the decode quality you can really see.",
})
add("model.comfy.audioVAE", {
    "en": "Audio VAE in fp32, for the stereo track H3 generates alongside the picture.",
    "zh-Hant": "fp32 的 audio VAE，用於 H3 在畫面之外同時生成的立體聲軌。",
    "zh-Hans": "fp32 的 audio VAE，用于 H3 在画面之外同时生成的立体声轨。",
    "de": "Audio-VAE in fp32, für die Stereospur, die H3 zusätzlich zum Bild erzeugt.",
    "ar": "‏audio VAE بدقة fp32، للمسار الصوتي المجسَّم الذي يولّده H3 إلى جانب الصورة.",
    "ja": "fp32 の音声 VAE。H3 が映像と一緒に生成するステレオトラック用です。",
    "ko": "fp32 오디오 VAE. H3가 영상과 함께 만드는 스테레오 트랙에 씁니다.",
    "th": "VAE เสียงแบบ fp32 สำหรับแทร็ก stereo ที่ H3 สร้างพร้อมกับภาพ",
    "yue-Hant": "fp32 嘅 audio VAE,用喺 H3 同畫面一齊生成嘅立體聲軌。",
    "en-SG": "Audio VAE in fp32, for the stereo track H3 makes together with the picture. Small one, no need worry.",
})
add("model.comfy.lora.ref2va", {
    "en": "4-step Ref2VA turbo LoRA. This is what makes reference renders practical at all "
          "— four steps instead of fifty, so tens of minutes rather than many hours.",
    "zh-Hant": "4 步的 Ref2VA turbo LoRA。正是它讓參考素材算圖變得可行——四步而非五十步，時間從數小時降到數十分鐘。",
    "zh-Hans": "4 步的 Ref2VA turbo LoRA。正是它让参考素材渲染变得可行——四步而非五十步，时间从数小时降到数十分钟。",
    "de": "4-Schritt-Turbo-LoRA für Ref2VA. Sie macht Referenz-Renderings überhaupt erst "
          "praktikabel – vier Schritte statt fünfzig, also Dutzende Minuten statt vieler "
          "Stunden.",
    "ar": "نموذج LoRA السريع لـ Ref2VA بأربع خطوات. هو ما يجعل التصيير المرجعي عمليًا أصلًا "
          "— أربع خطوات بدل خمسين، أي عشرات الدقائق بدل ساعات طويلة.",
    "ja": "4 ステップの Ref2VA turbo LoRA。参考素材を使うレンダリングを現実的にしているのはこれです。50 ステップが 4 ステップになるので、何時間もかかっていたものが数十分で済みます。",
    "ko": "4스텝 Ref2VA turbo LoRA. 참조 렌더링을 현실적으로 만들어 주는 것이 바로 이것입니다. 50스텝이 4스텝이 되므로 몇 시간이 수십 분으로 줄어듭니다.",
    "th": "Turbo LoRA ของ Ref2VA แบบ 4 step ตัวนี้คือสิ่งที่ทำให้การเรนเดอร์ด้วยไฟล์อ้างอิงเป็นไปได้จริง จากห้าสิบ step เหลือสี่ จากหลายชั่วโมงเหลือหลายสิบนาที",
    "yue-Hant": "4 步嘅 Ref2VA turbo LoRA。正正係佢令到參考素材算圖變得做得過——四步而唔係五十步,由幾個鐘變幾十分鐘。",
    "en-SG": "4-step Ref2VA turbo LoRA. This one is the real lobang — four steps instead of fifty, so tens of minutes instead of many hours. Without it, reference renders sibeh jialat.",
})
add("model.comfy.lora.fl2va", {
    "en": "4-step FL2VA turbo LoRA. Distilled for four steps, where MLX's undistilled "
          "weights want sixteen.",
    "zh-Hant": "4 步的 FL2VA turbo LoRA。專為四步蒸餾，而 MLX 未蒸餾的權重需要十六步。",
    "zh-Hans": "4 步的 FL2VA turbo LoRA。专为四步蒸馏，而 MLX 未蒸馏的权重需要十六步。",
    "de": "4-Schritt-Turbo-LoRA für FL2VA. Auf vier Schritte destilliert, während die "
          "undestillierten MLX-Gewichte sechzehn brauchen.",
    "ar": "نموذج LoRA السريع لـ FL2VA بأربع خطوات. مُقطَّر لأربع خطوات، بينما تحتاج أوزان "
          "MLX غير المقطَّرة إلى ستّ عشرة.",
    "ja": "4 ステップの FL2VA turbo LoRA。4 ステップ用に蒸留されており、MLX の未蒸留の重みは 16 ステップを要します。",
    "ko": "4스텝 FL2VA turbo LoRA. 4스텝에 맞춰 증류되었으며, MLX의 비증류 가중치는 16스텝이 필요합니다.",
    "th": "Turbo LoRA ของ FL2VA แบบ 4 step กลั่นมาเพื่อสี่ step ขณะที่น้ำหนักที่ยังไม่กลั่นของ MLX ต้องใช้สิบหก step",
    "yue-Hant": "4 步嘅 FL2VA turbo LoRA。專登為四步蒸餾,而 MLX 未蒸餾嘅權重要十六步。",
    "en-SG": "4-step FL2VA turbo LoRA. Distilled for four steps, while MLX's undistilled weights want sixteen. Big difference.",
})
add("model.textEncoder.uncensored", {
    "en": "Qwen3-VL-32B with its refusal behaviour trained out. Drop-in replacement for the "
          "stock encoder — H3 itself is unchanged, since refusals live in the language "
          "model, not the diffusion transformer. ComfyUI only; MLX has no loader for this "
          "format.",
    "zh-Hant": "已移除拒絕行為的 Qwen3-VL-32B。可直接替換原本的編碼器——H3 本身沒有改動，因為拒絕行為存在於語言模型，而非 diffusion "
               "transformer。僅支援 ComfyUI；MLX 無法載入此格式。",
    "zh-Hans": "已移除拒绝行为的 Qwen3-VL-32B。可直接替换原本的编码器——H3 本身没有改动，因为拒绝行为存在于语言模型，而非 diffusion "
               "transformer。仅支持 ComfyUI；MLX 无法加载此格式。",
    "de": "Qwen3-VL-32B, dem das Verweigerungsverhalten abtrainiert wurde. Direkter Ersatz "
          "für den Standard-Encoder – H3 selbst bleibt unverändert, da Verweigerungen im "
          "Sprachmodell sitzen, nicht im Diffusion-Transformer. Nur ComfyUI; MLX hat keinen "
          "Loader für dieses Format.",
    "ar": "‏Qwen3-VL-32B بعد تدريبه على التخلّي عن سلوك الرفض. بديل مباشر للمشفّر القياسي — "
          "ويبقى H3 نفسه دون تغيير، لأن الرفض يقيم في نموذج اللغة لا في محوّل الانتشار. "
          "يعمل مع ComfyUI فقط؛ ولا يملك MLX محمِّلًا لهذه الصيغة.",
    "ja": "拒否の振る舞いを学習から取り除いた Qwen3-VL-32B です。標準のエンコーダとそのまま差し替えられます。拒否は言語モデル側にあり拡散トランスフォーマーにはないため、H3 自体は変わりません。ComfyUI 専用で、MLX にはこの形式のローダーがありません。",
    "ko": "거부 동작을 학습에서 제거한 Qwen3-VL-32B입니다. 기본 인코더와 그대로 바꿔 쓸 수 있습니다. 거부는 언어 모델 쪽에 있고 디퓨전 트랜스포머에는 없으므로 H3 자체는 달라지지 않습니다. ComfyUI 전용이며 MLX에는 이 형식의 로더가 없습니다.",
    "th": "Qwen3-VL-32B ที่ฝึกให้ไม่มีพฤติกรรมปฏิเสธ ใช้แทนตัวเข้ารหัสมาตรฐานได้ทันที ตัว H3 เองไม่เปลี่ยน เพราะการปฏิเสธอยู่ในโมเดลภาษา ไม่ใช่ใน diffusion transformer ใช้ได้กับ ComfyUI เท่านั้น เพราะ MLX ไม่มีตัวโหลดสำหรับรูปแบบนี้",
    "yue-Hant": "拒絕行為訓練走咗嘅 Qwen3-VL-32B。可以直接換走原本嗰個——H3 本身冇變,因為拒絕行為喺語言模型度,唔喺 diffusion transformer。淨係 ComfyUI 用得;MLX 冇呢個格式嘅載入器。",
    "en-SG": "Qwen3-VL-32B with the refusal behaviour trained away. Can swap in directly for the stock encoder — H3 itself never change, because the refusals sit inside the language model, not the diffusion transformer. ComfyUI only; MLX bo loader for this format.",
})
add("model.fl2va.gguf", {
    "en": "GGUF quantizations, including very small ones. Loaded by ComfyUI, not by MLX — "
          "useful if you ever run this model through ComfyUI instead.",
    "zh-Hant": "GGUF 量化版本，包含非常小的檔案。由 ComfyUI 載入，MLX 不支援——若你改以 ComfyUI 執行本模型就用得上。",
    "zh-Hans": "GGUF 量化版本，包含非常小的文件。由 ComfyUI 加载，MLX 不支持——若你改用 ComfyUI 运行本模型就用得上。",
    "de": "GGUF-Quantisierungen, auch sehr kleine. Wird von ComfyUI geladen, nicht von MLX "
          "– nützlich, falls Sie das Modell stattdessen über ComfyUI laufen lassen.",
    "ar": "تكميمات بصيغة GGUF، منها نسخ صغيرة جدًا. يحمّلها ComfyUI لا MLX — مفيدة إن شغّلت "
          "هذا النموذج عبر ComfyUI بدلًا من ذلك.",
    "ja": "非常に小さいものを含む GGUF 量子化です。MLX ではなく ComfyUI が読み込みます。このモデルを ComfyUI 側で回す場合に役立ちます。",
    "ko": "아주 작은 것까지 포함한 GGUF 양자화입니다. MLX가 아니라 ComfyUI가 불러옵니다. 이 모델을 ComfyUI로 돌릴 때 쓸모가 있습니다.",
    "th": "Quantization แบบ GGUF รวมถึงรุ่นที่เล็กมาก โหลดด้วย ComfyUI ไม่ใช่ MLX มีประโยชน์หากคุณรันโมเดลนี้ผ่าน ComfyUI แทน",
    "yue-Hant": "GGUF 量化版,包括好細嘅。由 ComfyUI 載入,MLX 唔支援——你改用 ComfyUI 跑呢個模型嗰陣先用得著。",
    "en-SG": "GGUF quantizations, some of them sibeh small. ComfyUI load one, not MLX — only useful if you run this model through ComfyUI instead.",
})
add("model.fl2va.nvfp4", {
    "en": "Community prune in NVIDIA's NVFP4 format. Listed for completeness.",
    "zh-Hant": "社群釋出的修剪版，採用 NVIDIA 的 NVFP4 格式。列出以求完整。",
    "zh-Hans": "社区发布的剪枝版，采用 NVIDIA 的 NVFP4 格式。列出以求完整。",
    "de": "Community-Prune im NVFP4-Format von NVIDIA. Der Vollständigkeit halber "
          "aufgeführt.",
    "ar": "نسخة مُقلَّمة من المجتمع بصيغة NVFP4 من NVIDIA. مُدرجة لاكتمال القائمة.",
    "ja": "NVIDIA の NVFP4 形式によるコミュニティ版の枝刈りです。網羅のために掲載しています。",
    "ko": "NVIDIA의 NVFP4 형식으로 만든 커뮤니티 프루닝입니다. 빠짐없이 보여 주기 위해 실어 둡니다.",
    "th": "เวอร์ชันตัดแต่งโดยชุมชนในรูปแบบ NVFP4 ของ NVIDIA แสดงไว้เพื่อความครบถ้วน",
    "yue-Hant": "社群用 NVIDIA NVFP4 格式做嘅修剪版。列出嚟求個齊。",
    "en-SG": "Community prune in NVIDIA's NVFP4 format. Put here for completeness only, here cannot use one.",
})

# ── Formatting fragments ─────────────────────────────────────────────────────
add("format.clipLength", {
    "en": "%@ s",
    "zh-Hant": "%@ 秒",
    "zh-Hans": "%@ 秒",
    "de": "%@ s",
    "ar": "%@ ث",
    "ja": "%@ 秒",
    "ko": "%@ 초",
    "th": "%@ วินาที",
    "yue-Hant": "%@ 秒",
    "en-SG": "%@ s",
})
add("format.frames", {
    "en": "%@ frames",
    "zh-Hant": "%@ 影格",
    "zh-Hans": "%@ 帧",
    "de": "%@ Bilder",
    "ar": "%@ إطارًا",
    "ja": "%@ フレーム",
    "ko": "%@ 프레임",
    "th": "%@ เฟรม",
    "yue-Hant": "%@ 格",
    "en-SG": "%@ frames",
}, note={
    "content": "Takes a count. English offers only two forms and this string supplies one, so \"1 "
               "frames\" is already wrong; Arabic needs six categories and settles for a single "
               "compromise form. Any language with Slavic-style plurals will need a .stringsdict "
               "before this can be translated correctly. Counts start at 5 here because frames "
               "follow the VAE's 17n+5 grid, which is why nobody has hit the singular case.",
    "level": WARNING,
})
add("format.steps", {
    "en": "%@ steps",
    "zh-Hant": "%@ 步",
    "zh-Hans": "%@ 步",
    "de": "%@ Schritte",
    "ar": "%@ خطوة",
    "ja": "%@ ステップ",
    "ko": "%@ 스텝",
    "th": "%@ step",
    "yue-Hant": "%@ 步",
    "en-SG": "%@ steps",
}, note={
    "content": "Takes a count. English offers only two forms and this string supplies one, so \"1 "
               "steps\" is already wrong; Arabic needs six categories and settles for a single "
               "compromise form. Any language with Slavic-style plurals will need a .stringsdict "
               "before this can be translated correctly. GenerationSpec.stepsRange is 4...60, so "
               "the singular is unreachable today — but that range is a UI choice, not a "
               "property of the sampler.",
    "level": WARNING,
})
add("format.framesAndLength", {
    "en": "%1$@ frames · %2$@ s",
    "zh-Hant": "%1$@ 影格 · %2$@ 秒",
    "zh-Hans": "%1$@ 帧 · %2$@ 秒",
    "de": "%1$@ Bilder · %2$@ s",
    "ar": "%1$@ إطارًا · %2$@ ث",
    "ja": "%1$@ フレーム・%2$@ 秒",
    "ko": "%1$@ 프레임 · %2$@ 초",
    "th": "%1$@ เฟรม · %2$@ วินาที",
    "yue-Hant": "%1$@ 格 · %2$@ 秒",
    "en-SG": "%1$@ frames · %2$@ s",
})
add("sampling.steps.note", {
    "en": "Steps are actual denoising passes, and dominate render time almost linearly. "
          "%1$@ Duration snaps to the video VAE's 17n+5 frame grid, so the value shown is "
          "what renders.",
    "zh-Hant": "步數就是實際的去噪次數，幾乎線性決定算圖時間。%1$@時長會對齊 video VAE 的 17n+5 影格格線，因此顯示的數值就是實際會算出的長度。",
    "zh-Hans": "步数就是实际的去噪次数，几乎线性决定渲染时间。%1$@时长会对齐 video VAE 的 17n+5 帧栅格，因此显示的数值就是实际会渲染出的长度。",
    "de": "Schritte sind echte Entrausch-Durchgänge und bestimmen die Renderzeit nahezu "
          "linear. %1$@ Die Dauer rastet auf das 17n+5-Bildraster des Video-VAE ein, der "
          "angezeigte Wert ist also der, der gerendert wird.",
    "ar": "الخطوات هي مرات إزالة التشويش الفعلية، وتحدّد زمن التصيير تحديدًا خطّيًا "
          "تقريبًا. %1$@ وتنحاز المدة إلى شبكة إطارات video VAE ‏(17n+5)، لذا فالقيمة "
          "المعروضة هي ما سيُصيَّر فعلًا.",
    "ja": "ステップはノイズ除去の実回数で、レンダリング時間をほぼ線形に左右します。%1$@ 長さは動画 VAE の 17n+5 のフレーム格子に丸められるので、表示される値がそのままレンダリングされます。",
    "ko": "스텝은 실제 디노이징 횟수이며 렌더링 시간을 거의 선형으로 좌우합니다. %1$@ 길이는 비디오 VAE의 17n+5 프레임 격자에 맞춰지므로, 표시된 값이 그대로 렌더링됩니다.",
    "th": "Step คือรอบการลด noise จริง และกำหนดเวลาเรนเดอร์เกือบเป็นเส้นตรง %1$@ ความยาวจะถูกปัดเข้าตาราง 17n+5 เฟรมของ VAE วิดีโอ ค่าที่เห็นจึงคือค่าที่เรนเดอร์จริง",
    "yue-Hant": "步數就係實際去噪嘅次數，幾乎線性咁決定算幾耐。%1$@時長會對齊 video VAE 嘅 17n+5 格線，所以顯示嘅數值就係真係會算出嚟嗰個。",
    "en-SG": "Steps are the actual denoising passes, and they decide render time almost linearly. %1$@ Duration will snap to the video VAE's 17n+5 frame grid, so the number you see is what you get.",
})
add("sampling.steps.note.turbo", {
    "en": "This engine loads a %1$@-step turbo LoRA, distilled for exactly that many — more "
          "steps mostly cost time.",
    "zh-Hant": "此引擎會載入 %1$@ 步的 turbo LoRA，正是針對這個步數蒸餾的——再加步數多半只是多花時間。",
    "zh-Hans": "此引擎会加载 %1$@ 步的 turbo LoRA，正是针对这个步数蒸馏的——再加步数多半只是多花时间。",
    "de": "Diese Engine lädt eine Turbo-LoRA für %1$@ Schritte, genau darauf destilliert – "
          "mehr Schritte kosten meist nur Zeit.",
    "ar": "يحمّل هذا المحرّك نموذج LoRA سريعًا بـ %1$@ خطوات، مُقطَّرًا لهذا العدد تحديدًا "
          "— والمزيد من الخطوات يكلّف وقتًا في الغالب.",
    "ja": "このエンジンは %1$@ ステップ用の turbo LoRA を読み込みます。ちょうどその回数で蒸留されているため、増やしても主に時間が増えるだけです。",
    "ko": "이 엔진은 %1$@ 스텝용 turbo LoRA를 불러옵니다. 딱 그 횟수에 맞춰 증류되었기 때문에 스텝을 늘려도 대체로 시간만 늘어납니다.",
    "th": "Engine นี้โหลด turbo LoRA สำหรับ %1$@ step ซึ่งกลั่นมาเพื่อจำนวนนั้นพอดี เพิ่ม step จึงเปลืองเวลาเป็นหลัก",
    "yue-Hant": "呢個引擎會載入 %1$@ 步嘅 turbo LoRA，正正係為咗咁多步而蒸餾——加多啲步大多數只係多花時間。",
    "en-SG": "This engine loads a %1$@-step turbo LoRA, distilled for exactly that many — add more steps also mostly waste time only.",
})
add("sampling.steps.note.undistilled", {
    "en": "These weights are undistilled, so around %1$@ steps is the working range; far "
          "fewer is off-distribution and looks soft.",
    "zh-Hant": "這些權重未經蒸餾，因此約 %1$@ 步是合用的範圍；步數遠低於此會偏離訓練分佈，畫面會顯得鬆散。",
    "zh-Hans": "这些权重未经蒸馏，因此约 %1$@ 步是合用的范围；步数远低于此会偏离训练分布，画面会显得发软。",
    "de": "Diese Gewichte sind undestilliert, brauchbar ist daher der Bereich um %1$@ "
          "Schritte; deutlich weniger liegt außerhalb der Verteilung und wirkt weich.",
    "ar": "هذه الأوزان غير مقطَّرة، لذا فالمجال العملي نحو %1$@ خطوة؛ وما دون ذلك بكثير "
          "يخرج عن التوزيع ويبدو ناعمًا.",
    "ja": "この重みは未蒸留なので、実用域は %1$@ ステップ前後です。大幅に減らすと分布から外れ、眠い絵になります。",
    "ko": "이 가중치는 비증류라 %1$@ 스텝 안팎이 실용 범위입니다. 그보다 훨씬 적으면 분포를 벗어나 흐릿해 보입니다.",
    "th": "น้ำหนักชุดนี้ยังไม่ผ่านการกลั่น ช่วงที่ใช้ได้จริงจึงราว %1$@ step ถ้าน้อยกว่านี้มากจะหลุดการกระจายและดูเบลอ",
    "yue-Hant": "呢啲權重未蒸餾，所以大概 %1$@ 步先係合用嘅範圍；少好多就會偏離分佈，畫面會鬆。",
    "en-SG": "These weights never distil, so around %1$@ steps is the working range. Much fewer, it goes off-distribution and comes out blur.",
})

# ── Models: why a format will not load ───────────────────────────────────────
add("quantization.unloadable.nvfp4", {
    "en": "NVFP4 is an NVIDIA Blackwell format. There is no Metal path.",
    "zh-Hant": "NVFP4 是 NVIDIA Blackwell 的格式，沒有對應的 Metal 執行路徑。",
    "zh-Hans": "NVFP4 是 NVIDIA Blackwell 的格式，没有对应的 Metal 执行路径。",
    "de": "NVFP4 ist ein NVIDIA-Blackwell-Format. Einen Metal-Pfad dafür gibt es nicht.",
    "ar": "‏NVFP4 صيغة خاصة ببنية NVIDIA Blackwell. ولا يوجد مسار عبر Metal لتشغيلها.",
    "ja": "NVFP4 は NVIDIA Blackwell 向けの形式です。Metal で動かす手段はありません。",
    "ko": "NVFP4는 NVIDIA Blackwell 형식입니다. Metal 경로가 없습니다.",
    "th": "NVFP4 เป็นรูปแบบของ NVIDIA Blackwell จึงไม่มีทางรันบน Metal",
    "yue-Hant": "NVFP4 係 NVIDIA Blackwell 嘅格式，冇 Metal 行得通嘅路。",
    "en-SG": "NVFP4 is NVIDIA Blackwell format. No Metal path one.",
})
add("quantization.unloadable.gguf", {
    "en": "GGUF needs a ComfyUI custom node this app does not install.",
    "zh-Hant": "GGUF 需要一個本 App 不會安裝的 ComfyUI 自訂節點。",
    "zh-Hans": "GGUF 需要一个本 App 不会安装的 ComfyUI 自定义节点。",
    "de": "GGUF benötigt eine ComfyUI-Erweiterung, die diese App nicht installiert.",
    "ar": "يحتاج GGUF إلى عقدة مخصّصة في ComfyUI لا يثبّتها هذا التطبيق.",
    "ja": "GGUF にはこのアプリが導入しない ComfyUI のカスタムノードが必要です。",
    "ko": "GGUF에는 이 앱이 설치하지 않는 ComfyUI 커스텀 노드가 필요합니다.",
    "th": "GGUF ต้องใช้คัสตอมโหนดของ ComfyUI ที่แอปนี้ไม่ได้ติดตั้ง",
    "yue-Hant": "GGUF 要一個呢個 App 唔會裝嘅 ComfyUI 自訂節點。",
    "en-SG": "GGUF need one ComfyUI custom node, but this app don't install it.",
})
add("quantization.unloadable.other", {
    "en": "No engine here can load %@.",
    "zh-Hant": "此處的任何引擎都無法載入 %@。",
    "zh-Hans": "此处的任何引擎都无法加载 %@。",
    "de": "Keine Engine hier kann %@ laden.",
    "ar": "لا يستطيع أي محرّك هنا تحميل %@.",
    "ja": "ここにあるどのエンジンも %@ を読み込めません。",
    "ko": "여기 있는 어떤 엔진도 %@ 을(를) 불러올 수 없습니다.",
    "th": "ไม่มี engine ใดที่นี่โหลด %@ ได้",
    "yue-Hant": "呢度冇一個引擎載入到 %@。",
    "en-SG": "No engine here can load %@.",
}, note={
    "content": "Injects a name into a sentence. Languages that inflect a noun for case, choose "
               "an article by gender, or attach a vowel-harmonising suffix cannot do it without "
               "knowing the word, and it is only known at runtime. Prefer wording that sets the "
               "name apart — quoted, or on its own line.",
    "level": WARNING,
})

# ── Models: how an entry names itself, and two stragglers ────────────────────
add("problem.tooManyOfKind", {
    "en": "At most %1$@ reference %2$@ files — you have %3$@.",
    "zh-Hant": "參考%2$@檔案最多 %1$@ 個——目前有 %3$@ 個。",
    "zh-Hans": "参考%2$@文件最多 %1$@ 个——目前有 %3$@ 个。",
    "de": "Höchstens %1$@ Referenzdateien vom Typ %2$@ – Sie haben %3$@.",
    "ar": "بحد أقصى %1$@ من ملفات %2$@ المرجعية — لديك %3$@.",
    "ja": "参考 %2$@ ファイルは最大 %1$@ 件ですが、%3$@ 件あります。",
    "ko": "참조 %2$@ 파일은 최대 %1$@ 개인데 %3$@ 개가 있습니다.",
    "th": "ไฟล์ %2$@ อ้างอิงได้มากสุด %1$@ ไฟล์ แต่คุณมี %3$@",
    "yue-Hant": "參考%2$@檔案最多 %1$@ 個——你而家有 %3$@ 個。",
    "en-SG": "Most %1$@ reference %2$@ files only — you got %3$@.",
}, note={
    "content": "Injects a count, then a *noun* naming the file kind, then a second count. The "
               "noun has to agree with the numeral in most inflecting languages, and it arrives "
               "lowercased by the call site, which is an assumption German does not share. The "
               "counts themselves never reach 1 — the per-kind limits are 9, 3 and 3 — so only "
               "the noun is a live problem.",
    "level": WARNING,
})
add("queue.untitled", {
    "en": "Untitled render",
    "zh-Hant": "未命名算圖",
    "zh-Hans": "未命名渲染",
    "de": "Unbenannter Render",
    "ar": "تصيير بلا عنوان",
    "ja": "無題のレンダリング",
    "ko": "제목 없는 렌더링",
    "th": "การเรนเดอร์ไม่มีชื่อ",
    "yue-Hant": "未改名嘅算圖",
    "en-SG": "No name render",
})
add("models.chooseFolder.message", {
    "en": "Choose the folder where model weights are shared between projects",
    "zh-Hant": "選擇各專案共用模型權重的資料夾",
    "zh-Hans": "选择各项目共用模型权重的文件夹",
    "de": "Wählen Sie den Ordner, in dem Modellgewichte projektübergreifend geteilt werden",
    "ar": "اختر المجلد الذي تُشارَك فيه أوزان النماذج بين المشاريع",
    "ja": "プロジェクト間でモデルの重みを共有するフォルダを選んでください",
    "ko": "프로젝트 사이에서 모델 가중치를 공유할 폴더를 고르세요",
    "th": "เลือกโฟลเดอร์ที่จะใช้เก็บไฟล์น้ำหนักโมเดลร่วมกันระหว่างโปรเจกต์",
    "yue-Hant": "揀個各專案共用模型權重嘅資料夾",
    "en-SG": "Choose the folder where projects share model weights",
})

# ── Fitting the estimate and the weights to this Mac ─────────────────────────
add("summary.eta.footnote.predicted", {
    "en": "An estimate for %@, scaled from a published figure for a different Mac. It will "
          "be replaced by a measurement after your first render.",
    "zh-Hant": "針對 %@ 的推估值，由另一款 Mac 的公開數據換算而來。完成第一次算圖後，會改用實測值。",
    "zh-Hans": "针对 %@ 的推算值，由另一款 Mac 的公开数据换算而来。完成第一次渲染后，会改用实测值。",
    "de": "Eine Schätzung für %@, hochgerechnet aus einem veröffentlichten Wert für einen "
          "anderen Mac. Nach Ihrem ersten Render wird sie durch eine Messung ersetzt.",
    "ar": "تقدير لجهاز %@، محسوب من رقم منشور لجهاز Mac مختلف. وسيحلّ محلّه قياس فعلي بعد "
          "أول تصيير تجريه.",
    "ja": "%@ 向けの推定値で、別の Mac の公表値から換算しています。最初のレンダリングが終わると実測値に置き換わります。",
    "ko": "%@ 에 대한 추정값으로, 다른 Mac의 공개 수치를 환산한 것입니다. 첫 렌더링이 끝나면 실측값으로 바뀝니다.",
    "th": "เป็นค่าประมาณสำหรับ %@ ที่ปรับมาจากตัวเลขที่เผยแพร่ของ Mac รุ่นอื่น จะถูกแทนด้วยค่าที่วัดได้จริงหลังการเรนเดอร์ครั้งแรก",
    "yue-Hant": "針對 %@ 嘅推算，由另一部 Mac 嘅公開數字換算。算完第一次之後，會改用實測值。",
    "en-SG": "Agak agak only, for %@, scaled from a published figure for another Mac. After your first render it will change to a real measurement.",
})
add("summary.eta.footnote.measured", {
    "en": "Measured from this Mac's own renders on this engine (%@ so far).",
    "zh-Hant": "依本機此引擎的實際算圖測得（目前 %@ 次）。",
    "zh-Hans": "依本机此引擎的实际渲染测得（目前 %@ 次）。",
    "de": "Aus den Renderings dieses Macs mit dieser Engine gemessen (bisher %@).",
    "ar": "مقيس من عمليات التصيير على هذا الـ Mac بهذا المحرّك (%@ حتى الآن).",
    "ja": "この Mac でこのエンジンを使った実測値です（これまで %@ 件）。",
    "ko": "이 Mac에서 이 엔진으로 실제 측정한 값입니다(지금까지 %@ 회).",
    "th": "วัดจากการเรนเดอร์จริงบน Mac เครื่องนี้ด้วย engine นี้ (%@ ครั้งจนถึงตอนนี้)",
    "yue-Hant": "按本機呢個引擎實際算圖度出嚟（暫時 %@ 次）。",
    "en-SG": "Measured from this Mac's own renders on this engine (%@ so far), so quite zhun.",
})
add("models.memory.tooLarge", {
    "en": "Needs about %1$@ in memory. This Mac can give about %2$@ to a model, so this "
          "will swap rather than run.",
    "zh-Hant": "需要約 %1$@ 記憶體。本機可分配給模型的約為 %2$@，因此會落到置換空間而非正常執行。",
    "zh-Hans": "需要约 %1$@ 内存。本机可分配给模型的约为 %2$@，因此会落到交换空间而非正常运行。",
    "de": "Benötigt etwa %1$@ Arbeitsspeicher. Dieser Mac kann einem Modell etwa %2$@ "
          "geben, es würde also auslagern statt zu laufen.",
    "ar": "يحتاج نحو %1$@ من الذاكرة. ولا يستطيع هذا الـ Mac منح النموذج سوى %2$@ تقريبًا، "
          "لذا سيلجأ إلى التبديل بدل التشغيل.",
    "ja": "メモリが約 %1$@ 必要です。この Mac がモデルに割けるのは約 %2$@ なので、実行ではなくスワップになります。",
    "ko": "메모리가 약 %1$@ 필요합니다. 이 Mac이 모델에 줄 수 있는 양은 약 %2$@ 이라 제대로 돌지 않고 스와핑합니다.",
    "th": "ต้องใช้หน่วยความจำราว %1$@ แต่ Mac เครื่องนี้ให้โมเดลได้ราว %2$@ จึงจะสลับหน่วยความจำแทนที่จะรันได้จริง",
    "yue-Hant": "記憶體要大概 %1$@。本機可以俾模型用嘅得大概 %2$@,所以會用到置換空間,跑唔順。",
    "en-SG": "Needs about %1$@ in memory. This Mac only can give a model about %2$@, so it will kena swap, cannot run properly one.",
})
add("models.memory.tight", {
    "en": "Needs about %1$@ of the roughly %2$@ this Mac can give a model. It will fit, "
          "with little to spare.",
    "zh-Hant": "需要約 %1$@，而本機可分配給模型的約為 %2$@。放得下，但餘裕不多。",
    "zh-Hans": "需要约 %1$@，而本机可分配给模型的约为 %2$@。放得下，但余量不多。",
    "de": "Benötigt etwa %1$@ von den rund %2$@, die dieser Mac einem Modell geben kann. Es "
          "passt, aber knapp.",
    "ar": "يحتاج نحو %1$@ من أصل %2$@ تقريبًا يمكن لهذا الـ Mac منحها لنموذج. سيتّسع، لكن "
          "دون هامش يُذكر.",
    "ja": "この Mac がモデルに割ける約 %2$@ のうち、約 %1$@ が必要です。収まりますが、余裕はほとんどありません。",
    "ko": "이 Mac이 모델에 줄 수 있는 약 %2$@ 중 %1$@ 정도가 필요합니다. 들어가기는 하지만 여유가 거의 없습니다.",
    "th": "ต้องใช้ราว %1$@ จากประมาณ %2$@ ที่ Mac เครื่องนี้ให้โมเดลได้ พอดีอยู่ แต่แทบไม่เหลือที่ว่าง",
    "yue-Hant": "要大概 %1$@,而本機可以俾模型用嘅大概 %2$@。夠,但係冇乜餘。",
    "en-SG": "Needs about %1$@, and this Mac can give a model about %2$@. Enough lah, but no room to play.",
})
add("problem.memory", {
    "en": "The selected weights need about %1$@ in memory together. This Mac can give a "
          "model about %2$@. Choose a smaller quantization, or expect it to swap.",
    "zh-Hant": "所選的權重合計需要約 %1$@ 記憶體，而本機可分配給模型的約為 %2$@。請改選更小的量化版本，否則會落到置換空間。",
    "zh-Hans": "所选的权重合计需要约 %1$@ 内存，而本机可分配给模型的约为 %2$@。请改选更小的量化版本，否则会落到交换空间。",
    "de": "Die gewählten Gewichte brauchen zusammen etwa %1$@ Arbeitsspeicher. Dieser Mac "
          "kann einem Modell etwa %2$@ geben. Wählen Sie eine kleinere Quantisierung, oder "
          "rechnen Sie mit Auslagerung.",
    "ar": "تحتاج الأوزان المختارة معًا نحو %1$@ من الذاكرة، ولا يستطيع هذا الـ Mac منح "
          "النموذج سوى %2$@ تقريبًا. اختر تكميمًا أصغر، أو توقّع اللجوء إلى التبديل.",
    "ja": "選択した重みは合わせて約 %1$@ のメモリを必要とします。この Mac がモデルに割けるのは約 %2$@ です。より小さい量子化を選ぶか、スワップを覚悟してください。",
    "ko": "선택한 가중치는 합쳐서 약 %1$@ 의 메모리가 필요합니다. 이 Mac이 모델에 줄 수 있는 양은 약 %2$@ 입니다. 더 작은 양자화를 고르거나 스와핑을 감수하세요.",
    "th": "น้ำหนักที่เลือกต้องใช้หน่วยความจำรวมราว %1$@ แต่ Mac เครื่องนี้ให้โมเดลได้ราว %2$@ เลือก quantization ที่เล็กลง หรือยอมให้สลับหน่วยความจำ",
    "yue-Hant": "揀咗嘅權重加埋大概要 %1$@ 記憶體，而本機可以俾模型用嘅大概係 %2$@。揀細啲嘅量化版本，唔係就要預咗佢用置換空間。",
    "en-SG": "The weights you choose need about %1$@ memory all together. This Mac can give a model about %2$@ only. Choose a smaller quantization, if not confirm plus chop it will kena swap.",
})
add("problem.noMetalKernel", {
    "en": "%@ has no Metal kernel and cannot run on Apple silicon.",
    "zh-Hant": "%@ 沒有對應的 Metal kernel，無法在 Apple 晶片上執行。",
    "zh-Hans": "%@ 没有对应的 Metal kernel，无法在 Apple 芯片上运行。",
    "de": "%@ hat keinen Metal-Kernel und läuft nicht auf Apple Silicon.",
    "ar": "لا يملك %@ نواة Metal، ولا يمكن تشغيله على شرائح Apple.",
    "ja": "%@ には Metal カーネルがなく、Apple シリコンでは実行できません。",
    "ko": "%@ 에는 Metal 커널이 없어 Apple 실리콘에서 실행할 수 없습니다.",
    "th": "%@ ไม่มีเคอร์เนล Metal จึงรันบน Apple silicon ไม่ได้",
    "yue-Hant": "%@ 冇對應嘅 Metal kernel，喺 Apple 晶片上面跑唔到。",
    "en-SG": "%@ got no Metal kernel, so cannot run on Apple silicon.",
}, note={
    "content": "Injects a name into a sentence. Languages that inflect a noun for case, choose "
               "an article by gender, or attach a vowel-harmonising suffix cannot do it without "
               "knowing the word, and it is only known at runtime. Prefer wording that sets the "
               "name apart — quoted, or on its own line. Here the name also begins the sentence, "
               "which forces capitalisation the model name may not want.",
    "level": WARNING,
})

# ── Models: what each entry is ───────────────────────────────────────────────
# Names, not formats. Every one is unique, because the tag pills and the grey
# description below are not where identity should live.
add("model.name.support.mlx", {
    "en": "FL2VA VAEs, processor & tokenizer",
    "zh-Hant": "FL2VA VAE、處理器與 tokenizer",
    "zh-Hans": "FL2VA VAE、处理器与 tokenizer",
    "de": "FL2VA-VAEs, Prozessor und Tokenizer",
    "ar": "‏VAE ومعالج و‏tokenizer لـ FL2VA",
    "ja": "FL2VA の VAE・プロセッサ・トークナイザ",
    "ko": "FL2VA VAE, 프로세서 및 토크나이저",
    "th": "VAE ตัวประมวลผล และ tokenizer ของ FL2VA",
    "yue-Hant": "FL2VA VAE、處理器同 tokenizer",
    "en-SG": "FL2VA VAEs, processor & tokenizer",
})
add("model.name.textEncoder.mlx", {
    "en": "Text encoder — bfloat16",
    "zh-Hant": "文字編碼器 — bfloat16",
    "zh-Hans": "文本编码器 — bfloat16",
    "de": "Text-Encoder – bfloat16",
    "ar": "مشفّر النص — bfloat16",
    "ja": "テキストエンコーダ — bfloat16",
    "ko": "텍스트 인코더 — bfloat16",
    "th": "ตัวเข้ารหัสข้อความ — bfloat16",
    "yue-Hant": "文字編碼器 — bfloat16",
    "en-SG": "Text encoder — bfloat16",
})
add("model.name.fl2va.q4", {
    "en": "FL2VA transformer — 4-bit (MLX)",
    "zh-Hant": "FL2VA transformer — 4-bit (MLX)",
    "zh-Hans": "FL2VA transformer — 4-bit (MLX)",
    "de": "FL2VA-Transformer – 4-bit (MLX)",
    "ar": "محوّل FL2VA — ‏4-bit ‏(MLX)",
    "ja": "FL2VA トランスフォーマー — 4 ビット（MLX）",
    "ko": "FL2VA 트랜스포머 — 4비트(MLX)",
    "th": "Transformer FL2VA — 4 บิต (MLX)",
    "yue-Hant": "FL2VA transformer — 4-bit (MLX)",
    "en-SG": "FL2VA transformer — 4-bit (MLX)",
})
add("model.name.fl2va.q6", {
    "en": "FL2VA transformer — 6-bit (MLX)",
    "zh-Hant": "FL2VA transformer — 6-bit (MLX)",
    "zh-Hans": "FL2VA transformer — 6-bit (MLX)",
    "de": "FL2VA-Transformer – 6-bit (MLX)",
    "ar": "محوّل FL2VA — ‏6-bit ‏(MLX)",
    "ja": "FL2VA トランスフォーマー — 6 ビット（MLX）",
    "ko": "FL2VA 트랜스포머 — 6비트(MLX)",
    "th": "Transformer FL2VA — 6 บิต (MLX)",
    "yue-Hant": "FL2VA transformer — 6-bit (MLX)",
    "en-SG": "FL2VA transformer — 6-bit (MLX)",
})
add("model.name.fl2va.q8", {
    "en": "FL2VA transformer — 8-bit (MLX)",
    "zh-Hant": "FL2VA transformer — 8-bit (MLX)",
    "zh-Hans": "FL2VA transformer — 8-bit (MLX)",
    "de": "FL2VA-Transformer – 8-bit (MLX)",
    "ar": "محوّل FL2VA — ‏8-bit ‏(MLX)",
    "ja": "FL2VA トランスフォーマー — 8 ビット（MLX）",
    "ko": "FL2VA 트랜스포머 — 8비트(MLX)",
    "th": "Transformer FL2VA — 8 บิต (MLX)",
    "yue-Hant": "FL2VA transformer — 8-bit (MLX)",
    "en-SG": "FL2VA transformer — 8-bit (MLX)",
})
add("model.name.fl2va.bf16", {
    "en": "FL2VA transformer — bfloat16",
    "zh-Hant": "FL2VA transformer — bfloat16",
    "zh-Hans": "FL2VA transformer — bfloat16",
    "de": "FL2VA-Transformer – bfloat16",
    "ar": "محوّل FL2VA — ‏bfloat16",
    "ja": "FL2VA トランスフォーマー — bfloat16",
    "ko": "FL2VA 트랜스포머 — bfloat16",
    "th": "Transformer FL2VA — bfloat16",
    "yue-Hant": "FL2VA transformer — bfloat16",
    "en-SG": "FL2VA transformer — bfloat16",
})
add("model.name.ref2va.bf16", {
    "en": "Ref2VA transformer — bfloat16",
    "zh-Hant": "Ref2VA transformer — bfloat16",
    "zh-Hans": "Ref2VA transformer — bfloat16",
    "de": "Ref2VA-Transformer – bfloat16",
    "ar": "محوّل Ref2VA — ‏bfloat16",
    "ja": "Ref2VA トランスフォーマー — bfloat16",
    "ko": "Ref2VA 트랜스포머 — bfloat16",
    "th": "Transformer Ref2VA — bfloat16",
    "yue-Hant": "Ref2VA transformer — bfloat16",
    "en-SG": "Ref2VA transformer — bfloat16",
})
add("model.name.lora.fl2va.mlx", {
    "en": "FL2VA turbo LoRA — 4-step, MLX format",
    "zh-Hant": "FL2VA turbo LoRA — 4 步，MLX 格式",
    "zh-Hans": "FL2VA turbo LoRA — 4 步，MLX 格式",
    "de": "FL2VA-Turbo-LoRA – 4 Schritte, MLX-Format",
    "ar": "‏FL2VA turbo LoRA — أربع خطوات، بصيغة MLX",
    "ja": "FL2VA turbo LoRA — 4 ステップ、MLX 形式",
    "ko": "FL2VA turbo LoRA — 4스텝, MLX 형식",
    "th": "Turbo LoRA ของ FL2VA — 4 step รูปแบบ MLX",
    "yue-Hant": "FL2VA turbo LoRA — 4 步，MLX 格式",
    "en-SG": "FL2VA turbo LoRA — 4-step, MLX format",
})
add("model.name.comfy.ref2va", {
    "en": "Ref2VA transformer — INT8 ConvRot",
    "zh-Hant": "Ref2VA transformer — INT8 ConvRot",
    "zh-Hans": "Ref2VA transformer — INT8 ConvRot",
    "de": "Ref2VA-Transformer – INT8 ConvRot",
    "ar": "محوّل Ref2VA — ‏INT8 ConvRot",
    "ja": "Ref2VA トランスフォーマー — INT8 ConvRot",
    "ko": "Ref2VA 트랜스포머 — INT8 ConvRot",
    "th": "Transformer Ref2VA — INT8 ConvRot",
    "yue-Hant": "Ref2VA transformer — INT8 ConvRot",
    "en-SG": "Ref2VA transformer — INT8 ConvRot",
})
add("model.name.comfy.fl2va", {
    "en": "FL2VA transformer — INT8 ConvRot",
    "zh-Hant": "FL2VA transformer — INT8 ConvRot",
    "zh-Hans": "FL2VA transformer — INT8 ConvRot",
    "de": "FL2VA-Transformer – INT8 ConvRot",
    "ar": "محوّل FL2VA — ‏INT8 ConvRot",
    "ja": "FL2VA トランスフォーマー — INT8 ConvRot",
    "ko": "FL2VA 트랜스포머 — INT8 ConvRot",
    "th": "Transformer FL2VA — INT8 ConvRot",
    "yue-Hant": "FL2VA transformer — INT8 ConvRot",
    "en-SG": "FL2VA transformer — INT8 ConvRot",
})
add("model.name.comfy.textEncoder", {
    "en": "Text encoder — INT8 ConvRot",
    "zh-Hant": "文字編碼器 — INT8 ConvRot",
    "zh-Hans": "文本编码器 — INT8 ConvRot",
    "de": "Text-Encoder – INT8 ConvRot",
    "ar": "مشفّر النص — ‏INT8 ConvRot",
    "ja": "テキストエンコーダ — INT8 ConvRot",
    "ko": "텍스트 인코더 — INT8 ConvRot",
    "th": "ตัวเข้ารหัสข้อความ — INT8 ConvRot",
    "yue-Hant": "文字編碼器 — INT8 ConvRot",
    "en-SG": "Text encoder — INT8 ConvRot",
})
add("model.name.comfy.videoVAE", {
    "en": "Video VAE — fp16",
    "zh-Hant": "Video VAE — fp16",
    "zh-Hans": "Video VAE — fp16",
    "de": "Video-VAE – fp16",
    "ar": "‏VAE الفيديو — ‏fp16",
    "ja": "動画 VAE — fp16",
    "ko": "비디오 VAE — fp16",
    "th": "VAE วิดีโอ — fp16",
    "yue-Hant": "Video VAE — fp16",
    "en-SG": "Video VAE — fp16",
})
add("model.name.comfy.audioVAE", {
    "en": "Audio VAE — fp32",
    "zh-Hant": "Audio VAE — fp32",
    "zh-Hans": "Audio VAE — fp32",
    "de": "Audio-VAE – fp32",
    "ar": "‏VAE الصوت — ‏fp32",
    "ja": "音声 VAE — fp32",
    "ko": "오디오 VAE — fp32",
    "th": "VAE เสียง — fp32",
    "yue-Hant": "Audio VAE — fp32",
    "en-SG": "Audio VAE — fp32",
})
add("model.name.comfy.lora.ref2va", {
    "en": "Ref2VA turbo LoRA — 4-step",
    "zh-Hant": "Ref2VA turbo LoRA — 4 步",
    "zh-Hans": "Ref2VA turbo LoRA — 4 步",
    "de": "Ref2VA-Turbo-LoRA – 4 Schritte",
    "ar": "‏Ref2VA turbo LoRA — أربع خطوات",
    "ja": "Ref2VA turbo LoRA — 4 ステップ",
    "ko": "Ref2VA turbo LoRA — 4스텝",
    "th": "Turbo LoRA ของ Ref2VA — 4 step",
    "yue-Hant": "Ref2VA turbo LoRA — 4 步",
    "en-SG": "Ref2VA turbo LoRA — 4-step",
})
add("model.name.comfy.lora.fl2va", {
    "en": "FL2VA turbo LoRA — 4-step, ComfyUI format",
    "zh-Hant": "FL2VA turbo LoRA — 4 步，ComfyUI 格式",
    "zh-Hans": "FL2VA turbo LoRA — 4 步，ComfyUI 格式",
    "de": "FL2VA-Turbo-LoRA – 4 Schritte, ComfyUI-Format",
    "ar": "‏FL2VA turbo LoRA — أربع خطوات، بصيغة ComfyUI",
    "ja": "FL2VA turbo LoRA — 4 ステップ、ComfyUI 形式",
    "ko": "FL2VA turbo LoRA — 4스텝, ComfyUI 형식",
    "th": "Turbo LoRA ของ FL2VA — 4 step รูปแบบ ComfyUI",
    "yue-Hant": "FL2VA turbo LoRA — 4 步，ComfyUI 格式",
    "en-SG": "FL2VA turbo LoRA — 4-step, ComfyUI format",
})
add("model.name.textEncoder.uncensored", {
    "en": "Text encoder — INT8 ConvRot, uncensored",
    "zh-Hant": "文字編碼器 — INT8 ConvRot，無審查",
    "zh-Hans": "文本编码器 — INT8 ConvRot，无审查",
    "de": "Text-Encoder – INT8 ConvRot, ohne Filter",
    "ar": "مشفّر النص — ‏INT8 ConvRot، بلا رقابة",
    "ja": "テキストエンコーダ — INT8 ConvRot、無検閲",
    "ko": "텍스트 인코더 — INT8 ConvRot, 무검열",
    "th": "ตัวเข้ารหัสข้อความ — INT8 ConvRot ไม่เซ็นเซอร์",
    "yue-Hant": "文字編碼器 — INT8 ConvRot，無審查",
    "en-SG": "Text encoder — INT8 ConvRot, uncensored",
})
add("model.name.fl2va.gguf", {
    "en": "FL2VA transformer — GGUF",
    "zh-Hant": "FL2VA transformer — GGUF",
    "zh-Hans": "FL2VA transformer — GGUF",
    "de": "FL2VA-Transformer – GGUF",
    "ar": "محوّل FL2VA — ‏GGUF",
    "ja": "FL2VA トランスフォーマー — GGUF",
    "ko": "FL2VA 트랜스포머 — GGUF",
    "th": "Transformer FL2VA — GGUF",
    "yue-Hant": "FL2VA transformer — GGUF",
    "en-SG": "FL2VA transformer — GGUF",
})
add("model.name.fl2va.nvfp4", {
    "en": "FL2VA transformer — NVFP4",
    "zh-Hant": "FL2VA transformer — NVFP4",
    "zh-Hans": "FL2VA transformer — NVFP4",
    "de": "FL2VA-Transformer – NVFP4",
    "ar": "محوّل FL2VA — ‏NVFP4",
    "ja": "FL2VA トランスフォーマー — NVFP4",
    "ko": "FL2VA 트랜스포머 — NVFP4",
    "th": "Transformer FL2VA — NVFP4",
    "yue-Hant": "FL2VA transformer — NVFP4",
    "en-SG": "FL2VA transformer — NVFP4",
})

# ── ComfyUI availability ─────────────────────────────────────────────────────
# File names arrive wrapped in backticks and are set in a monospaced face; keep
# the markers in every translation.
add("comfy.notInstalled", {
    "en": "ComfyUI is not installed. Install it in Settings › ComfyUI.",
    "zh-Hant": "尚未安裝 ComfyUI。請至「設定 › ComfyUI」安裝。",
    "zh-Hans": "尚未安装 ComfyUI。请至“设置 › ComfyUI”安装。",
    "de": "ComfyUI ist nicht installiert. Installieren Sie es unter „Einstellungen › "
          "ComfyUI“.",
    "ar": "‏ComfyUI غير مثبَّت. ثبّته من «الإعدادات › ComfyUI».",
    "ja": "ComfyUI がインストールされていません。「設定 › ComfyUI」からインストールしてください。",
    "ko": "ComfyUI가 설치되어 있지 않습니다. 설정 › ComfyUI에서 설치하세요.",
    "th": "ยังไม่ได้ติดตั้ง ComfyUI ติดตั้งได้ที่ การตั้งค่า › ComfyUI",
    "yue-Hant": "仲未裝 ComfyUI。去「設定 › ComfyUI」裝佢。",
    "en-SG": "ComfyUI not installed yet. Go Settings › ComfyUI and install lah.",
})
add("comfy.missingWeights", {
    "en": "Missing ComfyUI weights: %@",
    "zh-Hant": "缺少 ComfyUI 權重檔：%@",
    "zh-Hans": "缺少 ComfyUI 权重文件：%@",
    "de": "Fehlende ComfyUI-Gewichte: %@",
    "ar": "أوزان ComfyUI ناقصة: %@",
    "ja": "ComfyUI の重みが不足しています：%@",
    "ko": "ComfyUI 가중치가 없습니다: %@",
    "th": "ไม่พบไฟล์น้ำหนักของ ComfyUI: %@",
    "yue-Hant": "唔見咗 ComfyUI 權重檔：%@",
    "en-SG": "Missing ComfyUI weights: %@",
})
add("comfy.executionError", {
    "en": "ComfyUI reported an execution error.",
    "zh-Hant": "ComfyUI 回報執行錯誤。",
    "zh-Hans": "ComfyUI 报告执行错误。",
    "de": "ComfyUI hat einen Ausführungsfehler gemeldet.",
    "ar": "أبلغ ComfyUI عن خطأ أثناء التنفيذ.",
    "ja": "ComfyUI が実行エラーを報告しました。",
    "ko": "ComfyUI가 실행 오류를 보고했습니다.",
    "th": "ComfyUI รายงานข้อผิดพลาดขณะทำงาน",
    "yue-Hant": "ComfyUI 話執行出錯。",
    "en-SG": "ComfyUI say got execution error.",
})

# ── Models: row status and copying ───────────────────────────────────────────
add("models.status.inUse", {
    "en": "Downloaded, and used by this render",
    "zh-Hant": "已下載，且本次算圖會用到",
    "zh-Hans": "已下载，且本次渲染会用到",
    "de": "Geladen und für dieses Rendering verwendet",
    "ar": "مُنزَّل، ويُستخدم في هذا التصيير",
    "ja": "ダウンロード済みで、このレンダリングで使用します",
    "ko": "다운로드되어 이번 렌더링에 사용됩니다",
    "th": "ดาวน์โหลดแล้ว และใช้กับการเรนเดอร์นี้",
    "yue-Hant": "下載咗，今次算圖會用到",
    "en-SG": "Downloaded, and this render is using it",
})
add("models.status.missing", {
    "en": "Needed by this render, but not downloaded",
    "zh-Hant": "本次算圖需要，但尚未下載",
    "zh-Hans": "本次渲染需要，但尚未下载",
    "de": "Für dieses Rendering erforderlich, aber nicht geladen",
    "ar": "مطلوب لهذا التصيير، لكنه غير مُنزَّل",
    "ja": "このレンダリングに必要ですが、未ダウンロードです",
    "ko": "이번 렌더링에 필요하지만 아직 내려받지 않았습니다",
    "th": "จำเป็นต่อการเรนเดอร์นี้ แต่ยังไม่ได้ดาวน์โหลด",
    "yue-Hant": "今次算圖要用，但係仲未下載",
    "en-SG": "This render need it, but never download yet leh",
})
add("models.copyLink", {
    "en": "Copy link",
    "zh-Hant": "拷貝連結",
    "zh-Hans": "复制链接",
    "de": "Link kopieren",
    "ar": "نسخ الرابط",
    "ja": "リンクをコピー",
    "ko": "링크 복사",
    "th": "คัดลอกลิงก์",
    "yue-Hant": "拷貝連結",
    "en-SG": "Copy link",
})
add("models.copyFilename", {
    "en": "Copy file name",
    "zh-Hant": "拷貝檔案名稱",
    "zh-Hans": "复制文件名",
    "de": "Dateinamen kopieren",
    "ar": "نسخ اسم الملف",
    "ja": "ファイル名をコピー",
    "ko": "파일 이름 복사",
    "th": "คัดลอกชื่อไฟล์",
    "yue-Hant": "拷貝檔案名",
    "en-SG": "Copy file name",
})
add("models.copyRepoID", {
    "en": "Copy repository id",
    "zh-Hant": "拷貝儲存庫 ID",
    "zh-Hans": "复制仓库 ID",
    "de": "Repository-ID kopieren",
    "ar": "نسخ معرّف المستودع",
    "ja": "リポジトリ ID をコピー",
    "ko": "저장소 ID 복사",
    "th": "คัดลอกรหัสที่เก็บ",
    "yue-Hant": "拷貝儲存庫 ID",
    "en-SG": "Copy repository id",
})

# ── Queue: throughput and sequence length ────────────────────────────────────
# "Tokens" here is the length of the one sequence the text encoder is handed, not
# a running cost: H3 is a diffusion model and generates nothing token by token.
add("queue.perStep.now", {
    "en": "%@/step now",
    "zh-Hant": "目前 %@/步",
    "zh-Hans": "当前 %@/步",
    "de": "jetzt %@/Schritt",
    "ar": "%@/خطوة الآن",
    "ja": "現在 %@/ステップ",
    "ko": "현재 %@/스텝",
    "th": "ตอนนี้ %@/ step",
    "yue-Hant": "而家 %@/步",
    "en-SG": "%@/step now",
})
add("queue.perStep.average", {
    "en": "%@/step average",
    "zh-Hant": "平均 %@/步",
    "zh-Hans": "平均 %@/步",
    "de": "im Mittel %@/Schritt",
    "ar": "%@/خطوة في المتوسط",
    "ja": "平均 %@/ステップ",
    "ko": "평균 %@/스텝",
    "th": "เฉลี่ย %@/ step",
    "yue-Hant": "平均 %@/步",
    "en-SG": "%@/step average",
})
add("queue.tokens", {
    "en": "%@ tokens",
    "zh-Hant": "%@ 個 token",
    "zh-Hans": "%@ 个 token",
    "de": "%@ Tokens",
    "ar": "%@ توكن",
    "ja": "%@ トークン",
    "ko": "%@ 토큰",
    "th": "%@ token",
    "yue-Hant": "%@ 個 token",
    "en-SG": "%@ tokens",
}, note={
    "content": "Takes a count. English offers only two forms and this string supplies one, so \"1 "
               "tokens\" is already wrong; Arabic needs six categories and settles for a single "
               "compromise form. Any language with Slavic-style plurals will need a .stringsdict "
               "before this can be translated correctly.",
    "level": WARNING,
})
add("queue.tokens.help", {
    "en": "Length of the sequence the text encoder reads: %1$@ tokens in all, of which %2$@ "
          "are the prompt. The rest are vision tokens, one block per reference image. It is "
          "read once, before denoising starts — nothing here is generated token by token.",
    "zh-Hant": "文字編碼器讀取的序列長度：共 %1$@ 個 token，其中 %2$@ 個來自提示詞，其餘是視覺 "
               "token，每張參考圖片一段。這段序列在去噪開始前只讀取一次——此處並非逐 token 生成。",
    "zh-Hans": "文本编码器读取的序列长度：共 %1$@ 个 token，其中 %2$@ 个来自提示词，其余是视觉 "
               "token，每张参考图片一段。这段序列在去噪开始前只读取一次——此处并非逐 token 生成。",
    "de": "Länge der Sequenz, die der Text-Encoder liest: insgesamt %1$@ Tokens, davon %2$@ "
          "aus dem Prompt. Der Rest sind Vision-Tokens, ein Block je Referenzbild. Sie wird "
          "einmal vor dem Entrauschen gelesen — hier wird nichts Token für Token erzeugt.",
    "ar": "طول المتسلسلة التي يقرأها مشفّر النص: %1$@ توكن إجمالًا، منها %2$@ من المطالبة، "
          "والباقي توكنات بصرية بمقدار كتلة لكل صورة مرجعية. تُقرأ مرة واحدة قبل بدء إزالة "
          "التشويش — ولا يُولَّد هنا شيء توكنًا بتوكن.",
    "ja": "テキストエンコーダが読む系列の長さです。全体で %1$@ トークン、うち %2$@ がプロンプトです。残りは視覚トークンで、参考画像ごとに 1 ブロックです。ノイズ除去が始まる前に一度だけ読まれ、ここで 1 トークンずつ生成されるものはありません。",
    "ko": "텍스트 인코더가 읽는 시퀀스 길이입니다. 전체 %1$@ 토큰 중 %2$@ 개가 프롬프트이고, 나머지는 참조 이미지마다 한 블록씩인 비전 토큰입니다. 디노이징이 시작되기 전에 한 번만 읽으며, 여기서 토큰을 하나씩 생성하지는 않습니다.",
    "th": "ความยาวของลำดับที่ตัวเข้ารหัสข้อความอ่าน ทั้งหมด %1$@ token โดย %2$@ token เป็น prompt ที่เหลือเป็น token ภาพ หนึ่งบล็อกต่อภาพอ้างอิงหนึ่งภาพ อ่านเพียงครั้งเดียวก่อนเริ่มลด noise ไม่มีอะไรตรงนี้ที่สร้างทีละ token",
    "yue-Hant": "文字編碼器讀嘅序列有幾長:總共 %1$@ 個 token,其中 %2$@ 個係提示詞。其餘係視覺 token,每張參考圖一段。呢段嘢喺去噪開始之前淨係讀一次——呢度唔係逐個 token 生成嘅。",
    "en-SG": "How long the sequence the text encoder reads: %1$@ tokens all together, of which %2$@ come from your prompt. The rest are vision tokens, one block for each reference image. Read once only, before denoising start — nothing here generate token by token one.",
})
add("compose.preset.saved", {
    "en": "Saved “%@” to Presets",
    "zh-Hant": "已將「%@」儲存至預設組合",
    "zh-Hans": "已将“%@”保存至预设组合",
    "de": "„%@“ unter Voreinstellungen gesichert",
    "ar": "حُفِظ «%@» ضمن الإعدادات المُسبَقة",
    "ja": "「%@」をプリセットに保存しました",
    "ko": "'%@' 을(를) 프리셋에 저장했습니다",
    "th": "บันทึก “%@” ลงใน preset แล้ว",
    "yue-Hant": "已經將「%@」存咗入預設組合",
    "en-SG": "Keep “%@” inside Saved Recipes already",
})
add("compose.preset.duplicate", {
    "en": "A preset called “%@” already exists. Choose another name.",
    "zh-Hant": "已有名為「%@」的預設組合，請換一個名稱。",
    "zh-Hans": "已有名为“%@”的预设组合，请换一个名称。",
    "de": "Eine Vorlage namens „%@“ gibt es bereits. Wählen Sie einen anderen Namen.",
    "ar": "يوجد إعداد باسم «%@» مسبقًا. اختر اسمًا آخر.",
    "ja": "「%@」という名前のプリセットは既にあります。別の名前を選んでください。",
    "ko": "'%@' 이름의 프리셋이 이미 있습니다. 다른 이름을 고르세요.",
    "th": "มี preset ชื่อ “%@” อยู่แล้ว กรุณาตั้งชื่ออื่น",
    "yue-Hant": "已經有個叫「%@」嘅預設組合喇，改過個名啦。",
    "en-SG": "Got a recipe called “%@” already. Use another name lah.",
})
add("models.download.starting", {
    "en": "Starting transfer…",
    "zh-Hant": "正在開始傳輸…",
    "zh-Hans": "正在开始传输…",
    "de": "Übertragung wird gestartet…",
    "ar": "جارٍ بدء النقل…",
    "ja": "転送を開始しています…",
    "ko": "전송을 시작하는 중…",
    "th": "กำลังเริ่มถ่ายโอน…",
    "yue-Hant": "開始傳緊…",
    "en-SG": "Starting to transfer…",
})
add("models.downloading", {
    "en": "Downloading…",
    "zh-Hant": "下載中…",
    "zh-Hans": "下载中…",
    "de": "Wird geladen…",
    "ar": "جارٍ التنزيل…",
    "ja": "ダウンロード中…",
    "ko": "다운로드 중…",
    "th": "กำลังดาวน์โหลด…",
    "yue-Hant": "下載緊…",
    "en-SG": "Downloading…",
})

# ── Spoken and compact progress text ─────────────────────────────────────────
# The a11y.* keys are read aloud by VoiceOver, so they are translated even
# though they never appear on screen.
add("format.ofTotal", {
    "en": "%1$@ of %2$@",
    "zh-Hant": "已下載 %1$@，共 %2$@",
    "zh-Hans": "已下载 %1$@，共 %2$@",
    "de": "%1$@ von %2$@",
    "ar": "%1$@ من %2$@",
    "ja": "%2$@ 中 %1$@",
    "ko": "%2$@ 중 %1$@",
    "th": "%1$@ จาก %2$@",
    "yue-Hant": "下載咗 %1$@，總共 %2$@",
    "en-SG": "%1$@ out of %2$@",
})
add("a11y.percent", {
    "en": "%@ percent",
    "zh-Hant": "%@%%",
    "zh-Hans": "%@%%",
    "de": "%@ Prozent",
    "ar": "%@ بالمئة",
    "ja": "%@ パーセント",
    "ko": "%@ 퍼센트",
    "th": "%@ เปอร์เซ็นต์",
    "yue-Hant": "%@%%",
    "en-SG": "%@ percent",
}, note={
    "content": "Spoken by VoiceOver. Percentages take plural agreement in several languages — "
               "Russian distinguishes 1, 2-4 and 5-20 — and this has one form.",
    "level": WARNING,
})
add("a11y.elapsed", {
    "en": "elapsed %@",
    "zh-Hant": "已用 %@",
    "zh-Hans": "已用 %@",
    "de": "%@ vergangen",
    "ar": "انقضى %@",
    "ja": "経過 %@",
    "ko": "경과 %@",
    "th": "ผ่านไป %@",
    "yue-Hant": "用咗 %@",
    "en-SG": "ran %@ already",
})
add("a11y.remaining", {
    "en": "about %@ remaining",
    "zh-Hant": "約剩 %@",
    "zh-Hans": "约剩 %@",
    "de": "noch etwa %@",
    "ar": "يتبقى نحو %@",
    "ja": "残り約 %@",
    "ko": "약 %@ 남음",
    "th": "เหลืออีกประมาณ %@",
    "yue-Hant": "仲爭大概 %@",
    "en-SG": "about %@ more",
})
add("a11y.usingMemory", {
    "en": "using %@",
    "zh-Hant": "佔用 %@",
    "zh-Hans": "占用 %@",
    "de": "belegt %@",
    "ar": "يستخدم %@",
    "ja": "%@ 使用中",
    "ko": "%@ 사용 중",
    "th": "ใช้ %@",
    "yue-Hant": "用緊 %@",
    "en-SG": "using %@",
})
add("queue.a11y.held", {
    "en": "held",
    "zh-Hant": "已暫停",
    "zh-Hans": "已暂停",
    "de": "angehalten",
    "ar": "مُعلَّق",
    "ja": "保留中",
    "ko": "보류됨",
    "th": "พักไว้",
    "yue-Hant": "暫停咗",
    "en-SG": "on hold",
}, note={
    "content": "A lowercase fragment appended to a longer spoken string. Languages that inflect "
               "or that put the qualifier first cannot produce a correct sentence from a "
               "fragment, and lowercase is itself an assumption German does not share.",
    "level": WARNING,
})

# ── Remaining engine and onboarding messages ─────────────────────────────────
add("mlx.runtimeNotReady", {
    "en": "The Python runtime is not ready. Open Settings › Runtime.",
    "zh-Hant": "Python 執行環境尚未就緒。請開啟「設定 › 執行環境」。",
    "zh-Hans": "Python 运行时尚未就绪。请打开“设置 › 运行时”。",
    "de": "Die Python-Umgebung ist nicht bereit. Öffnen Sie „Einstellungen › "
          "Laufzeitumgebung“.",
    "ar": "‏بيئة Python غير جاهزة. افتح «الإعدادات › بيئة التشغيل».",
    "ja": "Python 実行環境が準備できていません。「設定 › 実行環境」を開いてください。",
    "ko": "Python 런타임이 준비되지 않았습니다. 설정 › 런타임을 여세요.",
    "th": "Runtime Python ยังไม่พร้อม เปิด การตั้งค่า › runtime",
    "yue-Hant": "Python 執行環境未 ready。開「設定 › 執行環境」。",
    "en-SG": "Python runtime not ready yet. Open Settings › Runtime.",
})
add("mlx.checkpointMissing", {
    "en": "The selected checkpoint is not installed.",
    "zh-Hant": "所選的檢查點尚未安裝。",
    "zh-Hans": "所选的检查点尚未安装。",
    "de": "Der gewählte Checkpoint ist nicht installiert.",
    "ar": "نقطة التحقّق المختارة غير مثبَّتة.",
    "ja": "選択したチェックポイントがインストールされていません。",
    "ko": "선택한 체크포인트가 설치되어 있지 않습니다.",
    "th": "ยังไม่ได้ติดตั้ง checkpoint ที่เลือก",
    "yue-Hant": "揀咗嘅 checkpoint 仲未裝。",
    "en-SG": "The checkpoint you choose not installed yet.",
})
add("onboarding.spaceTight", {
    "en": "There may not be enough free space once scratch space for rendering is taken "
          "into account.",
    "zh-Hant": "把算圖所需的暫存空間算進來後，可用空間可能不足。",
    "zh-Hans": "把渲染所需的临时空间算进来后，可用空间可能不足。",
    "de": "Zusammen mit dem temporären Speicher fürs Rendern könnte der freie Platz nicht "
          "reichen.",
    "ar": "قد لا تكفي المساحة الحرة بعد احتساب المساحة المؤقتة اللازمة للتصيير.",
    "ja": "レンダリング中の作業用領域まで考えると、空き容量が足りない可能性があります。",
    "ko": "렌더링 중 쓰는 임시 공간까지 고려하면 여유 공간이 모자랄 수 있습니다.",
    "th": "เมื่อรวมพื้นที่ทำงานชั่วคราวขณะเรนเดอร์แล้ว พื้นที่ว่างอาจไม่พอ",
    "yue-Hant": "計埋算圖要用嘅暫存空間，可能唔夠位。",
    "en-SG": "After you count the working space for rendering, maybe not enough space liao.",
})

# ── Settings: what Compose carries over ──────────────────────────────────────
add("settings.remember.section", {
    "en": "Compose",
    "zh-Hant": "編寫",
    "zh-Hans": "编写",
    "de": "Erstellen",
    "ar": "الإنشاء",
    "ja": "作成",
    "ko": "작성",
    "th": "เรียบเรียง",
    "yue-Hant": "編寫",
    "en-SG": "New Video",
}, note="Names the group of Compose-screen settings in Settings ▸ General. A heading "
        "over a set of options, not the tab itself — see section.compose.")
add("settings.remember.mode", {
    "en": "Remember the last mode",
    "zh-Hant": "記住上次使用的模式",
    "zh-Hans": "记住上次使用的模式",
    "de": "Zuletzt verwendeten Modus merken",
    "ar": "تذكّر الوضع المستخدم آخر مرة",
    "ja": "前回のモードを覚えておく",
    "ko": "마지막 모드 기억하기",
    "th": "จำโหมดล่าสุด",
    "yue-Hant": "記住上次用嘅模式",
    "en-SG": "Remember the last mode",
})
add("settings.remember.engine", {
    "en": "Remember the last engine",
    "zh-Hant": "記住上次使用的引擎",
    "zh-Hans": "记住上次使用的引擎",
    "de": "Zuletzt verwendete Engine merken",
    "ar": "تذكّر المحرّك المستخدم آخر مرة",
    "ja": "前回のエンジンを覚えておく",
    "ko": "마지막 엔진 기억하기",
    "th": "จำ engine ล่าสุด",
    "yue-Hant": "記住上次用嘅引擎",
    "en-SG": "Remember the last engine",
})
add("settings.remember.note", {
    "en": "The prompt, the seed and any attached files are never carried over: they belong "
          "to one render, and always start clear.",
    "zh-Hant": "提示詞、種子與附加檔案永遠不會沿用——它們屬於單次算圖，每次都會重新開始。",
    "zh-Hans": "提示词、种子与附加文件永远不会沿用——它们属于单次渲染，每次都会重新开始。",
    "de": "Prompt, Seed und angehängte Dateien werden nie übernommen: Sie gehören zu einem "
          "einzelnen Rendering und beginnen immer leer.",
    "ar": "لا تُنقل أبدًا المطالبة ولا البذرة ولا الملفات المرفقة: فهي تخصّ تصييرًا واحدًا، "
          "وتبدأ فارغة في كل مرة.",
    "ja": "プロンプト・シード・添付ファイルは決して引き継がれません。これらは 1 回のレンダリングに属するもので、常に空の状態から始まります。",
    "ko": "프롬프트와 시드, 첨부 파일은 절대 이어지지 않습니다. 한 번의 렌더링에 속하는 것이라 언제나 비운 채로 시작합니다.",
    "th": "Prompt, seed และไฟล์แนบจะไม่ถูกนำมาใช้ต่อ เพราะเป็นของการเรนเดอร์ครั้งเดียว และเริ่มใหม่เปล่า ๆ เสมอ",
    "yue-Hant": "提示詞、種子同附加檔案永遠唔會沿用：佢哋屬於一次算圖，每次都重新開始。",
    "en-SG": "Prompt, seed and attached files never carry over one: they belong to one render only, and always start empty.",
})
add("settings.remember.sampling", {
    "en": "Remember sampling settings",
    "zh-Hant": "記住取樣設定",
    "zh-Hans": "记住采样设置",
    "de": "Sampling-Einstellungen merken",
    "ar": "تذكّر إعدادات المعاينة",
    "ja": "サンプリング設定を覚えておく",
    "ko": "샘플링 설정 기억하기",
    "th": "จำการตั้งค่าการสุ่มตัวอย่าง",
    "yue-Hant": "記住取樣設定",
    "en-SG": "Remember sampling settings",
})
add("settings.remember.output", {
    "en": "Remember output settings",
    "zh-Hant": "記住輸出設定",
    "zh-Hans": "记住输出设置",
    "de": "Ausgabeeinstellungen merken",
    "ar": "تذكّر إعدادات الإخراج",
    "ja": "出力設定を覚えておく",
    "ko": "출력 설정 기억하기",
    "th": "จำการตั้งค่า output",
    "yue-Hant": "記住輸出設定",
    "en-SG": "Remember output settings",
})

# ── Touch Bar ────────────────────────────────────────────────────────────────
#
# The rest of the strip reuses keys from the screens it mirrors — compose.generate,
# queue.stop, queue.hold and so on — because a control that says one thing in the
# window and another on the Touch Bar is worse than no Touch Bar.
add("touchbar.progress", {
    "en": "Progress",
    "zh-Hant": "進度",
    "zh-Hans": "进度",
    "de": "Fortschritt",
    "ar": "التقدم",
    "ja": "進捗",
    "ko": "진행률",
    "th": "ความคืบหน้า",
    "yue-Hant": "進度",
    "en-SG": "Progress",
}, note="Names the progress item in the Customize Touch Bar sheet, so it is "
        "read out of context, with no render beside it to explain it.")
add("touchbar.idle", {
    "en": "No render running",
    "zh-Hant": "沒有進行中的算圖",
    "zh-Hans": "没有进行中的渲染",
    "de": "Es läuft kein Render",
    "ar": "لا يوجد تصيير قيد التشغيل",
    "ja": "レンダリングなし",
    "ko": "실행 중인 렌더링 없음",
    "th": "ไม่มีการเรนเดอร์",
    "yue-Hant": "冇嘢算緊",
    "en-SG": "Nothing running now",
}, note="Fills the Touch Bar's progress slot when the queue is idle. Keep it "
        "short — the strip is about 685 pt wide in total and this shares it.")
add("touchbar.controls", {
    "en": "Controls",
    "zh-Hant": "控制項",
    "zh-Hans": "控件",
    "de": "Steuerung",
    "ar": "عناصر التحكم",
    "ja": "コントロール",
    "ko": "컨트롤",
    "th": "ส่วนควบคุม",
    "yue-Hant": "控制項",
    "en-SG": "Controls",
}, note="Names the Touch Bar's left-hand item in the Customize Touch Bar sheet. "
        "What it holds depends on the screen — mode and seed while composing, "
        "stop and hold while rendering — so the label has to stay general.")

# ── Notifications ────────────────────────────────────────────────────────────
#
# Delivered when a render ends while the app is in the background. The body
# reuses queue.took and the failure message the backend reported, so only the
# titles are new.
add("notify.finished.title", {
    "en": "Render finished",
    "zh-Hant": "算圖完成",
    "zh-Hans": "渲染完成",
    "de": "Render fertig",
    "ar": "اكتمل التصيير",
    "ja": "レンダリング完了",
    "ko": "렌더링 완료",
    "th": "เรนเดอร์เสร็จแล้ว",
    "yue-Hant": "算好喇",
    "en-SG": "Render done liao",
}, note="Notification title when a render succeeds. Kept short — macOS truncates "
        "a notification title to roughly one line.")
add("notify.failed.title", {
    "en": "Render failed",
    "zh-Hant": "算圖失敗",
    "zh-Hans": "渲染失败",
    "de": "Render fehlgeschlagen",
    "ar": "فشل التصيير",
    "ja": "レンダリング失敗",
    "ko": "렌더링 실패",
    "th": "เรนเดอร์ล้มเหลว",
    "yue-Hant": "算唔到",
    "en-SG": "Render fail liao",
}, note="Notification title when a render fails. Not used when the user cancels "
        "one themselves — that needs no announcement.")
add("notify.failed.body", {
    "en": "It stopped before finishing, and the log has the details.",
    "zh-Hant": "在完成前中止，詳情請看記錄。",
    "zh-Hans": "在完成前中止，详情请看日志。",
    "de": "Er wurde vor dem Ende abgebrochen; Einzelheiten stehen im Protokoll.",
    "ar": "توقّف قبل أن يكتمل، والتفاصيل في السجل.",
    "ja": "完了する前に停止しました。詳細はログを見てください。",
    "ko": "끝나기 전에 멈췄습니다. 자세한 내용은 로그에 있습니다.",
    "th": "หยุดก่อนจะเสร็จ รายละเอียดอยู่ในบันทึก",
    "yue-Hant": "未算完就停咗，詳情睇記錄。",
    "en-SG": "It stop before finish. Go see the log for details.",
}, note="Fallback body for a failure notification, used only when the backend "
        "reported no message of its own.")
add("notify.download.finished.title", {
    "en": "Download finished",
    "zh-Hant": "下載完成",
    "zh-Hans": "下载完成",
    "de": "Download abgeschlossen",
    "ar": "اكتمل التنزيل",
    "ja": "ダウンロード完了",
    "ko": "다운로드 완료",
    "th": "ดาวน์โหลดเสร็จแล้ว",
    "yue-Hant": "下載好喇",
    "en-SG": "Download done liao",
}, note="Notification title when a model finishes downloading. Weights run to "
        "tens of gigabytes, so this often arrives long after the user walked "
        "away — the same reason the render notifications exist.")
add("notify.download.failed.title", {
    "en": "Download failed",
    "zh-Hant": "下載失敗",
    "zh-Hans": "下载失败",
    "de": "Download fehlgeschlagen",
    "ar": "فشل التنزيل",
    "ja": "ダウンロード失敗",
    "ko": "다운로드 실패",
    "th": "ดาวน์โหลดล้มเหลว",
    "yue-Hant": "下載失敗",
    "en-SG": "Download fail liao",
}, note="Notification title when a model download fails. Not used when the user "
        "cancels one.")

# ── Notification settings ────────────────────────────────────────────────────
add("settings.notifications", {
    "en": "Notifications",
    "zh-Hant": "通知",
    "zh-Hans": "通知",
    "de": "Mitteilungen",
    "ar": "الإشعارات",
    "ja": "通知",
    "ko": "알림",
    "th": "การแจ้งเตือน",
    "yue-Hant": "通知",
    "en-SG": "Notifications",
})
add("settings.notifications.note", {
    "en": "A render or a download can run for hours, so the app says so when one "
          "ends — whether or not Halation is the app you happen to be looking at.",
    "zh-Hant": "算圖或下載可能要跑上數小時，所以結束時 App 會通知你——不論你當下看的是不是 Halation。",
    "zh-Hans": "渲染或下载可能要跑上数小时，所以结束时 App 会通知你——不论你当下看的是不是 Halation。",
    "de": "Ein Render oder ein Download kann stundenlang laufen, daher meldet sich "
          "die App, wenn etwas endet — ganz gleich, ob Halation gerade im "
          "Vordergrund ist.",
    "ar": "قد يستغرق التصيير أو التنزيل ساعات، لذا يخبرك التطبيق عند انتهاء أيٍّ "
          "منهما، سواء كان Halation أمامك أم لا.",
    "ja": "レンダリングやダウンロードは何時間もかかることがあるので、終わったらアプリが知らせます——Halation を見ているかどうかに関係なく通知します。",
    "ko": "렌더링이나 다운로드는 몇 시간씩 걸릴 수 있어서, 끝나면 앱이 알려 줍니다 — 지금 보고 있는 앱이 Halation이든 아니든 상관없습니다.",
    "th": "การเรนเดอร์หรือการดาวน์โหลดอาจใช้เวลาหลายชั่วโมง แอปจึงแจ้งเมื่อเสร็จ "
          "ไม่ว่าตอนนั้นคุณจะกำลังดู Halation อยู่หรือไม่",
    "yue-Hant": "算圖或者下載可以跑幾個鐘，所以完咗個 App 會話你知——你當時睇唔睇緊 Halation 都一樣。",
    "en-SG": "Render or download can run for hours, so the app will tell you when it "
             "ends — never mind whether you looking at Halation or not.",
}, note="Explains the notification row in Settings ▸ General and in the welcome "
        "dialog. Banners arrive even when the app is frontmost, which is a "
        "deliberate opt-in — see Notifier.")
add("settings.notifications.open", {
    "en": "Open Notification Settings",
    "zh-Hant": "開啟通知設定",
    "zh-Hans": "打开通知设置",
    "de": "Mitteilungseinstellungen öffnen",
    "ar": "فتح إعدادات الإشعارات",
    "ja": "通知設定を開く",
    "ko": "알림 설정 열기",
    "th": "เปิดการตั้งค่าการแจ้งเตือน",
    "yue-Hant": "開通知設定",
    "en-SG": "Open Notification Settings",
}, note="Button opening System Settings ▸ Notifications, where macOS — not this "
        "app — controls whether notifications are allowed.")
add("settings.notifications.denied", {
    "en": "Turned off in System Settings",
    "zh-Hant": "已在系統設定中關閉",
    "zh-Hans": "已在系统设置中关闭",
    "de": "In den Systemeinstellungen deaktiviert",
    "ar": "مُعطَّلة في إعدادات النظام",
    "ja": "システム設定でオフになっています",
    "ko": "시스템 설정에서 꺼져 있음",
    "th": "ปิดอยู่ในการตั้งค่าระบบ",
    "yue-Hant": "喺系統設定度熄咗",
    "en-SG": "Off inside System Settings",
}, note="Shown when macOS has notifications switched off for Halation. Without "
        "this the app simply stays silent and looks broken.")
add("settings.notifications.notYetAsked", {
    "en": "Asked when you first queue something",
    "zh-Hant": "第一次排入佇列時才會詢問",
    "zh-Hans": "第一次排入队列时才会询问",
    "de": "Wird bei der ersten Warteschlange abgefragt",
    "ar": "يُطلَب عند أول إضافة إلى قائمة الانتظار",
    "ja": "最初にキューに入れたときに確認します",
    "ko": "처음 대기열에 넣을 때 물어봅니다",
    "th": "จะถามเมื่อคุณเข้าคิวครั้งแรก",
    "yue-Hant": "第一次排隊嗰陣先會問你",
    "en-SG": "Will ask you when you first queue something",
}, note="Shown before permission has been requested at all.")
add("settings.notifications.noBanner", {
    "en": "Allowed, but banners are switched off",
    "zh-Hant": "已允許，但橫幅已關閉",
    "zh-Hans": "已允许，但横幅已关闭",
    "de": "Erlaubt, aber Banner sind deaktiviert",
    "ar": "مسموح بها، لكن اللافتات مُعطَّلة",
    "ja": "許可されていますが、バナーがオフです",
    "ko": "허용됐지만 배너가 꺼져 있음",
    "th": "อนุญาตแล้ว แต่แบนเนอร์ถูกปิดอยู่",
    "yue-Hant": "准咗，但係橫額熄咗",
    "en-SG": "Allowed, but banner off",
}, note="macOS separates permission from alert style. A user can allow "
        "notifications and still set the style to None, and then nothing ever "
        "appears on screen — which is indistinguishable from the app being "
        "broken unless this says otherwise.")
add("settings.notifications.focusNote", {
    "en": "A Focus, or Do Not Disturb, holds these in Notification Center instead "
          "of showing a banner. That is macOS rather than Halation — allow "
          "Halation inside that Focus to see them as they arrive.",
    "zh-Hant": "開啟「專注模式」或「勿擾模式」時，這些通知會留在通知中心，不會顯示橫幅。這是 macOS 的行為，不是 Halation —— 在該專注模式中允許 Halation，就能即時看到。",
    "zh-Hans": "开启“专注模式”或“勿扰模式”时，这些通知会留在通知中心，不会显示横幅。这是 macOS 的行为，不是 Halation —— 在该专注模式中允许 Halation，就能即时看到。",
    "de": "Ein Fokus oder „Nicht stören“ behält diese in der Mitteilungszentrale, "
          "statt ein Banner zu zeigen. Das ist macOS, nicht Halation — erlaube "
          "Halation in diesem Fokus, um sie sofort zu sehen.",
    "ar": "يحتفظ وضع التركيز أو «عدم الإزعاج» بهذه الإشعارات في مركز الإشعارات بدل "
          "عرض لافتة. هذا سلوك macOS وليس Halation — اسمح بـ Halation داخل وضع "
          "التركيز لتراها فور وصولها.",
    "ja": "集中モードやおやすみモードのあいだは、バナーを出さずに通知センターに溜まります。これは Halation ではなく macOS の動作です——その集中モードで Halation を許可すると、届いたときに表示されます。",
    "ko": "집중 모드나 방해금지 모드에서는 배너를 띄우지 않고 알림 센터에 쌓아 둡니다. Halation이 아니라 macOS의 동작입니다 — 해당 집중 모드에서 Halation을 허용하면 도착할 때 바로 보입니다.",
    "th": "โหมดโฟกัสหรือห้ามรบกวนจะเก็บการแจ้งเตือนเหล่านี้ไว้ในศูนย์การแจ้งเตือนแทนการแสดงแบนเนอร์ "
          "นี่เป็นพฤติกรรมของ macOS ไม่ใช่ Halation — อนุญาต Halation ในโหมดโฟกัสนั้นเพื่อให้เห็นทันทีที่มาถึง",
    "yue-Hant": "開咗「專注模式」或者「勿擾」嗰陣，呢啲通知會留喺通知中心，唔會出橫額。呢個係 macOS 嘅行為，唔關 Halation 事——喺嗰個專注模式度准咗 Halation，就即刻見到。",
    "en-SG": "Focus or Do Not Disturb will keep these inside Notification Center and "
             "not show any banner. That one is macOS, not Halation — allow Halation "
             "inside that Focus and you will see them as they come.",
}, note="Explains the most common reason a notification arrives but is never "
        "seen. Shown under the permission row in Settings and in the welcome "
        "dialog.")
add("settings.notifications.test", {
    "en": "Send a Test Notification",
    "zh-Hant": "傳送測試通知",
    "zh-Hans": "发送测试通知",
    "de": "Testmitteilung senden",
    "ar": "إرسال إشعار تجريبي",
    "ja": "テスト通知を送る",
    "ko": "테스트 알림 보내기",
    "th": "ส่งการแจ้งเตือนทดสอบ",
    "yue-Hant": "send 個測試通知",
    "en-SG": "Send Test Notification",
}, note="Button beside the permission row. Fires one harmless notification, so a "
        "user can find out whether they will actually see these before waiting "
        "two hours for a render to prove it.")
add("notify.test.title", {
    "en": "Notifications are working",
    "zh-Hant": "通知運作正常",
    "zh-Hans": "通知工作正常",
    "de": "Mitteilungen funktionieren",
    "ar": "الإشعارات تعمل",
    "ja": "通知は届いています",
    "ko": "알림이 작동합니다",
    "th": "การแจ้งเตือนทำงานปกติ",
    "yue-Hant": "通知冇問題",
    "en-SG": "Notifications can already",
}, note="Title of the test notification. Phrased as the conclusion the reader "
        "should draw, since seeing it at all is the whole message.")
add("notify.test.body", {
    "en": "This is what you will get when a render or a download ends.",
    "zh-Hant": "算圖或下載結束時，你會收到的就是這樣的通知。",
    "zh-Hans": "渲染或下载结束时，你会收到的就是这样的通知。",
    "de": "So sieht es aus, wenn ein Render oder ein Download endet.",
    "ar": "هكذا سيصلك الإشعار عند انتهاء تصيير أو تنزيل.",
    "ja": "レンダリングやダウンロードが終わったときは、これと同じ形で届きます。",
    "ko": "렌더링이나 다운로드가 끝나면 이런 알림을 받게 됩니다.",
    "th": "นี่คือสิ่งที่คุณจะได้รับเมื่อการเรนเดอร์หรือการดาวน์โหลดเสร็จ",
    "yue-Hant": "算圖或者下載完咗嗰陣，你收到嘅就係咁樣。",
    "en-SG": "This is what you will get when a render or download ends.",
})

# ── Onboarding body copy ─────────────────────────────────────────────────────
#
# These were literals in OnboardingView until now, which made the first screen a
# new user sees the only untranslated surface in the app.
add("onboarding.welcome.body", {
    "en": "This app runs MiniMax H3 entirely on your own machine. Nothing is sent "
          "to a server, and there is no account or API key.\n\nTwo things are "
          "worth knowing before you start.",
    "zh-Hant": "這個 App 完全在你自己的機器上執行 MiniMax H3。不會傳送任何資料到伺服器，也不需要帳號或 API 金鑰。\n\n開始之前，有兩件事值得先知道。",
    "zh-Hans": "这个 App 完全在你自己的机器上运行 MiniMax H3。不会发送任何数据到服务器，也不需要账号或 API 密钥。\n\n开始之前，有两件事值得先知道。",
    "de": "Diese App führt MiniMax H3 vollständig auf deinem eigenen Rechner aus. "
          "Nichts wird an einen Server gesendet, und es gibt weder Konto noch "
          "API-Schlüssel.\n\nZwei Dinge solltest du vorher wissen.",
    "ar": "يشغّل هذا التطبيق MiniMax H3 على جهازك بالكامل. لا يُرسَل شيء إلى أي "
          "خادم، ولا حاجة إلى حساب أو مفتاح API.\n\nهناك أمران يستحقان المعرفة قبل البدء.",
    "ja": "このアプリは MiniMax H3 をすべてあなたのマシン上で実行します。サーバーには何も送りませんし、アカウントも API キーも要りません。\n\n始める前に、知っておくとよいことが二つあります。",
    "ko": "이 앱은 MiniMax H3를 전적으로 여러분의 기기에서 실행합니다. 서버로 아무것도 보내지 않으며, 계정이나 API 키도 필요 없습니다.\n\n시작하기 전에 알아 둘 것이 두 가지 있습니다.",
    "th": "แอปนี้รัน MiniMax H3 บนเครื่องของคุณทั้งหมด ไม่มีการส่งข้อมูลไปยังเซิร์ฟเวอร์ "
          "และไม่ต้องใช้บัญชีหรือคีย์ API\n\nมีสองเรื่องที่ควรรู้ก่อนเริ่ม",
    "yue-Hant": "呢個 App 完全喺你自己部機度行 MiniMax H3。乜都唔會send去伺服器，亦都唔使帳號或者 API key。\n\n開始之前，有兩樣嘢值得知。",
    "en-SG": "This app runs MiniMax H3 fully on your own machine. Nothing send to any "
             "server, and no account or API key needed.\n\nTwo things worth knowing "
             "before you start.",
})
add("onboarding.slow.body", {
    "en": "H3 is a 33-billion-parameter diffusion model. On an M4 Max, a 5-second "
          "clip at the fast-preview settings takes roughly one to two hours; at 50 "
          "steps it is an overnight job. The queue is built for that — it keeps "
          "running while you use the Mac for other things, and it survives a quit.",
    "zh-Hant": "H3 是一個 330 億參數的擴散模型。在 M4 Max 上，用快速預覽設定算一段 5 秒的片子大約要一到兩小時；50 步則是整夜的工作。佇列正是為此而設——你拿 Mac 做別的事時它照跑，結束 App 也不會中斷。",
    "zh-Hans": "H3 是一个 330 亿参数的扩散模型。在 M4 Max 上，用快速预览设置算一段 5 秒的片子大约要一到两小时；50 步则是整夜的工作。队列正是为此而设——你拿 Mac 做别的事时它照跑，退出 App 也不会中断。",
    "de": "H3 ist ein Diffusionsmodell mit 33 Milliarden Parametern. Auf einem M4 Max "
          "dauert ein 5-Sekunden-Clip mit den Schnellvorschau-Einstellungen etwa ein "
          "bis zwei Stunden; mit 50 Schritten wird daraus eine Nachtschicht. Die "
          "Warteschlange ist dafür gebaut — sie läuft weiter, während du den Mac "
          "anders nutzt, und übersteht ein Beenden.",
    "ar": "‏H3 نموذج انتشار بثلاثة وثلاثين مليار معامل. على M4 Max يستغرق مقطع من خمس "
          "ثوانٍ بإعدادات المعاينة السريعة ساعة إلى ساعتين تقريبًا، وعند خمسين خطوة "
          "يصبح عملًا ليليًا. قائمة الانتظار مصمَّمة لذلك — تواصل العمل بينما تستخدم "
          "الـ Mac في أمور أخرى، وتبقى بعد إنهاء التطبيق.",
    "ja": "H3 は 330 億パラメータの拡散モデルです。M4 Max では、高速プレビュー設定の 5 秒クリップでおよそ 1〜2 時間、50 ステップなら一晩仕事になります。キューはそのために作られています——Mac で別の作業をしていても動き続け、アプリを終了しても消えません。",
    "ko": "H3는 330억 파라미터 디퓨전 모델입니다. M4 Max에서 빠른 미리보기 설정의 5초 클립은 대략 한두 시간, 50스텝이면 밤샘 작업이 됩니다. 대기열은 바로 그것을 위해 만들었습니다 — Mac으로 다른 일을 하는 동안에도 계속 돌아가고, 앱을 종료해도 남습니다.",
    "th": "H3 เป็นโมเดลดิฟฟิวชันขนาด 33 พันล้านพารามิเตอร์ บน M4 Max คลิปห้าวินาทีที่ค่าพรีวิวเร็ว "
          "ใช้เวลาราวหนึ่งถึงสองชั่วโมง ส่วนที่ 50 สเต็ปคืองานข้ามคืน คิวถูกออกแบบมาเพื่อสิ่งนี้ "
          "— ทำงานต่อไปขณะคุณใช้ Mac ทำอย่างอื่น และยังอยู่แม้ปิดแอป",
    "yue-Hant": "H3 係一個 330 億參數嘅擴散模型。喺 M4 Max 上面，用快手預覽設定算一段 5 秒片大概要一至兩個鐘；50 步就係成晚嘅嘢。佇列就係為咗呢樣而整——你攞部 Mac 做第二樣嘢佢照跑，收咗 App 都仲喺度。",
    "en-SG": "H3 is a 33-billion-parameter diffusion model. On an M4 Max, a 5-second "
             "clip at fast-preview settings takes about one to two hours; at 50 steps "
             "it is an overnight job. The queue is built for that — it keeps running "
             "while you use the Mac for other things, and it still there after you quit.",
})
add("onboarding.disk.body", {
    "en": "The recommended set of weights is a little over 100 GB — most of it the "
          "Qwen3-VL-32B text encoder. They are stored in a shared folder so other "
          "projects on this Mac can use the same copy.",
    "zh-Hant": "建議的權重組合略多於 100 GB，其中大部分是 Qwen3-VL-32B 文字編碼器。它們存放在共用資料夾，讓這台 Mac 上的其他專案可以共用同一份。",
    "zh-Hans": "建议的权重组合略多于 100 GB，其中大部分是 Qwen3-VL-32B 文本编码器。它们存放在共享文件夹，让这台 Mac 上的其他项目可以共用同一份。",
    "de": "Der empfohlene Satz Gewichte liegt bei etwas über 100 GB — das meiste davon "
          "der Qwen3-VL-32B-Textencoder. Sie liegen in einem gemeinsamen Ordner, "
          "damit andere Projekte auf diesem Mac dieselbe Kopie nutzen können.",
    "ar": "المجموعة الموصى بها من الأوزان تتجاوز 100 غيغابايت بقليل، ومعظمها مرمِّز النص "
          "‏Qwen3-VL-32B. تُحفَظ في مجلد مشترك كي تستخدم مشاريع أخرى على هذا الـ Mac النسخة نفسها.",
    "ja": "推奨の重み一式は 100 GB を少し超えます。その大半は Qwen3-VL-32B テキストエンコーダです。共有フォルダに置かれるので、この Mac の他のプロジェクトも同じものを使えます。",
    "ko": "권장 가중치 모음은 100 GB를 조금 넘고, 대부분이 Qwen3-VL-32B 텍스트 인코더입니다. 공유 폴더에 저장되므로 이 Mac의 다른 프로젝트도 같은 사본을 쓸 수 있습니다.",
    "th": "ชุดไฟล์น้ำหนักที่แนะนำมีขนาดเกิน 100 GB เล็กน้อย ส่วนใหญ่เป็นตัวเข้ารหัสข้อความ "
          "Qwen3-VL-32B เก็บไว้ในโฟลเดอร์ที่ใช้ร่วมกัน เพื่อให้โปรเจกต์อื่นบน Mac เครื่องนี้ใช้ชุดเดียวกันได้",
    "yue-Hant": "建議嗰套權重多過 100 GB 少少，大部分係 Qwen3-VL-32B 文字編碼器。佢哋擺喺共用資料夾，等呢部 Mac 上面其他專案用返同一份。",
    "en-SG": "The recommended set of weights is a bit over 100 GB — most of it the "
             "Qwen3-VL-32B text encoder. They sit inside a shared folder so other "
             "projects on this Mac can tompang the same copy.",
})
add("onboarding.licence.body", {
    "en": "The weights are open, but not unconditionally. The terms you are agreeing "
          "to are MiniMax's, not this app's, and it is worth reading them on the "
          "model card before you download 60 GB.",
    "zh-Hant": "權重是開放的，但不是無條件的。你要同意的是 MiniMax 的條款，不是這個 App 的；在下載 60 GB 之前，值得先到模型頁面讀一遍。",
    "zh-Hans": "权重是开放的，但不是无条件的。你要同意的是 MiniMax 的条款，不是这个 App 的；在下载 60 GB 之前，值得先到模型页面读一遍。",
    "de": "Die Gewichte sind offen, aber nicht bedingungslos. Die Bedingungen, denen du "
          "zustimmst, sind die von MiniMax und nicht die dieser App — lies sie auf der "
          "Modellseite, bevor du 60 GB herunterlädst.",
    "ar": "الأوزان مفتوحة، لكن ليست بلا شروط. الشروط التي توافق عليها هي شروط MiniMax لا "
          "شروط هذا التطبيق، ويستحق الأمر قراءتها في صفحة النموذج قبل تنزيل 60 غيغابايت.",
    "ja": "重みは公開されていますが、無条件ではありません。同意するのは MiniMax の条件であって、このアプリの条件ではありません。60 GB をダウンロードする前に、モデルカードで読んでおく価値があります。",
    "ko": "가중치는 공개되어 있지만 무조건은 아닙니다. 동의하는 것은 이 앱이 아니라 MiniMax의 약관이며, 60 GB를 내려받기 전에 모델 카드에서 읽어 볼 만합니다.",
    "th": "ไฟล์น้ำหนักเปิดให้ใช้ แต่ไม่ใช่แบบไร้เงื่อนไข สิ่งที่คุณกำลังยอมรับคือเงื่อนไขของ MiniMax "
          "ไม่ใช่ของแอปนี้ และควรอ่านในหน้าโมเดลก่อนจะดาวน์โหลด 60 GB",
    "yue-Hant": "權重係開放嘅，但唔係冇條件。你要同意嘅係 MiniMax 嘅條款，唔係呢個 App 嘅；下載 60 GB 之前，值得去模型頁度睇一次。",
    "en-SG": "The weights are open, but not unconditionally. The terms you agreeing to "
             "are MiniMax's, not this app's, so better go read them on the model card "
             "before you download 60 GB.",
})
add("onboarding.licence.restrictions", {
    "en": "The restrictions that actually bite",
    "zh-Hant": "真正會影響你的限制",
    "zh-Hans": "真正会影响你的限制",
    "de": "Die Einschränkungen, die wirklich greifen",
    "ar": "القيود التي تُحدث فرقًا فعليًا",
    "ja": "実際に効いてくる制限",
    "ko": "실제로 발목을 잡는 제한",
    "th": "ข้อจำกัดที่ส่งผลจริง",
    "yue-Hant": "真係會影響你嘅限制",
    "en-SG": "The restrictions that really bite",
}, note="Card heading. \"Bite\" as in restrictions that have real consequences, "
        "not a warning about danger.")
add("onboarding.licence.bullet.territory", {
    "en": "Local use is restricted in the USA, the EU, the UK and South Korea. "
          "Running the model in those territories needs a separate application to "
          "MiniMax.",
    "zh-Hant": "在美國、歐盟、英國與南韓，本機使用受到限制。要在這些地區執行本模型，需另外向 MiniMax 申請。",
    "zh-Hans": "在美国、欧盟、英国与韩国，本机使用受到限制。要在这些地区运行本模型，需另外向 MiniMax 申请。",
    "de": "Die lokale Nutzung ist in den USA, der EU, dem Vereinigten Königreich und "
          "Südkorea eingeschränkt. Dort braucht der Betrieb des Modells einen eigenen "
          "Antrag bei MiniMax.",
    "ar": "الاستخدام المحلي مقيَّد في الولايات المتحدة والاتحاد الأوروبي والمملكة المتحدة "
          "وكوريا الجنوبية. تشغيل النموذج في تلك المناطق يتطلب طلبًا منفصلًا إلى MiniMax.",
    "ja": "アメリカ、EU、イギリス、韓国ではローカル利用が制限されています。これらの地域でモデルを動かすには、MiniMax への個別の申請が必要です。",
    "ko": "미국, EU, 영국, 한국에서는 로컬 사용이 제한됩니다. 해당 지역에서 모델을 실행하려면 MiniMax에 별도로 신청해야 합니다.",
    "th": "การใช้งานในเครื่องถูกจำกัดในสหรัฐอเมริกา สหภาพยุโรป สหราชอาณาจักร และเกาหลีใต้ "
          "การรันโมเดลในพื้นที่เหล่านั้นต้องยื่นคำขอแยกต่างหากกับ MiniMax",
    "yue-Hant": "喺美國、歐盟、英國同南韓，本機使用受限。要喺呢啲地方行呢個模型，要另外向 MiniMax 申請。",
    "en-SG": "Local use is restricted in the USA, the EU, the UK and South Korea. To "
             "run the model in those places, must apply to MiniMax separately.",
})
add("onboarding.licence.bullet.revenue", {
    "en": "Organisations above roughly US$20 million in annual revenue need "
          "authorisation.",
    "zh-Hant": "年營收約超過 2,000 萬美元的組織需要取得授權。",
    "zh-Hans": "年营收约超过 2,000 万美元的组织需要取得授权。",
    "de": "Organisationen mit mehr als rund 20 Millionen US-Dollar Jahresumsatz "
          "brauchen eine Genehmigung.",
    "ar": "المؤسسات التي تتجاوز إيراداتها السنوية نحو عشرين مليون دولار أمريكي تحتاج إلى تصريح.",
    "ja": "年間売上がおよそ 2,000 万米ドルを超える組織には、許諾が必要です。",
    "ko": "연 매출이 약 2,000만 달러를 넘는 조직은 별도의 승인이 필요합니다.",
    "th": "องค์กรที่มีรายได้ต่อปีเกินราว 20 ล้านดอลลาร์สหรัฐ ต้องขออนุญาตก่อน",
    "yue-Hant": "年收入大概超過 2,000 萬美金嘅機構，要攞授權。",
    "en-SG": "Organisations above around US$20 million yearly revenue need "
             "authorisation.",
})
add("onboarding.licence.bullet.training", {
    "en": "Training another model on H3's output is prohibited.",
    "zh-Hant": "禁止用 H3 的輸出去訓練其他模型。",
    "zh-Hans": "禁止用 H3 的输出去训练其他模型。",
    "de": "Ein anderes Modell mit den Ausgaben von H3 zu trainieren, ist untersagt.",
    "ar": "يُحظر تدريب نموذج آخر على مخرجات H3.",
    "ja": "H3 の出力を使って別のモデルを学習させることは禁止されています。",
    "ko": "H3의 출력으로 다른 모델을 학습시키는 것은 금지되어 있습니다.",
    "th": "ห้ามนำผลลัพธ์จาก H3 ไปฝึกโมเดลอื่น",
    "yue-Hant": "唔准攞 H3 嘅輸出去訓練第二個模型。",
    "en-SG": "Cannot use H3's output to train another model.",
})
add("onboarding.licence.bullet.unlawful", {
    "en": "Unlawful and pornographic output is prohibited by the licence, wherever "
          "you are. There is no server-side filter on a local run, so this is on you "
          "rather than on the software.",
    "zh-Hant": "不論你身在何處，授權條款都禁止產生違法內容與色情內容。本機執行沒有伺服器端過濾，因此這是你的責任，而非軟體的。",
    "zh-Hans": "不论你身在何处，许可条款都禁止产生违法内容与色情内容。本机运行没有服务器端过滤，因此这是你的责任，而非软件的。",
    "de": "Rechtswidrige und pornografische Ausgaben sind durch die Lizenz untersagt, "
          "wo auch immer du bist. Bei einem lokalen Lauf gibt es keinen serverseitigen "
          "Filter — das liegt also bei dir und nicht bei der Software.",
    "ar": "يحظر الترخيص المخرجات غير القانونية والإباحية أينما كنت. ولا يوجد مرشِّح على "
          "الخادم في التشغيل المحلي، فالمسؤولية عليك لا على البرنامج.",
    "ja": "どこにいても、違法な出力と性的な出力はライセンスで禁止されています。ローカル実行にサーバー側のフィルタはないので、これはソフトウェアではなくあなたの責任です。",
    "ko": "어디에 있든 불법적이거나 음란한 출력은 라이선스로 금지됩니다. 로컬 실행에는 서버 측 필터가 없으므로, 이는 소프트웨어가 아니라 사용자의 책임입니다.",
    "th": "สัญญาอนุญาตห้ามผลลัพธ์ที่ผิดกฎหมายและลามกอนาจาร ไม่ว่าคุณจะอยู่ที่ใด "
          "การรันในเครื่องไม่มีตัวกรองฝั่งเซิร์ฟเวอร์ เรื่องนี้จึงเป็นความรับผิดชอบของคุณ ไม่ใช่ของซอฟต์แวร์",
    "yue-Hant": "無論你喺邊度，授權都禁止產生違法同色情內容。本機行冇伺服器端過濾，所以呢樣係你嘅責任，唔係軟件嘅。",
    "en-SG": "Unlawful and pornographic output is prohibited by the licence, wherever "
             "you are. Local run got no server-side filter, so this one is on you, not "
             "on the software.",
})
add("onboarding.licence.toggleHelp", {
    "en": "⌘L toggles this",
    "zh-Hant": "⌘L 可切換此項",
    "zh-Hans": "⌘L 可切换此项",
    "de": "⌘L schaltet dies um",
    "ar": "‏⌘L يبدّل هذا الخيار",
    "ja": "⌘L で切り替えます",
    "ko": "⌘L로 전환합니다",
    "th": "⌘L สลับตัวเลือกนี้",
    "yue-Hant": "⌘L 可以切換呢項",
    "en-SG": "⌘L toggles this",
})
add("onboarding.licence.keys", {
    "en": "⌘L accepts · Return continues · Space activates whichever button has focus",
    "zh-Hant": "⌘L 同意 · Return 繼續 · Space 啟動目前聚焦的按鈕",
    "zh-Hans": "⌘L 同意 · Return 继续 · Space 启动当前聚焦的按钮",
    "de": "⌘L akzeptiert · Return fährt fort · Leertaste aktiviert den fokussierten Knopf",
    "ar": "‏⌘L للموافقة · Return للمتابعة · المسافة تُفعّل الزر الذي عليه التركيز",
    "ja": "⌘L で同意 · Return で次へ · Space でフォーカス中のボタンを実行",
    "ko": "⌘L 동의 · Return 계속 · Space 포커스된 버튼 실행",
    "th": "⌘L ยอมรับ · Return ไปต่อ · Space สั่งทำงานปุ่มที่กำลังโฟกัส",
    "yue-Hant": "⌘L 同意 · Return 繼續 · Space 撳落focus緊嗰個掣",
    "en-SG": "⌘L accepts · Return continues · Space presses whichever button got focus",
}, note="Keyboard hints under the licence checkbox. The key names are what macOS "
        "prints on the keys, so they stay in English.")
add("onboarding.runtime.body", {
    "en": "H3 has no native Swift implementation. The app drives the MLX port through "
          "its own private Python environment, kept separate from any Python you "
          "already have so it cannot break yours or be broken by it.",
    "zh-Hant": "H3 沒有原生的 Swift 實作。這個 App 透過自己專屬的 Python 環境驅動 MLX 移植版，與你既有的任何 Python 互不干擾——不會弄壞你的，也不會被你的弄壞。",
    "zh-Hans": "H3 没有原生的 Swift 实现。这个 App 通过自己专属的 Python 环境驱动 MLX 移植版，与你已有的任何 Python 互不干扰——不会弄坏你的，也不会被你的弄坏。",
    "de": "Für H3 gibt es keine native Swift-Implementierung. Die App steuert den "
          "MLX-Port über eine eigene, private Python-Umgebung, getrennt von jedem "
          "Python, das du schon hast — sie kann deines nicht beschädigen und deines "
          "nicht sie.",
    "ar": "لا توجد لـ H3 نسخة أصلية بلغة Swift. يشغّل التطبيق منفذ MLX عبر بيئة Python "
          "خاصة به، منفصلة عن أي Python لديك، فلا يفسد بيئتك ولا تفسدها بيئتك.",
    "ja": "H3 にネイティブな Swift 実装はありません。このアプリは専用の Python 環境を通して MLX 移植版を動かします。既存の Python とは分けてあるので、互いに壊し合うことはありません。",
    "ko": "H3에는 네이티브 Swift 구현이 없습니다. 이 앱은 자체 전용 Python 환경을 통해 MLX 이식판을 구동하며, 기존에 쓰던 Python과 분리되어 있어 서로 망가뜨리지 않습니다.",
    "th": "H3 ไม่มีการพัฒนาแบบเนทีฟด้วย Swift แอปนี้จึงขับพอร์ต MLX ผ่านสภาพแวดล้อม Python "
          "ของตัวเอง แยกจาก Python ที่คุณมีอยู่ จึงไม่ทำให้ของคุณพัง และไม่ถูกของคุณทำให้พัง",
    "yue-Hant": "H3 冇原生嘅 Swift 實作。呢個 App 用自己專屬嘅 Python 環境去行 MLX 移植版，同你本身嗰啲 Python 分開，唔會整壞你嘅，亦唔會俾你嘅整壞。",
    "en-SG": "H3 got no native Swift implementation. The app drives the MLX port through "
             "its own private Python environment, kept separate from whatever Python you "
             "already have, so it cannot spoil yours and yours cannot spoil it.",
})
add("onboarding.runtime.installs", {
    "en": "What gets installed",
    "zh-Hant": "會安裝哪些東西",
    "zh-Hans": "会安装哪些东西",
    "de": "Was installiert wird",
    "ar": "ما الذي سيُثبَّت",
    "ja": "インストールされるもの",
    "ko": "설치되는 것",
    "th": "สิ่งที่จะถูกติดตั้ง",
    "yue-Hant": "會裝啲乜",
    "en-SG": "What will be installed",
})
add("onboarding.runtime.bullet.uv", {
    "en": "uv, into this app's Application Support folder",
    "zh-Hant": "uv，安裝到這個 App 的 Application Support 資料夾",
    "zh-Hans": "uv，安装到这个 App 的 Application Support 文件夹",
    "de": "uv, in den Application-Support-Ordner dieser App",
    "ar": "‏uv، داخل مجلد Application Support الخاص بهذا التطبيق",
    "ja": "uv（このアプリの Application Support フォルダ内）",
    "ko": "uv — 이 앱의 Application Support 폴더 안에",
    "th": "uv ลงในโฟลเดอร์ Application Support ของแอปนี้",
    "yue-Hant": "uv，裝落呢個 App 嘅 Application Support 資料夾",
    "en-SG": "uv, inside this app's Application Support folder",
})
add("onboarding.runtime.bullet.venv", {
    "en": "A Python 3.12 virtual environment, about 1.5 GB with MLX",
    "zh-Hant": "一個 Python 3.12 虛擬環境，連同 MLX 約 1.5 GB",
    "zh-Hans": "一个 Python 3.12 虚拟环境，连同 MLX 约 1.5 GB",
    "de": "Eine virtuelle Python-3.12-Umgebung, mit MLX rund 1,5 GB",
    "ar": "بيئة Python 3.12 افتراضية، نحو 1.5 غيغابايت مع MLX",
    "ja": "Python 3.12 の仮想環境（MLX 込みで約 1.5 GB）",
    "ko": "Python 3.12 가상 환경 — MLX 포함 약 1.5 GB",
    "th": "สภาพแวดล้อมเสมือนของ Python 3.12 ขนาดราว 1.5 GB เมื่อรวม MLX",
    "yue-Hant": "一個 Python 3.12 虛擬環境，連 MLX 大概 1.5 GB",
    "en-SG": "A Python 3.12 virtual environment, about 1.5 GB with MLX",
})
add("onboarding.runtime.bullet.port", {
    "en": "minimax-h3-mlx, the Apache-2.0 Apple-silicon port",
    "zh-Hant": "minimax-h3-mlx，Apache-2.0 授權的 Apple 晶片移植版",
    "zh-Hans": "minimax-h3-mlx，Apache-2.0 许可的 Apple 芯片移植版",
    "de": "minimax-h3-mlx, der Apple-Silicon-Port unter Apache 2.0",
    "ar": "‏minimax-h3-mlx، منفذ Apple silicon برخصة Apache-2.0",
    "ja": "minimax-h3-mlx（Apache-2.0 の Apple シリコン移植版）",
    "ko": "minimax-h3-mlx — Apache-2.0 라이선스의 Apple 실리콘 이식판",
    "th": "minimax-h3-mlx พอร์ตสำหรับ Apple silicon ภายใต้สัญญาอนุญาต Apache-2.0",
    "yue-Hant": "minimax-h3-mlx，Apache-2.0 授權嘅 Apple 晶片移植版",
    "en-SG": "minimax-h3-mlx, the Apache-2.0 Apple-silicon port",
})
add("onboarding.models.body", {
    "en": "The recommended set is the 4-bit FL2VA transformer plus the bfloat16 text "
          "encoder and the shared VAEs — the fastest combination the MLX port can "
          "currently load. Higher-precision transformers can be added later from the "
          "Models tab without re-downloading the encoder.",
    "zh-Hant": "建議的組合是 4-bit FL2VA transformer，加上 bfloat16 文字編碼器與共用的 VAE——這是目前 MLX 移植版能載入的最快組合。之後可以從「模型」分頁再加上更高精度的 transformer，不必重新下載編碼器。",
    "zh-Hans": "建议的组合是 4-bit FL2VA transformer，加上 bfloat16 文本编码器与共用的 VAE——这是目前 MLX 移植版能载入的最快组合。之后可以从“模型”分页再加上更高精度的 transformer，不必重新下载编码器。",
    "de": "Empfohlen sind der 4-Bit-FL2VA-Transformer, der bfloat16-Textencoder und die "
          "gemeinsamen VAEs — die schnellste Kombination, die der MLX-Port derzeit "
          "laden kann. Transformer höherer Präzision lassen sich später im Tab "
          "„Modelle“ ergänzen, ohne den Encoder erneut zu laden.",
    "ar": "المجموعة الموصى بها هي محوّل FL2VA بأربع بتات مع مرمِّز النص bfloat16 ووحدات "
          "الـ VAE المشتركة — أسرع تركيبة يستطيع منفذ MLX تحميلها حاليًا. ويمكن لاحقًا "
          "إضافة محوّلات أعلى دقة من تبويب النماذج دون إعادة تنزيل المرمِّز.",
    "ja": "推奨は 4-bit の FL2VA transformer に bfloat16 のテキストエンコーダと共有 VAE を組み合わせたもの——現時点で MLX 移植版が読み込める最速の構成です。より高精度の transformer は、あとから「モデル」タブで追加でき、エンコーダを再ダウンロードする必要はありません。",
    "ko": "권장 구성은 4비트 FL2VA 트랜스포머에 bfloat16 텍스트 인코더와 공용 VAE를 더한 것으로, 현재 MLX 이식판이 불러올 수 있는 가장 빠른 조합입니다. 더 높은 정밀도의 트랜스포머는 나중에 모델 탭에서 추가할 수 있고, 인코더를 다시 내려받을 필요는 없습니다.",
    "th": "ชุดที่แนะนำคือ FL2VA transformer แบบ 4 บิต บวกกับตัวเข้ารหัสข้อความ bfloat16 "
          "และ VAE ที่ใช้ร่วมกัน ซึ่งเป็นชุดที่เร็วที่สุดที่พอร์ต MLX โหลดได้ในตอนนี้ "
          "transformer ความแม่นยำสูงกว่าเพิ่มทีหลังได้จากแท็บโมเดล โดยไม่ต้องดาวน์โหลดตัวเข้ารหัสซ้ำ",
    "yue-Hant": "建議嗰套係 4-bit FL2VA transformer，加 bfloat16 文字編碼器同共用嘅 VAE——係而家 MLX 移植版載入得到最快嘅組合。想要精度高啲嘅 transformer，之後喺「模型」度加得，唔使再下載多次編碼器。",
    "en-SG": "The recommended set is the 4-bit FL2VA transformer plus the bfloat16 text "
             "encoder and the shared VAEs — fastest combination the MLX port can load "
             "right now. Higher-precision transformers can add later from the Models "
             "tab, no need download the encoder again.",
})
add("onboarding.models.aboutToDownload", {
    "en": "About to download",
    "zh-Hant": "即將下載",
    "zh-Hans": "即将下载",
    "de": "Wird gleich geladen",
    "ar": "على وشك التنزيل",
    "ja": "これからダウンロードするもの",
    "ko": "곧 내려받을 항목",
    "th": "กำลังจะดาวน์โหลด",
    "yue-Hant": "就快下載",
    "en-SG": "About to download",
})

# ── Memory reporting ─────────────────────────────────────────────────────────
add("status.memory.peak", {
    "en": "peak %@",
    "zh-Hant": "尖峰 %@",
    "zh-Hans": "峰值 %@",
    "de": "Spitze %@",
    "ar": "الذروة %@",
    "ja": "ピーク %@",
    "ko": "최대 %@",
    "th": "สูงสุด %@",
    "yue-Hant": "最高 %@",
    "en-SG": "peak %@",
}, note="Highest combined memory reached during this render, shown beside the "
        "current figure in the status bar.")
add("status.memory.breakdown", {
    "en": "%1$@ in the engine, %2$@ in the app. Peak %3$@ of this Mac's %4$@.",
    "zh-Hant": "引擎佔 %1$@，App 佔 %2$@。尖峰 %3$@，本機共 %4$@。",
    "zh-Hans": "引擎占 %1$@，App 占 %2$@。峰值 %3$@，本机共 %4$@。",
    "de": "%1$@ im Engine-Prozess, %2$@ in der App. Spitze %3$@ von %4$@ dieses Macs.",
    "ar": "%1$@ في المحرّك و%2$@ في التطبيق. الذروة %3$@ من %4$@ في هذا الـ Mac.",
    "ja": "エンジンが %1$@、アプリが %2$@。ピークは %3$@（この Mac の %4$@ 中）。",
    "ko": "엔진 %1$@, 앱 %2$@. 최대 %3$@ — 이 Mac의 %4$@ 중.",
    "th": "เอนจิน %1$@ แอป %2$@ สูงสุด %3$@ จาก %4$@ ของ Mac เครื่องนี้",
    "yue-Hant": "引擎佔 %1$@，App 佔 %2$@。最高 %3$@，本機總共 %4$@。",
    "en-SG": "%1$@ in the engine, %2$@ in the app. Peak %3$@ out of this Mac's %4$@.",
}, note="Tooltip on the status bar's memory figure. The engine is the Python "
        "process and its children, which hold almost all of it; the app's own "
        "share is a few hundred megabytes.")

# ── Cache settings ───────────────────────────────────────────────────────────
add("settings.cache", {
    "en": "Cache", "zh-Hant": "快取", "zh-Hans": "缓存", "de": "Cache",
    "ar": "ذاكرة مؤقتة", "ja": "キャッシュ", "ko": "캐시", "th": "แคช",
    "yue-Hant": "快取", "en-SG": "Cache",
}, note="Settings tab listing what the app has left on disk that can be deleted "
        "without losing anything. Model weights and finished videos are not here.")
add("settings.cache.note", {
    "en": "Everything here can be deleted without losing work — it is rebuilt or "
          "re-downloaded when needed. Model weights and finished videos are not "
          "listed: those live under Folders in the General tab, and are never "
          "touched from here.",
    "zh-Hant": "這裡的東西都可以刪除，不會弄丟任何成果——需要時會重建或重新下載。模型權重與完成的影片不在此列：它們在「一般」分頁的「資料夾」一節，這裡永遠不會動到。",
    "zh-Hans": "这里的东西都可以删除，不会丢失任何成果——需要时会重建或重新下载。模型权重与完成的视频不在此列：它们在“通用”分页的“文件夹”一节，这里永远不会动到。",
    "de": "Alles hier lässt sich löschen, ohne Arbeit zu verlieren — es wird bei "
          "Bedarf neu erzeugt oder geladen. Modellgewichte und fertige Videos "
          "stehen nicht hier: die stehen im Tab „Allgemein“ unter „Ordner“ und werden von hier aus "
          "nie angerührt.",
    "ar": "كل ما هنا يمكن حذفه دون فقدان أي عمل — يُعاد بناؤه أو تنزيله عند الحاجة. "
          "أوزان النماذج ومقاطع الفيديو المنجزة ليست هنا: مكانها قسم المجلدات في تبويب عام، ولا "
          "تُمَس من هذه الصفحة أبدًا.",
    "ja": "ここにあるものはすべて削除しても作業は失われません——必要になれば作り直すか再ダウンロードします。モデルの重みと完成した動画はここには出ません。それらは「一般」タブの「フォルダ」にあり、ここから触ることはありません。",
    "ko": "여기 있는 것은 모두 지워도 작업이 사라지지 않습니다 — 필요하면 다시 만들거나 내려받습니다. 모델 가중치와 완성된 영상은 여기 없습니다. 그것들은 일반 탭의 폴더 항목에 있고, 이 화면에서는 절대 건드리지 않습니다.",
    "th": "ทุกอย่างที่นี่ลบได้โดยไม่เสียงาน เพราะจะถูกสร้างใหม่หรือดาวน์โหลดใหม่เมื่อจำเป็น "
          "ไฟล์น้ำหนักโมเดลและวิดีโอที่เสร็จแล้วไม่อยู่ในรายการนี้ — อยู่ในหัวข้อโฟลเดอร์ของแท็บทั่วไป และจะไม่ถูกแตะจากที่นี่",
    "yue-Hant": "呢度啲嘢全部刪得，唔會蝕咗任何成果——要用嗰陣會重建或者再下載。模型權重同算好嘅片唔喺呢度：佢哋喺「一般」嗰版嘅「資料夾」嗰度，呢度永遠唔會郁佢哋。",
    "en-SG": "Everything here can delete without losing any work — it gets rebuilt or "
             "downloaded again when needed. Model weights and finished videos not "
             "listed here: those sit under Folders in the General tab, and never get "
             "touched from here.",
})
add("settings.cache.clearAll", {
    "en": "Clear All", "zh-Hant": "全部清除", "zh-Hans": "全部清除",
    "de": "Alle leeren", "ar": "مسح الكل", "ja": "すべて消去", "ko": "모두 지우기",
    "th": "ล้างทั้งหมด", "yue-Hant": "全部清走", "en-SG": "Clear All",
})
add("settings.cache.busy", {
    "en": "Not while a render or a download is running.",
    "zh-Hant": "算圖或下載進行中時無法清除。",
    "zh-Hans": "渲染或下载进行中时无法清除。",
    "de": "Nicht, solange ein Render oder ein Download läuft.",
    "ar": "غير متاح أثناء تشغيل تصيير أو تنزيل.",
    "ja": "レンダリングやダウンロードの実行中はできません。",
    "ko": "렌더링이나 다운로드가 실행 중일 때는 할 수 없습니다.",
    "th": "ทำไม่ได้ขณะกำลังเรนเดอร์หรือดาวน์โหลด",
    "yue-Hant": "算緊圖或者下載緊嗰陣做唔到。",
    "en-SG": "Cannot, render or download is running.",
}, note="Shown when the clear buttons are disabled. These files are in use "
        "mid-render, so deleting them would break the job in flight.")
add("settings.cache.empty", {
    "en": "Nothing cached", "zh-Hant": "沒有快取", "zh-Hans": "没有缓存",
    "de": "Nichts im Cache", "ar": "لا شيء مخزَّن", "ja": "キャッシュなし",
    "ko": "캐시 없음", "th": "ไม่มีแคช", "yue-Hant": "冇快取", "en-SG": "Nothing cached",
})
add("settings.cache.uv", {
    "en": "Package downloads (uv)",
    "zh-Hant": "套件下載快取（uv）", "zh-Hans": "包下载缓存（uv）",
    "de": "Paket-Downloads (uv)", "ar": "تنزيلات الحزم (uv)",
    "ja": "パッケージのダウンロード（uv）", "ko": "패키지 다운로드 (uv)",
    "th": "แพ็กเกจที่ดาวน์โหลด (uv)", "yue-Hant": "套件下載快取（uv）",
    "en-SG": "Package downloads (uv)",
})
add("settings.cache.uv.detail", {
    "en": "Wheels uv kept while building the Python runtime. Shared with any other "
          "uv project on this Mac, so clearing it makes their next install slower "
          "too — nothing is lost either way.",
    "zh-Hant": "uv 在建立 Python 執行環境時保留的套件檔。這台 Mac 上其他使用 uv 的專案也共用它，所以清掉之後它們下次安裝也會變慢——但不會遺失任何東西。",
    "zh-Hans": "uv 在建立 Python 运行环境时保留的包文件。这台 Mac 上其他使用 uv 的项目也共用它，所以清掉之后它们下次安装也会变慢——但不会丢失任何东西。",
    "de": "Wheels, die uv beim Bau der Python-Umgebung behalten hat. Wird mit jedem "
          "anderen uv-Projekt auf diesem Mac geteilt, deren nächste Installation "
          "also ebenfalls langsamer wird — verloren geht dabei nichts.",
    "ar": "حزم احتفظ بها uv أثناء بناء بيئة Python. وهي مشتركة مع أي مشروع uv آخر "
          "على هذا الـ Mac، فمسحها يبطئ تثبيتها التالي أيضًا — دون فقدان أي شيء.",
    "ja": "Python 環境を作るときに uv が保存した wheel です。この Mac の他の uv プロジェクトとも共有しているので、消すとそれらの次回インストールも遅くなります——失われるものはありません。",
    "ko": "Python 환경을 만들 때 uv가 보관한 휠입니다. 이 Mac의 다른 uv 프로젝트와 공유하므로, 지우면 그쪽의 다음 설치도 느려집니다 — 잃는 것은 없습니다.",
    "th": "ไฟล์ wheel ที่ uv เก็บไว้ตอนสร้างสภาพแวดล้อม Python ใช้ร่วมกับโปรเจกต์ uv อื่นบน Mac เครื่องนี้ "
          "ล้างแล้วการติดตั้งครั้งหน้าของโปรเจกต์เหล่านั้นจะช้าลงด้วย แต่ไม่มีอะไรสูญหาย",
    "yue-Hant": "uv 整 Python 環境嗰陣留低嘅套件檔。呢部 Mac 上面其他用 uv 嘅專案都共用，所以清咗佢哋下次裝嘢都會慢啲——不過乜都唔會冇咗。",
    "en-SG": "Wheels uv kept while building the Python runtime. Shared with any other "
             "uv project on this Mac, so clearing it makes their next install slower "
             "also — nothing lost either way.",
}, note="The shared-cache caveat is the point: this folder is not the app's "
        "alone, and the user should know before emptying it.")
add("settings.cache.bytecode", {
    "en": "Python bytecode",
    "zh-Hant": "Python 位元碼", "zh-Hans": "Python 字节码",
    "de": "Python-Bytecode", "ar": "شِفرة Python الوسيطة",
    "ja": "Python のバイトコード", "ko": "Python 바이트코드",
    "th": "ไบต์โค้ดของ Python", "yue-Hant": "Python 位元碼",
    "en-SG": "Python bytecode",
})
add("settings.cache.bytecode.detail", {
    "en": "__pycache__ folders written by ComfyUI as it runs. Regenerated the next "
          "time it starts, a little more slowly.",
    "zh-Hant": "ComfyUI 執行時寫入的 __pycache__ 資料夾。下次啟動會重新產生，只是稍微慢一點。",
    "zh-Hans": "ComfyUI 运行时写入的 __pycache__ 文件夹。下次启动会重新生成，只是稍微慢一点。",
    "de": "__pycache__-Ordner, die ComfyUI im Betrieb schreibt. Werden beim nächsten "
          "Start neu erzeugt, nur etwas langsamer.",
    "ar": "مجلدات __pycache__ التي يكتبها ComfyUI أثناء عمله. تُعاد كتابتها عند "
          "التشغيل التالي، وإن كان أبطأ قليلًا.",
    "ja": "ComfyUI が動作中に書き出す __pycache__ フォルダです。次回起動時に作り直されますが、その分だけ少し遅くなります。",
    "ko": "ComfyUI가 실행되면서 만드는 __pycache__ 폴더입니다. 다음 시작 때 다시 만들어지며, 그만큼 조금 느려집니다.",
    "th": "โฟลเดอร์ __pycache__ ที่ ComfyUI เขียนไว้ขณะทำงาน จะถูกสร้างใหม่เมื่อเริ่มครั้งหน้า เพียงแต่ช้าลงเล็กน้อย",
    "yue-Hant": "ComfyUI 行嗰陣寫低嘅 __pycache__ 資料夾。下次開會再整返，不過會慢少少。",
    "en-SG": "__pycache__ folders ComfyUI writes while it runs. Made again next time "
             "it starts, just a bit slower.",
})
add("settings.cache.comfyOutput", {
    "en": "ComfyUI leftovers",
    "zh-Hant": "ComfyUI 殘留檔", "zh-Hans": "ComfyUI 残留文件",
    "de": "ComfyUI-Reste", "ar": "بقايا ComfyUI", "ja": "ComfyUI の残りファイル",
    "ko": "ComfyUI 잔여 파일", "th": "ไฟล์ตกค้างของ ComfyUI",
    "yue-Hant": "ComfyUI 剩低嘅檔", "en-SG": "ComfyUI leftovers",
})
add("settings.cache.comfyOutput.detail", {
    "en": "Copies ComfyUI wrote into its own output and input folders. The app "
          "already moved what it needed into your Library.",
    "zh-Hant": "ComfyUI 寫進自己 output 與 input 資料夾的副本。App 需要的東西已經搬到你的媒體庫了。",
    "zh-Hans": "ComfyUI 写进自己 output 与 input 文件夹的副本。App 需要的东西已经搬到你的媒体库了。",
    "de": "Kopien, die ComfyUI in seine eigenen Ordner output und input geschrieben "
          "hat. Was gebraucht wurde, hat die App längst in deine Mediathek verschoben.",
    "ar": "نسخ كتبها ComfyUI في مجلدي output وinput الخاصين به. أما ما يلزم فقد نقله "
          "التطبيق إلى مكتبتك بالفعل.",
    "ja": "ComfyUI が自分の output と input フォルダに書いた複製です。必要なものはアプリがすでにライブラリへ移してあります。",
    "ko": "ComfyUI가 자체 output, input 폴더에 남긴 복사본입니다. 필요한 것은 앱이 이미 라이브러리로 옮겼습니다.",
    "th": "สำเนาที่ ComfyUI เขียนไว้ในโฟลเดอร์ output และ input ของตัวเอง ส่วนที่จำเป็นแอปย้ายเข้าคลังของคุณไปแล้ว",
    "yue-Hant": "ComfyUI 寫入佢自己 output 同 input 資料夾嘅副本。App 要用嘅嘢已經搬咗去你個媒體庫。",
    "en-SG": "Copies ComfyUI wrote into its own output and input folders. The app "
             "already moved whatever it needed into your Library.",
})
add("settings.cache.scratch", {
    "en": "Render scratch",
    "zh-Hant": "算圖暫存", "zh-Hans": "渲染暂存", "de": "Render-Zwischendateien",
    "ar": "ملفات التصيير المؤقتة", "ja": "レンダリングの作業ファイル",
    "ko": "렌더링 임시 파일", "th": "ไฟล์ชั่วคราวของการเรนเดอร์",
    "yue-Hant": "算圖暫存", "en-SG": "Render scratch",
})
add("settings.cache.scratch.detail", {
    "en": "Working files from renders that were interrupted. A finished render "
          "clears its own.",
    "zh-Hant": "中斷的算圖留下的工作檔。順利完成的算圖會自行清掉。",
    "zh-Hans": "中断的渲染留下的工作文件。顺利完成的渲染会自行清掉。",
    "de": "Arbeitsdateien abgebrochener Renders. Ein fertig gewordener Render räumt "
          "seine eigenen weg.",
    "ar": "ملفات عمل من عمليات تصيير انقطعت. أما التصيير الذي يكتمل فينظّف ملفاته بنفسه.",
    "ja": "中断されたレンダリングが残した作業ファイルです。最後まで終わったものは自分で片づけます。",
    "ko": "중단된 렌더링이 남긴 작업 파일입니다. 끝까지 마친 렌더링은 스스로 지웁니다.",
    "th": "ไฟล์ทำงานจากการเรนเดอร์ที่ถูกขัดจังหวะ ส่วนที่เรนเดอร์จนเสร็จจะล้างของตัวเอง",
    "yue-Hant": "中途斷咗嘅算圖留低嘅工作檔。行得完嗰啲會自己清走。",
    "en-SG": "Working files from renders that got interrupted. A render that finishes "
             "clears its own.",
})

# ── Memory requirements table ────────────────────────────────────────────────
add("settings.memory", {
    "en": "Memory", "zh-Hant": "記憶體", "zh-Hans": "内存", "de": "Speicher",
    "ar": "الذاكرة", "ja": "メモリ", "ko": "메모리", "th": "หน่วยความจำ",
    "yue-Hant": "記憶體", "en-SG": "Memory",
}, note="Settings tab, and the welcome dialog's second page: which model and "
        "engine combinations fit in how much unified memory.")
add("memory.table.combination", {
    "en": "Model and engine", "zh-Hant": "模型與引擎", "zh-Hans": "模型与引擎",
    "de": "Modell und Engine", "ar": "النموذج والمحرّك", "ja": "モデルとエンジン",
    "ko": "모델과 엔진", "th": "โมเดลและเอนจิน", "yue-Hant": "模型同引擎",
    "en-SG": "Model and engine",
})
add("memory.table.weights", {
    "en": "Weights", "zh-Hant": "權重", "zh-Hans": "权重", "de": "Gewichte",
    "ar": "الأوزان", "ja": "重み", "ko": "가중치", "th": "ไฟล์น้ำหนัก",
    "yue-Hant": "權重", "en-SG": "Weights",
}, note="Column heading: how much the weights alone occupy, before the working "
        "memory generation needs on top.")
add("memory.table.budget", {
    "en": "Usable for a model", "zh-Hant": "可給模型使用", "zh-Hans": "可给模型使用",
    "de": "Für ein Modell nutzbar", "ar": "المتاح للنموذج",
    "ja": "モデルに使える量", "ko": "모델이 쓸 수 있는 양",
    "th": "ใช้ได้สำหรับโมเดล", "yue-Hant": "可以俾模型用", "en-SG": "Usable for a model",
}, note="Sub-heading row under each machine size, giving the share of unified "
        "memory the GPU may actually hold.")
add("memory.table.orLess", {
    "en": "%@ or less", "zh-Hant": "%@ 或更少", "zh-Hans": "%@ 或更少",
    "de": "%@ oder weniger", "ar": "%@ أو أقل", "ja": "%@ 以下", "ko": "%@ 이하",
    "th": "%@ หรือน้อยกว่า", "yue-Hant": "%@ 或者更少", "en-SG": "%@ or less",
})
add("memory.table.orMore", {
    "en": "More than %@", "zh-Hant": "超過 %@", "zh-Hans": "超过 %@",
    "de": "Mehr als %@", "ar": "أكثر من %@", "ja": "%@ 超", "ko": "%@ 초과",
    "th": "มากกว่า %@", "yue-Hant": "多過 %@", "en-SG": "More than %@",
})
add("memory.verdict.fits", {
    "en": "Fits", "zh-Hant": "可執行", "zh-Hans": "可运行", "de": "Passt",
    "ar": "يكفي", "ja": "動きます", "ko": "실행 가능", "th": "รันได้",
    "yue-Hant": "行得", "en-SG": "Can",
}, note="Verdict in a table cell: this combination runs without swapping.")
add("memory.verdict.tight", {
    "en": "Tight", "zh-Hant": "勉強", "zh-Hans": "勉强", "de": "Knapp",
    "ar": "على الحد", "ja": "ぎりぎり", "ko": "빡빡함", "th": "เฉียดฉิว",
    "yue-Hant": "好緊", "en-SG": "Very tight",
}, note="Verdict: it will run, but with almost nothing to spare, so anything "
        "else on the machine may push it into swap.")
add("memory.verdict.swaps", {
    "en": "Swaps", "zh-Hant": "會置換", "zh-Hans": "会置换", "de": "Swappt",
    "ar": "يستخدم التبديل", "ja": "スワップします", "ko": "스와핑함",
    "th": "จะสลับหน่วยความจำ", "yue-Hant": "會置換", "en-SG": "Will swap",
}, note="Verdict: it does not fit, so macOS pages to disk and a render that "
        "would take an hour takes far longer. Not a refusal — the app still "
        "lets the user try.")
add("memory.table.note", {
    "en": "Weights are only part of it: generating needs working memory on top, "
          "and a measured render peaked at about 2.4 times its weight "
          "figure. The verdicts allow for that. \u201cTight\u201d means the peak "
          "clears the usable share but still fits in installed memory, so macOS "
          "pages some of it out and the render finishes anyway \u2014 measured, a "
          "120 GB peak on a 128 GB Mac used 16 GB of swap and completed. "
          "\u201cSwaps\u201d means it exceeds installed memory, and a render that "
          "would take an hour takes far longer. The usable share is what Metal "
          "reports for the machine \u2014 roughly three quarters to five sixths of "
          "what is installed, higher on the larger configurations.",
    "zh-Hant": "權重只是其中一部分：生成時還需要額外的工作記憶體，實測一次算圖的尖峰約為權重數字的 2.4 倍，上表的判定已計入這點。「吃緊」是指尖峰超出可用額度、但仍裝得進已安裝的記憶體，macOS 會把一部分換出，算圖照樣完成——實測在 128 GB 機器上尖峰 120 GB，用掉 16 GB 置換空間並順利跑完。「置換」是指超出已安裝的記憶體，本來一小時的算圖會拖得久很多。可用比例取自 Metal 對該機器的回報——大約是安裝容量的四分之三到六分之五，容量越大比例越高。",
    "zh-Hans": "权重只是其中一部分：生成时还需要额外的工作内存，实测一次渲染的峰值约为权重数字的 2.4 倍，上表的判定已计入这点。“吃紧”是指峰值超出可用额度、但仍装得进已安装的内存，macOS 会把一部分换出，渲染照样完成——实测在 128 GB 机器上峰值 120 GB，用掉 16 GB 交换空间并顺利跑完。“交换”是指超出已安装的内存，本来一小时的渲染会拖得久很多。可用比例取自 Metal 对该机器的报告——大约是安装容量的四分之三到六分之五，容量越大比例越高。",
    "de": "Die Gewichte sind nur ein Teil: Das Erzeugen braucht zusätzlich "
          "Arbeitsspeicher, und ein gemessener Render erreichte in der Spitze etwa "
          "das 2,4-Fache seines Gewichtswerts. Die Urteile berücksichtigen "
          "das. „Knapp“ heißt, die Spitze übersteigt den nutzbaren Anteil, passt "
          "aber noch in den verbauten Speicher: macOS lagert einen Teil aus und der "
          "Render läuft dennoch durch — gemessen brauchte eine Spitze von 120 GB auf "
          "einem Mac mit 128 GB 16 GB Swap und wurde fertig. „Swap“ heißt, es "
          "übersteigt den verbauten Speicher, und ein Render von einer Stunde dauert "
          "dann weit länger. Der nutzbare Anteil ist der, den Metal für die Maschine "
          "meldet — etwa drei Viertel bis fünf Sechstel des Verbauten, bei größeren "
          "Konfigurationen mehr.",
    "ar": "الأوزان ليست كل الحكاية: التوليد يحتاج ذاكرة عمل إضافية، وقد بلغ أحد "
          "عمليات التصيير المقيسة نحو 2.4 مرة رقم أوزانه في الذروة، والأحكام "
          "تأخذ ذلك في الحساب. \u201cمحدود\u201d يعني أن الذروة تتجاوز الحصة "
          "المتاحة لكنها تبقى داخل الذاكرة المثبَّتة، فيُرحِّل macOS جزءًا منها "
          "ويكتمل التصيير رغم ذلك — بالقياس، ذروة 120 غيغابايت على جهاز بـ 128 "
          "غيغابايت استهلكت 16 غيغابايت من التبديل وأُنجزت. و\u201cتبديل\u201d "
          "يعني أنها تتجاوز الذاكرة المثبَّتة، فيستغرق تصيير مدته ساعة وقتًا أطول "
          "بكثير. أما الحصة المتاحة فهي ما يبلّغ عنه Metal لهذا الجهاز — نحو ثلاثة "
          "أرباع إلى خمسة أسداس المثبَّت، وترتفع في التكوينات الأكبر.",
    "ja": "重みは一部にすぎません。生成にはさらに作業用メモリが必要で、実測したレンダリングのピークは重みの約 2.4 倍でした。判定はそれを見込んでいます。「ぎりぎり」はピークが使える割当てを超えるものの搭載メモリには収まる状態で、macOS が一部を退避させながらもレンダリングは完走します——実測では 128 GB の Mac でピーク 120 GB、スワップ 16 GB を使って完了しました。「スワップ」は搭載メモリを超える状態で、一時間で済むレンダリングがはるかに長くかかります。使える割合は Metal がその機械について報告する値で、搭載量のおよそ四分の三から六分の五、容量が大きいほど高くなります。",
    "ko": "가중치는 일부일 뿐입니다. 생성에는 별도의 작업 메모리가 필요하고, 실측한 렌더링의 최대치는 가중치의 약 2.4배였습니다. 위 판정은 그것을 감안한 것입니다. ‘빡빡함’은 최대치가 사용 가능한 몫을 넘지만 설치된 메모리에는 들어가는 경우로, macOS가 일부를 내보내면서도 렌더링은 끝까지 진행됩니다 — 실측으로 128 GB Mac에서 최대 120 GB, 스왑 16 GB를 쓰고 완료했습니다. ‘스왑’은 설치된 메모리를 넘는 경우이며, 한 시간이면 될 렌더링이 훨씬 오래 걸립니다. 사용 가능한 비율은 Metal이 해당 기기에 대해 보고하는 값으로, 설치된 용량의 약 4분의 3에서 6분의 5이며 용량이 클수록 높아집니다.",
    "th": "ไฟล์น้ำหนักเป็นเพียงส่วนหนึ่ง การสร้างต้องใช้หน่วยความจำทำงานเพิ่มอีก "
          "และการเรนเดอร์ที่วัดได้ขึ้นสูงสุดราว 2.4 เท่าของตัวเลขน้ำหนัก ผลสรุปคิดเผื่อไว้แล้ว "
          "“คับ” หมายถึงจุดสูงสุดเกินสัดส่วนที่ใช้ได้ แต่ยังพอดีกับหน่วยความจำที่ติดตั้ง "
          "macOS จะย้ายบางส่วนออกไปและการเรนเดอร์ก็ยังเสร็จ — วัดได้ว่าจุดสูงสุด 120 GB "
          "บนเครื่อง 128 GB ใช้ swap ไป 16 GB และทำงานจบ ส่วน “สลับ” หมายถึงเกินหน่วยความจำที่ติดตั้ง "
          "งานที่ควรใช้หนึ่งชั่วโมงจะนานขึ้นอีกมาก สัดส่วนที่ใช้ได้คือค่าที่ Metal รายงานสำหรับเครื่องนั้น — "
          "ราวสามในสี่ถึงห้าในหกของที่ติดตั้ง และสูงขึ้นในรุ่นที่หน่วยความจำมากกว่า",
    "yue-Hant": "權重只係其中一part：生成嗰陣仲要額外嘅工作記憶體，實測一次算圖尖峰大概係權重數字嘅 2.4 倍，上面嘅判斷已經計咗呢樣。「緊」係話尖峰超出可用嘅份額，但仲裝得落已裝嘅記憶體，macOS 會換走一部分，算圖照樣做得完——實測喺 128 GB 機上面尖峰 120 GB，用咗 16 GB 置換空間，順利跑完。「置換」係話超出已裝嘅記憶體，本來一個鐘嘅算圖會拖好多。可用比例係 Metal 對部機嘅回報——大概係安裝容量嘅四分三到六分五，容量越大比例越高。",
    "en-SG": "Weights are only part of the story: generating needs working memory on "
             "top, and one measured render peaked at about 2.4 times its "
             "weight figure. The verdicts already count that in. \u201cTight\u201d "
             "means the peak goes past the usable share but still fits inside "
             "installed memory, so macOS pages some of it out and the render still "
             "finishes \u2014 measured, a 120 GB peak on a 128 GB Mac used 16 GB of "
             "swap and completed. \u201cSwaps\u201d means it goes past installed "
             "memory altogether, and a render that would take an hour takes very much "
             "longer. The usable share is whatever Metal reports for the machine "
             "\u2014 roughly three quarters to five sixths of what is installed, "
             "higher on the bigger configurations.",
}, note="Footnote under the table, and the only place the verdict words are "
        "explained. The 2.4x multiplier and the swap figure both come from one "
        "measured MLX render (50 GB of weights peaking at 120 GB on a 128 GB "
        "Mac), so it is a rule of thumb rather than a specification. Keep the "
        "quoted words identical to memory.verdict.tight and .swaps.")
add("memory.table.thisMac", {
    "en": "This Mac: %1$@ installed, %2$@ usable for a model.",
    "zh-Hant": "本機：已安裝 %1$@，可給模型使用 %2$@。",
    "zh-Hans": "本机：已安装 %1$@，可给模型使用 %2$@。",
    "de": "Dieser Mac: %1$@ verbaut, %2$@ für ein Modell nutzbar.",
    "ar": "هذا الـ Mac: %1$@ مثبَّتة، و%2$@ متاحة للنموذج.",
    "ja": "この Mac：搭載 %1$@、モデルに使えるのは %2$@。",
    "ko": "이 Mac: %1$@ 설치, 모델이 쓸 수 있는 양 %2$@.",
    "th": "Mac เครื่องนี้: ติดตั้ง %1$@ ใช้ได้สำหรับโมเดล %2$@",
    "yue-Hant": "本機：裝咗 %1$@，可以俾模型用 %2$@。",
    "en-SG": "This Mac: %1$@ installed, %2$@ usable for a model.",
}, note="Read from the machine rather than assumed: the second figure is what "
        "Metal reports as the recommended maximum working set.")

# ── Disk requirements table ──────────────────────────────────────────────────
add("settings.disk", {
    "en": "Disk space", "zh-Hant": "磁碟空間", "zh-Hans": "磁盘空间",
    "de": "Speicherplatz", "ar": "مساحة القرص", "ja": "ディスク容量",
    "ko": "디스크 공간", "th": "พื้นที่ดิสก์", "yue-Hant": "磁碟空間",
    "en-SG": "Disk space",
})
add("disk.table.installedMemory", {
    "en": "Installed memory", "zh-Hant": "已安裝記憶體", "zh-Hans": "已安装内存",
    "de": "Verbauter Speicher", "ar": "الذاكرة المثبَّتة", "ja": "搭載メモリ",
    "ko": "설치된 메모리", "th": "หน่วยความจำที่ติดตั้ง", "yue-Hant": "裝咗嘅記憶體",
    "en-SG": "Installed memory",
})
add("disk.table.base", {
    "en": "Weights and runtime", "zh-Hant": "權重與執行環境", "zh-Hans": "权重与运行环境",
    "de": "Gewichte und Laufzeit", "ar": "الأوزان وبيئة التشغيل",
    "ja": "重みと実行環境", "ko": "가중치와 런타임", "th": "ไฟล์น้ำหนักและรันไทม์",
    "yue-Hant": "權重同執行環境", "en-SG": "Weights and runtime",
})
add("disk.table.swap", {
    "en": "Swap it will need", "zh-Hant": "所需置換空間", "zh-Hans": "所需置换空间",
    "de": "Benötigter Swap", "ar": "مساحة التبديل اللازمة",
    "ja": "必要なスワップ", "ko": "필요한 스왑", "th": "พื้นที่สลับที่ต้องใช้",
    "yue-Hant": "要用嘅置換空間", "en-SG": "Swap it will need",
}, note="Estimated, not fixed: macOS grows swap on demand, and how much it "
        "needs depends on how far a render overruns the memory the GPU may hold.")
add("disk.table.total", {
    "en": "Keep free", "zh-Hant": "建議預留", "zh-Hans": "建议预留",
    "de": "Freihalten", "ar": "احتفظ بمساحة فارغة", "ja": "空けておく容量",
    "ko": "비워 둘 용량", "th": "ควรเหลือว่างไว้", "yue-Hant": "建議留返",
    "en-SG": "Keep free",
})
add("disk.table.note", {
    "en": "The weights are the whole of it: %@ for the smallest usable set — the "
          "shared VAEs, the text encoder and the 4-bit transformer — plus about "
          "600 MB of Python runtime. A render's own temporary files are a few "
          "megabytes, because frames are piped straight to the encoder and never "
          "written out. Setup transiently needs 3.4 GB more for uv's download "
          "cache, which the Cache tab can empty afterwards. Reference mode needs "
          "a second set of weights, about 60 GB, and is not counted here.",
    "zh-Hant": "空間幾乎全用在權重上：最小可用組合約 %@——共用 VAE、文字編碼器與 4-bit transformer——再加上約 600 MB 的 Python 執行環境。算圖本身的暫存檔只有幾 MB，因為影格是直接餵給編碼器，不會寫到磁碟。初次設定期間還會多用 3.4 GB 作為 uv 的下載快取，之後可在「快取」分頁清除。參考素材模式需要另一整套權重，約 60 GB，未計入此表。",
    "zh-Hans": "空间几乎全用在权重上：最小可用组合约 %@——共用 VAE、文本编码器与 4-bit transformer——再加上约 600 MB 的 Python 运行环境。渲染本身的暂存文件只有几 MB，因为帧是直接喂给编码器，不会写到磁盘。初次设置期间还会多用 3.4 GB 作为 uv 的下载缓存，之后可在“缓存”分页清除。参考素材模式需要另一整套权重，约 60 GB，未计入此表。",
    "de": "Die Gewichte sind fast alles: %@ für den kleinsten brauchbaren Satz — die "
          "gemeinsamen VAEs, der Textencoder und der 4-Bit-Transformer — plus etwa "
          "600 MB Python-Laufzeit. Die Zwischendateien eines Renders sind wenige "
          "Megabyte, denn die Bilder gehen direkt in den Encoder und werden nie "
          "geschrieben. Die Einrichtung braucht vorübergehend 3,4 GB mehr für uvs "
          "Download-Cache, den der Tab „Cache“ später leeren kann. Der "
          "Referenzmodus braucht einen zweiten Satz Gewichte, etwa 60 GB, hier "
          "nicht mitgezählt.",
    "ar": "الأوزان هي كل شيء تقريبًا: %@ لأصغر مجموعة صالحة — وحدات VAE المشتركة "
          "ومرمِّز النص والمحوّل بأربع بتات — إضافة إلى نحو 600 ميغابايت لبيئة Python. "
          "أما ملفات التصيير المؤقتة فبضعة ميغابايتات فقط، لأن الإطارات تُمرَّر إلى "
          "المرمِّز مباشرة ولا تُكتب أبدًا. ويحتاج الإعداد مؤقتًا إلى 3.4 غيغابايت "
          "إضافية لذاكرة تنزيلات uv، ويمكن لتبويب الذاكرة المؤقتة إفراغها بعدها. "
          "ويحتاج وضع المراجع مجموعة أوزان ثانية، نحو 60 غيغابايت، غير محسوبة هنا.",
    "ja": "容量のほとんどは重みです。最小構成で約 %@——共有 VAE、テキストエンコーダ、4-bit transformer——に Python 実行環境の約 600 MB を加えた程度です。レンダリング自体の一時ファイルは数 MB しかありません。フレームはそのままエンコーダへ渡され、ディスクには書かれないからです。初回セットアップ中は uv のダウンロードキャッシュに一時的にさらに 3.4 GB を使い、あとから「キャッシュ」タブで空にできます。参考素材モードには別の重み一式、約 60 GB が必要で、この表には含めていません。",
    "ko": "용량은 거의 전부 가중치입니다. 가장 작은 실용 구성이 약 %@ — 공용 VAE, 텍스트 인코더, 4비트 트랜스포머 — 에 Python 런타임 약 600 MB를 더한 정도입니다. 렌더링 자체의 임시 파일은 수 MB뿐인데, 프레임이 인코더로 바로 전달되고 디스크에 쓰이지 않기 때문입니다. 설치 중에는 uv 다운로드 캐시로 3.4 GB를 일시적으로 더 쓰며, 나중에 캐시 탭에서 비울 수 있습니다. 참조 모드에는 약 60 GB의 두 번째 가중치 모음이 필요하고, 이 표에는 넣지 않았습니다.",
    "th": "พื้นที่แทบทั้งหมดคือไฟล์น้ำหนัก: ราว %@ สำหรับชุดที่เล็กที่สุดที่ใช้งานได้ — VAE ที่ใช้ร่วมกัน "
          "ตัวเข้ารหัสข้อความ และ transformer แบบ 4 บิต — บวกรันไทม์ Python ราว 600 MB "
          "ไฟล์ชั่วคราวของการเรนเดอร์มีเพียงไม่กี่เมกะไบต์ เพราะเฟรมถูกส่งตรงไปยังตัวเข้ารหัสและไม่เคยเขียนลงดิสก์ "
          "ระหว่างการตั้งค่าจะใช้เพิ่มชั่วคราวอีก 3.4 GB สำหรับแคชดาวน์โหลดของ uv ซึ่งล้างได้ภายหลังจากแท็บแคช "
          "โหมดไฟล์อ้างอิงต้องใช้ไฟล์น้ำหนักอีกชุดราว 60 GB ซึ่งไม่ได้รวมไว้ที่นี่",
    "yue-Hant": "空間差不多全部用喺權重：最細嘅可用組合大概 %@——共用 VAE、文字編碼器同 4-bit transformer——再加大概 600 MB 嘅 Python 執行環境。算圖本身嘅暫存檔得幾 MB，因為影格係直接餵去編碼器，唔會寫落碟。初次設定期間仲會多用 3.4 GB 做 uv 嘅下載快取，之後喺「快取」嗰版清得。參考素材模式要另一整套權重，大概 60 GB，呢個表冇計。",
    "en-SG": "The weights are almost all of it: about %@ for the smallest usable set — "
             "the shared VAEs, the text encoder and the 4-bit transformer — plus about "
             "600 MB of Python runtime. A render's own temp files are only a few "
             "megabytes, because frames go straight into the encoder and never get "
             "written out. Setup needs 3.4 GB more for a while for uv's download "
             "cache, which the Cache tab can clear after. Reference mode needs a "
             "second set of weights, about 60 GB, not counted here.",
})
add("settings.requirements", {
    "en": "Requirements",
    "zh-Hant": "系統需求", "zh-Hans": "系统需求",
    "de": "Anforderungen", "ar": "المتطلبات", "ja": "動作要件",
    "ko": "요구 사항", "th": "ความต้องการของระบบ", "yue-Hant": "系統需求",
    "en-SG": "Requirements",
}, note="Heads the memory and disk tables together, in Settings and as the "
        "welcome dialog's second page. Both tables answer one question — will "
        "this machine run it — so they share a heading.")
