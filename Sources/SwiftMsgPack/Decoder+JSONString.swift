//
//  Decoder+JSONString.swift
//  
//
//  Created by Nghia Tran on 23/06/2021.
//

import Foundation

public extension Data {

    // MARK - Unpack

    /// This is the public function which can read a sequence of Data
    /// and unpack all objects by returning a escaped String
    func unpackAsString() throws -> String? {
        // Create a reader which has a point to the current position in data instance
        // and several help functions to read data
        var reader = StreamReader(self)
        // try to unpack data
        return try self.unpackAsString(stream: &reader)
    }

    // MARK - Unpack Internal Functions

    /// This is the unpack function which reader
    ///
    /// - Parameter stream: stream object
    /// - Returns: decoded data
    /// - Throws: an error if decoding task cannot be finished correctly due to an error
    private func unpackAsString(stream: inout StreamReader) throws -> String? {
        let type = try stream.readType()

        // Spec is defined here:
        // https://github.com/msgpack/msgpack/blob/master/spec.md#formats-bool
        switch type {

        // POSITIVE FIX INT
        // positive fixint    0xxxxxxx    0x00 - 0x7f
        case 0x00...0x7f:
            return "\(Int8(type))"

        // FIX DICTIONARY (< 16 ITEMS)
        // fixmap    1000xxxx    0x80 - 0x8f
        case 0x80...0x8f:
            let count_items = Int(type & 0xf)
            return try self.unpackAsString(dictionary: &stream, count: count_items)

        // FIX ARRAY (< 16 ITEMS)
        // fixarray    1001xxxx    0x90 - 0x9f
        case 0x90...0x9f:
            let count_items = Int(type & 0xf)
            return try self.unpackAsString(array: &stream, count: count_items)

        // NEGATIVE FIX NUM
        // negative fixint    111xxxxx    0xe0 - 0xff
        case 0xe0...0xff:
            return "\(Int8(Int(type) - 256))"

        // FIX STRING (< 16 CHARS)
        // fixstr    101xxxxx    0xa0 - 0xbf
        case 0xa0...0xbf:
            let str_length = Int(type - 0xa0)
            return try self.unpackAsString(string: &stream, length: str_length)

        // NIL VALUE
        // nil    11000000    0xc0
        case 0xc0:
            return "null"

        // BOOLEAN FALSE
        // false     11000010    0xc2
        case 0xc2:
            return "false"

        // BOOLEAN TRUE
        // true    11000011    0xc3
        case 0xc3:
            return "true"

        // BINARY DATA 8 BIT
        // bin 8    11000100    0xc4
        case 0xc4:
            let len_data = Int(try stream.read8Bit())
            return "\(try stream.readData(length: len_data))"

        // BINARY DATA 16 BIT
        // bin 16    11000101    0xc5
        case 0xc5:
            let len_data = Int(try stream.read16Bit())
            return "\(try stream.readData(length: len_data))"

        // BINARY DATA 32 BIT
        // bin 32    11000110    0xc6
        case 0xc6:
            let len_data = Int(try stream.read32Bit())
            return "\(try stream.readData(length: len_data))"

        // FLOAT 32 BIT
        // float 32    11001010    0xca
        case 0xca:
            return "\(Float(bitPattern: try stream.read32Bit()))"

        // DOUBLE
        // float 64    11001011    0xcb
        case 0xcb:
            return "\(Double(bitPattern: try stream.read64Bit()))"

        // UNSIGNED INT 8 BIT
        // uint 8    11001100    0xcc
        case 0xcc:
            return "\(try stream.readType())"

        // UNSIGNED INT 16 BIT
        // uint 16    11001101    0xcd
        case 0xcd:
            let h = UInt16(try stream.read8Bit())
            let l = UInt16(try stream.read8Bit())
            return "\((h << 8 + l))"

        // UNSIGNED INT 32 BIT
        // uint 32    11001110    0xce
        case 0xce:
            return "\(try stream.read32Bit())"

        // UNSIGNED INT 64 BIT
        // uint 64    11001111    0xcf
        case 0xcf:
            return "\(try stream.read64Bit())"

        // INT 8 BIT
        // int 8    11010000    0xd0
        case 0xd0:
            let value = try stream.read8Bit()
            return "\(Int8(Int(value) - 256))"

        // INT 16 BIT
        // int 16    11010001    0xd1
        case 0xd1:
            let h = UInt16(try stream.read8Bit())
            let l = UInt16(try stream.read8Bit())
            return "\(Int16(bitPattern: h << 8 + l))"

        // INT 32 BIT
        // int 32    11010010    0xd2
        case 0xd2:
            return "\(try Int32(bitPattern: stream.read32Bit()))"

        // INT 64 BIT
        // int 64    11010011    0xd3
        case 0xd3:
            return "\(try Int64(bitPattern: stream.read64Bit()))"

        // STRING 8 BIT LENGTH
        // str 8    11011001    0xd9
        case 0xd9:
            let len_data = Int(try stream.read8Bit())
            return try unpackAsString(string: &stream, length: len_data)

        // STRING 16 BIT LENGTH
        // str 16    11011010    0xda
        case 0xda:
            let len_data = Int(try stream.read8Bit()) << 8 + Int(try stream.read8Bit())
            return try unpackAsString(string: &stream, length: len_data)

        // STRING 32 BIT LENGTH
        // str 32    11011011    0xdb
        case 0xdb:
            var len_data = Int(try stream.read8Bit()) << 24
            len_data += Int(try stream.read8Bit()) << 16
            len_data += Int(try stream.read8Bit()) << 8
            len_data += Int(try stream.read8Bit())
            return try unpackAsString(string: &stream, length: len_data)


        // ARRAY 16 ITEMS LENGTH
        // array 16    11011100    0xdc
        case 0xdc:
            let count_items = Int(try stream.read16Bit())
            return try unpackAsString(array: &stream, count: count_items)

        // ARRAY 32 ITEMS LENGTH
        // array 32    11011101    0xdd
        case 0xdd:
            let count_items = Int(try stream.read32Bit())
            return try unpackAsString(array: &stream, count: count_items)

        // DICTIONARY 16 ITEMS LENGTH
        // map 16    11011110    0xde
        case 0xde:
            let count_items = Int(try stream.read16Bit())
            return try unpackAsString(dictionary: &stream, count: count_items)

        // DICTIONARY 32 ITEMS LENGTH
        // map 32    11011111    0xdf
        case 0xdf:
            let count_items = Int(try stream.read32Bit())
            return try unpackAsString(dictionary: &stream, count: count_items)

        default:
            throw MsgPackError.unsupportedValue(String(format: "Type(%02x)", type))
        }
    }

    /// Unpack a `dictionary` sequence
    ///
    /// - Parameters:
    ///   - stream: input stream of data
    ///   - count: number of keys in dictionary
    /// - Returns: decoded dictionary
    /// - Throws: throw an exception if failed to decoded data
    private func unpackAsString(dictionary stream: inout StreamReader, count: Int) throws -> String {
        var dictString = "{"
        for i in 0..<count {
            guard let key = try self.unpackAsString(stream: &stream) else {
                throw MsgPackError.unsupportedValue("Invalid dict key")
            }
            let val = try self.unpackAsString(stream: &stream)
            dictString += "\(key):\(val ?? "null")"
            if i != (count - 1) {
                dictString += ","
            }
        }
        dictString += "}"
        return dictString
    }

    /// Unpack an `array` sequence
    ///
    /// - Parameters:
    ///   - stream: input stream of data
    ///   - count: number of keys in array
    /// - Returns: decoded array
    /// - Throws: throw an exception if failed to decoded data
    private func unpackAsString(array stream: inout StreamReader, count: Int) throws -> String {
        var arrayString = "["
        for i in 0..<count {
            let value = try self.unpackAsString(stream: &stream)
            arrayString += "\(value ?? "null")"
            if i != (count - 1) {
                arrayString += ","
            }
        }
        arrayString += "]"
        return arrayString
    }


    /// Unpack a `string` sequence
    ///
    /// - Parameters:
    ///   - stream: input stream of data
    ///   - length: length of data to read
    /// - Returns: decoded string
    /// - Throws: throw an exception if failed to decoded data
    private func unpackAsString(string stream: inout StreamReader, length: Int) throws -> String {
        let data = try stream.readData(length: length)
        guard let str = String(data: data, encoding: String.Encoding.utf8) else {
            throw MsgPackError.invalidEncoding
        }
        return str.javaScriptEscapedString
    }

}

extension String {

    var javaScriptEscapedString: String {
        // Because JSON is not a subset of JavaScript, the LINE_SEPARATOR and PARAGRAPH_SEPARATOR unicode
        // characters embedded in (valid) JSON will cause the webview's JavaScript parser to error. So we
        // must encode them first. See here: http://timelessrepo.com/json-isnt-a-javascript-subset
        // Also here: http://media.giphy.com/media/wloGlwOXKijy8/giphy.gif
        let str = self.replacingOccurrences(of: "\u{2028}", with: "\\u2028")
                      .replacingOccurrences(of: "\u{2029}", with: "\\u2029")
        // Because escaping JavaScript is a non-trivial task (https://github.com/johnezang/JSONKit/blob/master/JSONKit.m#L1423)
        // we proceed to hax instead:
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode([str])
            let encodedString = String(decoding: data, as: UTF8.self)
            return String(encodedString.dropLast().dropFirst())
        } catch {
            return self
        }
    }
}
