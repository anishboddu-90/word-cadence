# Word Cadence

Word Cadence is a native macOS utility for writing text into an open Microsoft Word document at a configurable pace. Use manual text or transcribe photos with your ChatGPT account, then review the text before starting a run.

## Get started

1. Unzip **Word Cadence.zip** and open **Word Cadence.app**. The download is a locally built, ad-hoc-signed app for Apple silicon. The source builds for the architecture of the Mac running the build.
2. Open an editable document in Microsoft Word for Mac. Click Refresh next to **Word destination** and allow Word Cadence to control Word if macOS prompts you. Review this permission under **System Settings → Privacy & Security → Automation**.
3. Choose the document in **Word destination**. Refresh the list if you just opened it.
4. Enter or paste text in **Manual Text**, or follow the photo workflow below.
5. Set the **WPM** and optionally adjust **Corrected typos**. Select **Write to Word**. The app brings the selected Word window forward, restores it if minimized, and appends the text at the end, including any leading line breaks you enter. Save the document in Word when ready.

Use **Pause** and **Resume** to suspend a run. **Stop** leaves the completed text in Word and attempts to remove any temporary typo. Keep Word open and avoid editing the destination during a run. If the document's end changes, the app stops. Protected or read-only documents and documents with Track Changes enabled are rejected.

## Transcribe photos

1. Select **Photos**, then **Continue with ChatGPT**. In your browser, sign in and approve ChatGPT plan usage for Word Cadence. Your account and workspace need to be eligible for this OpenAI integration. The app uses your selected plan and model. See [OpenAI's plan usage guide](https://developers.openai.com/siwc/token-sharing-open-source).
2. Add up to ten photos in any order. Choose a model that accepts images and select **Transcribe & Order**.
3. The review window appears above other apps. Choose a photo to view the source and its transcript. Use the arrows to reorder photos and adjust how they join. Shared overlap text is removed once only when it matches both adjoining transcripts.
4. When ChatGPT asks a question about the order, answer in the review window and select **Ask ChatGPT to revise**, or resolve it directly using the order and transcript controls.
5. Select **Confirm & Use Transcript**, review the resulting text, and select **Write to Word**.

Image data is sent to OpenAI when you request or retry transcription. The app prepares the images locally, strips embedded metadata, and keeps the inputs and drafts in memory. ChatGPT credentials are saved in macOS Keychain. You can disconnect from the account menu or manage access in [ChatGPT settings](https://chatgpt.com/settings/usage).

## Pace and scope

Choose 10–180 WPM. Word response times affect the achieved rate. The pacing engine schedules variable intervals, pauses at text boundaries, and optional corrected substitutions. Word Cadence sends edits through Word's automation interface. [Typing research](docs/typing-research.md)

The review panel floats across regular apps and macOS Spaces. macOS controls visibility over secure screens, system dialogs, and some full-screen environments.

## Build and verify

Requires macOS 14+, Swift 5.10+ and the Xcode Command Line Tools. The app has no third-party build dependencies.

```sh
scripts/build-app.sh
swift run CadenceChecks
swift run WordCadence --verify-word
swift run WordCadence --verify-photos
```

The first command writes `dist/Word Cadence.zip`. The Word check requires an already-running copy of Word and Automation permission. It creates and closes a disposable unsaved document.

The photo check uses synthetic photos and a simulated ChatGPT response. It verifies loopback state, image upload formatting, and the proposed order and questions without using a paid account.
