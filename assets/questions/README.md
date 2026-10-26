# Questions par défaut

Un fichier JSON par discipline (`java`, `algo`, `html_css`). Même format que l'import
JSON de l'interface admin :

```json
{ "discipline": "java",
  "questions": [
    { "text": "…", "type": "radio" | "checkbox", "timeLimit": 30,
      "choices": [ { "text": "…", "correct": true }, … ] } ] }
```

Règles : au moins 2 choix, `radio` = exactement 1 bonne réponse, `checkbox` = au moins 1,
`timeLimit` en secondes > 0.
