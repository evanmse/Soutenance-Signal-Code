%% ============================================================
%  GENERER_PPG_REEL.M
%  Génère un fichier ppg_reel.mat simulant un enregistrement
%  acquis sur la carte électronique (CAN 12 bits, Fe = 250 Hz).
%  Groupe G2D – APP Signal 2025/2026
% ============================================================
%  Ce script produit un signal PPG réaliste avec :
%   - Variabilité cardiaque naturelle (HRV)
%   - Dérive basale (respiration + mouvement lent)
%   - Bruit capteur (électronique + quantification 12 bits)
%   - Artefacts de mouvement ponctuels
%   - Offset DC typique d'un capteur optique
%
%  Le fichier généré est directement compatible avec
%  charger_ppg_reel.m (variable 'ppg', Fe = 250 Hz).
% ============================================================

clear; close all; clc;

fprintf('==========================================================\n');
fprintf('  GENERATION D''UN ENREGISTREMENT PPG SIMULE               \n');
fprintf('==========================================================\n\n');

rng(2026);   % reproductibilité

% ── Paramètres de l'enregistrement ─────────────────────────
Fe_acq   = 250;       % Hz – fréquence du CAN de la carte
duree_s  = 45;        % secondes d'enregistrement
N_total  = Fe_acq * duree_s;
t        = (0:N_total-1) / Fe_acq;

% ── Paramètres physiologiques ──────────────────────────────
FC_repos = 72;         % BPM moyen au repos
HRV_std  = 0.025;      % écart-type de la variabilité RR (s) ≈ 25 ms SDNN

fprintf('  Configuration :\n');
fprintf('  • Fe acquisition   : %d Hz\n', Fe_acq);
fprintf('  • Durée            : %d s (%d échantillons)\n', duree_s, N_total);
fprintf('  • FC moyenne       : %d BPM\n', FC_repos);
fprintf('  • HRV (SDNN)       : %.0f ms\n\n', HRV_std*1000);

% ── 1. Génération des instants de battement avec HRV ──────
% La variabilité RR suit un modèle AR(1) corrélé (réaliste)
RR_moy   = 60 / FC_repos;    % période moyenne (s)
rr_list  = [];
tc       = 0.5;              % premier battement à 0.5 s (transitoire capteur)

while tc < duree_s - 1
    % Variabilité corrélée (composante respiratoire + aléatoire)
    rr_resp = 0.03 * sin(2*pi*0.25*tc);      % arythmie sinusale respiratoire
    rr_rand = HRV_std * randn;                % composante aléatoire
    rr = RR_moy + rr_resp + rr_rand;
    rr = max(rr, 0.35);   % minimum physiologique (~170 BPM)
    rr = min(rr, 1.8);    % maximum physiologique (~33 BPM)
    rr_list = [rr_list, rr];
    tc = tc + rr;
end

n_beats = length(rr_list);
t_beats = cumsum([0.5, rr_list(1:end-1)]);

fprintf('  1. Battements générés : %d (FC effective ≈ %.0f BPM)\n', ...
        n_beats, 60/mean(rr_list));

% ── 2. Construction de la forme d'onde PPG ────────────────
% Modèle réaliste : onde systolique + encoche dicrotique + onde diastolique
ppg_clean = zeros(1, N_total);

for k = 1:n_beats
    tb = t_beats(k);
    
    % Onde systolique (pic principal, gaussienne étroite)
    amp_sys = 0.9 + 0.1*randn;   % légère variation d'amplitude
    sigma_sys = 0.06 + 0.005*randn;
    ppg_clean = ppg_clean + amp_sys * exp(-((t - tb).^2) / (2*sigma_sys^2));
    
    % Encoche dicrotique (pic secondaire, plus petit et retardé)
    amp_dic = 0.30 + 0.05*randn;
    delay_dic = 0.22 + 0.02*randn;
    sigma_dic = 0.08 + 0.005*randn;
    ppg_clean = ppg_clean + amp_dic * exp(-((t - tb - delay_dic).^2) / (2*sigma_dic^2));
    
    % Onde diastolique (descente lente)
    amp_dia = 0.15 + 0.03*randn;
    delay_dia = 0.40 + 0.03*randn;
    sigma_dia = 0.12;
    ppg_clean = ppg_clean + amp_dia * exp(-((t - tb - delay_dia).^2) / (2*sigma_dia^2));
end

fprintf('  2. Forme d''onde PPG construite (systolique + dicrotique + diastolique)\n');

% ── 3. Dérive basale ─────────────────────────────────────
% Respiration (0.2 Hz) + dérive lente du capteur
drift_resp   = 0.15 * sin(2*pi*0.20*t + pi/4);
drift_lent   = 0.08 * sin(2*pi*0.02*t);
drift_offset = 0.05 * t / duree_s;   % dérive monotone (échauffement capteur)
drift = drift_resp + drift_lent + drift_offset;

fprintf('  3. Dérive basale ajoutée (respiration 0.2 Hz + dérive lente)\n');

% ── 4. Bruit capteur ─────────────────────────────────────
% Bruit blanc gaussien (électronique) + bruit 50 Hz (secteur)
SNR_cible = 25;   % dB
P_sig     = mean(ppg_clean.^2);
P_bruit   = P_sig / 10^(SNR_cible/10);
bruit_blanc = sqrt(P_bruit) * randn(1, N_total);
bruit_50Hz  = 0.02 * sin(2*pi*50*t + rand*2*pi);
bruit = bruit_blanc + bruit_50Hz;

fprintf('  4. Bruit capteur (SNR ≈ %d dB + 50 Hz réseau)\n', SNR_cible);

% ── 5. Artefacts de mouvement (2 brefs) ──────────────────
artefact = zeros(1, N_total);
% Artefact 1 : vers t = 8 s (petite secousse)
idx1 = round(8 * Fe_acq);
len1 = round(0.3 * Fe_acq);
artefact(idx1:idx1+len1-1) = 0.8 * randn(1, len1);

% Artefact 2 : vers t = 25 s
idx2 = round(25 * Fe_acq);
len2 = round(0.2 * Fe_acq);
artefact(idx2:idx2+len2-1) = 0.6 * randn(1, len2);

fprintf('  5. Artefacts de mouvement ajoutés (t ≈ 8 s et 25 s)\n');

% ── 6. Signal final (simule la sortie du CAN) ────────────
% Offset DC typique d'un capteur optique réflectif
DC_offset = 2048;    % milieu de la plage 12 bits (0-4095)
amplitude_ppg = 200; % amplitude crête en LSB

ppg_analog = DC_offset + amplitude_ppg * (ppg_clean + drift + bruit + artefact);

% Quantification 12 bits
ppg = round(ppg_analog);
ppg = max(0, min(4095, ppg));   % saturation CAN
ppg = uint16(ppg);

fprintf('  6. Quantification 12 bits (plage 0-4095, offset = %d)\n\n', DC_offset);

% ── 7. Sauvegarde ─────────────────────────────────────────
save('ppg_reel.mat', 'ppg');
fprintf('  >>> Fichier "ppg_reel.mat" sauvegardé (%d échantillons, %.1f s)\n', ...
        N_total, duree_s);
fprintf('  >>> Variable : ppg (uint16), Fe = %d Hz\n\n', Fe_acq);

% ── 8. Affichage de vérification ──────────────────────────
figure('Name', 'Signal PPG simulé', 'Position', [100 150 1000 600], 'Color', 'w');

subplot(3,1,1);
plot(t, double(ppg), 'b', 'LineWidth', 0.5);
xlabel('Temps (s)'); ylabel('Valeur CAN (LSB)');
title(sprintf('Signal PPG simulé – sortie CAN 12 bits (Fe = %d Hz, %d s)', Fe_acq, duree_s));
grid on;

subplot(3,1,2);
plot(t, ppg_clean, 'Color', [0.2 0.6 0.2], 'LineWidth', 1);
xlabel('Temps (s)'); ylabel('Amplitude');
title(sprintf('Signal PPG propre (FC ≈ %d BPM, %d battements)', ...
      round(60/mean(rr_list)), n_beats));
grid on;

subplot(3,1,3);
plot(t, drift, 'r', 'LineWidth', 1);
hold on;
plot(t, bruit + artefact, 'Color', [0.6 0.6 0.6], 'LineWidth', 0.5);
xlabel('Temps (s)'); ylabel('Amplitude');
title('Perturbations : dérive basale (rouge) + bruit + artefacts (gris)');
legend('Dérive', 'Bruit + artefacts');
grid on;

% ── 9. Infos de référence (pour vérification) ────────────
FC_ref = 60 / mean(rr_list);
fprintf('\n  Informations de référence (pour vérification) :\n');
fprintf('  • FC moyenne réelle       : %.1f BPM\n', FC_ref);
fprintf('  • RR moyen                : %.0f ms (± %.0f ms)\n', ...
        mean(rr_list)*1000, std(rr_list)*1000);
fprintf('  • Nombre de battements    : %d\n', n_beats);
fprintf('  • SNR du signal           : ≈ %d dB\n', SNR_cible);
fprintf('  • Artefacts à             : t ≈ 8 s et 25 s\n\n');

fprintf('  Pour analyser ce fichier, exécuter :\n');
fprintf('  >> charger_ppg_reel\n\n');
fprintf('==========================================================\n');
