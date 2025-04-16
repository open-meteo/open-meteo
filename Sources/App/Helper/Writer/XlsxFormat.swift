import Foundation
import CZlib
import NIOCore

/// Create a simple excel sheet with exactly one sheet and the bare minimum to make it work in office applications
/// Please note that XLSX only support up to 16k columns
public final class XlsxWriter {
    let sheet_xml: GzipStream

    static var workbook_xml: ByteBuffer {
        let workbook_xml = try! GzipStream(level: 6, chunkCapacity: 512)
        workbook_xml.write("""
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Sheet1" sheetId="1" r:id="rId1"/></sheets></workbook>
        """)
        return workbook_xml.finish()
    }

    static var workbook_xml_rels: ByteBuffer {
        let workbook_xml_rels = try! GzipStream(level: 6, chunkCapacity: 512)
        workbook_xml_rels.write("""
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/></Relationships>
        """)
        return workbook_xml_rels.finish()
    }

    static var rels: ByteBuffer {
        let rels = try! GzipStream(level: 6, chunkCapacity: 512)
        rels.write("""
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>
        """)
        return rels.finish()
    }

    static var content_type: ByteBuffer {
        let content_type = try! GzipStream(level: 6, chunkCapacity: 512)
        content_type.write( """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/><Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/></Types>
        """)
        return content_type.finish()
    }

    static var styles_xml: ByteBuffer {
        let styles_xml = try! GzipStream(level: 6, chunkCapacity: 512)
        styles_xml.write("""
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" mc:Ignorable="x14ac x16r2 xr" xmlns:x14ac="http://schemas.microsoft.com/office/spreadsheetml/2009/9/ac" xmlns:x16r2="http://schemas.microsoft.com/office/spreadsheetml/2015/02/main" xmlns:xr="http://schemas.microsoft.com/office/spreadsheetml/2014/revision"><numFmts count="1"><numFmt numFmtId="168" formatCode="yyyy\\-mm\\-dd\\Thh:mm"/></numFmts><fonts count="1" x14ac:knownFonts="1"><font><sz val="12"/><color theme="1"/><name val="Calibri"/><family val="2"/><scheme val="minor"/></font></fonts><fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills><borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders><cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs><cellXfs count="2"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/><xf numFmtId="168" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/></cellXfs><cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles><dxfs count="0"/><tableStyles count="0" defaultTableStyle="TableStyleMedium2" defaultPivotStyle="PivotStyleLight16"/><extLst><ext uri="{EB79DEF2-80B8-43e5-95BD-54CBDDF9020C}" xmlns:x14="http://schemas.microsoft.com/office/spreadsheetml/2009/9/main"><x14:slicerStyles defaultSlicerStyle="SlicerStyleLight1"/></ext><ext uri="{9260A510-F301-46a8-8635-F512D64BE5F5}" xmlns:x15="http://schemas.microsoft.com/office/spreadsheetml/2010/11/main"><x15:timelineStyles defaultTimelineStyle="TimeSlicerStyleLight1"/></ext></extLst></styleSheet>
        """)
        return styles_xml.finish()
    }

    public init() throws {
        sheet_xml = try GzipStream(level: 6, chunkCapacity: 4096)
        sheet_xml.write( """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheetData>
        """)
    }

    public func startRow() {
        sheet_xml.write("<row>")
    }

    public func endRow() {
        sheet_xml.write("</row>")
    }

    public func write(_ int: Int) {
        sheet_xml.write("<c><v>\(int)</v></c>")
    }

    /// Write unix timestamp with iso8601 formated date
    public func writeTimestamp(_ timestamp: Timestamp) {
        let excelTime = Double(timestamp.timeIntervalSince1970) / 86400 + (70 * 365 + 19)
        sheet_xml.write("<c s=\"1\"><v>\(excelTime)</v></c>")
    }

    /// Write Float
    /// See https://docs.microsoft.com/en-us/dotnet/api/documentformat.openxml.spreadsheet.cell
    public func write(_ float: Float, significantDigits: Int) {
        if float.isInfinite || float.isNaN {
            sheet_xml.write("<c t=\"e\"><v>#NUM!</v></c>")
        } else {
            sheet_xml.write("<c><v>\(String(format: "%.\(significantDigits)f", float))</v></c>")
        }
    }

    /// Write string
    public func write(_ string: String) {
        sheet_xml.write("<c t=\"inlineStr\"><is><t>\(string)</t></is></c>")
    }

    func write(timestamp: Timestamp = .now()) -> ByteBuffer {
        sheet_xml.write("</sheetData></worksheet>")

        return ZipWriter.zip(files: [
            (path: "[Content_Types].xml", compressed: Self.content_type),
            (path: "xl/workbook.xml", compressed: Self.workbook_xml),
            (path: "xl/_rels/workbook.xml.rels", compressed: Self.workbook_xml_rels),
            (path: "_rels/.rels", compressed: Self.rels),
            (path: "xl/styles.xml", compressed: Self.styles_xml),
            (path: "xl/worksheets/sheet1.xml", compressed: sheet_xml.finish())
        ], timestamp: timestamp)
    }
}

enum ZipStreamError: Error {
    case zlibDeflateInitInvalidParameter
    case zlibInsufficientMemory
    case zlibVersionError
    case deflateInitFailed(code: Int32)
}

/// Gzip Stream compressor w
public final class GzipStream {
    var zstream: UnsafeMutablePointer<z_stream>
    var writebuffer: ByteBuffer

    public init(level: Int32 = 6, chunkCapacity: Int = 4096) throws {
        zstream = UnsafeMutablePointer<z_stream>.allocate(capacity: 1)
        zstream.pointee.zalloc = nil
        zstream.pointee.zfree = nil
        let ret = deflateInit2_(zstream, level, Z_DEFLATED, 15 | 16, MAX_MEM_LEVEL, Z_DEFAULT_STRATEGY, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
        guard ret != Z_STREAM_ERROR else {
            throw ZipStreamError.zlibDeflateInitInvalidParameter
        }
        guard ret != Z_MEM_ERROR else {
            throw ZipStreamError.zlibInsufficientMemory
        }
        guard ret != Z_VERSION_ERROR else {
            throw ZipStreamError.zlibVersionError
        }
        guard ret == Z_OK else {
            throw ZipStreamError.deflateInitFailed(code: ret)
        }
        self.writebuffer = ByteBufferAllocator().buffer(capacity: chunkCapacity)
        writebuffer.withUnsafeMutableWritableBytes { ptr in
            zstream.pointee.avail_out = UInt32(ptr.count)
            zstream.pointee.next_out = ptr.baseAddress?.assumingMemoryBound(to: Bytef.self)
            zstream.pointee.total_out = 0
        }
    }

    public func write(_ str: String) {
        str.withContiguousStorageIfAvailable { body in
            compress(data: UnsafeRawBufferPointer(body), flush: Z_NO_FLUSH)
        } ?? {
            var str = str
            str.withUTF8({ body in
                compress(data: UnsafeRawBufferPointer(body), flush: Z_NO_FLUSH)
            })
        }()
    }

    /// flush and return data
    public func finish() -> ByteBuffer {
        compress(data: nil, flush: Z_FINISH)
        return writebuffer
    }

    /// compress
    func compress(data: UnsafeRawBufferPointer?, flush: Int32) {
        if let data = data {
            // set input
            zstream.pointee.next_in = UnsafeMutablePointer(mutating: data.bindMemory(to: UInt8.self).baseAddress)
            zstream.pointee.avail_in = UInt32(data.count)
        }
        repeat {
            if zstream.pointee.avail_out == 0 {
                /// Increase buffer capacity. Always double underlaying storage.
                writebuffer.reserveCapacity(minimumWritableBytes: writebuffer.writerIndex)
                writebuffer.withUnsafeMutableWritableBytes({ ptr in
                    zstream.pointee.avail_out = uInt(ptr.count)
                    zstream.pointee.next_out = ptr.baseAddress?.assumingMemoryBound(to: Bytef.self)
                })
            }
            let avail_out_before = zstream.pointee.avail_out
            let ret = deflate(zstream, flush)
            writebuffer.moveWriterIndex(forwardBy: Int(avail_out_before - zstream.pointee.avail_out))
            if ret == Z_STREAM_END {
                break
            }
            guard ret == Z_OK else {
                fatalError("deflate loop error, \(ret)")
            }
        } while zstream.pointee.avail_out == 0
    }

    deinit {
        deflateEnd(zstream)
        zstream.deallocate()
    }
}

fileprivate extension Data {
    mutating func append(_ value: UInt32) {
        Swift.withUnsafeBytes(of: value) {
            self.append(contentsOf: $0)
        }
    }
    mutating func append(_ value: UInt16) {
        Swift.withUnsafeBytes(of: value) {
            self.append(contentsOf: $0)
        }
    }
}

public enum ZipWriter {
    /// compressed input data must be gzip compressed with correct gzip headers
    public static func zip(files: [(path: String, compressed: ByteBuffer)], timestamp: Timestamp = .now()) -> ByteBuffer {
        let totalSize = files.reduce(22, {
            $0 + $1.path.count * 2 + $1.compressed.writerIndex - 18 + 30 + 46
        })
        var out = ByteBufferAllocator().buffer(capacity: totalSize)

        let date = timestamp.toComponents()
        let modificationDate = UInt16(date.day) | ((UInt16(date.month) << 5)) | ((UInt16(date.year - 1980) << 9))
        let modificationTime = UInt16(timestamp.second) | ((UInt16(timestamp.minute) << 5)) | ((UInt16(timestamp.hour) << 11))

        // print local file header and compressed data
        var localHeaderOffsets = [Int]()
        localHeaderOffsets.reserveCapacity(files.count)

        for (path, compressed) in files {
            localHeaderOffsets.append(out.writerIndex)
            out.writeInteger(UInt32(0x04034b50), endianness: .little) // local fileheader signature
            out.writeInteger(UInt16(0x0014), endianness: .little) // version
            out.writeInteger(UInt16(0x0000), endianness: .little) // bitflag
            out.writeData([(compressed.getInteger(at: 2) as UInt8?)!, 0]) // compression method, lzma
            out.writeInteger(modificationTime, endianness: .little)
            out.writeInteger(modificationDate, endianness: .little)
            out.writeInteger((compressed.getInteger(at: compressed.writerIndex - 8) as UInt32?)!) // crc
            out.writeInteger(UInt32(compressed.writerIndex - 10 - 8), endianness: .little) // compressed size
            out.writeInteger((compressed.getInteger(at: compressed.writerIndex - 4) as UInt32?)!) // uncompressed size
            out.writeInteger(UInt16(path.count), endianness: .little) // filename length
            out.writeInteger(UInt16(0x0000), endianness: .little) // extra field length
            out.writeString(path) // filename
            var payload = compressed.getSlice(at: 10, length: compressed.writerIndex - 8 - 10)!
            out.writeBuffer(&payload) // compressed payload without header
        }

        let centralDirOffset = out.writerIndex

        // print central directory header
        for (i, (path, compressed)) in files.enumerated() {
            out.writeInteger(UInt32(0x02014b50), endianness: .little) // signature
            out.writeInteger(UInt16(0x0000), endianness: .little) // version generated by
            out.writeInteger(UInt16(0x0014), endianness: .little) // version needed
            out.writeInteger(UInt16(0x0000), endianness: .little) // bit flag
            out.writeData([(compressed.getInteger(at: 2) as UInt8?)!, 0]) // compression method, lzma
            out.writeInteger(modificationTime, endianness: .little)
            out.writeInteger(modificationDate, endianness: .little)
            out.writeInteger((compressed.getInteger(at: compressed.writerIndex - 8) as UInt32?)!) // crc
            out.writeInteger(UInt32(compressed.writerIndex - 10 - 8), endianness: .little) // compressed size
            out.writeInteger((compressed.getInteger(at: compressed.writerIndex - 4) as UInt32?)!) // uncompressed size
            out.writeInteger(UInt16(path.count), endianness: .little) // filename length
            out.writeInteger(UInt16(0x0000), endianness: .little) // extra field length
            out.writeInteger(UInt16(0x0000), endianness: .little) // comment length
            out.writeInteger(UInt16(0x0000), endianness: .little) // disk number start
            out.writeInteger(UInt16(0x0000), endianness: .little) // internal attributes
            out.writeInteger(UInt32(0x0000), endianness: .little) // external attributes
            out.writeInteger(UInt32(localHeaderOffsets[i]), endianness: .little)
            out.writeString(path) // filename
        }

        let centralDirSize = out.writerIndex - centralDirOffset

        // end central directory
        out.writeInteger(UInt32(0x06054b50), endianness: .little) // sig
        out.writeInteger(UInt16(0x0000), endianness: .little) // number of disks
        out.writeInteger(UInt16(0x0000), endianness: .little) // number of disks start
        out.writeInteger(UInt16(files.count), endianness: .little) // number disk entries
        out.writeInteger(UInt16(files.count), endianness: .little) // number central directory entries
        out.writeInteger(UInt32(centralDirSize), endianness: .little)
        out.writeInteger(UInt32(centralDirOffset), endianness: .little)
        out.writeInteger(UInt16(0x00), endianness: .little) // zip comment length

        precondition(totalSize == out.writerIndex)
        return out
    }
}
