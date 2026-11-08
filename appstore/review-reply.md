# Reply to App Review – Math Race Kids 1.0 (build 2)

Paste into the App Store Connect Resolution Center reply / App Review notes.

---

Hello App Review team,

Thank you for the review. We have addressed every point in build 1.0 (2).

**Guideline 2.1 – Information Needed (Kids Category, Guideline 1.3)**

- **Third-party analytics:** None. The app contains no analytics SDKs or services.
- **Third-party advertising:** None. The app shows no ads of any kind.
- **Data shared with third parties:** None. The app does not transmit any data off the device.
- **Other data collection:** None. The app has no accounts, no sign-in, no tracking and makes no network
  requests of its own. It uses no third-party SDKs or packages (no Swift Package Manager or CocoaPods
  dependencies); only Apple frameworks (SwiftUI, StoreKit, AVFoundation). Game settings and recent results are stored
  locally on the device (UserDefaults) and never leave it. The only App Store communication is StoreKit 2
  for the optional one-time in-app purchase, which is handled entirely by Apple.
- The Apple Watch app is a standalone practice game: no purchases, no links, no network access, no data collection.

**Guideline 1.3 – Kids Category (parental gate)**

A parental gate is now shown before every purchase and before every link that leaves the app. The adult must type,
using digits, a random four-digit number that is written out in words (for example “four thousand seven hundred
twelve” → 4712). A wrong answer generates a new number. The gate cannot be turned off. It protects:
- the purchase screen (it appears before the paywall opens, from every entry point), and
- the Privacy Policy, Terms of Use and Support links (in the purchase screen and in Settings → For parents).

The Apple Watch app has no purchases and no external links, so it does not need a gate.

**Guideline 2.1 – App Completeness (in-app purchase)**

The app does not offer any subscriptions. It has a single **non-consumable** in-app purchase,
“Math Race PRO” (product ID `funApp.MathRace.pro`), which unlocks Duel mode, more operations, larger tables and
statistics. It has now been submitted for review together with this build, including its review screenshot.

To test: Settings (gear) → PRO → Unlock PRO → pass the parental gate → the purchase screen shows the product.

**Guideline 3.1.2 – Purchase screen information**

The purchase screen now shows the product title (“Math Race PRO”), that it is a one-time purchase with lifetime
access and not a subscription, the localized price, and links to the Privacy Policy and the Terms of Use
(Apple's standard EULA). The App Store description also ends with the Terms of Use link, and the Privacy Policy
URL is set in App Store Connect.

**Guideline 1.5 – Support URL**

The Support URL now points to a dedicated support page with contact information:
https://joztoz.github.io/mathrace/
Privacy Policy: https://joztoz.github.io/mathrace/privacy.html
Contact: apps@maddog.sk

Thank you,
Jozef Ziak
