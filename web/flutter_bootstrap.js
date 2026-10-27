// Amorçage personnalisé de l'application web (modèle Flutter : les deux
// balises {{…}} sont remplacées au build par le chargeur et la configuration).
//
// Différence avec l'amorçage par défaut : AUCUN service worker n'est
// enregistré. Le service worker de Flutter garde en cache l'ancienne version
// de l'application et la sert même après une mise à jour, tant que tous les
// onglets ne sont pas fermés : les testeurs voyaient encore l'ancien nom et
// l'ancien compte admin. Sans lui, chaque chargement prend la dernière
// version publiée.
{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({});
