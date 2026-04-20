%% ============================================================
%  PARAMETRES_PROJET.M
%  Configuration centralisée de tous les paramètres
%  Groupe G2D – APP Signal 2025/2026
% ============================================================
function params = parametres_projet()
% PARAMETRES_PROJET  Retourne une structure avec tous les paramètres
%
% SORTIE:
%   params : structure contenant les paramètres du système

% ── Paramètres d'échantillonnage ──────────────────────────
params.Fe = 100;                 % Fréquence d'échantillonnage (Hz)
params.D  = 10;                  % Durée d'analyse (s)
params.N  = params.Fe * params.D;% Nombre d'échantillons

% ── Paramètres du signal cardiaque ────────────────────────
params.f_min_bpm = 30;
params.f_max_bpm = 180;
params.f_min_hz  = params.f_min_bpm / 60;   % 0.5 Hz
params.f_max_hz  = params.f_max_bpm / 60;   % 3.0 Hz

% ── Quantification (CAN 12 bits du Cortex-M4) ─────────────
params.bits_can     = 12;
params.snr_quant_db = 6.02 * params.bits_can + 4.77;   % ≈ 77 dB

% ── Gabarit du filtre RIF passe-bande ─────────────────────
% Bande passante : [fp1, fp2]
% Bande atténuée : [0, fs1] U [fs2, Fe/2]
params.fs1   = 0.2;         % début bande passante (Hz)
params.fp1   = 0.5;         % fin  bande atténuée basse (Hz)
params.fp2   = 3.0;         % fin  bande passante (Hz)
params.fs2   = 4.5;         % début bande atténuée haute (Hz)
params.Apass = 0.5;         % ondulation bande passante (dB)
params.Astop = 40;          % réjection bande atténuée (dB)

% Ordre et coefficients du filtre : calculés par synthese_filtre.m
[params.h_filtre, params.ordre_filtre] = synthese_filtre(params);

% ── Détection des pics ────────────────────────────────────
% Distance min entre pics : doit autoriser 180 BPM (= période 333 ms).
% On prend 280 ms pour une marge de sécurité (on ne détectera pas > 214 BPM,
% ce qui est bien au-dessus de la plage physiologique utile).
params.distance_min_ms      = 280;
params.distance_min_samples = round(params.distance_min_ms / 1000 * params.Fe);

% Prominence relative pour écarter l'onde dicrotique :
% Le pic systolique est typiquement 2 à 3 fois plus haut que l'encoche
% dicrotique. On exige une prominence d'au moins 40 % du max local.
params.prominence_rel = 0.40;

% ── Détection d'activité (seuil ADAPTATIF) ────────────────
% Un signal PPG après normalisation (division par l'écart-type) a une
% puissance proche de 1. Un bruit blanc seul après filtrage passe-bande
% [0.5-3] Hz a une puissance résiduelle de l'ordre de σ² × (3-0.5)/50 ≈ 0.05.
% On fixe le seuil à 3× cette valeur, soit ~0.15, comme compromis sensibilité
% / spécificité. Le seuil réel est calibré expérimentalement sur signaux réels.
params.seuil_P_absolu      = 0.15;
params.fenetre_activite_s  = 2;     % fenêtre glissante d'estimation (s)

% ── Plateforme cible : ARM Cortex-M4 (STM32F4xx) ─────────
params.cortex_freq_mhz = 168;   % STM32F407 @ 168 MHz
params.cortex_ram_kb   = 192;   % 192 KB SRAM
params.cortex_flash_kb = 1024;  % 1 MB FLASH

% ── Résolutions ──────────────────────────────────────────
params.delta_f = params.Fe / params.N;   % Résolution fréquentielle (Hz)
params.delta_t = 1 / params.Fe;          % Période d'échantillonnage (s)

% ── Paramètres de validation ─────────────────────────────
params.snr_test = [5, 15, 20, 30];          % dB
params.fc_test  = [60, 80, 100, 120, 180];  % BPM

end
