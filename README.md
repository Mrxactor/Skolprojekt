# Skolprojekt – Bygg din app-idé

Ett enkelt verktyg för elever i årskurs 4 som lär dem att tänka från idé till app.

## GitHub Pages

När GitHub Pages är aktiverat från `main` / `root` används denna adress:

https://mrxactor.github.io/Skolprojekt/

## Så fungerar övningen

Eleverna arbetar i grupper om högst tre personer och fyller i:

- gruppnamn eller gruppnummer
- deltagare 1–3
- app-idé
- målgrupp
- problemet appen ska lösa
- funktioner
- stil och färger
- appens namn

När gruppen är klar kan den:

1. skapa en färdig AI-prompt
2. kopiera prompten
3. spara gruppens arbete centralt

## Lagring

Svar sparas i Supabase-tabellen `app_ide_submissions`.

Eleverna får bara skicka in svar. De kan inte läsa andra gruppers inlämningar.

Lärarens Supabase-projekt:

https://supabase.com/dashboard/project/mytbxohrlwprlgmudnsg/editor

## Filer

- `index.html` – komplett elevsida
- `supabase_setup.sql` – databasschema och RLS-policy

## Publicering

GitHub Pages ska publicera direkt från:

- Branch: `main`
- Folder: `/ (root)`
