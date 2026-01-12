# Stasis
tvOS jailbreak & TrollStore utility to disable OTA software updates.

So far, Stasis has been verified working on:
- tvOS 26.2 (23K54) on Apple TV 4K (1st generation)
- tvOS 15.2 (19K53) on Apple TV (4th generation, HD)

Stasis should support all the way down to tvOS 14.0, but the lowest it's been tested on is 15.2. It'll probably be fine. If your Apple TV is running tvOS 13 or lower, I recommend checking out [Stasis Lite](https://github.com/forcequitOS/StasisLite), which requires a jailbreak to install and doesn't have the fancy UI.

### How does this work?

Stasis is generally rather simple, although it has become more complex to account for more edge cases. This is a general overview of the flow of Stasis' logic.

- Checks if `/var/mobile/Library/Preferences/com.apple.MobileAsset.plist` exists

- **[If]** this exists, and the next file *doesn't exist*, presume updates are *blocked.*

- Checks if `/var/Managed Preferences/mobile/com.apple.MobileAsset.plist` exists

- **[If]** this exists, and it *contains the text "mesu"*, presume updates are *not blocked*, *otherwise*, presume they are.

- **[If]** updates are not being blocked, toggling the button writes files at the two paths mentioned earlier (effectively overwrites a beta profile if you have one installed), and some empty placeholder files where a beta profile would install files to, setting permissions to read-only so that a beta profile can't be installed (Which would interfere with blocking updates).

- **[If]** updates are being blocked, toggling the button removes the files in question instead. (Unless a beta profile is installed and has not been disabled before by Stasis, edge case for upgrading from Stasis 1.x)

- After performing any modifications (and when opening/closing the app), `cfprefsd` and `mobileassetd` are reloaded, no longer needing a reboot to apply changes!

### Install:

Stasis has two installation methods, follow whichever fits your Apple TV best.

**Jailbroken (tvOS 14.0 - 26.x):**

Add the etaTV Repo at https://etatv.forcequit.cc to your package manager and install Stasis.

**TrollStore (tvOS 14.0 - 17.0):**

Open TrollStore, select the Install from URL button, and enter https://etatv.forcequit.cc/stasis.tipa, I will try to keep this .tipa updated and maintained to the best of my ability to avoid typing in a super long GitHub link.

### Credits:

[OTADisabler by ichitaso, the method Stasis is based on is basically copied from it](https://cydia.ichitaso.com/depiction/otadisabler.html)

[Geranium by c22dev, figured out some TrollStore stuff](https://github.com/c22dev/Geranium)

[TrollStore itself (TSUtil.m), to perform killall](https://github.com/opa334/TrollStore)

[ChatGPT, working with plists and doing killall in Swift](https://chat.com)

Have fun blocking updates!

<sub>Note: I'm aware of an edge case where Stasis will be completely unable to block updates for some users, however, more research would have to be done to identify how a fix could be made. If you experience this issue, and have a jailbreakable / jailbroken Apple TV, please report an issue and I'll get in touch with you.</sub>
