class_name CookIngredient
extends Resource

## One cooking ingredient (cooking/data/*.tres). The cooking HUD, the
## kitchen's drop targets and the recipes all read these, so a new
## ingredient is a new file, not new code.

## Unique id ("coffee_grounds"), used by recipes and the pantry.
@export var id := ""
@export var display_name := ""
## What's shown floating in its slot and held under the cursor: a model
## file (.glb/.tscn), or empty for a built-in placeholder (cooking/props.gd
## builds one by `id`).
@export_file("*.glb", "*.tscn") var model_path := ""
@export var model_scale := 1.0

## How much there is: "unlimited" (no indicator), "volume" (a fill level
## 0..1 shown as the liquid in its container), "count" (a number).
@export_enum("unlimited", "volume", "count") var supply := "count"
## Taken per use: a share of the container for "volume", 1 for "count".
@export var use_amount := 1.0
## At or below this a "volume" supply shows its low warning.
@export var low_at := 0.25

## Effects of the ingredient itself (a recipe's are added on top when it's
## part of one): vitals ids -> amount (see game_state.gd VITALS).
@export var nutrition := {}
## How it's used: "drop" (released over a vessel), "pour" (poured in).
@export var interactions: Array[String] = ["drop"]
## Vessels it can go into ("mug", "kettle", "pan").
@export var destinations: Array[String] = []
## "on_use": taken from the supply when it lands in a vessel (never when a
## release misses).
@export var consumption := "on_use"
## The short verb for the drop prompt: "Release to add coffee grounds".
@export var prompt_verb := "add"
