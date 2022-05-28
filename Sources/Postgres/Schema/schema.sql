CREATE TABLE IF NOT EXISTS "Entities" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "type" TEXT NOT NULL,
    "version" INT NOT NULL
);

CREATE TABLE IF NOT EXISTS "Events" (
    "entityId" TEXT NOT NULL,
    "entityType" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "details" TEXT NOT NULL,
    "actor" TEXT NOT NULL,
    "timestamp" DECIMAL(14,7) NOT NULL DEFAULT (extract(julian from current_timestamp at time zone 'UTC')),
    "version" INT NOT NULL,
    "position" BIGINT NOT NULL
);

CREATE TABLE IF NOT EXISTS "Properties" (
    "name" TEXT NOT NULL,
    "value" TEXT NOT NULL
);

INSERT INTO "Properties" ("name", "value") SELECT 'next_position', 0
    WHERE NOT EXISTS (SELECT 1 FROM "Properties" WHERE "name" = 'next_position');
