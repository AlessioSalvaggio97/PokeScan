#!/usr/bin/env python3
"""
PokéScan - TCGdex Catalog & Symbol Downloader
Questo script scarica il catalogo completo dei set Pokémon in Italiano e Inglese da TCGdex,
mappa le sigle ufficiali stampate sulle carte (es. SVI, PAL, OBF, SCR) e i denominatori numerici (es. /149, /147),
e scarica tutti i simboli di espansione PNG per il riconoscimento e l'esportazione Excel.
"""

import os
import sys
import json
import time
import urllib.request
import urllib.error
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
SYMBOLS_DIR = BASE_DIR / "symbols"
SYMBOLS_DIR.mkdir(parents=True, exist_ok=True)

USER_AGENT = "PokeScanApp/1.0 (iOS/SwiftUI bulk scanner)"

# Mappatura delle sigle ufficiali a 3/4 lettere stampate sulle carte recenti (SV, SWSH, etc.)
KNOWN_ABBREVIATIONS = {
    # Scarlatto & Violetto (SV)
    "SVI": "sv01", "SV1": "sv01",
    "PAL": "sv02", "SV2": "sv02",
    "OBF": "sv03", "SV3": "sv03",
    "MEW": "sv03.5", "151": "sv03.5",
    "PAR": "sv04", "SV4": "sv04",
    "PAF": "sv04.5",
    "TEF": "sv05", "SV5": "sv05",
    "TWM": "sv06", "SV6": "sv06",
    "SFA": "sv06.5",
    "SCR": "sv07", "SV7": "sv07",
    "SSP": "sv08", "SV8": "sv08",
    "PRE": "sv08.5",
    "SVP": "svp",
    
    # Spada & Scudo (SWSH)
    "SSH": "swsh1", "SWSH1": "swsh1",
    "RCL": "swsh2", "SWSH2": "swsh2",
    "DAA": "swsh3", "SWSH3": "swsh3",
    "CPA": "swsh3.5",
    "VIV": "swsh4", "SWSH4": "swsh4",
    "SHF": "swsh4.5",
    "BST": "swsh5", "SWSH5": "swsh5",
    "CRE": "swsh6", "SWSH6": "swsh6",
    "EVS": "swsh7", "SWSH7": "swsh7",
    "CEL": "swsh7.5",
    "FST": "swsh8", "SWSH8": "swsh8",
    "BRS": "swsh9", "SWSH9": "swsh9",
    "ASR": "swsh10", "SWSH10": "swsh10",
    "PGO": "pgo",
    "LOR": "swsh11", "SWSH11": "swsh11",
    "SIT": "swsh12", "SWSH12": "swsh12",
    "CRZ": "swsh12.5", "SWSH12.5": "swsh12.5",
    "SWSHP": "swshp",

    # Sole & Luna (SM)
    "SUM": "sm1", "SM1": "sm1",
    "GRI": "sm2", "SM2": "sm2",
    "BUS": "sm3", "SM3": "sm3",
    "SLG": "sm3.5",
    "CIN": "sm4", "SM4": "sm4",
    "UPR": "sm5", "SM5": "sm5",
    "FLI": "sm6", "SM6": "sm6",
    "CES": "sm7", "SM7": "sm7",
    "DRM": "sm7.5",
    "LOT": "sm8", "SM8": "sm8",
    "TEU": "sm9", "SM9": "sm9",
    "UNB": "sm10", "SM10": "sm10",
    "UNM": "sm11", "SM11": "sm11",
    "HIF": "sm11.5",
    "CEC": "sm12", "SM12": "sm12",
    "SMP": "smp"
}

def fetch_json(url: str):
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        print(f"  [!] HTTP {e.code} per {url}")
        return None
    except Exception as e:
        print(f"  [!] Errore per {url}: {e}")
        return None

def download_file(url: str, dest_path: Path):
    if dest_path.exists() and dest_path.stat().st_size > 0:
        return True
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            content = resp.read()
            with open(dest_path, "wb") as f:
                f.write(content)
            return True
    except Exception as e:
        return False

def main():
    print("=" * 60)
    print(" PokéScan - Download e Indicizzazione Catalogo TCGdex")
    print("=" * 60)

    print("\n[1/3] Scaricamento elenco set in Italiano e Inglese...")
    it_sets = fetch_json("https://api.tcgdex.net/v2/it/sets") or []
    en_sets = fetch_json("https://api.tcgdex.net/v2/en/sets") or []

    print(f"  -> Set Italiani trovati: {len(it_sets)}")
    print(f"  -> Set Inglesi trovati: {len(en_sets)}")

    en_dict = {s["id"]: s for s in en_sets}
    catalog = {}
    total_cards_index = {} # Denominatore (es. 149 -> ["sm1"])
    abbr_index = dict(KNOWN_ABBREVIATIONS)

    print("\n[2/3] Dettaglio set, simboli e indici...")
    count = 0
    symbols_downloaded = 0

    for s_it in it_sets:
        set_id = s_it["id"]
        s_en = en_dict.get(set_id, {})
        
        name_it = s_it.get("name", "")
        name_en = s_en.get("name", name_it)
        
        card_count = s_it.get("cardCount", {})
        official_count = card_count.get("official")
        total_count = card_count.get("total")
        
        symbol_url = s_it.get("symbol")
        logo_url = s_it.get("logo")
        
        # Download simbolo PNG se disponibile
        local_symbol_file = None
        normalized_url = None
        if symbol_url:
            dest = SYMBOLS_DIR / f"{set_id}.png"
            # Sostituiamo /univ/ con /en/ o /it/ perché univ genera 400 su S3
            normalized_url = symbol_url.replace("/univ/", "/en/")
            if not normalized_url.endswith(".png"):
                normalized_url += ".png"
            
            if download_file(normalized_url, dest):
                local_symbol_file = f"symbols/{set_id}.png"
                symbols_downloaded += 1
            else:
                # Prova fallback con it
                fallback_url = symbol_url.replace("/univ/", "/it/")
                if not fallback_url.endswith(".png"):
                    fallback_url += ".png"
                if download_file(fallback_url, dest):
                    local_symbol_file = f"symbols/{set_id}.png"
                    symbols_downloaded += 1

        final_symbol_url = normalized_url if symbol_url else None
        final_logo_url = f"{logo_url}.png" if logo_url and not logo_url.endswith(".png") else logo_url

        set_entry = {
            "id": set_id,
            "name_it": name_it,
            "name_en": name_en,
            "official_count": official_count,
            "total_count": total_count,
            "symbol_url": final_symbol_url,
            "local_symbol": local_symbol_file,
            "logo_url": final_logo_url
        }
        catalog[set_id] = set_entry

        # Indice per totale carte (Denominatore frazione es. /149, /147)
        if official_count:
            key = str(official_count)
            total_cards_index.setdefault(key, []).append(set_id)
        if total_count and total_count != official_count:
            key = str(total_count)
            total_cards_index.setdefault(key, []).append(set_id)

        # Mappatura ID in maiuscolo come abbreviazione
        abbr_index[set_id.upper()] = set_id
        count += 1

    print(f"  -> Set elaborati: {count}")
    print(f"  -> Simboli scaricati in 'symbols/': {symbols_downloaded}")

    print("\n[3/3] Salvataggio indici e catalogo JSON...")
    output_data = {
        "sets": catalog,
        "abbreviations": abbr_index,
        "denominator_index": total_cards_index,
        "generated_at": time.strftime("%Y-%m-%d %H:%M:%S")
    }

    output_file = BASE_DIR / "sets_catalog.json"
    with open(output_file, "w", encoding="utf-8") as f:
        json.dump(output_data, f, indent=2, ensure_ascii=False)

    print(f"  -> Catalogo salvato con successo in: {output_file.name} ({output_file.stat().st_size // 1024} KB)")
    print("\nCompletato con successo!")

if __name__ == "__main__":
    main()
