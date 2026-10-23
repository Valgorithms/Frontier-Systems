@abstract
class_name PressureRoomOwner
extends SimulationSystem

## Typed construction boundary without dependencies on concrete owner scripts.
## No base instance can accept a command or install an unvalidated candidate.

@abstract func bind_room_owners(production: Node, access: Node, world: StringName, region: StringName) -> ServiceResult

@abstract func install_prepared_room_state(state: Dictionary) -> void

@abstract func room_area(door_id: String) -> float

@abstract func room_difference(door_id: String) -> float

@abstract func validate_room_links(production: Dictionary, access: Dictionary, pressure_record: Dictionary = {}, tick: int = 0, inventory: Dictionary = {}) -> ServiceResult

@abstract func record_from_prepared(state: Dictionary) -> Dictionary

@abstract func prepare_room_change(context: AuthenticatedCommandContext, request: String, operation: String, door_id: String, production: Dictionary, tick: int) -> ServiceResult

@abstract func room_observation(door_id: String) -> Dictionary
