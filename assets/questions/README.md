# Questions par défaut

Un fichier JSON par discipline : `java.json`, `algo.json`, `html_css.json`.
Le nom du fichier est le **code** de la discipline (voir `lib/models/discipline.dart`).

## À quoi servent ces fichiers ?

- **Premier démarrage** : si la table `questions` est vide, `seedIfEmpty`
  (`lib/data/app_database.dart`) lit les trois fichiers et insère leurs questions.
- **Menu « Réinitialiser (questions par défaut) »** de l'admin : `QuestionRepository.resetFromDefaults`
  relit le fichier de la discipline et remplace toutes ses questions.

Ils utilisent **exactement le même format** que l'import JSON de l'interface admin
(`lib/logic/question_json.dart`), donc un fichier exporté depuis l'application peut
être recopié ici.

## Format

```json
{
  "discipline": "java",
  "questions": [
    {
      "text": "Quel mot-clé déclare une constante ?",
      "type": "radio",
      "timeLimit": 30,
      "choices": [
        { "text": "final", "correct": true },
        { "text": "static" },
        { "text": "const" }
      ]
    }
  ]
}
```

| Champ | Type | Rôle |
|---|---|---|
| `discipline` | texte | `java`, `algo` ou `html_css`. Doit correspondre au nom du fichier. |
| `questions` | liste | Au moins une question. |
| `text` | texte | Énoncé de la question (obligatoire, non vide). |
| `type` | texte | `radio` = une seule bonne réponse, `checkbox` = plusieurs. |
| `timeLimit` | entier | Temps limite en secondes, strictement supérieur à 0. |
| `choices` | liste | Au moins 2 choix. |
| `choices[].text` | texte | Texte du choix (obligatoire, non vide). |
| `choices[].correct` | booléen | `true` pour une bonne réponse. Absent = `false`. |

## Règles de validation

Vérifiées par `validateQuestion` à l'import et dans l'éditeur ; les fichiers de ce
dossier doivent les respecter (`resetFromDefaults` les revalide avant de les insérer) :

- au moins 2 choix, chacun avec un texte ;
- `radio` : **exactement** 1 bonne réponse ;
- `checkbox` : **au moins** 1 bonne réponse ;
- `timeLimit` en secondes, `> 0`.
