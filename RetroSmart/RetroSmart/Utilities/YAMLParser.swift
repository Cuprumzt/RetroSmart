import Foundation

enum YAMLValue: Equatable {
    case dictionary([String: YAMLValue])
    case array([YAMLValue])
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null
}

struct YAMLSubsetParser {
    struct ParsedLine {
        let indent: Int
        let content: String
        let lineNumber: Int
    }

    func parse(_ text: String) throws -> YAMLValue {
        let lines = preprocess(text)
        guard !lines.isEmpty else {
            throw ModuleConfigError(message: "The YAML document is empty.")
        }

        let (value, nextIndex) = try parseBlock(lines: lines, startIndex: 0, indent: lines[0].indent)
        guard nextIndex == lines.count else {
            let line = lines[nextIndex]
            throw ModuleConfigError(message: "Unexpected trailing YAML content near line \(line.lineNumber).")
        }

        return value
    }

    private func preprocess(_ text: String) -> [ParsedLine] {
        text
            .split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
            .enumerated()
            .compactMap { index, rawLine in
                let stripped = stripComments(String(rawLine))
                guard !stripped.trimmingCharacters(in: .whitespaces).isEmpty else {
                    return nil
                }

                let indent = stripped.prefix { $0 == " " }.count
                return ParsedLine(
                    indent: indent,
                    content: stripped.trimmingCharacters(in: .whitespaces),
                    lineNumber: index + 1
                )
            }
    }

    private func stripComments(_ line: String) -> String {
        var result = ""
        var inSingleQuote = false
        var inDoubleQuote = false

        for character in line {
            if character == "'" && !inDoubleQuote {
                inSingleQuote.toggle()
            } else if character == "\"" && !inSingleQuote {
                inDoubleQuote.toggle()
            } else if character == "#" && !inSingleQuote && !inDoubleQuote {
                break
            }

            result.append(character)
        }

        return result
    }

    private func parseBlock(lines: [ParsedLine], startIndex: Int, indent: Int) throws -> (YAMLValue, Int) {
        guard startIndex < lines.count else {
            return (.null, startIndex)
        }

        if lines[startIndex].content.hasPrefix("- ") {
            return try parseArray(lines: lines, startIndex: startIndex, indent: indent)
        }

        return try parseDictionary(lines: lines, startIndex: startIndex, indent: indent)
    }

    private func parseDictionary(lines: [ParsedLine], startIndex: Int, indent: Int) throws -> (YAMLValue, Int) {
        var index = startIndex
        var dictionary: [String: YAMLValue] = [:]

        while index < lines.count {
            let line = lines[index]
            if line.indent < indent {
                break
            }
            if line.indent > indent {
                throw ModuleConfigError(message: "Unexpected indentation near line \(line.lineNumber).")
            }

            guard let separator = line.content.firstIndex(of: ":") else {
                throw ModuleConfigError(message: "Expected a key/value pair near line \(line.lineNumber).")
            }

            let key = String(line.content[..<separator]).trimmingCharacters(in: .whitespaces)
            let remainder = String(line.content[line.content.index(after: separator)...]).trimmingCharacters(in: .whitespaces)

            if remainder.isEmpty {
                let nextIndex = index + 1
                guard nextIndex < lines.count, lines[nextIndex].indent > indent else {
                    dictionary[key] = .null
                    index += 1
                    continue
                }

                let (nestedValue, consumedIndex) = try parseBlock(
                    lines: lines,
                    startIndex: nextIndex,
                    indent: lines[nextIndex].indent
                )
                dictionary[key] = nestedValue
                index = consumedIndex
            } else {
                dictionary[key] = try parseScalarOrInlineCollection(remainder)
                index += 1
            }
        }

        return (.dictionary(dictionary), index)
    }

    private func parseArray(lines: [ParsedLine], startIndex: Int, indent: Int) throws -> (YAMLValue, Int) {
        var index = startIndex
        var items: [YAMLValue] = []

        while index < lines.count {
            let line = lines[index]
            if line.indent < indent {
                break
            }
            if line.indent != indent || !line.content.hasPrefix("- ") {
                break
            }

            let remainder = String(line.content.dropFirst(2)).trimmingCharacters(in: .whitespaces)

            if remainder.isEmpty {
                let nextIndex = index + 1
                guard nextIndex < lines.count else {
                    items.append(.null)
                    index += 1
                    continue
                }

                let (nestedValue, consumedIndex) = try parseBlock(
                    lines: lines,
                    startIndex: nextIndex,
                    indent: lines[nextIndex].indent
                )
                items.append(nestedValue)
                index = consumedIndex
                continue
            }

            if let separator = remainder.firstIndex(of: ":") {
                let key = String(remainder[..<separator]).trimmingCharacters(in: .whitespaces)
                let valueRemainder = String(remainder[remainder.index(after: separator)...]).trimmingCharacters(in: .whitespaces)
                var itemDictionary: [String: YAMLValue] = [:]

                if valueRemainder.isEmpty {
                    itemDictionary[key] = .null
                } else {
                    itemDictionary[key] = try parseScalarOrInlineCollection(valueRemainder)
                }

                index += 1
                while index < lines.count, lines[index].indent > indent {
                    let (nestedValue, consumedIndex) = try parseDictionary(
                        lines: lines,
                        startIndex: index,
                        indent: lines[index].indent
                    )

                    guard case .dictionary(let nestedDictionary) = nestedValue else {
                        throw ModuleConfigError(message: "Expected a dictionary item near line \(lines[index].lineNumber).")
                    }

                    itemDictionary.merge(nestedDictionary) { _, new in new }
                    index = consumedIndex
                }

                items.append(.dictionary(itemDictionary))
            } else {
                items.append(try parseScalarOrInlineCollection(remainder))
                index += 1
            }
        }

        return (.array(items), index)
    }

    private func parseScalarOrInlineCollection(_ value: String) throws -> YAMLValue {
        if value.hasPrefix("[") && value.hasSuffix("]") {
            let content = String(value.dropFirst().dropLast())
            if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return .array([])
            }

            let parts = splitInlineArray(content)
            return .array(try parts.map(parseScalarOrInlineCollection))
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == "null" {
            return .null
        }
        if trimmed == "true" {
            return .bool(true)
        }
        if trimmed == "false" {
            return .bool(false)
        }
        if let intValue = Int(trimmed) {
            return .int(intValue)
        }
        if let doubleValue = Double(trimmed) {
            return .double(doubleValue)
        }
        if trimmed.hasPrefix("\""), trimmed.hasSuffix("\""), trimmed.count >= 2 {
            return .string(String(trimmed.dropFirst().dropLast()))
        }
        if trimmed.hasPrefix("'"), trimmed.hasSuffix("'"), trimmed.count >= 2 {
            return .string(String(trimmed.dropFirst().dropLast()))
        }

        return .string(trimmed)
    }

    private func splitInlineArray(_ input: String) -> [String] {
        var parts: [String] = []
        var current = ""
        var inSingleQuote = false
        var inDoubleQuote = false

        for character in input {
            if character == "'" && !inDoubleQuote {
                inSingleQuote.toggle()
            } else if character == "\"" && !inSingleQuote {
                inDoubleQuote.toggle()
            }

            if character == ",", !inSingleQuote, !inDoubleQuote {
                parts.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(character)
            }
        }

        if !current.isEmpty {
            parts.append(current.trimmingCharacters(in: .whitespaces))
        }

        return parts
    }
}

extension YAMLValue {
    func requireDictionary(context: String) throws -> [String: YAMLValue] {
        guard case .dictionary(let dictionary) = self else {
            throw ModuleConfigError(message: "Expected a dictionary in \(context).")
        }
        return dictionary
    }
}

extension Dictionary where Key == String, Value == YAMLValue {
    func requireValue(_ key: String, context: String) throws -> YAMLValue {
        guard let value = self[key] else {
            throw ModuleConfigError(message: "Missing required key '\(key)' in \(context).")
        }
        return value
    }

    func value(_ key: String) -> YAMLValue? {
        self[key]
    }

    func requireString(_ key: String, context: String) throws -> String {
        guard let string = string(key) else {
            throw ModuleConfigError(message: "Expected '\(key)' to be a string in \(context).")
        }
        return string
    }

    func requireInt(_ key: String, context: String) throws -> Int {
        guard let int = int(key) else {
            throw ModuleConfigError(message: "Expected '\(key)' to be an integer in \(context).")
        }
        return int
    }

    func requireArray(_ key: String, context: String) throws -> [YAMLValue] {
        guard let array = array(key) else {
            throw ModuleConfigError(message: "Expected '\(key)' to be a list in \(context).")
        }
        return array
    }

    func string(_ key: String) -> String? {
        guard let value = self[key] else { return nil }
        switch value {
        case .string(let string):
            return string
        case .int(let int):
            return String(int)
        case .double(let double):
            return String(double)
        default:
            return nil
        }
    }

    func int(_ key: String) -> Int? {
        guard let value = self[key] else { return nil }
        switch value {
        case .int(let int):
            return int
        case .double(let double):
            return Int(double)
        case .string(let string):
            return Int(string)
        default:
            return nil
        }
    }

    func double(_ key: String) -> Double? {
        guard let value = self[key] else { return nil }
        switch value {
        case .int(let int):
            return Double(int)
        case .double(let double):
            return double
        case .string(let string):
            return Double(string)
        default:
            return nil
        }
    }

    func bool(_ key: String) -> Bool? {
        guard let value = self[key] else { return nil }
        switch value {
        case .bool(let bool):
            return bool
        case .string(let string):
            return Bool(string)
        default:
            return nil
        }
    }

    func array(_ key: String) -> [YAMLValue]? {
        guard let value = self[key] else { return nil }
        guard case .array(let array) = value else { return nil }
        return array
    }

    func arrayStrings(_ key: String) -> [String]? {
        array(key)?.compactMap {
            switch $0 {
            case .string(let string):
                return string
            case .int(let int):
                return String(int)
            case .double(let double):
                return String(double)
            default:
                return nil
            }
        }
    }

    func dictionaryStrings(_ key: String) -> [String: String]? {
        guard let value = self[key], case .dictionary(let dictionary) = value else {
            return nil
        }

        return dictionary.reduce(into: [String: String]()) { result, pair in
            switch pair.value {
            case .string(let string):
                result[pair.key] = string
            case .int(let int):
                result[pair.key] = String(int)
            case .double(let double):
                result[pair.key] = String(double)
            default:
                break
            }
        }
    }
}
