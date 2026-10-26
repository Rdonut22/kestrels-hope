extends Interactable

## Personal log entries. Newest first. Edit freely.
const LOGS := [
	{
		"title": "Entry 112",
		"body": "Ran the coffee machine's descale cycle. It's the most maintained system on this ship and I'm not ashamed of that.\n\nNav array still throwing errors. I'll take another look tomorrow.",
	},
	{
		"title": "Entry 111",
		"body": "Reactor's holding at seventy-two percent. Fuel's the real problem. I've done the math three times and I don't like the answer any better.",
	},
	{
		"title": "Entry 108",
		"body": "Quiet day. Cleaned the galley, recalibrated the airlock seals, talked to the ship out loud for a while.\n\nShe doesn't talk back, but she listens.",
	},
	{
		"title": "Entry 100",
		"body": "One hundred entries. When I bought the Kestrel's Hope I told myself I'd keep a log every day.\n\nI didn't think I'd mean it this literally.",
	},
]


## Crash-landed version: adds the entry written after the crash.
@export var crashed := false

const CRASH_LOG := {
	"title": "Entry 113",
	"body": "Went down. Something hit us in the upper atmosphere — or we hit it.\n\nThe Kestrel held together better than I did. Lounge is open to the sky now, and there are trees where the stars used to be.\n\nBeacon's on. Coffee machine survived. Priorities.",
}


func interact(_player: Node) -> void:
	hud().open_screen("PERSONAL LOG", [CRASH_LOG] + LOGS if crashed else LOGS)
