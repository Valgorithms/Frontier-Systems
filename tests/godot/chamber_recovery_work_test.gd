extends SceneTree

var failures: int = 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func run() -> void:
	var source := PressureVolumeState.from_pressure(&"source", 3.6, 293.15, 101.325)
	var receiver := PressureVolumeState.from_pressure(&"receiver", 996.4, 293.15, 101.325)
	var before: Array = [source.to_record(), receiver.to_record()]
	var first: ServiceResult = ChamberRecoveryWork.prepare(source, receiver, 0.1)
	check(first.is_success and first.value.charged_joules >= 1, "equal initial pressure still charges endpoint compression work")
	for quantity in [0.0, -0.1, 0.100001, INF, NAN, 1e-30]:
		check(not ChamberRecoveryWork.prepare(source, receiver, quantity).is_success, "invalid or unrepresentable quantity rejected")
	check([source.to_record(), receiver.to_record()] == before, "successful and rejected proposals leave both live volumes unchanged")
	check(not ChamberRecoveryWork.prepare(source, source, 0.1).is_success, "same volume cannot be source and receiver")
	var unequal := PressureVolumeState.from_pressure(&"unequal", 996.4, 293.150001, 101.325)
	check(not ChamberRecoveryWork.prepare(source, unequal, 0.1).is_success, "temperatures must match exactly")
	var high := PressureVolumeState.from_pressure(&"high", 3.6, 293.15, 109.0)
	var low := PressureVolumeState.from_pressure(&"low", 996.4, 293.15, 1.0)
	var downhill: ServiceResult = ChamberRecoveryWork.prepare(high, low, 0.1)
	check(downhill.is_success and downhill.value.charged_joules == 1, "downhill work costs one joule with no energy credit")
	var below_floor := PressureVolumeState.from_pressure(&"below", 3.6, 293.15, 1.0)
	check(not ChamberRecoveryWork.prepare(below_floor, receiver, 0.1).is_success, "source after-state below one kPa rejected")
	var full := PressureVolumeState.from_pressure(&"full", 996.4, 293.15, 110.0)
	check(not ChamberRecoveryWork.prepare(source, full, 0.1).is_success, "receiver after-state above 110 kPa rejected")
	var ratio_source := PressureVolumeState.from_pressure(&"ratio", 3.6, 293.15, 5.0)
	check(not ChamberRecoveryWork.prepare(ratio_source, receiver, 0.00001).is_success, "endpoint ratio above sixteen rejected independently of work cap")
	var expensive := PressureVolumeState.from_pressure(&"expensive", 3.6, 293.15, 10.0)
	check(not ChamberRecoveryWork.prepare(expensive, receiver, 0.1).is_success, "work above 250 joules rejected even below ratio limit")
	# Binary-exact mole increments exercise inclusive pressure endpoints without
	# adding a tolerance to production admission.
	var unit_volume: float = PressureVolumeState.GAS_CONSTANT_J_PER_MOL_K * 293.15 / 1000.0
	var small: float = 1.0 / 1024.0
	var edge_source := PressureVolumeState.new(&"edge-source", unit_volume, 293.15, 1.0 + small)
	var edge_receiver := PressureVolumeState.new(&"edge-receiver", unit_volume, 293.15, 16.0 - small)
	check(ChamberRecoveryWork.prepare(edge_source, edge_receiver, small).is_success, "inclusive one-kPa source and ratio-sixteen endpoints")
	edge_receiver.gas_moles += small
	check(not ChamberRecoveryWork.prepare(edge_source, edge_receiver, small).is_success, "just above ratio-sixteen rejected")
	edge_source.gas_moles = 110.0 + small
	edge_receiver.gas_moles = 110.0 - small
	check(ChamberRecoveryWork.prepare(edge_source, edge_receiver, small).is_success, "inclusive 110-kPa receiver endpoint")
	edge_receiver.gas_moles += small
	check(not ChamberRecoveryWork.prepare(edge_source, edge_receiver, small).is_success, "just above receiver cap rejected")
	for work in [79.9999999, 80.0000001, 248.9999999, 249.0000001]:
		var quantity: float = 0.1
		var ratio: float = exp(work * 0.35 / (quantity * PressureVolumeState.GAS_CONSTANT_J_PER_MOL_K * 293.15))
		var priced_source := PressureVolumeState.new(&"priced-source", unit_volume, 293.15, 10.0 + quantity)
		var priced_receiver := PressureVolumeState.new(&"priced-receiver", unit_volume, 293.15, 10.0 * ratio - quantity)
		var priced: ServiceResult = ChamberRecoveryWork.prepare(priced_source, priced_receiver, quantity)
		if work > 249.0: check(not priced.is_success, "just above 250-J price rejects without truncation")
		else: check(priced.is_success and priced.value.charged_joules == int(ceil(work)) + 1, "near-integer work rounds upward, including a 250-J batch")
	# Independent pinned finite-budget result; use returned detached states only.
	var initial: float = source.gas_moles
	var total: float = source.gas_moles + receiver.gas_moles
	var returned: float = 0.0
	var spent: int = 0
	var batches: int = 0
	while returned < initial * 0.2 and batches < 301:
		var quantity: float = minf(0.1, initial * 0.2 - returned)
		var proposal: ServiceResult = ChamberRecoveryWork.prepare(source, receiver, quantity)
		check(proposal.is_success, "finite twenty-percent route is physically admissible")
		if not proposal.is_success: break
		source = proposal.value.source_after
		receiver = proposal.value.receiver_after
		returned += quantity
		spent += int(proposal.value.charged_joules)
		batches += 1
	check(batches == 300 and spent == 22993, "pinned route costs 22993 J over 300 batches")
	check(returned == initial * 0.2, "small final batch ends at the immutable target")
	check(absf(source.gas_moles + receiver.gas_moles - total) < 1e-8, "bulk moles conserved within floating-point accumulation error")
	check(absf(source.pressure_kpa() - 81.06) < 1e-8, "twenty percent recovery leaves the expected finite source pressure")
	quit(failures)
