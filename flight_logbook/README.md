# Flight Logbook – Digitální letecký deník

Jednoduchá aplikace v Flutteru pro elektronické zaznamenávání letů a sledování nalétaných hodin. Cílem je přiblížit se klasické papírové podobě pilotního deníku, ale s výhodami digitálního zápisu a přehledných statistik.

## Funkce

- Přehled letů: seznam záznamů s datem, tratí, typem a imatrikulací.
- Přidání/úprava letu: formulář s datem, odkud–kam, typem, imatrikulací a dobou letu (HH:mm).
- Statistiky: součet nalétaných hodin.
- Mapa letišť: zobrazení navštívených letišť (CZ ukázkový dataset v `assets/airports_min.json`).

Pozn.: Import letů z externích zařízení/aplikací a širší databáze letišť lze snadno doplnit (viz níže).

## Rychlé spuštění

Na Windows můžete spustit desktop/web variantu:

```powershell
# Instalace závislostí
flutter pub get

# Spuštění jako Windows aplikace
flutter run -d windows

# Nebo spuštění ve webovém prohlížeči
flutter run -d chrome
```

## Struktura

- `lib/models/flight.dart`: datový model letu (Hive ukládání).
- `lib/services/hive_service.dart`: inicializace a CRUD nad lokální databází.
- `lib/services/airport_index.dart`: jednoduchý index letišť načtený z JSON assetu.
- `lib/screens/flights_list_screen.dart`: přehled letů + mazání, přechod na editaci.
- `lib/screens/add_edit_flight_screen.dart`: formulář pro přidání/úpravu záznamu.
- `lib/screens/stats_screen.dart`: agregace a zobrazení celkových hodin.
- `lib/screens/map_screen.dart`: mapa (OpenStreetMap přes `flutter_map`) s navštívenými letišti.

## Rozšíření (doporučení)

- Import: přidat podporu CSV/GPX/JSON (např. přes `file_picker`) a mapování na model `Flight`.
- Databáze letišť: nahradit ukázkový `assets/airports_min.json` kompletnějším datasetem (IATA/ICAO + souřadnice).
- Kategorie časů: rozlišovat PIC/DUAL/IFR/NOC apod. a rozšířit statistiky.
- Synchronizace: volitelný export/import (např. do souboru nebo přes cloudové úložiště).

## Technologie

- Flutter, Material 3
- Lokální úložiště: Hive (`hive`, `hive_flutter`)
- Mapa: `flutter_map` + `latlong2` (OpenStreetMap)
- Formátování: `intl`
