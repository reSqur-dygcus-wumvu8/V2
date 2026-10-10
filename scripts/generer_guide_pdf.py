#!/usr/bin/env python3
"""Génération du guide d'installation et d'utilisation de l'OSINT Suite (PDF)."""

from reportlab.lib.pagesizes import A4
from reportlab.lib.units import cm
from reportlab.lib.colors import HexColor
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.enums import TA_LEFT
from reportlab.platypus import (
    BaseDocTemplate, PageTemplate, Frame, Paragraph, Spacer,
    Table, TableStyle, NextPageTemplate, PageBreak, KeepTogether
)

BLEU = HexColor("#1a3c6e")
BLEU_CLAIR = HexColor("#e8eff7")
GRIS = HexColor("#555555")
ACCENT = HexColor("#c0392b")

STYLES = {
    "titre": ParagraphStyle("titre", fontName="Helvetica-Bold", fontSize=26,
                            textColor=BLEU, spaceAfter=6, leading=30),
    "sous_titre": ParagraphStyle("sous_titre", fontName="Helvetica", fontSize=13,
                                 textColor=GRIS, spaceAfter=18, leading=17),
    "h1": ParagraphStyle("h1", fontName="Helvetica-Bold", fontSize=17,
                         textColor=BLEU, spaceBefore=20, spaceAfter=8, leading=21),
    "h2": ParagraphStyle("h2", fontName="Helvetica-Bold", fontSize=13,
                         textColor=BLEU, spaceBefore=13, spaceAfter=5, leading=16),
    "corps": ParagraphStyle("corps", fontName="Helvetica", fontSize=10,
                            leading=14.5, spaceAfter=5, alignment=TA_LEFT),
    "puce": ParagraphStyle("puce", fontName="Helvetica", fontSize=10,
                           leading=14, leftIndent=16, spaceAfter=3),
    "code": ParagraphStyle("code", fontName="Courier", fontSize=9,
                           leading=12.5, backColor=HexColor("#f4f6f8"),
                           borderColor=BLEU_CLAIR, borderWidth=0.5,
                           borderPadding=6, leftIndent=6, rightIndent=6,
                           spaceBefore=4, spaceAfter=6),
    "note": ParagraphStyle("note", fontName="Helvetica-Oblique", fontSize=9.5,
                           leading=13, textColor=GRIS, spaceAfter=6),
    "avertissement": ParagraphStyle("avertissement", fontName="Helvetica-Bold",
                                    fontSize=9.5, leading=13, textColor=ACCENT,
                                    spaceAfter=6),
}


def entete_pied(canvas, doc):
    canvas.saveState()
    # En-tête
    canvas.setFillColor(BLEU)
    canvas.rect(0, A4[1] - 1.1 * cm, A4[0], 1.1 * cm, fill=1, stroke=0)
    canvas.setFillColor(HexColor("#ffffff"))
    canvas.setFont("Helvetica-Bold", 10)
    canvas.drawString(2 * cm, A4[1] - 0.75 * cm, "OSINT Suite — Guide d'installation et d'utilisation")
    # Pied
    canvas.setFillColor(GRIS)
    canvas.setFont("Helvetica", 8)
    canvas.drawString(2 * cm, 1.1 * cm, f"Page {doc.page}")
    canvas.drawRightString(A4[0] - 2 * cm, 1.1 * cm, "Document technique — usage professionnel")
    canvas.setStrokeColor(BLEU_CLAIR)
    canvas.line(2 * cm, 1.5 * cm, A4[0] - 2 * cm, 1.5 * cm)
    canvas.restoreState()


def bloc_note(texte, style="note"):
    return Paragraph(texte, STYLES[style])


def tableau_entetes(entetes, lignes, largeurs):
    donnees = [[Paragraph(f"<b>{e}</b>", STYLES["corps"]) for e in entetes]]
    for ligne in lignes:
        donnees.append([Paragraph(c, STYLES["corps"]) for c in ligne])
    t = Table(donnees, colWidths=largeurs, repeatRows=1)
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), BLEU),
        ("TEXTCOLOR", (0, 0), (-1, 0), HexColor("#ffffff")),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1), [HexColor("#ffffff"), BLEU_CLAIR]),
        ("GRID", (0, 0), (-1, -1), 0.5, BLEU_CLAIR),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("TOPPADDING", (0, 0), (-1, -1), 4),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
        ("LEFTPADDING", (0, 0), (-1, -1), 5),
    ]))
    return t


def contenu():
    f = []
    P = lambda s, st: f.append(Paragraph(s, STYLES[st]))
    code = lambda s: f.append(Paragraph(s.replace("&", "&amp;").replace("<", "&lt;"), STYLES["code"]))
    espace = lambda h=8: f.append(Spacer(1, h))
    puce = lambda s: f.append(Paragraph(f"•  {s}", STYLES["puce"]))

    # ============================ PAGE DE TITRE
    espace(60)
    f.append(Paragraph("OSINT Suite", STYLES["titre"]))
    f.append(Paragraph("Application de veille et de capitalisation du renseignement", STYLES["sous_titre"]))
    f.append(tableau_entetes(
        ["Élément", "Détail"],
        [
            ["Plateformes", "macOS 14+, iPadOS 17+, iOS 17+"],
            ["Architecture", "Monorepo Swift Package Manager, SwiftUI, MVVM"],
            ["Données au repos", "Archives chiffrées MLA (ANSSI) — chiffrement, compression, signatures"],
            ["Cotations", "OTAN / Admiralty Code : source A–F, information 1–6"],
            ["IA", "API Mistral via serveur proxy (clé jamais dans le client)"],
            ["Réseau", "Tout le trafic sortant via Tor (client Arti embarqué, proxy SOCKS5 local)"],
            ["Synchronisation", "Dépôt GitHub privé via Tor — deltas CRDT chiffrés (désactivable)"],
            ["Cartographie", "MapLibre — OSM, IGN (Etalab 2.0), EOX (CC BY 4.0)"],
            ["Application compagnon", "Gestionnaire d'accès : KEK/DEK, Secure Enclave, hors ligne"],
        ],
        [4.2 * cm, 12.3 * cm]))
    espace(14)
    P("Ce guide décrit l'installation complète depuis le dépôt, la configuration "
      "(signature, trousseau, proxy Mistral, LaunchAgent) et l'utilisation au "
      "quotidien des quatre modules, du Gestionnaire d'accès et du collecteur.", "corps")

    f.append(NextPageTemplate("suite"))
    f.append(PageBreak())

    # ============================ 1. PREREQUIS
    P("1. Prérequis", "h1")
    P("Avant de commencer, vérifiez les éléments suivants :", "corps")
    puce("Mac sous macOS 14+ avec Xcode 15.4 ou plus récent (Swift 5.10) ;")
    puce("Compte développeur Apple payant (obligatoire pour le partage de trousseau "
         "entre les deux applications et le Secure Enclave) ;")
    puce("iPhone/iPad sous iOS 17+ / iPadOS 17+ pour les tests mobiles ;")
    puce("XcodeGen (génération du projet) :")
    code("brew install xcodegen")
    puce("Un serveur pour le proxy Mistral (option A validée) : petit VPS, Fly.io ou "
         "Render — ou votre Mac si le proxy reste local ;")
    puce("Abonnement Mistral Pro (clé API Mistral).")
    espace(6)
    P("Répertoire des fichiers clés du dépôt :", "h2")
    f.append(tableau_entetes(
        ["Fichier / dossier", "Rôle"],
        [
            ["project.yml", "Définition XcodeGen du workspace (cibles, entitlements)"],
            ["docs/XCODE.md", "Guide de montage Xcode (détail de chaque réglage)"],
            ["docs/SECURITE.md", "Modèle de chiffrement KEK/DEK et flux de déverrouillage"],
            ["App/OSINTSuite/", "Application principale"],
            ["App/AccessManager/", "Gestionnaire d'accès (compagnon hors ligne)"],
            ["App/LaunchAgent/", "Plist du collecteur Mac hub (15 min)"],
            ["Server/ProxyVapor/", "Proxy Mistral (Vapor) — relais authentifié"],
            ["Packages/", "11 packages SPM (Domain, Persistence, Sync, Intelligence, Networking, Acces, 5 features + accueil)"],
        ],
        [5 * cm, 11.5 * cm]))

    # ============================ 2. INSTALLATION (mode débutant)
    P("2. Installation — mode pas-à-pas pour débutant", "h1")
    f.append(bloc_note(
        "Cette partie part de zéro : aucun prérequis technique. Chaque action est "
        "numérotée, chaque commande est à copier-coller, et chaque étape se termine "
        "par « Ce que vous devez voir » pour vérifier que tout va bien avant de "
        "continuer. Comptez environ 1 à 2 heures la première fois (le plus long "
        "étant le téléchargement de Xcode)."))

    P("2.1 Le vocabulaire indispensable (2 minutes)", "h2")
    f.append(tableau_entetes(
        ["Mot inconnu", "En langage simple"],
        [
            ["Terminal", "L'application Mac où l'on tape des commandes. Ouvrez-le avec Cmd+Espace, tapez « Terminal », Entrée."],
            ["Commande", "Une ligne de texte à copier-coller dans le Terminal, terminée par la touche Entrée."],
            ["Xcode", "L'atelier officiel d'Apple : c'est là que l'on fabrique et lance les applications."],
            ["XcodeGen", "Un petit utilitaire qui fabrique automatiquement le fichier projet à partir de notre fiche de fabrication."],
            ["Team ID", "L'identifiant de votre compte développeur Apple : 10 caractères (lettres et chiffres)."],
            ["project.yml", "La « fiche de fabrication » du projet. Vous n'y toucherez qu'une fois, pour y écrire votre Team ID."],
            ["Schéma (scheme)", "Le menu déroulant en haut de Xcode qui choisit quelle application on lance."],
        ],
        [3.4 * cm, 13.1 * cm]))

    P("2.2 Étape 1 — Installer Xcode", "h2")
    puce("<b>1.</b> Ouvrez l'App Store (icône bleue dans le Dock), cherchez "
         "<b>« Xcode »</b>, cliquez sur <b>Installer</b>. C'est gratuit. Le "
         "téléchargement est long (30 à 60 minutes selon votre connexion).")
    puce("<b>2.</b> À la fin, ouvrez Xcode une première fois : acceptez la "
         "licence (<b>Accept</b>), tapez le mot de passe de votre Mac, "
         "laissez-le finir ses installations.")
    espace(4)
    P("<b>Ce que vous devez voir :</b> une fenêtre « Welcome to Xcode » avec "
      "les boutons Choose a project / Create a new project. Vous pouvez la "
      "fermer.", "corps")

    P("2.3 Étape 2 — Ouvrir le Terminal et installer les petits outils", "h2")
    P("XcodeGen ne s'installe pas par glisser-déposer : on passe par le "
      "Terminal. Rien de compliqué : trois copier-coller.", "corps")
    puce("<b>1.</b> Ouvrez le Terminal (Cmd+Espace, tapez « Terminal », "
         "Entrée). <b>Ce que vous devez voir :</b> une fenêtre avec une ligne "
         "qui se termine par <b>$</b> et un curseur qui clignote.")
    puce("<b>2.</b> Installez Homebrew (le « magasin d'outils » en ligne de "
         "commande) : copiez la ligne ci-dessous, collez-la dans le Terminal, "
         "validez avec Entrée.")
    code('/bin/bash -c "$(' + 'curl -fsSL https://raw.githubusercontent.com/' + 'Homebrew/install/HEAD/install.sh)"')
    f.append(bloc_note(
        "Pendant l'installation, le Terminal peut demander le mot de passe du "
        "Mac (rien ne s'affiche quand vous tapez : c'est normal, tapez-le puis "
        "Entrée). À la toute fin, il peut afficher deux petites commandes "
        "« Next steps » : copiez-collez-les aussi, une par une.", "note"))
    puce("<b>3.</b> Installez XcodeGen :")
    code("brew install xcodegen")
    P("<b>Ce que vous devez voir :</b> le Terminal défile avec des "
      "pourcentages, puis la ligne avec le <b>$</b> revient sans message "
      "d'erreur.", "corps")

    P("2.4 Étape 3 — Récupérer le code de l'application", "h2")
    P("Deux méthodes : la méthode A se fait uniquement à la souris — "
      "commencez par elle.", "corps")
    P("<b>Méthode A (recommandée pour débuter) — à la souris :</b>", "h2")
    puce("<b>1.</b> Ouvrez la page du dépôt dans Safari : github.com, puis "
         "recherchez reSqur-dygcus-wumvu8 / V2 ;")
    puce("<b>2.</b> Cliquez sur le gros bouton <b>vert « Code »</b>, puis "
         "<b>« Download ZIP »</b> ;")
    puce("<b>3.</b> Dans Téléchargements, double-cliquez sur "
         "<b>V2-main.zip</b> pour le décompresser ;")
    puce("<b>4.</b> Glissez le dossier obtenu dans <b>Documents</b> et "
         "renommez-le simplement <b>V2</b> (facile à retrouver ensuite).")
    P("<b>Méthode B — dans le Terminal (une seule commande) :</b>", "h2")
    code("cd ~/Documents &amp;&amp; git clone https://github.com/reSqur-dygcus-wumvu8/V2.git")
    espace(4)
    P("<b>Ce que vous devez voir :</b> un dossier nommé <b>V2</b> dans "
      "Documents, contenant notamment project.yml, Packages et App.", "corps")

    P("2.5 Étape 4 — Trouver votre Team ID", "h2")
    puce("<b>1.</b> Ouvrez Safari sur le site développeur d'Apple, bouton "
         "<b>Account</b>, connectez-vous avec votre identifiant Apple ;")
    puce("<b>2.</b> Cliquez sur votre nom en haut à droite puis <b>View "
         "Account</b> ;")
    puce("<b>3.</b> Cherchez la ligne <b>Team ID</b> : 10 caractères, par "
         "exemple AB12CD34EF ;")
    puce("<b>4.</b> Notez-le sur papier ou dans l'app Notes — vous en aurez "
         "besoin à l'étape suivante.")
    espace(4)
    f.append(bloc_note(
        "Le compte développeur payant (99 $/an) est indispensable pour "
        "installer les applications sur iPhone/iPad et pour le partage de "
        "trousseau entre les deux apps. Sans compte payant, vous pourrez "
        "toujours lancer l'app sur votre Mac et sur le simulateur.", "note"))

    P("2.6 Étape 5 — Mettre votre Team ID dans le fichier project.yml", "h2")
    puce("<b>1.</b> Dans le dossier <b>V2</b> (Documents), double-cliquez sur "
         "le fichier <b>project.yml</b> : il s'ouvre dans TextEdit ;")
    puce("<b>2.</b> IMPORTANT : dans TextEdit, menu <b>Format &gt; Convertir "
         "en texte simple</b> (sinon TextEdit ajoute du gras et le fichier "
         "devient illisible pour l'outil) ;")
    puce("<b>3.</b> Menu <b>Édition &gt; Rechercher &gt; Remplacer</b> : dans "
         "« Rechercher », tapez <b>__TEAM_ID__</b> (deux tirets du 8, "
         "TEAM_ID, deux tirets du 8) ; dans « Remplacer par », collez votre "
         "Team ID ; cliquez <b>Tout</b> : 3 remplacements sont faits ;")
    puce("<b>4.</b> <b>Fichier &gt; Enregistrer</b>, fermez TextEdit.")
    espace(4)
    P("<b>Ce que vous devez voir :</b> dans project.yml, les lignes "
      "« fr.osintsuite.shared » sont précédées de votre Team ID, et il ne "
      "reste aucun <b>__TEAM_ID__</b> dans le fichier.", "corps")

    P("2.7 Étape 6 — Fabriquer le projet Xcode", "h2")
    puce("<b>1.</b> Retournez dans le <b>Terminal</b> ;")
    puce("<b>2.</b> Tapez <b>cd&nbsp;</b> (cd suivi d'un espace, sans "
         "valider), puis glissez-déposez le dossier <b>V2</b> depuis le "
         "Finder jusque dans la fenêtre du Terminal : le chemin s'écrit tout "
         "seul. Validez avec Entrée ;")
    puce("<b>3.</b> Tapez la commande :")
    code("xcodegen generate")
    espace(4)
    P("<b>Ce que vous devez voir :</b> quelques lignes se terminant par "
      "« Created project at .../OSINTSuite.xcodeproj » et un nouveau fichier "
      "<b>OSINTSuite.xcodeproj</b> est apparu dans le dossier V2.", "corps")

    P("2.8 Étape 7 — Ouvrir le projet et activer la signature", "h2")
    puce("<b>1.</b> Double-cliquez sur <b>OSINTSuite.xcodeproj</b> : Xcode "
         "s'ouvre et télécharge les composants (la première fois, patientez) ;")
    puce("<b>2.</b> Dans la colonne de gauche, cliquez sur l'icône en forme "
         "de <b>dossier</b> en haut, puis sélectionnez la ligne "
         "<b>OSINTSuite-macOS</b> (section TARGETS) ;")
    puce("<b>3.</b> Au centre, onglet <b>Signing &amp; Capabilities</b> : "
         "cochez <b>Automatically manage signing</b> si ce n'est pas déjà "
         "fait, puis ouvrez le menu <b>Team</b> et choisissez votre nom "
         "(celui de votre compte développeur) ;")
    puce("<b>4.</b> Recommencez pour les autres cibles : "
         "<b>AccessManager-macOS</b>, puis <b>OSINTSuite-iOS</b> et "
         "<b>AccessManager-iOS</b>.")
    espace(4)
    P("<b>Ce que vous devez voir :</b> à chaque cible, aucun message rouge — "
      "au pire un triangle jaune sur la cible Collecteur (outil macOS sans "
      "impact sur les apps).", "corps")

    P("2.9 Étape 8 — Lancer les applications sur le Mac", "h2")
    puce("<b>1.</b> En haut de Xcode, cliquez sur le menu déroulant à côté de "
         "« OSINTSuite » (le <b>schéma</b>) : choisissez "
         "<b>AccessManager-macOS</b> ;")
    puce("<b>2.</b> Cliquez sur le bouton <b>triangle ▶</b> ou pressez "
         "<b>Cmd+R</b>. La première fois, macOS peut signaler « développeur "
         "non identifié » : faites clic droit sur l'icône de l'app &gt; "
         "<b>Ouvrir</b> ;")
    puce("<b>3.</b> Autorisez l'appareil courant (bouton « Autoriser cet "
         "appareil… ») et générez la phrase de récupération — notez-la sur "
         "papier ;")
    puce("<b>4.</b> Changez le schéma pour <b>OSINTSuite-macOS</b>, relancez "
         "avec <b>▶</b>.")
    espace(4)
    P("<b>Ce que vous devez voir :</b> l'écran « Base verrouillée » de "
      "l'OSINT Suite. Le bouton « Demander le déverrouillage » bascule vers "
      "le Gestionnaire d'accès : la chaîne complète fonctionne.", "corps")

    P("2.10 Ça ne marche pas ? Les 6 pannes classiques", "h2")
    f.append(tableau_entetes(
        ["Message / symptôme", "Solution"],
        [
            ["« command not found: brew » ou « xcodegen »",
             "Homebrew n'a pas fini son installation : relancez l'étape 2.3 et lisez les « Next steps » affichés à la fin (deux commandes à copier-coller)."],
            ["« xcode-select: error » en lançant xcodegen",
             "Xcode n'est pas désigné comme outil par défaut : ouvrez Xcode une fois (étape 2.2), ou collez : sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"],
            ["Pas de nom dans le menu Team",
             "Xcode n'a pas encore récupéré votre compte : Xcode &gt; Settings &gt; Accounts &gt; sélectionnez votre compte &gt; Download Manual Profiles, puis rouvrez le menu Team."],
            ["« Signing ... failed » ou bundle ID en conflit",
             "Un autre développeur utilise fr.osintsuite.app : dans Signing &amp; Capabilities, remplacez le Bundle Identifier par fr.osintsuite.app.votrenom (faites-le aussi pour .acces)."],
            ["project.yml plein de gras ou de couleurs",
             "TextEdit l'a converti en texte riche : refaites l'étape 2.6 en commençant par Format &gt; Convertir en texte simple AVANT de modifier."],
            ["« No such file or directory » avec la commande cd",
             "Vous avez glissé le ZIP au lieu du dossier : décompressez V2-main.zip d'abord, glissez le dossier V2 obtenu."],
        ],
        [5.5 * cm, 11 * cm]))
    espace(6)
    P("Si aucune de ces solutions ne suffit : ouvrez un ticket sur le dépôt "
      "GitHub en copiant le message d'erreur complet (et son numéro de "
      "ligne), la correction sera apportée rapidement.", "corps")

    P("2.11 Installation sur iPhone et iPad", "h2")
    P("Deux méthodes selon votre usage :", "corps")
    P("<b>Méthode A — Développement direct (câble, compte gratuit ou payant)</b>", "corps")
    puce("Connectez l'iPhone/iPad au Mac par câble ;")
    puce("Dans Xcode, sélectionnez votre appareil comme destination "
         "(il doit être enregistré : Signing &amp; Capabilities &gt; Team) ;")
    puce("Schemes <b>OSINTSuite-iOS</b> et <b>AccessManager-iOS</b> : Cmd+R "
         "pour installer et lancer chaque application sur l'appareil ;")
    puce("Sur l'appareil : Réglages &gt; Général &gt; VPN et gestion des "
         "appareils &gt; votre profil développeur &gt; <b>Approuver</b> ;")
    puce("Note : la signature « free » expire tous les 7 jours (réinstaller "
         "via Xcode) ; avec un compte payant, 1 an et jusqu'à 100 appareils.")
    P("<b>Méthode B — TestFlight (compte développeur payant, recommandé)</b>", "corps")
    code("xcodebuild -scheme OSINTSuite-iOS -configuration Release build \\\n"
         "  -archivePath build/OSINTSuite.xcarchive -destination 'generic/platform=iOS'\n"
         "xcodebuild -exportArchive -archivePath build/OSINTSuite.xcarchive \\\n"
         "  -exportOptionsPlist ExportOptions.plist\n"
         "# puis : App Store Connect > TestFlight > téléverser, inviter les testeurs")
    puce("Les testateurs installent via l'app TestFlight depuis "
         "l'invitation ;")
    puce("Renouvelez l'opération pour le <b>AccessManager</b> (les deux apps "
         "doivent être installées sur l'appareil pour le déverrouillage).")
    espace(6)
    P("2.12 Spécificités iPhone/iPad", "h2")
    f.append(tableau_entetes(
        ["Sujet", "Comportement sur iPhone/iPad"],
        [
            ["Exécution en arrière-plan", "iOS n'autorise pas la veille continue : l'appareil est « consomme uniquement » — rafraîchissement à l'ouverture + BGTaskScheduler quand le système le permet"],
            ["Rôle de l'appareil", "Réglages &gt; Gérer &gt; Rôle : laissez « consomme uniquement » ; le Mac collecte (LaunchAgent 15 min) et les résultats arrivent par synchronisation"],
            ["Déverrouillage", "Le Gestionnaire d'accès s'authentifie par Face ID / Touch ID ou code, puis délivre la clé de session à durée limitée"],
            ["Notifications", "Pull via Tor aux rafraîchissements + notifications locales (les APNs contournent Tor : refusés par défaut)"],
            ["Carte hors ligne", "Préchargez la zone AVANT de partir hors connexion (Paramètres ou vue Carte) — le cache tuiles se consulte ensuite sans réseau"],
            ["Fenêtres multiples", "iPadOS : glissez l'app en Split View / Slide Over depuis le Dock (identique macOS)"],
        ],
        [4.5 * cm, 12 * cm]))
    espace(6)
    P("2.13 (Optionnel) Vérifier que tout est bon : les tests automatiques", "h2")
    P("Si vous souhaitez vérifier le code avant de lancer (optionnel) :", "corps")
    code("for p in Packages/PackageDomain Packages/PackageMLA Packages/PackageTor \\\n"
         "        Packages/PackagePersistence Packages/PackageNetworking \\\n"
         "        Packages/PackageIntelligence Packages/PackageSync \\\n"
         "        Packages/PackageAcces; do (cd $p &amp;&amp; swift test); done")
    P("<b>Ce que vous devez voir :</b> à la fin de chaque paquet, une ligne "
      "« TEST SUCCEEDED » en vert. Un « TEST FAILED » rouge : copiez le "
      "message pour le ticket.", "corps")

    # ============================ 3. CONFIGURATION
    f.append(NextPageTemplate("suite"))
    f.append(PageBreak())
    P("3. Configuration", "h1")

    P("3.1 Premier lancement du Gestionnaire d'accès", "h2")
    P("Au premier lancement, le Gestionnaire d'accès :", "corps")
    puce("génère la <b>KEK</b> (clé maîtresse) dans le <b>Secure Enclave</b> — "
         "non extractible, liée au matériel (repli KEK logicielle sur simulateur) ;")
    puce("génère le <b>secret maître MLA</b> (256 bits, base64) qui chiffre "
         "les archives, et l'enveloppe avec la KEK ;")
    puce("propose d'autoriser cet appareil.")
    P("Générez immédiatement la <b>phrase de récupération</b> (menu Actions) : "
      "12 mots affichés <b>une seule fois</b>. Notez-les sur papier et conservez-les "
      "hors de tout appareil — ils sont le seul secours si le Secure Enclave devient "
      "inaccessible (changement d'appareil).", "corps")

    P("3.2 Déverrouillage de l'OSINT Suite", "h2")
    P("Le flux nominal à chaque session :", "corps")
    puce("L'OSINT Suite affiche l'écran « Base verrouillée » ;")
    puce("« Demander le déverrouillage » appelle l'App Intent du Gestionnaire "
         "d'accès ;")
    puce("Vous vous authentifiez (Face ID / Touch ID ou code) ;")
    puce("Une <b>clé de session à durée limitée</b> (1 h par défaut, réglable "
         "de 5 min à 24 h) est publiée dans le groupe de trousseau partagé ;")
    puce("L'OSINT Suite déchiffre les archives MLA <b>en mémoire</b> "
         "(jeu de travail et index reconstruits) ;")
    puce("Au passage en arrière-plan : purge de la session et <b>consolidation</b> "
         "des archives MLA avant fermeture.")
    f.append(bloc_note("La KEK ne quitte jamais le Gestionnaire d'accès : une "
                       "application principale compromise ne peut pas ouvrir la base "
                       "sans validation humaine côté compagnon."))

    P("3.3 Proxy Mistral (option A validée)", "h2")
    P("Déployez le proxy Vapor sur votre serveur (Fly.io, Render, VPS ~4 €/mois "
      "ou Mac local). La clé API Mistral ne quitte jamais ce serveur :", "corps")
    code("cd Server/ProxyVapor\n\n# Fichier .env (JAMAIS commité — .gitignore l'exclut)\n"
         "cat &gt; .env &lt;&lt;'EOF'\nMISTRAL_API_KEY=votre_cle_mistral\n"
         "TOKEN_CLIENT=token_aleatoire_genere_par_vous\nPORT=8080\nEOF\n\n"
         "swift run   # le proxy écoute sur le port 8080")
    P("Testez la disponibilité :", "corps")
    code("curl https://votre-serveur.example.com/sante\n# réponse attendue : ok")
    P("Dans l'OSINT Suite (Paramètres), renseignez l'URL du proxy et le token "
      "client — tous deux stockés dans le <b>Keychain</b>, jamais dans les "
      "réglages en clair.", "corps")

    P("3.4 Collecteur « Mac hub » et LaunchAgent", "h2")
    P("iOS n'autorise pas l'exécution continue en arrière-plan : le Mac est le "
      "collecteur principal, les appareils mobiles consomment les résultats "
      "synchronisés (rafraîchissement opportuniste à l'ouverture + "
      "BGTaskScheduler).", "corps")
    code("xcodebuild -scheme Collecteur -configuration Release build\n"
         "cp .build/release/collecteur /Applications/OSINTSuite.app/Contents/Resources/\n\n"
         "# Renseignez __CHEMIN_BASE__ et __PASSPHRASE__ dans la plist\n"
         "# (injectés par l'app macOS au premier déverrouillage)\n"
         "cp App/LaunchAgent/com.osintsuite.collecteur.plist ~/Library/LaunchAgents/\n"
         "launchctl load ~/Library/LaunchAgents/com.osintsuite.collecteur.plist")
    P("Le collecteur exécute toutes les veilles actives toutes les 15 minutes et "
      "insère les nouveaux éléments dans la base chiffrée locale.", "corps")

    P("3.5 Cartes et tuiles", "h2")
    f.append(tableau_entetes(
        ["Fond", "Usage", "Licence / attribution"],
        [
            ["OpenStreetMap", "Plan (rues, toponymes), téléchargeable hors ligne", "© OpenStreetMap contributors"],
            ["IGN Orthophotos", "Ortho-images France ~20 cm", "Géoplateforme, licence Etalab 2.0"],
            ["EOX Sentinel-2", "Satellite mondial sans nuages ~10 m", "CC BY 4.0, attribution obligatoire"],
        ],
        [3.6 * cm, 7 * cm, 5.9 * cm]))
    espace(4)
    P("Ajoutez le package MapLibre dans Xcode "
      "(https://github.com/maplibre/maplibre-native-ios) : les styles et le pont "
      "de cache tuiles sont déjà implémentés (ConfigMapLibre, "
      "PontTuilesMapLibre — boucle locale 127.0.0.1, cache d'abord, réseau "
      "ensuite). Utilisez « Précharger la zone » dans la vue Carte pour "
      "télécharger à l'avance les tuiles d'une zone et la consulter hors "
      "connexion.", "corps")

    P("3.6 Tor — trafic sortant obligatoire", "h2")
    P("Le client <b>Arti</b> (implémentation officielle Tor) est embarqué dans "
      "l'application et expose un proxy SOCKS5 sur 127.0.0.1 :", "corps")
    puce("<b>Tout</b> le trafic sortant (veilles, tuiles, proxy Mistral, GitHub, "
         "Wikipedia) transite par Tor — aucune exception ;")
    puce("Résolution DNS via Tor : pas de fuite DNS ;")
    puce("Si une plateforme bloque les sorties Tor : échec <b>journalisé</b> dans "
         "le journal d'exécution, aucune donnée perdue ;")
    puce("Ponts obfs4 configurables dans Paramètres (section Tor) ;")
    puce("Conséquences assumées : latence accrue (cache local systématique), "
         "APNs refusés par défaut (tirage périodique + notifications locales), "
         "CloudKit exclu (synchronisation via GitHub/Tor).")
    P("Compilation des xcframeworks Rust (MLA + Arti) :", "h2")
    code("rustup target add aarch64-apple-darwin x86_64-apple-darwin \\\n"
         "                     aarch64-apple-ios aarch64-apple-ios-sim\n"
         "./scripts/build-xcframeworks.sh\n"
         "# puis lier Frameworks/mla.xcframework et Frameworks/tor.xcframework dans Xcode")

    # ============================ 4. UTILISATION
    f.append(NextPageTemplate("suite"))
    f.append(PageBreak())
    P("4. Utilisation quotidienne", "h1")
    P("La page d'accueil présente quatre entrées en grille adaptative :", "corps")

    P("4.1 Acquérir — importer et collecter", "h2")
    P("<b>Import de fichiers</b> (PDF, images, TXT/Markdown, HTML, audio/vidéo) :", "corps")
    puce("Bouton « Choisir un fichier » ou glisser-déposer ;")
    puce("Champs obligatoires : <b>Nom</b>, <b>Date</b>, <b>Source</b> (libellé, "
         "réutilisée ou créée automatiquement), <b>Cotation source A–F</b> ;")
    puce("Le hash SHA-256 détecte les doublons d'import (fichier identique "
         "refusé) ; le texte est extrait automatiquement (TXT/MD/HTML).")
    P("<b>Veilles</b> — onglet Veilles :", "corps")
    puce("Créez une veille Google Actualités (mots-clés), RSS/Atom (URL du flux) "
         "ou réseau social (X/nitter, Telegram t.me/s, Discord bot, TikTok import "
         "manuel) ;")
    puce("Réglez la fréquence (5 min à 24 h) et les <b>mots-clés de priorité</b> ;")
    puce("« Exécuter toutes maintenant » pour un passage immédiat ; activez/"
         "désactivez individuellement ; consultez le <b>journal d'exécution</b> "
         "(date, succès, nombre de nouveaux éléments) ;")
    puce("Chaque nouvel élément atteignant le seuil de priorité déclenche une "
         "<b>notification locale</b> (3 max par passe, pour éviter le spam).")
    f.append(bloc_note("Plateformes sans API publique : TikTok fonctionne par import "
                       "manuel (collez « url | texte », une publication par ligne) ; "
                       "X passe par des flux RSS tiers (nitter) — instables ; "
                       "Discord exige un bot (token dans le Keychain)."))

    P("4.2 Capitaliser — structurer la veille", "h2")
    P("<b>File d'attente</b> : liste chronologique des éléments non traités.", "corps")
    puce("Sélectionnez les informations relatives à un même événement ;")
    puce("Demandez une <b>proposition de cotation Mistral</b> (résumé + cotation "
         "justifiée) — la décision finale reste humaine : validez, modifiez ou "
         "refusez dans le sélecteur A1…F6 ;")
    puce("« Capitaliser » crée le regroupement d'événement avec toutes ses "
         "sources et leurs cotations.")
    P("<b>Base de connaissance</b> — six types de fiches :", "corps")
    f.append(tableau_entetes(
        ["Type", "Champs"],
        [
            ["Individu", "Prénom, nom, biographie, commentaires"],
            ["Organisation", "Dénomination, type, synthèse, commentaires"],
            ["Événement", "Dénomination, date et heure, résumé, commentaires"],
            ["Lieu", "Dénomination, adresse ou coordonnées GPS, résumé, commentaires"],
            ["Objet", "Dénomination, type, précisions (immat., n° série), commentaires"],
            ["Source", "Dénomination, description, cotation A–F"],
        ],
        [3.2 * cm, 13.3 * cm]))
    espace(4)
    puce("À la création d'une fiche, l'application <b>complète automatiquement</b> "
         "les champs (résumé Wikipedia FR puis synthèse Mistral) et propose la "
         "fiche pré-remplie à validation ; les champs auto-remplis portent le "
         "marqueur « [source : internet] » ou « [source : mistral] » jusqu'à "
         "validation ;")
    puce("La <b>reconnaissance d'entités</b> relie automatiquement les entités "
         "existantantes dont le nom apparaît dans le texte ; tout terme peut "
         "aussi être créé comme nouvelle entité (choix du type) ;")
    puce("Chaque fiche est <b>modifiable à la main</b>, avec historique des "
         "modifications (date, champs modifiés) ;")
    puce("Bouton « Exploiter » : ouvre directement le graphe, la frise ou la "
         "carte centrés sur l'entité.")

    # ============================ suite exploitation
    f.append(NextPageTemplate("suite"))
    f.append(PageBreak())
    P("4.3 Exploiter — analyser et visualiser", "h2")
    P("<b>Graphe relationnel</b> :", "corps")
    puce("Centré sur l'entité ciblée (rang 0), cercles concentriques par rang ;")
    puce("Ajoutez ou retirez des <b>rangs</b> (1–4) : rang 1 = directement liées, "
         "rang 2 = liées des liées, etc. ;")
    puce("Clic droit sur un nœud : <b>étendre le graphe</b> depuis cette "
         "entité ;")
    puce("Filtres par type d'entité et cotation minimale ; zoom par pincement ;")
    puce("Clic sur un nœud pour ouvrir la fiche.")
    P("<b>Frise chronologique</b> : événements et regroupements capitalisés, "
      "filtrables par type et cotation ; cartes cliquables vers la fiche.", "corps")
    P("<b>Carte</b> :", "corps")
    puce("Bascule de fond : OSM plan, IGN ortho (France ~20 cm), EOX satellite "
         "(monde ~10 m) ;")
    puce("Épingles cliquables des lieux géolocalisés → fiche ;")
    puce("« Précharger la zone affichée » : téléchargement à l'avance des tuiles "
         "pour consultation hors ligne ; attributions de licence affichées en "
         "permanence.")
    f.append(bloc_note("Limite assumée : en gratuit, la résolution satellite "
                       "mondiale est de ~10 m ; la haute résolution (~20 cm) est "
                       "réservée à la France (IGN)."))

    P("4.4 Gérer — administrer", "h2")
    P("<b>Doublons</b> — validation explicite :", "corps")
    puce("Détection automatique à l'import et à la capitalisation : hash exact, "
         "similarité de texte (Jaccard), dénominations proches ;")
    puce("Écran de revue : « C'est un doublon » / « Ce n'est pas un doublon » — "
         "les paires refusées sont <b>mémorisées et jamais reproposées</b> ;")
    puce("Fusion assistée <b>champ par champ</b> : pour chaque champ, garder A "
         "ou B (concaténation possible pour les commentaires), inversion des "
         "rôles possible ; les relations et sources sont transférées, la "
         "fusion est journalisée.")
    P("<b>Paramètres</b> :", "corps")
    puce("Seuils de similarité doublons (texte, dénominations) ;")
    puce("Fréquence de veille par défaut ; actions automatiques Mistral "
         "activables/désactivables ;")
    puce("Synchronisation via dépôt GitHub privé (via Tor) activable — deltas "
         "CRDT Automerge chiffrés, jamais « dernier écrit gagnant » ;")
    puce("Rôle de l'appareil : <b>collecte</b> (Mac hub, veilles périodiques) ou "
         "<b>consomme uniquement</b> (iPhone/iPad, rafraîchissement à l'ouverture) ;")
    puce("Export de la base (sauvegarde chiffrée) ; <b>effacement complet</b> "
         "(panic wipe) avec confirmation.")
    f.append(bloc_note("Le panic wipe est également disponible côté Gestionnaire "
                       "d'accès : la révocation de la KEK rend la base "
                       "définitivement illisible sur TOUS les appareils.", "avertissement"))

    P("4.5 Utilisation sur iPhone/iPad au quotidien", "h2")
    P("<b>Ouverture type sur mobile</b> :", "corps")
    puce("Ouvrez OSINT Suite → « Base verrouillée » → « Demander le "
         "déverrouillage » ;")
    puce("Bascule vers le Gestionnaire d'accès → Face ID / code ; retour "
         "automatique — la base est ouverte pour la durée de session ;")
    puce("Le rafraîchissement de veille se déclenche à l'ouverture (via Tor) : "
         "les nouveaux éléments du Mac arrivent par synchronisation ;")
    puce("En déplacement : mode hors ligne complet — fiches, graphe, frise et "
         "carte consultables depuis les caches locaux ; saisissez librement, "
         "la synchronisation repartira à la reconnexion ;")
    puce("Les alertes de mots-clés de priorité arrivent en notifications "
         "locales lors des rafraîchissements.")
    espace(4)
    P("4.6 Gestionnaire d'accès — coffret de clés", "h2")
    f.append(tableau_entetes(
        ["Fonction", "Description"],
        [
            ["Appareils autorisés", "Liste des appareils habilités, révocation individuelle"],
            ["Profils", "Lecture seule ou complet, plage horaire éventuelle (à cheval sur minuit supportée)"],
            ["Rotation des clés", "KEK (l'ancienne devient inutilisable) et DEK, à la demande"],
            ["Phrase de récupération", "12 mots, affichés une seule fois, à conserver hors appareil"],
            ["Journal d'audit", "Chaque déverrouillage (date, appareil, succès/échec), exportable JSON"],
            ["Panic wipe", "KEK révoquée = base définitivement illisible partout"],
        ],
        [4.5 * cm, 12 * cm]))
    espace(4)
    P("Limites documentées :", "h2")
    puce("Le groupe de trousseau partagé est accessible à toutes les apps du "
         "groupe : seule la clé de session (transitoire) y est placée, jamais "
         "la KEK ;")
    puce("Les éléments du trousseau persistent après désinstallation d'une "
         "application (limite connue d'iOS) — cf. Aide utilisateur ;")
    puce("Friction d'usage : chaque déverrouillage passe par le Gestionnaire "
         "d'accès ; compensée par la durée de session réglable (5 min à 24 h).")

    # ============================ 5. DEPANNAGE
    f.append(NextPageTemplate("suite"))
    f.append(PageBreak())
    P("5. Dépannage et bonnes pratiques", "h1")
    f.append(tableau_entests := tableau_entetes(
        ["Symptôme", "Cause probable", "Solution"],
        [
            ["« Session absente ou expirée »", "Session purgée (arrière-plan) ou expirée",
             "Redemander le déverrouillage via le Gestionnaire d'accès"],
            ["« Secret MLA non initialisé »", "Premier lancement sans passage par le compagnon",
             "Ouvrir d'abord le Gestionnaire d'accès (il initialise KEK/secret MLA)"],
            ["« Échec via Tor » en boucle", "Plateforme bloquante ou circuit coupé",
             "Vérifier les ponts obfs4 (Paramètres > Tor) ; consulter le journal d'exécution"],
            ["Base illisible après changement d'appareil", "Secure Enclave lié à l'ancien matériel",
             "Restaurer depuis la phrase de récupération (12 mots)"],
            ["« Cette plateforme n'expose pas d'API publique »", "TikTok sans API",
             "Utiliser l'import manuel (url | texte)"],
            ["Veilles sans nouveaux éléments", "Contenu déjà vu (hash) ou veille inactive",
             "Vérifier l'activation et le journal d'exécution"],
            ["Échec des actions Mistral", "Proxy indisponible ou token invalide",
             "curl https://…/sante ; vérifier .env et le Keychain"],
            ["Tuiles manquantes hors ligne", "Zone non préchargée",
             "« Précharger la zone affichée » avant de partir hors connexion"],
            ["Doublon reproposé après refus", "Paires refusées mémorisées par paire non ordonnée",
             "Comportement normal : vérifier que la décision a bien été enregistrée"],
        ],
        [4.6 * cm, 5 * cm, 6.9 * cm]))
    espace(8)
    P("Bonnes pratiques de sécurité :", "h2")
    puce("Ne jamais committer le fichier .env ni aucune clé (le .gitignore "
         "les exclut — vérifiez avant chaque push) ;")
    puce("Conservée hors appareil, la phrase de récupération est le seul "
         "recours : ne pas la photographier ni la stocker en ligne ;")
    puce("Révoquez immédiatement un appareil perdu depuis le Gestionnaire "
         "d'accès ;")
    puce("Exportez régulièrement la base (Paramètres) et conservez la "
         "sauvegarde chiffrée en lieu sûr ;")
    puce("Testez le panic wipe de temps en temps sur un environnement de "
         "test pour vérifier votre procédure de restauration.")
    espace(10)
    P("Pour toute erreur de compilation après génération du projet, "
      "reportez-vous aux messages du compilateur et à la CI GitHub Actions "
      "(9 cibles de test + build du Collecteur), puis ouvrez un ticket sur le "
      "dépôt avec le message complet.", "corps")

    return f


doc = BaseDocTemplate(
    "Guide_OSINT_Suite.pdf",
    pagesize=A4,
    leftMargin=2 * cm, rightMargin=2 * cm,
    topMargin=2 * cm, bottomMargin=2 * cm,
    title="OSINT Suite — Guide d'installation et d'utilisation",
    author="OSINT Suite",
)

frame_titre = Frame(2 * cm, 2 * cm, A4[0] - 4 * cm, A4[1] - 4 * cm, id="titre")
frame_suite = Frame(2 * cm, 2 * cm, A4[0] - 4 * cm, A4[1] - 4.2 * cm, id="suite")

doc.addPageTemplates([
    PageTemplate(id="titre", frames=[frame_titre], onPage=entete_pied),
    PageTemplate(id="suite", frames=[frame_suite], onPage=entete_pied),
])

doc.build(contenu())
print("PDF généré : Guide_OSINT_Suite.pdf")
