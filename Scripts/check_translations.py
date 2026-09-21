#!/usr/bin/env python3
"""Verify that everything about the translations agrees with everything else.

    python3 Scripts/check_translations.py

translations.py is the only source of truth. The .lproj/Localizable.strings
files and translation-catalog.json are generated from it, and the app reads the
generated files — so anything that edits one without the others, or edits
translations.py without regenerating, produces a build where the table the
developer reads and the strings the user sees have quietly diverged. Nothing
about that failure is visible: the app still launches, the strings are still
there, they are simply the previous ones.

Five checks, in the order they tend to break:

  1. Generated files match what translations.py would produce right now. This
     catches both halves of the usual mistake — editing the table and not
     rebuilding, and hand-editing a .strings file that says at the top it is
     generated.
  2. Every loc("key") in the Swift source exists in the table. A missing key is
     not a crash; loc falls back to returning the key, so the UI shows
     "compose.generate" where a button label should be.
  3. Every language has the same format placeholders as English. A translation
     that drops a %@ silently loses the value; one that adds a %@ reads
     uninitialised memory through NSString formatting.
  4. Multi-argument strings use positional specifiers (%1$@), without which a
     translator cannot reorder the arguments their grammar needs to move.
  5. Keys nothing references, and translations that fell back to English.

Errors exit non-zero; warnings are printed and do not fail, because both kinds
have legitimate exceptions.
"""
import pathlib, re, sys

sys.path.insert(0, str(pathlib.Path(__file__).parent))
import build_strings as gen
from translations import SOURCE_LANG, T, value

SOURCES = pathlib.Path(__file__).parent.parent / "Sources/Halation"

errors, warnings = [], []

# A format specifier: %@, %d, %1$@, %.1f, %%. The %% is a literal percent and is
# deliberately excluded — it takes no argument.
SPECIFIER = re.compile(r'%(?:(\d+)\$)?[-+ #0]*[\d.*]*(?:hh|h|ll|l|q|L|z|t|j)?([@dioufeEgGxXcsp])')


def specifiers(text):
    """The argument-taking specifiers in a format string, in order."""
    return [(m.group(1), m.group(2)) for m in SPECIFIER.finditer(text.replace('%%', ''))]


def check_generated_files():
    for lang in gen.LANGS:
        path = gen.ROOT / f"{lang}.lproj" / "Localizable.strings"
        expected = gen.render_strings(lang)
        if not path.exists():
            errors.append(f"{path.name} for {lang} is missing")
        elif path.read_text(encoding="utf-8") != expected:
            errors.append(f"{lang}.lproj/Localizable.strings is out of date or was "
                          f"hand-edited — run Scripts/build_strings.py")
    if not gen.CATALOG.exists():
        errors.append("translation-catalog.json is missing")
    elif gen.CATALOG.read_text(encoding="utf-8") != gen.render_catalog():
        errors.append("translation-catalog.json is out of date — run "
                      "Scripts/build_strings.py")


def swift_sources():
    return list(SOURCES.rglob("*.swift"))


def check_swift_language_enum():
    """AppLanguage must list exactly the languages in LANGS.

    Adding a language to translations.py generates its .lproj and everything
    looks done — but the picker in Settings is driven by the Swift enum, so a
    language missing here is translated, shipped, and unreachable. The reverse
    is worse: a case with no .lproj would offer a language that falls back to
    English with no explanation.
    """
    path = SOURCES / "Localization.swift"
    text = path.read_text(encoding="utf-8")
    block = re.search(r"enum AppLanguage[^{]*\{(.*?)\n\}", text, re.S)
    if not block:
        errors.append("could not find the AppLanguage enum in Localization.swift")
        return
    declared = re.findall(r'case\s+\w+\s*=\s*"([^"]+)"', block.group(1))
    for lang in gen.LANGS:
        if lang not in declared:
            errors.append(f"{lang} is in LANGS but not in AppLanguage — it will be "
                          f"built and shipped, but the Settings picker cannot "
                          f"offer it")
    for lang in declared:
        if lang not in gen.LANGS:
            errors.append(f"AppLanguage offers {lang}, which translations.py does "
                          f"not define — it would fall back to English silently")


def check_keys_used_in_code():
    """loc("x") must resolve. Dynamic loc(variable) calls cannot be checked."""
    literal = re.compile(r'\bloc\(\s*"([^"]+)"')
    dynamic = re.compile(r'\bloc\(\s*(?!")')
    referenced, dynamic_count = set(), 0
    for path in swift_sources():
        text = path.read_text(encoding="utf-8", errors="ignore")
        for match in literal.finditer(text):
            key = match.group(1)
            referenced.add(key)
            if key not in T:
                line = text[:match.start()].count("\n") + 1
                errors.append(f'{path.name}:{line} uses loc("{key}"), which is not '
                              f'in translations.py')
        # Subtract the literal hits from the total to count only dynamic ones.
        dynamic_count += len(dynamic.findall(text))
    return referenced, dynamic_count


def check_placeholders():
    """An untranslated language is skipped, not compared: it falls back to the
    English string, so it cannot disagree with it."""
    for key in sorted(T):
        english = specifiers(value(key, SOURCE_LANG))
        for lang in gen.LANGS:
            if lang == SOURCE_LANG:
                continue
            translated = T[key]["values"].get(lang)
            if not translated:
                continue
            other = specifiers(translated)
            if sorted(s[1] for s in other) != sorted(s[1] for s in english):
                errors.append(
                    f"{key} [{lang}] has {len(other)} placeholder(s) but "
                    f"{SOURCE_LANG} has {len(english)} — {translated!r}")


def check_positional():
    """Two or more arguments need %1$@ style, or they cannot be reordered."""
    for key in sorted(T):
        found = specifiers(value(key, SOURCE_LANG))
        if len(found) >= 2 and any(index is None for index, _ in found):
            warnings.append(f"{key} takes {len(found)} arguments without positional "
                            f"specifiers (%1$@); a translator cannot reorder them")


def check_unused(referenced):
    """A key may be referenced outside loc(), e.g. stored as a nameKey, so the
    whole source is searched for the quoted key before calling it unused."""
    blob = "\n".join(p.read_text(encoding="utf-8", errors="ignore")
                     for p in swift_sources())
    for key in sorted(T):
        if key not in referenced and f'"{key}"' not in blob:
            warnings.append(f"{key} is defined but never referenced")


def main():
    check_generated_files()
    check_swift_language_enum()
    referenced, dynamic_count = check_keys_used_in_code()
    check_placeholders()
    check_positional()
    check_unused(referenced)

    print(f"  {len(T)} keys, {len(gen.LANGS)} languages, {len(referenced)} referenced "
          f"by literal, {dynamic_count} dynamic loc() call(s) not checkable")
    gaps = gen.missing_translations()
    if gaps:
        by_lang = {}
        for _, lang in gaps:
            by_lang[lang] = by_lang.get(lang, 0) + 1
        # Summarised rather than listed: a language being added is normally
        # incomplete on purpose, and hundreds of lines saying so would bury the
        # warnings that do need acting on.
        for lang, count in sorted(by_lang.items()):
            warnings.append(f"{lang} has {count} untranslated key(s), showing "
                            f"{SOURCE_LANG}")

    for warning in warnings:
        print(f"  warning: {warning}")
    for error in errors:
        print(f"  ERROR: {error}")

    if errors:
        print(f"\n  {len(errors)} error(s).")
        return 1
    print(f"  OK{f' — {len(warnings)} warning(s)' if warnings else ''}.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
