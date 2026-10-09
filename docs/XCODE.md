# Montage Xcode du monorepo (XcodeGen)

Le projet est décrit dans `project.yml` : la commande `xcodegen` génère
`OSINTSuite.xcodeproj` avec les cibles applicatives et le workspace lié aux
packages SPM locaux — aucun réglage manuel à faire dans Xcode.

## 1. Prérequis

- Xcode 15.4+ (Swift 5.10), macOS 14+ ;
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) : `brew install xcodegen`.

## 2. Génération

```bash
# 1. Renseigner le Team ID Apple (3 occurrences dans project.yml) :
#    DEVELOPMENT_TEAM, application-groups, keychain-access-groups
sed -i '' 's/__TEAM_ID__/VOTRE_TEAM_ID/g' project.yml

# 2. Générer le projet
xcodegen generate

# 3. Ouvrir et signer avec votre compte développeur
open OSINTSuite.xcodeproj
```

## 3. Cibles générées

| Cible | Plateformes | Rôle |
|---|---|---|
| `OSINTSuite` | iOS 17+, macOS 14+ | Application principale (4 modules) |
| `AccessManager` | iOS 17+, macOS 14+ | Gestionnaire d'accès (hors ligne, KEK Secure Enclave) |
| `Collecteur` | macOS | CLI du LaunchAgent « Mac hub » |

## 4. Réglages à vérifier après génération

1. **Team ID** : même équipe pour les deux apps (partage trousseau) ;
2. **Entitlements** (générés par XcodeGen depuis project.yml) :
   - `App/OSINTSuite/OSINTSuite.entitlements` — Keychain Sharing, App Group, réseau client ;
   - `App/AccessManager/AccessManager.entitlements` — Keychain Sharing, App Group, **aucun réseau** ;
3. **Bundle IDs** : `fr.osintsuite.app` / `fr.osintsuite.acces` — provisionnés
   via le compte développeur (capacités Keychain Sharing à activer sur l'App ID) ;
4. **MapLibre** : ajouter `https://github.com/maplibre/maplibre-native-ios` aux
   packages du projet depuis Xcode, puis brancher `MLMapView` sur
   `ConfigMapLibre.style(...)` et le `PontTuilesMapLibre` (loopback 127.0.0.1) ;
5. **App Intent** : `IntentDeverrouillage` est détecté automatiquement (cible
   AccessManager) ; vérifier « Type d'extension » dans Signing & Capabilities ;
6. **Synchronisation CloudKit** : activer la capacité iCloud (CloudKit, zone
   privée) sur `OSINTSuite` si la synchronisation est utilisée.

## 5. Installation du LaunchAgent (Mac hub)

```bash
# Compiler le collecteur
xcodebuild -scheme Collecteur -configuration Release build

# Copier le binaire et installer l'agent
mkdir -p /Applications/OSINTSuite.app/Contents/Resources
cp .build/release/collecteur /Applications/OSINTSuite.app/Contents/Resources/

# Renseigner __CHEMIN_BASE__ et __PASSPHRASE__ dans la plist
# (la passphrase est injectée par l'app macOS au premier déverrouillage)
cp App/LaunchAgent/com.osintsuite.collecteur.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.osintsuite.collecteur.plist
```

## 6. Tests et CI

- En local : `swift test` dans chaque package, ou ⌘U dans Xcode ;
- CI GitHub Actions : 9 cibles de test + build Collecteur (runner macOS 14).
