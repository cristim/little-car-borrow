extends Node
## Global signal hub for decoupled cross-system communication.

# Player signals
signal player_health_changed(current: float, max_hp: float)
signal player_died
signal player_respawned
signal player_money_changed(amount: int)

# Vehicle signals
signal vehicle_entered(vehicle: Node)
signal vehicle_exited(vehicle: Node)
signal vehicle_speed_changed(speed_kmh: float)
signal vehicle_damaged(vehicle: Node, amount: float)
signal vehicle_destroyed(vehicle: Node)
signal force_exit_vehicle(vehicle: Node)

# Wanted level signals
signal crime_committed(crime_type: String, heat_points: int)
signal wanted_level_changed(level: int)
signal police_search_started
signal police_search_ended

# Mission signals
signal mission_available(mission_data: Dictionary)
signal mission_started(mission_id: String)
signal mission_completed(mission_id: String)
signal mission_failed(mission_id: String)
signal mission_objective_updated(objective_text: String)
signal mission_marker_reached(mission_id: String, marker_type: String)
signal missions_refreshed
signal mission_timer_updated(time_remaining: float)

# Weapon signals
signal weapon_switched(weapon_idx: int)
signal weapon_unlocked(weapon_idx: int)

# UI signals
signal show_notification(text: String, duration: float)
signal show_interaction_prompt(text: String)
signal hide_interaction_prompt

# Pedestrian signals
signal pedestrian_killed(pedestrian: Node)

# World signals
signal time_of_day_changed(hour: float)
