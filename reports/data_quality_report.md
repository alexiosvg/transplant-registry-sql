# Data quality report

Campaign date 2026-02-10. Database: 603 patients, 559 transplants, 1932 follow-up visits.

**12 of 12 checks flagged records. 57 issues need review.**

## Checks

| Check | Severity | Table | Description | Flagged | New this campaign | Confirmed correct |
|---|---|---|---|---|---|---|
| DQ01 | high | transplants | Transplant dated before the diagnosis | 6 | 0 | 0 |
| DQ02 | high | follow_ups | Follow-up visit dated before its transplant | 5 | 0 | 0 |
| DQ03 | high | patients | Birth date after registration date | 3 | 0 | 0 |
| DQ04 | high | follow_ups | Visit recorded as alive after a recorded death | 3 | 0 | 0 |
| DQ05 | medium | follow_ups | GvHD reported after an autologous transplant | 4 | 0 | 0 |
| DQ06 | medium | patients | Possible duplicate patients (same center, sex and birth date) | 4 | 0 | 1 |
| DQ07 | medium | follow_ups | Death recorded without a cause | 5 | 0 | 0 |
| DQ08 | medium | patients | Registered patient without any diagnosis | 3 | 0 | 0 |
| DQ09 | medium | transplants | Implausible age at transplant (below 0 or above 80) | 1 | 0 | 0 |
| DQ10 | low | patients | Missing sex | 8 | 0 | 0 |
| DQ11 | low | transplants | Missing conditioning regimen | 6 | 0 | 0 |
| DQ12 | low | follow_ups | Missing GvHD grade after an allogeneic transplant | 10 | 0 | 0 |

## Issue log

| Status | Issues |
|---|---|
| open | 54 |
| query_sent | 3 |
| resolved | 1 |
| confirmed_correct | 1 |

## Issues needing review, by center

| Center | Country | Issues |
|---|---|---|
| Hospital Clinic Barcelona | Spain | 8 |
| Hospital La Fe Valencia | Spain | 8 |
| Rigshospitalet Copenhagen | Denmark | 7 |
| Charite Berlin | Germany | 6 |
| Ospedale San Raffaele Milan | Italy | 6 |
| Hopital Saint-Louis Paris | France | 5 |
| Karolinska University Hospital | Sweden | 5 |
| Papanikolaou Hospital Thessaloniki | Greece | 5 |
| King's College Hospital London | United Kingdom | 4 |
| Leiden University Medical Center | Netherlands | 3 |

## Example records (up to 5 per check)

### DQ01: Transplant dated before the diagnosis

| transplant_id | patient_id | diagnosis_date | transplant_date |
|---|---|---|---|
| 72 | 81 | 2019-09-02 | 2019-07-23 |
| 93 | 103 | 2022-08-17 | 2022-02-27 |
| 247 | 267 | 2015-11-10 | 2015-09-04 |
| 429 | 460 | 2015-04-17 | 2014-11-14 |
| 435 | 466 | 2023-09-29 | 2023-04-12 |

### DQ02: Follow-up visit dated before its transplant

| followup_id | transplant_id | transplant_date | followup_date |
|---|---|---|---|
| 242 | 60 | 2020-01-22 | 2020-01-04 |
| 296 | 74 | 2019-10-30 | 2019-08-15 |
| 859 | 233 | 2022-11-10 | 2022-09-27 |
| 1108 | 308 | 2016-02-20 | 2016-01-23 |
| 1170 | 327 | 2016-08-04 | 2016-05-17 |

### DQ03: Birth date after registration date

| patient_id | birth_date | registration_date |
|---|---|---|
| 60 | 2022-11-30 | 2022-10-12 |
| 520 | 2024-02-13 | 2023-12-01 |
| 597 | 2018-07-22 | 2018-03-05 |

### DQ04: Visit recorded as alive after a recorded death

| followup_id | transplant_id | death_date | followup_date |
|---|---|---|---|
| 1931 | 218 | 2023-02-13 | 2023-07-10 |
| 1932 | 360 | 2019-08-16 | 2020-02-06 |
| 1930 | 385 | 2020-11-09 | 2021-05-14 |

### DQ05: GvHD reported after an autologous transplant

| followup_id | transplant_id | gvhd_grade |
|---|---|---|
| 161 | 40 | 1 |
| 1248 | 347 | 1 |
| 1271 | 352 | 2 |
| 1599 | 451 | 3 |

### DQ06: Possible duplicate patients (same center, sex and birth date)

| patient_id | possible_duplicate_of | center_id | birth_date |
|---|---|---|---|
| 486 | 194 | 8 | 1968-10-27 |
| 601 | 299 | 4 | 1957-11-11 |
| 602 | 77 | 2 | 1950-07-06 |
| 603 | 124 | 1 | 1960-07-03 |

### DQ07: Death recorded without a cause

| followup_id | transplant_id | followup_date |
|---|---|---|
| 304 | 77 | 2018-02-22 |
| 501 | 134 | 2021-04-17 |
| 1010 | 275 | 2019-11-24 |
| 1382 | 383 | 2024-06-21 |
| 1527 | 430 | 2020-10-17 |

### DQ08: Registered patient without any diagnosis

| patient_id | registration_date |
|---|---|
| 601 | 2024-02-10 |
| 602 | 2018-03-22 |
| 603 | 2024-01-21 |

### DQ09: Implausible age at transplant (below 0 or above 80)

| transplant_id | patient_id | age |
|---|---|---|
| 54 | 60 | -0.0 |

### DQ10: Missing sex

| patient_id | center_id |
|---|---|
| 50 | 9 |
| 75 | 8 |
| 97 | 7 |
| 155 | 5 |
| 332 | 1 |

### DQ11: Missing conditioning regimen

| transplant_id | patient_id | transplant_date |
|---|---|---|
| 51 | 56 | 2020-03-28 |
| 64 | 72 | 2020-11-16 |
| 137 | 150 | 2017-04-10 |
| 227 | 243 | 2024-08-16 |
| 297 | 319 | 2024-03-17 |

### DQ12: Missing GvHD grade after an allogeneic transplant

| followup_id | transplant_id | followup_date |
|---|---|---|
| 345 | 88 | 2023-07-23 |
| 728 | 196 | 2022-05-27 |
| 917 | 247 | 2018-03-02 |
| 939 | 254 | 2018-11-22 |
| 1144 | 318 | 2025-01-02 |
