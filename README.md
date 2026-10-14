# bangla-ai-keyboard

An iOS custom keyboard for writing Bangla by typing Banglish. Type `ami bhat khai`, tap **Convert**, and OpenAI turns it into `আমি ভাত খাই।` right inside any app. Each user brings their own OpenAI API key.

## Features

- **AI mode**: type Banglish into the bar above the keys, then Convert. You can **Edit** the result with Bangla keys and a cursor, **Retry**, or **Insert** it. A button on the empty bar converts Banglish already written before the cursor and replaces it in place.
- **English** and **Bangla (phonetic-style)** keyboards that type straight into the app. The `AI / EN / বাং` key cycles between modes.
- **Settings app**: stores the OpenAI API key in the Keychain (shared with the keyboard), lets you pick the model (default `gpt-4o-mini`, or any custom name), has a test conversion, and toggles for key sounds, haptics and adding a space after insert.

## Project layout

| Path | What |
| --- | --- |
| `BanglaKit/` | Swift package with shared logic: OpenAI client, prompt, composer state machine, layouts, storage. Has unit tests. |
| `App/` | SwiftUI host app (setup, try-it, settings). |
| `KeyboardExtension/` | The keyboard (`UIInputViewController` + SwiftUI). |
| `project.yml` | [XcodeGen](https://github.com/yonaskolb/XcodeGen) spec that generates `BanglaKeyboard.xcodeproj`. |

## Build

Requires Xcode 16+ and iOS 17+.

```bash
brew install xcodegen
xcodegen generate
open BanglaKeyboard.xcodeproj
```

Set your team in `DEVELOPMENT_TEAM` in `project.yml` (then re-run `xcodegen generate`). The app and keyboard share the API key through an App Group (`group.com.miraidev.BanglaKeyboard`) and a Keychain access group, so both targets need signing with the same team.

Run the logic tests:

```bash
cd BanglaKit && swift test
```

## Using it

1. Open the app and save your OpenAI API key in the **Settings** tab.
2. Go to Settings › General › Keyboard › Keyboards › Add New Keyboard… and choose **Bangla AI**.
3. Tap **Bangla AI** in that list and turn on **Allow Full Access**. The keyboard needs it to reach OpenAI.
4. In any text field, hold 🌐 and pick Bangla AI.

## Privacy

Only the text you choose to convert is sent to `api.openai.com`, using your own key. Nothing else you type leaves the keyboard.
