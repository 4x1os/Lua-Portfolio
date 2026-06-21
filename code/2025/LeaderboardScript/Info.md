This was originally made to handle a leaderboard which could support teams and a nesting of multiple subteams within.
The teams used are customizable and adjustable based on the Team
object, and shows a custom leaderboard for the players, displaying information based on rank and affiliated faction.

Changing teams is dependant on the player's available groups. Video demo available in folder.

This is an older version, but the leaderboard was eventually updated to track join/leave logs rather than requesting data every single time it was opened and rehydrating the panel every time, 
and the teams were eventually replaced with a config file which would track groupings rather than using team objects and folders.
