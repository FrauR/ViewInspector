import SwiftUI

@available(iOS 13.0, macOS 10.15, tvOS 13.0, *)
internal extension ViewType.Text.Attributes {
    
    static func extract(from view: InspectableView<ViewType.Text>) throws -> ViewType.Text.Attributes {
        if let first = try? Inspector
            .attribute(path: "storage|anyTextStorage|first", value: view.content.view, type: Text.self),
            let second = try? Inspector
                .attribute(path: "storage|anyTextStorage|second", value: view.content.view, type: Text.self) {
            let firstAttr = try first.inspect().text().attributes()
            let secondAttr = try second.inspect().text().attributes()
            return firstAttr + secondAttr
        }
        let string = try view.string()
        let modifiers = try Inspector.attribute(label: "modifiers", value: view.content.view, type: [Any].self)
        return .init(string: string, modifiers: modifiers)
    }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, *)
public extension ViewType.Text.Attributes {
    
    subscript<Range>(_ range: Range) -> Self where Range: RangeExpression, Range.Bound == Int {
        let relativeRange = range.relative(to: 0..<string.count)
        let chunksInRange = zip(chunkRanges, chunks)
            .filter { relativeRange.overlaps($0.0) }
            .map { $0.1 }
        return .init(chunks: chunksInRange)
    }

    subscript<Range>(_ range: Range) -> Self where Range: RangeExpression, Range.Bound == String.Index {
        let relativeRange = range.relative(to: string)
        let chunksInRange = zip(chunkStringRanges, chunks)
            .filter { relativeRange.overlaps($0.0) }
            .map { $0.1 }
        return .init(chunks: chunksInRange)
    }
    
    func isItalic() throws -> Bool {
        return try commonTrait(name: "italic") { modifier in
            String(describing: modifier) == "italic" ? true : nil
        } == true
    }
    
    func isBold() throws -> Bool {
        do {
            return try fontWeight(attributeName: "bold") == .bold
        } catch {
            if case .textAttribute = error as? InspectionError {
                throw error
            }
        }
        return try commonTrait(name: "bold") { modifier in
            guard let child = try? Inspector.attribute(label: "anyTextModifier", value: modifier)
                else { return nil }
            return Inspector.typeName(value: child) == "BoldTextModifier" ? true : nil
        } == true
    }
    
    func fontWeight() throws -> Font.Weight {
        return try fontWeight(attributeName: "fontWeight")
    }
    
    private func fontWeight(attributeName: String) throws -> Font.Weight {
        return try commonTrait(name: attributeName) { modifier -> Font.Weight? in
            guard let fontWeight = try? Inspector
                .attribute(path: "weight|some", value: modifier, type: Font.Weight.self)
                else { return nil }
            return fontWeight
        }
    }
    
    func font() throws -> Font {
        return try commonTrait(name: "font") { modifier -> Font? in
            return try? Inspector.attribute(path: "font|some", value: modifier, type: Font.self)
        }
    }
    
    func foregroundColor() throws -> Color {
        return try commonTrait(name: "foregroundColor") { modifier -> Color? in
            guard let color = try? Inspector
                .attribute(path: "color|some", value: modifier, type: Color.self)
                else { return nil }
            return color
        }
    }
    
    func isStrikethrough() throws -> Bool {
        return try commonTrait(name: "strikethrough") { modifier -> Bool? in
            guard let child = try? Inspector.attribute(label: "anyTextModifier", value: modifier),
                Inspector.typeName(value: child) == "StrikethroughTextModifier",
                let active = try? Inspector
                    .attribute(path: "lineStyle|some|active", value: child, type: Bool.self)
                else { return nil }
            return active
        }
    }
    
    func strikethroughColor() throws -> Color? {
        return try commonTrait(name: "strikethrough") { modifier -> Color? in
            guard let child = try? Inspector.attribute(label: "anyTextModifier", value: modifier),
                Inspector.typeName(value: child) == "StrikethroughTextModifier",
                let color = try? Inspector
                    .attribute(path: "lineStyle|some|color", value: child, type: Color?.self)
                else { return nil }
            return color
        }
    }
    
    func isUnderline() throws -> Bool {
        return try commonTrait(name: "underline") { modifier -> Bool? in
            guard let child = try? Inspector.attribute(label: "anyTextModifier", value: modifier),
                Inspector.typeName(value: child) == "UnderlineTextModifier",
                let active = try? Inspector
                    .attribute(path: "lineStyle|some|active", value: child, type: Bool.self)
                else { return nil }
            return active
        }
    }
    
    func underlineColor() throws -> Color? {
        return try commonTrait(name: "underline") { modifier -> Color? in
            guard let child = try? Inspector.attribute(label: "anyTextModifier", value: modifier),
                Inspector.typeName(value: child) == "UnderlineTextModifier",
                let color = try? Inspector
                    .attribute(path: "lineStyle|some|color", value: child, type: Color?.self)
                else { return nil }
            return color
        }
    }
    
    func kerning() throws -> CGFloat {
        return try commonTrait(name: "kerning") { modifier -> CGFloat? in
            guard let kerning = try? Inspector
                .attribute(label: "kerning", value: modifier, type: CGFloat.self)
                else { return nil }
            return kerning
        }
    }
    
    func tracking() throws -> CGFloat {
        return try commonTrait(name: "tracking") { modifier -> CGFloat? in
            guard let kerning = try? Inspector
                .attribute(label: "tracking", value: modifier, type: CGFloat.self)
                else { return nil }
            return kerning
        }
    }
    
    func baselineOffset() throws -> CGFloat {
        return try commonTrait(name: "baselineOffset") { modifier -> CGFloat? in
            guard let kerning = try? Inspector
                .attribute(label: "baseline", value: modifier, type: CGFloat.self)
                else { return nil }
            return kerning
        }
    }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, *)
public extension ViewType.Text {
    struct Attributes {
        
        private struct Chunk {
            let string: String
            let modifiers: [Any]

            var length: Int {
                string.count
            }
        }
        private let chunks: [Chunk]
        
        private init(chunks: [Chunk]) {
            self.chunks = chunks
        }
        
        fileprivate init(string: String, modifiers: [Any]) {
            self.init(chunks: [Chunk(string: string, modifiers: modifiers)])
        }
        
        fileprivate static func + (lhs: Attributes, rhs: Attributes) -> Attributes {
            return Attributes(chunks: lhs.chunks + rhs.chunks)
        }
        
        private var chunkRanges: [Range<Int>] {
            return chunks.reduce([]) { (array, chunk) in
                let start = array.last?.upperBound ?? 0
                return array + [start ..< start + chunk.length]
            }
        }

        private var chunkStringRanges: [Range<String.Index>] {
            var totalString = ""
            return chunks.reduce([]) { (array, chunk) in
                let start = totalString.endIndex
                totalString += chunk.string
                let end = totalString.endIndex
                return array + [start ..< end]
            }
        }

        private var string: String {
            chunks.map { $0.string }.joined()
        }
        
        private func commonTrait<V>(name: String, _ trait: (Any) throws -> V?) throws -> V where V: Equatable {
            guard chunks.count > 0 else {
                throw InspectionError.textAttribute("Invalid text range")
            }
            let traits = try chunks.compactMap { chunk -> V? in
                for modifier in chunk.modifiers {
                    if let value = try trait(modifier) {
                        return value
                    }
                }
                return nil
            }
            guard let trait = traits.first else {
                throw InspectionError.modifierNotFound(parent: "Text", modifier: name)
            }
            guard traits.count == chunks.count else {
                throw InspectionError.textAttribute("Modifier '\(name)' is applied only to a subrange")
            }
            guard traits.allSatisfy({ $0 == trait }) else {
                throw InspectionError.textAttribute("Modifier '\(name)' has different values in subranges")
            }
            return trait
        }
    }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, *)
public extension Font {
    
    func size() throws -> CGFloat {
        do {
            return try Inspector
                .attribute(path: "provider|base|size", value: self, type: CGFloat.self)
        } catch {
            throw InspectionError.attributeNotFound(label: "size", type: "Font")
        }
    }
    
    func isFixedSize() -> Bool {
        guard let provider = try? Inspector.attribute(path: "provider|base", value: self),
              Inspector.typeName(value: provider) == "NamedProvider"
        else { return false }
        return (try? style()) == nil
    }
    
    func name() throws -> String {
        do {
            return try Inspector
                .attribute(path: "provider|base|name", value: self, type: String.self)
        } catch {
            throw InspectionError.attributeNotFound(label: "name", type: "Font")
        }
    }
    
    func weight() throws -> Font.Weight {
        do {
            return try Inspector
                .attribute(path: "provider|base|weight", value: self, type: Font.Weight.self)
        } catch {
            throw InspectionError.attributeNotFound(label: "weight", type: "Font")
        }
    }
    
    func design() throws -> Font.Design {
        do {
            return try Inspector
                .attribute(path: "provider|base|design", value: self, type: Font.Design.self)
        } catch {
            throw InspectionError.attributeNotFound(label: "design", type: "Font")
        }
    }
    
    func style() throws -> Font.TextStyle {
        do {
            return try (try? Inspector
                .attribute(path: "provider|base|style", value: self, type: Font.TextStyle.self))
                ?? (try Inspector
                .attribute(path: "provider|base|textStyle", value: self, type: Font.TextStyle.self))
        } catch {
            throw InspectionError.attributeNotFound(label: "style", type: "Font")
        }
    }
}
