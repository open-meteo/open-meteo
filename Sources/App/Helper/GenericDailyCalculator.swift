import Foundation


protocol DailyVariableCalculatable {
    associatedtype Variable
    var aggregation: DailyAggregation<Variable> { get }
}

enum DailyAggregation<WeatherVariable> {
    case none
    case max(WeatherVariable)
    case min(WeatherVariable)
    case mean(WeatherVariable)
    case sum(WeatherVariable)
    case radiationSum(WeatherVariable)
    case precipitationHours(WeatherVariable)
    case dominantDirection(velocity: WeatherVariable, direction: WeatherVariable)
    case dominantDirectionComponents(u: WeatherVariable, v: WeatherVariable)
    
    /// Return 0, 1 or 2 weahter variables which should be prefetched
    var variables: (WeatherVariable?, WeatherVariable?) {
        switch self {
        case .none:
            return (nil, nil)
        case .max(let weatherVariable):
            return (weatherVariable, nil)
        case .min(let weatherVariable):
            return (weatherVariable, nil)
        case .mean(let weatherVariable):
            return (weatherVariable, nil)
        case .sum(let weatherVariable):
            return (weatherVariable, nil)
        case .radiationSum(let weatherVariable):
            return (weatherVariable, nil)
        case .precipitationHours(let weatherVariable):
            return (weatherVariable, nil)
        case .dominantDirection(let velocity, let direction):
            return (velocity, direction)
        case .dominantDirectionComponents(let u, let v):
            return (u, v)
        }
    }
}

/*extension GenericReaderMixable {
    func getDaily<V: DailyVariableCalculatable, Units: ApiUnitsSelectable>(variable: V, params: Units, time timeDaily: TimerangeDt) throws -> DataAndUnit? where V.Variable == MixingVar {
        let time = timeDaily.with(dtSeconds: 3600)
        fatalError()
    }
    
    func prefetchDaily<V: DailyVariableCalculatable>(variables: [V], time timeDaily: TimerangeDt) throws where V.Variable == MixingVar {
        fatalError()
    }
}*/

extension GenericReaderMulti {
    func getDaily<V: DailyVariableCalculatable, Units: ApiUnitsSelectable>(variable: V, params: Units, time timeDaily: TimerangeDt) throws -> DataAndUnit? where V.Variable == Variable {
        let time = timeDaily.with(dtSeconds: 3600)
        
        switch variable.aggregation {
        case .none:
            return nil
        case .max(let variable):
            guard let data = try get(variable: variable, time: time)?.convertAndRound(params: params) else {
                return nil
            }
            return DataAndUnit(data.data.max(by: 24), data.unit)
        case .min(let variable):
            guard let data = try get(variable: variable, time: time)?.convertAndRound(params: params) else {
                return nil
            }
            return DataAndUnit(data.data.min(by: 24), data.unit)
        case .mean(let variable):
            guard let data = try get(variable: variable, time: time)?.convertAndRound(params: params) else {
                return nil
            }
            return DataAndUnit(data.data.mean(by: 24), data.unit)
        case .sum(let variable):
            guard let data = try get(variable: variable, time: time)?.convertAndRound(params: params) else {
                return nil
            }
            return DataAndUnit(data.data.sum(by: 24), data.unit)
        case .radiationSum(let variable):
            guard let data = try get(variable: variable, time: time)?.convertAndRound(params: params) else {
                return nil
            }
            // 3600s only for hourly data of source
            return DataAndUnit(data.data.map({$0*0.0036}).sum(by: 24).round(digits: 2), .megajoulePerSquareMetre)
        case .precipitationHours(let variable):
            guard let data = try get(variable: variable, time: time)?.convertAndRound(params: params) else {
                return nil
            }
            return DataAndUnit(data.data.map({$0 > 0.001 ? 1 : 0}).sum(by: 24), .hours)
        case .dominantDirection(velocity: let velocity, direction: let direction):
            guard let speed = try get(variable: velocity, time: time)?.data,
                let direction = try get(variable: direction, time: time)?.data else {
                return nil
            }
            // vector addition
            let u = zip(speed, direction).map(Meteorology.uWind).sum(by: 24)
            let v = zip(speed, direction).map(Meteorology.vWind).sum(by: 24)
            return DataAndUnit(Meteorology.windirectionFast(u: u, v: v), .degreeDirection)
        case .dominantDirectionComponents(u: let u, v: let v):
            guard let u = try get(variable: u, time: time)?.data,
                let v = try get(variable: v, time: time)?.data else {
                return nil
            }
            return DataAndUnit(Meteorology.windirectionFast(u: u.sum(by: 24), v: v.sum(by: 24)), .degreeDirection)
        }
    }
    

    func prefetchData<V: DailyVariableCalculatable>(variables: [V], time timeDaily: TimerangeDt) throws where V.Variable == Variable {
        let time = timeDaily.with(dtSeconds: 3600)
        for variable in variables {
            if let v0 = variable.aggregation.variables.0 {
                try prefetchData(variable: v0, time: time)
            }
            if let v1 = variable.aggregation.variables.1 {
                try prefetchData(variable: v1, time: time)
            }
        }
    }
}
