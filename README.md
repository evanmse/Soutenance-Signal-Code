# Projet 1 – Mesure de la fréquence cardiaque

**APP Signal 2025/2026 – Groupe G2D**

## Description

Système de mesure de la fréquence cardiaque basé sur un capteur optique PPG (photopléthysmogramme). Le traitement est réalisé sous MATLAB en vue de l'implémentation sur microcontrôleur ARM Cortex-M4 (STM32F4).

## Cahier des charges

- Détection de la présence d'un signal cardiaque (LED + afficheur OLED)
- Mesure de la pulsation cardiaque (30–180 BPM)
- Stockage et analyse de 10 s de signal
- **Option** : mesure du BPM par fenêtres glissantes (BPM fonction du temps)

## Architecture des fichiers

| Fichier | Rôle |
|---|---|
| `parametres_projet.m` | Configuration centralisée (Fe, durée, gabarit filtre, seuils) |
| `synthese_filtre.m` | Synthèse du filtre RIF passe-bande (Parks-McClellan) |
| `detecter_activite.m` | Détection de la présence d'un signal cardiaque |
| `analyser_cle.m` | Analyse spectrale : fréquence dominante et SNR |
| `bpm_glissant.m` | Mesure du BPM en continu par fenêtres glissantes (option) |
| `main_cardiaque.m` | **Script principal** : chaîne complète sur signal synthétique |
| `charger_ppg_reel.m` | Chargement et analyse d'un enregistrement PPG réel |
| `verifier_shannon.m` | Vérification des contraintes système (Shannon, mémoire, CPU) |
| `test_cardiaque_complet.m` | Batterie de tests sur signaux synthétiques |

## Schéma fonctionnel

```
Signal PPG brut (capteur optique)
        │
        ▼
┌───────────────────┐
│  Échantillonnage  │  Fe = 100 Hz, CAN 12 bits
│  (10 s → 1000 éch)│
└───────┬───────────┘
        │
        ▼
┌───────────────────┐
│  Filtrage RIF     │  Passe-bande [0.5 – 3.0] Hz
│  (Parks-McClellan)│  Astop = 40 dB
└───────┬───────────┘
        │
        ▼
┌───────────────────┐
│  Détection        │  Puissance glissante > seuil
│  d'activité       │  → LED ON / OFF
└───────┬───────────┘
        │
        ▼
┌───────────────────┐
│  Détection pics   │  findpeaks (distance min, prominence)
│  systoliques      │
└───────┬───────────┘
        │
        ▼
┌───────────────────┐
│  Calcul BPM       │  BPM = 60 / moyenne(RR)
│  + vérification   │  Vérification croisée par FFT
│  spectrale        │
└───────────────────┘
```

## Paramètres clés

| Paramètre | Valeur | Justification |
|---|---|---|
| Fe | 100 Hz | Shannon : fmax = 3 Hz → Fe_min = 6 Hz, suréchantillonnage ×16 |
| Durée | 10 s | ≥ 5 battements à 30 BPM, résolution Δf = 0.1 Hz |
| Filtre | RIF, [0.5–3.0] Hz | 30–180 BPM, réjection dérive + 50 Hz |
| CAN | 12 bits | SNR_q = 77 dB >> 40 dB requis |

## Utilisation

1. **Signal synthétique** : exécuter `main_cardiaque.m`
2. **Signal réel** : placer le fichier d'enregistrement (.mat/.csv/.txt) dans le dossier, configurer `charger_ppg_reel.m` et l'exécuter
3. **Validation** : exécuter `test_cardiaque_complet.m`
4. **Vérification système** : exécuter `verifier_shannon.m`

## Dépendances MATLAB

- Signal Processing Toolbox (`firpm`, `findpeaks`, `freqz`, `resample`)
