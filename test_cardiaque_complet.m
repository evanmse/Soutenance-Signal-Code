%% ============================================================
%  TEST_CARDIAQUE_COMPLET.M
%  Batterie de tests sur signaux PPG synthétiques réalistes
%  Groupe G2D – APP Signal 2025/2026
% ============================================================
%  Produit :
%   - Un tableau récapitulatif des performances
%   - Les statistiques globales (erreur moyenne, taux de succès)
%   - Les figures de synthèse (erreur vs SNR, concordance BPM)
% ============================================================

clear; close all; clc;

fprintf('==========================================================\n');
fprintf('  TESTS EXHAUSTIFS - FC SUR SIGNAUX PPG SYNTHETIQUES      \n');
fprintf('==========================================================\n\n');

% ── Paramètres ─────────────────────────────────────────────
params = parametres_projet();
Fe = params.Fe;  D = params.D;  N = params.N;
h  = params.h_filtre;
t  = (0:N-1) / Fe;

% Scénarios testés
fc_tests  = [60  80 100 120 150 180];
snr_tests = [30  30  20  15  10   5];     % SNR croisé avec FC

% Nombre de tirages par scénario
n_trials = 20;

% Stockage des résultats
erreurs_all = zeros(length(fc_tests), n_trials);
bpm_all     = zeros(length(fc_tests), n_trials);
pics_all    = zeros(length(fc_tests), n_trials);

rng(42);  % reproductibilité

for i = 1 : length(fc_tests)
    FC = fc_tests(i);
    SNR = snr_tests(i);
    period = 60 / FC;

    for j = 1 : n_trials
        % -- Génération d'un signal PPG réaliste --
        ppg = zeros(1, N);
        for k = 0 : ceil(D/period)
            tc = k * period;
            ppg = ppg + exp(-((t - tc).^2) / (2 * 0.08^2));
            ppg = ppg + 0.35 * exp(-((t - tc - 0.25).^2) / (2 * 0.10^2));
        end
        ppg = (ppg - mean(ppg)) / std(ppg);

        P_sig = mean(ppg.^2);
        P_b   = P_sig / 10^(SNR/10);
        x = ppg + sqrt(P_b) * randn(1, N);

        % -- Traitement --
        x_f = filter(h, 1, x);
        delay = params.ordre_filtre / 2;
        x_aligned = [x_f(delay+1:end), zeros(1, delay)];

        [~, pks] = findpeaks(x_aligned, ...
            'MinPeakDistance',   params.distance_min_samples, ...
            'MinPeakProminence', params.prominence_rel * max(x_aligned));

        if length(pks) >= 2
            RR = diff(pks) / Fe;
            BPM_est = 60 / mean(RR);
            erreurs_all(i,j) = abs(BPM_est - FC);
            bpm_all(i,j)     = BPM_est;
            pics_all(i,j)    = length(pks);
        else
            erreurs_all(i,j) = NaN;
            bpm_all(i,j)     = NaN;
            pics_all(i,j)    = length(pks);
        end
    end
end

% ── Tableau récapitulatif ─────────────────────────────────
fprintf('\n');
fprintf('  +----+----------+----------+------------+---------+-----------+--------+\n');
fprintf('  | N° | FC (BPM) | SNR (dB) | BPM estimé | Erreur  | Pics moy. | Statut |\n');
fprintf('  +----+----------+----------+------------+---------+-----------+--------+\n');

statut_ok = zeros(length(fc_tests), 1);
for i = 1 : length(fc_tests)
    err_moy  = mean(erreurs_all(i,:), 'omitnan');
    bpm_moy  = mean(bpm_all(i,:),      'omitnan');
    pics_moy = mean(pics_all(i,:));

    statut_ok(i) = (err_moy < 5);
    symb = {' X ', ' OK'};
    fprintf('  | %2d | %7d  | %7d  |  %7.2f   |  %5.2f  |   %5.1f   |  %s   |\n', ...
            i, fc_tests(i), snr_tests(i), bpm_moy, err_moy, pics_moy, ...
            symb{statut_ok(i)+1});
end
fprintf('  +----+----------+----------+------------+---------+-----------+--------+\n\n');

% ── Statistiques globales ─────────────────────────────────
err_flat = erreurs_all(:);
err_flat = err_flat(~isnan(err_flat));

fprintf('STATISTIQUES GLOBALES (sur %d mesures)\n', length(err_flat));
fprintf('  Erreur moyenne    : %.3f BPM\n',   mean(err_flat));
fprintf('  Ecart-type        : %.3f BPM\n',   std(err_flat));
fprintf('  Erreur médiane    : %.3f BPM\n',   median(err_flat));
fprintf('  Erreur max        : %.3f BPM\n',   max(err_flat));
fprintf('  Taux de succès    : %.1f%% (%d scénarios / %d)\n\n', ...
        100*sum(statut_ok)/length(statut_ok), sum(statut_ok), length(statut_ok));

% ── Figure : erreur vs SNR (courbe) ──────────────────────
% Re-teste un balayage SNR fin pour la figure
snr_range = 0:5:30;
fc_benchmark = [60 100 150];
err_bench = zeros(length(fc_benchmark), length(snr_range));

for a = 1:length(fc_benchmark)
    FC = fc_benchmark(a);
    period = 60 / FC;
    for b = 1:length(snr_range)
        err_trials = zeros(1, n_trials);
        for k = 1:n_trials
            ppg = zeros(1, N);
            for m = 0:ceil(D/period)
                tc = m * period;
                ppg = ppg + exp(-((t - tc).^2) / (2 * 0.08^2));
                ppg = ppg + 0.35 * exp(-((t - tc - 0.25).^2) / (2 * 0.10^2));
            end
            ppg = (ppg - mean(ppg)) / std(ppg);
            P_b = mean(ppg.^2) / 10^(snr_range(b)/10);
            x = ppg + sqrt(P_b) * randn(1, N);
            x_f = filter(h, 1, x);
            x_a = [x_f(params.ordre_filtre/2+1:end), zeros(1, params.ordre_filtre/2)];
            [~, pks] = findpeaks(x_a, ...
                'MinPeakDistance',   params.distance_min_samples, ...
                'MinPeakProminence', params.prominence_rel * max(x_a));
            if length(pks) >= 2
                err_trials(k) = abs(60/mean(diff(pks)/Fe) - FC);
            else
                err_trials(k) = NaN;
            end
        end
        err_bench(a,b) = mean(err_trials, 'omitnan');
    end
end

figure('Name', 'Performances', 'Position', [150 150 900 400]);

subplot(1,2,1);
markers = {'o', 's', '^'};
colors = lines(3);
for a = 1:length(fc_benchmark)
    semilogy(snr_range, err_bench(a,:), ['-' markers{a}], ...
        'Color', colors(a,:), 'LineWidth', 1.5, 'MarkerSize', 7, ...
        'DisplayName', sprintf('%d BPM', fc_benchmark(a)));
    hold on;
end
yline(5, 'r--', 'Seuil 5 BPM');
xlabel('SNR d''entrée (dB)'); ylabel('Erreur absolue (BPM)');
title('Erreur en fonction du SNR');
legend('Location', 'best'); grid on;

subplot(1,2,2);
bpm_moy_plot = mean(bpm_all, 2, 'omitnan');
err_moy_plot = mean(erreurs_all, 2, 'omitnan');
errorbar(fc_tests, bpm_moy_plot, err_moy_plot, 'bo-', ...
    'LineWidth', 1.5, 'MarkerSize', 8);
hold on;
plot([20 200], [20 200], 'k--');
xlabel('BPM imposé'); ylabel('BPM mesuré');
title('Concordance BPM mesuré / imposé');
xlim([20 200]); ylim([20 200]); grid on;

fprintf('Tests terminés. Voir figures.\n');
