# Map Together

Multiplayer Map Editor for TM2020.

License: Public Domain

Authors: XertroV

Suggestions/feedback: @XertroV on Openplanet discord

Code/issues: [https://github.com/XertroV/tm-map-together](https://github.com/XertroV/tm-map-together)

GL HF


todo:
- [x] block/prevent undo redo
- [x] detect test mode and session, only update after
- [x] add server choice
- [x] svr: remove players
- [x] svr: parallel reads / per player
- sync period where inputs are disabled

- SIGNS FUCK EVERYTHING
- SnowRoadPillarStriaght
- RallCastleWallStraightPillar
-
- send custom items
- wait for blocks when entering editor mb?
- cursor and camera of other players

- deleting macroblock crashed game??

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
