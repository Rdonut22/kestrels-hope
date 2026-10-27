extends Interactable

## Personal log entries. Newest first. Edit freely.
const LOGS := [
	{
		"title": "Day 43",
		"body": "Ran the coffee machine's descale cycle. It's the most maintained system on this ship and I'm not ashamed of that.\n\nThere's a world below us now. Green. Clouds. First thing worth looking at in weeks.",
	},
	{
		"title": "Day 38",
		"body": "Reactor's holding at thirty-one percent. Fuel's the real problem. I've done the math three times and I don't like the answer any better.\n\nNav array still dead. I've stopped counting the stars.",
	},
	{
		"title": "Day 21",
		"body": "Cleaned out Hale's bunk today. Couldn't do it. Put everything back the way it was.\n\nTalked to the ship out loud for a while. She doesn't talk back, but she listens.",
	},
	{
		"title": "Day 1",
		"body": "Pirates hit us on the outer rim, coming back from Aphelion. Hull breach in the cargo bay. The reactor took a round.\n\nI'm the only one left.\n\nUshida will want a report. I don't know what to tell them.",
	},
]


## Crash-landed version: adds the entry written after the crash.
@export var crashed := false

const CRASH_LOG := {
	"title": "Day 44",
	"body": "Went down. Something hit us in the upper atmosphere — or we hit it.\n\nThe Kestrel held together better than I did. Lounge is open to the sky now, and there are trees where the stars used to be.\n\nBeacon's on. Coffee machine survived. Priorities.",
}


func interact(_player: Node) -> void:
	hud().open_screen("PERSONAL LOG", [CRASH_LOG] + LOGS if crashed else LOGS)
