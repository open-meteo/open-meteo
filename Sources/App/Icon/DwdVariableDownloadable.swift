/// Fields consumed by the shared DWD native-grid ingestion pipeline.
protocol DwdVariableDownloadable: GenericVariable {
    var multiplyAdd: (multiply: Float, add: Float)? { get }
    func getVarAndLevel(model: DwdModel) -> (variable: String, cat: String, level: Int?)?
    func skipHour(hour: Int, model: DwdModel, forDownload: Bool, run: Timestamp) -> Bool
}

extension IconVariableDownloadable {
    func getVarAndLevel(model: DwdModel) -> (variable: String, cat: String, level: Int?)? {
        guard let domain = model.iconFeed else { return nil }
        return domain.getVarAndLevel(self)
    }

    func skipHour(hour: Int, model: DwdModel, forDownload: Bool, run: Timestamp) -> Bool {
        guard let domain = model.iconFeed else { return true }
        return domain.skipHour(self, hour: hour, forDownload: forDownload, run: run)
    }
}

extension AiconSurfaceVariable: DwdVariableDownloadable {
    func getVarAndLevel(model: DwdModel) -> (variable: String, cat: String, level: Int?)? {
        model == .aicon ? (gribVariableName, "single-level", nil) : nil
    }

    func skipHour(hour: Int, model: DwdModel, forDownload: Bool, run: Timestamp) -> Bool {
        model != .aicon || hour == 0
    }
}
