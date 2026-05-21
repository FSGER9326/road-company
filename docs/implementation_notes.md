# Implementation Notes

## Structure

The prototype is a text-first Godot 4 project. `project.godot` points to `game/scenes/main/Main.tscn`, which runs `game/scripts/main/Main.gd`. Most screens are generated in GDScript so the project stays easy to diff and extend.

Core runtime files:

- `game/scripts/core/DataStore.gd`: loads JSON content and provides ID lookup helpers.
- `game/scripts/core/CompanyState.gd`: owns runtime company state, route costs, contract results, combat persistence, and camp actions.
- `game/scripts/core/SeededRng.gd`: small deterministic RNG wrapper used by rule systems.
- `game/scripts/core/AutoplaySmoke.gd`: noninteractive deterministic escort smoke scenario.
- `game/scripts/road/RoadSystem.gd`: testable road travel, ambush, scout, and road event rules.
- `game/scripts/contracts/ContractSystem.gd`: testable contract acceptance and resolution rules.
- `game/scripts/combat/CombatSystem.gd`: testable combat setup, terrain, movement, attack, damage, morale, and turn-order helpers.
- `game/scripts/camp/CampSystem.gd`: testable camp action wrapper.
- `game/scripts/road/RoadScreen.gd`: settlement, resources, active contract, route list, and travel requests.
- `game/scripts/combat/CombatScreen.gd`: tactical hex combat, combat AI, morale, injuries, objective handling, and result generation.
- `game/scripts/camp/CampScreen.gd`: aftermath display and camp actions.

## Road to Combat

Travel starts from a selected route. The route consumes food and vigor immediately. Combat starts if the route danger is high, if the active contract targets that route or destination, or if the company has low vigor.

Road context feeds combat:

- high danger or low vigor marks the fight as an ambush;
- low vigor adds starting fatigue;
- escort contracts spawn a wagon objective;
- forest and mud route tags add blocked or slow hexes.

## Adding Content

Add locations in `data/world/locations.json`. Each location needs an ID, description, faction influence, market tags, and available contract IDs.

Add routes in `data/world/routes.json`. Routes must reference valid locations and define travel costs, danger, terrain tags, encounter table, and battlefield tags.

Add contracts in `data/contracts/contracts.json`. Contracts must reference valid factions, origin and target data, and an encounter ID.

Add fighters in `data/company/company_start.json`. Fighters must reference weapon and armor IDs from combat data.

Add enemies in `data/combat/enemies.json`, then include them in `data/combat/encounters.json`.

Run `python tools/validate_data.py` after any data change.

## Testing

Use `python tools/run_all_tests.py` as the default verification command. It runs validators, pure gameplay simulation tests, and Godot headless tests if a Godot executable is available. See `docs/VALIDATION.md` for exact commands and `docs/AGENT_HANDOFF.md` for commit handoff rules.

## Known Limitations

- No save/load.
- No recruitment or economy screen.
- Combat has no path preview, ability bar, or animation polish.
- Enemy AI only moves toward a nearby objective or fighter and attacks.
- Contract success is binary and currently resolves after victorious combat.
- Camp repairs can exceed original armor values; armor caps should be added once equipment durability is modeled.
