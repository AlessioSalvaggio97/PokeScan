import Foundation
import UIKit

/// Generatore nativo di file Excel (.xlsx) con immagini incorporate (OpenXML) senza dipendenze esterne
public class ExcelExporter {
    public static let shared = ExcelExporter()
    
    private init() {}
    
    /// Esporta una collezione in un file .xlsx temporaneo e restituisce l'URL del file
    public func exportCollectionToXLSX(_ collection: CardCollection) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let safeName = collection.name.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "\\", with: "_")
        let fileName = "\(safeName)_\(Date().formatted(.iso8601.year().month().day())).xlsx"
        let outputURL = tempDir.appendingPathComponent(fileName)
        
        var zip = MiniZipArchive()
        
        // 1. [Content_Types].xml
        let contentTypes = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Default Extension="xml" ContentType="application/xml"/>
          <Default Extension="png" ContentType="image/png"/>
          <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
          <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
          <Override PartName="/xl/drawings/drawing1.xml" ContentType="application/vnd.openxmlformats-officedocument.drawing+xml"/>
        </Types>
        """
        zip.addFile(path: "[Content_Types].xml", data: Data(contentTypes.utf8))
        
        // 2. _rels/.rels
        let rootRels = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
        </Relationships>
        """
        zip.addFile(path: "_rels/.rels", data: Data(rootRels.utf8))
        
        // 3. xl/_rels/workbook.xml.rels
        let workbookRels = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
        </Relationships>
        """
        zip.addFile(path: "xl/_rels/workbook.xml.rels", data: Data(workbookRels.utf8))
        
        // 4. xl/workbook.xml
        let workbook = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
          <sheets>
            <sheet name="\(escapeXML(collection.name))" sheetId="1" r:id="rId1"/>
          </sheets>
        </workbook>
        """
        zip.addFile(path: "xl/workbook.xml", data: Data(workbook.utf8))
        
        // Costruiamo le righe di dati, i drawing e le immagini
        var sheetDataRows = ""
        // Header
        sheetDataRows += """
        <row r="1" ht="26" customHeight="1">
          <c r="A1" t="inlineStr"><is><t>Miniatura</t></is></c>
          <c r="B1" t="inlineStr"><is><t>Nome Carta</t></is></c>
          <c r="C1" t="inlineStr"><is><t>Simbolo Set</t></is></c>
          <c r="D1" t="inlineStr"><is><t>Espansione</t></is></c>
          <c r="E1" t="inlineStr"><is><t>Numero</t></is></c>
          <c r="F1" t="inlineStr"><is><t>Rarità</t></is></c>
          <c r="G1" t="inlineStr"><is><t>Versione</t></is></c>
          <c r="H1" t="inlineStr"><is><t>Lingua</t></is></c>
          <c r="I1" t="inlineStr"><is><t>Data Scansione</t></is></c>
        </row>
        """
        
        var drawingXML = ""
        var drawingRels = ""
        var mediaCounter = 1
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM/yyyy HH:mm"
        
        for (index, card) in collection.cards.enumerated() {
            let rowNumber = index + 2
            let scanDateStr = dateFormatter.string(from: card.scannedAt)
            
            sheetDataRows += """
            <row r="\(rowNumber)" ht="65" customHeight="1">
              <c r="A\(rowNumber)"/>
              <c r="B\(rowNumber)" t="inlineStr"><is><t>\(escapeXML(card.name))</t></is></c>
              <c r="C\(rowNumber)"/>
              <c r="D\(rowNumber)" t="inlineStr"><is><t>\(escapeXML(card.setName))</t></is></c>
              <c r="E\(rowNumber)" t="inlineStr"><is><t>\(escapeXML(card.formattedNumber))</t></is></c>
              <c r="F\(rowNumber)" t="inlineStr"><is><t>\(escapeXML(card.rarity))</t></is></c>
              <c r="G\(rowNumber)" t="inlineStr"><is><t>\(escapeXML(card.variant.rawValue))</t></is></c>
              <c r="H\(rowNumber)" t="inlineStr"><is><t>\(escapeXML(card.language))</t></is></c>
              <c r="I\(rowNumber)" t="inlineStr"><is><t>\(escapeXML(scanDateStr))</t></is></c>
            </row>
            """
            
            // Immagine Miniatura Carta (Colonna A, indice 0)
            if let cardImgData = card.thumbnailData {
                let imgId = "rId\(mediaCounter)"
                let imgName = "card_\(card.id.uuidString).png"
                zip.addFile(path: "xl/media/\(imgName)", data: cardImgData)
                drawingRels += """
                <Relationship Id="\(imgId)" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="../media/\(imgName)"/>
                """
                
                // OneCellAnchor per la miniatura: 430000 x 600000 EMUs (~45x63pt)
                drawingXML += """
                <xdr:oneCellAnchor>
                  <xdr:from>
                    <xdr:col>0</xdr:col>
                    <xdr:colOff>35000</xdr:colOff>
                    <xdr:row>\(index + 1)</xdr:row>
                    <xdr:rowOff>25000</xdr:rowOff>
                  </xdr:from>
                  <xdr:ext cx="430000" cy="600000"/>
                  <xdr:pic>
                    <xdr:nvPicPr>
                      <xdr:cNvPr id="\(mediaCounter + 10)" name="Thumb \(index + 1)"/>
                      <xdr:cNvPicPr><a:picLocks noChangeAspect="1"/></xdr:cNvPicPr>
                    </xdr:nvPicPr>
                    <xdr:blipFill>
                      <a:blip xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" r:embed="\(imgId)"/>
                      <a:stretch><a:fillRect/></a:stretch>
                    </xdr:blipFill>
                    <xdr:spPr>
                      <a:xfrm><a:off x="0" y="0"/><a:ext cx="430000" cy="600000"/></a:xfrm>
                      <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
                    </xdr:spPr>
                  </xdr:pic>
                  <xdr:clientData/>
                </xdr:oneCellAnchor>
                """
                mediaCounter += 1
            }
            
            // Simbolo Set (Colonna C, indice 2)
            let symbolData = card.symbolData ?? SetCatalog.shared.getSymbolData(for: card.setId)
            if let symData = symbolData {
                let symId = "rId\(mediaCounter)"
                let symName = "sym_\(card.setId).png"
                // Evita di riscrivere se già aggiunto
                if zip.getFile(path: "xl/media/\(symName)") == nil {
                    zip.addFile(path: "xl/media/\(symName)", data: symData)
                }
                drawingRels += """
                <Relationship Id="\(symId)" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="../media/\(symName)"/>
                """
                
                // OneCellAnchor per il simbolo: 300000 x 300000 EMUs (~30x30pt)
                drawingXML += """
                <xdr:oneCellAnchor>
                  <xdr:from>
                    <xdr:col>2</xdr:col>
                    <xdr:colOff>40000</xdr:colOff>
                    <xdr:row>\(index + 1)</xdr:row>
                    <xdr:rowOff>120000</xdr:rowOff>
                  </xdr:from>
                  <xdr:ext cx="300000" cy="300000"/>
                  <xdr:pic>
                    <xdr:nvPicPr>
                      <xdr:cNvPr id="\(mediaCounter + 10)" name="Sym \(index + 1)"/>
                      <xdr:cNvPicPr><a:picLocks noChangeAspect="1"/></xdr:cNvPicPr>
                    </xdr:nvPicPr>
                    <xdr:blipFill>
                      <a:blip xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" r:embed="\(symId)"/>
                      <a:stretch><a:fillRect/></a:stretch>
                    </xdr:blipFill>
                    <xdr:spPr>
                      <a:xfrm><a:off x="0" y="0"/><a:ext cx="300000" cy="300000"/></a:xfrm>
                      <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
                    </xdr:spPr>
                  </xdr:pic>
                  <xdr:clientData/>
                </xdr:oneCellAnchor>
                """
                mediaCounter += 1
            }
        }
        
        // 5. xl/worksheets/sheet1.xml
        let worksheet = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
          <cols>
            <col min="1" max="1" width="12" customWidth="1"/>
            <col min="2" max="2" width="25" customWidth="1"/>
            <col min="3" max="3" width="11" customWidth="1"/>
            <col min="4" max="4" width="25" customWidth="1"/>
            <col min="5" max="5" width="14" customWidth="1"/>
            <col min="6" max="6" width="16" customWidth="1"/>
            <col min="7" max="7" width="14" customWidth="1"/>
            <col min="8" max="8" width="10" customWidth="1"/>
            <col min="9" max="9" width="18" customWidth="1"/>
          </cols>
          <sheetData>
            \(sheetDataRows)
          </sheetData>
          <drawing r:id="rId1"/>
        </worksheet>
        """
        zip.addFile(path: "xl/worksheets/sheet1.xml", data: Data(worksheet.utf8))
        
        // 6. xl/worksheets/_rels/sheet1.xml.rels
        let sheetRels = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/drawing" Target="../drawings/drawing1.xml"/>
        </Relationships>
        """
        zip.addFile(path: "xl/worksheets/_rels/sheet1.xml.rels", data: Data(sheetRels.utf8))
        
        // 7. xl/drawings/drawing1.xml
        let drawingContainer = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <xdr:wsDr xmlns:xdr="http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
          \(drawingXML)
        </xdr:wsDr>
        """
        zip.addFile(path: "xl/drawings/drawing1.xml", data: Data(drawingContainer.utf8))
        
        // 8. xl/drawings/_rels/drawing1.xml.rels
        let fullDrawingRels = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          \(drawingRels)
        </Relationships>
        """
        zip.addFile(path: "xl/drawings/_rels/drawing1.xml.rels", data: Data(fullDrawingRels.utf8))
        
        // Scrittura file .xlsx compresso
        do {
            let zipData = zip.generateZipData()
            try zipData.write(to: outputURL, options: .atomic)
            print("[ExcelExporter] File esportato con successo in: \(outputURL.path)")
            return outputURL
        } catch {
            print("[ExcelExporter] Errore scrittura file .xlsx: \(error)")
            return nil
        }
    }
    
    private func escapeXML(_ str: String) -> String {
        return str
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}

// MARK: - MiniZipArchive (Implementazione compatta e pura di ZIP standard per iOS)
public struct MiniZipArchive {
    private struct ZipEntry {
        let path: String
        let data: Data
        let crc: UInt32
    }
    
    private var entries: [ZipEntry] = []
    
    public init() {}
    
    public mutating func addFile(path: String, data: Data) {
        let crc = computeCRC32(data: data)
        entries.append(ZipEntry(path: path, data: data, crc: crc))
    }
    
    public func getFile(path: String) -> Data? {
        return entries.first(where: { $0.path == path })?.data
    }
    
    public func generateZipData() -> Data {
        var result = Data()
        var centralDirectory = Data()
        var offsets: [UInt32] = []
        
        for entry in entries {
            let offset = UInt32(result.count)
            offsets.append(offset)
            
            let pathData = Data(entry.path.utf8)
            let pathLen = UInt16(pathData.count)
            let size = UInt32(entry.data.count)
            
            // Local file header (30 bytes)
            var localHeader = Data()
            localHeader.append(contentsOf: [0x50, 0x4b, 0x03, 0x04]) // PK\x03\x04
            localHeader.append(contentsOf: [20, 0]) // version needed
            localHeader.append(contentsOf: [0, 0])  // general flags
            localHeader.append(contentsOf: [0, 0])  // compression = STORE (0)
            localHeader.append(contentsOf: [0, 0, 0, 0]) // mod time/date
            localHeader.append(contentsOf: withUnsafeBytes(of: entry.crc.littleEndian) { Array($0) })
            localHeader.append(contentsOf: withUnsafeBytes(of: size.littleEndian) { Array($0) })
            localHeader.append(contentsOf: withUnsafeBytes(of: size.littleEndian) { Array($0) })
            localHeader.append(contentsOf: withUnsafeBytes(of: pathLen.littleEndian) { Array($0) })
            localHeader.append(contentsOf: [0, 0]) // extra field len
            localHeader.append(pathData)
            
            result.append(localHeader)
            result.append(entry.data)
            
            // Central directory entry (46 bytes + path)
            var cd = Data()
            cd.append(contentsOf: [0x50, 0x4b, 0x01, 0x02]) // PK\x01\x02
            cd.append(contentsOf: [20, 0]) // version made by
            cd.append(contentsOf: [20, 0]) // version needed
            cd.append(contentsOf: [0, 0])  // flags
            cd.append(contentsOf: [0, 0])  // STORE
            cd.append(contentsOf: [0, 0, 0, 0]) // time/date
            cd.append(contentsOf: withUnsafeBytes(of: entry.crc.littleEndian) { Array($0) })
            cd.append(contentsOf: withUnsafeBytes(of: size.littleEndian) { Array($0) })
            cd.append(contentsOf: withUnsafeBytes(of: size.littleEndian) { Array($0) })
            cd.append(contentsOf: withUnsafeBytes(of: pathLen.littleEndian) { Array($0) })
            cd.append(contentsOf: [0, 0, 0, 0, 0, 0]) // extra len, comment len, disk nr
            cd.append(contentsOf: [0, 0, 0, 0]) // internal/external attrs
            cd.append(contentsOf: withUnsafeBytes(of: offset.littleEndian) { Array($0) })
            cd.append(pathData)
            
            centralDirectory.append(cd)
        }
        
        let cdOffset = UInt32(result.count)
        let cdSize = UInt32(centralDirectory.count)
        result.append(centralDirectory)
        
        // End of central directory record (22 bytes)
        var eocd = Data()
        eocd.append(contentsOf: [0x50, 0x4b, 0x05, 0x06]) // PK\x05\x06
        eocd.append(contentsOf: [0, 0, 0, 0]) // disk nr
        let entryCount = UInt16(entries.count)
        eocd.append(contentsOf: withUnsafeBytes(of: entryCount.littleEndian) { Array($0) })
        eocd.append(contentsOf: withUnsafeBytes(of: entryCount.littleEndian) { Array($0) })
        eocd.append(contentsOf: withUnsafeBytes(of: cdSize.littleEndian) { Array($0) })
        eocd.append(contentsOf: withUnsafeBytes(of: cdOffset.littleEndian) { Array($0) })
        eocd.append(contentsOf: [0, 0]) // comment length
        
        result.append(eocd)
        return result
    }
    
    private func computeCRC32(data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in data {
            let lookupIndex = UInt8((crc ^ UInt32(byte)) & 0xFF)
            crc = (crc >> 8) ^ crc32Table[Int(lookupIndex)]
        }
        return crc ^ 0xFFFFFFFF
    }
}

// Tabella standard CRC-32 (IEEE 802.3)
private let crc32Table: [UInt32] = {
    var table = [UInt32](repeating: 0, count: 256)
    for i in 0..<256 {
        var c = UInt32(i)
        for _ in 0..<8 {
            c = (c & 1 != 0) ? (0xEDB88320 ^ (c >> 1)) : (c >> 1)
        }
        table[i] = c
    }
    return table
}()
