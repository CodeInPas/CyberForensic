CREATE TABLE IF NOT EXISTS GameSessions (
    SessionID INTEGER PRIMARY KEY AUTOINCREMENT,
    DifficultyLevel INTEGER NOT NULL,
    Status TEXT NOT NULL,
    FinalExfiltration REAL,
    StartTime DATETIME DEFAULT CURRENT_TIMESTAMP,
    EndTime DATETIME
);

CREATE TABLE IF NOT EXISTS SimLogs (
    LogID INTEGER PRIMARY KEY AUTOINCREMENT,
    SessionID INTEGER,
    Time TEXT NOT NULL,
    EventType TEXT NOT NULL,
    Description TEXT NOT NULL,
    FOREIGN KEY(SessionID) REFERENCES GameSessions(SessionID)
);

CREATE TABLE IF NOT EXISTS FoundIoCs (
    IoCID INTEGER PRIMARY KEY AUTOINCREMENT,
    SessionID INTEGER,
    IndicatorType TEXT NOT NULL,
    IndicatorValue TEXT NOT NULL,
    MemoryOffset TEXT,
    ThreatLevel TEXT,
    Timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(SessionID) REFERENCES GameSessions(SessionID)
);

CREATE TABLE IF NOT EXISTS ThreatDictionary (
    RuleID INTEGER PRIMARY KEY AUTOINCREMENT,
    RuleType TEXT NOT NULL, 
    Pattern TEXT NOT NULL,
    Description TEXT,
    RiskLevel TEXT
);

CREATE INDEX idx_simlogs_session ON SimLogs(SessionID);
CREATE INDEX idx_foundiocs_session ON FoundIoCs(SessionID);

INSERT INTO GameSessions (DifficultyLevel, Status, FinalExfiltration, StartTime, EndTime) VALUES
(1, 'gsCaseSolved', 42.5, datetime('now', '-2 days'), datetime('now', '-2 days', '+15 minutes')),
(2, 'gsGameOver', 100.0, datetime('now', '-1 days'), datetime('now', '-1 days', '+8 minutes')),
(1, 'gsActive', 12.0, datetime('now'), NULL);

INSERT INTO SimLogs (SessionID, Time, EventType, Description) VALUES
(1, datetime('now', '-2 days', '+1 minutes'), 'START', 'Case Initialized'),
(1, datetime('now', '-2 days', '+4 minutes'), 'SCAN', 'Hex scan initiated on memory dump'),
(1, datetime('now', '-2 days', '+5 minutes'), 'IOC_FOUND', '192.168.10.55'),
(2, datetime('now', '-1 days', '+1 minutes'), 'START', 'Case Initialized'),
(2, datetime('now', '-1 days', '+6 minutes'), 'WARNING', 'Data exfiltration threshold critical'),
(3, datetime('now'), 'START', 'Case Initialized');

INSERT INTO FoundIoCs (SessionID, IndicatorType, IndicatorValue, MemoryOffset, ThreatLevel, Timestamp) VALUES
(1, 'IPv4_C2', '192.168.10.55', '0x0001A4F0', 'tlCritical', datetime('now', '-2 days', '+5 minutes')),
(1, 'Suspicious_String', 'ReflectiveLoader', '0x0045B200', 'tlMalicious', datetime('now', '-2 days', '+9 minutes')),
(1, 'IPv4_C2', '45.33.32.156', '0x0088C110', 'tlCritical', datetime('now', '-2 days', '+14 minutes'));

INSERT INTO ThreatDictionary (RuleType, Pattern, Description, RiskLevel) VALUES
('REGEX', '\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b', 'IPv4 Address Pattern (Potential C2/Exfiltration)', 'High'),
('REGEX', '(?i)(http|https)://[a-zA-Z0-9\-\.]+\.[a-zA-Z]{2,3}(/\S*)?', 'Malicious URL / Payload Staging', 'High'),
('REGEX', '(?i)(cmd\.exe /c |powershell\.exe -enc )', 'Suspicious Command Line Execution', 'Critical'),
('YARA', '{ 4D 5A 90 00 }', 'MZ Header (Windows Executable)', 'Medium'),
('YARA', '{ EB ?? E8 ?? ?? ?? ?? 5E }', 'Common Shellcode (GetPC) Pattern', 'Critical'),
('YARA', '{ 55 8B EC 83 EC ?? 53 56 57 }', 'Standard Function Prologue (Code Injection)', 'High'),
('YARA', '{ 6A 40 68 00 30 00 00 6A 14 6A 00 }', 'VirtualAlloc Hook/Injection Signature', 'Critical');