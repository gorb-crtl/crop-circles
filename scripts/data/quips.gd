class_name Quips
extends RefCounted
## Things the Overlord says. Add lines freely.

const INTRO: Array = [
	"Greetings, field operative. The humans must SEE our art.",
	"Drag across the wheat to flatten it. Close a loop and it becomes a crop circle.",
	"Rounder circles pay more. Buy crew in the shop. Make me proud. Or at least make me money.",
]
const IDLE: Array = [
	"The humans think it was wind. WIND. Make it rounder.",
	"I have crossed eleven galaxies for this wheat.",
	"Remember: we come in peace. And in circles.",
	"Mothership says our art is 'derivative'. Prove them wrong.",
	"Do the cows suspect? The cows always suspect.",
	"A perfect circle is worth a thousand blobs.",
	"I'd help, but my hands are for pointing.",
	"Fun fact: the farmer has called the newspaper four times.",
	"Our ancestors drew circles. Their ancestors drew circles. It's circles all the way up.",
]
const PERFECT: Array = [
	"PERFECT. I am weeping from all three eyes.",
	"Now THAT is a circle. Frame it. Beam it home.",
	"Flawless. The humans will write books about this one.",
]
const BLOB: Array = [
	"That is not a circle. That is a potato.",
	"Interesting. Abstract. Bad.",
	"I said circle, not 'whatever that is'.",
]
const BULLSEYE: Array = [
	"A BULLSEYE! Rings within rings! Glorious!",
	"Concentric! You've done this before, haven't you?",
]
const COW: Array = [
	"Cow acquired. She will be very confused and very happy.",
	"Another cow for the collection. Moo indeed.",
	"Abduction successful. Do not tell the farmer.",
]
const GOLDEN: Array = [
	"Golden wheat! Shiny! Mine!",
	"Ooh, the good stuff.",
]
const SLOT_WIN: Array = [
	"The Mothership smiles upon you.",
	"Winner! Gambling is a perfectly sound economic strategy.",
	"See? Space luck. It's a real thing.",
]
const SLOT_JACKPOT: Array = [
	"JACKPOT! Quick, before the Mothership audits us!",
	"JACKPOT!! I'm buying a second moon!",
]
const SLOT_LOSE: Array = [
	"The house always wins. We ARE the house. It's complicated.",
	"Unlucky. Pull it again. For science.",
	"That money was going to be a funding gap anyway.",
	"Hmm. The Mothership keeps that one.",
]
const SLOT_COW: Array = [
	"Three cows! The cows have abducted YOUR money. Ironic.",
]
const BUY: Array = [
	"A new recruit! Try not to step on it.",
	"Excellent. More hands. Well, more tentacles.",
	"Welcome aboard. Circles. That's the whole job.",
]
const GOAL: Array = [
	"The field is ready. Open the Signal tab when you want the farmer to harvest.",
]
const HARVEST: Array = [
	"Here comes the farmer. Look natural.",
	"Hide! ...We're three metres tall. Just stand still, then.",
]
const SEASON: Array = [
	"A new season. Bigger signal. Same wheat. Go.",
	"The wheat has regrown. The humans never learn.",
]
const COMBO: Array = [
	"Combo! Keep the circles coming!",
	"Chain them! CHAIN THEM!",
]
const WIN: Array = [
	"CONTACT! The Mothership heard us! ...They want more circles.",
]


static func pick(list: Array) -> String:
	return list[randi() % list.size()]
