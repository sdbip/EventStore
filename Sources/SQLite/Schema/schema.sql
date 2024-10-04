CREATE TABLE IF NOT EXISTS Entities (
    id TEXT NOT NULL PRIMARY KEY,
    type TEXT NOT NULL,
    version INT NOT NULL
);

CREATE TABLE IF NOT EXISTS Events (
    entity_id TEXT NOT NULL,
    name TEXT NOT NULL,
    details TEXT NOT NULL,
    actor TEXT NOT NULL,
    timestamp DECIMAL(12,7) NOT NULL DEFAULT (strftime('%s', CURRENT_TIMESTAMP) / 86400.0),
    version INT NOT NULL,
    position BIGINT NOT NULL
);
