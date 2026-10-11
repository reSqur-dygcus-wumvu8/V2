# OSINT Suite

Application de veille et de capitalisation du renseignement (OSINT) pour **Mac, iPad et iPhone**,
offline-first, base locale chiffrée **GRDB + SQLCipher**, cotations OTAN (A–F / 1–6),
actions IA via **proxy Mistral** (clé API jamais dans le client), synchronisation optionnelle
**CloudKit + CRDT (Automerge)**, carte **MapLibre** multi-fournisseurs gratuits (IGN, EOX, OSM).

Application compagnon : **Gestionnaire d'accès** (`App/AccessManager`) — coffret de clés
KEK/DEK hors ligne, Secure Enclave, App Intents (Étape 6).

## Structure du monorepo

```
App/
  OSINTSuite/            Application principale (SwiftUI, macOS 14+ / iOS 17+)
  AccessManager/         App compagnon (Étape 6)
Packages/
  PackageDomain/         Entités, cotations OTAN, règles métier (zéro dépendance)
  PackagePersistence/    GRDB + SQLCipher, migrations, FTS5, Keychain, panic wipe
  PackageSync/           CloudKit + CRDT Automerge (optionnel, désactivable)
  PackageIntelligence/   Client du proxy Mistral (résumé, NER, cotation, embeddings)
  PackageNetworking/     RSS/Google News, SocialFeedProvider, file différée
  Features/
    FeatureHome/         Page d'accueil (4 entrées)
    FeatureAcquerir/     Import + veilles
    FeatureCapitaliser/  File d'attente, regroupements, base de connaissance
    FeatureExploiter/    Fiches, graphes, frise, carte
    FeatureGerer/        Doublons, fusion, paramètres
Server/
  ProxyVapor/            Proxy Mistral (Vapor) — détient MISTRAL_API_KEY (.env ignoré)
```

## Démarrage

1. Générer le projet Xcode avec [XcodeGen](https://github.com/yonaskolb/XcodeGen) :
   `brew install xcodegen && xcodegen generate` (voir `docs/XCODE.md` — renseigner le
   Team ID dans `project.yml` avant génération).
2. Déployer le proxy : `cd Server/ProxyVapor && swift run` avec `.env` contenant
   `MISTRAL_API_KEY=…` et `TOKEN_CLIENT=…` (le `.env` est ignoré par Git).
3. Tests : `for p in Packages/PackageDomain Packages/PackagePersistence Packages/PackageNetworking Packages/PackageIntelligence; do (cd $p && swift test); done`

## Sécurité

- Clé Mistral : uniquement côté serveur proxy, jamais dans le client ni dans Git.
- DEK (base) enveloppée par la KEK du Gestionnaire d'accès (Secure Enclave).
- Clé de session transitoire uniquement dans le groupe de trousseau partagé.
- Panic wipe : révocation KEK = base définitivement illisible sur tous les appareils.

## Mode test sans compte développeur (branche `vibe/test-sans-compte-dev-b8bd7b`)

Variante pour tester l'application **sans compte Apple Developer payant** :
suppression des entitlements App Group / trousseau partagé et du Team ID,
remplacement du pont inter-applications par un **déverrouillage manuel**.

### Ce qui change

- `project.yml` : plus d'`application-groups`, plus de `keychain-access-groups`,
  plus de `DEVELOPMENT_TEAM` — signature locale uniquement.
- OSINT Suite : écran verrouillé avec saisie de la **phrase secrète MLA**.
  - *Première utilisation* : bouton « Créer la base » → génère la phrase secrète
    (affichée une seule fois, à noter hors appareil) et crée les archives chiffrées.
  - *Ouvertures suivantes* : saisir la phrase → la base se déchiffre en mémoire.
  - La phrase n'est **jamais stockée** sur l'appareil : sans elle, la base est
    définitivement illisible (même garantie que le mode production).
- Gestionnaire d'accès : fonctionne en local (génération KEK, audit, panic wipe)
  mais **ne peut plus transmettre la clé de session** à OSINT Suite (pas de
  trousseau partagé sans compte payant).

### Limites du mode test

| Fonctionnalité | État |
|---|---|
| Base MLA chiffrée, Tor, veilles, découverte, fiches, graphes, carte | ✅ |
| Installation iPhone/iPad | ⚠️ profil provisoire 7 jours, à resigner chaque semaine |
| Pont AccessManager → OSINTSuite (session automatique) | ❌ (saisie manuelle à la place) |
| TestFlight | ❌ (compte payant requis) |

### Passage en mode production (avec compte payant)

1. Remplacer `__TEAM_ID__` dans `project.yml` (ligne `DEVELOPMENT_TEAM` et les
   `com.apple.security.application-groups`) par votre Team ID réel.
2. Restaurer les blocs entitlements supprimés (cf. historique Git du fichier
   `project.yml`, commit `80763b4`).
3. `xcodegen`, puis signer normalement dans Xcode.
