# Chiffrement et flux de déverrouillage

## Modèle à deux niveaux (MLA)

- **Données au repos** : archives chiffrées au format **MLA (ANSSI)** — segments
  par domaine (entites, documents, veilles, relations, blobs/<uuid>…), chiffrement
  + compression + signatures, option post-quantique via la FFI Rust (xcframework).
- **Secret maître** (matériel de clés MLA) : conservé dans le trousseau privé du
  Gestionnaire d'accès, protégé par le **Secure Enclave** (non extractible) et par
  Face ID / Touch ID + code. Jamais dans le groupe de trousseau partagé.
- **Clé de session** (durée limitée, réglable 5 min–24 h) : seul élément transitoire
  du trousseau partagé ; elle déchiffre le jeu de travail en mémoire.
- **Aucune donnée déchiffrée sur disque** : le moteur reconstruit les index en
  mémoire à l'ouverture et consolide les archives MLA à chaque mise au repos
  (arrière-plan, fermeture, fin de passe du collecteur).

## Flux de déverrouillage

1. OSINT Suite appelle l'App Intent `UnlockDatabaseIntent` du Gestionnaire d'accès.
2. L'utilisateur s'authentifie (biométrie + code) dans le Gestionnaire d'accès.
3. Le Gestionnaire d'accès vérifie la stratégie (appareil autorisé, profil lecture
   seule / complet, plage horaire) et délivre une **clé de session à durée limitée**
   dans le groupe de trousseau partagé — jamais la KEK.
4. OSINT Suite déchiffre les archives MLA **en mémoire** (jeu de travail) ;
5. La clé de session est purgée au passage en arrière-plan ou à expiration ;
   les archives sont consolidées avant fermeture.

## Règles absolues

- La KEK ne quitte **jamais** le Gestionnaire d'accès.
- Le groupe de trousseau partagé ne contient que la clé de session transitoire.
- Aucun secret dans UserDefaults ou dans le dépôt Git (`.env` ignoré).
- Panic wipe : révocation de la KEK → base définitivement illisible partout ;
  effacement local des fichiers binaires et des entrées trousseau du service.

## Limites documentées

- Les éléments du trousseau persistent après désinstallation d'une app (iOS) :
  documenté dans l'aide utilisateur du Gestionnaire d'accès.
- Friction d'usage compensée par la durée de session réglable.

## Branchements production (Étape 6 — suite)

1. **KEK Secure Enclave** : `FournisseurKEKSecureEnclave` (`PackageAcces/FournisseurKEK.swift`)
   stocke la KEK avec `kSecAttrTokenIDSecureEnclave` + AccessControl `userPresence`
   (Face ID / Touch ID, repli code). Le Gestionnaire d'accès l'utilise à son lancement ;
   sur simulateur (pas de Secure Enclave), repli KEK logicielle documenté.
2. **Trousseau partagé** : `TrousseauSessionPartage` (`groupePartage` = Team ID commun,
   ex. `XXXXXXXXXX.fr.osintsuite.shared`). Seule la clé de session (32 octets clé +
   8 octets expiration) y est écrite ; purge à l'expiration ou à l'arrière-plan.
   La KEK n'y est jamais placée.
3. **Flux de déverrouillage complet** :
   - OSINT Suite lit la session (`lireSession`) → déballe la DEK enveloppée
     (stockée dans le trousseau du service principal) → ouvre la base SQLCipher ;
   - sans session : écran verrouillé → App Intent `IntentDeverrouillage` →
     authentification biométrique côté compagnon → session publiée ;
   - passage en arrière-plan : `verrouiller()` purge la session et ferme la base.
4. **Mac hub** : exécutable `Collecteur` (`App/OSINTSuite/Collecteur`) exécuté par le
   LaunchAgent `App/LaunchAgent/com.osintsuite.collecteur.plist` (toutes les 15 min).
   La passphrase DEK est passée en argument au moment de l'installation par l'app
   macOS (jamais stockée en clair sur disque) ; ajuster `__CHEMIN_BASE__`.
5. **Entitlements à configurer dans Xcode** (les deux apps, même Team ID) :
   - Keychain Sharing : groupe `fr.osintsuite.shared` (valeur avec préfixe Team ID) ;
   - App Groups (optionnel, fichiers binaires chiffrés) ;
   - Face ID usage (NSFaceIDUsageDescription) pour le Gestionnaire d'accès.


## Trafic sortant — Tor obligatoire

- Client **Arti embarqué** (FFI Rust, xcframework) : proxy SOCKS5 sur 127.0.0.1 ;
- **Résolution DNS via Tor** (pas de fuite DNS) ;
- La fabrique `ReseauTor` est l'unique point de sortie — aucune requête ne peut
  partir hors Tor (test d'invariant : refus propre si le client est indisponible) ;
- Échecs (plateformes bloquant Tor, circuits coupés) **journalisés** dans le
  journal d'exécution des veilles ; ponts obfs4 configurables dans Paramètres ;
- Conséquences : APNs refusés par défaut (pull via Tor + notifications locales) ;
  CloudKit exclu — la synchronisation passe par un dépôt GitHub privé relevé via
  Tor (deltas CRDT Automerge chiffrés, interface `TransportSync`).
