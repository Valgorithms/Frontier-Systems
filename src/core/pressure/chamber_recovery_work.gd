extends RefCounted
class_name ChamberRecoveryWork

## Detached isothermal chamber-to-habitat compression proposal. Does not authorize
## a job, draw energy, change either volume, or publish a prepared transaction.
const EFFICIENCY: float = 0.35
const MAX_BATCH_MOLES: float = 0.1
const MAX_BATCH_JOULES: int = 250
const MIN_SOURCE_KPA: float = 1.0
const MAX_RECEIVER_KPA: float = 110.0
const MAX_PRESSURE_RATIO: float = 16.0


static func prepare(source: PressureVolumeState, receiver: PressureVolumeState, quantity_moles: float) -> ServiceResult:
	if source == null or receiver == null or not source.is_valid() or not receiver.is_valid(): return denied()
	if source == receiver or source.volume_id == receiver.volume_id: return denied()
	if source.temperature_kelvin != receiver.temperature_kelvin: return denied()
	if not is_finite(quantity_moles) or quantity_moles <= 0.0 or quantity_moles > MAX_BATCH_MOLES or quantity_moles >= source.gas_moles: return denied()
	var source_after := PressureVolumeState.new(source.volume_id, source.volume_m3, source.temperature_kelvin, source.gas_moles - quantity_moles)
	var receiver_after := PressureVolumeState.new(receiver.volume_id, receiver.volume_m3, receiver.temperature_kelvin, receiver.gas_moles + quantity_moles)
	# Reject quantities smaller than representable changes; never clamp/delete gas.
	if not source_after.is_valid() or not receiver_after.is_valid(): return denied()
	if source_after.gas_moles >= source.gas_moles or receiver_after.gas_moles <= receiver.gas_moles: return denied()
	var source_kpa: float = source_after.pressure_kpa()
	var receiver_kpa: float = receiver_after.pressure_kpa()
	if source_kpa < MIN_SOURCE_KPA or receiver_kpa > MAX_RECEIVER_KPA: return denied()
	if source_kpa >= source.pressure_kpa() or receiver_kpa <= receiver.pressure_kpa(): return denied()
	var ratio: float = receiver_kpa / source_kpa
	if not is_finite(ratio) or ratio > MAX_PRESSURE_RATIO: return denied()
	# The endpoint ratio bounds the increasing ratio over the entire batch.
	# Downhill transfer still costs one joule and never generates energy credit.
	var work: float = quantity_moles * PressureVolumeState.GAS_CONSTANT_J_PER_MOL_K * source.temperature_kelvin * log(maxf(1.0, ratio)) / EFFICIENCY
	if not is_finite(work) or work < 0.0 or work > float(MAX_BATCH_JOULES - 1): return denied()
	var charge: int = int(ceil(work)) + 1
	if charge < 1 or charge > MAX_BATCH_JOULES: return denied()
	return ServiceResult.success({"source_after": source_after, "receiver_after": receiver_after, "quantity_moles": quantity_moles, "charged_joules": charge})


static func denied() -> ServiceResult:
	return ServiceResult.failure(&"chamber_recovery_work_rejected", "The detached compression proposal exceeds a physical or work limit.")
