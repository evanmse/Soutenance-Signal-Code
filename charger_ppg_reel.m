%% ============================================================
%  CHARGER_PPG_REEL.M
%  Chargement, rééchantillonnage et analyse d'un enregistrement
%  PPG acquis sur la carte électronique.
%  Groupe G2D – APP Signal 2025/2026
% ============================================================
%  USAGE :
%   1. Placer le fichier de données dans le même dossier
%      (format accepté : .mat, .csv, .txt)
%   2. Modifier FICHIER et FE_ACQ ci-dessous si besoin
%   3. Exécuter le script
% ============================================================

clear; close all; clc;

% ──────────────────────────────────────────────────────────
% CONFIGURATION (à adapter à votre fichier)
% ──────────────────────────────────────────────────────────
FICHIER   = 'ppg_reel.mat';    % Nom du fichier d'enregistrement
FE_ACQ    = 250;               % Fréquence d'acquisition de la carte (Hz)
VARIABLE  = 'ppg';             % Nom de la variable dans le .mat
FC_REF    = [];                % BPM de référence si connu, sinon []

% ──────────────────────────────────────────────────────────
% 1. Chargement des données
% ──────────────────────────────────────────────────────────
fprintf('==========================================================\n');
fprintf('  ANALYSE D''UN ENREGISTREMENT PPG REEL                   \n');
fprintf('==========================================================\n\n');

if ~exist(FICHIER, 'file')
    error(['Fichier "%s" introuvable. Voir README pour le format' ...
           ' attendu et placer le fichier dans le dossier courant.'], FICHIER);
end

[~, ~, ext] = fileparts(FICHIER);
switch lower(ext)
    case '.mat'
        data = load(FICHIER);
        if isfield(data, VARIABLE)
            x_raw_full = double(data.(VARIABLE));
        else
            champs = fieldnames(data);
            x_raw_full = double(data.(champs{1}));
            warning('Variable "%s" non trouvée, utilisation de "%s".', ...
                    VARIABLE, champs{1});
        end
    case {'.csv', '.txt'}
        x_raw_full = readmatrix(FICHIER);
        if size(x_raw_full, 2) > 1
            x_raw_full = x_raw_full(:, end);   % dernière colonne = signal
        end
    otherwise
        error('Format de fichier non supporté : %s', ext);
end

x_raw_full = x_raw_full(:)';   % vecteur ligne
duree_acq_s = length(x_raw_full) / FE_ACQ;

fprintf('1. CHARGEMENT\n');
fprintf('   Fichier             : %s\n', FICHIER);
fprintf('   Fréquence acquisition : %d Hz\n', FE_ACQ);
fprintf('   Durée totale        : %.2f s (%d échantillons)\n\n', ...
        duree_acq_s, length(x_raw_full));

% ──────────────────────────────────────────────────────────
% 2. Rééchantillonnage vers Fe = 100 Hz (Fe du système cible)
% ──────────────────────────────────────────────────────────
params = parametres_projet();
Fe = params.Fe;

if FE_ACQ ~= Fe
    fprintf('2. REECHANTILLONNAGE : %d Hz -> %d Hz\n', FE_ACQ, Fe);
    % Rééchantillonnage par interpolation (sans Signal Processing Toolbox)
    t_old = (0:length(x_raw_full)-1) / FE_ACQ;
    N_new = round(length(x_raw_full) * Fe / FE_ACQ);
    t_new = (0:N_new-1) / Fe;
    x_100Hz = interp1(t_old, x_raw_full, t_new, 'spline');
    fprintf('   Nouveau nb échantillons : %d\n\n', length(x_100Hz));
else
    x_100Hz = x_raw_full;
    fprintf('2. Pas de rééchantillonnage nécessaire.\n\n');
end

% ──────────────────────────────────────────────────────────
% 3. Sélection d'une fenêtre de 10 s
% ──────────────────────────────────────────────────────────
N_win = params.N;   % 1000 échantillons = 10 s
if length(x_100Hz) < N_win
    error('Signal trop court (%.1f s) pour une analyse de 10 s.', ...
          length(x_100Hz)/Fe);
end

% On saute les 2 premières secondes (transitoire de contact doigt/capteur)
idx_start = 2 * Fe + 1;
idx_end   = idx_start + N_win - 1;
if idx_end > length(x_100Hz)
    idx_start = 1;
    idx_end   = N_win;
end
x_10s = x_100Hz(idx_start : idx_end);
t     = (0 : N_win-1) / Fe;

fprintf('3. FENETRE D''ANALYSE\n');
fprintf('   Durée : 10 s (%d échantillons) à partir de t = %.2f s\n\n', ...
        N_win, (idx_start-1)/Fe);

% ──────────────────────────────────────────────────────────
% 4. Normalisation
% ──────────────────────────────────────────────────────────
x_norm = (x_10s - mean(x_10s)) / std(x_10s);

% ──────────────────────────────────────────────────────────
% 5. Filtrage passe-bande RIF
% ──────────────────────────────────────────────────────────
h = params.h_filtre;
x_filt = filter(h, 1, x_norm);

% Compensation du retard de groupe
delay = round(params.ordre_filtre / 2);
x_filt_aligned = [x_filt(delay+1:end), zeros(1, delay)];

% ──────────────────────────────────────────────────────────
% 6. Détection d'activité
% ──────────────────────────────────────────────────────────
[actif, P_est] = detecter_activite(x_filt_aligned, Fe, ...
                                   params.fenetre_activite_s, ...
                                   params.seuil_P_absolu);

etats = {'NON', 'OUI'};
fprintf('4. DETECTION D''ACTIVITE\n');
fprintf('   Puissance estimée : %.3f   Seuil : %.3f\n', P_est, params.seuil_P_absolu);
fprintf('   Détection : %s\n\n', etats{double(actif)+1});

if ~actif
    warning('Pas d''activité détectée. Vérifier le contact du capteur.');
end

% ──────────────────────────────────────────────────────────
% 7. Détection des pics R
% ──────────────────────────────────────────────────────────
[pics_val, pics_idx] = findpeaks_custom(x_filt_aligned, ...
    'MinPeakDistance',   params.distance_min_samples, ...
    'MinPeakProminence', params.prominence_rel * max(x_filt_aligned));

fprintf('5. DETECTION DES PICS\n');
fprintf('   Nombre de pics : %d\n\n', length(pics_idx));

if length(pics_idx) < 2
    error('Pas assez de pics détectés pour calculer le BPM.');
end

% ──────────────────────────────────────────────────────────
% 8. Calcul du BPM
% ──────────────────────────────────────────────────────────
RR = diff(pics_idx) / Fe;
BPM_estime = 60 / mean(RR);
RR_moy_ms  = mean(RR) * 1000;
RR_std_ms  = std(RR)  * 1000;

fprintf('6. RESULTATS\n');
fprintf('   RR moyen     : %.1f ± %.1f ms\n', RR_moy_ms, RR_std_ms);
fprintf('   BPM estimé   : %.1f\n', BPM_estime);
if ~isempty(FC_REF)
    fprintf('   BPM référence: %.1f\n', FC_REF);
    fprintf('   Erreur       : %.2f BPM\n', abs(BPM_estime - FC_REF));
end

% ──────────────────────────────────────────────────────────
% 9. Analyse spectrale de vérification
% ──────────────────────────────────────────────────────────
[f_dom, snr_db, bpm_fft] = analyser_cle(x_filt_aligned, Fe);
fprintf('   FFT : pic à %.2f Hz (%.1f BPM), SNR spectral %.1f dB\n\n', ...
        f_dom, bpm_fft, snr_db);

% ──────────────────────────────────────────────────────────
% 10. Affichage
% ──────────────────────────────────────────────────────────
figure('Name', 'PPG réel - analyse', 'Position', [100 100 1100 700]);

subplot(3,1,1);
plot(t, x_norm, 'b', 'LineWidth', 0.9);
xlabel('Temps (s)'); ylabel('Amplitude normalisée');
title(sprintf('Signal PPG réel brut (%s, Fe = %d Hz)', FICHIER, Fe));
grid on;

subplot(3,1,2);
plot(t, x_filt_aligned, 'g', 'LineWidth', 1);
hold on;
plot(pics_idx/Fe, x_filt_aligned(pics_idx), 'r*', 'MarkerSize', 10);
xlabel('Temps (s)'); ylabel('Amplitude');
title(sprintf('Signal filtré + pics détectés (BPM = %.1f)', BPM_estime));
grid on;

subplot(3,1,3);
X = fft(x_filt_aligned) / N_win;
f_axis = (0:N_win-1) / N_win * Fe;
plot(f_axis(1:N_win/2), 20*log10(abs(X(1:N_win/2))+1e-12), 'k', 'LineWidth', 1);
hold on;
xline(f_dom, 'r--', sprintf('%.2f Hz', f_dom));
xlim([0 10]);
xlabel('Fréquence (Hz)'); ylabel('Magnitude (dB)');
title('Spectre d''amplitude'); grid on;

% ──────────────────────────────────────────────────────────
% 11. BPM glissant (option) si signal assez long
% ──────────────────────────────────────────────────────────
if length(x_100Hz) >= 20 * Fe
    fprintf('7. BPM GLISSANT (option)\n');
    [bpm_t, t_c] = bpm_glissant(x_100Hz, Fe, 10, 1);
    figure('Name', 'BPM glissant (signal réel)');
    plot(t_c, bpm_t, 'bo-', 'LineWidth', 1.5, 'MarkerSize', 5);
    xlabel('Temps (s)'); ylabel('BPM');
    title('BPM glissant sur enregistrement réel (fenêtre 10 s, pas 1 s)');
    ylim([30 180]); grid on;
    fprintf('   %d mesures glissantes\n\n', sum(~isnan(bpm_t)));
end

fprintf('==========================================================\n');
