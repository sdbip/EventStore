<!--
    This comment only exists to disable the Markdownlint rule
    MD025/single-title/single-h1: Multiple top-level headings in the same document
    This behaviour was observed when using https://marketplace.visualstudio.com/items?itemName=DavidAnson.vscode-markdownlint
-->

# EventStore

A package for employing event-sourcing in applications. It is particularly useful when using the CQRS architecture style. The Command side would reference the `Source` target, and the Query side would use the `Projection` target.

State is stored in a relational database with built-in support for SQLite and PostgreSQL. See the [Tables](#tables) section for schema details.

This document is meant to help developers contribute to the source code and test their changes. There is separate documentation describing [the concept of event-sourcing](./Documentation/ES.md) and [usage in applications](./Documentation/USAGE.md).

# Build and Test

Start by executing the `./build` command. It will add a pre-commit hook to Git that builds and runs tests; it will cancel the commit if the tests fail.

You can add the `-n` (`--no-verify`) flag to `git commit` to bypass hooks, but that is not recommended.

## PostgreSQL

The tests will fail without write-access to a running PostgreSQL test-database. Ensure that the PostgreSQL server is started and that a test database has been created before running tests.

You can download [Postgres.app](https://postgresapp.com) which is probably the easiest to run PostgreSQL on a Mac. It is also available as a [Docker image](https://hub.docker.com/_/postgres/) and by [direct installation](https://www.postgresql.org/download/).

The `./build` command adds the (Git untracked) file developer.env to buildscripts/. You will need to edit the values of the `POSTGRES_TEST_*` variables to match your PostgreSQL setup. Note: `POSTGRES_TEST_HOST` and `POSTGRES_TEST_PASS` are commented out. The defaults are `localhost` and an empty password respectively.

# Technical Notes

The point of DDD is to *not* focus on the technology or other implementation details. However, the technical choices do need to be mentioned, because developers believe they need to know them. If they actually do or not is beside the point.

## Optimistic Locking

Concurrent modification of shared state can be a big problem. If two users happen to change the same entity at the same time, there's a risk that they both read the same initial state, and then make conflicting changes that cannot be reconciled. This library employs “optimistic locking” to avoid such a scenario. Every entity has a `version` that is read when it is reconstituted, and again before publishing changes. Only if the version is the same at both instants is publishing allowed.

If the stored state is the same, it is assumed that no other process has changed the state in the intervening time. If no one has yet published new changes, there is no possibility of a conflict, and publishing the current changes will be allowed. At that time, the version is also incremented to indicate to any other active process that the state has now changed.

If the stored version number is different from what was read at reconstitution, the state has changed during the execution of this action. Since a different state can potentially affect the outcome of this action, all the current changes are to be considered invalid and publishing them is not allowed. Our only choices are to either abort the operation entirely or perform the action again. If we choose to repeat the action, we must discard the current, invalid state information, and reconstitute the entity from its new state. Then we can perform the action on this state, and try to publish those changes.

## Type Checking

Every entity in the system has a `Type` property. The `Type` property indicates what specific `EntityType` the entity has. The `EntityType` name should uniquely identify the class that implements this particular type of entity. (This is however not enforced.) When the first version (0) of an entity is added to the system, a row is added to the `Entities` table (see [the Tables Section](#tables) below). That row will include the name of the `EntityType` in the `type` column. When the entity is reconstituted by the `EventStore` that stored `type` is checked against the expected `EntityType`. If the values do not match, the `EntityStore` will return `null`.

Do not use `nameof(MyEntity)`, `entity.GetType().Name` or any other reference to the actual class name. The name of the `EntityType` must never change, even if the relevant class is renamed. The name needs to always match the `type` column for already added entities. If the `EntityType` is changed, those entities can never be reconstituted (or worse: they may be reconstituted as instances of the wrong class).

## Tables

State is stored in a relational database with built-in support for SQLite and PostgreSQL. Note that table names are never quoted in the SQL scripts, and, because reasons, PostgreSQL converts unquoted names to lowercase. That is however the only difference you will see.

The table layout is the exact same as used by the C# NuGet package Segerfeldt.EventSourcing. A write model generated by a C# web application should be 100% compatible with the Swift Projection target defined here. And vice versa too.

The `Entities` table:

```sql
"id" TEXT PRIMARY KEY
"type" TEXT
"version" INT
```

The `Entities` table has two data columns: the `type` and the `version` of an entity. The version is used for concurrency checks (see [Optimistic Locking](#optimistic-locking) above). The type is used as a runtime type-checker. When reconstituting the state of an entity it needs to be the type you expect. If it isn't, an error will be thrown.

The `Events` table:

```sql
"entity_id" TEXT
"name" TEXT
"details" TEXT
"actor" TEXT
"timestamp" DECIMAL(12,7)
"ordinal" INT
"position" BIGINT
```

The events table is the main storage space for entity state. The `entity_id` column must match the `id` column for a row in the `Entities` table. This is the entity that changed with this event.

The `name` and `details` (JSON) columns define what changed for the entity. The `ordinal` column orders events per entity. The `position` column orders events globally and is mostly used for projections.

The `actor` and `timestamp` columns are metadata that can be used for auditing.

The `timestamp` is stored as the number of days (including fraction) that have passed since midnight UTC on Jan 1, 1970 (a.k.a. the Unix Epoch).

## Database Support

EventStore comes with support for two database providers.

- PostgreSQL
- SQLite

### What about SQL Server?

As of 2022, there is no known SQL Server driver available for Swift. Here's a discussion that indicates some small progress: <https://forums.swift.org/t/sql-server-driver/20327>. It is unknown what has happened since April 2020.

Apparently SQL Server is not prioritised by the Swift community.

### Maybe add suppoet for MySQL?

MySQL support does not feel as important as SQL Server. On the other hand, MySQL has Swift drivers. Here are a couple:

- <https://github.com/mcorega/MySqlSwiftNative>
- <https://github.com/novi/mysql-swift>
