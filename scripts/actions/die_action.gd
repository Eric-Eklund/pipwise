class_name DieAction
extends Resource
## What spending a die does.
##
## Because dice are currency rather than points, a die face *is* an action.
## Adding a new effect is a new subclass plus a .tres on a face — the engine
## only ever knows this base class, so it never has to change.

## Short label shown on the die and in any explanation UI.
@export var description : String = ""

## Whether the action can run against the current state. The view uses this to
## grey out dice that would do nothing.
func can_apply(_context : GameContext) -> bool:
	return true

## Applies the effect. Subclasses must override.
func apply(_context : GameContext) -> void:
	push_error("DieAction.apply() not overridden in %s" % get_script().resource_path)
