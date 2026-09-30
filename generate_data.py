"""
Build a synthetic transplant registry database (registry.db).

All data are fake and randomly generated. A small number of data-quality
problems are inserted on purpose, so that the checks in
queries/04_data_quality.sql and dq_report.py have something to find.

Uses only the Python standard library.
Usage:  python generate_data.py
"""

import random
import sqlite3
from datetime import date, timedelta
from pathlib import Path

SEED = 42
N_PATIENTS = 600
DATA_CUTOFF = date(2025, 6, 30)
DB_PATH = Path(__file__).parent / "registry.db"
SCHEMA_PATH = Path(__file__).parent / "schema.sql"

random.seed(SEED)

CENTERS = [
    ("Hospital Clinic Barcelona", "Spain"), ("Hospital La Fe Valencia", "Spain"),
    ("Karolinska University Hospital", "Sweden"), ("Charite Berlin", "Germany"),
    ("Hopital Saint-Louis Paris", "France"), ("Leiden University Medical Center", "Netherlands"),
    ("Papanikolaou Hospital Thessaloniki", "Greece"), ("Ospedale San Raffaele Milan", "Italy"),
    ("Rigshospitalet Copenhagen", "Denmark"), ("King's College Hospital London", "United Kingdom"),
]

# (ICD-10 code, disease name, sampling weight, probability of autologous transplant)
DISEASES = [
    ("C92.0", "Acute myeloid leukaemia", 30, 0.05),
    ("C91.0", "Acute lymphoblastic leukaemia", 12, 0.02),
    ("D46", "Myelodysplastic syndrome", 10, 0.02),
    ("C92.1", "Chronic myeloid leukaemia", 4, 0.02),
    ("C90.0", "Multiple myeloma", 25, 0.95),
    ("C83.3", "Diffuse large B-cell lymphoma", 12, 0.85),
    ("C81", "Hodgkin lymphoma", 7, 0.80),
]

ALLO_TYPES = ["matched_related", "matched_unrelated", "haploidentical"]


def rand_date(start: date, end: date) -> date:
    """Random date between start and end (inclusive)."""
    return start + timedelta(days=random.randint(0, (end - start).days))


def build():
    if DB_PATH.exists():
        DB_PATH.unlink()
    con = sqlite3.connect(DB_PATH)
    con.executescript(SCHEMA_PATH.read_text())
    cur = con.cursor()

    cur.executemany("INSERT INTO centers (center_id, center_name, country) VALUES (?, ?, ?)",
                    [(i + 1, n, c) for i, (n, c) in enumerate(CENTERS)])

    patients, diagnoses, donors, transplants, followups = [], [], [], [], []
    donor_id = transplant_id = followup_id = diagnosis_id = 0
    weights = [d[2] for d in DISEASES]

    for pid in range(1, N_PATIENTS + 1):
        center = random.randint(1, len(CENTERS))
        sex = random.choice(["M", "F"])
        age_at_dx = min(72, max(2, int(random.gauss(52, 14))))
        dx_date = rand_date(date(2015, 1, 1), date(2024, 6, 30))
        birth = dx_date - timedelta(days=age_at_dx * 365 + random.randint(0, 364))
        reg_date = dx_date + timedelta(days=random.randint(0, 60))
        patients.append([pid, center, sex, birth.isoformat(), reg_date.isoformat()])

        code, name, _, p_auto = random.choices(DISEASES, weights=weights)[0]
        diagnosis_id += 1
        diagnoses.append([diagnosis_id, pid, code, name, dx_date.isoformat()])

        # About 92% of registered patients receive a transplant
        if random.random() > 0.92:
            continue

        tx_date = dx_date + timedelta(days=random.randint(60, 400))
        if tx_date > DATA_CUTOFF:
            continue

        donor_id += 1
        if random.random() < p_auto:
            dtype, dsex, dbirth = "autologous", sex, birth.isoformat()
            cond = "myeloablative"
        else:
            dtype = random.choice(ALLO_TYPES)
            dsex = random.choice(["M", "F"])
            dbirth = rand_date(date(1950, 1, 1), date(2004, 12, 31)).isoformat()
            cond = random.choice(["myeloablative", "reduced_intensity"])
        donors.append([donor_id, dtype, dsex, dbirth])

        source = random.choices(["peripheral_blood", "bone_marrow", "cord_blood"], weights=[80, 15, 5])[0]
        transplant_id += 1
        transplants.append([transplant_id, pid, donor_id, center, tx_date.isoformat(), source, cond])

        # Follow-up visits at about 100 days, then yearly, until death, loss or data cutoff
        allo = dtype != "autologous"
        relapsed = 0
        for days in [100, 365, 730, 1095, 1460, 1825]:
            fu_date = tx_date + timedelta(days=days + random.randint(-15, 30))
            if fu_date > DATA_CUTOFF:
                break
            followup_id += 1
            if not relapsed and random.random() < 0.12:
                relapsed = 1
            gvhd = random.choices([0, 1, 2, 3, 4], weights=[55, 20, 15, 7, 3])[0] if allo else 0
            p_death = 0.06 + 0.10 * relapsed + (0.04 if allo else 0)
            if random.random() < p_death:
                cause = "Relapse or progression" if relapsed else random.choice(
                    ["Infection", "Graft-versus-host disease", "Organ toxicity"] if allo else ["Infection", "Organ toxicity"])
                followups.append([followup_id, transplant_id, fu_date.isoformat(), "dead", relapsed, gvhd, cause])
                break
            if random.random() < 0.02:
                followups.append([followup_id, transplant_id, fu_date.isoformat(), "lost_to_followup", relapsed, gvhd, None])
                break
            followups.append([followup_id, transplant_id, fu_date.isoformat(), "alive", relapsed, gvhd, None])

    inject_quality_issues(patients, diagnoses, donors, transplants, followups)

    cur.executemany("INSERT INTO patients VALUES (?, ?, ?, ?, ?)", patients)
    cur.executemany("INSERT INTO diagnoses VALUES (?, ?, ?, ?, ?)", diagnoses)
    cur.executemany("INSERT INTO donors VALUES (?, ?, ?, ?)", donors)
    cur.executemany("INSERT INTO transplants VALUES (?, ?, ?, ?, ?, ?, ?)", transplants)
    cur.executemany("INSERT INTO follow_ups VALUES (?, ?, ?, ?, ?, ?, ?)", followups)
    con.commit()

    for table in ["centers", "patients", "diagnoses", "donors", "transplants", "follow_ups"]:
        n = cur.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]
        print(f"{table:<12} {n:>5} rows")
    con.close()
    print(f"\nDatabase written to {DB_PATH.name}")


def inject_quality_issues(patients, diagnoses, donors, transplants, followups):
    """Insert realistic errors that simple column constraints cannot catch."""
    rng = random.Random(7)
    dx_by_patient = {d[1]: d for d in diagnoses}
    donor_by_id = {d[0]: d for d in donors}

    # 1. Missing sex for some patients
    for p in rng.sample(patients, 8):
        p[2] = None

    # 2. Birth date after registration date (likely a typo in the year)
    for p in rng.sample(patients, 3):
        reg = date.fromisoformat(p[4])
        p[3] = (reg + timedelta(days=rng.randint(30, 400))).isoformat()

    # 3. Transplant recorded before the diagnosis date
    for t in rng.sample(transplants, 6):
        dx = date.fromisoformat(dx_by_patient[t[1]][4])
        t[4] = (dx - timedelta(days=rng.randint(10, 200))).isoformat()

    # 4. Missing conditioning regimen
    for t in rng.sample(transplants, 7):
        t[6] = None

    # 5. Follow-up visit dated before its transplant
    tx_date = {t[0]: date.fromisoformat(t[4]) for t in transplants}
    for f in rng.sample(followups, 5):
        f[2] = (tx_date[f[1]] - timedelta(days=rng.randint(5, 90))).isoformat()

    # 6. Death recorded without a cause
    deaths = [f for f in followups if f[3] == "dead"]
    for f in rng.sample(deaths, min(5, len(deaths))):
        f[6] = None

    # 7. GvHD reported after an autologous transplant (biologically implausible)
    auto_tx = {t[0] for t in transplants if donor_by_id[t[2]][1] == "autologous"}
    auto_fu = [f for f in followups if f[1] in auto_tx]
    for f in rng.sample(auto_fu, 4):
        f[5] = rng.randint(1, 3)

    # 8. Missing GvHD grade after allogeneic transplants
    allo_fu = [f for f in followups if f[1] not in auto_tx]
    for f in rng.sample(allo_fu, 10):
        f[5] = None

    # 9. A visit recorded as 'alive' after the patient's death
    max_id = max(f[0] for f in followups)
    for i, f in enumerate(rng.sample(deaths, 3)):
        later = date.fromisoformat(f[2]) + timedelta(days=rng.randint(60, 200))
        followups.append([max_id + i + 1, f[1], later.isoformat(), "alive", f[4], f[5], None])

    # 10. Possible duplicate patients: same center, sex and birth date, new ID
    next_id = max(p[0] for p in patients) + 1
    for p in rng.sample([p for p in patients if p[2] is not None], 3):
        reg = date.fromisoformat(p[4]) + timedelta(days=rng.randint(100, 500))
        patients.append([next_id, p[1], p[2], p[3], reg.isoformat()])
        next_id += 1


if __name__ == "__main__":
    build()
