# Reine — plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Application Flutter couvrant les 7 user stories du backlog (candidats : inscription, test unique par discipline, profil ; admin : connexion, questions, tableau de bord, camemberts).

**Architecture:** App Flutter mono-package. Couche `data/` (SQLite via `sqflite_common`, repositories SQL brut), `models/` (classes + enums), `state/` (`AuthState` ChangeNotifier), `screens/` par rôle. Les repositories sont testés avec `sqflite_common_ffi` en mémoire.

**Tech Stack:** Flutter 3.47 / Dart 3.13, `sqflite`, `sqflite_common_ffi`, `sqflite_common_ffi_web`, `provider`, `fl_chart`, `crypto`, `intl`.

**Spec:** `docs/superpowers/specs/2026-10-26-reine-evaluation-platform-design.md`

## Global Constraints

- UI en français. Disciplines : `java` « Java », `algo` « Algorithmes », `html_css` « HTML/CSS ».
- Motivations : « Poursuite d'études », « Réorientation », « Reconversion ».
- Un seul résultat par `(user_id, discipline)` ; un seul compte par `(nom, email)` insensible à la casse.
- Réussite = `percent >= 50`. Année scolaire = `YYYY-YYYY+1` si mois ≥ 9 sinon `YYYY-1-YYYY`.
- Admin seedé : `admin@reine.app` / `admin123`.
- `flutter analyze` sans erreur, `flutter test` vert, `flutter build web` OK.

## Review Focus

1. Email saisi avec majuscules/espaces → l'inscription et la connexion doivent matcher (normaliser `trim().toLowerCase()`). Test dans Task 3.
2. Timer à 0 sans réponse cochée → la question compte faux et on passe à la suivante sans crash. Test dans Task 7.
3. JSON d'import invalide (discipline inconnue, radio avec 2 bonnes réponses) → refusé avec message, aucune question supprimée. Test dans Task 4.
4. Suppression d'une question en cours de test → le test en cours garde sa liste chargée en mémoire (pas de relecture DB pendant le test). Vérifié par construction dans Task 7.
5. Recherche admin « dupont » vs nom « DUPONT » → insensible à la casse. Test dans Task 5.

---

### Task 1 : Scaffold, dépendances, base de données

**Files:** `pubspec.yaml`, `lib/data/app_database.dart`, `lib/data/db_factory.dart`, `lib/data/db_factory_web.dart` (conditional import), `assets/questions/{java,algo,html_css}.json`, `assets/questions/README.md`, `test/data/app_database_test.dart`.

**Interfaces produits:**
- `Future<Database> openAppDatabase({DatabaseFactory? factory, String? path})` — crée le schéma v1, seed admin + questions si tables vides. `path == inMemoryDatabasePath` pour les tests.
- `const kAdminEmail = 'admin@reine.app'; const kAdminPassword = 'admin123';`
- `String hashPassword(String raw)` (SHA-256 hex) dans `lib/data/password.dart`.
- `Future<Map<String, dynamic>> loadDefaultQuestionsJson(String discipline)` (lecture asset).

- [ ] Ajouter dépendances, assets dans `pubspec.yaml`, `dart run sqflite_common_ffi_web:setup --force`.
- [ ] Test : `openAppDatabase` en mémoire → `users` contient 1 admin avec `role = 'admin'`, `questions` contient ≥ 3 disciplines avec ≥ 5 questions chacune, chaque question a ≥ 2 choix.
- [ ] Implémenter, `flutter test test/data`, commit `feat: database schema, seed and default questions`.

### Task 2 : Modèles et règles métier pures

**Files:** `lib/models/discipline.dart`, `lib/models/motivation.dart`, `lib/models/user.dart`, `lib/models/question.dart`, `lib/models/test_result.dart`, `lib/logic/school_year.dart`, `lib/logic/scoring.dart`, `test/logic/*.dart`.

**Interfaces produits:**
- `enum Discipline { java, algo, htmlCss }` avec `String get code`, `String get label`, `static Discipline fromCode(String)`.
- `enum Motivation { poursuiteEtudes, reorientation, reconversion }` avec `label`, `fromLabel`.
- `class AppUser { int id; String role; String lastName, firstName, email; int age; String address; Motivation motivation; bool get isAdmin; }`
- `class Question { int? id; Discipline discipline; String text; QuestionType type; int timeLimitS; List<Choice> choices; }`, `class Choice { int? id; String text; bool correct; }`, `enum QuestionType { radio, checkbox }`.
- `class TestResult { int? id; int userId; Discipline discipline; int score, total; double percent; bool passed; String schoolYear; DateTime takenAt; String? candidateName; }`
- `String schoolYearFor(DateTime d)`; `bool isCorrectAnswer(Question q, Set<int> selectedIndexes)`; `TestResult computeResult({required int userId, required Discipline d, required List<Question> qs, required List<Set<int>> answers, required DateTime now})`.

- [ ] Tests : `schoolYearFor(2026-10-26) == '2026-2027'`, `schoolYearFor(2026-03-01) == '2025-2026'` ; radio bon/mauvais ; checkbox exact / partiel (faux) / sur-ensemble (faux) ; `computeResult` 2/4 → percent 50, passed true ; 1/4 → passed false.
- [ ] Implémenter, tests verts, commit `feat: models and scoring rules`.

### Task 3 : UserRepository (US1, US3, US4)

**Files:** `lib/data/user_repository.dart`, `test/data/user_repository_test.dart`.

**Interfaces produits:**
- `class UserRepository { UserRepository(Database db); Future<AppUser> register({lastName, firstName, email, password, age, address, motivation}); Future<AppUser?> login(String email, String password); Future<AppUser> updateProfile(int id, {String? address, Motivation? motivation}); Future<AppUser?> byId(int id); }`
- `class DuplicateAccountException implements Exception`.

- [ ] Tests : register puis login OK ; login mauvais mdp → null ; register même nom + même email (casse différente) → `DuplicateAccountException` ; même email autre nom → OK ; `login(kAdminEmail, kAdminPassword)` → `isAdmin` ; `updateProfile` change adresse + motivation.
- [ ] Implémenter, commit `feat: user repository`.

### Task 4 : QuestionRepository + import JSON (US5)

**Files:** `lib/data/question_repository.dart`, `lib/logic/question_json.dart`, `test/data/question_repository_test.dart`, `test/logic/question_json_test.dart`.

**Interfaces produits:**
- `List<Question> parseQuestionsJson(String raw, {Discipline? expected})` lève `QuestionJsonException(message)` si invalide.
- `class QuestionRepository { Future<List<Question>> forDiscipline(Discipline d); Future<Question> save(Question q); Future<void> delete(int id); Future<void> replaceDiscipline(Discipline d, List<Question> qs); Future<void> resetFromDefaults(Discipline d); }` (`save` insère ou met à jour avec ses choix, en transaction).

- [ ] Tests parse : JSON valide → 2 questions ; radio avec 2 `correct` → exception ; 1 seul choix → exception ; `timeLimit` 0 → exception ; discipline inconnue → exception.
- [ ] Tests repo : save insert → id non nul + choix relus ; save update remplace les choix ; delete ; replaceDiscipline ne touche pas les autres disciplines ; resetFromDefaults recharge les assets.
- [ ] Implémenter, commit `feat: question repository and JSON import`.

### Task 5 : ResultRepository (US2, US3, US6, US7)

**Files:** `lib/data/result_repository.dart`, `test/data/result_repository_test.dart`.

**Interfaces produits:**
- `Future<TestResult> save(TestResult r)` lève `AlreadyTakenException` si doublon.
- `Future<List<TestResult>> forUser(int userId)`.
- `Future<List<TestResult>> recent({String? search, String? schoolYear, int limit = 50})` (tri `taken_at DESC`, `candidateName` rempli, recherche nom OU prénom, `LIKE` insensible à la casse).
- `Future<List<String>> schoolYears()`.
- `class PassStats { int passed; int failed; double get rate; }`, `Future<Map<Discipline, PassStats>> statsByDiscipline({String? schoolYear})`, `Future<PassStats> globalStats(String schoolYear)`.

- [ ] Tests : save deux fois même user/discipline → exception ; recent search `'dupont'` trouve `'DUPONT'` ; filtre année ; stats 2 réussis / 1 échec → rate ≈ 0.667.
- [ ] Implémenter, commit `feat: result repository and statistics`.

### Task 6 : App shell, AuthState, connexion, inscription (US1, US4)

**Files:** `lib/main.dart`, `lib/app.dart`, `lib/state/auth_state.dart`, `lib/screens/auth/login_screen.dart`, `lib/screens/auth/register_screen.dart`, `test/widgets/register_screen_test.dart`.

- `class AuthState extends ChangeNotifier { AppUser? user; Future<String?> login(email, pwd); Future<String?> register(...); void logout(); Future<void> refresh(); }` retourne un message d'erreur ou `null`.
- `MultiProvider` fournit `Database`, les 3 repositories et `AuthState`. Après login : admin → `AdminShell`, candidat → `CandidateHomeScreen`.
- [ ] Widget test : soumettre le formulaire vide → 6 messages « Champ obligatoire » ; email invalide → « Email invalide ».
- [ ] Implémenter, commit `feat: auth screens`.

### Task 7 : Parcours candidat (US2, US3)

**Files:** `lib/screens/candidate/candidate_home_screen.dart`, `lib/screens/candidate/test_screen.dart`, `lib/screens/candidate/test_result_screen.dart`, `lib/screens/candidate/profile_screen.dart`, `test/widgets/test_screen_test.dart`.

- Accueil : 3 cartes, « Passer le test » si pas de résultat, sinon score et bouton désactivé.
- `TestScreen(questions, discipline)` : index courant, `Timer.periodic` 1 s, `remaining` démarre à `timeLimitS` ; à 0 ou « Valider » → enregistre `Set<int>` et passe à la suivante ; fin → `computeResult` + `ResultRepository.save` + `TestResultScreen`.
- Profil : scores par discipline, formulaire adresse + dropdown motivation → `updateProfile`.
- [ ] Widget test (avec `tester.pump(Duration)`) : question timeLimit 2 s, aucune sélection, après 3 s → question 2 affichée ; test de 1 question radio bonne réponse → écran résultat « 1 / 1 ».
- [ ] Implémenter, commit `feat: candidate flow`.

### Task 8 : Admin (US5, US6, US7)

**Files:** `lib/screens/admin/admin_shell.dart` (NavigationBar 3 onglets), `lib/screens/admin/dashboard_screen.dart`, `lib/screens/admin/questions_screen.dart`, `lib/screens/admin/question_editor_screen.dart`, `lib/screens/admin/json_import_screen.dart`, `lib/screens/admin/stats_screen.dart`, `test/widgets/dashboard_screen_test.dart`.

- Dashboard : `TextField` recherche + `DropdownButton` année (« Toutes ») → `recent(...)`, `ListTile` nom, discipline, score, date.
- Questions : `SegmentedButton<Discipline>`, liste avec édition/suppression, FAB ajout, menu « Importer JSON » et « Réinitialiser par défaut ».
- Éditeur : texte, type, temps limite, liste de choix dynamiques avec case « correcte » ; validation identique à `parseQuestionsJson`.
- Stats : dropdown année ; `PieChart` fl_chart par discipline + global.
- [ ] Widget test : dashboard avec 2 résultats, saisir « dupont » → 1 tile.
- [ ] Implémenter, commit `feat: admin screens`.

### Task 9 : Finition

- [ ] `README.md` : présentation, stack, lancer (web / Android), comptes de test, format JSON, structure du code, tests.
- [ ] `flutter analyze`, `flutter test`, `flutter build web --release`, capture d'écran via navigateur headless, `flutter build apk --debug`.
- [ ] Commit `docs: README and build verification`.
