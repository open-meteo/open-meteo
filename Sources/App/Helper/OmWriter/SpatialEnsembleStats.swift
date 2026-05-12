import Foundation
import Logging

struct SpatialEnsembleStats {
    static func calculate(
        logger: Logger,
        run: Timestamp,
        ensembleMeanDomain: GenericDomain,
        handles: [GenericVariableHandle]
    ) async throws -> [GenericVariableHandle] {
        let calculator = EnsembleMeanCalculatorMultistep()

        for (_, variableHandles) in handles.groupedPreservedOrder(by: { "\($0.variable.omFileName.file)" }) {
            for handle in variableHandles.sorted(by: {
                if $0.time.range.lowerBound != $1.time.range.lowerBound {
                    return $0.time.range.lowerBound < $1.time.range.lowerBound
                }
                return $0.member < $1.member
            }) {
                guard handle.time.count == 1 else {
                    fatalError("Ensemble stats currently require single-timestep handles")
                }
                let data = try await handle.read()
                await calculator.ingest(
                    time: handle.time.range.lowerBound,
                    variable: handle.variable,
                    spreadVariable: handle.variable.asSpreadVariableGeneric,
                    data: data
                )
            }
        }

        let writer = OmSpatialMultistepWriter(
            domain: ensembleMeanDomain,
            run: run,
            storeOnDisk: false,
            realm: nil,
            logger: logger,
            ensembleMeanDomain: nil
        )
        try await calculator.calculateAndWrite(to: writer)
        return try await writer.finalise()
    }
}
