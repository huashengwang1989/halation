# -*- coding: utf-8 -*-
"""Source of truth for UI translations.

Keys are semantic, not English text, so a word can differ by context — a "Rate"
button and a rate measurement are not the same word in most languages.

Technical terms stay in English on purpose: model names, bfloat16, ComfyUI, MLX,
HEVC, LoRA, VAE, seed values. Translating them would make the app harder to use,
not easier, because that is how the surrounding ecosystem names them.

Run Scripts/build_strings.py to regenerate the .lproj files.
"""

T = {}

def add(key, en, zh_hant, zh_hans, de, ar, note=""):
    T[key] = {"en": en, "zh-Hant": zh_hant, "zh-Hans": zh_hans, "de": de, "ar": ar,
              "note": note}

# ── Navigation ───────────────────────────────────────────────────────────────
add("section.compose", "Compose", "編寫", "编写", "Erstellen", "إنشاء",
    "The screen where you write a prompt and set up a render.")
add("section.queue", "Queue", "佇列", "队列", "Warteschlange", "قائمة الانتظار")
add("section.library", "Library", "媒體庫", "媒体库", "Mediathek", "المكتبة",
    "Collection of finished videos — not a code library.")
add("section.models", "Models", "模型", "模型", "Modelle", "النماذج")

# ── Status bar ───────────────────────────────────────────────────────────────
add("status.ready", "Ready", "就緒", "就绪", "Bereit", "جاهز")
add("status.checking", "Checking…", "檢查中…", "检查中…", "Wird geprüft …", "جارٍ التحقق…")
add("status.runtime.incomplete", "Runtime incomplete", "執行環境不完整",
    "运行环境不完整", "Laufzeitumgebung unvollständig", "بيئة التشغيل غير مكتملة")
add("status.runtime.error", "Runtime error", "執行環境錯誤", "运行环境错误",
    "Laufzeitfehler", "خطأ في بيئة التشغيل")
add("status.runtime.missing", "Runtime not installed", "尚未安裝執行環境",
    "尚未安装运行环境", "Laufzeitumgebung nicht installiert", "بيئة التشغيل غير مثبتة")
add("status.queued.count", "%@ queued", "佇列中 %@", "队列中 %@",
    "%@ in Warteschlange", "%@ في قائمة الانتظار")
add("status.label", "Status", "狀態", "状态", "Status", "الحالة")
add("status.memory.help",
    "Resident memory of the render process, and its share of this Mac's %@",
    "算圖程序佔用的實體記憶體，以及在本機 %@ 中的佔比",
    "渲染进程占用的物理内存，以及在本机 %@ 中的占比",
    "Vom Renderprozess belegter Arbeitsspeicher und sein Anteil an den %@ dieses Mac",
    "الذاكرة المقيمة لعملية التصيير ونسبتها من ذاكرة هذا الـ Mac البالغة %@")

# ── Built-in presets ─────────────────────────────────────────────────────────
# Named for what they are for, not for a setting: "Fast preview" is a draft you
# look at, not a speed. Translations follow the purpose rather than the words.
add("preset.fastPreview", "Fast preview", "快速預覽", "快速预览",
    "Schnelle Vorschau", "معاينة سريعة")
add("preset.quality", "Quality — overnight", "高品質——整夜算圖", "高质量——整夜渲染",
    "Hohe Qualität – über Nacht", "جودة عالية — طوال الليل")
add("preset.vertical", "Vertical social", "直式社群影片", "竖屏社交视频",
    "Hochformat für Social Media", "فيديو رأسي للتواصل الاجتماعي")

# ── Settings: language ───────────────────────────────────────────────────────
# The English name rides along in every language. Someone who switches to a
# script they cannot read has to be able to find their way back, and "Language"
# is the one label that has to stay recognisable for that to work.
add("settings.language.section", "Language", "語言 (Language)", "语言 (Language)",
    "Sprache (Language)", 'اللغة \u2068(Language)\u2069')
add("settings.language.label", "Interface language",
    "介面語言 (Interface Language)", "界面语言 (Interface Language)",
    "Sprache der Benutzeroberfläche (Interface Language)",
    'لغة الواجهة \u2068(Interface Language)\u2069')
add("settings.language.system", "Follow system (%@)", "跟隨系統（%@）",
    "跟随系统（%@）", "Systemsprache (%@)", "اتّباع النظام (%@)")

# Two notes, chosen by whether the writing direction actually changes. Telling
# someone moving between two left-to-right languages about mirroring only
# invents a worry; most people have never needed the word.
add("settings.language.restart",
    "Text changes immediately. The menu bar at the top of the screen follows "
    "when you restart the app.",
    "文字會立即切換。畫面上方的選單列則需重新啟動 App 後才會跟著改變。",
    "文字会立即切换。屏幕顶部的菜单栏需重新启动 App 后才会跟着改变。",
    "Texte wechseln sofort. Die Menüleiste am oberen Bildschirmrand folgt, "
    "sobald Sie die App neu starten.",
    "تتغيّر النصوص فورًا. أمّا شريط القوائم أعلى الشاشة فيتبعها عند إعادة تشغيل "
    "التطبيق.")
add("settings.language.restart.direction",
    "Text changes immediately. This language reads in the other direction, so "
    "the window swaps sides to match — that, and the menu bar at the top of the "
    "screen, follow when you restart the app.",
    "文字會立即切換。此語言的閱讀方向相反，因此整個視窗的左右會對調——這項變更與畫面"
    "上方的選單列，都需重新啟動 App 後才會套用。",
    "文字会立即切换。此语言的阅读方向相反，因此整个窗口的左右会对调——这项变更与屏幕"
    "顶部的菜单栏，都需重新启动 App 后才会生效。",
    "Texte wechseln sofort. Diese Sprache wird in der anderen Richtung gelesen, "
    "daher tauscht das Fenster die Seiten. Das und die Menüleiste am oberen "
    "Bildschirmrand folgen, sobald Sie die App neu starten.",
    "تتغيّر النصوص فورًا. تُقرأ هذه اللغة في الاتجاه المعاكس، لذا تتبادل عناصر "
    "النافذة جانبيها. يحدث ذلك، مع شريط القوائم أعلى الشاشة، عند إعادة تشغيل "
    "التطبيق.")
add("settings.language.relaunch", "Relaunch now", "立即重新啟動", "立即重新启动",
    "Jetzt neu starten", "أعِد التشغيل الآن")

# ── Generation modes ─────────────────────────────────────────────────────────
# TW and CN diverge on core vocabulary: 影片/视频 for video, 影格/帧 for frame,
# 解析度/分辨率 for resolution, 預設/默认 for default. Applied throughout.
add("mode.t2v", "Text to video", "文字轉影片", "文字转视频", "Text zu Video",
    "نص إلى فيديو")
add("mode.first", "First frame", "首格", "首帧", "Erstes Bild", "الإطار الأول",
    "The opening frame of the clip.")
add("mode.firstlast", "First & last frame", "首尾格", "首尾帧",
    "Erstes & letztes Bild", "الإطار الأول والأخير")
add("mode.reference", "References", "參考素材", "参考素材", "Referenzen", "مراجع",
    "Reference images/videos/audio that define subject or style.")
add("mode.t2v.detail", "Generate purely from a written description.",
    "僅依文字描述生成。", "仅依文字描述生成。",
    "Ausschließlich aus einer Beschreibung erzeugen.", "التوليد من وصف نصي فقط.")
add("mode.first.detail", "Animate outward from a still image you supply.",
    "以你提供的靜態圖片為起點延伸動態。", "以你提供的静态图片为起点延伸动态。",
    "Ausgehend von einem Standbild animieren.",
    "تحريك انطلاقًا من صورة ثابتة تقدّمها.")
add("mode.firstlast.detail",
    "Supply both ends of the shot; the model fills in the motion between them.",
    "提供鏡頭的起點與終點，模型補出中間的動態。",
    "提供镜头的起点与终点，模型补出中间的动态。",
    "Beide Enden der Einstellung vorgeben; das Modell erzeugt die Bewegung dazwischen.",
    "قدّم بداية اللقطة ونهايتها، ويولّد النموذج الحركة بينهما.")
add("mode.reference.detail",
    "Supply reference images, clips or audio to pin down a subject, style or voice.",
    "提供參考圖片、片段或音訊，用來固定主體、風格或聲音。",
    "提供参考图片、片段或音频，用来固定主体、风格或声音。",
    "Referenzbilder, -clips oder -audio vorgeben, um Motiv, Stil oder Stimme festzulegen.",
    "قدّم صورًا أو مقاطع أو أصواتًا مرجعية لتثبيت الموضوع أو الأسلوب أو الصوت.")

# ── Job states ───────────────────────────────────────────────────────────────
add("state.queued", "Queued", "等待中", "等待中", "In Warteschlange", "في الانتظار")
add("state.preparing", "Loading model", "載入模型中", "加载模型中",
    "Modell wird geladen", "جارٍ تحميل النموذج")
add("state.generating", "Generating", "生成中", "生成中", "Wird erzeugt", "جارٍ التوليد")
add("state.decoding", "Decoding", "解碼中", "解码中", "Wird dekodiert", "جارٍ فك الترميز")
add("state.encoding", "Encoding", "編碼中", "编码中", "Wird kodiert", "جارٍ الترميز")
add("state.finished", "Finished", "已完成", "已完成", "Fertig", "اكتمل")
add("state.failed", "Failed", "失敗", "失败", "Fehlgeschlagen", "فشل")
add("state.cancelled", "Cancelled", "已取消", "已取消", "Abgebrochen", "أُلغي")

# ── Engines ──────────────────────────────────────────────────────────────────
# "MLX" and "ComfyUI" are product names and stay as they are.
add("backend.mlx.detail",
    "Apple's own framework, running the model natively. Text-to-video and "
    "keyframes only — the port has no reference conditioning.",
    "Apple 自家的框架，原生執行模型。僅支援文字轉影片與關鍵格，移植版沒有參考素材條件化。",
    "Apple 自家的框架，原生运行模型。仅支持文字转视频与关键帧，移植版没有参考素材条件化。",
    "Apples eigenes Framework, das Modell läuft nativ. Nur Text-zu-Video und "
    "Keyframes — die Portierung kennt keine Referenzkonditionierung.",
    "إطار عمل Apple، يشغّل النموذج أصليًا. يدعم النص إلى فيديو والإطارات المفتاحية "
    "فقط، إذ لا يتضمّن النقل شرطنة المراجع.")
add("backend.comfy.detail",
    "PyTorch on Metal. The only backend that supports references, and the only "
    "one that can load the 4-step turbo LoRAs.",
    "以 Metal 執行 PyTorch。唯一支援參考素材的後端，也是唯一能載入 4 步 turbo LoRA 的。",
    "以 Metal 运行 PyTorch。唯一支持参考素材的后端，也是唯一能加载 4 步 turbo LoRA 的。",
    "PyTorch auf Metal. Das einzige Backend mit Referenzen und das einzige, das "
    "die 4-Schritt-Turbo-LoRAs laden kann.",
    "PyTorch على Metal. الواجهة الخلفية الوحيدة التي تدعم المراجع، والوحيدة "
    "القادرة على تحميل نماذج turbo LoRA ذات الأربع خطوات.")

# ── Compose: buttons and chrome ──────────────────────────────────────────────
add("compose.generate", "Generate", "生成", "生成", "Erzeugen", "توليد",
    "Button that queues a render — the verb, not a noun.")
add("compose.generate.help.ready", "Add this render to the queue",
    "將這次算圖加入佇列", "将这次渲染加入队列",
    "Diesen Render der Warteschlange hinzufügen", "أضف هذا التصيير إلى قائمة الانتظار")
add("compose.generate.why", "Why is this disabled?", "為什麼無法使用？",
    "为什么无法使用？", "Warum ist das deaktiviert?", "لماذا هذا معطّل؟")
add("compose.generate.blocked.runtime",
    "The Python runtime is not ready. Open Settings › Runtime.",
    "Python 執行環境尚未就緒。請開啟「設定 › Runtime」。",
    "Python 运行环境尚未就绪。请打开“设置 › Runtime”。",
    "Die Python-Laufzeitumgebung ist nicht bereit. Öffne „Einstellungen › Runtime“.",
    "بيئة تشغيل Python غير جاهزة. افتح «الإعدادات › Runtime».")
add("compose.generate.blocked.generic",
    "Resolve the issues listed under “Before you generate”.",
    "請先處理「生成前請確認」列出的問題。", "请先处理“生成前请确认”列出的问题。",
    "Behebe die unter „Vor dem Erzeugen“ aufgeführten Punkte.",
    "عالِج المشكلات المذكورة تحت «قبل التوليد».")
add("compose.presets", "Presets", "預設組合", "预设组合", "Vorlagen", "إعدادات محفوظة",
    "Saved combinations of settings — not 'default' in the factory sense.")
add("compose.presets.help", "Apply a saved combination of settings",
    "套用已儲存的設定組合", "应用已保存的设置组合",
    "Eine gespeicherte Einstellungskombination anwenden",
    "تطبيق مجموعة إعدادات محفوظة")
add("compose.preset.delete", "Delete Custom Preset", "刪除自訂預設組合",
    "删除自定义预设组合", "Eigene Vorlage löschen", "حذف إعداد مخصّص")
add("compose.preset.save", "Save as Preset…", "另存為預設組合…", "另存为预设组合…",
    "Als Vorlage sichern …", "حفظ كإعداد محفوظ…")
add("compose.preset.save.title", "Save preset", "儲存預設組合", "保存预设组合",
    "Vorlage sichern", "حفظ الإعداد")
add("compose.preset.save.message",
    "Saves the current settings as a reusable recipe. The prompt, seed and "
    "attached files are not included.",
    "將目前設定存成可重複使用的配方。不包含提示詞、種子與附加檔案。",
    "将当前设置存为可重复使用的配方。不包含提示词、种子与附加文件。",
    "Sichert die aktuellen Einstellungen als wiederverwendbares Rezept. Prompt, "
    "Seed und angehängte Dateien sind nicht enthalten.",
    "يحفظ الإعدادات الحالية كوصفة قابلة لإعادة الاستخدام. لا يشمل الموجّه أو "
    "قيمة seed أو الملفات المرفقة.")
add("common.name", "Name", "名稱", "名称", "Name", "الاسم")
add("common.cancel", "Cancel", "取消", "取消", "Abbrechen", "إلغاء")
add("common.save", "Save", "儲存", "保存", "Sichern", "حفظ")
add("common.done", "Done", "完成", "完成", "Fertig", "تم")
add("common.delete", "Delete", "刪除", "删除", "Löschen", "حذف")
add("common.download", "Download", "下載", "下载", "Laden", "تنزيل")
add("common.reveal", "Reveal", "顯示", "显示", "Anzeigen", "إظهار",
    "Reveal in Finder.")
add("common.refresh", "Refresh", "重新整理", "刷新", "Aktualisieren", "تحديث")
add("common.copy", "Copy", "拷貝", "复制", "Kopieren", "نسخ",
    "macOS uses 拷貝 in Traditional Chinese, 复制 in Simplified.")

# ── Compose: prompt ──────────────────────────────────────────────────────────
add("compose.prompt.title", "Prompt", "提示詞", "提示词", "Prompt", "الموجّه")
add("compose.prompt.hint",
    "Describe the shot. Press Tab to move on, Option-Tab to insert a tab.",
    "描述這個鏡頭。按 Tab 跳到下一項，Option-Tab 插入定位字元。",
    "描述这个镜头。按 Tab 跳到下一项，Option-Tab 插入制表符。",
    "Beschreibe die Einstellung. Tab wechselt weiter, Wahl-Tab fügt einen "
    "Tabulator ein.",
    "صِف اللقطة. اضغط Tab للانتقال، وOption-Tab لإدراج علامة جدولة.")
add("compose.prompt.footnote",
    "H3 responds well to camera language — shot size, lens, movement, lighting — "
    "and to a described soundscape, since it generates audio in the same pass. "
    "There is no negative prompt: the released weights are CFG-distilled, so "
    "guidance controls would do nothing.",
    "H3 對鏡頭語言反應良好，例如景別、鏡頭、運動與打光；也能理解對聲音場景的描述，"
    "因為它在同一次運算中生成音訊。沒有負面提示詞：釋出的權重經過 CFG 蒸餾，"
    "引導強度的設定不會有任何作用。",
    "H3 对镜头语言反应良好，例如景别、镜头、运动与打光；也能理解对声音场景的描述，"
    "因为它在同一次运算中生成音频。没有负面提示词：发布的权重经过 CFG 蒸馏，"
    "引导强度的设置不会有任何作用。",
    "H3 reagiert gut auf Kamerasprache — Einstellungsgröße, Objektiv, Bewegung, "
    "Licht — und auf beschriebene Klangbilder, da Audio im selben Durchgang "
    "entsteht. Es gibt keinen Negativ-Prompt: die veröffentlichten Gewichte sind "
    "CFG-destilliert, Guidance-Regler hätten keine Wirkung.",
    "يستجيب H3 جيدًا للغة الكاميرا — حجم اللقطة والعدسة والحركة والإضاءة — وكذلك "
    "لوصف المشهد الصوتي، لأنه يولّد الصوت في المسار نفسه. لا يوجد موجّه سلبي: "
    "الأوزان المنشورة مقطّرة بأسلوب CFG، لذا لن يكون لعناصر التوجيه أي أثر.")

# ── Compose: mode card ───────────────────────────────────────────────────────
add("compose.mode.title", "Mode", "模式", "模式", "Modus", "الوضع")
add("compose.mode.task.fl2va", " Uses the FL2VA checkpoint.",
    "　使用 FL2VA 檢查點。", "　使用 FL2VA 检查点。",
    " Verwendet den FL2VA-Checkpoint.", " يستخدم نقطة التحقق FL2VA.")
add("compose.mode.task.ref2va", " Uses the Ref2VA checkpoint.",
    "　使用 Ref2VA 檢查點。", "　使用 Ref2VA 检查点。",
    " Verwendet den Ref2VA-Checkpoint.", " يستخدم نقطة التحقق Ref2VA.")
add("compose.engine.label", "Engine", "引擎", "引擎", "Engine", "المحرّك")
add("compose.engine.mlx.note",
    "Runs natively on MLX. No server, and the default. Its weights are "
    "undistilled, so low step counts are off-distribution — use the port's 16 "
    "steps or more for quality.",
    "以 MLX 原生執行，不需伺服器，也是預設選項。其權重未經蒸餾，步數太低會偏離"
    "訓練分布；要求品質請用移植版預設的 16 步以上。",
    "以 MLX 原生运行，不需服务器，也是默认选项。其权重未经蒸馏，步数太低会偏离"
    "训练分布；要求质量请用移植版默认的 16 步以上。",
    "Läuft nativ auf MLX. Kein Server, und die Voreinstellung. Die Gewichte sind "
    "nicht destilliert, niedrige Schrittzahlen liegen daher außerhalb der "
    "Verteilung — für Qualität die 16 Schritte der Portierung oder mehr.",
    "يعمل أصليًا على MLX. بلا خادم، وهو الخيار الافتراضي. أوزانه غير مقطّرة، لذا "
    "فإن أعداد الخطوات المنخفضة تخرج عن التوزيع — استخدم 16 خطوة أو أكثر للجودة.")
add("compose.engine.comfy.note",
    "Runs through ComfyUI on PyTorch/Metal, which can load the 4-step turbo LoRA. "
    "Four distilled steps take about as long as five undistilled ones on MLX, and "
    "are what the LoRA was trained for.",
    "透過 ComfyUI 以 PyTorch/Metal 執行，可載入 4 步 turbo LoRA。四個蒸餾步驟"
    "所需時間與 MLX 上五個未蒸餾步驟相當，而這正是該 LoRA 訓練的目標。",
    "通过 ComfyUI 以 PyTorch/Metal 运行，可加载 4 步 turbo LoRA。四个蒸馏步骤"
    "所需时间与 MLX 上五个未蒸馏步骤相当，而这正是该 LoRA 训练的目标。",
    "Läuft über ComfyUI auf PyTorch/Metal und kann die 4-Schritt-Turbo-LoRA "
    "laden. Vier destillierte Schritte dauern etwa so lange wie fünf "
    "undestillierte auf MLX — und genau dafür wurde die LoRA trainiert.",
    "يعمل عبر ComfyUI على PyTorch/Metal، ويستطيع تحميل turbo LoRA ذات الأربع "
    "خطوات. أربع خطوات مقطّرة تستغرق زمنًا قريبًا من خمس خطوات غير مقطّرة على "
    "MLX، وهي ما دُرّبت عليه الـ LoRA.")

# ── Output format vocabulary ─────────────────────────────────────────────────
add("format.res.native", "768p — native", "768p — 原生", "768p — 原生",
    "768p — nativ", "‏768p — أصلي")
add("format.res.1080", "1080p — upscaled", "1080p — 放大", "1080p — 放大",
    "1080p — hochskaliert", "‏1080p — مُكبَّر")
add("format.res.1440", "1440p — upscaled", "1440p — 放大", "1440p — 放大",
    "1440p — hochskaliert", "‏1440p — مُكبَّر")
add("format.res.native.detail",
    "Exactly what the model produces, with no resampling. Recommended.",
    "模型的原始輸出，不做重新取樣。建議使用。",
    "模型的原始输出，不做重新采样。建议使用。",
    "Genau das, was das Modell erzeugt, ohne Resampling. Empfohlen.",
    "ما ينتجه النموذج تمامًا، دون إعادة أخذ عيّنات. موصى به.")
add("format.res.1080.detail",
    "Resampled after generation to fit a 1080p delivery pipeline. No detail is added.",
    "生成後重新取樣以符合 1080p 交付流程，不會增加細節。",
    "生成后重新采样以符合 1080p 交付流程，不会增加细节。",
    "Nach der Erzeugung auf eine 1080p-Auslieferung resampelt. Es kommen keine "
    "Details hinzu.",
    "يُعاد أخذ العيّنات بعد التوليد ليلائم مسار تسليم 1080p. لا تُضاف أي تفاصيل.")
add("format.res.1440.detail",
    "Resampled to 1440p. Larger files for the same real detail; useful only if a "
    "downstream tool demands this size.",
    "重新取樣為 1440p。檔案更大但實際細節不變；只有下游工具要求此尺寸時才有意義。",
    "重新采样为 1440p。文件更大但实际细节不变；只有下游工具要求此尺寸时才有意义。",
    "Auf 1440p resampelt. Größere Dateien bei gleichem echten Detail; nur "
    "sinnvoll, wenn ein nachgelagertes Werkzeug diese Größe verlangt.",
    "يُعاد أخذ العيّنات إلى 1440p. ملفات أكبر بالتفاصيل الحقيقية نفسها؛ مفيد فقط "
    "إذا طلبت أداة لاحقة هذا الحجم.")
add("format.fps.native", "24 fps — native", "24 fps — 原生", "24 fps — 原生",
    "24 fps — nativ", "‏24 fps — أصلي")
add("format.fps.conformed", "%@ fps — conformed", "%@ fps — 轉換", "%@ fps — 转换",
    "%@ fps — angepasst", "‏%@ fps — مُوائَم")
add("format.fps.native.detail",
    "The model's own cadence. No frames are invented or dropped.",
    "模型本身的節奏，不會憑空產生或丟棄影格。",
    "模型本身的节奏，不会凭空产生或丢弃帧。",
    "Die eigene Kadenz des Modells. Es werden keine Bilder erfunden oder verworfen.",
    "إيقاع النموذج نفسه. لا تُختلق إطارات ولا تُحذف.")
add("format.fps.30.detail",
    "Frames are duplicated to a 30 fps timeline. Motion may judder slightly.",
    "影格會複製到 30 fps 時間軸，動態可能略為頓挫。",
    "帧会复制到 30 fps 时间轴，动态可能略为顿挫。",
    "Bilder werden auf eine 30-fps-Zeitleiste dupliziert. Die Bewegung kann leicht ruckeln.",
    "تُكرَّر الإطارات على خط زمني بمعدل 30 fps. قد تبدو الحركة متقطّعة قليلًا.")
add("format.fps.60.detail",
    "Frames are duplicated to a 60 fps timeline. No new motion is synthesised.",
    "影格會複製到 60 fps 時間軸，不會合成新的動態。",
    "帧会复制到 60 fps 时间轴，不会合成新的动态。",
    "Bilder werden auf eine 60-fps-Zeitleiste dupliziert. Es wird keine neue "
    "Bewegung erzeugt.",
    "تُكرَّر الإطارات على خط زمني بمعدل 60 fps. لا تُصطنَع حركة جديدة.")
add("format.codec.h264.detail",
    "What the model produces. Delivered as rendered, with no second encode, and "
    "plays everywhere.",
    "模型的原生輸出。依算圖結果直接交付，不做二次編碼，相容性最廣。",
    "模型的原生输出。依渲染结果直接交付，不做二次编码，兼容性最广。",
    "Was das Modell erzeugt. Wird unverändert ausgeliefert, ohne zweite Kodierung, "
    "und läuft überall.",
    "ما ينتجه النموذج. يُسلَّم كما صُيِّر، دون ترميز ثانٍ، ويعمل في كل مكان.")
add("format.codec.av1.detail",
    "About half the size for the same quality. Encoded in software, since Apple "
    "silicon has no AV1 encoder — but SVT-AV1 handles a five-second clip in a "
    "second or two, so the cost is negligible next to generation.",
    "同等品質下檔案約為一半大小。因為 Apple 晶片沒有 AV1 編碼器，改以軟體編碼；"
    "但 SVT-AV1 處理五秒片段只要一兩秒，相較生成時間可以忽略。",
    "同等质量下文件约为一半大小。因为 Apple 芯片没有 AV1 编码器，改以软件编码；"
    "但 SVT-AV1 处理五秒片段只要一两秒，相较生成时间可以忽略。",
    "Etwa halb so groß bei gleicher Qualität. Wird in Software kodiert, da Apple "
    "Silicon keinen AV1-Encoder hat — SVT-AV1 schafft einen Fünf-Sekunden-Clip "
    "aber in ein bis zwei Sekunden, gegenüber der Erzeugung also vernachlässigbar.",
    "نحو نصف الحجم بالجودة نفسها. يُرمَّز برمجيًا لأن معالجات Apple لا تتضمّن "
    "مرمِّز AV1 — غير أن SVT-AV1 ينهي مقطعًا من خمس ثوانٍ في ثانية أو اثنتين، "
    "وهو زمن ضئيل مقارنةً بالتوليد.")
add("format.audio.muxed", "Muxed into the video", "混流至影片中", "混流至视频中",
    "In das Video gemuxt", "مدمج داخل الفيديو")
add("format.audio.wav", "Muxed, plus a separate WAV", "混流，並另存 WAV",
    "混流，并另存 WAV", "Gemuxt, plus separate WAV-Datei", "مدمج، مع ملف WAV منفصل")

# ── Compose: output card ─────────────────────────────────────────────────────
add("compose.output.title", "Output", "輸出", "输出", "Ausgabe", "الإخراج")
add("compose.output.footnote",
    "The model always renders 24 fps at a 768 px short edge. Anything else on "
    "this card is applied afterwards, during encoding.",
    "模型固定以 24 fps、短邊 768 px 算圖。此卡片上的其他設定都是事後在編碼階段套用。",
    "模型固定以 24 fps、短边 768 px 渲染。此卡片上的其他设置都是事后在编码阶段应用。",
    "Das Modell rendert immer 24 fps mit 768 px kurzer Kante. Alles andere auf "
    "dieser Karte wird erst beim Kodieren angewandt.",
    "يصيّر النموذج دائمًا بمعدل 24 fps وبحافة قصيرة قدرها 768 بكسل. وكل ما عدا "
    "ذلك في هذه البطاقة يُطبَّق لاحقًا أثناء الترميز.")
add("compose.aspect", "Aspect ratio", "長寬比", "宽高比", "Seitenverhältnis",
    "نسبة العرض إلى الارتفاع")
add("compose.aspect.help", "%1$@ — renders at %2$@", "%1$@ — 以 %2$@ 算圖",
    "%1$@ — 以 %2$@ 渲染", "%1$@ — rendert mit %2$@", "%1$@ — يُصيَّر بمقاس %2$@")
add("compose.aspect.accessibility", "%@ aspect ratio", "%@ 長寬比", "%@ 宽高比",
    "Seitenverhältnis %@", "نسبة عرض إلى ارتفاع %@")
add("compose.aspect.pixels", "%1$@ by %2$@ pixels", "%1$@ 乘 %2$@ 像素",
    "%1$@ 乘 %2$@ 像素", "%1$@ mal %2$@ Pixel", "%1$@ في %2$@ بكسل")
add("compose.resolution", "Resolution", "解析度", "分辨率", "Auflösung", "الدقة")
add("compose.framerate", "Frame rate", "影格率", "帧率", "Bildrate", "معدل الإطارات")
add("compose.codec", "Codec", "編碼格式", "编码格式", "Codec", "الترميز")
add("compose.audio", "Audio", "音訊", "音频", "Audio", "الصوت")
add("compose.audio.footnote",
    "H3 generates 32 kHz stereo audio in the same pass as the picture; there is "
    "no silent mode that renders faster.",
    "H3 會在生成畫面的同一次運算中產生 32 kHz 立體聲音訊；沒有更快的無聲模式。",
    "H3 会在生成画面的同一次运算中产生 32 kHz 立体声音频；没有更快的静音模式。",
    "H3 erzeugt 32-kHz-Stereo-Audio im selben Durchgang wie das Bild; einen "
    "schnelleren stummen Modus gibt es nicht.",
    "يولّد H3 صوتًا ستيريو بتردد 32 kHz في المسار نفسه الذي يولّد فيه الصورة؛ "
    "ولا يوجد وضع صامت أسرع.")

# ── Sampling card ────────────────────────────────────────────────────────────
add("sampling.title", "Sampling", "取樣", "采样", "Sampling", "المعاينة")
add("sampling.duration", "Duration", "長度", "时长", "Dauer", "المدة")
add("sampling.steps", "Steps", "步數", "步数", "Schritte", "الخطوات")
add("sampling.seed.fixed", "Fixed seed", "固定種子", "固定种子", "Fester Seed",
    "بذرة ثابتة", "'Seed' is kept in English; the qualifier is translated.")
add("sampling.seed.randomise", "Randomise", "隨機", "随机", "Zufällig", "عشوائي")
add("sampling.seed.note",
    "A fixed seed makes a render repeatable. Change any other setting and the "
    "result changes anyway.",
    "固定種子可讓算圖結果重現。但只要更動其他設定，結果仍然會變。",
    "固定种子可让渲染结果重现。但只要改动其他设置，结果仍然会变。",
    "Ein fester Seed macht einen Render wiederholbar. Ändert man eine andere "
    "Einstellung, ändert sich das Ergebnis trotzdem.",
    "تجعل البذرة الثابتة التصيير قابلًا للتكرار. لكن تغيير أي إعداد آخر يغيّر "
    "النتيجة على أي حال.")
add("sampling.snapped.exact", "Renders %1$@ frames — exactly %2$@ s at 24 fps.",
    "算出 %1$@ 格 — 在 24 fps 下正好 %2$@ 秒。",
    "渲染 %1$@ 帧 — 在 24 fps 下正好 %2$@ 秒。",
    "Rendert %1$@ Bilder — exakt %2$@ s bei 24 fps.",
    "يُصيَّر %1$@ إطارًا — أي %2$@ ثانية بالضبط عند 24 fps.")
add("sampling.snapped.inexact",
    "Renders %1$@ frames — %2$@ s at 24 fps, the nearest length the video VAE can encode.",
    "算出 %1$@ 格 — 在 24 fps 下為 %2$@ 秒，是 video VAE 能編碼的最接近長度。",
    "渲染 %1$@ 帧 — 在 24 fps 下为 %2$@ 秒，是 video VAE 能编码的最接近长度。",
    "Rendert %1$@ Bilder — %2$@ s bei 24 fps, die nächstliegende Länge, die die "
    "Video-VAE kodieren kann.",
    "يُصيَّر %1$@ إطارًا — أي %2$@ ثانية عند 24 fps، وهي أقرب مدة يستطيع "
    "video VAE ترميزها.")

# ── Compose summary ──────────────────────────────────────────────────────────
add("summary.render", "This render", "本次算圖", "本次渲染", "Dieser Render",
    "هذا التصيير")
add("summary.task", "Task", "任務", "任务", "Aufgabe", "المهمة")
add("summary.generates", "Generates at", "生成解析度", "生成分辨率", "Erzeugt mit",
    "يُولَّد بمقاس")
add("summary.delivers", "Delivered at", "輸出解析度", "输出分辨率", "Ausgeliefert mit",
    "يُسلَّم بمقاس")
add("summary.length", "Length", "長度", "时长", "Länge", "الطول")
add("summary.length.value", "%1$@ frames · %2$@ s", "%1$@ 格 · %2$@ 秒",
    "%1$@ 帧 · %2$@ 秒", "%1$@ Bilder · %2$@ s", "%1$@ إطارًا · %2$@ ثانية")
add("summary.bitrate", "Target bitrate", "目標位元率", "目标码率", "Ziel-Bitrate",
    "معدل البت المستهدف")
add("summary.eta", "Estimated time", "預估時間", "预计时间", "Geschätzte Dauer",
    "الوقت المقدَّر")
add("summary.eta.noModel", "Select a model", "請選擇模型", "请选择模型",
    "Modell wählen", "اختر نموذجًا")
add("summary.problems", "Before you generate", "生成前請確認", "生成前请确认",
    "Vor dem Erzeugen", "قبل التوليد")
add("summary.models", "Models", "模型", "模型", "Modelle", "النماذج")
add("summary.transformer", "Transformer", "Transformer", "Transformer",
    "Transformer", "Transformer", "Architecture name; left in English.")
add("summary.textEncoder", "Text encoder", "文字編碼器", "文本编码器",
    "Text-Encoder", "مُرمِّز النص")
add("summary.notSelected", "Not selected", "未選擇", "未选择", "Nicht gewählt",
    "لم يُحدَّد")
add("summary.chooseInModels", "Choose in Models…", "在「模型」中選擇…",
    "在“模型”中选择…", "Unter „Modelle“ wählen …", "اختر من «النماذج»…")
add("summary.engineNotReady", "Engine not ready", "引擎尚未就緒", "引擎尚未就绪",
    "Engine nicht bereit", "المحرّك غير جاهز")

# ── Queue ────────────────────────────────────────────────────────────────────
add("queue.empty.title", "Nothing queued", "佇列是空的", "队列是空的",
    "Nichts in der Warteschlange", "لا شيء في قائمة الانتظار")
add("queue.empty.detail",
    "Renders you start from Compose appear here. They keep running while you "
    "work, and survive quitting the app.",
    "從「編寫」開始的算圖會出現在這裡。它們會在你工作時持續執行，即使結束 App 也不會中斷。",
    "从“编写”开始的渲染会出现在这里。它们会在你工作时持续运行，即使退出 App 也不会中断。",
    "Renders, die du unter „Erstellen“ startest, erscheinen hier. Sie laufen "
    "weiter, während du arbeitest, und überstehen das Beenden der App.",
    "تظهر هنا عمليات التصيير التي تبدأها من «إنشاء». تستمر أثناء عملك، وتبقى حتى "
    "بعد إغلاق التطبيق.")
add("queue.goCompose", "Go to Compose", "前往「編寫」", "前往“编写”",
    "Zu „Erstellen“", "الانتقال إلى «إنشاء»")
add("queue.clearFinished", "Clear Finished", "清除已完成", "清除已完成",
    "Fertige entfernen", "مسح المكتملة")
add("queue.clearFinished.help",
    "Remove finished, failed and cancelled renders from this list",
    "從清單移除已完成、失敗與已取消的算圖",
    "从列表移除已完成、失败与已取消的渲染",
    "Fertige, fehlgeschlagene und abgebrochene Renders aus dieser Liste entfernen",
    "إزالة عمليات التصيير المكتملة والفاشلة والملغاة من هذه القائمة")
add("queue.runtimeWarning",
    "The Python runtime is not ready, so queued renders cannot start.",
    "Python 執行環境尚未就緒，佇列中的算圖無法開始。",
    "Python 运行环境尚未就绪，队列中的渲染无法开始。",
    "Die Python-Laufzeitumgebung ist nicht bereit, daher können wartende Renders "
    "nicht starten.",
    "بيئة تشغيل Python غير جاهزة، لذا لا يمكن بدء عمليات التصيير المنتظرة.")
add("queue.openSettings", "Open Settings", "開啟設定", "打开设置",
    "Einstellungen öffnen", "فتح الإعدادات")
add("queue.hold", "Hold", "暫緩", "暂缓", "Zurückstellen", "تعليق",
    "Hold a queued job back so it is skipped, not cancel it.")
add("queue.release", "Release", "恢復", "恢复", "Freigeben", "استئناف")
add("queue.hold.help", "Hold this render back", "暫緩這次算圖", "暂缓这次渲染",
    "Diesen Render zurückstellen", "تعليق هذا التصيير")
add("queue.release.help", "Allow this render to start", "允許這次算圖開始",
    "允许这次渲染开始", "Diesen Render starten lassen", "السماح ببدء هذا التصيير")
add("queue.moveToFront", "Move to Front", "移到最前", "移到最前",
    "Nach vorne verschieben", "نقل إلى المقدمة")
add("queue.stop", "Stop", "停止", "停止", "Anhalten", "إيقاف")
add("queue.stop.help",
    "Stop this render. Progress is lost — a render cannot be resumed.",
    "停止這次算圖。進度會遺失，算圖無法續算。",
    "停止这次渲染。进度会丢失，渲染无法续算。",
    "Diesen Render anhalten. Der Fortschritt geht verloren — ein Render lässt "
    "sich nicht fortsetzen.",
    "إيقاف هذا التصيير. سيضيع التقدّم، إذ لا يمكن استئناف التصيير.")
add("queue.renderAgain", "Render Again", "重新算圖", "重新渲染", "Erneut rendern",
    "إعادة التصيير")
add("queue.renderAgain.help", "Queue this again with a new seed",
    "以新的種子重新排入佇列", "以新的种子重新排入队列",
    "Erneut mit neuem Seed einreihen", "إعادة الإدراج ببذرة جديدة")
add("queue.reproduce", "Reproduce Exactly", "完全重現", "完全重现",
    "Exakt reproduzieren", "إعادة إنتاج مطابقة")
add("queue.editCopy", "Edit a Copy", "編輯副本", "编辑副本", "Kopie bearbeiten",
    "تحرير نسخة")
add("queue.showLog", "Show Log", "顯示記錄", "显示日志", "Protokoll anzeigen",
    "عرض السجل")
add("queue.log.help", "Show this render's log", "顯示這次算圖的記錄",
    "显示这次渲染的日志", "Protokoll dieses Renders anzeigen", "عرض سجل هذا التصيير")
add("queue.revealInFinder", "Reveal in Finder", "在 Finder 中顯示",
    "在 Finder 中显示", "Im Finder zeigen", "إظهار في Finder")
add("queue.remove", "Remove from Queue", "從佇列移除", "从队列移除",
    "Aus Warteschlange entfernen", "إزالة من قائمة الانتظار")
add("queue.held", "Held — will not start until released", "已暫緩，恢復後才會開始",
    "已暂缓，恢复后才会开始",
    "Zurückgestellt — startet erst nach Freigabe",
    "معلّق — لن يبدأ حتى يُستأنف")
add("queue.nextUp", "Next up", "下一個", "下一个", "Als Nächstes", "التالي")
add("queue.ahead", "Queued — %@ ahead", "等待中 — 前面還有 %@",
    "等待中 — 前面还有 %@", "In Warteschlange — %@ davor",
    "في الانتظار — %@ قبله")
add("queue.took", "Took %@", "耗時 %@", "耗时 %@", "Dauerte %@", "استغرق %@")
add("queue.step", "step %1$@ of %2$@", "第 %1$@ 步，共 %2$@ 步",
    "第 %1$@ 步，共 %2$@ 步", "Schritt %1$@ von %2$@", "الخطوة %1$@ من %2$@")
add("queue.perStep", "%@/step", "%@/步", "%@/步", "%@/Schritt", "%@/خطوة")
add("queue.peak", "%@ peak", "尖峰 %@", "峰值 %@", "%@ Spitze", "الذروة %@")
add("queue.remaining", "%@ remaining", "剩餘 %@", "剩余 %@", "noch %@", "يتبقى %@")
add("queue.remainingUnknown", "remaining unknown until generation starts",
    "開始生成前無法估算剩餘時間", "开始生成前无法估算剩余时间",
    "Restzeit erst ab Beginn der Erzeugung bekannt",
    "الوقت المتبقي غير معروف حتى يبدأ التوليد")
add("queue.log.title", "Render log", "算圖記錄", "渲染日志", "Render-Protokoll",
    "سجل التصيير")
add("queue.log.copyAll", "Copy All", "全部拷貝", "全部复制", "Alles kopieren",
    "نسخ الكل")
add("queue.log.empty.title", "No log yet", "尚無記錄", "尚无日志",
    "Noch kein Protokoll", "لا يوجد سجل بعد")
add("queue.log.empty.detail",
    "Output appears here once this render starts. Logs are kept for the current session.",
    "算圖開始後輸出會顯示在這裡。記錄只保留本次工作階段。",
    "渲染开始后输出会显示在这里。日志只保留本次会话。",
    "Sobald dieser Render startet, erscheint die Ausgabe hier. Protokolle gelten "
    "nur für die aktuelle Sitzung.",
    "يظهر الإخراج هنا فور بدء التصيير. تُحفظ السجلات للجلسة الحالية فقط.")

# ── Library ──────────────────────────────────────────────────────────────────
add("library.empty.title", "No videos yet", "還沒有影片", "还没有视频",
    "Noch keine Videos", "لا توجد مقاطع بعد")
add("library.empty.detail",
    "Finished renders are saved to %@, each with a JSON file recording the exact "
    "settings that produced it.",
    "完成的算圖會儲存到 %@，並各自附一個 JSON 檔記錄產生它的完整設定。",
    "完成的渲染会保存到 %@，并各自附一个 JSON 文件记录产生它的完整设置。",
    "Fertige Renders werden in %@ gesichert, jeweils mit einer JSON-Datei, die "
    "die genauen Einstellungen festhält.",
    "تُحفظ عمليات التصيير المكتملة في %@، مع ملف JSON لكل منها يسجّل الإعدادات "
    "التي أنتجته بالضبط.")
add("library.search", "Search prompts", "搜尋提示詞", "搜索提示词",
    "Prompts durchsuchen", "البحث في الموجّهات")
add("library.revealFolder", "Reveal Folder", "顯示資料夾", "显示文件夹",
    "Ordner anzeigen", "إظهار المجلد")
add("library.open", "Open", "打開", "打开", "Öffnen", "فتح")
add("library.useSettings", "Use These Settings", "沿用這些設定", "沿用这些设置",
    "Diese Einstellungen übernehmen", "استخدام هذه الإعدادات")
add("library.moveToTrash", "Move to Trash", "移到垃圾桶", "移到废纸篓",
    "In den Papierkorb legen", "نقل إلى المهملات",
    "macOS calls it 垃圾桶 in TW, 废纸篓 in CN.")
add("library.revealWav", "Reveal WAV", "顯示 WAV", "显示 WAV", "WAV anzeigen",
    "إظهار ملف WAV")
add("library.settings", "Settings", "設定", "设置", "Einstellungen", "الإعدادات")
add("library.duration", "Duration", "長度", "时长", "Dauer", "المدة")
add("library.seed", "Seed", "種子", "种子", "Seed", "البذرة")
add("library.filesize", "File size", "檔案大小", "文件大小", "Dateigröße",
    "حجم الملف")
add("library.renderTime", "Render time", "算圖時間", "渲染时间", "Renderdauer",
    "زمن التصيير")
add("library.mode", "Mode", "模式", "模式", "Modus", "الوضع")
add("library.missing", "This file is no longer on disk", "這個檔案已不在磁碟上",
    "这个文件已不在磁盘上", "Diese Datei ist nicht mehr auf dem Volume",
    "لم يعد هذا الملف موجودًا على القرص")
add("library.copySeed", "Copy %@", "拷貝%@", "复制%@", "%@ kopieren", "نسخ %@")
add("library.copied", "Copied", "已拷貝", "已复制", "Kopiert", "تم النسخ")
add("library.seconds", "%@ seconds", "%@ 秒", "%@ 秒", "%@ Sekunden", "%@ ثانية")

# ── Models ───────────────────────────────────────────────────────────────────
add("models.folder.title", "Shared models folder", "共用模型資料夾", "共享模型文件夹",
    "Gemeinsamer Modellordner", "مجلد النماذج المشترك")
add("models.folder.footnote",
    "Downloads go into the Hugging Face cache inside this folder. Any other "
    "project pointed at the same folder reuses them instead of downloading a "
    "second copy.",
    "下載內容會放進這個資料夾裡的 Hugging Face 快取。任何指向同一資料夾的其他專案"
    "都能直接重用，不必再下載一份。",
    "下载内容会放进这个文件夹里的 Hugging Face 缓存。任何指向同一文件夹的其他项目"
    "都能直接重用，不必再下载一份。",
    "Downloads landen im Hugging-Face-Cache in diesem Ordner. Jedes andere "
    "Projekt, das auf denselben Ordner zeigt, verwendet sie weiter, statt eine "
    "zweite Kopie zu laden.",
    "تُحفظ التنزيلات في ذاكرة Hugging Face المؤقتة داخل هذا المجلد. وأي مشروع آخر "
    "موجَّه إلى المجلد نفسه يعيد استخدامها بدل تنزيل نسخة ثانية.")
add("models.change", "Change…", "更改…", "更改…", "Ändern …", "تغيير…")
add("models.installed", "Installed", "已安裝", "已安装", "Installiert", "مثبَّت")
add("models.freeSpace", "Free space", "可用空間", "可用空间", "Freier Speicher",
    "المساحة الحرة")
add("models.found", "Models found", "找到的模型", "找到的模型", "Gefundene Modelle",
    "النماذج المعثور عليها")
add("models.spaceWarning",
    "The recommended set needs about %@, plus scratch space while rendering.",
    "建議的組合約需 %@，算圖時還需要額外的暫存空間。",
    "建议的组合约需 %@，渲染时还需要额外的暂存空间。",
    "Der empfohlene Satz benötigt etwa %@, zuzüglich Arbeitsspeicherplatz beim Rendern.",
    "تحتاج المجموعة الموصى بها نحو %@، إضافةً إلى مساحة مؤقتة أثناء التصيير.")
add("models.downloads", "Downloads", "下載", "下载", "Downloads", "التنزيلات")
add("models.downloads.footnote",
    "This list covers the current session. A finished download stays here until "
    "cleared; what is installed is shown against each model below.",
    "此清單只涵蓋本次工作階段。已完成的下載會留在這裡直到清除；實際安裝狀態顯示在"
    "下方各模型旁。",
    "此列表只涵盖本次会话。已完成的下载会留在这里直到清除；实际安装状态显示在"
    "下方各模型旁。",
    "Diese Liste gilt für die aktuelle Sitzung. Ein abgeschlossener Download "
    "bleibt hier, bis er entfernt wird; was installiert ist, steht unten bei "
    "jedem Modell.",
    "تغطي هذه القائمة الجلسة الحالية. يبقى التنزيل المكتمل هنا حتى يُمسح؛ أما ما "
    "هو مثبَّت فيظهر بجانب كل نموذج أدناه.")
add("models.cancelAll", "Cancel All", "全部取消", "全部取消", "Alle abbrechen",
    "إلغاء الكل")
add("models.clearFinished", "Clear Finished", "清除已完成", "清除已完成",
    "Fertige entfernen", "مسح المكتملة")
add("models.rescan", "Rescan", "重新掃描", "重新扫描", "Neu einlesen",
    "إعادة الفحص")
add("models.rescan.help", "Re-read the shared models folder", "重新讀取共用模型資料夾",
    "重新读取共享模型文件夹", "Den gemeinsamen Modellordner neu einlesen",
    "إعادة قراءة مجلد النماذج المشترك")
add("models.showIncompatible", "Show Incompatible", "顯示不相容項目", "显示不兼容项目",
    "Inkompatible anzeigen", "إظهار غير المتوافق")
add("models.showIncompatible.help",
    "Include checkpoints in formats this Mac cannot run",
    "一併顯示本機無法執行之格式的檢查點",
    "一并显示本机无法运行之格式的检查点",
    "Auch Checkpoints in Formaten zeigen, die dieser Mac nicht ausführen kann",
    "تضمين نقاط التحقق بصيغ لا يستطيع هذا الـ Mac تشغيلها")
add("models.installRecommended", "Install Recommended", "安裝建議組合", "安装建议组合",
    "Empfohlene installieren", "تثبيت الموصى به")
add("models.installRecommended.title", "Install the recommended models?",
    "要安裝建議的模型嗎？", "要安装建议的模型吗？",
    "Die empfohlenen Modelle installieren?", "هل تريد تثبيت النماذج الموصى بها؟")
add("models.willDownload", "Will download:", "即將下載：", "即将下载：",
    "Wird geladen:", "سيتم تنزيل:")
add("models.alreadyInstalled", "Already installed, and skipped:",
    "已安裝，將略過：", "已安装，将跳过：",
    "Bereits installiert, wird übersprungen:", "مثبَّت مسبقًا، وسيُتخطّى:")
add("models.savingTo", "Saving to %1$@, with %2$@ free.",
    "儲存至 %1$@，可用空間 %2$@。", "保存至 %1$@，可用空间 %2$@。",
    "Wird in %1$@ gesichert, %2$@ frei.", "سيُحفظ في %1$@، والمساحة الحرة %2$@.")
add("models.downloadAmount", "Download %@", "下載 %@", "下载 %@", "%@ laden",
    "تنزيل %@")
add("models.other.title", "Other models in this folder", "此資料夾中的其他模型",
    "此文件夹中的其他模型", "Weitere Modelle in diesem Ordner",
    "نماذج أخرى في هذا المجلد")
add("models.other.footnote",
    "These belong to other projects. This app leaves them alone.",
    "這些屬於其他專案，本 App 不會動它們。",
    "这些属于其他项目，本 App 不会动它们。",
    "Diese gehören zu anderen Projekten. Diese App rührt sie nicht an.",
    "هذه تخص مشاريع أخرى، ولا يمسّها هذا التطبيق.")
add("models.inUse", "In use", "使用中", "使用中", "In Verwendung", "قيد الاستخدام")
add("models.notRunnable", "Not runnable here", "此裝置無法執行", "此设备无法运行",
    "Hier nicht lauffähig", "غير قابل للتشغيل هنا")
add("models.use", "Use", "使用", "使用", "Verwenden", "استخدام")
add("models.selected", "Selected", "已選擇", "已选择", "Ausgewählt", "محدَّد")
add("models.use.help.download", "Download this first", "請先下載", "请先下载",
    "Zuerst laden", "نزّله أولًا")
add("models.use.help.inUse", "Already in use for the current render",
    "目前的算圖已在使用", "当前的渲染已在使用",
    "Wird für den aktuellen Render bereits verwendet",
    "مستخدَم بالفعل في التصيير الحالي")
add("models.use.help.select", "Use this for the current render", "用於目前的算圖",
    "用于当前的渲染", "Für den aktuellen Render verwenden",
    "استخدامه في التصيير الحالي")
add("models.delete.title", "Delete %@?", "要刪除%@嗎？", "要删除%@吗？",
    "%@ löschen?", "هل تريد حذف %@؟")
add("models.delete.message",
    "Frees about %1$@ from the shared models folder, which other projects on this "
    "Mac may also be using — anything relying on %2$@ would have to download it "
    "again. The files go to the Trash, so this can be undone until you empty it.",
    "可釋出約 %1$@ 的共用模型資料夾空間；本機其他專案可能也在使用，任何依賴 %2$@ "
    "的程式都得重新下載。檔案會移到垃圾桶，清空前都還能還原。",
    "可释出约 %1$@ 的共享模型文件夹空间；本机其他项目可能也在使用，任何依赖 %2$@ "
    "的程序都得重新下载。文件会移到废纸篓，清空前都还能还原。",
    "Gibt etwa %1$@ im gemeinsamen Modellordner frei, den andere Projekte auf "
    "diesem Mac ebenfalls nutzen könnten — alles, was auf %2$@ angewiesen ist, "
    "müsste es erneut laden. Die Dateien wandern in den Papierkorb und lassen "
    "sich bis zum Leeren wiederherstellen.",
    "يحرّر نحو %1$@ من مجلد النماذج المشترك، وقد تستخدمه مشاريع أخرى على هذا "
    "الـ Mac — وأي شيء يعتمد على %2$@ سيحتاج إلى تنزيله مجددًا. تنتقل الملفات إلى "
    "المهملات، فيمكن التراجع حتى تفريغها.")
add("models.delete.help.running", "Not while a render is running", "算圖進行中無法刪除",
    "渲染进行中无法删除", "Nicht während ein Render läuft",
    "غير ممكن أثناء تشغيل تصيير")
add("models.delete.help.inUse",
    "In use for the current render — choose another first",
    "目前的算圖正在使用，請先改選其他", "当前的渲染正在使用，请先改选其他",
    "Wird für den aktuellen Render verwendet — zuerst ein anderes wählen",
    "مستخدَم في التصيير الحالي — اختر غيره أولًا")
add("models.delete.help.ok", "Move this model to the Trash", "將此模型移到垃圾桶",
    "将此模型移到废纸篓", "Dieses Modell in den Papierkorb legen",
    "نقل هذا النموذج إلى المهملات")
add("models.delete.freed", "Moved %@ to the Trash.", "已將 %@ 移到垃圾桶。",
    "已将 %@ 移到废纸篓。", "%@ in den Papierkorb gelegt.",
    "نُقل %@ إلى المهملات.")
add("models.inMemory", "%@ in memory", "記憶體 %@", "内存 %@",
    "%@ im Arbeitsspeicher", "%@ في الذاكرة")
add("models.downloaded", "Downloaded", "已下載", "已下载", "Geladen", "تم التنزيل")
add("models.downloadFailed", "Download failed", "下載失敗", "下载失败",
    "Download fehlgeschlagen", "فشل التنزيل")
add("models.cancelDownload", "Cancel download of %@", "取消下載 %@", "取消下载 %@",
    "Download von %@ abbrechen", "إلغاء تنزيل %@")
add("models.progress", "Download progress", "下載進度", "下载进度",
    "Download-Fortschritt", "تقدّم التنزيل")
add("models.bytesOf", "%1$@ of %2$@", "%1$@ / %2$@", "%1$@ / %2$@",
    "%1$@ von %2$@", "%1$@ من %2$@")
add("models.notInstalled", "Not installed", "未安裝", "未安装",
    "Nicht installiert", "غير مثبَّت")

# ── Model roles and provenance ───────────────────────────────────────────────
add("role.transformer", "Diffusion transformer", "擴散 Transformer", "扩散 Transformer",
    "Diffusion-Transformer", "مُحوِّل الانتشار")
add("role.textEncoder", "Text encoder", "文字編碼器", "文本编码器", "Text-Encoder",
    "مُرمِّز النص")
add("role.support", "VAEs & processors", "VAE 與前處理器", "VAE 与预处理器",
    "VAEs & Prozessoren", "‏VAE والمعالِجات")
add("role.accelerator", "Acceleration LoRAs", "加速 LoRA", "加速 LoRA",
    "Beschleunigungs-LoRAs", "نماذج LoRA للتسريع")
add("provenance.official", "Official", "官方", "官方", "Offiziell", "رسمي")
add("provenance.port", "MLX port", "MLX 移植", "MLX 移植", "MLX-Portierung",
    "نقل MLX")
add("provenance.community", "Community", "社群", "社区", "Community", "المجتمع")
add("task.fl2va", "FL2VA — text & keyframes", "FL2VA — 文字與關鍵格",
    "FL2VA — 文字与关键帧", "FL2VA — Text & Keyframes",
    "‏FL2VA — نص وإطارات مفتاحية")
add("task.ref2va", "Ref2VA — references", "Ref2VA — 參考素材", "Ref2VA — 参考素材",
    "Ref2VA — Referenzen", "‏Ref2VA — مراجع")

# ── Onboarding ───────────────────────────────────────────────────────────────
add("onboarding.skip", "Skip setup", "略過設定", "跳过设置",
    "Einrichtung überspringen", "تخطّي الإعداد")
add("onboarding.back", "Back", "上一步", "上一步", "Zurück", "رجوع")
add("onboarding.continue", "Continue", "繼續", "继续", "Fortfahren", "متابعة")
add("onboarding.welcome.title", "Generate video on this Mac", "在這台 Mac 上生成影片",
    "在这台 Mac 上生成视频", "Video auf diesem Mac erzeugen",
    "توليد الفيديو على هذا الـ Mac")
add("onboarding.licence.title", "Model licence", "模型授權", "模型许可",
    "Modelllizenz", "ترخيص النموذج")
add("onboarding.runtime.title", "Python runtime", "Python 執行環境", "Python 运行环境",
    "Python-Laufzeitumgebung", "بيئة تشغيل Python")
add("onboarding.models.title", "Model weights", "模型權重", "模型权重",
    "Modellgewichte", "أوزان النموذج")
add("onboarding.installRuntime", "Install Runtime", "安裝執行環境", "安装运行环境",
    "Laufzeitumgebung installieren", "تثبيت بيئة التشغيل")
add("onboarding.installing", "Installing…", "安裝中…", "安装中…",
    "Wird installiert …", "جارٍ التثبيت…")
add("onboarding.startDownload", "Start Download", "開始下載", "开始下载",
    "Download starten", "بدء التنزيل")
add("onboarding.slowTitle", "Renders take hours, not seconds", "算圖需要數小時，而非數秒",
    "渲染需要数小时，而非数秒", "Renders dauern Stunden, nicht Sekunden",
    "يستغرق التصيير ساعات لا ثوانٍ")
add("onboarding.diskTitle", "Setup is a large download", "初始設定的下載量很大",
    "初始设置的下载量很大", "Die Einrichtung lädt viel herunter",
    "الإعداد يتطلّب تنزيلًا كبيرًا")
add("onboarding.licence.acknowledge",
    "I have read the licence and I am entitled to use these weights where I am",
    "我已閱讀授權條款，並確認在我所在地有權使用這些權重",
    "我已阅读许可条款，并确认在我所在地有权使用这些权重",
    "Ich habe die Lizenz gelesen und bin berechtigt, diese Gewichte hier zu verwenden",
    "لقد قرأت الترخيص وأنا مخوَّل باستخدام هذه الأوزان في موقعي")
add("onboarding.licence.readFull", "Read the full licence on Hugging Face",
    "在 Hugging Face 閱讀完整授權", "在 Hugging Face 阅读完整许可",
    "Vollständige Lizenz auf Hugging Face lesen",
    "اقرأ الترخيص كاملًا على Hugging Face")
add("onboarding.total", "Total", "總計", "总计", "Gesamt", "الإجمالي")
add("onboarding.freeOnDisk", "Free on disk", "磁碟可用空間", "磁盘可用空间",
    "Frei auf dem Volume", "المساحة الحرة على القرص")
add("onboarding.savingTo", "Saving to %@", "儲存至 %@", "保存至 %@",
    "Wird gesichert in %@", "سيُحفظ في %@")

# ── Sidebar / window chrome ──────────────────────────────────────────────────
add("sidebar.show", "Show Sidebar", "顯示側邊欄", "显示边栏", "Seitenleiste einblenden",
    "إظهار الشريط الجانبي")
add("sidebar.hide", "Hide Sidebar", "隱藏側邊欄", "隐藏边栏", "Seitenleiste ausblenden",
    "إخفاء الشريط الجانبي")
add("menu.newRender", "New Render", "新增算圖", "新建渲染", "Neuer Render",
    "تصيير جديد")
add("menu.rescanModels", "Rescan Models Folder", "重新掃描模型資料夾",
    "重新扫描模型文件夹", "Modellordner neu einlesen", "إعادة فحص مجلد النماذج")
add("menu.revealModels", "Reveal Models Folder in Finder", "在 Finder 中顯示模型資料夾",
    "在 Finder 中显示模型文件夹", "Modellordner im Finder zeigen",
    "إظهار مجلد النماذج في Finder")

# ── References card ──────────────────────────────────────────────────────────
add("refs.title.keyframes", "Keyframes", "關鍵格", "关键帧", "Keyframes",
    "الإطارات المفتاحية")
add("refs.title.references", "References", "參考素材", "参考素材", "Referenzen",
    "المراجع")
add("refs.addFiles", "Add Files…", "加入檔案…", "添加文件…", "Dateien hinzufügen …",
    "إضافة ملفات…")
add("refs.removeAll", "Remove All", "全部移除", "全部移除", "Alle entfernen",
    "إزالة الكل")
add("refs.drop", "Drop files here", "把檔案拖到這裡", "把文件拖到这里",
    "Dateien hierher ziehen", "أفلِت الملفات هنا")
add("refs.insertTag", "Insert Tag", "插入標記", "插入标记", "Tag einfügen",
    "إدراج وسم")
add("refs.insertTags", "Insert Tags", "插入標記", "插入标记", "Tags einfügen",
    "إدراج وسوم")
add("refs.insertTags.help", "Append %@ to the prompt", "將 %@ 附加到提示詞",
    "将 %@ 附加到提示词", "%@ an den Prompt anhängen", "إلحاق %@ بالموجّه")
add("refs.remove", "Remove %@", "移除 %@", "移除 %@", "%@ entfernen", "إزالة %@")
add("refs.choose.image", "Choose a keyframe image", "選擇關鍵格圖片",
    "选择关键帧图片", "Keyframe-Bild wählen", "اختر صورة إطار مفتاحي")
add("refs.choose.any", "Choose reference images, videos or audio",
    "選擇參考圖片、影片或音訊", "选择参考图片、视频或音频",
    "Referenzbilder, -videos oder -audio wählen",
    "اختر صورًا أو مقاطع فيديو أو صوتًا مرجعية")
add("refs.slot.first", "First frame", "首格", "首帧", "Erstes Bild", "الإطار الأول")
add("refs.slot.last", "Last frame", "末格", "末帧", "Letztes Bild", "الإطار الأخير")
add("refs.slot.reference", "Reference", "參考", "参考", "Referenz", "مرجع")
add("refs.kind.image", "Image", "圖片", "图片", "Bild", "صورة")
add("refs.kind.video", "Video", "影片", "视频", "Video", "فيديو")
add("refs.kind.audio", "Audio", "音訊", "音频", "Audio", "صوت")
add("refs.footnote.first",
    "One image, used as the opening frame. The clip animates outward from it.",
    "一張圖片，作為開場影格，片段會由此延伸動態。",
    "一张图片，作为开场帧，片段会由此延伸动态。",
    "Ein Bild als Anfangsbild. Der Clip animiert von dort aus.",
    "صورة واحدة تُستخدم كإطار افتتاحي، وينطلق منها تحريك المقطع.")
add("refs.footnote.firstlast",
    "Two images. The first becomes frame one, the second the final frame, and H3 "
    "generates the motion between them.",
    "兩張圖片：第一張為第一格，第二張為最後一格，H3 生成兩者之間的動態。",
    "两张图片：第一张为第一帧，第二张为最后一帧，H3 生成两者之间的动态。",
    "Zwei Bilder. Das erste wird Bild eins, das zweite das Schlussbild; H3 "
    "erzeugt die Bewegung dazwischen.",
    "صورتان: الأولى تصبح الإطار الأول والثانية الإطار الأخير، ويولّد H3 الحركة بينهما.")
add("refs.footnote.reference",
    "Up to 9 images, 3 videos and 3 audio clips, 12 files in total. Refer to them "
    "from the prompt as <Picture 1>, <Video 1>, <Audio 1> — H3 conditions on them "
    "through those tags, so an unmentioned reference has little effect.",
    "最多 9 張圖片、3 段影片與 3 段音訊，合計 12 個檔案。在提示詞中以 "
    "<Picture 1>、<Video 1>、<Audio 1> 指稱它們；H3 透過這些標記做條件化，"
    "沒有被提到的參考素材幾乎不起作用。",
    "最多 9 张图片、3 段视频与 3 段音频，合计 12 个文件。在提示词中以 "
    "<Picture 1>、<Video 1>、<Audio 1> 指称它们；H3 通过这些标记做条件化，"
    "没有被提到的参考素材几乎不起作用。",
    "Bis zu 9 Bilder, 3 Videos und 3 Audioclips, insgesamt 12 Dateien. Im Prompt "
    "als <Picture 1>, <Video 1>, <Audio 1> ansprechen — H3 konditioniert über "
    "diese Tags, eine nicht erwähnte Referenz wirkt kaum.",
    "حتى 9 صور و3 مقاطع فيديو و3 مقاطع صوتية، بمجموع 12 ملفًا. أشِر إليها في "
    "الموجّه بصيغة <Picture 1> و<Video 1> و<Audio 1> — إذ يشترط H3 عليها عبر هذه "
    "الوسوم، فالمرجع غير المذكور يكاد لا يؤثّر.")

# ── Validation messages ──────────────────────────────────────────────────────
add("problem.prompt.empty", "Write a prompt describing the shot.",
    "請寫一段描述鏡頭的提示詞。", "请写一段描述镜头的提示词。",
    "Schreibe einen Prompt, der die Einstellung beschreibt.",
    "اكتب موجّهًا يصف اللقطة.")
add("problem.duration", "H3 only generates 4–15 second clips.",
    "H3 只能生成 4–15 秒的片段。", "H3 只能生成 4–15 秒的片段。",
    "H3 erzeugt nur Clips von 4–15 Sekunden.",
    "يولّد H3 مقاطع مدتها 4–15 ثانية فقط.")
add("problem.t2v.extraFiles",
    "Text-to-video ignores attached files. Switch modes to use them.",
    "文字轉影片會忽略附加檔案。若要使用，請切換模式。",
    "文字转视频会忽略附加文件。若要使用，请切换模式。",
    "Text-zu-Video ignoriert angehängte Dateien. Wechsle den Modus, um sie zu nutzen.",
    "يتجاهل وضع النص إلى فيديو الملفات المرفقة. بدّل الوضع لاستخدامها.")
add("problem.needFirst", "Add a first-frame image.", "請加入首格圖片。",
    "请添加首帧图片。", "Füge ein Bild für das erste Bild hinzu.",
    "أضف صورة للإطار الأول.")
add("problem.needLast", "Add a last-frame image.", "請加入末格圖片。",
    "请添加末帧图片。", "Füge ein Bild für das letzte Bild hinzu.",
    "أضف صورة للإطار الأخير.")
add("problem.needReference", "Ref2VA needs at least one reference file.",
    "Ref2VA 至少需要一個參考檔案。", "Ref2VA 至少需要一个参考文件。",
    "Ref2VA benötigt mindestens eine Referenzdatei.",
    "يتطلّب Ref2VA ملف مرجع واحدًا على الأقل.")
add("problem.tooManyKind", "At most %1$@ reference %2$@ files — you have %3$@.",
    "參考%2$@最多 %1$@ 個，目前有 %3$@ 個。",
    "参考%2$@最多 %1$@ 个，当前有 %3$@ 个。",
    "Höchstens %1$@ Referenzdateien vom Typ %2$@ — du hast %3$@.",
    "بحد أقصى %1$@ من ملفات %2$@ المرجعية — لديك %3$@.")
add("problem.tooManyTotal", "Ref2VA accepts %@ reference files in total.",
    "Ref2VA 總共最多接受 %@ 個參考檔案。", "Ref2VA 总共最多接受 %@ 个参考文件。",
    "Ref2VA akzeptiert insgesamt %@ Referenzdateien.",
    "يقبل Ref2VA %@ ملف مرجع بالإجمال.")
add("problem.notInstalled", "The selected checkpoint isn't installed yet.",
    "所選的檢查點尚未安裝。", "所选的检查点尚未安装。",
    "Der gewählte Checkpoint ist noch nicht installiert.",
    "نقطة التحقق المحددة غير مثبتة بعد.")
add("problem.chooseCheckpoint", "Choose a %@ checkpoint in Models.",
    "請在「模型」中選擇 %@ 檢查點。", "请在“模型”中选择 %@ 检查点。",
    "Wähle unter „Modelle“ einen %@-Checkpoint.",
    "اختر نقطة تحقق %@ من «النماذج».")
add("problem.lowSteps",
    "Below 8 steps the model tends to produce soft, unstable motion.",
    "低於 8 步時，模型容易產生模糊、不穩定的動態。",
    "低于 8 步时，模型容易产生模糊、不稳定的动态。",
    "Unter 8 Schritten erzeugt das Modell eher weiche, instabile Bewegung.",
    "دون 8 خطوات يميل النموذج إلى حركة ناعمة غير مستقرة.")
add("problem.longOvernight",
    "Long clips at high step counts can run overnight. Consider a short test first.",
    "長片段搭配高步數可能需要整夜。建議先做一次短測試。",
    "长片段搭配高步数可能需要整夜。建议先做一次短测试。",
    "Lange Clips mit hoher Schrittzahl können über Nacht laufen. Erst einen "
    "kurzen Test erwägen.",
    "قد تستغرق المقاطع الطويلة بأعداد خطوات كبيرة ليلة كاملة. جرّب اختبارًا قصيرًا أولًا.")
add("problem.upscale",
    "%@ is a resample of the model's 768p output. H3's true 2K mode is not "
    "open-sourced and cannot run locally.",
    "%@ 只是模型 768p 輸出的重新取樣。H3 真正的 2K 模式未開源，無法在本機執行。",
    "%@ 只是模型 768p 输出的重新采样。H3 真正的 2K 模式未开源，无法在本机运行。",
    "%@ ist ein Resampling der 768p-Ausgabe des Modells. Der echte 2K-Modus von "
    "H3 ist nicht quelloffen und läuft nicht lokal.",
    "‏%@ مجرد إعادة أخذ عيّنات لإخراج النموذج بدقة 768p. أما وضع 2K الحقيقي في H3 "
    "فليس مفتوح المصدر ولا يمكن تشغيله محليًا.")
add("problem.refUntagged",
    "The prompt never mentions %@. H3 conditions on references through those "
    "tags — untagged ones have much less influence.",
    "提示詞中沒有提到 %@。H3 透過這些標記對參考素材做條件化，沒被標記的影響力小得多。",
    "提示词中没有提到 %@。H3 通过这些标记对参考素材做条件化，没被标记的影响力小得多。",
    "Der Prompt erwähnt %@ nie. H3 konditioniert Referenzen über diese Tags — "
    "ohne Tag ist der Einfluss deutlich geringer.",
    "لا يذكر الموجّه %@ إطلاقًا. يشترط H3 على المراجع عبر هذه الوسوم، وما لا "
    "يُذكر يكون تأثيره أضعف بكثير.")
add('problem.refSlow',
    'Reference mode runs through ComfyUI rather than MLX, which is slower per step. The 4-step turbo LoRA is what keeps it to minutes rather than hours.',
    '參考模式透過 ComfyUI 而非 MLX 執行，每步較慢。4 步 turbo LoRA 正是把時間控制在數分鐘而非數小時的關鍵。',
    '参考模式通过 ComfyUI 而非 MLX 运行，每步较慢。4 步 turbo LoRA 正是把时间控制在数分钟而非数小时的关键。',
    'Der Referenzmodus läuft über ComfyUI statt MLX und ist pro Schritt langsamer. Die 4-Schritt-Turbo-LoRA hält es bei Minuten statt Stunden.',
    'يعمل وضع المراجع عبر ComfyUI بدل MLX، وهو أبطأ لكل خطوة. ونموذج turbo LoRA ذو الأربع خطوات هو ما يبقي الزمن بالدقائق لا بالساعات.')
add("problem.blocking", "Blocking issue. %@", "阻擋問題：%@", "阻塞问题：%@",
    "Blockierendes Problem. %@", "مشكلة مانعة. %@")
add("problem.note", "Note. %@", "提醒：%@", "提醒：%@", "Hinweis. %@", "ملاحظة. %@")

# ── Settings ─────────────────────────────────────────────────────────────────
add("settings.general", "General", "一般", "通用", "Allgemein", "عام")
add("settings.runtime", "Runtime", "執行環境", "运行时",
    "Laufzeitumgebung", "بيئة التشغيل",
    "The Python environment the app manages, not a term of art: TW says 執行環境, "
    "mainland 运行时.")
add("settings.advanced", "Advanced", "進階", "高级", "Erweitert", "متقدّم")
add("settings.log.clear", "Clear", "清除", "清除", "Leeren", "مسح")
add("settings.log.accessibility", "Installation log", "安裝記錄", "安装日志",
    "Installationsprotokoll", "سجل التثبيت")
add("settings.runtime.rebuild.note",
    "Rebuilding deletes and recreates the Python environment. It does not touch "
    "downloaded weights.",
    "完全重建會刪除並重新建立 Python 執行環境，不會動到已下載的模型權重。",
    "完全重建会删除并重新创建 Python 运行时，不会影响已下载的模型权重。",
    "Beim vollständigen Neuaufbau wird die Python-Umgebung gelöscht und neu "
    "erstellt. Geladene Gewichte bleiben unberührt.",
    "تؤدي إعادة البناء إلى حذف بيئة Python وإنشائها من جديد. ولا تمسّ الأوزان "
    "التي جرى تنزيلها.")
add("settings.advanced.support.note",
    "Holds the Python environment, the render queue, and scratch files for "
    "in-flight renders.",
    "存放 Python 執行環境、算圖佇列，以及算圖進行中的暫存檔案。",
    "存放 Python 运行时、渲染队列，以及渲染进行中的临时文件。",
    "Enthält die Python-Umgebung, die Renderwarteschlange und temporäre Dateien "
    "laufender Rendervorgänge.",
    "يحتوي على بيئة Python وقائمة انتظار التصيير والملفات المؤقتة لعمليات "
    "التصيير الجارية.")
add("settings.folders", "Folders", "資料夾", "文件夹", "Ordner", "المجلدات")
add("settings.folder.models", "Models", "模型", "模型", "Modelle", "النماذج")
add("settings.folder.output", "Output", "輸出", "输出", "Ausgabe", "الإخراج")
add("settings.queue.note",
    "Renders hold tens of gigabytes of weights in memory, so only one runs at a "
    "time. Hold or stop an individual render from its own row in the Queue.",
    "算圖會在記憶體中保留數十 GB 的權重，因此一次只執行一個。要暫緩或停止個別算圖，"
    "請在「佇列」中該列操作。",
    "渲染会在内存中保留数十 GB 的权重，因此一次只运行一个。要暂缓或停止单个渲染，"
    "请在“队列”中该行操作。",
    "Renders halten zig Gigabyte an Gewichten im Speicher, daher läuft immer nur "
    "einer. Einzelne Renders lassen sich in ihrer Zeile in der Warteschlange "
    "zurückstellen oder anhalten.",
    "يحتفظ التصيير بعشرات الغيغابايتات من الأوزان في الذاكرة، لذا يعمل واحد فقط "
    "في كل مرة. يمكنك تعليق أو إيقاف أي تصيير من صفّه في قائمة الانتظار.")
add("settings.status", "Status", "狀態", "状态", "Status", "الحالة")
add("settings.python", "Python", "Python", "Python", "Python", "Python")
add("settings.architecture", "Architecture", "架構", "架构", "Architektur",
    "البنية")
add("settings.mlxMetal", "MLX on Metal", "MLX on Metal", "MLX on Metal",
    "MLX auf Metal", "‏MLX على Metal")
add("settings.working", "Working", "正常", "正常", "Funktioniert", "يعمل")
add("settings.notWorking", "Not working", "異常", "异常", "Funktioniert nicht",
    "لا يعمل")
add("settings.notFound", "Not found", "找不到", "未找到", "Nicht gefunden",
    "غير موجود")
add("settings.h3Pipeline", "H3 pipeline", "H3 管線", "H3 管线", "H3-Pipeline",
    "خط معالجة H3")
add("settings.detected", "Detected", "已偵測", "已检测", "Erkannt", "تم الكشف")
add("settings.notDetected", "Not detected", "未偵測到", "未检测到",
    "Nicht erkannt", "لم يُكتشف")
add("settings.recheck", "Re-check", "重新檢查", "重新检查", "Erneut prüfen",
    "إعادة الفحص")
add("settings.repair", "Repair", "修復", "修复", "Reparieren", "إصلاح")
add("settings.rebuild", "Rebuild from Scratch", "完全重建", "完全重建",
    "Komplett neu aufbauen", "إعادة البناء من الصفر")
add("settings.rebuild.note",
    "Rebuilding deletes and recreates the Python environment. It does not touch "
    "downloaded weights.",
    "重建會刪除並重新建立 Python 環境，不會動到已下載的權重。",
    "重建会删除并重新创建 Python 环境，不会动到已下载的权重。",
    "Beim Neuaufbau wird die Python-Umgebung gelöscht und neu erstellt. "
    "Heruntergeladene Gewichte bleiben unberührt.",
    "تؤدي إعادة البناء إلى حذف بيئة Python وإنشائها من جديد، دون المساس بالأوزان "
    "المنزَّلة.")
add("settings.log", "Log", "記錄", "日志", "Protokoll", "السجل")
add("settings.notInstalled", "Not installed.", "尚未安裝。", "尚未安装。",
    "Nicht installiert.", "غير مثبَّت.")
add("settings.state", "State", "狀態", "状态", "Zustand", "الحالة")
add("settings.comfy.server", "Server", "伺服器", "服务器", "Server", "الخادم")
add("settings.comfy.running", "running on port %@", "執行中，連接埠 %@",
    "运行中，端口 %@", "läuft auf Port %@", "يعمل على المنفذ %@")
add("settings.comfy.notRunning", "not running", "未執行", "未运行",
    "läuft nicht", "لا يعمل")
add("settings.comfy.weights", "Weights", "權重", "权重", "Gewichte", "الأوزان")
add("settings.comfy.install", "Install", "安裝", "安装", "Installieren", "تثبيت")
add("settings.comfy.stop", "Stop Server", "停止伺服器", "停止服务器",
    "Server anhalten", "إيقاف الخادم")
add('settings.comfy.why',
    'Reference mode runs here rather than on MLX, whose pipeline accepts keyframes only. ComfyUI also loads the 4-step turbo LoRAs, which is what makes reference renders practical at all.',
    '參考模式在此執行，而非 MLX，因為 MLX 的管線只接受關鍵格。ComfyUI 還能載入 4 步 turbo LoRA，這正是參考模式算圖得以可行的原因。',
    '参考模式在此运行，而非 MLX，因为 MLX 的管线只接受关键帧。ComfyUI 还能加载 4 步 turbo LoRA，这正是参考模式渲染得以可行的原因。',
    'Der Referenzmodus läuft hier statt auf MLX, dessen Pipeline nur Keyframes annimmt. ComfyUI lädt zudem die 4-Schritt-Turbo-LoRAs — erst dadurch werden Referenz-Renders überhaupt praktikabel.',
    'يعمل وضع المراجع هنا بدل MLX، إذ لا تقبل منظومته سوى الإطارات المفتاحية. كما يحمّل ComfyUI نماذج turbo LoRA ذات الأربع خطوات، وهو ما يجعل التصيير المرجعي عمليًا أصلًا.')
add("settings.comfy.note",
    "The app's own headless ComfyUI, kept apart from any you have installed "
    "yourself. The server starts on demand and stops with the app.",
    "這是 App 自帶的無介面 ComfyUI，與你自行安裝的版本互不干擾。伺服器會在需要時"
    "啟動，並隨 App 結束。",
    "这是 App 自带的无界面 ComfyUI，与你自行安装的版本互不干扰。服务器会在需要时"
    "启动，并随 App 退出。",
    "Das eigene headless ComfyUI der App, getrennt von jedem selbst installierten. "
    "Der Server startet bei Bedarf und endet mit der App.",
    "نسخة ComfyUI الخاصة بالتطبيق بلا واجهة، منفصلة عن أي نسخة ثبّتها بنفسك. "
    "يبدأ الخادم عند الحاجة ويتوقف مع إغلاق التطبيق.")
add("settings.advanced.port", "MiniMax-H3 port", "MiniMax-H3 移植版", "MiniMax-H3 移植版",
    "MiniMax-H3-Portierung", "نقل MiniMax-H3")
add("settings.advanced.checkout", "Checkout path", "簽出路徑", "检出路径",
    "Checkout-Pfad", "مسار النسخة")
add("settings.advanced.checkout.hint", "Leave empty to use the installed package",
    "留空則使用已安裝的套件", "留空则使用已安装的包",
    "Leer lassen, um das installierte Paket zu verwenden",
    "اتركه فارغًا لاستخدام الحزمة المثبتة")
add("settings.advanced.reveal", "Reveal Application Support Folder",
    "顯示 Application Support 資料夾", "显示 Application Support 文件夹",
    "Ordner „Application Support“ zeigen", "إظهار مجلد Application Support")
add("settings.advanced.supportNote",
    "Holds the Python environment, the render queue, and scratch files for "
    "in-flight renders.",
    "存放 Python 環境、算圖佇列，以及進行中算圖的暫存檔。",
    "存放 Python 环境、渲染队列，以及进行中渲染的暂存文件。",
    "Enthält die Python-Umgebung, die Render-Warteschlange und Zwischendateien "
    "laufender Renders.",
    "يضم بيئة Python وقائمة انتظار التصيير والملفات المؤقتة لعمليات التصيير الجارية.")

# ── Remaining onboarding / runtime prose ─────────────────────────────────────
add("onboarding.licence.heading", "MiniMax H3 Community License",
    "MiniMax H3 社群授權條款", "MiniMax H3 社区许可协议",
    "MiniMax H3 Community License", "ترخيص مجتمع MiniMax H3",
    "The licence's proper name stays in English; TW/CN gloss it.")
add("runtime.ready", "Runtime ready — Python %1$@, MLX on Metal",
    "執行環境就緒 — Python %1$@，MLX on Metal",
    "运行环境就绪 — Python %1$@，MLX on Metal",
    "Laufzeitumgebung bereit — Python %1$@, MLX auf Metal",
    "بيئة التشغيل جاهزة — Python %1$@، وMLX على Metal")
add("runtime.installedNotUsable", "Installed, but not usable yet",
    "已安裝，但尚無法使用", "已安装，但尚无法使用",
    "Installiert, aber noch nicht nutzbar", "مثبَّت، لكنه غير قابل للاستخدام بعد")
add("runtime.notInstalledYet", "Not installed yet.", "尚未安裝。", "尚未安装。",
    "Noch nicht installiert.", "غير مثبَّت بعد.")
add("models.revealInFinder", "Reveal %@ in Finder", "在 Finder 中顯示 %@",
    "在 Finder 中显示 %@", "%@ im Finder zeigen", "إظهار %@ في Finder")

# ── Duration formatting ──────────────────────────────────────────────────────
add("format.seconds", "%@ s", "%@ 秒", "%@ 秒", "%@ s", "%@ ث")
add("format.minutes", "%@ min", "%@ 分", "%@ 分", "%@ Min.", "%@ د")
add("format.hours", "%@ h", "%@ 小時", "%@ 小时", "%@ Std.", "%@ س")
add("format.hoursMinutes", "%1$@ h %2$@ min", "%1$@ 小時 %2$@ 分",
    "%1$@ 小时 %2$@ 分", "%1$@ Std. %2$@ Min.", "%1$@ س %2$@ د")

# ── Models: roles and tasks ──────────────────────────────────────────────────
add('role.transformer.detail',
    'The model itself. Pick one quantization; higher precision costs disk, memory and time.',
    '模型本體。擇一量化版本；精度越高，佔用的磁碟、記憶體與時間也越多。',
    '模型本体。择一量化版本；精度越高，占用的磁盘、内存与时间也越多。',
    'Das Modell selbst. Wählen Sie eine Quantisierung; höhere Präzision kostet Speicherplatz, Arbeitsspeicher und Zeit.',
    'النموذج نفسه. اختر تكميمًا واحدًا؛ فكلما ارتفعت الدقة زاد استهلاك القرص والذاكرة والوقت.')
add('role.textEncoder.detail',
    'H3 conditions on Qwen3-VL-32B. This is the largest single download and is shared by both tasks.',
    'H3 以 Qwen3-VL-32B 作為條件輸入。這是單一檔案中最大的下載項目，兩種任務共用。',
    'H3 以 Qwen3-VL-32B 作为条件输入。这是单个文件中最大的下载项，两种任务共用。',
    'H3 wird auf Qwen3-VL-32B konditioniert. Das ist der größte Einzeldownload und wird von beiden Aufgaben genutzt.',
    'يعتمد H3 على Qwen3-VL-32B. وهو أكبر تنزيل مفرد، وتشترك فيه المهمتان.')
add('role.support.detail',
    'Small, mandatory, and shared by everything. Install once.',
    '檔案小、必要，且所有項目共用。安裝一次即可。',
    '文件小、必需，且所有项目共用。安装一次即可。',
    'Klein, zwingend erforderlich und von allem gemeinsam genutzt. Einmal installieren.',
    'صغيرة وإلزامية ومشتركة بين كل شيء. تُثبَّت مرة واحدة.')
add('role.accelerator.detail',
    'Optional LoRAs trained to produce usable video in around 4 steps instead of 50.',
    '選用的 LoRA，經訓練後約 4 步即可產出可用影片，而非 50 步。',
    '可选的 LoRA，经训练后约 4 步即可产出可用视频，而非 50 步。',
    'Optionale LoRAs, trainiert für brauchbares Video in etwa 4 statt 50 Schritten.',
    'نماذج LoRA اختيارية مدرَّبة لإنتاج فيديو صالح في نحو 4 خطوات بدل 50.')
add('task.fl2va.detail',
    'Text-to-video, plus optional first and/or last frame images. Use this for most work.',
    '文字轉影片，並可選擇性指定首張與／或末張影格圖片。多數情況用這個。',
    '文字转视频，并可选择性指定首帧与/或末帧图片。多数情况用这个。',
    'Text zu Video, dazu optional Bilder für das erste und/oder letzte Bild. Für die meisten Arbeiten geeignet.',
    'من نص إلى فيديو، مع إمكانية تحديد صورة للإطار الأول و/أو الأخير. استخدم هذا في معظم الأعمال.')
add('task.ref2va.detail',
    'Conditions on up to 9 reference images, 3 reference videos and 3 reference audio clips.',
    '最多可依據 9 張參考圖片、3 段參考影片與 3 段參考音訊生成。',
    '最多可依据 9 张参考图片、3 段参考视频与 3 段参考音频生成。',
    'Konditioniert auf bis zu 9 Referenzbilder, 3 Referenzvideos und 3 Referenz-Audioclips.',
    'يعتمد على ما يصل إلى 9 صور و3 مقاطع فيديو و3 مقاطع صوتية مرجعية.')

# ── Models: per-entry summaries ──────────────────────────────────────────────
# Model, repository and format names stay as they are; only the prose around
# them is translated.
add('model.support.mlx',
    'Video VAE (10.4 GB), audio VAE, processor and tokenizer, taken from the FL2VA task directory the pipeline loads as a unit. Required by every run.',
    'video VAE（10.4 GB）、audio VAE、處理器與 tokenizer，取自 pipeline 整包載入的 FL2VA 任務目錄。每次算圖都需要。',
    'video VAE（10.4 GB）、audio VAE、处理器与 tokenizer，取自 pipeline 整包加载的 FL2VA 任务目录。每次渲染都需要。',
    'Video-VAE (10,4 GB), Audio-VAE, Prozessor und Tokenizer aus dem FL2VA-Aufgabenverzeichnis, das die Pipeline als Einheit lädt. Für jeden Lauf erforderlich.',
    '\u200fvideo VAE (10.4 GB) و\u200faudio VAE والمعالج و\u200ftokenizer، مأخوذة من مجلد مهمة FL2VA الذي تحمّله المنظومة ككتلة واحدة. مطلوبة في كل تشغيل.')
add('model.textEncoder.mlx',
    'Qwen3-VL-32B in bfloat16 — H3 reads its 50th-layer hidden states. The largest single download, and currently the only text encoder the MLX pipeline can load. At about 34 GB resident it, not the transformer, decides whether this app runs on a given Mac: with the smallest transformer that is roughly 46 GB, so about 64 GB of unified memory is the practical floor. It installs beside the VAEs in FL2VA/.',
    'bfloat16 版的 Qwen3-VL-32B——H3 讀取其第 50 層的隱藏狀態。單一檔案中最大的下載項目，目前也是 MLX pipeline 唯一能載入的文字編碼器。常駐約 34 GB，因此決定本 App 能否在某台 Mac 上執行的是它而非 transformer：搭配最小的 transformer 約需 46 GB，實務上統一記憶體約 64 GB 是門檻。會與 VAE 一同安裝在 FL2VA/ 之下。',
    'bfloat16 版的 Qwen3-VL-32B——H3 读取其第 50 层的隐藏状态。单个文件中最大的下载项，目前也是 MLX pipeline 唯一能加载的文本编码器。常驻约 34 GB，因此决定本 App 能否在某台 Mac 上运行的是它而非 transformer：搭配最小的 transformer 约需 46 GB，实际上统一内存约 64 GB 是门槛。会与 VAE 一同安装在 FL2VA/ 之下。',
    'Qwen3-VL-32B in bfloat16 – H3 liest dessen Hidden States aus Schicht 50. Der größte Einzeldownload und derzeit der einzige Text-Encoder, den die MLX-Pipeline laden kann. Mit rund 34 GB resident entscheidet er, nicht der Transformer, ob die App auf einem Mac läuft: mit dem kleinsten Transformer sind das etwa 46 GB, praktisch also rund 64 GB Unified Memory als Untergrenze. Wird neben den VAEs unter FL2VA/ installiert.',
    '\u200fQwen3-VL-32B بدقة bfloat16 — يقرأ H3 الحالات المخفية من طبقته الخمسين. أكبر تنزيل مفرد، وهو حاليًا مشفّر النص الوحيد الذي تستطيع منظومة MLX تحميله. وبإشغاله نحو 34 غيغابايت، فهو — لا المحوّل — ما يحدّد إمكانية تشغيل التطبيق على جهاز بعينه: مع أصغر محوّل يبلغ المجموع نحو 46 غيغابايت، أي أن الحدّ العملي هو ذاكرة موحّدة بنحو 64 غيغابايت. يُثبَّت بجانب الـ VAE داخل \u200eFL2VA/\u200e.')
add('model.fl2va.q4',
    '4-bit, group size 64. The fastest of these and about 12 GB resident. Loses some fine texture. The best place to start — but the text encoder, not this, is what sets the memory floor.',
    '4-bit，group size 64。這些選項中最快，常駐約 12 GB。細節質感會有所損失。建議從這個開始——不過決定記憶體門檻的是文字編碼器，而不是它。',
    '4-bit，group size 64。这些选项中最快，常驻约 12 GB。细节质感会有所损失。建议从这个开始——不过决定内存门槛的是文本编码器，而不是它。',
    '4 Bit, Gruppengröße 64. Die schnellste dieser Varianten und rund 12 GB resident. Verliert etwas Feintextur. Der beste Einstieg – die Speicheruntergrenze setzt allerdings der Text-Encoder, nicht diese Datei.',
    '\u200f4-bit بحجم مجموعة 64. الأسرع بينها ويشغل نحو 12 غيغابايت. يفقد بعض التفاصيل الدقيقة. أفضل نقطة للبدء — غير أن الحدّ الأدنى للذاكرة يفرضه مشفّر النص لا هذا الملف.')
add('model.fl2va.q6',
    '6-bit. A middle point if 4-bit looks soft and 8-bit is too slow.',
    '6-bit。若覺得 4-bit 太鬆散、8-bit 又太慢，這是折衷選擇。',
    '6-bit。若觉得 4-bit 太软、8-bit 又太慢，这是折中选择。',
    '6 Bit. Ein Mittelweg, wenn 4 Bit zu weich wirkt und 8 Bit zu langsam ist.',
    '\u200f6-bit. حل وسط إذا بدا 4-bit ناعمًا أكثر من اللازم وكان 8-bit بطيئًا.')
add('model.fl2va.q8',
    'The quality-per-gigabyte sweet spot — visually very close to bf16.',
    '每 GB 畫質的最佳平衡點——視覺上非常接近 bf16。',
    '每 GB 画质的最佳平衡点——视觉上非常接近 bf16。',
    'Das beste Verhältnis von Qualität zu Gigabyte – optisch sehr nah an bf16.',
    'أفضل توازن بين الجودة وحجم التخزين — قريب بصريًا جدًا من bf16.')
add('model.fl2va.bf16',
    'Reference precision, validated against the diffusers implementation. The slowest option, and about 41 GB resident on its own — with the text encoder loaded as well, plan on 128 GB of unified memory.',
    '參考精度，已對照 diffusers 實作驗證。速度最慢，單是本體常駐就約 41 GB——再加上文字編碼器，建議使用 128 GB 統一記憶體的機器。',
    '参考精度，已对照 diffusers 实现验证。速度最慢，单是本体常驻就约 41 GB——再加上文本编码器，建议使用 128 GB 统一内存的机器。',
    'Referenzpräzision, gegen die diffusers-Implementierung validiert. Die langsamste Option und allein schon rund 41 GB resident – zusammen mit dem Text-Encoder sollten es 128 GB Unified Memory sein.',
    'دقة مرجعية، جرى التحقق منها مقابل تنفيذ diffusers. الخيار الأبطأ، ويشغل وحده نحو 41 غيغابايت — ومع تحميل مشفّر النص أيضًا، يُنصح بذاكرة موحّدة سعتها 128 غيغابايت.')
add('model.ref2va.bf16',
    "Upstream bf16 Ref2VA checkpoint. Listed so the option is visible, but the MLX port's pipeline accepts keyframes only — it has no reference conditioning path — so this cannot be driven from this app yet.",
    '上游的 bf16 Ref2VA 檢查點。列出是為了讓選項可見，但 MLX 移植版的 pipeline 只接受關鍵影格——沒有參考條件的路徑——因此目前無法從本 App 驅動。',
    '上游的 bf16 Ref2VA 检查点。列出是为了让选项可见，但 MLX 移植版的 pipeline 只接受关键帧——没有参考条件的通路——因此目前无法从本 App 驱动。',
    'Upstream-bf16-Checkpoint für Ref2VA. Nur aufgeführt, damit die Option sichtbar ist: Die Pipeline der MLX-Portierung akzeptiert ausschließlich Keyframes und kennt keinen Pfad für Referenzkonditionierung, lässt sich also aus dieser App noch nicht ansteuern.',
    'نقطة تحقّق Ref2VA الأصلية بدقة bf16. مُدرجة ليظهر الخيار فحسب، لكن منظومة نسخة MLX لا تقبل سوى الإطارات المفتاحية ولا تملك مسارًا للاشتراط المرجعي، لذا لا يمكن تشغيلها من هذا التطبيق بعد.')
add('model.ref2va.bf16.blocked',
    'The MLX port does not implement reference conditioning. Ref2VA currently needs the CUDA stack (SGLang, vLLM or ComfyUI).',
    'MLX 移植版尚未實作參考條件。Ref2VA 目前需要 CUDA 環境（SGLang、vLLM 或 ComfyUI）。',
    'MLX 移植版尚未实现参考条件。Ref2VA 目前需要 CUDA 环境（SGLang、vLLM 或 ComfyUI）。',
    'Die MLX-Portierung implementiert keine Referenzkonditionierung. Ref2VA benötigt derzeit den CUDA-Stack (SGLang, vLLM oder ComfyUI).',
    'لا تنفّذ نسخة MLX الاشتراط المرجعي. يحتاج Ref2VA حاليًا إلى منظومة CUDA \u200f(SGLang أو vLLM أو ComfyUI).')
add('model.lora.fl2va.mlx',
    'A 4-step distillation LoRA for FL2VA at 768p — the single biggest speed win available for this model. The MLX port has no LoRA loader yet, so it is listed here to watch rather than to install.',
    '針對 768p FL2VA 的 4 步蒸餾 LoRA——本模型目前最大的一項加速。MLX 移植版尚無 LoRA 載入器，因此這裡只是列出供關注，還不能安裝。',
    '针对 768p FL2VA 的 4 步蒸馏 LoRA——本模型目前最大的一项加速。MLX 移植版尚无 LoRA 加载器，因此这里只是列出供关注，还不能安装。',
    'Eine 4-Schritt-Destillations-LoRA für FL2VA bei 768p – der größte verfügbare Geschwindigkeitsgewinn für dieses Modell. Die MLX-Portierung hat noch keinen LoRA-Loader, daher steht sie hier zum Beobachten, nicht zum Installieren.',
    'نموذج LoRA مُقطَّر بأربع خطوات لـ FL2VA بدقة 768p — أكبر مكسب في السرعة متاح لهذا النموذج. لا تملك نسخة MLX محمِّل LoRA بعد، لذا يُدرج هنا للمتابعة لا للتثبيت.')
add('model.lora.fl2va.mlx.blocked',
    'The MLX port has no LoRA loader yet. Fusing this would need a merged checkpoint rather than the LoRA on its own.',
    'MLX 移植版尚無 LoRA 載入器。要套用它得改用已合併的檢查點，而非單獨的 LoRA。',
    'MLX 移植版尚无 LoRA 加载器。要套用它得改用已合并的检查点，而非单独的 LoRA。',
    'Die MLX-Portierung hat noch keinen LoRA-Loader. Zum Einbinden wäre ein zusammengeführter Checkpoint nötig, nicht die LoRA allein.',
    'لا تملك نسخة MLX محمِّل LoRA بعد. ودمجه يتطلب نقطة تحقّق مدموجة بدل ملف LoRA وحده.')
add('model.comfy.ref2va',
    'Ref2VA transformer for ComfyUI. Required for reference mode, which the MLX port cannot do at all.',
    'ComfyUI 用的 Ref2VA transformer。參考素材模式必備，而 MLX 移植版完全無法處理該模式。',
    'ComfyUI 用的 Ref2VA transformer。参考素材模式必备，而 MLX 移植版完全无法处理该模式。',
    'Ref2VA-Transformer für ComfyUI. Erforderlich für den Referenzmodus, den die MLX-Portierung überhaupt nicht beherrscht.',
    'محوّل Ref2VA الخاص بـ ComfyUI. لازم لوضع المراجع، وهو ما لا تستطيعه نسخة MLX إطلاقًا.')
add('model.comfy.fl2va',
    'FL2VA transformer for ComfyUI. Only needed if you want to run text-to-video or keyframes through ComfyUI instead of MLX.',
    'ComfyUI 用的 FL2VA transformer。只有當你想改用 ComfyUI（而非 MLX）執行文字轉影片或關鍵影格時才需要。',
    'ComfyUI 用的 FL2VA transformer。只有当你想改用 ComfyUI（而非 MLX）执行文字转视频或关键帧时才需要。',
    'FL2VA-Transformer für ComfyUI. Nur nötig, wenn Sie Text-zu-Video oder Keyframes über ComfyUI statt über MLX laufen lassen wollen.',
    'محوّل FL2VA الخاص بـ ComfyUI. لا يلزم إلا إذا أردت تشغيل التحويل من نص إلى فيديو أو الإطارات المفتاحية عبر ComfyUI بدل MLX.')
add('model.comfy.textEncoder',
    'Qwen3-VL-32B for ComfyUI. Shared by both tasks — download once.',
    'ComfyUI 用的 Qwen3-VL-32B。兩種任務共用——下載一次即可。',
    'ComfyUI 用的 Qwen3-VL-32B。两种任务共用——下载一次即可。',
    'Qwen3-VL-32B für ComfyUI. Von beiden Aufgaben genutzt – einmal laden.',
    '\u200fQwen3-VL-32B الخاص بـ ComfyUI. تشترك فيه المهمتان — نزّله مرة واحدة.')
add('model.comfy.videoVAE',
    'Video VAE in fp16. Chosen over the INT8 build: it is small, and decode quality is visible.',
    'fp16 的 video VAE。相較 INT8 版更建議這個：體積小，而且解碼品質看得出差別。',
    'fp16 的 video VAE。相较 INT8 版更建议这个：体积小，而且解码质量看得出差别。',
    'Video-VAE in fp16. Dem INT8-Build vorgezogen: klein, und die Decodier-Qualität ist sichtbar.',
    '\u200fvideo VAE بدقة fp16. فُضّل على نسخة INT8: حجمه صغير وجودة فك الترميز ملحوظة.')
add('model.comfy.audioVAE',
    'Audio VAE in fp32, for the stereo track H3 generates alongside the picture.',
    'fp32 的 audio VAE，用於 H3 在畫面之外同時生成的立體聲軌。',
    'fp32 的 audio VAE，用于 H3 在画面之外同时生成的立体声轨。',
    'Audio-VAE in fp32, für die Stereospur, die H3 zusätzlich zum Bild erzeugt.',
    '\u200faudio VAE بدقة fp32، للمسار الصوتي المجسَّم الذي يولّده H3 إلى جانب الصورة.')
add('model.comfy.lora.ref2va',
    '4-step Ref2VA turbo LoRA. This is what makes reference renders practical at all — four steps instead of fifty, so tens of minutes rather than many hours.',
    '4 步的 Ref2VA turbo LoRA。正是它讓參考素材算圖變得可行——四步而非五十步，時間從數小時降到數十分鐘。',
    '4 步的 Ref2VA turbo LoRA。正是它让参考素材渲染变得可行——四步而非五十步，时间从数小时降到数十分钟。',
    '4-Schritt-Turbo-LoRA für Ref2VA. Sie macht Referenz-Renderings überhaupt erst praktikabel – vier Schritte statt fünfzig, also Dutzende Minuten statt vieler Stunden.',
    'نموذج LoRA السريع لـ Ref2VA بأربع خطوات. هو ما يجعل التصيير المرجعي عمليًا أصلًا — أربع خطوات بدل خمسين، أي عشرات الدقائق بدل ساعات طويلة.')
add('model.comfy.lora.fl2va',
    "4-step FL2VA turbo LoRA. Distilled for four steps, where MLX's undistilled weights want sixteen.",
    '4 步的 FL2VA turbo LoRA。專為四步蒸餾，而 MLX 未蒸餾的權重需要十六步。',
    '4 步的 FL2VA turbo LoRA。专为四步蒸馏，而 MLX 未蒸馏的权重需要十六步。',
    '4-Schritt-Turbo-LoRA für FL2VA. Auf vier Schritte destilliert, während die undestillierten MLX-Gewichte sechzehn brauchen.',
    'نموذج LoRA السريع لـ FL2VA بأربع خطوات. مُقطَّر لأربع خطوات، بينما تحتاج أوزان MLX غير المقطَّرة إلى ستّ عشرة.')
add('model.textEncoder.uncensored',
    'Qwen3-VL-32B with its refusal behaviour trained out. Drop-in replacement for the stock encoder — H3 itself is unchanged, since refusals live in the language model, not the diffusion transformer. ComfyUI only; MLX has no loader for this format.',
    '已移除拒絕行為的 Qwen3-VL-32B。可直接替換原本的編碼器——H3 本身沒有改動，因為拒絕行為存在於語言模型，而非 diffusion transformer。僅支援 ComfyUI；MLX 無法載入此格式。',
    '已移除拒绝行为的 Qwen3-VL-32B。可直接替换原本的编码器——H3 本身没有改动，因为拒绝行为存在于语言模型，而非 diffusion transformer。仅支持 ComfyUI；MLX 无法加载此格式。',
    'Qwen3-VL-32B, dem das Verweigerungsverhalten abtrainiert wurde. Direkter Ersatz für den Standard-Encoder – H3 selbst bleibt unverändert, da Verweigerungen im Sprachmodell sitzen, nicht im Diffusion-Transformer. Nur ComfyUI; MLX hat keinen Loader für dieses Format.',
    '\u200fQwen3-VL-32B بعد تدريبه على التخلّي عن سلوك الرفض. بديل مباشر للمشفّر القياسي — ويبقى H3 نفسه دون تغيير، لأن الرفض يقيم في نموذج اللغة لا في محوّل الانتشار. يعمل مع ComfyUI فقط؛ ولا يملك MLX محمِّلًا لهذه الصيغة.')
add('model.fl2va.gguf',
    'GGUF quantizations, including very small ones. Loaded by ComfyUI, not by MLX — useful if you ever run this model through ComfyUI instead.',
    'GGUF 量化版本，包含非常小的檔案。由 ComfyUI 載入，MLX 不支援——若你改以 ComfyUI 執行本模型就用得上。',
    'GGUF 量化版本，包含非常小的文件。由 ComfyUI 加载，MLX 不支持——若你改用 ComfyUI 运行本模型就用得上。',
    'GGUF-Quantisierungen, auch sehr kleine. Wird von ComfyUI geladen, nicht von MLX – nützlich, falls Sie das Modell stattdessen über ComfyUI laufen lassen.',
    'تكميمات بصيغة GGUF، منها نسخ صغيرة جدًا. يحمّلها ComfyUI لا MLX — مفيدة إن شغّلت هذا النموذج عبر ComfyUI بدلًا من ذلك.')
add('model.fl2va.nvfp4',
    "Community prune in NVIDIA's NVFP4 format. Listed for completeness.",
    '社群釋出的修剪版，採用 NVIDIA 的 NVFP4 格式。列出以求完整。',
    '社区发布的剪枝版，采用 NVIDIA 的 NVFP4 格式。列出以求完整。',
    'Community-Prune im NVFP4-Format von NVIDIA. Der Vollständigkeit halber aufgeführt.',
    'نسخة مُقلَّمة من المجتمع بصيغة NVFP4 من NVIDIA. مُدرجة لاكتمال القائمة.')

# ── Formatting fragments ─────────────────────────────────────────────────────
add('format.clipLength',
    '%@ s',
    '%@ 秒',
    '%@ 秒',
    '%@ s',
    '%@ ث')
add('format.frames',
    '%@ frames',
    '%@ 影格',
    '%@ 帧',
    '%@ Bilder',
    '%@ إطارًا')
add('format.steps',
    '%@ steps',
    '%@ 步',
    '%@ 步',
    '%@ Schritte',
    '%@ خطوة')
add('format.framesAndLength',
    '%1$@ frames · %2$@ s',
    '%1$@ 影格 · %2$@ 秒',
    '%1$@ 帧 · %2$@ 秒',
    '%1$@ Bilder · %2$@ s',
    '%1$@ إطارًا · %2$@ ث')
add('sampling.steps.note',
    "Steps are actual denoising passes, and dominate render time almost linearly. %1$@ Duration snaps to the video VAE's 17n+5 frame grid, so the value shown is what renders.",
    '步數就是實際的去噪次數，幾乎線性決定算圖時間。%1$@時長會對齊 video VAE 的 17n+5 影格格線，因此顯示的數值就是實際會算出的長度。',
    '步数就是实际的去噪次数，几乎线性决定渲染时间。%1$@时长会对齐 video VAE 的 17n+5 帧栅格，因此显示的数值就是实际会渲染出的长度。',
    'Schritte sind echte Entrausch-Durchgänge und bestimmen die Renderzeit nahezu linear. %1$@ Die Dauer rastet auf das 17n+5-Bildraster des Video-VAE ein, der angezeigte Wert ist also der, der gerendert wird.',
    'الخطوات هي مرات إزالة التشويش الفعلية، وتحدّد زمن التصيير تحديدًا خطّيًا تقريبًا. %1$@ وتنحاز المدة إلى شبكة إطارات video VAE \u200f(17n+5)، لذا فالقيمة المعروضة هي ما سيُصيَّر فعلًا.')
add('sampling.steps.note.turbo',
    'This engine loads a %1$@-step turbo LoRA, distilled for exactly that many — more steps mostly cost time.',
    '此引擎會載入 %1$@ 步的 turbo LoRA，正是針對這個步數蒸餾的——再加步數多半只是多花時間。',
    '此引擎会加载 %1$@ 步的 turbo LoRA，正是针对这个步数蒸馏的——再加步数多半只是多花时间。',
    'Diese Engine lädt eine Turbo-LoRA für %1$@ Schritte, genau darauf destilliert – mehr Schritte kosten meist nur Zeit.',
    'يحمّل هذا المحرّك نموذج LoRA سريعًا بـ %1$@ خطوات، مُقطَّرًا لهذا العدد تحديدًا — والمزيد من الخطوات يكلّف وقتًا في الغالب.')
add('sampling.steps.note.undistilled',
    'These weights are undistilled, so around %1$@ steps is the working range; far fewer is off-distribution and looks soft.',
    '這些權重未經蒸餾，因此約 %1$@ 步是合用的範圍；步數遠低於此會偏離訓練分佈，畫面會顯得鬆散。',
    '这些权重未经蒸馏，因此约 %1$@ 步是合用的范围；步数远低于此会偏离训练分布，画面会显得发软。',
    'Diese Gewichte sind undestilliert, brauchbar ist daher der Bereich um %1$@ Schritte; deutlich weniger liegt außerhalb der Verteilung und wirkt weich.',
    'هذه الأوزان غير مقطَّرة، لذا فالمجال العملي نحو %1$@ خطوة؛ وما دون ذلك بكثير يخرج عن التوزيع ويبدو ناعمًا.')

# ── Models: why a format will not load ───────────────────────────────────────
add('quantization.unloadable.nvfp4',
    'NVFP4 is an NVIDIA Blackwell format. There is no Metal path.',
    'NVFP4 是 NVIDIA Blackwell 的格式，沒有對應的 Metal 執行路徑。',
    'NVFP4 是 NVIDIA Blackwell 的格式，没有对应的 Metal 执行路径。',
    'NVFP4 ist ein NVIDIA-Blackwell-Format. Einen Metal-Pfad dafür gibt es nicht.',
    '\u200fNVFP4 صيغة خاصة ببنية NVIDIA Blackwell. ولا يوجد مسار عبر Metal لتشغيلها.')
add('quantization.unloadable.gguf',
    'GGUF needs a ComfyUI custom node this app does not install.',
    'GGUF 需要一個本 App 不會安裝的 ComfyUI 自訂節點。',
    'GGUF 需要一个本 App 不会安装的 ComfyUI 自定义节点。',
    'GGUF benötigt eine ComfyUI-Erweiterung, die diese App nicht installiert.',
    'يحتاج GGUF إلى عقدة مخصّصة في ComfyUI لا يثبّتها هذا التطبيق.')
add('quantization.unloadable.other',
    'No engine here can load %@.',
    '此處的任何引擎都無法載入 %@。',
    '此处的任何引擎都无法加载 %@。',
    'Keine Engine hier kann %@ laden.',
    'لا يستطيع أي محرّك هنا تحميل %@.')

# ── Models: how an entry names itself, and two stragglers ────────────────────
add('problem.tooManyOfKind',
    'At most %1$@ reference %2$@ files — you have %3$@.',
    '參考%2$@檔案最多 %1$@ 個——目前有 %3$@ 個。',
    '参考%2$@文件最多 %1$@ 个——目前有 %3$@ 个。',
    'Höchstens %1$@ Referenzdateien vom Typ %2$@ – Sie haben %3$@.',
    'بحد أقصى %1$@ من ملفات %2$@ المرجعية — لديك %3$@.')
add('queue.untitled',
    'Untitled render',
    '未命名算圖',
    '未命名渲染',
    'Unbenannter Render',
    'تصيير بلا عنوان')
add("models.chooseFolder.message",
    "Choose the folder where model weights are shared between projects",
    "選擇各專案共用模型權重的資料夾",
    "选择各项目共用模型权重的文件夹",
    "Wählen Sie den Ordner, in dem Modellgewichte projektübergreifend geteilt werden",
    "اختر المجلد الذي تُشارَك فيه أوزان النماذج بين المشاريع")

# ── Fitting the estimate and the weights to this Mac ─────────────────────────
add('summary.eta.footnote.predicted',
    'An estimate for %@, scaled from a published figure for a different Mac. It will be replaced by a measurement after your first render.',
    '針對 %@ 的推估值，由另一款 Mac 的公開數據換算而來。完成第一次算圖後，會改用實測值。',
    '针对 %@ 的推算值，由另一款 Mac 的公开数据换算而来。完成第一次渲染后，会改用实测值。',
    'Eine Schätzung für %@, hochgerechnet aus einem veröffentlichten Wert für einen anderen Mac. Nach Ihrem ersten Render wird sie durch eine Messung ersetzt.',
    'تقدير لجهاز %@، محسوب من رقم منشور لجهاز Mac مختلف. وسيحلّ محلّه قياس فعلي بعد أول تصيير تجريه.')
add('summary.eta.footnote.measured',
    "Measured from this Mac's own renders on this engine (%@ so far).",
    '依本機此引擎的實際算圖測得（目前 %@ 次）。',
    '依本机此引擎的实际渲染测得（目前 %@ 次）。',
    'Aus den Renderings dieses Macs mit dieser Engine gemessen (bisher %@).',
    'مقيس من عمليات التصيير على هذا الـ Mac بهذا المحرّك (%@ حتى الآن).')
add('models.memory.tooLarge',
    'Needs about %1$@ in memory. This Mac can give about %2$@ to a model, so this will swap rather than run.',
    '需要約 %1$@ 記憶體。本機可分配給模型的約為 %2$@，因此會落到置換空間而非正常執行。',
    '需要约 %1$@ 内存。本机可分配给模型的约为 %2$@，因此会落到交换空间而非正常运行。',
    'Benötigt etwa %1$@ Arbeitsspeicher. Dieser Mac kann einem Modell etwa %2$@ geben, es würde also auslagern statt zu laufen.',
    'يحتاج نحو %1$@ من الذاكرة. ولا يستطيع هذا الـ Mac منح النموذج سوى %2$@ تقريبًا، لذا سيلجأ إلى التبديل بدل التشغيل.')
add('models.memory.tight',
    'Needs about %1$@ of the roughly %2$@ this Mac can give a model. It will fit, with little to spare.',
    '需要約 %1$@，而本機可分配給模型的約為 %2$@。放得下，但餘裕不多。',
    '需要约 %1$@，而本机可分配给模型的约为 %2$@。放得下，但余量不多。',
    'Benötigt etwa %1$@ von den rund %2$@, die dieser Mac einem Modell geben kann. Es passt, aber knapp.',
    'يحتاج نحو %1$@ من أصل %2$@ تقريبًا يمكن لهذا الـ Mac منحها لنموذج. سيتّسع، لكن دون هامش يُذكر.')
add('problem.memory',
    'The selected weights need about %1$@ in memory together. This Mac can give a model about %2$@. Choose a smaller quantization, or expect it to swap.',
    '所選的權重合計需要約 %1$@ 記憶體，而本機可分配給模型的約為 %2$@。請改選更小的量化版本，否則會落到置換空間。',
    '所选的权重合计需要约 %1$@ 内存，而本机可分配给模型的约为 %2$@。请改选更小的量化版本，否则会落到交换空间。',
    'Die gewählten Gewichte brauchen zusammen etwa %1$@ Arbeitsspeicher. Dieser Mac kann einem Modell etwa %2$@ geben. Wählen Sie eine kleinere Quantisierung, oder rechnen Sie mit Auslagerung.',
    'تحتاج الأوزان المختارة معًا نحو %1$@ من الذاكرة، ولا يستطيع هذا الـ Mac منح النموذج سوى %2$@ تقريبًا. اختر تكميمًا أصغر، أو توقّع اللجوء إلى التبديل.')
add("problem.noMetalKernel",
    "%@ has no Metal kernel and cannot run on Apple silicon.",
    "%@ 沒有對應的 Metal kernel，無法在 Apple 晶片上執行。",
    "%@ 没有对应的 Metal kernel，无法在 Apple 芯片上运行。",
    "%@ hat keinen Metal-Kernel und läuft nicht auf Apple Silicon.",
    "لا يملك %@ نواة Metal، ولا يمكن تشغيله على شرائح Apple.")

# ── Models: what each entry is ───────────────────────────────────────────────
# Names, not formats. Every one is unique, because the tag pills and the grey
# description below are not where identity should live.
add('model.name.support.mlx',
    'FL2VA VAEs, processor & tokenizer',
    'FL2VA VAE、處理器與 tokenizer',
    'FL2VA VAE、处理器与 tokenizer',
    'FL2VA-VAEs, Prozessor und Tokenizer',
    '\u200fVAE ومعالج و\u200ftokenizer لـ FL2VA')
add('model.name.textEncoder.mlx',
    'Text encoder — bfloat16',
    '文字編碼器 — bfloat16',
    '文本编码器 — bfloat16',
    'Text-Encoder – bfloat16',
    'مشفّر النص — bfloat16')
add('model.name.fl2va.q4',
    'FL2VA transformer — 4-bit (MLX)',
    'FL2VA transformer — 4-bit (MLX)',
    'FL2VA transformer — 4-bit (MLX)',
    'FL2VA-Transformer – 4-bit (MLX)',
    'محوّل FL2VA — \u200f4-bit \u200f(MLX)')
add('model.name.fl2va.q6',
    'FL2VA transformer — 6-bit (MLX)',
    'FL2VA transformer — 6-bit (MLX)',
    'FL2VA transformer — 6-bit (MLX)',
    'FL2VA-Transformer – 6-bit (MLX)',
    'محوّل FL2VA — \u200f6-bit \u200f(MLX)')
add('model.name.fl2va.q8',
    'FL2VA transformer — 8-bit (MLX)',
    'FL2VA transformer — 8-bit (MLX)',
    'FL2VA transformer — 8-bit (MLX)',
    'FL2VA-Transformer – 8-bit (MLX)',
    'محوّل FL2VA — \u200f8-bit \u200f(MLX)')
add('model.name.fl2va.bf16',
    'FL2VA transformer — bfloat16',
    'FL2VA transformer — bfloat16',
    'FL2VA transformer — bfloat16',
    'FL2VA-Transformer – bfloat16',
    'محوّل FL2VA — \u200fbfloat16')
add('model.name.ref2va.bf16',
    'Ref2VA transformer — bfloat16',
    'Ref2VA transformer — bfloat16',
    'Ref2VA transformer — bfloat16',
    'Ref2VA-Transformer – bfloat16',
    'محوّل Ref2VA — \u200fbfloat16')
add('model.name.lora.fl2va.mlx',
    'FL2VA turbo LoRA — 4-step, MLX format',
    'FL2VA turbo LoRA — 4 步，MLX 格式',
    'FL2VA turbo LoRA — 4 步，MLX 格式',
    'FL2VA-Turbo-LoRA – 4 Schritte, MLX-Format',
    '\u200fFL2VA turbo LoRA — أربع خطوات، بصيغة MLX')
add('model.name.comfy.ref2va',
    'Ref2VA transformer — INT8 ConvRot',
    'Ref2VA transformer — INT8 ConvRot',
    'Ref2VA transformer — INT8 ConvRot',
    'Ref2VA-Transformer – INT8 ConvRot',
    'محوّل Ref2VA — \u200fINT8 ConvRot')
add('model.name.comfy.fl2va',
    'FL2VA transformer — INT8 ConvRot',
    'FL2VA transformer — INT8 ConvRot',
    'FL2VA transformer — INT8 ConvRot',
    'FL2VA-Transformer – INT8 ConvRot',
    'محوّل FL2VA — \u200fINT8 ConvRot')
add('model.name.comfy.textEncoder',
    'Text encoder — INT8 ConvRot',
    '文字編碼器 — INT8 ConvRot',
    '文本编码器 — INT8 ConvRot',
    'Text-Encoder – INT8 ConvRot',
    'مشفّر النص — \u200fINT8 ConvRot')
add('model.name.comfy.videoVAE',
    'Video VAE — fp16',
    'Video VAE — fp16',
    'Video VAE — fp16',
    'Video-VAE – fp16',
    '\u200fVAE الفيديو — \u200ffp16')
add('model.name.comfy.audioVAE',
    'Audio VAE — fp32',
    'Audio VAE — fp32',
    'Audio VAE — fp32',
    'Audio-VAE – fp32',
    '\u200fVAE الصوت — \u200ffp32')
add('model.name.comfy.lora.ref2va',
    'Ref2VA turbo LoRA — 4-step',
    'Ref2VA turbo LoRA — 4 步',
    'Ref2VA turbo LoRA — 4 步',
    'Ref2VA-Turbo-LoRA – 4 Schritte',
    '\u200fRef2VA turbo LoRA — أربع خطوات')
add('model.name.comfy.lora.fl2va',
    'FL2VA turbo LoRA — 4-step, ComfyUI format',
    'FL2VA turbo LoRA — 4 步，ComfyUI 格式',
    'FL2VA turbo LoRA — 4 步，ComfyUI 格式',
    'FL2VA-Turbo-LoRA – 4 Schritte, ComfyUI-Format',
    '\u200fFL2VA turbo LoRA — أربع خطوات، بصيغة ComfyUI')
add('model.name.textEncoder.uncensored',
    'Text encoder — INT8 ConvRot, uncensored',
    '文字編碼器 — INT8 ConvRot，無審查',
    '文本编码器 — INT8 ConvRot，无审查',
    'Text-Encoder – INT8 ConvRot, ohne Filter',
    'مشفّر النص — \u200fINT8 ConvRot، بلا رقابة')
add('model.name.fl2va.gguf',
    'FL2VA transformer — GGUF',
    'FL2VA transformer — GGUF',
    'FL2VA transformer — GGUF',
    'FL2VA-Transformer – GGUF',
    'محوّل FL2VA — \u200fGGUF')
add('model.name.fl2va.nvfp4',
    'FL2VA transformer — NVFP4',
    'FL2VA transformer — NVFP4',
    'FL2VA transformer — NVFP4',
    'FL2VA-Transformer – NVFP4',
    'محوّل FL2VA — \u200fNVFP4')

# ── ComfyUI availability ─────────────────────────────────────────────────────
# File names arrive wrapped in backticks and are set in a monospaced face; keep
# the markers in every translation.
add("comfy.notInstalled",
    "ComfyUI is not installed. Install it in Settings \u203a ComfyUI.",
    "尚未安裝 ComfyUI。請至「設定 \u203a ComfyUI」安裝。",
    "尚未安装 ComfyUI。请至“设置 \u203a ComfyUI”安装。",
    "ComfyUI ist nicht installiert. Installieren Sie es unter \u201eEinstellungen \u203a ComfyUI\u201c.",
    "\u200fComfyUI غير مثبَّت. ثبّته من \u00ab\u0627\u0644\u0625\u0639\u062f\u0627\u062f\u0627\u062a \u203a ComfyUI\u00bb.")
add("comfy.missingWeights",
    "Missing ComfyUI weights: %@",
    "缺少 ComfyUI 權重檔：%@",
    "缺少 ComfyUI 权重文件：%@",
    "Fehlende ComfyUI-Gewichte: %@",
    "أوزان ComfyUI ناقصة: %@")
add("comfy.executionError",
    "ComfyUI reported an execution error.",
    "ComfyUI 回報執行錯誤。",
    "ComfyUI 报告执行错误。",
    "ComfyUI hat einen Ausführungsfehler gemeldet.",
    "أبلغ ComfyUI عن خطأ أثناء التنفيذ.")

# ── Models: row status and copying ───────────────────────────────────────────
add("models.status.inUse", "Downloaded, and used by this render",
    "已下載，且本次算圖會用到", "已下载，且本次渲染会用到",
    "Geladen und für dieses Rendering verwendet",
    "مُنزَّل، ويُستخدم في هذا التصيير")
add("models.status.missing", "Needed by this render, but not downloaded",
    "本次算圖需要，但尚未下載", "本次渲染需要，但尚未下载",
    "F\u00fcr dieses Rendering erforderlich, aber nicht geladen",
    "مطلوب لهذا التصيير، لكنه غير مُنزَّل")
add("models.copyLink", "Copy link", "拷貝連結", "复制链接", "Link kopieren", "نسخ الرابط")
add("models.copyFilename", "Copy file name", "拷貝檔案名稱", "复制文件名",
    "Dateinamen kopieren", "نسخ اسم الملف")
add("models.copyRepoID", "Copy repository id", "拷貝儲存庫 ID", "复制仓库 ID",
    "Repository-ID kopieren", "نسخ معرّف المستودع")

# ── Queue: throughput and sequence length ────────────────────────────────────
# "Tokens" here is the length of the one sequence the text encoder is handed, not
# a running cost: H3 is a diffusion model and generates nothing token by token.
add("queue.perStep.now", "%@/step now", "目前 %@/步", "当前 %@/步",
    "jetzt %@/Schritt", "%@/خطوة الآن")
add("queue.perStep.average", "%@/step average", "平均 %@/步", "平均 %@/步",
    "im Mittel %@/Schritt", "%@/خطوة في المتوسط")
add("queue.tokens", "%@ tokens", "%@ 個 token", "%@ 个 token",
    "%@ Tokens", "%@ توكن")
add("queue.tokens.help",
    "Length of the sequence the text encoder reads: %1$@ tokens in all, of which %2$@ are the prompt. The rest are vision tokens, one block per reference image. It is read once, before denoising starts \u2014 nothing here is generated token by token.",
    "文字編碼器讀取的序列長度：共 %1$@ 個 token，其中 %2$@ 個來自提示詞，其餘是視覺 token，每張參考圖片一段。這段序列在去噪開始前只讀取一次——此處並非逐 token 生成。",
    "文本编码器读取的序列长度：共 %1$@ 个 token，其中 %2$@ 个来自提示词，其余是视觉 token，每张参考图片一段。这段序列在去噪开始前只读取一次——此处并非逐 token 生成。",
    "L\u00e4nge der Sequenz, die der Text-Encoder liest: insgesamt %1$@ Tokens, davon %2$@ aus dem Prompt. Der Rest sind Vision-Tokens, ein Block je Referenzbild. Sie wird einmal vor dem Entrauschen gelesen \u2014 hier wird nichts Token f\u00fcr Token erzeugt.",
    "\u0637\u0648\u0644 \u0627\u0644\u0645\u062a\u0633\u0644\u0633\u0644\u0629 \u0627\u0644\u062a\u064a \u064a\u0642\u0631\u0623\u0647\u0627 \u0645\u0634\u0641\u0651\u0631 \u0627\u0644\u0646\u0635: %1$@ \u062a\u0648\u0643\u0646 \u0625\u062c\u0645\u0627\u0644\u064b\u0627\u060c \u0645\u0646\u0647\u0627 %2$@ \u0645\u0646 \u0627\u0644\u0645\u0637\u0627\u0644\u0628\u0629\u060c \u0648\u0627\u0644\u0628\u0627\u0642\u064a \u062a\u0648\u0643\u0646\u0627\u062a \u0628\u0635\u0631\u064a\u0629 \u0628\u0645\u0642\u062f\u0627\u0631 \u0643\u062a\u0644\u0629 \u0644\u0643\u0644 \u0635\u0648\u0631\u0629 \u0645\u0631\u062c\u0639\u064a\u0629. \u062a\u064f\u0642\u0631\u0623 \u0645\u0631\u0629 \u0648\u0627\u062d\u062f\u0629 \u0642\u0628\u0644 \u0628\u062f\u0621 \u0625\u0632\u0627\u0644\u0629 \u0627\u0644\u062a\u0634\u0648\u064a\u0634 \u2014 \u0648\u0644\u0627 \u064a\u064f\u0648\u0644\u0651\u064e\u062f \u0647\u0646\u0627 \u0634\u064a\u0621 \u062a\u0648\u0643\u0646\u064b\u0627 \u0628\u062a\u0648\u0643\u0646.")
add("compose.preset.saved", "Saved \u201c%@\u201d to Presets",
    "已將「%@」儲存至預設組合", "已将“%@”保存至预设组合",
    "\u201e%@\u201c unter Voreinstellungen gesichert",
    "\u062d\u064f\u0641\u0650\u0638 \u00ab%@\u00bb \u0636\u0645\u0646 \u0627\u0644\u0625\u0639\u062f\u0627\u062f\u0627\u062a \u0627\u0644\u0645\u064f\u0633\u0628\u064e\u0642\u0629")
add("compose.preset.duplicate",
    "A preset called \u201c%@\u201d already exists. Choose another name.",
    "已有名為「%@」的預設組合，請換一個名稱。",
    "已有名为“%@”的预设组合，请换一个名称。",
    "Eine Vorlage namens \u201e%@\u201c gibt es bereits. W\u00e4hlen Sie einen anderen Namen.",
    "\u064a\u0648\u062c\u062f \u0625\u0639\u062f\u0627\u062f \u0628\u0627\u0633\u0645 \u00ab%@\u00bb \u0645\u0633\u0628\u0642\u064b\u0627. \u0627\u062e\u062a\u0631 \u0627\u0633\u0645\u064b\u0627 \u0622\u062e\u0631.")
add("models.download.starting", "Starting transfer\u2026", "正在開始傳輸…", "正在开始传输…",
    "\u00dcbertragung wird gestartet\u2026", "\u062c\u0627\u0631\u064d \u0628\u062f\u0621 \u0627\u0644\u0646\u0642\u0644\u2026")
add("models.downloading", "Downloading\u2026", "下載中…", "下载中…",
    "Wird geladen\u2026", "\u062c\u0627\u0631\u064d \u0627\u0644\u062a\u0646\u0632\u064a\u0644\u2026")

# ── Spoken and compact progress text ─────────────────────────────────────────
# The a11y.* keys are read aloud by VoiceOver, so they are translated even
# though they never appear on screen.
add('format.ofTotal',
    '%1$@ of %2$@',
    '已下載 %1$@，共 %2$@',
    '已下载 %1$@，共 %2$@',
    '%1$@ von %2$@',
    '%1$@ من %2$@')
add('a11y.percent',
    '%@ percent',
    '%@%%',
    '%@%%',
    '%@ Prozent',
    '%@ بالمئة')
add('a11y.elapsed',
    'elapsed %@',
    '已用 %@',
    '已用 %@',
    '%@ vergangen',
    'انقضى %@')
add('a11y.remaining',
    'about %@ remaining',
    '約剩 %@',
    '约剩 %@',
    'noch etwa %@',
    'يتبقى نحو %@')
add('a11y.usingMemory',
    'using %@',
    '佔用 %@',
    '占用 %@',
    'belegt %@',
    'يستخدم %@')
add('queue.a11y.held',
    'held',
    '已暫停',
    '已暂停',
    'angehalten',
    'مُعلَّق')
add('library.empty.detail',
    'Finished renders are saved to %@, each with a JSON file recording the exact settings that produced it.',
    '完成的算圖會存到 %@，每支影片都附一個 JSON 檔，記下產生它的完整設定。',
    '完成的渲染会保存到 %@，每个视频都附一个 JSON 文件，记录生成它的完整设置。',
    'Fertige Renderings werden unter %@ gesichert, jeweils mit einer JSON-Datei, die die genauen Einstellungen festhält.',
    'تُحفظ عمليات التصيير المنجزة في %@، مع ملف JSON لكل منها يسجّل الإعدادات التي أنتجته بالضبط.')

# ── Remaining engine and onboarding messages ─────────────────────────────────
add('mlx.runtimeNotReady',
    'The Python runtime is not ready. Open Settings › Runtime.',
    'Python 執行環境尚未就緒。請開啟「設定 › 執行環境」。',
    'Python 运行时尚未就绪。请打开“设置 › 运行时”。',
    'Die Python-Umgebung ist nicht bereit. Öffnen Sie „Einstellungen › Laufzeitumgebung“.',
    '\u200fبيئة Python غير جاهزة. افتح «الإعدادات › بيئة التشغيل».')
add('mlx.checkpointMissing',
    'The selected checkpoint is not installed.',
    '所選的檢查點尚未安裝。',
    '所选的检查点尚未安装。',
    'Der gewählte Checkpoint ist nicht installiert.',
    'نقطة التحقّق المختارة غير مثبَّتة.')
add('onboarding.spaceTight',
    'There may not be enough free space once scratch space for rendering is taken into account.',
    '把算圖所需的暫存空間算進來後，可用空間可能不足。',
    '把渲染所需的临时空间算进来后，可用空间可能不足。',
    'Zusammen mit dem temporären Speicher fürs Rendern könnte der freie Platz nicht reichen.',
    'قد لا تكفي المساحة الحرة بعد احتساب المساحة المؤقتة اللازمة للتصيير.')

# ── Settings: what Compose carries over ──────────────────────────────────────
add('settings.remember.section',
    'Compose',
    '編寫',
    '编写',
    'Erstellen',
    'الإنشاء')
add('settings.remember.mode',
    'Remember the last mode',
    '記住上次使用的模式',
    '记住上次使用的模式',
    'Zuletzt verwendeten Modus merken',
    'تذكّر الوضع المستخدم آخر مرة')
add('settings.remember.engine',
    'Remember the last engine',
    '記住上次使用的引擎',
    '记住上次使用的引擎',
    'Zuletzt verwendete Engine merken',
    'تذكّر المحرّك المستخدم آخر مرة')
add('settings.remember.note',
    'Only the mode and the engine. The prompt, the seed and any attached files belong to one render, and always start clear.',
    '只會記住模式與引擎。提示詞、種子與附加檔案屬於單次算圖，每次都會重新開始。',
    '只会记住模式与引擎。提示词、种子与附加文件属于单次渲染，每次都会重新开始。',
    'Nur Modus und Engine. Prompt, Seed und angehängte Dateien gehören zu einem einzelnen Rendering und beginnen immer leer.',
    'الوضع والمحرّك فقط. أما المطالبة والبذرة والملفات المرفقة فتخصّ تصييرًا واحدًا، وتبدأ فارغة في كل مرة.')
