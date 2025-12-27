# Stasis
tvOS jailbreak & TrollStore utility to disable OTA software updates.

So far, Stasis has been verified working on:
- tvOS 26.2 (23K54) on Apple TV 4K (1st generation)

You absolutely **must** (userspace) reboot your Apple TV after disabling/enabling updates for changes to apply! I have warning in the app too for good measure. Please don't harass me if your Apple TV auto-updates just because you didn't restart after applying.

Stasis should support all the way down to tvOS 14.0, but I only have my one tvOS 26 Apple TV to test on. It'll probably be fine. If your Apple TV is running tvOS 13 or lower, I recommend checking out [Stasis Lite](https://github.com/forcequitOS/StasisLite), which requires a jailbreak to install and doesn't have the fancy UI.

This is a really simple app. I would have included tvOS 13.x support, but SwiftUI on appleOS 13 is miserable. All it does is...

- Checks if /var/mobile/Library/Preferences/com.apple.MobileAsset.plist exists
- If it does, pressing the toggle button removes it, as updates were likely disabled using it
- If it doesn't, pressing the toggle button writes it there with some really simple contents.

### Install:

Stasis has two installation methods, follow whichever fits your Apple TV best.

**Jailbroken (tvOS 14.0 - 26.x):**

Add the etaTV Repo at https://etatv.forcequit.cc to your package manager and install Stasis

**TrollStore (tvOS 14.0 - 17.0):**

Open TrollStore, select the Install from URL button, and enter https://etatv.forcequit.cc/stasis.tipa, I will try to keep this .tipa updated and maintained to the best of my ability to avoid typing in a super long GitHub link.

### Credits:

[OTADisabler by ichitaso, the entire method Stasis uses is basically copied from it](https://cydia.ichitaso.com/depiction/otadisabler.html)

[Geranium by c22dev, figured out some TrollStore stuff](https://github.com/c22dev/Geranium)

Have fun blocking updates!