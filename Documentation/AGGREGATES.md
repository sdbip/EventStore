# An In-Depth Discussion on Aggregates

Aggregate (as a noun) is a redundant term.

In his “Big Blue Book,” Eric Evans defines the term “aggregate.” This refers to a collection of entities that can only exist meaningfully as a group. This group always has an “aggregate root” which is one of the contained entities. It is meaningful to say that an entity *has the property* of being the root entity of an aggregate, but there is no point in modelling an `Aggregate` as a concept in your code,

The term aggregate is replaced with `Entity` in this library; mostly because every aggregate *is* indeed an entity: the aggregate root is the container of all its children. There is no need to add a second word for the same concept. Even if it is to illustrate an interesting and useful rule. The aggregate *rule* still applies though. Entities that belong to an aggregate relationship should only ever be accessed through the root entity. It should not be possible to refer to a child entity without its parent nearby.

Some YouTube videos teach that you should add an `abstract class AggregateRoot : Entity` and inherit from that rather than the `Entity` class directly to signal that this is indeed the root of an aggregate structure. This class, however, typically adds no properties, no methods, nothing at all. It does not add any new functionality. It doesn't help enforcing the aggregate rule. All it does is *document* that the entity is the root of an aggregate.

The aggregate rule is a rule of discipline, not one that can be prevented by clever design; it cannot be enforced in code. If the discipline is lacking, or if the developer is not aware of the rule, the architecture cannot help them do the right thing. Architecture and design should be created first and foremost to help the developer avoid mistakes. Architecting only for documentation is next to meaningless.

Other libraries often treat the `Aggregate` much like a list of commands rather than a modelling object. Commands often perform multiple operations on the same entity in one batch. It does not meaningfully allow for manipulating multiple (root) entities. This style of implementation (or the interpretation perhaps) does not make composition or operations very easy at all.

Better then if a (web API) command could focus on the HTTP request/response and think of entities in more abstract terms.
