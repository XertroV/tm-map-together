# Map Together

Multiplayer Map Editor for TM2020.

License: Public Domain

Authors: XertroV

Suggestions/feedback: @XertroV on Openplanet discord

Code/issues: [https://github.com/XertroV/tm-map-together](https://github.com/XertroV/tm-map-together)

GL HF


todo:
recent:
- [x] disable sweeps
- [x] server issue limiting to 25 blocks, only triggers more on update
- [x] limited undo support
- [x] server: map size, base/mood, car, rules_flags,
- [ ] better UI
- [x] create map base
- [ ] ping messages every 2s or so
- [ ] timeout detection
- [x] player join leave announcements (tmx together rip)
- [ ] player stats (total placed, deleted, time spent, etc)
- [ ] admin tools (kick / ban)
- [ ] status hud (processing updates)
- [ ] follow mode (control camera)
- [ ] time of day update msgs
- [ ] custom items


- [x] block/prevent undo redo
- [x] detect test mode and session, only update after
- [x] add server choice
- [x] svr: remove players
- [x] svr: parallel reads / per player

- follow mode -- update camera to match user


- version checking
  - can abuse bad room id for version?

- room options:
  - allow custom items
  - map base size
  - map mood
  - set car (stadium / rally / snow / desert)
  - block delete all

- reconnect to server issue on desync (then it rebuilds)
  - avoid rebuild (use autosave with sequence number?)
  - avoid needing to restart map at all (detect desync and reapply actions)

- grand2020: laggy when building together after a while
- (this is okay) test driving updates when you leave

- optimize loading prior map, break into chunks
- add autosave or saved map pre-upload / download to avoid replaying history
  - requires sequence numbers

- clear all locked down
- undo capacity for admin / mods

- skin sync

- tm2 map together

does it build entire map

what if 2 ppl load diff maps

-


- custom item uploads

- game crash on reload or joining room

- sync period where inputs are disabled

- seq numbers on packets

- rejoin from X spot

- [x] separate loop for reading packets



- demarcate packets with start / end
  - 0x2a2a2a5452415453 (b"START***")
  - len: uint32
  - len: uint32 (repeated for packet framing) & 0xFFFFFF | (ty << 24)
  -   check len & 0xFFFFFF are eq, and read type
  - 0x53444e452a2a2a2a (b"****ENDS")


- SIGNS FUCK EVERYTHING
- SnowRoadPillarStriaght
- RallCastleWallStraightPillar

-
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
