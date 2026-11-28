class_name CookRecipe
extends Resource

## A dish (cooking/data/*.tres): what goes in, how it has to be prepared,
## and what eating or drinking it does. Recipes exist whether or not the
## player has found them; the kitchen just checks what's in a vessel
## against all of them (Cookbook.match_recipe).

@export var id := ""
@export var display_name := ""
## Ingredient ids that must all be in the vessel (in any order).
@export var ingredients: Array[String] = []
## The vessel the finished dish is served in ("mug", "bowl").
@export var vessel := ""
## Conditions the vessel's contents must meet, by name -> value:
## "water_hot" (the water was hot when poured), "cooked" (cooked through).
@export var conditions := {}
## The finished dish's look: a model, or empty for the vessel's own
## placeholder (cooking/props.gd).
@export_file("*.glb", "*.tscn") var dish_model := ""

## Added to the vitals when it's had (ids in game_state.gd VITALS):
## "health", "hunger", "hydration", "stamina", "temp".
@export var nutrition := {}
## Temporary attribute modifiers, multipliers by name: "move_speed",
## "strength", "stamina_regen", "env_resistance" (1.1 = +10 %).
@export var modifiers := {}
## How long the modifiers last, in seconds of play.
@export var effect_duration := 300.0
## What Gana says (or thinks) when he has it.
@export var on_consume := ""
## Story flag set the first time it's had ("ate_meal").
@export var first_time_flag := ""
