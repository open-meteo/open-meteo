// automatically generated by the FlatBuffers compiler, do not modify
// swiftlint:disable all
// swiftformat:disable all

import FlatBuffers

public enum SiUnit: Int8, Enum, Verifiable {
  public typealias T = Int8
  public static var byteSize: Int { return MemoryLayout<Int8>.size }
  public var value: Int8 { return self.rawValue }
  case undefined = 0
  case celsius = 1
  case fahrenheit = 2
  case kelvin = 3
  case kmh = 4
  case mph = 5
  case knots = 6
  case ms = 7
  case msNotUnitConverted = 8
  case millimeter = 9
  case centimeter = 10
  case inch = 11
  case feet = 12
  case meter = 13
  case gpm = 14
  case percent = 15
  case hectoPascal = 16
  case pascal = 17
  case degreeDirection = 18
  case wmoCode = 19
  case wattPerSquareMeter = 20
  case kilogramPerSquareMeter = 21
  case gramPerKilogram = 22
  case perSecond = 23
  case second = 24
  case qubicMeterPerQubicMeter = 25
  case qubicMeterPerSecond = 26
  case kiloPascal = 27
  case megaJoulesPerSquareMeter = 28
  case joulesPerKilogram = 29
  case hours = 30
  case iso8601 = 31
  case unixtime = 32
  case microgramsPerQuibicMeter = 33
  case grainsPerQuibicMeter = 34
  case dimensionless = 35
  case dimensionlessInteger = 36
  case eaqi = 37
  case usaqi = 38
  case gddCelsius = 39
  case fraction = 40

  public static var max: SiUnit { return .fraction }
  public static var min: SiUnit { return .undefined }
}


