import Foundation

struct SlateMergeResult: Equatable {
    let archive: TodoArchive
    let conflictingIDs: Set<UUID>
}

enum SlateMergeEngine {
    static func merge(
        base: TodoArchive?,
        local: TodoArchive,
        remote: TodoArchive,
        preferLocalOnConflict: Bool
    ) -> SlateMergeResult {
        var conflicts = Set<UUID>()
        var groups = mergeEntities(
            base: base?.groups ?? [],
            local: local.groups,
            remote: remote.groups,
            id: \.id,
            preferLocal: preferLocalOnConflict,
            conflicts: &conflicts
        )
        if groups.isEmpty {
            groups = [TodoGroup.defaultGroup()]
        }
        groups.sort { $0.sortOrder < $1.sortOrder }

        let validGroupIDs = Set(groups.map(\.id))
        let fallbackGroupID = groups[0].id
        var items = mergeEntities(
            base: base?.items ?? [],
            local: local.items,
            remote: remote.items,
            id: \.id,
            preferLocal: preferLocalOnConflict,
            conflicts: &conflicts
        )
        items = items.compactMap { item in
            guard !item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }
            var repaired = item
            if repaired.groupID == nil || !validGroupIDs.contains(repaired.groupID!) {
                repaired.groupID = fallbackGroupID
            }
            return repaired
        }
        items.sort {
            let lhs = $0.sortOrder ?? $0.createdAt.timeIntervalSinceReferenceDate
            let rhs = $1.sortOrder ?? $1.createdAt.timeIntervalSinceReferenceDate
            return lhs < rhs
        }

        return SlateMergeResult(
            archive: TodoArchive(items: items, groups: groups).normalized(),
            conflictingIDs: conflicts
        )
    }

    private static func mergeEntities<Entity: Equatable>(
        base: [Entity],
        local: [Entity],
        remote: [Entity],
        id: KeyPath<Entity, UUID>,
        preferLocal: Bool,
        conflicts: inout Set<UUID>
    ) -> [Entity] {
        // Sync payloads are user data, so duplicate identifiers must never be
        // allowed to reach Dictionary(uniqueKeysWithValues:), which traps the
        // entire process. Keep the last serialized value for an identifier:
        // older clients append their newest edit last when producing a payload.
        let baseByID = indexByID(base, id: id)
        let localByID = indexByID(local, id: id)
        let remoteByID = indexByID(remote, id: id)
        var orderedIDs = [UUID]()
        var seen = Set<UUID>()
        for entity in local + remote + base {
            let entityID = entity[keyPath: id]
            if seen.insert(entityID).inserted {
                orderedIDs.append(entityID)
            }
        }

        return orderedIDs.compactMap { entityID in
            let baseline = baseByID[entityID]
            let localValue = localByID[entityID]
            let remoteValue = remoteByID[entityID]
            if localValue == remoteValue {
                return localValue
            }
            if localValue == baseline {
                return remoteValue
            }
            if remoteValue == baseline {
                return localValue
            }
            conflicts.insert(entityID)
            return preferLocal ? localValue : remoteValue
        }
    }

    private static func indexByID<Entity>(
        _ entities: [Entity],
        id: KeyPath<Entity, UUID>
    ) -> [UUID: Entity] {
        entities.reduce(into: [:]) { result, entity in
            result[entity[keyPath: id]] = entity
        }
    }
}
