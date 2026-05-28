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
Xcode>Product>Show build folder in finder

####  package the .app directly from the correct location
rm -rf Payload
mkdir -p Payload
cp -R Aidoku.app Payload/

####  5) zip and rename — the IPA is created at the project root: Aidoku/Aidoku_unsigned.ipa
zip -r ../Aidoku_unsigned.ipa Payload

### Signing for Personal Developer Account

If you're building with a free/personal Apple ID (no paid Apple Developer Program), some capabilities (iCloud, Push Notifications, system-wide fonts) are not supported by personal teams. To build and run on your device while keeping the widget working, use the provided lightweight entitlements file:

1. Open the workspace in Xcode and select the **Aidoku (iOS)** target.
2. In **Build Settings**, search for **Code Signing Entitlements** and set the value to:

	iOS/iOS-Personal.entitlements

3. In **Signing & Capabilities**, set your **Team** to your personal account (e.g. "Arilton Aguilar").
4. Ensure **App Groups** contains `group.app.aidoku.Aidoku` (this is required for the widget to share data).

To restore full capabilities later (after you upgrade to a paid developer account), change **Code Signing Entitlements** back to:

	iOS/iOS.entitlements

### Manual Installation

The latest ipa file will always be available from the [releases page](https://github.com/Aidoku/Aidoku/releases).

## Contributing
Aidoku is still in a beta phase, and there are a lot of planned features and fixes. If you're interested in contributing, I'd first recommend checking with me on [Discord](https://discord.gg/kh2PYT8V8d) in the app development channel.

This repo (excluding translations) is licensed under [GPLv3](https://github.com/Aidoku/Aidoku/blob/main/LICENSE), but contributors must also sign the project [CLA](https://gist.github.com/Skittyblock/893952ff23f0df0e5cd02abbaddc2be9). Essentially, this just gives me (Skittyblock) the ability to distribute Aidoku via TestFlight/the App Store, but others must obtain an exception from me in order to do the same. Otherwise, GPLv3 applies and this code can be used freely as long as the modified source code is made available.

### Translations
Interested in translating Aidoku? We use [Weblate](https://hosted.weblate.org/engage/aidoku/) to crowdsource translations, so anyone can create an account and contribute!

Translations are licensed separately from the app code, under [Apache 2.0](https://spdx.org/licenses/Apache-2.0.html).

## Atualizando do upstream

Se você der um `git pull` do repositório upstream, o arquivo `project.pbxproj` pode ser sobrescrito e as referências das suas configurações pessoais (`Aidoku-IOS-Personal.xcconfig` e `AidokuWidget-Personal.xcconfig`) podem ser removidas.

Siga estes passos rápidos após atualizar do upstream para reaplicar o patch localmente:

1. Verifique que os arquivos pessoais existem:

- `iOS/Aidoku-IOS-Personal.xcconfig`
- `AidokuWidget/AidokuWidget-Personal.xcconfig`
- `iOS/iOS-Personal.entitlements`

2. A partir do diretório raiz do repositório, execute o seguinte comando no Terminal para reaplicar a modificação ao `project.pbxproj` (irá inserir referências e ajustar os build configs):

```bash
python3 << 'PYEOF'
import re, sys
pbxproj = 'Aidoku.xcodeproj/project.pbxproj'
with open(pbxproj, 'r') as f:
	content = f.read()
original = content
IOS_UUID    = 'AA01AA01AA01AA01AA01AA01'
WIDGET_UUID = 'AA02AA02AA02AA02AA02AA02'
old_ios_ref = ('91D7BEF72DD7E46800898539 /* Aidoku-IOS.xcconfig */ = '
			   '{isa = PBXFileReference; lastKnownFileType = text.xcconfig; '
			   'path = "Aidoku-IOS.xcconfig"; sourceTree = "<group>"; };')
new_ios_ref = (old_ios_ref + '\n'
			   f'\t\t{IOS_UUID} /* Aidoku-IOS-Personal.xcconfig */ = '
			   '{isa = PBXFileReference; lastKnownFileType = text.xcconfig; '
			   'path = "Aidoku-IOS-Personal.xcconfig"; sourceTree = "<group>"; };\n'
			   f'\t\t{WIDGET_UUID} /* AidokuWidget-Personal.xcconfig */ = '
			   '{isa = PBXFileReference; lastKnownFileType = text.xcconfig; '
			   'path = "AidokuWidget-Personal.xcconfig"; sourceTree = "<group>"; };')
if old_ios_ref not in content:
	print("ERROR: Aidoku-IOS.xcconfig file reference not found"); sys.exit(1)
content = content.replace(old_ios_ref, new_ios_ref, 1)
old_child = '\t\t\t\t91D7BEF72DD7E46800898539 /* Aidoku-IOS.xcconfig */,'
new_child  = (old_child + '\n'
			  f'\t\t\t\t{IOS_UUID} /* Aidoku-IOS-Personal.xcconfig */,')
if old_child not in content:
	print("ERROR: iOS group child entry not found"); sys.exit(1)
content = content.replace(old_child, new_child, 1)
old_base = '91D7BEF72DD7E46800898539 /* Aidoku-IOS.xcconfig */'
new_base = f'{IOS_UUID} /* Aidoku-IOS-Personal.xcconfig */'
if content.count(f'baseConfigurationReference = {old_base};') == 0:
	print("ERROR: baseConfigurationReference for Aidoku-IOS.xcconfig not found"); sys.exit(1)
content = content.replace(
	f'baseConfigurationReference = {old_base};',
	f'baseConfigurationReference = {new_base};'
)
def patch_widget_config(src, config_uuid, config_name):
	marker = f'{config_uuid} /* {config_name} */ = {{\n\t\t\tisa = XCBuildConfiguration;'
	if marker not in src:
		print(f"ERROR: widget {config_name} config ({config_uuid}) not found"); sys.exit(1)
	src = src.replace(
		marker,
		(f'{config_uuid} /* {config_name} */ = {{\n'
		 f'\t\t\tisa = XCBuildConfiguration;\n'
		 f'\t\t\tbaseConfigurationReference = {WIDGET_UUID} /* AidokuWidget-Personal.xcconfig */;'),
		1
	)
	src = src.replace(
		'PRODUCT_BUNDLE_IDENTIFIER = app.aidoku.Aidoku.AidokuWidget;',
		'PRODUCT_BUNDLE_IDENTIFIER = "$(APP_ID_PREFIX).$(APP_ID_SUFFIX).AidokuWidget";',
		1
	)
	return src
content = patch_widget_config(content, 'EAADDC682FC7D84D006BBB6D', 'Debug')
content = patch_widget_config(content, 'EAADDC692FC7D84D006BBB6D', 'Release')
if content != original:
	with open(pbxproj, 'w') as f:
		f.write(content)
	print('OK: project.pbxproj patched')
else:
	print('No changes necessary')
PYEOF
```

3. Reabra o projeto no Xcode e confirme em **Signing & Capabilities** que os alvos `Aidoku` e `AidokuWidget` estão usando seu **Team** pessoal e que o App Group `group.app.aidoku.Aidoku` está habilitado.

Se preferir, copie este comando para um arquivo de script local e rode-o sempre que precisar reaplicar o patch após um merge/pull do upstream.

