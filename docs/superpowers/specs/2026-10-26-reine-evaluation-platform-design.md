# Skillo — plateforme d'évaluation (design)

Source : backlog `New_BacklogFlutter4J_1.pdf` (7 user stories, projet Flutter en groupe de 4, EduScrum).

## Intention

Application Flutter qui permet à des candidats de passer un test unique par discipline
(Java, Algorithmes, HTML/CSS) et de suivre leurs scores, et à un administrateur de gérer
les questions, consulter les résultats et visualiser des taux de réussite.

## Objectifs / non-objectifs

- Objectifs : couvrir les 7 user stories et tous leurs critères d'acceptance ; code simple,
  en français, qu'un étudiant peut expliquer et refaire ; tests automatisés ; README.
- Non-objectifs : backend distant, multi-appareils synchronisés, i18n, thème sombre custom.
- Anti-objectifs : une archi « clever » impossible à expliquer en soutenance.

## Choix techniques (choix du builder, pas imposés par le backlog)

- Flutter stable 3.47 / Dart 3, cibles **web** (démo) et **Android**.
- Persistance : **SQLite embarqué** via l'API `sqflite_common` : `sqflite` sur Android,
  `sqflite_common_ffi_web` sur web, `sqflite_common_ffi` (en mémoire) dans les tests.
  SQL brut dans de petits repositories, pas de code generation.
- État : `provider` + `ChangeNotifier` (un `AuthState` pour l'utilisateur connecté).
- Graphiques : `fl_chart` (camemberts).
- Mots de passe : hash SHA-256 (`crypto`). Un mot de passe est demandé à l'inscription
  (le backlog n'en parle pas, mais il faut bien se reconnecter).
- Compte admin pré-existant seedé en base : `admin@skillo.app` / `admin123`.
- Questions par défaut seedées depuis `assets/questions/{java,algo,html_css}.json`.

## Modèle de données (SQLite, schéma v1)

- `users(id, role, last_name, first_name, email, password_hash, age, address, motivation, created_at)`
  index unique sur `(last_name COLLATE NOCASE, email COLLATE NOCASE)` (critère US1).
- `questions(id, discipline, text, type, time_limit_s)` — `type` ∈ {`radio`, `checkbox`}.
- `choices(id, question_id, text, is_correct)`.
- `results(id, user_id, discipline, score, total, percent, passed, school_year, taken_at)`
  index unique sur `(user_id, discipline)` (un seul passage par test, US2).

Valeurs fixes :
- Disciplines : `java` « Java », `algo` « Algorithmes », `html_css` « HTML/CSS ».
- Motivations : « Poursuite d'études », « Réorientation », « Reconversion ».
- Année scolaire d'un résultat : `YYYY-YYYY+1` si mois ≥ 9, sinon `YYYY-1-YYYY`.
- Réussite : `percent >= 50`.
- Notation : 1 point par question ; radio = le bon choix sélectionné ; checkbox = ensemble
  sélectionné strictement égal à l'ensemble des bonnes réponses.

## Format JSON d'import (US5, « réinitialiser une catégorie complète »)

```json
{ "discipline": "java",
  "questions": [
    { "text": "…", "type": "radio", "timeLimit": 30,
      "choices": [ { "text": "…", "correct": true }, { "text": "…", "correct": false } ] } ] }
```
Validation : ≥ 2 choix, radio = exactement 1 bonne réponse, checkbox ≥ 1, `timeLimit` > 0,
texte non vide. L'import remplace toutes les questions de la discipline.

## Écrans

Candidat : Connexion, Inscription (nom, prénom, mail, âge, adresse, motivation liste
déroulante, mot de passe), Accueil (3 disciplines avec statut « à passer / score »),
Passage du test (une question à la fois, compte à rebours par question, passage auto à la
suivante à 0, pas de retour arrière), Résultat, Profil (scores + édition adresse/motivation).

Admin (même écran de connexion, rôle `admin`) : Tableau de bord (derniers résultats,
recherche nom/prénom, filtre année scolaire), Questions (liste par discipline, ajout /
édition / suppression, import JSON, réinitialisation depuis les questions par défaut),
Statistiques (camembert réussite/échec par discipline + camembert global pour une année).

## Laissé au builder

Mise en page exacte, textes d'erreur, choix des widgets Material, contenu des questions
par défaut (≈ 8 par discipline).
