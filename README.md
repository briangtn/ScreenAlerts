# ScreenAlert

Application macOS qui se loge dans la barre de menu et affiche des alertes plein ecran avant le debut de vos evenements calendrier. Impossible de manquer une reunion, meme en mode plein ecran.

<!-- screenshot: Vue d'ensemble de l'alerte plein ecran -->
<!-- ![Alerte plein ecran](docs/screenshots/alert-fullscreen.png) -->

---

## Table des matieres

- [Fonctionnalites](#fonctionnalites)
  - [Alertes plein ecran](#alertes-plein-ecran)
  - [Integration visioconference](#integration-visioconference)
  - [Snooze et fermeture](#snooze-et-fermeture)
  - [Surveillance des calendriers](#surveillance-des-calendriers)
  - [Selection des calendriers](#selection-des-calendriers)
  - [Interface barre de menu](#interface-barre-de-menu)
  - [Alerte de test](#alerte-de-test)
  - [Demarrage automatique](#demarrage-automatique)
  - [Son d'alerte](#son-dalerte)
- [Parametres](#parametres)
  - [Onglet General](#onglet-general)
  - [Onglet Apparence](#onglet-apparence)
  - [Onglet Calendriers](#onglet-calendriers)
- [Installation](#installation)
- [Compilation](#compilation)
- [Configuration requise](#configuration-requise)
- [Structure du projet](#structure-du-projet)
- [Licence](#licence)

---

## Fonctionnalites

### Alertes plein ecran

Des alertes s'affichent en superposition au-dessus de tout, y compris les applications en mode plein ecran. L'overlay utilise le niveau `CGShieldingWindowLevel` (niveau ecran de veille) et le comportement `canJoinAllSpaces` + `fullScreenAuxiliary`, ce qui garantit la visibilite sur tous les bureaux virtuels (Spaces).

Chaque alerte affiche :
- L'indicateur de couleur du calendrier
- Le titre de l'evenement (police 52pt)
- L'heure de debut (police 32pt)
- Un compte a rebours en temps reel (mis a jour chaque seconde)
- Le nom du calendrier source

Le compte a rebours change de couleur selon l'urgence :
- **Blanc** : plus de 60 secondes avant le debut
- **Orange** : 60 secondes ou moins
- **Rouge** : l'evenement a commence ("Commence maintenant !")

L'alerte apparait avec une animation d'entree (scale + opacite, 0.4s) et disparait en fondu (0.25s).

<!-- screenshot: Alerte avec compte a rebours -->
<!-- ![Compte a rebours](docs/screenshots/alert-countdown.png) -->

<!-- screenshot: Alerte quand l'evenement a commence (rouge) -->
<!-- ![Alerte rouge](docs/screenshots/alert-started.png) -->

### Integration visioconference

ScreenAlert detecte automatiquement les liens de visioconference dans vos evenements et affiche un bouton "Rejoindre" qui ouvre le lien dans votre navigateur par defaut et ferme automatiquement l'alerte.

**Services supportes :**

| Service | Detection |
|---|---|
| Zoom | `zoom.us/j/...` ou `zoom.us/w/...` |
| Google Meet | `meet.google.com/...` |
| Microsoft Teams | `teams.microsoft.com/l/meetup-join/...` |
| Webex | `*.webex.com/...` |
| Slack Huddles | `*.slack.com/...*huddle*...` |

Les liens sont recherches dans cet ordre de priorite :
1. Champ URL de l'evenement
2. Champ lieu (location)
3. Champ notes

<!-- screenshot: Alerte avec bouton Rejoindre (ex: Zoom) -->
<!-- ![Bouton Rejoindre](docs/screenshots/alert-join-button.png) -->

### Snooze et fermeture

- **Snooze** : reporte l'alerte pour une duree configurable. L'alerte reapparaitra meme si l'evenement a deja commence, tant qu'il n'est pas termine.
- **Fermer** : masque definitivement l'alerte pour cet evenement.

Les durees de snooze sont configurables dans les preferences (voir [Parametres](#parametres)).

<!-- screenshot: Boutons snooze dans l'alerte -->
<!-- ![Boutons snooze](docs/screenshots/alert-snooze-buttons.png) -->

### Surveillance des calendriers

L'application surveille en permanence vos calendriers Apple Calendar :

| Parametre | Valeur |
|---|---|
| Fenetre de recherche des evenements | 24 heures |
| Rafraichissement automatique | toutes les 5 minutes |
| Verification des alertes a declencher | toutes les 15 secondes |
| Reaction aux modifications externes | oui (via notification `EKEventStoreChanged`) |

### Selection des calendriers

Choisissez quels calendriers surveiller grace a des toggles individuels par calendrier, avec indicateur de couleur et nom de la source. Des boutons "Tout activer" / "Tout desactiver" permettent de gerer rapidement la selection.

<!-- screenshot: Onglet Calendriers dans les preferences -->
<!-- ![Selection calendriers](docs/screenshots/settings-calendars.png) -->

### Interface barre de menu

L'application vit exclusivement dans la barre de menu (pas d'icone dans le Dock). L'icone change selon l'etat :
- `bell.badge` : actif
- `bell.slash` : en pause

Le menu deroulant affiche :
- La liste des prochains evenements (jusqu'a 10), avec : barre de couleur du calendrier, titre, plage horaire, icone video si applicable, temps restant relatif
- Bouton de declenchement manuel d'alerte par evenement (au survol)
- Bouton Pause / Reprendre
- Bouton de test d'alerte
- Lien vers les Preferences
- Bouton Quitter

**Etats speciaux :**
- Sans acces calendrier : message explicatif + bouton vers Reglages Systeme
- Aucun evenement : "Aucun evenement a venir"

<!-- screenshot: Menu barre de menu avec liste d'evenements -->
<!-- ![Menu barre de menu](docs/screenshots/menubar-events.png) -->

<!-- screenshot: Menu barre de menu en etat pause -->
<!-- ![Menu en pause](docs/screenshots/menubar-paused.png) -->

### Alerte de test

Un bouton dans la barre de menu permet de declencher une alerte de test. Celle-ci cree un faux evenement "Reunion de test" debutant dans 30 secondes, d'une duree d'1 heure, avec un faux lien Zoom pour tester le bouton "Rejoindre".

### Demarrage automatique

L'application peut demarrer automatiquement a l'ouverture de session via l'API `SMAppService` (ServiceManagement). Cette option est activee par defaut au premier lancement et peut etre desactivee dans les preferences.

### Son d'alerte

Trois modes de son disponibles :
- **Bip systeme** : son par defaut
- **Son systeme nomme** : choix parmi les sons disponibles dans `/System/Library/Sounds` et `/Library/Sounds`
- **Fichier audio personnalise** : selection via un selecteur de fichiers (formats : mp3, wav, aiff)

Un bouton d'apercu permet d'ecouter le son choisi directement dans les preferences.

<!-- screenshot: Configuration du son dans les preferences -->
<!-- ![Reglages son](docs/screenshots/settings-sound.png) -->

---

## Parametres

Tous les parametres sont persistes via `UserDefaults` et synchronises automatiquement.

### Onglet General

| Parametre | Description | Valeurs possibles | Defaut |
|---|---|---|---|
| Delai d'alerte | Minutes avant l'evenement pour declencher l'alerte | 1, 2, 3, 5, 10, 15 min | 1 min |
| Durees de snooze | Durees proposees pour le bouton snooze | 1, 2, 3, 5, 10, 15, 30, 60 min (choix multiple) | 1, 5, 15 min |
| Son d'alerte | Activer/desactiver le son | oui / non | oui |
| Choix du son | Son systeme ou fichier personnalise | bip systeme, sons systeme, fichier mp3/wav/aiff | bip systeme |
| Demarrage automatique | Lancer l'app a l'ouverture de session | oui / non | oui (au 1er lancement) |
| Evenements journee entiere | Inclure les evenements "toute la journee" | oui / non | non |

<!-- screenshot: Onglet General des preferences -->
<!-- ![Preferences General](docs/screenshots/settings-general.png) -->

### Onglet Apparence

| Parametre | Description | Valeurs possibles | Defaut |
|---|---|---|---|
| Afficher sur tous les ecrans | Alerte sur tous les moniteurs ou ecran principal uniquement | oui / non | oui |
| Opacite de l'overlay | Opacite du fond de l'alerte | 0.30 a 1.00 (pas de 0.05) | 0.88 |
| Couleur de l'overlay | Couleur de fond de l'alerte | selecteur RGB | noir (0, 0, 0) |
| Couleur d'accentuation | Couleur du bouton "Rejoindre" | selecteur RGB | vert (0, 0.8, 0) |

<!-- screenshot: Onglet Apparence des preferences -->
<!-- ![Preferences Apparence](docs/screenshots/settings-appearance.png) -->

### Onglet Calendriers

| Parametre | Description |
|---|---|
| Calendriers surveilles | Toggles individuels par calendrier avec indicateur de couleur et nom de la source |
| Tout activer / Tout desactiver | Boutons de selection rapide |

<!-- screenshot: Onglet Calendriers des preferences -->
<!-- ![Preferences Calendriers](docs/screenshots/settings-calendars-tab.png) -->

---

## Installation

1. Telecharger `ScreenAlert.zip` depuis la [derniere release](https://github.com/briangtn/ScreenAlerts/releases/latest)
2. Dezipper l'archive
3. Copier `ScreenAlert.app` dans `/Applications`
4. Lancer l'app -- elle apparaitra dans la barre de menu
5. Autoriser l'acces au calendrier quand macOS le demande

## Compilation

```bash
# Build debug
./build.sh

# Build release (optimise)
./build.sh release

# Build debug + lancement
./build.sh run
```

Le script de build :
1. Compile via Swift Package Manager (`swift build`)
2. Cree le bundle `.app` (`Contents/MacOS`, `Contents/Resources`)
3. Copie le binaire et `Info.plist`
4. Signe en ad-hoc avec les entitlements requis (`codesign --force --sign -`)
5. Installe dans `/Applications`

## Configuration requise

- macOS 14.0 (Sonoma) ou ulterieur
- Apple Silicon (arm64)
- Acces au calendrier (permission demandee au lancement)

## Structure du projet

```
Sources/
├── ScreenAlertApp.swift              # Point d'entree (@main), MenuBarExtra + Settings
├── AppDelegate.swift                 # Cycle de vie, demande d'acces calendrier
├── AppState.swift                    # Etat observable singleton (UserDefaults)
├── Managers/
│   └── FullScreenWindowManager.swift # Gestion NSPanel niveau ecran de veille, multi-ecran
├── Models/
│   ├── CalendarEvent.swift           # Modele evenement (wrapping EKEvent)
│   └── VideoLink.swift               # Detection liens visio (Zoom, Meet, Teams, Webex, Slack)
├── Services/
│   ├── AlertScheduler.swift          # Boucle 15s, declenchement alertes, snooze/dismiss
│   └── CalendarService.swift         # Acces EventKit, rafraichissement, observation changements
└── Views/
    ├── AlertOverlayView.swift        # UI alerte plein ecran (compte a rebours, boutons)
    ├── MenuBarView.swift             # Menu deroulant barre de menu (liste evenements)
    └── SettingsView.swift            # Preferences 3 onglets (General, Apparence, Calendriers)
```

## Licence

All rights reserved.
