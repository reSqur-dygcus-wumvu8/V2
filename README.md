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
