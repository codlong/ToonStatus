# ToonStatus
Simple addon to keep track of interesting stats. Tracks gold, item level, adventure campaign progress, and 
interesting currency balances to help you decide at a glance what to spend your play time working on. Stats for every toon that has been added to the add-on are shown in the dialog.

The data is brought up-to-date for a toon when you log in, when you display the dialog, and on several UI events.

# Usage
`/ts` to toggle the ToonStatus table dialog. Adds current player to the active list if they are not active.

`/ts csv` to get all data in comma-separated values format. Data is pre-selected, just hit ctrl-c to copy to the clipboard, and paste into your favorite spreadsheet program.

`/ts help` to display this information.

`/ts toon [add remove] Player (Player2 ...)` to add or remove toons from display. Note: names are case-sensitive.

`/ts update` to update current player data without displaying anything. Can be used in a macro with /logout to save before exit.
