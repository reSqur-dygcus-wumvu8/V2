# Gestionnaire d'accès (app compagnon)

Application compagnon « Gestionnaire d'accès », entièrement hors ligne, qui détient la KEK
(clé maîtresse) dans le Secure Enclave et délivre des clés de session à durée limitée à
l'application principale via le groupe de trousseau partagé.

Implémentation complète prévue à l'Étape 6 :
- KEK liée au Secure Enclave (kSecAttrTokenIDSecureEnclave), non extractible ;
- authentification Face ID / Touch ID + code ;
- App Intent `UnlockDatabaseIntent` pour le flux de déverrouillage ;
- politiques d'accès (lecture seule / complet, plage horaire), appareils autorisés ;
- journal d'audit local exportable, rotation des clés, phrase de récupération ;
- panic wipe : révocation de la KEK = base définitivement illisible.

Ne jamais placer la KEK dans le groupe de trousseau partagé — uniquement la clé de
session transitoire, purgée au passage en arrière-plan.
