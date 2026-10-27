# Conventions de code

Ce projet est un projet d'école : chaque membre du groupe doit pouvoir **expliquer
et refaire n'importe quelle partie du code** à l'oral. Les règles ci-dessous
servent cet objectif.

## Commentaires (en français)

- Chaque fichier commence par un commentaire `///` qui dit à quoi il sert.
- Chaque classe, fonction, méthode et champ non évident porte un commentaire
  de documentation `///` : **quoi**, **pourquoi**, et les cas limites.
- À l'intérieur des fonctions, un commentaire `//` introduit chaque bloc
  logique (« 1. on vérifie… », « 2. on calcule… »).
- Chaque boucle est précédée d'un commentaire qui dit : sur quoi on itère,
  ce qu'on accumule, et ce qu'on obtient à la fin.

## Boucles simples

- On préfère `for (final element in liste) { ... }` avec un accumulateur
  explicite déclaré juste avant.
- Pas de chaînes `.map().where().fold()` imbriquées. Un seul `.map` pour
  transformer une liste en liste de widgets est accepté, s'il est commenté.
- Une boucle fait **une seule chose**. Si elle doit en faire deux, on écrit
  deux boucles ou on extrait une fonction nommée.
- Pas d'expression conditionnelle compliquée dans l'en-tête de la boucle.

## Interface

- Tout le style vient de `lib/theme/` (couleurs dans `AppColors`, thème
  Material 3 dans `buildAppTheme`). Aucune couleur en dur dans les écrans.
- Les composants réutilisables sont dans `lib/widgets/` (`GradientHeader`,
  `DisciplineAvatar`, `StatusChip`, `EmptyState`, `SectionTitle`).
- Les animations utilisent `flutter_animate` et restent discrètes
  (fondu + léger glissement à l'apparition, 200 à 400 ms).
- Les scores circulaires utilisent `percent_indicator`.

## Tests

- Les `Key` utilisées par les tests de widgets (`login-email`, `start-java`,
  `test-validate`, `editor-save`…) ne changent pas : elles sont le contrat
  entre l'interface et les tests.
