# Ramen

Adds ULX commands for preventing players from picking up props and placing/removing nails.

## Commands

All commands are located under "ZS ULX Commands" in the ULX menu.

- `noodle <PLAYER> [<TIME>]`  
	Bans the player from picking up props (and placing/removing nails, if that is enabled).  
	`TIME` (optional) specifies when the ban should expire -
	if set to 0, it will expire once the map is changed,
	otherwise it will expire after the specified amount of minutes.

- `unnoodle <PLAYER>`  
	Allows the player pick up props and place/remove nails again.

- `votenoodle <PLAYER>`  
	Starts a vote to `noodle` the specified player.

## Convars

- `cl_ramen_drawdistance <DISTANCE>`, default `256`  
	Range at which the noodle text ("BANNED FROM CADING") stops being rendered.

- `sv_ramen_hammer_override <BOOL>`, default `1`  
	Prevent players from placing/removing nails?

- `sv_ramen_allow_remove_noodled_nails <BOOL>`, default `1`  
	Should players not be penalized for removing nails placed by a noodled player?  
	This doesn't give the removed nail to the player.  
	*Note*: this option depends on a hook that doesn't exist on older versions of ZS. This option won't do anything if that hook doesn't exist.

- `ulx_votenoodleminvotes <NUMBER>`, default `3`  
	Amount of votes required for a `votenoodle` to succeed.

- `ulx_votenoodleminratio <RATIO>`, default `0.5`  
	Ratio of votes required for a `votenoodle` to succeed.

- `ulx_votenoodletimeout <TIME>`, default `-1`  
	Duration of ban given by `votenoodle`.
