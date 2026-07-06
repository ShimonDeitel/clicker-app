# Clicker - Universal TV Remote

One-line: a TV remote that actually looks and feels good, for Roku, Samsung, and LG over local Wi-Fi.

## Why (queue slot 3)
Biggest proven category: $11M/mo consumer spend, 21 apps grossing $1M+/yr with nameless, ugly incumbents (Appfigures). Caveat known: most winners also run Apple Search Ads; this is the one queue app where a small ASA budget is likely required.

## v1 scope
- Protocols, local network only, no cloud: Roku ECP (HTTP :8060), Samsung Tizen (websocket :8001/:8002, token pairing), LG webOS (websocket :3000/:3001, pairing prompt). Android TV deferred to v2 (protobuf pairing).
- Discovery: Bonjour where available + SSDP. IMPORTANT: SSDP needs the RESTRICTED entitlement com.apple.developer.networking.multicast - request it from Apple EARLY (approval lead time, days to weeks). Fallback that always works: manual IP entry + saved devices.
- Core remote: power, volume, mute, d-pad, back/home, keyboard input (Roku/Samsung text), app-launch shortcuts (Netflix etc. via protocol deep links).
- Quirky hook: "couch radar" - a sonar-style sweep animation while discovering TVs; found TVs ping onto the radar with haptics.

## Monetization
- Free: full remote for 1 saved TV. Pro: unlimited TVs + keyboard input + app shortcuts + custom button layout.
- clicker_pro_monthly $4.99/mo, clicker_pro_yearly $29.99/yr. Transparent paywall on adding TV #2.

## ASO
- Name: "Clicker - Universal TV Remote". Subtitle: "Roku, Samsung and LG remote".
- Keywords: tv remote, universal remote, roku remote, samsung tv remote, lg remote.
- 4.3 spam risk in this category: the bespoke design IS the defense; nothing template.

## Design direction (bespoke)
- Feel: late-night living room. Near-black blue-charcoal, one neon-teal accent, soft-glow buttons like backlit hardware keys, big rubbery press deformation with strong haptics. Rounded-square hardware-remote silhouette.
- Signature motion: buttons depress with squash physics and glow trails; the couch radar sweep; volume as an arc that fills with light.

## Technical
- Native SwiftUI, iOS 26, XcodeGen, com.deitel.clicker, W7Q885Q59C, conventions from Attic/project.yml.
- Network framework (NWConnection/NWBrowser for Bonjour), URLSession for ECP, URLSessionWebSocketTask for Samsung/LG.
- Info.plist: NSLocalNetworkUsageDescription + NSBonjourServices list. Multicast entitlement gated on Apple approval; ship v1 without SSDP if not granted (Bonjour + manual IP).
- No external APIs, no keys. Test protocol clients against real hardware or community simulators; every button must work first-try on a real TV before submission.

## Status
- 2026-07-06: spec written. Build starts after Crate's design pass.
