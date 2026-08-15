# 🎓 EduTrack - Application de Gestion Scolaire Moderne & Multiplateforme

<div align="center">
  <h3>Plateforme Épurée, Performante & Multiplateforme (Android & Web/PWA pour iOS & PC)</h3>
  
  [![Flutter Version](https://img.shields.io/badge/Flutter-3.x-blue.svg)](https://flutter.dev)
  [![Dart Version](https://img.shields.io/badge/Dart-3.x-blue.svg)](https://dart.dev)
  [![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20Web%20PWA-indigo.svg)](https://flutter.dev)
  [![Build Status](https://img.shields.io/badge/CI%2FCD-GitHub%20Actions-blueviolet.svg)](.github/workflows/ci.yml)
  [![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
</div>

---

## 📋 Présentation de EduTrack

**EduTrack** est une application multiplateforme de gestion scolaire de nouvelle génération, conçue pour offrir une expérience utilisateur ultra-fluide, épurée et réactive. Elle centralise les opérations scolaires pour l'ensemble des acteurs : **Administrateurs, Enseignants, Étudiants et Parents**.

---

## ✨ Fonctionnalités Clés

### 🌐 Multiplateforme & PWA Ready
- **Android AppBundle / APK** : Compilation native haute performance.
- **Progressive Web App (PWA)** : Installable directement sur l'écran d'accueil iOS (iPhone/iPad) et PC sans store applicatif.

### 🤖 CI/CD Automatisé sur GitHub Actions
- **Compilation automatique** : Chaque `push` ou `pull_request` sur GitHub déclenche le workflow `.github/workflows/ci.yml`.
- **Génération des Artefacts** : Les paquets Web PWA (`build/web`) et Android AppBundle (`.aab`) sont générés et archivés automatiquement sur GitHub.

### 🎨 Design Épuré & Thème Dynamique (Dark / Light Mode)
- **Design System Material 3** : Typographie soignée, cartes minimalistes, espacements aérés.
- **ThemeNotifier** : Basculement instantané entre Mode Clair, Mode Sombre et Thème Système avec sauvegarde locale (`shared_preferences`).

### 🔗 Architecture API REST Centralisée
- **`ApiConfig` & `ApiService`** : Communication sécurisée avec l'API backend (`https://api.edutrack.com/api`).
- **Authentification JWT** : Gestion automatique des tokens d'accès et des entêtes `Authorization: Bearer <token>`.
- **Services Métiers** : Gestion dynamique de la connexion, des notes/évaluations, du suivi des absences et de l'emploi du temps.

### 🔔 Notifications Push Temps Réel (FCM)
- Intégration de **Firebase Cloud Messaging** sur Android et sur le Web.
- **Service Worker Web (`firebase-messaging-sw.js`)** pour la réception des notifications en arrière-plan.

---

## 👥 Profils Utilisateurs

### 🏫 Administrateurs Scolaires
- Vue d'ensemble statistique de l'établissement (élèves, enseignants, cours, événements).
- Gestion centralisée des utilisateurs et des emplois du temps.
- Publication des annonces et suivi analytique.

### 👨‍🏫 Enseignants
- Consultation des emplois du temps et listes de classe.
- Saisie et validation des notes et évaluations.
- Prise d'appels et gestion du suivi des absences.

### 🎓 Étudiants & 👨‍👩‍👧 Parents
- Consultation en temps réel du bulletin de notes et des moyennes.
- Suivi détaillé des absences, retards et justifications.
- Visualisation de l'emploi du temps interactif et calendrier scolaire.

---

## 🛠️ Instructions d'Installation & Compilation Locale

### Prérequis
- Flutter SDK (>= 3.3.1)
- Dart SDK (>= 3.3.0)

### 1. Cloner le dépôt et installer les dépendances
```bash
git clone https://github.com/votre-depot/school_management_app.git
cd school_management_app
flutter pub get
```

### 2. Lancer l'application en mode Développement Web
```bash
flutter run -d chrome
```

### 3. Compiler pour la Production Web (PWA)
```bash
flutter build web --release
```

### 4. Compiler l'AppBundle Android
```bash
flutter build appbundle
```

---

## 📄 Licence

Ce projet est sous licence [MIT](LICENSE). Vous êtes libre de l'utiliser, le modifier et le distribuer.

© 2026 EduTrack - Tous droits réservés.
