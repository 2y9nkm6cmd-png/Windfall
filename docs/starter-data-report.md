# Starter data: conversion report

Made on 2026-11-11 from `Garden_Planning.xlsx` by `Tools/data/build_starter_data.py`.

## What was carried across

| Table | Rows |
|---|---|
| Permaculture Garden | 224 |
| Allotment Garden | 173 |
| Permaculture Plants to buy | 40 |
| Previously Owned Plants | 1 |
| Companion planting | 410 |
| Fauna | 21 |
| Plant-Fauna Links | 58 |
| Flower Form Guide | 20 |
| Cascades | 7 |

## Decisions the script made

- **Permaculture Garden**: left out 2 formula-only column(s): Current age [months], Plant variety.
- **Permaculture Garden**: skipped 1 row(s) that had some content but no 'Common Name'.
- **Allotment Garden**: left out 8 formula-only column(s): All sowing months, Germination days, Germination days max, Plant this month?, Plant variety, Sow to crop days, Sow to crop days max, Sow to crop days min.
- **Permaculture Plants to buy**: left out 2 formula-only column(s): Current age [months], Plant variety.
- **Previously Owned Plants**: left out 2 formula-only column(s): Current age [months], Plant variety.
- **Companion planting**: left out 3 formula-only column(s): Category 1, Category 2, Plant combo.
- **Companion planting**: kept 410 of 2777 pairs. The rest have no + or - mark and say nothing either way. Marks left out: {'(blank)': 2360, '?': 7}.

## Sheets not carried across

| Sheet | Why |
|---|---|
| Planting front page | a lookup page made of formulas |
| Planting Schedule | a working schedule built from formulas; the app keeps its own sowing records |
| Read Me | instructions for the spreadsheet itself |
| Plantings | example row only; real records are made in the app |
| Harvests | example row only; real records are made in the app |
| FIT Counts | example row only; real records are made in the app |
| FIT Tallies | example row only; real records are made in the app |
| Wildlife Observations | example row only; real records are made in the app |
| Wild Plant Assemblages | the app has nowhere to put these yet |
| Recording Organisations | the app has nowhere to put these yet |
