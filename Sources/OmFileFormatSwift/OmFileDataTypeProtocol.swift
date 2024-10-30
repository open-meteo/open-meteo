//
//  OmFileDataTypeProtocol.swift
//  OpenMeteoApi
//
//  Created by Patrick Zippenfenig on 30.10.2024.
//

/// Allowed data types for reading and writing
public protocol OmFileDataTypeProtocol {
    static var dataType: DataType { get }
}

extension Int8: OmFileDataTypeProtocol {
    public static var dataType: DataType {
        return .int8
    }
}

extension UInt8: OmFileDataTypeProtocol {
    public static var dataType: DataType {
        return .uint8
    }
}

extension Int16: OmFileDataTypeProtocol {
    public static var dataType: DataType {
        return .int16
    }
}

extension UInt16: OmFileDataTypeProtocol {
    public static var dataType: DataType {
        return .uint16
    }
}

extension Int32: OmFileDataTypeProtocol {
    public static var dataType: DataType {
        return .int32
    }
}

extension UInt32: OmFileDataTypeProtocol {
    public static var dataType: DataType {
        return .uint32
    }
}

extension Int: OmFileDataTypeProtocol {
    public static var dataType: DataType {
        return .int64
    }
}

extension UInt: OmFileDataTypeProtocol {
    public static var dataType: DataType {
        return .uint64
    }
}

extension Float: OmFileDataTypeProtocol {
    public static var dataType: DataType {
        return .float
    }
}

extension Double: OmFileDataTypeProtocol {
    public static var dataType: DataType {
        return .double
    }
}
