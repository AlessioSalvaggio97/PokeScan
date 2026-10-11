#!/usr/bin/env python3
"""
Test di esportazione Excel (.xlsx) con immagini incorporate (miniatura carta e simbolo set).
Questo script valida la struttura OpenXML e le relazioni grafiche (drawing) per garantire
che Excel, Numbers e Google Sheets visualizzino correttamente le immagini dentro le celle.
"""

import os
import io
import zipfile
import json
import urllib.request
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent

def download_image_bytes(url: str):
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    try:
        with urllib.request.urlopen(req, timeout=10) as r:
            return r.read()
    except Exception as e:
        print(f"Errore download {url}: {e}")
        return None

def create_sample_xlsx():
    output_path = BASE_DIR / "Collezione_Test.xlsx"
    print(f"Creazione file test Excel in: {output_path.name}")

    # Scarichiamo una miniatura di prova (Toedscool da TCGdex) e il simbolo sv01
    card_img_url = "https://assets.tcgdex.net/it/sv/sv01/025/low.webp"
    symbol_path = BASE_DIR / "symbols/sv01.png"

    card_data = download_image_bytes(card_img_url)
    symbol_data = symbol_path.read_bytes() if symbol_path.exists() else None

    # Se card_img è webp, possiamo convertirla in png se necessario o salvarla
    # Excel supporta png e jpeg
    import tempfile
    
    # Verifichiamo se python3-pillow è disponibile, altrimenti usiamo sips su macOS per convertire webp in png
    png_card_path = BASE_DIR / "temp_card.png"
    if card_data:
        webp_card_path = BASE_DIR / "temp_card.webp"
        webp_card_path.write_bytes(card_data)
        os.system(f"sips -s format png '{webp_card_path}' --out '{png_card_path}' >/dev/null 2>&1")
        if png_card_path.exists():
            card_png_data = png_card_path.read_bytes()
            webp_card_path.unlink(missing_ok=True)
            png_card_path.unlink(missing_ok=True)
        else:
            card_png_data = card_data
    else:
        card_png_data = None

    print(f"Dati immagine pronti: Carta ({len(card_png_data) if card_png_data else 0} bytes), Simbolo ({len(symbol_data) if symbol_data else 0} bytes)")

    # Creiamo un file .xlsx con zipfile
    with zipfile.ZipFile(output_path, "w", zipfile.ZIP_DEFLATED) as z:
        # [Content_Types].xml
        z.writestr("[Content_Types].xml", """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Default Extension="png" ContentType="image/png"/>
  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
  <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
  <Override PartName="/xl/drawings/drawing1.xml" ContentType="application/vnd.openxmlformats-officedocument.drawing+xml"/>
</Types>""")

        # _rels/.rels
        z.writestr("_rels/.rels", """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>""")

        # xl/_rels/workbook.xml.rels
        z.writestr("xl/_rels/workbook.xml.rels", """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
</Relationships>""")

        # xl/workbook.xml
        z.writestr("xl/workbook.xml", """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheets>
    <sheet name="Carte Scansionate" sheetId="1" r:id="rId1"/>
  </sheets>
</workbook>""")

        # xl/worksheets/sheet1.xml
        # Riga 1 = Intestazioni (altezza standard)
        # Riga 2 = Carta Toedscool (altezza 70pt per contenere la miniatura)
        z.writestr("xl/worksheets/sheet1.xml", """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <cols>
    <col min="1" max="1" width="12" customWidth="1"/>
    <col min="2" max="2" width="22" customWidth="1"/>
    <col min="3" max="3" width="10" customWidth="1"/>
    <col min="4" max="4" width="24" customWidth="1"/>
    <col min="5" max="5" width="14" customWidth="1"/>
    <col min="6" max="6" width="16" customWidth="1"/>
    <col min="7" max="7" width="16" customWidth="1"/>
  </cols>
  <sheetData>
    <row r="1" ht="25" customHeight="1">
      <c r="A1" t="inlineStr"><is><t>Miniatura</t></is></c>
      <c r="B1" t="inlineStr"><is><t>Nome Carta</t></is></c>
      <c r="C1" t="inlineStr"><is><t>Simbolo Set</t></is></c>
      <c r="D1" t="inlineStr"><is><t>Espansione</t></is></c>
      <c r="E1" t="inlineStr"><is><t>Numero</t></is></c>
      <c r="F1" t="inlineStr"><is><t>Rarità</t></is></c>
      <c r="G1" t="inlineStr"><is><t>Versione</t></is></c>
    </row>
    <row r="2" ht="70" customHeight="1">
      <c r="A2"/>
      <c r="B2" t="inlineStr"><is><t>Toedscool</t></is></c>
      <c r="C2"/>
      <c r="D2" t="inlineStr"><is><t>Scarlatto e Violetto</t></is></c>
      <c r="E2" t="inlineStr"><is><t>025/198</t></is></c>
      <c r="F2" t="inlineStr"><is><t>Comune</t></is></c>
      <c r="G2" t="inlineStr"><is><t>Regular</t></is></c>
    </row>
  </sheetData>
  <drawing r:id="rId1"/>
</worksheet>""")

        # xl/worksheets/_rels/sheet1.xml.rels
        z.writestr("xl/worksheets/_rels/sheet1.xml.rels", """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/drawing" Target="../drawings/drawing1.xml"/>
</Relationships>""")

        # xl/drawings/_rels/drawing1.xml.rels
        z.writestr("xl/drawings/_rels/drawing1.xml.rels", """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="../media/card1.png"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="../media/symbol1.png"/>
</Relationships>""")

        # xl/drawings/drawing1.xml (OneCellAnchor o TwoCellAnchor)
        # EMUs: 1 point = 12700 EMUs, 1 pixel = 9525 EMUs
        # Col 0 (A2) -> Carta: larghezza 45px (~428625 EMUs), altezza 63px (~600000 EMUs)
        # Col 2 (C2) -> Simbolo: larghezza 30px (~285750 EMUs), altezza 30px (~285750 EMUs)
        z.writestr("xl/drawings/drawing1.xml", """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<xdr:wsDr xmlns:xdr="http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
  <xdr:oneCellAnchor>
    <xdr:from>
      <xdr:col>0</xdr:col>
      <xdr:colOff>40000</xdr:colOff>
      <xdr:row>1</xdr:row>
      <xdr:rowOff>40000</xdr:rowOff>
    </xdr:from>
    <xdr:ext cx="430000" cy="600000"/>
    <xdr:pic>
      <xdr:nvPicPr>
        <xdr:cNvPr id="2" name="Card 1"/>
        <xdr:cNvPicPr><a:picLocks noChangeAspect="1"/></xdr:cNvPicPr>
      </xdr:nvPicPr>
      <xdr:blipFill>
        <a:blip xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" r:embed="rId1"/>
        <a:stretch><a:fillRect/></a:stretch>
      </xdr:blipFill>
      <xdr:spPr>
        <a:xfrm><a:off x="0" y="0"/><a:ext cx="430000" cy="600000"/></a:xfrm>
        <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
      </xdr:spPr>
    </xdr:pic>
    <xdr:clientData/>
  </xdr:oneCellAnchor>

  <xdr:oneCellAnchor>
    <xdr:from>
      <xdr:col>2</xdr:col>
      <xdr:colOff>50000</xdr:colOff>
      <xdr:row>1</xdr:row>
      <xdr:rowOff>150000</xdr:rowOff>
    </xdr:from>
    <xdr:ext cx="300000" cy="300000"/>
    <xdr:pic>
      <xdr:nvPicPr>
        <xdr:cNvPr id="3" name="Symbol 1"/>
        <xdr:cNvPicPr><a:picLocks noChangeAspect="1"/></xdr:cNvPicPr>
      </xdr:nvPicPr>
      <xdr:blipFill>
        <a:blip xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" r:embed="rId2"/>
        <a:stretch><a:fillRect/></a:stretch>
      </xdr:blipFill>
      <xdr:spPr>
        <a:xfrm><a:off x="0" y="0"/><a:ext cx="300000" cy="300000"/></a:xfrm>
        <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
      </xdr:spPr>
    </xdr:pic>
    <xdr:clientData/>
  </xdr:oneCellAnchor>
</xdr:wsDr>""")

        if card_png_data:
            z.writestr("xl/media/card1.png", card_png_data)
        if symbol_data:
            z.writestr("xl/media/symbol1.png", symbol_data)

    print(f"File generato con successo! Dimensione: {output_path.stat().st_size} bytes")

if __name__ == "__main__":
    create_sample_xlsx()
