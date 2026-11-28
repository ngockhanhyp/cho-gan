# Passy languages

Passy supports Vietnamese (`vi`), English (`en`), and Korean (`ko`). The language picker is in the app header and on the story, privacy and terms pages. It persists with SharedPreferences key `passy.language`; static pages share `flutter.passy.language` (JSON encoded) and `passy.language`. Explicit `?lang=en` / `?lang=ko` links select a language, and changing the app language updates the URL without replacing other query parameters or fragments.

Interface source strings remain Vietnamese. `locales/app.json` and `locales/pages.json` contain English/Korean pairs; run `node tool/generate_locales.cjs` after editing them. Dynamic placeholders must be preserved in both translations. Runtime files are `lib/i18n.dart`, `lib/i18n_catalog.dart` and `web/story-assets/story-language.js` / `translations.js`. Static pages translate before the existing motion script splits text, retaining Vietnamese grapheme handling and Korean font fallback.

Database category/location values are unchanged. Item titles, message bodies, personal names and geographic names are not machine-translated. Application-owned labels and the standard condition prefix are localized while preserving the rest of each description. Currency stays VND. Uploaded content and third-party/server error text may retain their original language.

Validation: bilingual placeholder coverage and persistence/widget tests, existing location/social-auth/listing semantics tests, release web build, and browser checks for English/Korean home, sign-in, story text and language picker. The analyzer has no errors; existing advisory warnings are outside this change.

Direct links: `https://passy.id.vn/?app=1&lang=en`, `https://passy.id.vn/?app=1&lang=ko`, and `story.html?lang=en` / `story.html?lang=ko`.
