# ToonStatus
Simple addon to keep track of interesting stats. Tracks gold, artifact power level, resources and item level to help you decide at a glance what to spend your play time working on. Stats for every toon that has logged in with the add-on active are shown 
in the dialog.

The data is brought up-to-date for a toon when you log in, and when you display the dialog. Future versions will synchronize data automatically on logout or on status updates as well.

# Usage
`/ts` to toggle the ToonStatus table dialog. Adds current player to the active list if they are not active.

`/ts csv` to get all data in comma-separated values format. Data is pre-selected, just hit ctrl-c to copy to the clipboard, and paste into your favorite spreadsheet program.

`/ts help` to display this information.

`/ts sort [level gold artifact_power war_resources service_medal residuum ilvl]` to sort the data by the given resource. 

`/ts stat [level gold artifact_power war_resources service_medal residuum ilvl]` to filter stats. The filter does not persist, all stats will be shown on subsequent calls.

`/ts toon [add remove] Player (Player2 ...)` to add or remove toons from display. Note: names are case-sensitive.

`/ts update` to update current player data without displaying anything. Can be used in a macro with /logout to save before exit.
