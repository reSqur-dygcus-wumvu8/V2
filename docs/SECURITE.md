# Chiffrement et flux de déverrouillage

## Modèle à deux niveaux

- **DEK** (Data Encryption Key, 256 bits) : passphrase SQLCipher de la base GRDB ;
  chiffre aussi les fichiers binaires (dérivation par fichier).
- **KEK** (Key Encryption Key) : clé maîtresse générée et liée au **Secure Enclave**
  du Gestionnaire d'accès (`kSecAttrTokenIDSecureEnclave`, non extractible),
  protégée par Face ID / Touch ID + code.
- La DEK est stockée **enveloppée** par la KEK dans le trousseau partagé (Team ID commun).

## Flux de déverrouillage

1. OSINT Suite appelle l'App Intent `UnlockDatabaseIntent` du Gestionnaire d'accès.
2. L'utilisateur s'authentifie (biométrie + code) dans le Gestionnaire d'accès.
3. Le Gestionnaire d'accès vérifie la stratégie (appareil autorisé, profil lecture
   seule / complet, plage horaire) et délivre une **clé de session à durée limitée**
   dans le groupe de trousseau partagé — jamais la KEK.
4. OSINT Suite déballe la DEK avec la clé de session et ouvre la base.
5. La clé de session est purgée au passage en arrière-plan ou à expiration
   (durée réglable de 5 minutes à 24 heures).

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
