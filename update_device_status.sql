-- Insert or update device status data provided by user
INSERT INTO device_status (id, device_name, valve_status, water_flow, status, last_update)
VALUES 
    ('632e6ea6-ef66-4c48-86d0-8586f215cdb0', 'Device 3', 'CLOSED', 0.00, 'OFFLINE', '2026-01-06 19:28:21.949448+00'),
    ('7a766cf3-25c6-4540-9892-9c83e92f7945', 'Device 2', 'CLOSED', 0.00, 'OFFLINE', '2026-01-06 11:22:23.560077+00'),
    ('c82c8c1c-e045-46e2-987b-ec56283e026f', 'Device 1', 'OPEN', 1.00, 'ONLINE', '2026-01-06 19:28:26.842574+00')
ON CONFLICT (id) DO UPDATE SET
    device_name = EXCLUDED.device_name,
    valve_status = EXCLUDED.valve_status,
    water_flow = EXCLUDED.water_flow,
    status = EXCLUDED.status,
    last_update = EXCLUDED.last_update;
