# Design Overview

## Pitch

ROAD COMPANY is a dark fantasy mercenary caravan-company RPG about keeping a small armed outfit alive while hauling contracts through hostile roads. The company is poor, useful, and expendable. The player makes pressure-filled route, supply, contract, and battle decisions rather than managing a heroic party.

## Pillars

- Road pressure: every route spends food, vigor, morale, and time.
- Company survival: fighters are named, fragile, injured, and replaceable only with cost.
- Tactical brutality: armor, HP, fatigue, morale, and positioning matter more than flashy abilities.
- Faction consequences: contracts help one patron and can anger another.
- Data-first production: JSON content, simple GDScript systems, 2D tokens, and procedural placeholders.

## MVP Loop

Start at settlement -> view contract board -> accept contract -> travel a connected route -> consume supplies -> trigger event or combat -> resolve tactical battle -> view aftermath/camp -> update company state -> return to settlement or road layer.

## Systems Overview

The road layer loads locations and routes from JSON. Routes define travel costs, danger, terrain tags, encounter tables, and battlefield tags.

Company state is runtime data loaded from `data/company/company_start.json`. It tracks resources, roster, graveyard, reputation, current location, and active contract.

Contracts are loaded from `data/contracts/contracts.json`. The prototype supports escort caravan, hunt bandits, recover missing wagon, and capture bounty target contracts.

Combat uses a 2D axial hex grid. Units have AP, fatigue, HP, body armor, head armor, morale state, initiative, skills, weapons, injuries, and death state. The current enemy AI is intentionally simple.

Camp is the recovery and accounting screen after travel or combat. It displays losses, injuries, loot, rewards, and reputation changes, then offers Rest, Repair, Treat Wounds, and Continue.
