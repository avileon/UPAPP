# android_overlay

`android/` is not committed: CI regenerates it with `flutter create`. Native
code the app needs is kept here and copied over the generated folder by the
"Android overlay" step in the APK workflow in `.github/workflows/`, which also patches
the manifest.

- `kotlin/MainActivity.kt` — replaces the generated one; adds the `up/nfc_card`
  MethodChannel.
- `kotlin/CardHceService.kt` — Host Card Emulation: the phone answers as an NFC
  Forum Type 4 tag holding one NDEF URI record (`https://up.atar.co/c/<token>`).
  Any phone that touches it opens the link, no app needed.
- `res/xml/card_apdu_service.xml` — the NDEF AID the service claims.

Running locally: after `flutter create --org co.vibit.up --project-name up .`,
run `python3 tool/apply_android_overlay.py`.

Kotlin files use `package __PACKAGE__`; the script writes them next to the
generated `MainActivity.kt` with its real package (`co.vibit.up.up` today).
