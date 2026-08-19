## 2026-08-10

### from software engineer
- lists should be paginated or be endless scrolling (logs, equipment, certs, etc) not a simple query all
- we need a search/filter feature for lists
- we need to be able to order the lists ascending or descending by certain fields
- look for n+1 queries and fix them
- db migrations should be in .sql files and need a proper migration manager
- db migrations need to be idempotent and always backward compatible
- app needs a proper app logo, it's currently the default flutter logo (we will need to find someone for this)
- analysis needs to be done on security and performance
- tests needs to be done for photo upload (todo: think of how to do them)
- tank volume input needs separate number and drop down units section
- in general, inputs needing specific units should have a drop down selectable units section
- input guards/validation need to exist if they don't exist

## 2026-08-12

### from user
Ok notes on the fields
Altitude - should be "Sea Level (0m)" by default
Gas Type - should be "Air" by default
For Gear
Gear needs some default categories
- BCD
- Wetsuit
- Fins
- Dive Computer
- Torch
- Regulator
	- First Stage
	- Second Stage
- Other

Also in the main dive log entry - you should have an option to input gear that is not from your gear list (very common to use some of your own gear and rent some gear)

Certification
each cert should have the fields
- Organization
- Level
- ID#
- Image of certification (photo upload)

2026-08-19
manual QA result
- Despite creating gear, gear does not show up in dive log creation -> fixed
- Once forms are filled in and saved, they need to be cleared when a new form is opened (all forms) -> fixed
further feedback
- dive logs may need a delete button
- marine photo sightings should be possible to add separately (you were stuck at the allow app access to photos stage)
- only being able to add marine photo sightings when creating logs seems restrictive (full CRUD may be needed)
- in the future when stuck endlessly during manual testing, pause and ask for clarification
- when there is a lot of gear available to select, it may overflow a lot (haven't tested but the gear list seems to wrap) and that may need some other kind of UI
- the share on social media option puts the numbers from top to bottom which makes it read akward. putting the numbers left to right naturally is preferred
- additional feature request: manual backup and import from backup (no cloud, no signin etc) feature we should brainstorm together and solidify into a plan