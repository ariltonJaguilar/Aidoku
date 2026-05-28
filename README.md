# Aidoku
A free and open source manga reading application for iOS and iPadOS.

## Features
- [x] No ads
- [x] Robust WASM source system
- [x] Online reading through external sources
- [x] Downloads
- [x] Tracker integration (AniList, MyAnimeList)

## Installation

For detailed installation instructions, check out [the website](https://aidoku.app).

### TestFlight

To join the TestFlight, you will need to join the [Aidoku Discord](https://discord.gg/kh2PYT8V8d).

### AltStore

We have an AltStore repo that contains the latest releases ipa. You can copy the [direct source URL](https://raw.githubusercontent.com/Aidoku/Aidoku/altstore/apps.json) and paste it into AltStore. Note that AltStore PAL is not supported.


### How to generate an IPA
#### go to the iOS folder
cd iOS

####  1) build device (puts the build inside iOS/build)
BUILD_DIR=$(pwd)/build xcodebuild -project ../Aidoku.xcodeproj \
  -scheme "Aidoku (iOS)" \
  -configuration Release \
  -sdk iphoneos \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  build

####  2) confirm that the .app exists and is for iphoneos (arm64)
ls -l build/Release-iphoneos/*.app
file build/Release-iphoneos/*.app/*   # shows binary file types
lipo -info build/Release-iphoneos/*.app/* 2>/dev/null || true

####  3) package the .app directly from the correct location
rm -rf Payload
mkdir -p Payload
cp -R build/Release-iphoneos/Aidoku.app Payload/

####  4) verify contents before zipping
ls -l Payload
ls -l Payload/Aidoku.app

####  5) zip and rename
zip -r ../Aidoku_unsigned.ipa Payload
####  return to root folder (optional)
cd ..


### Manual Installation

The latest ipa file will always be available from the [releases page](https://github.com/Aidoku/Aidoku/releases).

## Contributing
Aidoku is still in a beta phase, and there are a lot of planned features and fixes. If you're interested in contributing, I'd first recommend checking with me on [Discord](https://discord.gg/kh2PYT8V8d) in the app development channel.

This repo (excluding translations) is licensed under [GPLv3](https://github.com/Aidoku/Aidoku/blob/main/LICENSE), but contributors must also sign the project [CLA](https://gist.github.com/Skittyblock/893952ff23f0df0e5cd02abbaddc2be9). Essentially, this just gives me (Skittyblock) the ability to distribute Aidoku via TestFlight/the App Store, but others must obtain an exception from me in order to do the same. Otherwise, GPLv3 applies and this code can be used freely as long as the modified source code is made available.

### Translations
Interested in translating Aidoku? We use [Weblate](https://hosted.weblate.org/engage/aidoku/) to crowdsource translations, so anyone can create an account and contribute!

Translations are licensed separately from the app code, under [Apache 2.0](https://spdx.org/licenses/Apache-2.0.html).
