--[[
	═══════════════════════════════════════════════════════════════
	AsyncWorkspaceMonitor — Single LocalScript (Client-Side Only)
	═══════════════════════════════════════════════════════════════
	
	Penempatan : StarterPlayerScripts / StarterGui (LocalScript)
	Engine     : Roblox Luau (strict mode)
	Arsitektur : Self-contained, zero external dependency
	
	Fitur:
	  ✓ Monitoring Workspace secara asinkron via task.spawn
	  ✓ Jeda acak (jitter) per iterasi — natural pacing
	  ✓ Error handling berlapis dengan pcall
	  ✓ Circuit breaker untuk mencegah infinite error loop
	  ✓ Delta detection (objek bertambah / berkurang)
	  ✓ Listener system dengan unsubscribe
	  ✓ Graceful shutdown & cleanup
	  ✓ Debug logging dengan toggle
	
	═══════════════════════════════════════════════════════════════
]]

--!strict

-- ╔══════════════════════════════════════════╗
-- ║          SERVICES & REFERENCES           ║
-- ╚══════════════════════════════════════════╝

local Workspace   = game:GetService("Workspace")
local RunService  = game:GetService("RunService")

-- Sanity check: pastikan ini berjalan di client
if not RunService:IsClient() then
	warn("[AsyncWorkspaceMonitor] Script ini HANYA untuk client (LocalScript).")
	return
end

-- ╔══════════════════════════════════════════╗
-- ║          TYPE DEFINITIONS                ║
-- ╚══════════════════════════════════════════╝

type MonitorConfig = {
	MinInterval:     number,   -- Jeda minimum per iterasi (detik)
	MaxInterval:     number,   -- Jeda maksimum per iterasi (detik)
	MaxRetryOnFail:  number,   -- Batas error berturut sebelum circuit break
	VerboseLogging:  boolean,  -- Toggle debug log
	TrackModels:     boolean,  -- Pantau Instance bertipe Model
	TrackParts:      boolean,  -- Pantau Instance bertipe BasePart
	TrackFolders:    boolean,  -- Pantau Instance bertipe Folder
}

type WorkspaceSnapshot = {
	Timestamp:      number,
	ChildCount:     number,
	ActiveChildren: { [string]: boolean },
	DeltaAdded:     { string },
	DeltaRemoved:   { string },
}

type MonitorState = "Idle" | "Running" | "Stopped" | "Error"

-- ╔══════════════════════════════════════════╗
-- ║          CONFIGURATION                   ║
-- ╚══════════════════════════════════════════╝

local CONFIG: MonitorConfig = {
	MinInterval     = 0.8,
	MaxInterval     = 2.5,
	MaxRetryOnFail  = 5,
	VerboseLogging  = true,
	TrackModels     = true,
	TrackParts      = true,
	TrackFolders    = true,
}

-- ╔══════════════════════════════════════════╗
-- ║          INTERNAL STATE                  ║
-- ╚══════════════════════════════════════════╝

local _state:             MonitorState            = "Idle"
local _lastSnapshot:      WorkspaceSnapshot?      = nil
local _consecutiveErrors: number                  = 0
local _iterationCount:    number                  = 0
local _listeners:         { (WorkspaceSnapshot) -> () } = {}
local _childAddedConn:    RBXScriptConnection?    = nil
local _childRemovedConn:  RBXScriptConnection?    = nil
local _pendingAdded:      { string }              = {}
local _pendingRemoved:    { string }              = {}
local _monitorThread:     thread?                 = nil

-- ╔══════════════════════════════════════════╗
-- ║          UTILITY FUNCTIONS               ║
-- ╚══════════════════════════════════════════╝

--- Logging internal dengan level & guard
local function Log(level: string, message: string)
	if not CONFIG.VerboseLogging and level ~= "ERROR" then
		return
	end
	local timestamp = string.format("[%.3f]", os.clock())
	local prefix = string.format("[WorkspaceMonitor]%s %s", timestamp, level)
	if level == "ERROR" then
		warn(prefix, message)
	else
		print(prefix, message)
	end
end

--- Generate jeda acak dalam rentang [MinInterval, MaxInterval]
--- Dikembalikan dalam satuan detik
local function GetRandomDelay(): number
	local minMs = math.floor(CONFIG.MinInterval * 1000)
	local maxMs = math.floor(CONFIG.MaxInterval * 1000)

	-- Guard terhadap edge case
	if maxMs < minMs then
		maxMs = minMs
	end

	local jitterMs = math.random(minMs, maxMs)
	return jitterMs / 1000
end

--- Cek apakah Instance relevan untuk dipantau berdasarkan config
local function IsTrackedInstance(instance: Instance): boolean
	if CONFIG.TrackParts and instance:IsA("BasePart") then
		return true
	end
	if CONFIG.TrackModels and instance:IsA("Model") then
		return true
	end
	if CONFIG.TrackFolders and instance:IsA("Folder") then
		return true
	end
	return false
end

-- ╔══════════════════════════════════════════╗
-- ║          SNAPSHOT CAPTURE                ║
-- ╚══════════════════════════════════════════╝

--- Ambil snapshot Workspace saat ini.
--- Dibungkus pcall agar error tidak merambat ke caller.
local function CaptureSnapshot(): (boolean, WorkspaceSnapshot?)
	local ok, result = pcall(function(): WorkspaceSnapshot
		local children = Workspace:GetChildren()
		local activeMap: { [string]: boolean } = {}
		local count = 0

		for _, child in children do
			if IsTrackedInstance(child) then
				-- Gunakan unique key untuk menghindari collision nama duplikat
				local key = child:GetFullName()
				activeMap[key] = true
				count += 1
			end
		end

		-- Hitung delta terhadap snapshot sebelumnya
		local added:   { string } = {}
		local removed: { string } = {}

		if _lastSnapshot then
			-- Objek baru: ada di snapshot sekarang, tidak ada di sebelumnya
			for key, _ in activeMap do
				if not _lastSnapshot.ActiveChildren[key] then
					table.insert(added, key)
				end
			end
			-- Objek hilang: ada di snapshot sebelumnya, tidak ada sekarang
			for key, _ in _lastSnapshot.ActiveChildren do
				if not activeMap[key] then
					table.insert(removed, key)
				end
			end
		end

		return {
			Timestamp      = os.clock(),
			ChildCount     = count,
			ActiveChildren = activeMap,
			DeltaAdded     = added,
			DeltaRemoved   = removed,
		}
	end)

	if ok then
		return true, result :: WorkspaceSnapshot
	else
		return false, nil
	end
end

-- ╔══════════════════════════════════════════╗
-- ║          LISTENER SYSTEM                 ║
-- ╚══════════════════════════════════════════╝

--- Notify semua registered listeners.
--- Setiap callback dibungkus pcall agar satu listener error
--- tidak menghentikan listener lainnya.
local function NotifyListeners(snapshot: WorkspaceSnapshot)
	if #_listeners == 0 then return end

	for i, callback in _listeners do
		local ok, err = pcall(callback, snapshot)
		if not ok then
			Log("ERROR", string.format(
				"Listener #%d threw an error: %s", i, tostring(err)
			))
		end
	end
end

--- Daftarkan listener. Mengembalikan fungsi unsubscribe.
local function OnSnapshot(callback: (WorkspaceSnapshot) -> ()): () -> ()
	table.insert(_listeners, callback)
	local index = #_listeners
	Log("INFO", "Listener #" .. index .. " registered")

	-- Return unsubscribe closure
	return function()
		for i, cb in _listeners do
			if cb == callback then
				table.remove(_listeners, i)
				Log("INFO", "Listener #" .. i .. " unregistered")
				break
			end
		end
	end
end

-- ╔══════════════════════════════════════════╗
-- ║          EVENT BRIDGE                    ║
-- ╚══════════════════════════════════════════╝
-- Menggunakan ChildAdded/ChildRemoving sebagai pelengkap
-- delta detection di luar polling loop.

local function SetupEventBridge()
	local ok1, err1 = pcall(function()
		_childAddedConn = Workspace.ChildAdded:Connect(function(child: Instance)
			if IsTrackedInstance(child) then
				table.insert(_pendingAdded, child:GetFullName())
			end
		end)
	end)

	local ok2, err2 = pcall(function()
		_childRemovedConn = Workspace.ChildRemoving:Connect(function(child: Instance)
			if IsTrackedInstance(child) then
				table.insert(_pendingRemoved, child:GetFullName())
			end
		end)
	end)

	if not ok1 then
		Log("ERROR", "ChildAdded bridge failed: " .. tostring(err1))
	end
	if not ok2 then
		Log("ERROR", "ChildRemoving bridge failed: " .. tostring(err2))
	end
end

local function TeardownEventBridge()
	if _childAddedConn then
		_childAddedConn:Disconnect()
		_childAddedConn = nil
	end
	if _childRemovedConn then
		_childRemovedConn:Disconnect()
		_childRemovedConn = nil
	end
	_pendingAdded   = {}
	_pendingRemoved = {}
end

-- ╔══════════════════════════════════════════╗
-- ║          CORE MONITOR LOOP               ║
-- ╚══════════════════════════════════════════╝
-- Loop utama yang berjalan di dalam task.spawn.
-- Setiap iterasi:
--   1. task.wait(GetRandomDelay())  → jitter acak
--   2. CaptureSnapshot()            → pcall-wrapped
--   3. Proses delta & notify
--   4. Circuit breaker check

local function MonitorLoop()
	Log("INFO", "═══ Monitor loop STARTED ═══")
	Log("INFO", string.format(
		"Config → Interval: [%.1fs ~ %.1fs] | MaxRetry: %d",
		CONFIG.MinInterval, CONFIG.MaxInterval, CONFIG.MaxRetryOnFail
	))

	while _state == "Running" do
		-- ── Jeda acak SEBELUM eksekusi (natural pacing) ──
		local delay = GetRandomDelay()
		_iterationCount += 1

		if CONFIG.VerboseLogging then
			Log("INFO", string.format(
				"Iteration #%d | Waiting %.3fs ...",
				_iterationCount, delay
			))
		end

		task.wait(delay)

		-- Guard: pastikan state masih Running setelah wait
		-- (bisa berubah jika Stop() dipanggil saat menunggu)
		if _state ~= "Running" then
			Log("INFO", "State changed during wait, exiting loop")
			break
		end

		-- ── Capture snapshot ──
		local success, snapshot = CaptureSnapshot()

		if success and snapshot then
			-- Reset error counter pada keberhasilan
			_consecutiveErrors = 0

			local hasChange = (#snapshot.DeltaAdded > 0) or (#snapshot.DeltaRemoved > 0)

			if hasChange then
				Log("INFO", string.format(
					"Δ CHANGE DETECTED | +%d added | -%d removed | Total tracked: %d",
					#snapshot.DeltaAdded,
					#snapshot.DeltaRemoved,
					snapshot.ChildCount
				))

				-- Log detail objek yang berubah
				for _, name in snapshot.DeltaAdded do
					Log("INFO", "  [+] " .. name)
				end
				for _, name in snapshot.DeltaRemoved do
					Log("INFO", "  [-] " .. name)
				end
			else
				if CONFIG.VerboseLogging then
					Log("INFO", string.format(
						"No change | Tracked objects: %d",
						snapshot.ChildCount
					))
				end
			end

			-- Simpan & notify
			_lastSnapshot = snapshot
			NotifyListeners(snapshot)

		else
			-- ── Error path ──
			_consecutiveErrors += 1
			Log("ERROR", string.format(
				"Snapshot capture FAILED (%d/%d)",
				_consecutiveErrors, CONFIG.MaxRetryOnFail
			))

			-- Circuit breaker: hentikan jika error berlebihan
			if _consecutiveErrors >= CONFIG.MaxRetryOnFail then
				_state = "Error"
				Log("ERROR", "═══ CIRCUIT BREAKER TRIPPED — Monitor HALTED ═══")
				break
			end
		end
	end

	Log("INFO", "═══ Monitor loop EXITED | State: " .. _state .. " ═══")
end

-- ╔══════════════════════════════════════════╗
-- ║          PUBLIC API FUNCTIONS            ║
-- ╚══════════════════════════════════════════╝

--- Mulai monitoring secara asinkron (non-blocking).
--- Menggunakan task.spawn agar TIDAK memblokir thread utama.
local function StartMonitor(): boolean
	if _state == "Running" then
		Log("INFO", "Monitor already running — Start() ignored")
		return false
	end

	_state             = "Running"
	_consecutiveErrors = 0
	_iterationCount    = 0
	_lastSnapshot      = nil

	-- Setup event bridge untuk real-time delta hints
	SetupEventBridge()

	-- Spawn core loop di thread terpisah
	local spawnOk, spawnErr = pcall(function()
		_monitorThread = task.spawn(function()
			-- Wrap seluruh loop dalam pcall sebagai safety net terakhir
			local loopOk, loopErr = pcall(MonitorLoop)
			if not loopOk then
				_state = "Error"
				Log("ERROR", "Unhandled exception in monitor loop: " .. tostring(loopErr))
			end
		end)
	end)

	if spawnOk then
		Log("INFO", "Async monitor thread spawned successfully")
		return true
	else
		_state = "Error"
		Log("ERROR", "Failed to spawn monitor thread: " .. tostring(spawnErr))
		return false
	end
end

--- Hentikan monitoring secara graceful.
--- Thread akan exit natural di task.wait() berikutnya.
local function StopMonitor()
	if _state ~= "Running" then
		Log("INFO", "Monitor not running — Stop() ignored")
		return
	end

	_state = "Stopped"
	TeardownEventBridge()
	Log("INFO", "Stop signal sent — thread will exit after current wait")
end

--- Full cleanup: hentikan, putus connection, bersihkan memori.
local function DestroyMonitor()
	StopMonitor()
	_listeners    = {}
	_lastSnapshot = nil
	_monitorThread = nil
	Log("INFO", "Monitor destroyed — all references cleared")
end

--- Ambil snapshot terakhir tanpa menunggu iterasi berikutnya.
local function GetLastSnapshot(): WorkspaceSnapshot?
	return _lastSnapshot
end

--- Dapatkan state monitor saat ini.
local function GetMonitorState(): MonitorState
	return _state
end

-- ╔══════════════════════════════════════════╗
-- ║          EXECUTION — CLIENT SIDE         ║
-- ╚══════════════════════════════════════════╝
-- Semua logika dieksekusi langsung di sini.
-- Tidak ada Server Script, tidak ada RemoteEvent,
-- tidak ada require() ke modul eksternal.

Log("INFO", "══════════════════════════════════════════")
Log("INFO", " AsyncWorkspaceMonitor — Initializing")
Log("INFO", " Execution context: CLIENT")
Log("INFO", "══════════════════════════════════════════")

-- Validasi config sebelum mulai
local configOk, configErr = pcall(function()
	assert(CONFIG.MinInterval > 0, "MinInterval harus > 0")
	assert(CONFIG.MaxInterval >= CONFIG.MinInterval, "MaxInterval harus >= MinInterval")
	assert(CONFIG.MaxRetryOnFail > 0, "MaxRetryOnFail harus > 0")
end)

if not configOk then
	Log("ERROR", "Config validation failed: " .. tostring(configErr))
	return
end

-- ── Daftarkan listener contoh (demo) ──
local unsubscribeDemo = OnSnapshot(function(snapshot: WorkspaceSnapshot)
	-- Listener ini berjalan setiap snapshot berhasil diambil.
	-- Bisa diganti dengan logic game-specific.

	if #snapshot.DeltaAdded > 0 then
		-- Contoh: print objek baru yang muncul di Workspace
		for _, name in snapshot.DeltaAdded do
			print("[Demo Listener] Objek baru terdeteksi:", name)
		end
	end

	if #snapshot.DeltaRemoved > 0 then
		for _, name in snapshot.DeltaRemoved do
			print("[Demo Listener] Objek dihapus:", name)
		end
	end
end)

-- ── Mulai monitoring ──
local started = StartMonitor()

if started then
	Log("INFO", "Monitor aktif. Tekan tombol 'M' untuk toggle stop/start (demo).")

	-- ── Demo: Keyboard toggle (opsional, hapus jika tidak perlu) ──
	local UserInputService = game:GetService("UserInputService")

	local inputOk, inputErr = pcall(function()
		UserInputService.InputBegan:Connect(function(input, gameProcessed)
			if gameProcessed then return end

			if input.KeyCode == Enum.KeyCode.M then
				if GetMonitorState() == "Running" then
					Log("INFO", "[KEY M] Stopping monitor...")
					StopMonitor()
				else
					Log("INFO", "[KEY M] Restarting monitor...")
					StartMonitor()
				end
			end
		end)
	end)

	if not inputOk then
		Log("ERROR", "Keyboard listener setup failed: " .. tostring(inputErr))
	end

else
	Log("ERROR", "Monitor failed to start. Check Output for details.")
end

-- ╔══════════════════════════════════════════╗
-- ║          CLEANUP ON PLAYER LEAVING       ║
-- ╚══════════════════════════════════════════╝

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

if LocalPlayer then
	local cleanupOk, cleanupErr = pcall(function()
		Players.PlayerRemoving:Connect(function(player)
			if player == LocalPlayer then
				DestroyMonitor()
			end
		end)
	end)

	if not cleanupOk then
		Log("ERROR", "Cleanup handler failed: " .. tostring(cleanupErr))
	end

	-- Fallback cleanup saat LocalScript di-destroy
	script.Destroying:Connect(function()
		DestroyMonitor()
	end)
end

Log("INFO", "══════════════════════════════════════════")
Log("INFO", " AsyncWorkspaceMonitor — READY")
Log("INFO", "══════════════════════════════════════════")
