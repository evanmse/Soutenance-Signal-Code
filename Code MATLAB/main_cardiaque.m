%% ============================================================
%  MAIN_CARDIAQUE.M
%  Programme principal : mesure de fréquence cardiaque sur 10 s
%  Groupe G2D – APP Signal 2025/2026
% ============================================================
%  Ce script démontre la chaîne complète sur un signal de test
%  synthétique. Pour utiliser un signal PPG réel, voir
%  charger_ppg_reel.m qui se substitue à la section 2.
% ============================================================

clear; close all; clc;

fprintf('=========================================================\n');
fprintf('   MESURE DE FREQUENCE CARDIAQUE - Chaine complete       \n');
fprintf('=========================================================\n\n');

% ── 1. Chargement des paramètres ──────────────────────────
params = parametres_projet();
Fe = params.Fe;  D = params.D;  N = params.N;
h  = params.h_filtre;
t  = (0:N-1) / Fe;

fprintf('1. CONFIGURATION\n');
fprintf('   Fe = %d Hz   D = %d s   N = %d échantillons\n', Fe, D, N);
fprintf('   Gabarit filtre : [%.1f-%.1f] Hz,  Astop = %d dB\n', ...
        params.fp1, params.fp2, params.Astop);
fprintf('   Ordre effectif du filtre : %d\n\n', params.ordre_filtre);

% ── 2. Génération d'un signal de test PPG réaliste ────────
% Modèle PPG = onde systolique (gaussienne) + encoche dicrotique
FC_test = 80;                % BPM
period  = 60 / FC_test;      % s

ppg = zeros(1, N);
for k = 0 : ceil(D/period)
    tc = k * period;
    ppg = ppg + exp(-((t - tc).^2) / (2 * 0.08^2));
    ppg = ppg + 0.35 * exp(-((t - tc - 0.25).^2) / (2 * 0.10^2));
end

% Normalisation
ppg = (ppg - mean(ppg)) / std(ppg);

% Bruit + dérive basale (respiration)
SNR_db = 20;
P_sig  = mean(ppg.^2);
P_b    = P_sig / 10^(SNR_db/10);
bruit  = sqrt(P_b) * randn(1, N);
drift  = 0.3 * sin(2*pi*0.2*t);

x_raw = ppg + bruit + drift;

fprintf('2. SIGNAL DE TEST SYNTHETIQUE\n');
fprintf('   FC imposée : %d BPM   SNR = %d dB   Dérive basale ajoutée\n\n', ...
        FC_test, SNR_db);

% ── 3. Filtrage passe-bande RIF ──────────────────────────
% Equation : y(n) = somme_{i=0}^{N_h-1} h(i) * x(n-i)
x_filt = filter(h, 1, x_raw);

% Compensation du retard de groupe (filtre FIR linéaire) pour
% retrouver la position réelle des pics sur l'axe temps.
delay = round(params.ordre_filtre / 2);
x_filt_aligned = [x_filt(delay+1:end), zeros(1, delay)];

fprintf('3. FILTRAGE RIF : ordre %d, retard de groupe = %d échantillons (%.0f ms)\n\n', ...
        params.ordre_filtre, delay, delay*1000/Fe);

% ── 4. Détection d'activité ──────────────────────────────
[actif, P_est] = detecter_activite(x_filt_aligned, Fe, ...
                                   params.fenetre_activite_s, ...
                                   params.seuil_P_absolu);

etats = {'NON', 'OUI'};
fprintf('4. DETECTION D''ACTIVITE\n');
fprintf('   Puissance estimée : %.3f   Seuil : %.3f\n', P_est, params.seuil_P_absolu);
fprintf('   Détection : %s\n\n', etats{double(actif)+1});

if ~actif
    warning('Pas d''activité cardiaque détectée, arrêt de l''analyse.');
    return;
end

% ── 5. Détection des pics R ──────────────────────────────
[pics_val, pics_idx] = findpeaks_custom(x_filt_aligned, ...
    'MinPeakDistance',   params.distance_min_samples, ...
    'MinPeakProminence', params.prominence_rel * max(x_filt_aligned));

fprintf('5. DETECTION DE PICS\n');
fprintf('   Distance min : %d échantillons (%d ms)\n', ...
        params.distance_min_samples, params.distance_min_ms);
fprintf('   Prominence min (relative) : %.0f%% du max\n', params.prominence_rel*100);
fprintf('   Nombre de pics détectés : %d\n\n', length(pics_idx));

if length(pics_idx) < 2
    error('Pas assez de pics détectés pour calculer un BPM.');
end

% ── 6. Calcul du BPM ─────────────────────────────────────
RR_samples = diff(pics_idx);
RR_sec     = RR_samples / Fe;
RR_moy_ms  = mean(RR_sec) * 1000;
RR_std_ms  = std(RR_sec) * 1000;
BPM_estime = 60 / mean(RR_sec);

fprintf('6. FREQUENCE CARDIAQUE\n');
fprintf('   RR moyen    : %.1f ms (± %.1f ms)\n', RR_moy_ms, RR_std_ms);
fprintf('   BPM estimé  : %.1f\n', BPM_estime);
fprintf('   BPM imposé  : %.1f\n', FC_test);
fprintf('   Erreur      : %.2f BPM\n\n', abs(BPM_estime - FC_test));

% ── 7. Analyse spectrale (vérification croisée) ──────────
[f_dom, snr_db, bpm_fft] = analyser_cle(x_filt_aligned, Fe);
fprintf('7. VERIFICATION FREQUENTIELLE (FFT)\n');
fprintf('   Fréquence dominante : %.3f Hz (%.1f BPM)\n', f_dom, bpm_fft);
fprintf('   SNR spectral estimé : %.2f dB\n\n', snr_db);

% ── 8. Affichage graphique ───────────────────────────────
figure('Name', 'Livrable III - Mesure FC', 'Position', [100 100 1100 700]);

subplot(3,2,1);
plot(t, x_raw, 'b', 'LineWidth', 0.9);
xlabel('Temps (s)'); ylabel('Amplitude');
title(sprintf('Signal brut (FC=%d BPM, SNR=%d dB)', FC_test, SNR_db));
grid on;

subplot(3,2,2);
plot(t, x_filt_aligned, 'g', 'LineWidth', 1);
hold on;
plot(pics_idx/Fe, x_filt_aligned(pics_idx), 'r*', 'MarkerSize', 10);
xlabel('Temps (s)'); ylabel('Amplitude');
title(sprintf('Filtré + pics (BPM = %.1f)', BPM_estime));
grid on;

subplot(3,2,3);
[H, f] = freqz_custom(h, 1, 4096, Fe);
plot(f, 20*log10(abs(H)+1e-12), 'b', 'LineWidth', 1.2);
hold on;
xline(params.fp1, 'g--'); xline(params.fp2, 'g--');
xlim([0 10]); ylim([-80 5]);
xlabel('Fréquence (Hz)'); ylabel('|H(f)| (dB)');
title('Réponse du filtre RIF'); grid on;

subplot(3,2,4);
X = fft(x_filt_aligned) / N;
f_axis = (0:N-1) / N * Fe;
plot(f_axis(1:N/2), 20*log10(abs(X(1:N/2))+1e-12), 'k', 'LineWidth', 1);
xlim([0 10]);
xlabel('Fréquence (Hz)'); ylabel('Magnitude (dB)');
title(sprintf('Spectre (pic = %.2f Hz)', f_dom)); grid on;

subplot(3,2,5);
plot(RR_sec*1000, 'bo-', 'LineWidth', 1.5);
hold on;
yline(RR_moy_ms, 'r--');
xlabel('Battement'); ylabel('RR (ms)');
title('Variabilité RR'); grid on;

subplot(3,2,6);
axis off;
recap = {
    'RESULTATS'
    '-------------------------'
    sprintf('BPM estimé     : %.1f', BPM_estime)
    sprintf('BPM imposé     : %.1f', FC_test)
    sprintf('Erreur         : %.2f BPM', abs(BPM_estime-FC_test))
    ''
    sprintf('Pics détectés  : %d', length(pics_idx))
    sprintf('RR moyen       : %.0f ms', RR_moy_ms)
    sprintf('RR écart-type  : %.1f ms', RR_std_ms)
    ''
    sprintf('SNR entrée     : %d dB', SNR_db)
    sprintf('SNR spectral   : %.1f dB', snr_db)
    sprintf('Détection      : %s', etats{double(actif)+1})
};
text(0.05, 0.95, recap, 'VerticalAlignment', 'top', ...
     'FontName', 'Courier', 'FontSize', 10);

% ── 9. BPM glissant (OPTION cahier des charges) ──────────
% Génération d'un signal plus long (60 s) avec FC variable pour
% démontrer la mesure de BPM en continu par fenêtres glissantes.
fprintf('8. BPM GLISSANT (option)\n');

D_long = 60;                  % durée 60 s
N_long = Fe * D_long;
t_long = (0:N_long-1) / Fe;

% FC variable : 70 BPM pendant 20s, puis 110 BPM, puis retour 80 BPM
ppg_long = zeros(1, N_long);
fc_instants = 70 * ones(1, N_long);
fc_instants(20*Fe+1:40*Fe) = 110;
fc_instants(40*Fe+1:end)   = 80;

tc = 0;
for n = 1:N_long
    if t_long(n) >= tc
        ppg_long = ppg_long + exp(-((t_long - tc).^2) / (2 * 0.08^2));
        ppg_long = ppg_long + 0.35 * exp(-((t_long - tc - 0.25).^2) / (2 * 0.10^2));
        tc = tc + 60 / fc_instants(n);
    end
end
ppg_long = (ppg_long - mean(ppg_long)) / std(ppg_long);
ppg_long = ppg_long + sqrt(P_b) * randn(1, N_long);

[bpm_t, t_c] = bpm_glissant(ppg_long, Fe, 10, 1);

figure('Name', 'BPM glissant (option)', 'Position', [200 200 800 350]);
plot(t_c, bpm_t, 'bo-', 'LineWidth', 1.5, 'MarkerSize', 5);
hold on;
yline(70, 'r--', '70 BPM'); yline(110, 'r--', '110 BPM'); yline(80, 'r--', '80 BPM');
xlabel('Temps (s)'); ylabel('BPM');
title('BPM glissant sur signal à FC variable (fenêtre 10 s, pas 1 s)');
ylim([30 180]); grid on;
legend('BPM mesuré', 'FC théorique', 'Location', 'best');

fprintf('   Signal de 60 s avec FC variable (70/110/80 BPM)\n');
fprintf('   %d mesures glissantes réalisées\n\n', sum(~isnan(bpm_t)));

fprintf('=========================================================\n');
fprintf('   FIN - Programme exécuté sans erreur                   \n');
fprintf('=========================================================\n');
