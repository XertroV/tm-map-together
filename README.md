# Map Together

Multiplayer Map Editor for TM2020.

License: Public Domain

Authors: XertroV

Suggestions/feedback: @XertroV on Openplanet discord

Code/issues: [https://github.com/XertroV/tm-map-together](https://github.com/XertroV/tm-map-together)

GL HF


todo:
- block/prevent undo redo

- detect test mode and session, only update after
- add server choice
- svr: remove players
- svr: parallel reads / per player
- sync period where inputs are disabled
-

# rules for mapping

- vanilla only (custom blocks / items possible but not supported)
- no media tracker
- validation isn't supported
- leaving test mode might cause updates
- skins not yet supported
- no undo / redo
- placing / deleting blocks will send them to the server, then undo them, then replay things in the right order (so everyone has the same map)
- no item editor


- need a feed of all objects placed/deleted
- can do E++ stuff by using MB to nudge, instead of modifying and refreshing -- that will be compatible with hooks
