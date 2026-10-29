extends ProductionDevelopmentCommand
class_name HostedPaidDoorCommand

## Door-only transport lease; no transport state enters the persisted owners.
var host_reference: WeakRef
var peer_id: int
var slot: int
var session_lease: RefCounted
var body_id: String


func current_session(simulation_context: Node) -> ServiceResult:
	var host: Variant = host_reference.get_ref() if host_reference != null else null
	if not is_instance_valid(host) or not is_instance_valid(host._world) or host._world != simulation_context or not host._peers.has(peer_id) or host._peers[peer_id].slot != slot or authenticated_context == null or session_lease == null or host._peers[peer_id].get("door_session_lease") != session_lease:
		return ServiceResult.failure(&"door_session_expired", "The door command's authenticated session has ended.")
	var live: AuthenticatedCommandContext = host._context(slot, peer_id)
	if live.session_id != authenticated_context.session_id or live.principal_id != authenticated_context.principal_id:
		return ServiceResult.failure(&"door_session_expired", "The door command's authenticated binding changed.")
	var inventory: InventorySimulationSystem = host._world.get_simulation_system(InventorySimulationSystem.SYSTEM_ID)
	if inventory == null: return ServiceResult.failure(&"door_body_changed", "The door inventory owner is unavailable.")
	var actor: ServiceResult = inventory.authorize(authenticated_context, true)
	if not actor.is_success or actor.value != body_id: return ServiceResult.failure(&"door_body_changed", "The queued door command belongs to another body binding.")
	return ServiceResult.success()


func validate(simulation_context: Node) -> ServiceResult:
	var active: ServiceResult = current_session(simulation_context)
	return super.validate(simulation_context) if active.is_success else active


func apply(simulation_context: Node) -> ServiceResult:
	var active: ServiceResult = current_session(simulation_context)
	return super.apply(simulation_context) if active.is_success else active
