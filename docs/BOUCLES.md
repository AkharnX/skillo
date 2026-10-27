# Catalogue des boucles du projet

Ce document liste **toutes les boucles** du code de l'application (`lib/`), pour
que chaque membre du groupe puisse les expliquer et les réécrire à l'oral.

## Conventions du projet pour les boucles

Les règles complètes sont dans [`CONVENTIONS.md`](CONVENTIONS.md). En résumé :

1. **Une boucle = une seule tâche.** Si on doit faire deux choses, on écrit deux
   boucles (ex. `statsByDiscipline` : une boucle range les lignes SQL dans une
   Map, une seconde boucle construit les statistiques).
2. **Forme préférée** : `for (final element in liste) { … }` avec un
   **accumulateur explicite** déclaré juste au-dessus (`final total = <int>[];`),
   rempli dans la boucle, puis renvoyé après la boucle.
3. **Boucle indexée** `for (var i = 0; i < liste.length; i++)` seulement quand on
   a besoin de la position `i` (numéroter un message d'erreur, lire deux listes
   « en parallèle », retrouver l'index d'un choix).
4. **Sortie anticipée** : `return` dans la boucle dès qu'on a trouvé ce qu'on
   cherche (recherche dans une énumération, vérification « au moins un… »).
5. **Pas de chaînes** `.map().where().fold()`. Les `firstWhere`, `any`,
   `whereType`, compréhensions `{for … if …}` et opérations d'ensemble
   (`containsAll`) ont été remplacés par des boucles explicites.
6. **Tolérés** : un seul `.map(...)` ou un `for` de collection
   (`[for (final x in xs) Widget(...)]`) pour transformer une liste en liste de
   widgets dans un écran, à condition qu'il soit commenté.
7. **Chaque boucle est précédée d'un commentaire** qui dit : sur quoi on boucle,
   ce qu'on accumule, ce qu'on obtient à la fin.

Les fiches ci-dessous suivent toutes le même plan : extrait de code, *Sur quoi on
boucle*, *Ce qu'on construit*, *Pourquoi*, et une *explication orale* de deux ou
trois phrases.

---

## 1. Couche données (`lib/data/`)

### 1.1 `app_database.dart` — `seedIfEmpty`

```dart
for (final code in kDisciplineCodes) {
  final json = await loadDefaultQuestionsJson(code);
  await insertQuestionsFromJson(db, code, json);
}
```

- **Sur quoi on boucle** : les trois codes de discipline `['java', 'algo', 'html_css']`.
- **Ce qu'on construit** : rien en mémoire ; chaque tour insère en base les questions d'un fichier JSON.
- **Pourquoi** : au premier démarrage la table `questions` est vide, il faut la remplir pour les trois disciplines.
- **À l'oral** : « Pour chaque discipline, je lis son fichier `assets/questions/<code>.json` puis j'insère ses questions. La boucle ne tourne que si la table est vide, donc relancer l'application ne duplique rien. »

### 1.2 `app_database.dart` — `insertQuestionsFromJson` (boucle externe)

```dart
for (final q in json['questions'] as List) {
  final question = q as Map<String, dynamic>;
  final questionId = await db.insert('questions', {...});
  for (final c in question['choices'] as List) { … }   // voir 1.3
}
```

- **Sur quoi on boucle** : la liste `questions` du JSON (une Map par question).
- **Ce qu'on construit** : une ligne dans la table `questions` par tour, dont on garde l'`id` généré (`questionId`).
- **Pourquoi** : les choix doivent connaître l'`id` de leur question ; on insère donc la question d'abord, une par une.
- **À l'oral** : « Pour chaque question du fichier, j'insère la ligne dans `questions` et je récupère l'identifiant que SQLite a créé. J'en ai besoin juste après pour rattacher les choix. »

### 1.3 `app_database.dart` — `insertQuestionsFromJson` (boucle interne)

```dart
for (final c in question['choices'] as List) {
  final choice = c as Map<String, dynamic>;
  batch.insert('choices', {
    'question_id': questionId,
    'text': choice['text'],
    'is_correct': choice['correct'] == true ? 1 : 0,
  });
}
```

- **Sur quoi on boucle** : la liste `choices` de la question courante.
- **Ce qu'on construit** : une insertion par choix ajoutée au `batch` (envoyé en une fois à la fin).
- **Pourquoi** : un batch regroupe toutes les écritures en un seul aller-retour avec la base, plus rapide que des insertions séparées.
- **À l'oral** : « Pour chaque choix, je prépare une ligne de `choices` avec l'id de la question, le texte et 1 ou 0 selon que la réponse est bonne. Je ne l'envoie pas tout de suite, je l'ajoute au batch qui sera validé après la boucle externe. »

### 1.4 `question_repository.dart` — `forDiscipline` : ids des questions

```dart
final questionIds = <int>[];
for (final row in questionRows) {
  questionIds.add(row['id'] as int);
}
```

- **Sur quoi on boucle** : les lignes SQL de la table `questions` pour la discipline.
- **Ce qu'on construit** : la liste des identifiants `[12, 13, 14, …]`.
- **Pourquoi** : pour charger tous les choix en une seule requête `WHERE question_id IN (…)`.
- **À l'oral** : « Je parcours les lignes de questions et je mets l'id de chacune dans une liste. Cette liste servira d'arguments à la requête des choix. »

### 1.5 `question_repository.dart` — `forDiscipline` : les `?` du `IN`

```dart
final placeholders = <String>[];
for (var i = 0; i < questionIds.length; i++) {
  placeholders.add('?');
}
// puis : 'question_id IN (${placeholders.join(',')})'
```

- **Sur quoi on boucle** : un compteur de 0 au nombre d'ids.
- **Ce qu'on construit** : une liste de `'?'` de la même longueur, jointe ensuite en `"?,?,?"`.
- **Pourquoi** : SQL exige un `?` par valeur ; on ne concatène jamais les valeurs dans le texte de la requête (sécurité contre les injections).
- **À l'oral** : « J'ai besoin d'autant de points d'interrogation que d'ids. Je boucle `n` fois en ajoutant `'?'` à une liste, puis je la joins avec des virgules pour écrire la clause `IN`. »

### 1.6 `question_repository.dart` — `forDiscipline` : regroupement des choix

```dart
final choicesByQuestion = <int, List<Choice>>{};
for (final row in choiceRows) {
  final questionId = row['question_id'] as int;
  final choice = Choice(id: …, text: …, correct: row['is_correct'] == 1);
  if (!choicesByQuestion.containsKey(questionId)) {
    choicesByQuestion[questionId] = <Choice>[];
  }
  choicesByQuestion[questionId]!.add(choice);
}
```

- **Sur quoi on boucle** : toutes les lignes de `choices` des questions de la discipline.
- **Ce qu'on construit** : une Map « id de question → liste de ses choix ».
- **Pourquoi** : on a chargé les choix de toutes les questions d'un coup ; il faut les redistribuer à la bonne question.
- **À l'oral** : « Pour chaque ligne de choix, je crée l'objet `Choice`, je regarde à quelle question il appartient, je crée sa liste si c'est la première fois que je vois cette question, puis j'ajoute le choix dans cette liste. »

### 1.7 `question_repository.dart` — `forDiscipline` : construction des `Question`

```dart
final questions = <Question>[];
for (final row in questionRows) {
  final questionId = row['id'] as int;
  questions.add(Question(
    id: questionId, discipline: discipline, text: …, type: …, timeLimitS: …,
    choices: choicesByQuestion[questionId] ?? const [],
  ));
}
return questions;
```

- **Sur quoi on boucle** : les lignes SQL de `questions` (même ordre que la requête, par id).
- **Ce qu'on construit** : la liste finale d'objets `Question`, chacun avec ses choix.
- **Pourquoi** : c'est la liste que l'écran de test affiche.
- **À l'oral** : « Je parcours une seconde fois les lignes de questions. Pour chacune je crée un `Question` et je vais chercher ses choix dans la Map de l'étape précédente ; si elle n'en a pas, liste vide. »

### 1.8 `question_repository.dart` — `_saveIn`

```dart
for (final c in q.choices) {
  await txn.insert('choices', {
    'question_id': id, 'text': c.text.trim(), 'is_correct': c.correct ? 1 : 0,
  });
}
```

- **Sur quoi on boucle** : les choix de la question à enregistrer.
- **Ce qu'on construit** : une ligne de `choices` par tour, dans la transaction.
- **Pourquoi** : à la modification on a supprimé les anciens choix ; on réécrit tous les nouveaux, c'est plus simple que de comparer.
- **À l'oral** : « Après avoir inséré ou mis à jour la question, j'insère chacun de ses choix avec l'id de la question. Tout est dans une transaction : si un choix échoue, rien n'est enregistré. »

### 1.9 `question_repository.dart` — `replaceDiscipline`

```dart
for (final q in questions) {
  await _saveIn(txn, q.copyWith(discipline: discipline), forceInsert: true);
}
```

- **Sur quoi on boucle** : les questions validées de l'import JSON.
- **Ce qu'on construit** : une nouvelle ligne par question (et ses choix), après avoir vidé la discipline.
- **Pourquoi** : `forceInsert` garantit une **copie** même si la question porte déjà un id ; `copyWith(discipline:)` force la discipline cible.
- **À l'oral** : « Une fois les anciennes questions supprimées, j'insère chaque question de la liste comme une nouvelle ligne de la discipline choisie. Le tout dans une transaction, pour ne jamais se retrouver avec une discipline à moitié importée. »

### 1.10 `result_repository.dart` — `forUser`

```dart
final results = <TestResult>[];
for (final row in rows) {
  results.add(TestResult.fromRow(row));
}
```

- **Sur quoi on boucle** : les lignes de `results` du candidat, triées du plus récent au plus ancien.
- **Ce qu'on construit** : la liste d'objets `TestResult`.
- **Pourquoi** : l'écran profil affiche des objets, pas des Map SQL.
- **À l'oral** : « Je transforme chaque ligne SQL en objet `TestResult` grâce à `fromRow` et je les mets dans une liste, dans le même ordre. »

### 1.11 `result_repository.dart` — `recent`

```dart
final results = <TestResult>[];
for (final row in rows) {
  results.add(TestResult.fromRow(row));
}
```

- **Sur quoi on boucle** : les lignes de la requête jointe `results` + `users` (avec la colonne calculée `candidate_name`).
- **Ce qu'on construit** : la liste de `TestResult` affichée sur le tableau de bord admin.
- **Pourquoi** : même conversion que `forUser`, mais `fromRow` lit en plus le nom du candidat.
- **À l'oral** : « La requête me rend des lignes avec toutes les colonnes de résultat plus le nom du candidat. Je convertis chaque ligne en `TestResult` et je renvoie la liste. »

### 1.12 `result_repository.dart` — `schoolYears`

```dart
final years = <String>[];
for (final row in rows) {
  years.add(row['school_year'] as String);
}
```

- **Sur quoi on boucle** : les lignes de `SELECT DISTINCT school_year …`.
- **Ce qu'on construit** : la liste `['2026-2027', '2025-2026', …]`.
- **Pourquoi** : alimente les listes déroulantes de filtre de l'admin.
- **À l'oral** : « Chaque ligne contient une seule colonne, l'année scolaire. Je la lis et je l'ajoute à une liste de textes. »

### 1.13 `result_repository.dart` — `statsByDiscipline` : lignes par code

```dart
final rowByCode = <String, Map<String, Object?>>{};
for (final row in rows) {
  rowByCode[row['discipline'] as String] = row;
}
```

- **Sur quoi on boucle** : les lignes du `GROUP BY discipline` (une par discipline ayant au moins un résultat).
- **Ce qu'on construit** : une Map « code de discipline → ligne SQL ».
- **Pourquoi** : pour retrouver la ligne d'une discipline sans la rechercher à chaque fois dans la liste.
- **À l'oral** : « Je range chaque ligne dans une Map avec son code de discipline comme clé. Comme ça, à l'étape suivante, je demande directement `rowByCode['java']`. »

### 1.14 `result_repository.dart` — `statsByDiscipline` : une entrée par discipline

```dart
final stats = <Discipline, PassStats>{};
for (final discipline in Discipline.values) {
  final row = rowByCode[discipline.code];
  var passed = 0;
  var failed = 0;
  if (row != null) {
    passed = (row['passed'] as int?) ?? 0;
    failed = (row['failed'] as int?) ?? 0;
  }
  stats[discipline] = PassStats(passed: passed, failed: failed);
}
```

- **Sur quoi on boucle** : les trois valeurs de l'énumération `Discipline`.
- **Ce qu'on construit** : une Map complète « discipline → `PassStats` », y compris pour les disciplines sans aucun résultat (0 / 0).
- **Pourquoi** : l'écran de statistiques affiche toujours les trois disciplines, même sans résultat.
- **À l'oral** : « Je parcours toutes les disciplines, pas seulement celles de la requête. Pour chacune, je lis ses compteurs dans la Map si elle y est, sinon je laisse 0, et je crée son objet `PassStats`. »

### 1.15 `result_repository.dart` — `_sum`

```dart
var passed = 0;
var failed = 0;
for (final s in perDiscipline.values) {
  passed += s.passed;
  failed += s.failed;
}
return PassStats(passed: passed, failed: failed);
```

- **Sur quoi on boucle** : les `PassStats` de chaque discipline.
- **Ce qu'on construit** : deux compteurs, réussites et échecs, additionnés.
- **Pourquoi** : le taux de réussite global (US7) est la somme de toutes les disciplines.
- **À l'oral** : « J'additionne les réussites et les échecs de chaque discipline dans deux variables, puis je fabrique un `PassStats` global avec ces deux totaux. »

---

## 2. Couche logique (`lib/logic/`)

### 2.1 `scoring.dart` — `isCorrectAnswer`

```dart
if (selectedIndexes.length != correctIndexes.length) return false;
for (final index in correctIndexes) {
  if (!selectedIndexes.contains(index)) return false;
}
return true;
```

- **Sur quoi on boucle** : les index des bonnes réponses de la question.
- **Ce qu'on construit** : rien ; on cherche une bonne réponse **non cochée** pour renvoyer `false` tout de suite.
- **Pourquoi** : une réponse est juste seulement si l'ensemble coché est exactement l'ensemble des bonnes réponses, pour radio comme pour checkbox. Même nombre + toutes les bonnes cochées = aucun mauvais choix coché.
- **À l'oral** : « D'abord je compare les tailles : si le candidat n'a pas coché autant de cases qu'il y a de bonnes réponses, c'est faux. Ensuite je vérifie que chaque bonne réponse est bien cochée. Si j'arrive au bout de la boucle, la réponse est juste. »

### 2.2 `scoring.dart` — `computeResult`

```dart
var score = 0;
for (var i = 0; i < questions.length; i++) {
  var selected = <int>{};
  if (i < answers.length) selected = answers[i];
  if (isCorrectAnswer(questions[i], selected)) score++;
}
```

- **Sur quoi on boucle** : les positions `i` des questions (boucle indexée car on lit `questions[i]` et `answers[i]` en parallèle).
- **Ce qu'on construit** : `score`, le nombre de bonnes réponses.
- **Pourquoi** : 1 point par question juste ; si le test a été interrompu, les questions sans réponse valent 0 (ensemble vide).
- **À l'oral** : « Pour chaque question, je prends la réponse du candidat à la même position, ou un ensemble vide s'il n'a pas répondu. Si elle est juste, j'ajoute un point. Le pourcentage est calculé après la boucle. »

### 2.3 `question_json.dart` — `parseQuestionsMap`

```dart
final questions = <Question>[];
for (var i = 0; i < list.length; i++) {
  final item = list[i];
  if (item is! Map<String, dynamic>) {
    throw QuestionJsonException('Question ${i + 1} : objet attendu.');
  }
  final question = _questionFromMap(item, discipline);
  final error = validateQuestion(question);
  if (error != null) throw QuestionJsonException('Question ${i + 1} : $error');
  questions.add(question);
}
```

- **Sur quoi on boucle** : les positions `i` de la liste `questions` du JSON (indexée pour numéroter les erreurs « Question 3 : … »).
- **Ce qu'on construit** : la liste des `Question` valides.
- **Pourquoi** : chaque élément est converti puis validé ; la première erreur arrête l'import avec un message précis.
- **À l'oral** : « Pour chaque élément du JSON, je vérifie que c'est un objet, je le convertis en `Question`, je le valide avec les règles métier. Si quelque chose ne va pas, je lève une exception avec le numéro de la question ; sinon je l'ajoute à la liste. »

### 2.4 `question_json.dart` — `_allDisciplineCodes`

```dart
final codes = <String>[];
for (final discipline in Discipline.values) {
  codes.add(discipline.code);
}
return codes.join(', ');
```

- **Sur quoi on boucle** : les valeurs de l'énumération `Discipline`.
- **Ce qu'on construit** : la liste des codes, puis le texte `java, algo, html_css`.
- **Pourquoi** : pour le message « Discipline inconnue "php" (attendu : java, algo, html_css) ».
- **À l'oral** : « Je collecte le code de chaque discipline dans une liste et je les joins avec des virgules pour afficher la liste des valeurs acceptées. »

### 2.5 `question_json.dart` — `_questionFromMap` : les choix

```dart
final choices = <Choice>[];
final rawChoices = m['choices'];
if (rawChoices is List) {
  for (final raw in rawChoices) {
    if (raw is! Map<String, dynamic>) continue;
    choices.add(Choice(text: '${raw['text'] ?? ''}', correct: raw['correct'] == true));
  }
}
```

- **Sur quoi on boucle** : les éléments bruts de `choices` dans le JSON.
- **Ce qu'on construit** : la liste de `Choice` de la question.
- **Pourquoi** : les éléments qui ne sont pas des objets sont ignorés (`continue`) ; les champs manquants deviennent `""` / `false` et seront rejetés par `validateQuestion` avec un message clair.
- **À l'oral** : « Si le champ `choices` est une liste, je parcours ses éléments. J'ignore ceux qui ne sont pas des objets, et pour les autres je crée un `Choice` avec le texte et le booléen `correct`. »

### 2.6 `question_json.dart` — `validateQuestion`

```dart
for (final choice in q.choices) {
  if (choice.text.trim().isEmpty) return 'chaque choix doit avoir un texte.';
}
```

- **Sur quoi on boucle** : les choix de la question.
- **Ce qu'on construit** : rien ; on cherche un choix au texte vide pour renvoyer l'erreur immédiatement.
- **Pourquoi** : règle métier partagée par l'import JSON et l'éditeur de questions.
- **À l'oral** : « Je regarde chaque choix ; dès que j'en trouve un dont le texte est vide, je renvoie le message d'erreur. Si j'arrive au bout, tous les choix ont un texte et je passe aux règles suivantes. »

### 2.7 `question_json.dart` — `questionsToJson`

```dart
final questionMaps = <Map<String, Object?>>[];
for (final question in questions) {
  questionMaps.add(_questionToMap(question));
}
```

- **Sur quoi on boucle** : les questions à exporter.
- **Ce qu'on construit** : la liste `questions` du document JSON (une Map par question).
- **Pourquoi** : l'export doit produire exactement le format que l'import relit.
- **À l'oral** : « Pour chaque question, je fabrique sa Map JSON avec une fonction dédiée et je l'ajoute à la liste. Ensuite j'encode le document avec `JsonEncoder`. »

### 2.8 `question_json.dart` — `_questionToMap`

```dart
final choiceMaps = <Map<String, Object?>>[];
for (final choice in question.choices) {
  choiceMaps.add({'text': choice.text, 'correct': choice.correct});
}
```

- **Sur quoi on boucle** : les choix d'une question.
- **Ce qu'on construit** : la liste `choices` du JSON : `{"text": …, "correct": …}` par choix.
- **Pourquoi** : séparée de la boucle 2.7 pour qu'une boucle fasse une seule chose.
- **À l'oral** : « Pour chaque choix, je crée un petit objet JSON avec son texte et son booléen, et je l'ajoute à la liste `choices` de la question. »

---

## 3. Modèles (`lib/models/`)

### 3.1 `discipline.dart` — `Discipline.fromCode`

```dart
for (final discipline in values) {
  if (discipline.code == code) return discipline;
}
throw ArgumentError('Discipline inconnue : $code');
```

- **Sur quoi on boucle** : les trois valeurs de l'énumération.
- **Ce qu'on construit** : rien ; on renvoie la première discipline dont le code correspond.
- **Pourquoi** : convertir le texte stocké en base ou dans un JSON en valeur typée. Un code inconnu est une erreur.
- **À l'oral** : « Je compare le code cherché à celui de chaque discipline ; dès qu'il correspond, je renvoie la discipline. Si la boucle se termine sans rien trouver, je lève une erreur. »

### 3.2 `motivation.dart` — `Motivation.fromLabel`

```dart
for (final motivation in values) {
  if (motivation.label == label) return motivation;
}
return null;
```

- **Sur quoi on boucle** : les trois motivations.
- **Ce qu'on construit** : rien ; renvoie la motivation dont le libellé correspond, ou `null`.
- **Pourquoi** : la base stocke le libellé ; `null` est normal pour l'admin (libellé vide).
- **À l'oral** : « Même principe que `Discipline.fromCode`, mais ici on renvoie `null` au lieu d'une erreur, parce que le compte admin n'a pas de motivation. »

### 3.3 `question.dart` — `QuestionType.fromCodeOrNull`

```dart
for (final type in values) {
  if (type.code == code) return type;
}
return null;
```

- **Sur quoi on boucle** : `radio` et `checkbox`.
- **Ce qu'on construit** : rien ; renvoie le type correspondant au code, ou `null`.
- **Pourquoi** : l'import JSON veut afficher « type "xxx" inconnu » plutôt que planter ; `fromCode` réutilise cette fonction et lève une erreur si le résultat est `null`.
- **À l'oral** : « Je parcours les deux types de question et je renvoie celui dont le code est égal à celui qu'on me donne. S'il n'y en a pas, je renvoie `null`. »

### 3.4 `question.dart` — `Question.correctIndexes`

```dart
final indexes = <int>{};
for (var i = 0; i < choices.length; i++) {
  if (choices[i].correct) indexes.add(i);
}
return indexes;
```

- **Sur quoi on boucle** : les positions `i` des choix (indexée car c'est la position qu'on veut).
- **Ce qu'on construit** : l'ensemble (`Set`) des positions des bonnes réponses, ex. `{0, 2}`.
- **Pourquoi** : la correction (`isCorrectAnswer`) et la validation (`validateQuestion`) raisonnent en positions, et l'ordre n'a pas d'importance, d'où un `Set`.
- **À l'oral** : « Je parcours les choix avec leur position. Chaque fois qu'un choix est marqué correct, j'ajoute sa position à un ensemble. Pour une question radio j'obtiens un seul index, pour une checkbox plusieurs. »

---

## 4. État (`lib/state/`), thème (`lib/theme/`) et widgets (`lib/widgets/`)

`AuthState` ne fait que mémoriser l'utilisateur connecté et prévenir les
écrans ; le thème construit des objets de style fixes. Les `if (x != null)
...[ … ]` que l'on y voit sont des **conditions** dans une liste de widgets, pas
des boucles. Il n'y a pas non plus de boucle dans `lib/main.dart` ni
`lib/app.dart`.

Un seul widget partagé contient une boucle : le faux terminal `TerminalCard`,
qui affiche une ligne par `TerminalLine` reçue.

### 4.1 `terminal_card.dart` — `TerminalCard.build`

```dart
final rows = <Widget>[];
for (final line in lines) {
  rows.add(
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Text(
        line.text,
        style: AppText.mono(
          13.5,
          color: line.color,
          weight: FontWeight.w500,
        ),
      ),
    ),
  );
}
```

- **Sur quoi on boucle** : les `TerminalLine` (texte + couleur) passées au widget, dans l'ordre.
- **Ce qu'on construit** : la liste `rows` des widgets `Text` en chasse fixe, un par ligne.
- **Pourquoi** : le widget ne connaît pas à l'avance le nombre de lignes (trois disciplines sur l'écran de connexion, une vingtaine de lignes de JSON sur l'import) ; la même boucle sert aux deux.
- **À l'oral** : « Pour chaque ligne reçue, je crée un `Text` avec son texte et sa couleur, dans la police mono, et je l'ajoute à une liste. Cette liste devient les enfants de la colonne sous la barre de titre du terminal. »

---

## 5. Écrans (`lib/screens/`)

Les boucles ci-dessous sont celles présentes dans `lib/screens/` après la
réécriture des écrans en identité « encre et signal ». Dans les écrans, les
boucles servent presque toujours à **construire une liste de widgets** (une carte
par discipline, une entrée de menu par année, un séparateur entre deux lignes…)
ou à **compter** quelque chose avant l'affichage. `admin/admin_shell.dart`
n'en contient aucune.

### 5.1 `auth/register_screen.dart` — `dispose`

```dart
final controllers = [
  _lastName,
  _firstName,
  _email,
  _age,
  _address,
  _password,
];
for (final controller in controllers) {
  controller.dispose();
}
```

- **Sur quoi on boucle** : les six `TextEditingController` du formulaire d'inscription.
- **Ce qu'on construit** : rien ; chaque tour libère un contrôleur.
- **Pourquoi** : Flutter demande de libérer les contrôleurs quand l'écran disparaît ; une boucle évite six lignes identiques.
- **À l'oral** : « Je mets tous mes contrôleurs dans une liste et j'appelle `dispose()` sur chacun avant de fermer l'écran, pour ne pas laisser de ressources ouvertes. »

### 5.2 `auth/register_screen.dart` — `_buildFormCard` (menu motivation)

```dart
items: [
  for (final m in Motivation.values)
    DropdownMenuItem(value: m, child: Text(m.label)),
],
```

- **Sur quoi on boucle** : les trois valeurs de `Motivation`.
- **Ce qu'on construit** : la liste des entrées du menu déroulant (un `for` de collection, toléré pour une liste de widgets).
- **Pourquoi** : la liste déroulante doit proposer exactement les motivations du cahier des charges.
- **À l'oral** : « Pour chaque motivation de l'énumération, je crée une entrée de menu dont la valeur est la motivation et le texte son libellé. »

### 5.3 `auth/register_screen.dart` — `_InkColumn.build` (les trois étapes)

```dart
final stepRows = <Widget>[];
for (var i = 0; i < _steps.length; i++) {
  final (icon, text) = _steps[i];
  stepRows.add(
    Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: _StepRow(number: i + 1, icon: icon, text: text),
    ),
  );
}
```

- **Sur quoi on boucle** : les positions `i` de `_steps`, la liste constante des trois étapes « Ce que vous allez faire » (un couple icône + texte chacune). Indexée car la ligne affiche son numéro `i + 1`.
- **Ce qu'on construit** : la liste `stepRows` des lignes numérotées, chacune avec un espace en dessous.
- **Pourquoi** : la colonne encre à gauche de l'inscription (grand écran) présente le parcours du candidat en trois étapes ; les numéros viennent de l'index, pas d'un champ supplémentaire.
- **À l'oral** : « Je parcours les trois étapes avec leur position. Pour chacune, je déstructure le couple icône/texte et je crée une ligne `_StepRow` numérotée de 1 à 3. La boucle me donne la liste des lignes que j'affiche dans la colonne. »

### 5.4 `auth/login_screen.dart` — `_InkPanel._terminalLines`

```dart
final lines = <TerminalLine>[const TerminalLine(r'$ skillo test --list')];
for (final d in Discipline.values) {
  lines.add(
    TerminalLine(
      '${d.code.padRight(12)}${_specs[d]}',
      color: AppColors.forDiscipline(d),
    ),
  );
}
```

- **Sur quoi on boucle** : les trois disciplines.
- **Ce qu'on construit** : les lignes du faux terminal de l'écran de connexion, après la ligne de commande `$ skillo test --list` ; la ligne « 1 tentative par discipline » est ajoutée après la boucle.
- **Pourquoi** : chaque discipline s'affiche comme une sortie de commande, dans sa couleur, avec le code complété à 12 caractères (`padRight`) pour que les descriptions soient alignées en chasse fixe.
- **À l'oral** : « Je commence la liste par la commande tapée, puis pour chaque discipline j'ajoute une ligne "code  description" colorée avec la couleur de la discipline. Le `padRight` aligne les colonnes. Le widget `TerminalCard` affiche ensuite ces lignes. »

### 5.5 `candidate/candidate_home_screen.dart` — `_DisciplineInfo.fromQuestions`

```dart
var minTime = 0;
var maxTime = 0;
for (final q in questions) {
  if (minTime == 0 || q.timeLimitS < minTime) minTime = q.timeLimitS;
  if (q.timeLimitS > maxTime) maxTime = q.timeLimitS;
}
```

- **Sur quoi on boucle** : les questions d'une discipline, chargées depuis la base.
- **Ce qu'on construit** : deux compteurs, `minTime` et `maxTime`, le plus petit et le plus grand temps limite rencontrés (0 et 0 pour une liste vide).
- **Pourquoi** : la carte de discipline affiche « 8 questions · 20-30 s / question » ; le nombre vient de `questions.length`, la fourchette de cette boucle. Le test `minTime == 0` sert d'initialisation : la première question fixe le minimum.
- **À l'oral** : « Pour chaque question je compare son temps limite au minimum et au maximum déjà vus et je les mets à jour. Le minimum part de 0, qui veut dire "pas encore vu", donc la première question le remplace forcément. »

### 5.6 `candidate/candidate_home_screen.dart` — `_loadData`

```dart
final infos = <Discipline, _DisciplineInfo>{};
for (final d in Discipline.values) {
  final questions = await questionRepository.forDiscipline(d);
  infos[d] = _DisciplineInfo.fromQuestions(questions);
}
```

- **Sur quoi on boucle** : les trois disciplines.
- **Ce qu'on construit** : la Map `infos` « discipline → résumé (nombre de questions, temps min/max) ».
- **Pourquoi** : chaque carte de l'accueil affiche le résumé de sa discipline ; on charge les questions discipline par discipline, en attendant chaque requête (`await` dans la boucle).
- **À l'oral** : « Pour chaque discipline, je charge ses questions depuis le repository, j'en tire un résumé avec `fromQuestions` et je le range dans une Map sous la discipline. Les cartes lisent ensuite `infos[d]`. »

### 5.7 `candidate/candidate_home_screen.dart` — `_indexByDiscipline`

```dart
final byDiscipline = <Discipline, TestResult>{};
for (final result in list) {
  byDiscipline[result.discipline] = result;
}
return byDiscipline;
```

- **Sur quoi on boucle** : les résultats du candidat chargés par `ResultRepository.forUser`.
- **Ce qu'on construit** : une Map « discipline → résultat ».
- **Pourquoi** : chaque carte de discipline doit savoir vite si le test a déjà été passé (`results[d]`).
- **À l'oral** : « Je range chaque résultat dans une Map avec sa discipline comme clé. Comme un candidat ne passe un test qu'une fois, il y a au plus un résultat par discipline. »

### 5.8 `candidate/candidate_home_screen.dart` — `_buildSummary`

```dart
var passedCount = 0;
for (final result in results.values) {
  if (result.passed) passedCount++;
}
final takenCount = results.length;
final totalCount = Discipline.values.length;
```

- **Sur quoi on boucle** : les résultats de la Map précédente.
- **Ce qu'on construit** : `passedCount`, le nombre de tests réussis.
- **Pourquoi** : les deux tuiles de l'en-tête affichent « X / 3 tests passés » et « Y réussis ».
- **À l'oral** : « Je parcours les résultats et j'incrémente un compteur à chaque test réussi. Le nombre de tests passés, c'est simplement la taille de la Map. »

### 5.9 `candidate/candidate_home_screen.dart` — `_buildList`

```dart
final cards = <Widget>[];
for (var i = 0; i < Discipline.values.length; i++) {
  final d = Discipline.values[i];
  cards.add(
    Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child:
          _DisciplineCard(
                discipline: d,
                result: data.results[d],
                info: data.infos[d],
                onStart: _starting ? null : () => _start(d),
              )
              .animate(delay: (60 * i).ms)
              .fadeIn(duration: 280.ms)
              .slideY(begin: 0.04, end: 0),
    ),
  );
}
```

- **Sur quoi on boucle** : les positions `i` des disciplines (indexée pour le délai d'animation `60 * i` ms).
- **Ce qu'on construit** : la liste des cartes de discipline, chacune avec son résultat éventuel et son résumé de questions.
- **Pourquoi** : une carte par discipline, qui apparaît en cascade : la 1re tout de suite, la 2e 60 ms après, etc. Le bouton de démarrage est désactivé pendant qu'un test se lance (`_starting`).
- **À l'oral** : « Pour chaque discipline, je crée sa carte avec son résultat, son résumé et le bouton de démarrage. J'utilise l'index pour décaler l'animation d'apparition de chaque carte. »

### 5.10 `candidate/profile_screen.dart` — `_indexByDiscipline`

```dart
final byDiscipline = <Discipline, TestResult>{};
for (final result in list) {
  byDiscipline[result.discipline] = result;
}
return byDiscipline;
```

- **Sur quoi on boucle** : les résultats du candidat.
- **Ce qu'on construit** : la Map « discipline → résultat », comme en 5.7.
- **Pourquoi** : la carte « Mes résultats » affiche une ligne par discipline, avec ou sans résultat.
- **À l'oral** : « Même boucle que sur l'accueil : chaque résultat est rangé sous sa discipline pour qu'on puisse le retrouver directement par `byDiscipline[d]`. »

### 5.11 `candidate/profile_screen.dart` — `_countPassed`

```dart
var passed = 0;
for (final result in byDiscipline.values) {
  if (result.passed) passed++;
}
return passed;
```

- **Sur quoi on boucle** : les résultats de la Map « discipline → résultat ».
- **Ce qu'on construit** : `passed`, le nombre de tests réussis.
- **Pourquoi** : l'en-tête du profil (`_buildHeader`) affiche le nombre de réussites à côté des initiales du candidat.
- **À l'oral** : « Même comptage que sur l'accueil, mais isolé dans une petite fonction : je parcours les résultats et j'ajoute 1 à chaque test réussi. »

### 5.12 `candidate/profile_screen.dart` — `_buildResultsCard`

```dart
final rows = <Widget>[];
for (var i = 0; i < Discipline.values.length; i++) {
  final d = Discipline.values[i];
  if (i > 0) rows.add(const Divider(height: 1, indent: 16));
  rows.add(_ResultRow(discipline: d, result: byDiscipline[d]));
}
return Card(child: Column(children: rows));
```

- **Sur quoi on boucle** : les positions `i` des disciplines (indexée pour savoir si on est à la première ligne).
- **Ce qu'on construit** : la liste des lignes de résultat, séparées par un trait.
- **Pourquoi** : un `Divider` entre chaque ligne mais pas au-dessus de la première, d'où le test `i > 0`.
- **À l'oral** : « Pour chaque discipline j'ajoute une ligne de résultat ; à partir de la deuxième, j'ajoute d'abord un séparateur. Le résultat est une carte avec trois lignes séparées par deux traits. »

### 5.13 `candidate/profile_screen.dart` — `_buildFormCard` (menu motivation)

```dart
items: [
  for (final m in Motivation.values)
    DropdownMenuItem(value: m, child: Text(m.label)),
],
```

- **Sur quoi on boucle** : les valeurs de `Motivation`.
- **Ce qu'on construit** : les entrées du menu déroulant du profil.
- **Pourquoi** : le candidat peut changer sa motivation (US3) parmi les mêmes valeurs qu'à l'inscription.
- **À l'oral** : « Identique au formulaire d'inscription : une entrée de menu par motivation. »

### 5.14 `candidate/profile_screen.dart` — `_InitialsAvatar._initials`

```dart
final words = fullName.trim().split(' ');
var initials = '';
for (final word in words) {
  if (word.isEmpty || initials.length >= 2) continue;
  initials += word[0].toUpperCase();
}
return initials;
```

- **Sur quoi on boucle** : les mots du nom complet (« Jean Dupont » → `['Jean', 'Dupont']`).
- **Ce qu'on construit** : la chaîne des initiales, deux lettres au maximum (« JD »).
- **Pourquoi** : le carré encre du profil affiche les initiales du candidat en jaune signal ; les mots vides (double espace) sont ignorés.
- **À l'oral** : « Je coupe le nom sur les espaces, puis pour chaque mot non vide je prends sa première lettre en majuscule, en m'arrêtant à deux lettres. »

### 5.15 `candidate/test_screen.dart` — `_buildChoiceCards`

```dart
final cards = <Widget>[];
for (var i = 0; i < q.choices.length; i++) {
  cards.add(
    Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _ChoiceCard(
        index: i,
        text: q.choices[i].text,
        isRadio: q.type == QuestionType.radio,
        selected: _selected.contains(i),
        onToggle: (value) => _toggle(i, value),
      ),
    ),
  );
}
return cards;
```

- **Sur quoi on boucle** : les positions `i` des choix de la question courante (indexée car la réponse du candidat est un ensemble d'index).
- **Ce qu'on construit** : la liste des cartes de réponse.
- **Pourquoi** : la position est la clé de tout le système de correction : `_selected` contient des index, `correctIndexes` aussi.
- **À l'oral** : « Pour chaque choix de la question, je crée une carte cliquable. Je lui passe son index pour savoir, au clic, quel index ajouter ou retirer de l'ensemble des réponses cochées. »

### 5.16 `candidate/test_result_screen.dart` — `_SummaryBlock.build`

```dart
final children = <Widget>[];
for (var i = 0; i < rows.length; i++) {
  if (i > 0) children.add(const Divider(height: 1));
  children.add(rows[i]);
}
```

- **Sur quoi on boucle** : les positions `i` des lignes du récapitulatif (`_SummaryRow` : score, taux, date…). Indexée pour détecter la première ligne.
- **Ce qu'on construit** : la liste `children`, lignes et traits alternés.
- **Pourquoi** : le bloc gris de l'écran de résultat sépare ses lignes par un trait fin, sans trait au-dessus de la première ; même motif que 5.12.
- **À l'oral** : « Pour chaque ligne du récapitulatif, j'ajoute d'abord un séparateur si ce n'est pas la première, puis la ligne elle-même. La colonne obtenue alterne lignes et traits. »

### 5.17 `admin/dashboard_screen.dart` — `_buildFilters` (menu année)

```dart
final items = <DropdownMenuItem<String?>>[
  const DropdownMenuItem<String?>(
    value: null,
    child: Text('Toutes les années'),
  ),
];
for (final y in snapshot.data ?? const <String>[]) {
  items.add(DropdownMenuItem<String?>(value: y, child: Text(y)));
}
```

- **Sur quoi on boucle** : les années scolaires trouvées en base (`ResultRepository.schoolYears`), ou une liste vide tant qu'elles chargent.
- **Ce qu'on construit** : les entrées du menu, après l'entrée fixe « Toutes les années » (valeur `null`).
- **Pourquoi** : l'admin filtre les résultats par année ; `null` signifie « pas de filtre ».
- **À l'oral** : « Je commence la liste avec l'option "Toutes les années", puis j'ajoute une entrée par année scolaire présente en base. »

### 5.18 `admin/dashboard_screen.dart` — `_KeyFigures.build`

```dart
final candidateIds = <int>{};
var passedCount = 0;
for (final r in results) {
  candidateIds.add(r.userId);
  if (r.passed) passedCount++;
}
```

- **Sur quoi on boucle** : les résultats affichés sur le tableau de bord (déjà filtrés par la recherche et l'année).
- **Ce qu'on construit** : l'ensemble des ids de candidats distincts (un `Set` ne garde pas les doublons) et le nombre de tests réussis.
- **Pourquoi** : les tuiles « Candidats », « Tests », « Taux de réussite » en haut du tableau de bord.
- **À l'oral** : « Je parcours les résultats une fois : j'ajoute l'id du candidat à un ensemble, qui élimine les doublons, et je compte les réussites. La taille de l'ensemble donne le nombre de candidats distincts. »

### 5.19 `admin/stats_screen.dart` — `_buildYearFilter`

```dart
final items = <DropdownMenuItem<String?>>[
  const DropdownMenuItem<String?>(
    value: null,
    child: Text('Toutes les années'),
  ),
];
for (final y in data.years) {
  items.add(DropdownMenuItem<String?>(value: y, child: Text(y)));
}
```

- **Sur quoi on boucle** : les années scolaires chargées avec les statistiques.
- **Ce qu'on construit** : les entrées du menu déroulant, après « Toutes les années ».
- **Pourquoi** : même filtre que le tableau de bord, pour les statistiques (US7).
- **À l'oral** : « Une entrée de menu par année scolaire, ajoutée à une liste qui commence par l'option sans filtre. »

### 5.20 `admin/stats_screen.dart` — `_buildDisciplineGrid` : les cartes

```dart
final cards = <Widget>[];
for (final d in Discipline.values) {
  final stats = data.byDiscipline[d]!;
  cards.add(
    _DonutCard(
      leading: DisciplineAvatar(discipline: d, size: 40),
      title: d.label,
      caption: _label(d.label, stats),
      stats: stats,
      size: 150,
      rateSize: 28,
    ),
  );
}
```

- **Sur quoi on boucle** : les trois disciplines.
- **Ce qu'on construit** : la liste `cards`, une carte « donut » (anneau de taux de réussite) par discipline, sans mise en page.
- **Pourquoi** : `statsByDiscipline` garantit une entrée par discipline, d'où le `!`. La mise en page (colonne ou ligne) est faite par les deux boucles suivantes, pour qu'une boucle ne fasse qu'une chose.
- **À l'oral** : « Pour chaque discipline, je récupère ses statistiques dans la Map et je crée une carte avec son avatar, son titre, sa légende et son anneau. J'obtiens trois cartes que je dispose ensuite selon la largeur de l'écran. »

### 5.21 `admin/stats_screen.dart` — `_buildDisciplineGrid` : empilement sur téléphone

```dart
if (!threeColumns) {
  final column = <Widget>[];
  for (var i = 0; i < cards.length; i++) {
    if (i > 0) column.add(const SizedBox(height: 12));
    column.add(cards[i]);
  }
  return Column(
    children: column,
  ).animate().fadeIn(duration: 280.ms).slideY(begin: 0.04, end: 0);
}
```

- **Sur quoi on boucle** : les positions `i` des cartes construites en 5.20 (indexée pour ne pas mettre d'espace avant la première).
- **Ce qu'on construit** : la liste `column`, cartes et espaces verticaux de 12 px alternés.
- **Pourquoi** : sous 700 px de large (`threeColumns` faux), les cartes s'empilent les unes sous les autres dans une `Column`.
- **À l'oral** : « Sur téléphone, je parcours les cartes et j'intercale un espace de 12 px entre deux cartes, jamais avant la première. La liste devient les enfants d'une colonne. »

### 5.22 `admin/stats_screen.dart` — `_buildDisciplineGrid` : mise en ligne sur grand écran

```dart
final row = <Widget>[];
for (var i = 0; i < cards.length; i++) {
  if (i > 0) row.add(const SizedBox(width: 12));
  row.add(Expanded(child: cards[i]));
}
return IntrinsicHeight(
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: row,
  ),
).animate().fadeIn(duration: 280.ms).slideY(begin: 0.04, end: 0);
```

- **Sur quoi on boucle** : les positions `i` des mêmes cartes (indexée pour l'espace entre deux cartes).
- **Ce qu'on construit** : la liste `row`, chaque carte enveloppée dans un `Expanded` pour prendre un tiers de la largeur, avec un espace horizontal de 12 px entre deux cartes.
- **Pourquoi** : à partir de 700 px, les trois cartes sont côte à côte ; `IntrinsicHeight` aligne leur bas même si une légende tient sur deux lignes.
- **À l'oral** : « Sur grand écran, je parcours les cartes, je mets chacune dans un `Expanded` pour qu'elles se partagent la largeur, et j'intercale un espace de 12 px. La liste devient les enfants d'une ligne de même hauteur. »

### 5.23 `admin/questions_screen.dart` — `_buildToolbar`

```dart
final segments = <ButtonSegment<Discipline>>[];
for (final d in Discipline.values) {
  segments.add(
    ButtonSegment(
      value: d,
      label: Text(d.label, maxLines: 1, overflow: TextOverflow.ellipsis),
    ),
  );
}
```

- **Sur quoi on boucle** : les trois disciplines.
- **Ce qu'on construit** : les segments du bouton segmenté qui sert d'onglets.
- **Pourquoi** : l'admin choisit la discipline dont il gère les questions (US5) ; le libellé est coupé avec des points de suspension s'il manque de place.
- **À l'oral** : « Un segment par discipline, avec son libellé sur une ligne ; le bouton segmenté les affiche côte à côte. »

### 5.24 `admin/json_import_screen.dart` — `_buildExample`

```dart
final lines = <TerminalLine>[];
for (final text in _exampleLines) {
  lines.add(TerminalLine(text));
}
```

- **Sur quoi on boucle** : `_exampleLines`, la liste constante des lignes de l'exemple de JSON (`{`, `"discipline": "java",`, …).
- **Ce qu'on construit** : la liste de `TerminalLine` (toutes blanches, couleur par défaut) passée au widget `TerminalCard`.
- **Pourquoi** : l'exemple s'affiche dans le même faux terminal que l'écran de connexion ; le widget attend des `TerminalLine`, pas des chaînes.
- **À l'oral** : « Pour chaque ligne de texte de l'exemple, je crée une `TerminalLine` sans couleur particulière et je l'ajoute à une liste. Le terminal affiche ensuite cette liste sous le titre `java.json`. »

### 5.25 `admin/question_editor_screen.dart` — `initState` (brouillons des choix)

```dart
_choices = [];
if (q == null) {
  _choices.add(_ChoiceDraft('', false));
  _choices.add(_ChoiceDraft('', false));
} else {
  for (final c in q.choices) {
    _choices.add(_ChoiceDraft(c.text, c.correct));
  }
}
```

- **Sur quoi on boucle** : les choix de la question à modifier.
- **Ce qu'on construit** : un brouillon (`_ChoiceDraft`, avec son `TextEditingController`) par choix.
- **Pourquoi** : le formulaire travaille sur des brouillons modifiables, pas sur la `Question` immuable ; pour une nouvelle question on crée deux brouillons vides à la place.
- **À l'oral** : « À l'ouverture en mode édition, je crée pour chaque choix existant un brouillon avec son texte et son état "bonne réponse", dans le même ordre. »

### 5.26 `admin/question_editor_screen.dart` — `dispose`

```dart
for (final c in _choices) {
  c.controller.dispose();
}
```

- **Sur quoi on boucle** : les brouillons de choix.
- **Ce qu'on construit** : rien ; chaque tour libère le contrôleur de texte d'un choix.
- **Pourquoi** : le nombre de choix varie, on ne peut pas écrire les `dispose()` un par un.
- **À l'oral** : « Comme chaque choix a son propre contrôleur, je les libère tous en boucle quand l'écran se ferme. »

### 5.27 `admin/question_editor_screen.dart` — `_draft`

```dart
final choices = <Choice>[];
for (final c in _choices) {
  choices.add(Choice(text: c.controller.text, correct: c.correct));
}
```

- **Sur quoi on boucle** : les brouillons de choix.
- **Ce qu'on construit** : la liste de `Choice` de la `Question` à valider puis enregistrer.
- **Pourquoi** : opération inverse de 5.25 : brouillons → modèle, au moment de cliquer sur « Enregistrer ».
- **À l'oral** : « Je relis le texte tapé dans chaque brouillon et son état coché, et j'en fais un `Choice`. La liste obtenue est passée à `validateQuestion` puis au repository. »

### 5.28 `admin/question_editor_screen.dart` — `_setCorrect` (mode radio)

```dart
for (var j = 0; j < _choices.length; j++) {
  _choices[j].correct = j == i && value;
}
```

- **Sur quoi on boucle** : les positions `j` des brouillons.
- **Ce qu'on construit** : rien ; met à jour `correct` de chaque brouillon : vrai seulement pour le choix `i` cliqué (et si on le coche).
- **Pourquoi** : en choix unique, cocher un choix doit décocher tous les autres.
- **À l'oral** : « En mode radio, je repasse sur tous les choix : celui qu'on vient de cliquer prend la nouvelle valeur, tous les autres passent à faux. »

### 5.29 `admin/question_editor_screen.dart` — `_setType` : première bonne réponse

```dart
var first = -1;
for (var j = 0; j < _choices.length; j++) {
  if (_choices[j].correct) {
    first = j;
    break;
  }
}
```

- **Sur quoi on boucle** : les positions `j` des brouillons.
- **Ce qu'on construit** : `first`, l'index de la première bonne réponse (ou -1 s'il n'y en a aucune).
- **Pourquoi** : en passant de checkbox à radio, on ne peut garder qu'une seule bonne réponse : on garde la première.
- **À l'oral** : « Je cherche le premier choix coché ; dès que je le trouve, je note son index et je sors de la boucle avec `break`. »

### 5.30 `admin/question_editor_screen.dart` — `_setType` : ne garder que celle-là

```dart
for (var j = 0; j < _choices.length; j++) {
  _choices[j].correct = j == first;
}
```

- **Sur quoi on boucle** : les positions `j` des brouillons.
- **Ce qu'on construit** : rien ; seul le choix `first` reste coché.
- **Pourquoi** : deuxième moitié du passage en mode radio ; séparée de 5.29 pour qu'une boucle ne fasse qu'une chose.
- **À l'oral** : « Une fois l'index de la première bonne réponse connu, je repasse sur tous les choix et je ne laisse coché que celui-là. »

### 5.31 `admin/question_editor_screen.dart` — `_buildParams`

```dart
final items = <DropdownMenuItem<QuestionType>>[];
for (final t in QuestionType.values) {
  items.add(DropdownMenuItem(value: t, child: Text(t.label)));
}
```

- **Sur quoi on boucle** : `radio` et `checkbox`.
- **Ce qu'on construit** : les entrées du menu « Type ».
- **Pourquoi** : l'admin choisit le type de question dans une liste déroulante.
- **À l'oral** : « Une entrée de menu par type de question, avec son libellé "Choix unique" ou "Choix multiples". »

### 5.32 `admin/question_editor_screen.dart` — `_buildChoices`

```dart
final rows = <Widget>[];
for (var i = 0; i < _choices.length; i++) {
  rows.add(
    _ChoiceRow(
      index: i,
      draft: _choices[i],
      canRemove: _choices.length > 2,
      onCorrectChanged: (v) => _setCorrect(i, v),
      onRemove: () => _removeChoice(i),
    ),
  );
}
```

- **Sur quoi on boucle** : les positions `i` des brouillons (indexée pour savoir quel choix cocher ou supprimer au clic).
- **Ce qu'on construit** : une ligne de formulaire par choix.
- **Pourquoi** : la suppression est désactivée quand il ne reste que deux choix (règle « au moins 2 choix »).
- **À l'oral** : « Pour chaque brouillon, je crée une ligne avec son champ texte, sa lettre-bascule "Bonne réponse" et son bouton supprimer ; je passe l'index pour que les callbacks sachent sur quel choix agir. »

---

## Récapitulatif

| Couche | Fichiers | Boucles |
|---|---|---|
| Données | `app_database.dart`, `question_repository.dart`, `result_repository.dart` | 15 |
| Logique | `scoring.dart`, `question_json.dart` | 8 |
| Modèles | `discipline.dart`, `motivation.dart`, `question.dart` | 4 |
| État / thème / widgets / `main` / `app` | `widgets/terminal_card.dart` | 1 |
| Écrans | `auth/` (4), `candidate/` (12), `admin/` (16) | 32 |
| **Total** | | **60** |
