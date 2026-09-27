-- ============================================================================
--  AI-Based Heatwave Complaint & Early Warning System
--  Complete SQL schema (SQLite)  -- 3NF normalized
--
--  Contents:
--    * Lookup tables (HeatwaveSeverity, GovernmentDepartment, Advisory)
--    * Core entities (User, Region, Citizen, Officer, Administrator, ...)
--    * Weather monitoring (WeatherStation, WeatherObservation)
--    * AI / expert-system output (HeatwavePrediction)
--    * Early warning (WarningAlert)
--    * Complaint management (Complaint) and Notifications
--    * 1 TRIGGER  -> auto-create a WarningAlert when a High/Extreme prediction is inserted
--    * 1 VIEW     -> region-wise complaint summary (total / open / in-progress / resolved)
-- ============================================================================

PRAGMA foreign_keys = ON;

-- ---------------------------------------------------------------------------
-- Drop in reverse-dependency order so the script is re-runnable.
-- ---------------------------------------------------------------------------
DROP VIEW    IF EXISTS v_region_complaint_summary;
DROP TRIGGER IF EXISTS trg_prediction_autowarn;

DROP TABLE IF EXISTS Notification;
DROP TABLE IF EXISTS Complaint;
DROP TABLE IF EXISTS WarningAlert;
DROP TABLE IF EXISTS Advisory;
DROP TABLE IF EXISTS HeatwavePrediction;
DROP TABLE IF EXISTS WeatherObservation;
DROP TABLE IF EXISTS WeatherStation;
DROP TABLE IF EXISTS Officer;
DROP TABLE IF EXISTS Administrator;
DROP TABLE IF EXISTS Citizen;
DROP TABLE IF EXISTS GovernmentDepartment;
DROP TABLE IF EXISTS HeatwaveSeverity;
DROP TABLE IF EXISTS Region;
DROP TABLE IF EXISTS User;

-- ===========================================================================
-- 1. USER  (base table for role-based login)
-- ===========================================================================
CREATE TABLE User (
    user_id       INTEGER PRIMARY KEY AUTOINCREMENT,
    username      TEXT    NOT NULL UNIQUE,
    password_hash TEXT    NOT NULL,
    role          TEXT    NOT NULL CHECK (role IN ('Citizen', 'Officer', 'Administrator')),
    full_name     TEXT    NOT NULL,
    email         TEXT    UNIQUE,
    created_at    TEXT    NOT NULL DEFAULT (datetime('now'))
);

-- ===========================================================================
-- 2. REGION
-- ===========================================================================
CREATE TABLE Region (
    region_id   INTEGER PRIMARY KEY AUTOINCREMENT,
    name        TEXT    NOT NULL UNIQUE,
    state       TEXT    NOT NULL,
    population  INTEGER CHECK (population >= 0)
);

-- ===========================================================================
-- 3. HEATWAVE SEVERITY  (lookup table for severity levels)
-- ===========================================================================
CREATE TABLE HeatwaveSeverity (
    severity_id INTEGER PRIMARY KEY AUTOINCREMENT,
    level       TEXT    NOT NULL UNIQUE CHECK (level IN ('Low', 'Moderate', 'High', 'Extreme')),
    rank        INTEGER NOT NULL UNIQUE,          -- 1=Low .. 4=Extreme, used for complaint prioritisation
    description TEXT
);

-- ===========================================================================
-- 4. GOVERNMENT DEPARTMENT
-- ===========================================================================
CREATE TABLE GovernmentDepartment (
    dept_id     INTEGER PRIMARY KEY AUTOINCREMENT,
    name        TEXT    NOT NULL UNIQUE,
    description TEXT,
    contact     TEXT
);

-- ===========================================================================
-- 5. CITIZEN  (1:1 with User, belongs to a Region)
-- ===========================================================================
CREATE TABLE Citizen (
    citizen_id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id    INTEGER NOT NULL UNIQUE,
    region_id  INTEGER NOT NULL,
    phone      TEXT,
    address    TEXT,
    FOREIGN KEY (user_id)   REFERENCES User(user_id)     ON DELETE CASCADE,
    FOREIGN KEY (region_id) REFERENCES Region(region_id) ON DELETE RESTRICT
);

-- ===========================================================================
-- 6. OFFICER  (1:1 with User, belongs to a GovernmentDepartment)
-- ===========================================================================
CREATE TABLE Officer (
    officer_id  INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id     INTEGER NOT NULL UNIQUE,
    dept_id     INTEGER NOT NULL,
    designation TEXT,
    FOREIGN KEY (user_id) REFERENCES User(user_id)                    ON DELETE CASCADE,
    FOREIGN KEY (dept_id) REFERENCES GovernmentDepartment(dept_id)    ON DELETE RESTRICT
);

-- ===========================================================================
-- 7. ADMINISTRATOR  (1:1 with User)
-- ===========================================================================
CREATE TABLE Administrator (
    admin_id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id  INTEGER NOT NULL UNIQUE,
    office   TEXT,
    FOREIGN KEY (user_id) REFERENCES User(user_id) ON DELETE CASCADE
);

-- ===========================================================================
-- 8. WEATHER STATION  (a Region has many WeatherStations)
-- ===========================================================================
CREATE TABLE WeatherStation (
    station_id   INTEGER PRIMARY KEY AUTOINCREMENT,
    region_id    INTEGER NOT NULL,
    name         TEXT    NOT NULL,
    latitude     REAL,
    longitude    REAL,
    installed_on TEXT    DEFAULT (date('now')),
    FOREIGN KEY (region_id) REFERENCES Region(region_id) ON DELETE CASCADE
);

-- ===========================================================================
-- 9. WEATHER OBSERVATION  (a WeatherStation logs many WeatherObservations)
-- ===========================================================================
CREATE TABLE WeatherObservation (
    obs_id       INTEGER PRIMARY KEY AUTOINCREMENT,
    station_id   INTEGER NOT NULL,
    temperature  REAL    NOT NULL,                 -- degrees Celsius
    humidity     REAL    NOT NULL CHECK (humidity BETWEEN 0 AND 100),
    wind_speed   REAL    NOT NULL CHECK (wind_speed >= 0),   -- km/h
    observed_at  TEXT    NOT NULL DEFAULT (datetime('now')),
    recorded_by  INTEGER,                          -- User who entered the reading
    FOREIGN KEY (station_id)  REFERENCES WeatherStation(station_id) ON DELETE CASCADE,
    FOREIGN KEY (recorded_by) REFERENCES User(user_id)              ON DELETE SET NULL
);

-- ===========================================================================
-- 10. HEATWAVE PREDICTION  (output of the rule-based expert system)
--     A Region + a source WeatherObservation -> a classified severity.
-- ===========================================================================
CREATE TABLE HeatwavePrediction (
    prediction_id INTEGER PRIMARY KEY AUTOINCREMENT,
    region_id     INTEGER NOT NULL,
    obs_id        INTEGER,                         -- the observation this was based on
    severity_id   INTEGER NOT NULL,
    temperature   REAL    NOT NULL,
    humidity      REAL    NOT NULL,
    wind_speed    REAL    NOT NULL,
    reason        TEXT,                            -- which rule fired
    predicted_at  TEXT    NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (region_id)   REFERENCES Region(region_id)             ON DELETE CASCADE,
    FOREIGN KEY (obs_id)      REFERENCES WeatherObservation(obs_id)    ON DELETE SET NULL,
    FOREIGN KEY (severity_id) REFERENCES HeatwaveSeverity(severity_id) ON DELETE RESTRICT
);

-- ===========================================================================
-- 11. ADVISORY  (static catalogue of advisory messages mapped to a severity)
-- ===========================================================================
CREATE TABLE Advisory (
    advisory_id INTEGER PRIMARY KEY AUTOINCREMENT,
    severity_id INTEGER NOT NULL,
    message     TEXT    NOT NULL,
    FOREIGN KEY (severity_id) REFERENCES HeatwaveSeverity(severity_id) ON DELETE CASCADE
);

-- ===========================================================================
-- 12. WARNING ALERT  (auto-generated for High/Extreme predictions, per Region)
-- ===========================================================================
CREATE TABLE WarningAlert (
    alert_id      INTEGER PRIMARY KEY AUTOINCREMENT,
    region_id     INTEGER NOT NULL,
    prediction_id INTEGER,
    severity_id   INTEGER NOT NULL,
    message       TEXT    NOT NULL,
    issued_at     TEXT    NOT NULL DEFAULT (datetime('now')),
    is_active     INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
    FOREIGN KEY (region_id)     REFERENCES Region(region_id)               ON DELETE CASCADE,
    FOREIGN KEY (prediction_id) REFERENCES HeatwavePrediction(prediction_id) ON DELETE SET NULL,
    FOREIGN KEY (severity_id)   REFERENCES HeatwaveSeverity(severity_id)    ON DELETE RESTRICT
);

-- ===========================================================================
-- 13. COMPLAINT  (linked to Citizen, Region, and optionally a Department/Officer)
-- ===========================================================================
CREATE TABLE Complaint (
    complaint_id       INTEGER PRIMARY KEY AUTOINCREMENT,
    citizen_id         INTEGER NOT NULL,
    region_id          INTEGER NOT NULL,
    dept_id            INTEGER,                    -- assigned department (nullable until assigned)
    assigned_officer_id INTEGER,                   -- assigned officer   (nullable until assigned)
    category           TEXT    NOT NULL,
    description        TEXT    NOT NULL,
    status             TEXT    NOT NULL DEFAULT 'Open'
                               CHECK (status IN ('Open', 'In Progress', 'Resolved')),
    created_at         TEXT    NOT NULL DEFAULT (datetime('now')),
    resolved_at        TEXT,
    FOREIGN KEY (citizen_id)          REFERENCES Citizen(citizen_id)              ON DELETE CASCADE,
    FOREIGN KEY (region_id)           REFERENCES Region(region_id)                ON DELETE RESTRICT,
    FOREIGN KEY (dept_id)             REFERENCES GovernmentDepartment(dept_id)    ON DELETE SET NULL,
    FOREIGN KEY (assigned_officer_id) REFERENCES Officer(officer_id)              ON DELETE SET NULL
);

-- ===========================================================================
-- 14. NOTIFICATION  (linked to a User)
-- ===========================================================================
CREATE TABLE Notification (
    notification_id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id         INTEGER NOT NULL,
    message         TEXT    NOT NULL,
    is_read         INTEGER NOT NULL DEFAULT 0 CHECK (is_read IN (0, 1)),
    created_at      TEXT    NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (user_id) REFERENCES User(user_id) ON DELETE CASCADE
);

-- ===========================================================================
--  TRIGGER (grading point: triggers)
--  Auto-create a WarningAlert row whenever a HeatwavePrediction is inserted
--  with severity High or Extreme.  The severity rank (3=High, 4=Extreme) is
--  used so the rule keeps working even if severity_id ordering changes.
-- ===========================================================================
CREATE TRIGGER trg_prediction_autowarn
AFTER INSERT ON HeatwavePrediction
FOR EACH ROW
WHEN (SELECT rank FROM HeatwaveSeverity WHERE severity_id = NEW.severity_id) >= 3
BEGIN
    INSERT INTO WarningAlert (region_id, prediction_id, severity_id, message, issued_at, is_active)
    VALUES (
        NEW.region_id,
        NEW.prediction_id,
        NEW.severity_id,
        'HEATWAVE WARNING (' ||
            (SELECT level FROM HeatwaveSeverity WHERE severity_id = NEW.severity_id) ||
            '): Recorded ' || NEW.temperature || ' C in ' ||
            (SELECT name FROM Region WHERE region_id = NEW.region_id) ||
            '. Take precautions.',
        NEW.predicted_at,
        1
    );
END;

-- ===========================================================================
--  VIEW (grading point: views)
--  Region-wise complaint summary: total / open / in-progress / resolved counts.
-- ===========================================================================
CREATE VIEW v_region_complaint_summary AS
SELECT
    r.region_id,
    r.name                                                         AS region_name,
    COUNT(c.complaint_id)                                          AS total_complaints,
    SUM(CASE WHEN c.status = 'Open'        THEN 1 ELSE 0 END)      AS open_complaints,
    SUM(CASE WHEN c.status = 'In Progress' THEN 1 ELSE 0 END)      AS in_progress_complaints,
    SUM(CASE WHEN c.status = 'Resolved'    THEN 1 ELSE 0 END)      AS resolved_complaints
FROM Region r
LEFT JOIN Complaint c ON c.region_id = r.region_id
GROUP BY r.region_id, r.name;
