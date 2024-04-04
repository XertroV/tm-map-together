# Map Together

Multiplayer Map Editor for TM2020.

License: Public Domain

Authors: XertroV

Suggestions/feedback: @XertroV on Openplanet discord

Code/issues: [https://github.com/XertroV/tm-map-together](https://github.com/XertroV/tm-map-together)

GL HF


0.1.5
- numerous performance optimizations
- add server chat (shift+enter hotkey)
- expose many settings through settings tab in main UI
- reduce overhead when processing updates (may partially resolve lag/frame issues)
- add support for limiting players in a room
- ms support for timestamps
- add custom titles
- fix player labels lerping to screen position instead of world position
- support testing mode in cursor status color
- smooth cursor anims a bit
- add stats (under yield) for created and destroyed instances of plugin classes (can be used for debug)
- flag to avoid using nostadium base patch in case of game crashes when opening editor
- make max placement time a configurable setting
- numerous additional settings
- update support for next server version


E++:
- fix change of placement mode when freeblocks are deleted (item -> free-ground, for example)



- many bugfixes
- lowerable update frequency
- player tag toggle
- expose settings prelim



to test:
- [ ] crash with many players for an extended period (ref count > 1 million issue)
- [ ] performance with 16+ players in a room over time (the 'lag' issue with long frames)
- [ ] is the server reliably sending msgs?

- [ ] desync detection + custom blocks/items (no loop, or other issues)

todo:
recent:
- [ ] better UI
- [ ] ping messages every 2s or so
- [ ] timeout detection
- [ ] player stats (total placed, deleted, time spent, etc)
- [ ] admin tools (kick / ban)
- [?] follow mode (control camera)
- [ ] time of day update msgs
- [ ] custom items
- [ ] server update msgs (alerts to active users that server will be going down)
- [ ] undo stack bug
- [ ] fade player labels based on distance from camera vs camera target distance
- [ ] save session for playback
- [ ] change room player limit
- [ ] remove custom item from cursor
- [ ] on-grid free block only
- [ ] auto-duplicate detection
- [ ] compress macroblocks
- [ ] map partitioning idea for testing without interference
- [ ] save mapper metadata in track
- [ ] add app setting for tmx author (autorecord in metadata)
- [ ] colored names
- [ ] add compression to macroblocks (detect place-deletes, delete-places, repeated skin application, etc)
- [ ] add ding on chat msg (or one that mentions your name only maybe)
- [ ] freeblock nudging is BAAAAD
-

v0.1.6
- [x] fix undo
- [x] enable skins -- can be disabled in settings under optional features
- [x] add one frame delay after leaving test mode
- [x] dynamic rate-limiting of cursor updates (more ppl -> less often)
- [x] optimize vehicle pos update packets
- [x] add admin can always join thing
- [x] chat log snap to bottom
- [x] name custom block abusers
- [x] fix server lockup and disconnect reconnect
- [x] fix: chat use server timestamp
- [x] fix: players in list after leaving bug
- [x] vehicle marker jelly when moving camera


.0.1.5x
- [x] server chat
- [x] server: map size, base/mood, car, rules_flags,
- [x] create map base
- [x] player join leave announcements (tmx together rip)
- [x] status hud (processing updates) - pending updates hud
- [x] disable sweeps
- [x] server issue limiting to 25 blocks, only triggers more on update
- [x] limited undo support
- [x] add room player limit
- [x] free block del cursor change (items / ghost)
- [x] settings tab
- [x] block/prevent undo redo
- [x] detect test mode and session, only update after
- [x] add server choice
- [x] svr: remove players
- [x] svr: parallel reads / per player

- follow mode -- update camera to match user



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


## problems to solve

- finding blocks in large map:
  - points (not regions)
  - oct tree
  - expand as more blocks placed
  - faster duplicate block checks?
  - export from E++
  - tie into map cache and block/item hooks
- comparing maps to calculated spec
- finding differences between calculated and actual
  - use oct tree?

- undo
  - we have a local stack
  - need to ignore action from our undo queue
    - keep track of index?
    - ignore most recent flag
