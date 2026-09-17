# V3 节点覆盖地图 / Phase 6

This is a schematic offline map, not a geopolitical boundary map, precise node location, latency test, or live status display. The silhouette and location dots do not depend on any remote mapping SDK or new permissions. Hong Kong and Taiwan use backend region codes `HK` and `TW` as distinct filter entries, without claiming national borders.

## Verified original behavior
- `lib/v3/pages/v3_nodes_page.dart` used search + continent selection + node list. It had no country-code filter or world view.
- Backend `NodeModel.code` already supports two-character region codes. Count only real nodes, never virtual auto entries.
- Existing automatic selection, manual row selection, latency actions, refresh, and search remain in place.

## Behavior / edge cases
- Only actual node codes produce highlighted markers; no fixed advertised coverage. Supported map pin positions are an approximate curated set. Valid but unmapped codes still appear in filter chips and coverage statistics.
- Selecting a map dot or region chip filters the node list; selecting that chip again or `全部地区` clears the filter. Selecting a continent and selecting a map code reset the other dimension to avoid stale contradictory filters. Search remains independent.
- If refresh removes the selected code, the active country filter is discarded at rendering time; users are not trapped in an un-clearable empty list.
- The map explicitly says `离线示意图` and does not suggest that a marker guarantees connectivity, exact country boundaries or a real geolocation fix.
- Both mouse and touch can use the region chips (map markers also accept taps); the existing accessible node list remains the primary selection surface.

## Verification gate
`flutter test`, `flutter analyze`, Windows 900×700 light/dark render and Android 360/390 light/dark render, plus manual screenshot acceptance. Tests cover real/virtual/unknown codes, map filtering and reset on subscription refresh, and narrow layouts. Do not merge this draft PR before checks and visual acceptance. Stage #82–#86 separately; they have not been merged into this branch.
