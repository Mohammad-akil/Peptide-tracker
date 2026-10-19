"""Builds MedicineCatalog.json from medicines.txt.

Line format, grouped under `# Category` headings:
    Name;type;strength,strength;Brand,Brand
"""
import json
import re
import sys

TYPES = {"capsule", "tablet", "injection", "liquid", "drops", "inhaler", "powder", "cream", "other"}

# Servings that differ from the type's default: (text, units each time).
OVERRIDES = {
    "Creatine Monohydrate": ("5 g (1 scoop)", 1),
    "Creatine Gummies": ("3 gummies", 3),
    "Whey Protein": ("1 scoop (30 g)", 1),
    "Whey Isolate": ("1 scoop (25 g)", 1),
    "Casein Protein": ("1 scoop (33 g)", 1),
    "Plant Protein": ("1 scoop (30 g)", 1),
    "Collagen Peptides": ("1 scoop (10 g)", 1),
    "Collagen + Vitamin C": ("1 scoop (10 g)", 1),
    "Psyllium Husk": ("1 tsp (3.4 g)", 1),
    "Polyethylene Glycol 3350": ("17 g (1 capful)", 1),
    "Glycine": ("3 g", 1),
    "L-Glutamine": ("5 g", 1),
    "L-Citrulline": ("6 g", 1),
    "Citrulline Malate": ("8 g", 1),
    "Beta-Alanine": ("3.2 g", 1),
    "BCAA": ("1 scoop (7 g)", 1),
    "EAA (Essential Amino Acids)": ("1 scoop (10 g)", 1),
    "Pre-Workout": ("1 scoop", 1),
    "Electrolyte Powder": ("1 stick", 1),
    "Omega-3 Fish Oil": ("2 capsules", 2),
    "Krill Oil": ("2 capsules", 2),
    "Glucosamine / Chondroitin": ("2 tablets", 2),
    "Multivitamin Gummies": ("2 gummies", 2),
    "Elderberry Gummies": ("2 gummies", 2),
    "Glucose Tablets": ("4 tablets", 4),
    "Albuterol (Salbutamol)": ("1–2 puffs", 2),
    "Levalbuterol": ("1–2 puffs", 2),
    "Fluticasone / Vilanterol": ("1 puff", 1),
    "Fluticasone / Umeclidinium / Vilanterol": ("1 puff", 1),
    "Umeclidinium": ("1 puff", 1),
    "Umeclidinium / Vilanterol": ("1 puff", 1),
    "Fluticasone / Salmeterol": ("1 puff", 1),
    "Salmeterol": ("1 puff", 1),
    "Aclidinium": ("1 puff", 1),
    "Glycopyrronium / Indacaterol": ("1 puff", 1),
    "Zanamivir": ("2 puffs", 2),
    "Nitroglycerin Spray": ("1 spray", 1),
    "Paracetamol Liquid": ("5 ml", 5),
    "Ibuprofen Liquid": ("5 ml", 5),
    "Amoxicillin Liquid": ("5 ml", 5),
    "Lactulose": ("15 ml", 15),
    "Alginate Antacid": ("10 ml", 10),
    "Magnesium Hydroxide": ("15 ml", 15),
    "Bismuth Subsalicylate": ("30 ml", 30),
    "Dextromethorphan": ("10 ml", 10),
    "Codeine / Guaifenesin": ("10 ml", 10),
    "Cod Liver Oil": ("5 ml", 5),
    "MCT Oil": ("15 ml", 15),
    "Chlorhexidine Mouthwash": ("15 ml rinse", 15),
    "Nystatin": ("1 ml", 1),
    "Sodium Oxybate": ("As prescribed", 1),
    "Cannabidiol (Prescription)": ("As prescribed", 1),
    "Liposomal Vitamin C": ("5 ml", 5),
    "Liposomal Glutathione": ("5 ml", 5),
    "Ketone Ester": ("1 shot", 1),
    "Bacteriostatic Water": ("For reconstitution", 1),
    "Heparin": ("As prescribed", 1),
}

# The most commonly taken, ranked first among equally good matches
# ("crea" → Creatine Monohydrate before Creatine HCl).
POPULAR = {
    "Creatine Monohydrate", "Whey Protein", "Collagen Peptides", "Ashwagandha", "Magnesium Glycinate",
    "Vitamin D3", "Vitamin C", "Vitamin B12 (Cyanocobalamin)", "Omega-3 Fish Oil", "Multivitamin",
    "Zinc", "Iron (Ferrous Sulfate)", "Folic Acid", "Melatonin", "Probiotic", "Coenzyme Q10",
    "BPC-157", "TB-500", "Ipamorelin", "CJC-1295 / Ipamorelin", "NAD+", "GHK-Cu", "Retatrutide",
    "Semaglutide", "Tirzepatide", "Liraglutide", "Metformin", "Insulin Glargine",
    "Testosterone Cypionate", "Levothyroxine", "Finasteride", "Minoxidil Topical", "Tadalafil", "Sildenafil",
    "Atorvastatin", "Rosuvastatin", "Simvastatin", "Lisinopril", "Losartan", "Amlodipine",
    "Metoprolol Succinate", "Hydrochlorothiazide", "Aspirin Low Dose", "Apixaban", "Warfarin",
    "Paracetamol (Acetaminophen)", "Ibuprofen", "Gabapentin", "Prednisone", "Amoxicillin",
    "Sertraline", "Escitalopram", "Fluoxetine", "Omeprazole", "Pantoprazole", "Cetirizine",
    "Montelukast", "Albuterol (Salbutamol)",
}

APPLY = ("Shampoo", "Lotion", "Solution", "Lacquer", "Topical", "Enema", "Povidone", "Ciclopirox", "Podofilox")


def default_serving(name, type_, category):
    if type_ == "capsule":
        return "1 capsule", 1
    if type_ == "tablet":
        return "1 tablet", 1
    if type_ == "injection":
        return "1 injection", 1
    if type_ == "inhaler":
        return "2 puffs", 2
    if type_ == "cream":
        return "Apply a thin layer", 1
    if type_ == "powder":
        return ("1 scoop", 1) if category in ("Sports nutrition", "Supplements", "Vitamins & minerals") else ("1 sachet", 1)
    if type_ == "liquid":
        return ("Apply as directed", 1) if any(w in name for w in APPLY) else ("5 ml", 5)
    if type_ == "drops":
        if "Ear" in name:
            return "3 drops", 3
        if "Nasal" in name or "Spray" in name or category in ("Peptides", "Respiratory & allergy"):
            return "1 spray", 1
        if category == "Eyes & ears":
            return "1 drop", 1
        if "Oil" in name or category in ("Supplements", "Vitamins & minerals"):
            return "1 dropper", 1
        return "1 drop", 1
    # other
    if "Gummies" in name:
        return "2 gummies", 2
    if "Patch" in name or "Ring" in name:
        return "1 patch" if "Patch" in name else "1 ring", 1
    if "Gum" in name:
        return "1 piece", 1
    if "Gel" in name:
        return "1 gel", 1
    return "1", 1


def build(src):
    entries, seen, category, errors = [], set(), None, []
    for number, raw in enumerate(open(src, encoding="utf-8"), 1):
        line = raw.strip()
        if not line:
            continue
        if line.startswith("#"):
            category = line.lstrip("# ").strip()
            continue
        parts = line.split(";")
        if len(parts) != 4:
            errors.append(f"{number}: expected 4 fields, got {len(parts)}: {line}")
            continue
        name, type_, strengths, brands = (p.strip() for p in parts)
        if type_ not in TYPES:
            errors.append(f"{number}: unknown type {type_!r}")
            continue
        key = name.lower()
        if key in seen:
            errors.append(f"{number}: duplicate {name}")
            continue
        seen.add(key)
        serving, per_dose = OVERRIDES.get(name) or default_serving(name, type_, category)
        entries.append({
            "name": name,
            "type": type_,
            "category": category,
            "strengths": [s.strip() for s in strengths.split(",") if s.strip()],
            "brands": [b.strip() for b in brands.split(",") if b.strip()],
            "serving": serving,
            "perDose": per_dose,
            "popular": name in POPULAR,
        })
    unused = (set(OVERRIDES) | POPULAR) - {e["name"] for e in entries}
    errors += [f"override or popular entry for unknown medicine: {n}" for n in sorted(unused)]
    if errors:
        sys.exit("\n".join(errors))
    # A–Z, ignoring case and leading digits/punctuation order quirks.
    entries.sort(key=lambda e: re.sub(r"[^a-z0-9]", "", e["name"].lower()))
    return entries


if __name__ == "__main__":
    src, out = sys.argv[1], sys.argv[2]
    entries = build(src)
    with open(out, "w", encoding="utf-8") as f:
        f.write("[\n")
        f.write(",\n".join("  " + json.dumps(e, ensure_ascii=False) for e in entries))
        f.write("\n]\n")
    print(f"{len(entries)} medicines → {out}")
