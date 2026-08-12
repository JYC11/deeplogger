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