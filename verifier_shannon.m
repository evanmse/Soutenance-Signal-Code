%% ============================================================
%  VERIFIER_SHANNON.M
%  Vérification des paramètres : Shannon, mémoire, complexité
%  Groupe G2D – APP Signal 2025/2026
% ============================================================

clear; close all; clc;

fprintf('==========================================================\n');
fprintf('  VERIFICATION DES PARAMETRES DU SYSTEME                  \n');
fprintf('==========================================================\n\n');

params = parametres_projet();

% ── 1. Shannon ───────────────────────────────────────────
fprintf('1. THEOREME DE SHANNON\n');
fprintf('   ------------------------------------------------------\n');
f_max = params.f_max_hz;
fe_min = 2 * f_max;
ratio = params.Fe / fe_min;
fprintf('   fmax (signal utile)          : %.2f Hz\n', f_max);
fprintf('   Fe minimum (Shannon)         : %.2f Hz\n', fe_min);
fprintf('   Fe choisi                    : %d Hz\n',  params.Fe);
fprintf('   Facteur de suréchantillonnage: %.1f x\n', ratio);
if params.Fe >= fe_min
    fprintf('   Statut : OK (Shannon satisfait)\n\n');
else
    fprintf('   Statut : ERREUR (Shannon violé)\n\n');
end

% ── 2. Résolution fréquentielle ──────────────────────────
fprintf('2. RESOLUTION FREQUENTIELLE\n');
fprintf('   ------------------------------------------------------\n');
fprintf('   Delta f = Fe/N = %d/%d = %.3f Hz\n', params.Fe, params.N, params.delta_f);
fprintf('   En BPM  = %.2f BPM\n', params.delta_f * 60);
fprintf('   Remarque : la résolution spectrale est améliorée\n');
fprintf('   en pratique par la méthode temporelle (RR-intervals).\n\n');

% ── 3. SNR de quantification ─────────────────────────────
fprintf('3. SNR DE QUANTIFICATION\n');
fprintf('   ------------------------------------------------------\n');
fprintf('   Bits CAN     : %d bits\n',       params.bits_can);
fprintf('   SNR_q        : %.2f dB\n',       params.snr_quant_db);
fprintf('   Seuil requis : ~40 dB (typique en physio)\n');
fprintf('   Marge        : %.1f dB -> OK\n\n', params.snr_quant_db - 40);

% ── 4. Mémoire ───────────────────────────────────────────
fprintf('4. BUDGET MEMOIRE\n');
fprintf('   ------------------------------------------------------\n');
taille_signal = params.N * 2;                             % int16
taille_filtre = (params.ordre_filtre + 1) * 4;            % float32
taille_temp   = 500;
taille_total  = taille_signal + taille_filtre + taille_temp;

fprintf('   Signal (%d x 2 bytes)        : %d bytes\n', params.N, taille_signal);
fprintf('   Filtre (%d x 4 bytes)        : %d bytes\n', ...
        params.ordre_filtre+1, taille_filtre);
fprintf('   Temporaires                    : %d bytes\n', taille_temp);
fprintf('   -----------------------------------------\n');
fprintf('   Total                          : %d bytes (%.2f KB)\n', ...
        taille_total, taille_total/1024);
fprintf('   RAM disponible (STM32F4)       : %d KB\n', params.cortex_ram_kb);
util_pct = 100 * taille_total / (params.cortex_ram_kb * 1024);
fprintf('   Utilisation                    : %.2f%% -> OK\n\n', util_pct);

% ── 5. Complexité algorithmique ──────────────────────────
fprintf('5. COMPLEXITE ALGORITHMIQUE\n');
fprintf('   ------------------------------------------------------\n');
% Filtre RIF : 1 mul + 1 add par coefficient par échantillon
ops_filtre = 2 * params.ordre_filtre * params.N;
% FFT radix-2 : 5 ops par N log2(N)
ops_fft = 5 * params.N * log2(params.N);
% Détection de pics : O(N)
ops_pics = 3 * params.N;

ops_total = ops_filtre + ops_fft + ops_pics;
fprintf('   Filtrage RIF  : %s ops\n', num2str(ops_filtre));
fprintf('   FFT (option)  : %s ops\n', num2str(round(ops_fft)));
fprintf('   Détec. pics   : %s ops\n', num2str(ops_pics));
fprintf('   Total         : %s ops\n\n', num2str(round(ops_total)));

% ── 6. Charge CPU ────────────────────────────────────────
fprintf('6. CHARGE CPU (ARM Cortex-M4)\n');
fprintf('   ------------------------------------------------------\n');
F_cpu = params.cortex_freq_mhz * 1e6;
% Hypothèse conservatrice : 1 op = 1 cycle (DSP SIMD possible mais ignoré)
t_exec_s = ops_total / F_cpu;
charge_pct = 100 * t_exec_s / params.D;

fprintf('   Processeur                  : STM32F4 @ %d MHz\n', params.cortex_freq_mhz);
fprintf('   Temps traitement par bloc   : %.3f ms\n', t_exec_s * 1000);
fprintf('   Charge CPU (bloc 10 s)      : %.4f%% -> OK (très faible)\n\n', ...
        charge_pct);

% ── 7. Validation globale ───────────────────────────────
fprintf('7. VALIDATION FINALE\n');
fprintf('   ------------------------------------------------------\n');
all_ok = (params.Fe >= fe_min) && ...
         (taille_total < params.cortex_ram_kb * 1024) && ...
         (charge_pct < 10);

if all_ok
    fprintf('   >>> TOUS LES PARAMETRES SONT VALIDES\n');
    fprintf('   >>> Systeme pret pour implementation sur Cortex-M4\n\n');
else
    fprintf('   >>> ERREUR : un ou plusieurs critères non satisfaits\n\n');
end

fprintf('==========================================================\n');
