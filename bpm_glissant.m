%% ============================================================
%  BPM_GLISSANT.M
%  Mesure du BPM en continu par fenêtres glissantes (OPTION).
%  Groupe G2D – APP Signal 2025/2026
% ============================================================
%  Principe :
%   - Fenêtre de 10 s glissée par pas de 1 s
%   - Pour chaque fenêtre : filtrage + détection pics + calcul BPM
%   - Courbe BPM(t) permettant de suivre les variations de FC
% ============================================================

function [bpm_t, t_centres] = bpm_glissant(x_raw, Fe, win_s, hop_s)
% BPM_GLISSANT  BPM en fonction du temps, par fenêtres glissantes.
%
% SYNTAXE :
%   [bpm_t, t_centres] = bpm_glissant(x_raw, Fe, win_s, hop_s)
%
% ENTREES :
%   x_raw  : signal PPG brut (vecteur ligne ou colonne)
%   Fe     : fréquence d'échantillonnage (Hz)
%   win_s  : durée de la fenêtre (s), typiquement 10
%   hop_s  : pas d'avancement (s), typiquement 1
%
% SORTIES :
%   bpm_t     : BPM mesuré pour chaque fenêtre
%   t_centres : temps central de chaque fenêtre (s)

    if nargin < 4
        hop_s = 1;
    end
    if nargin < 3
        win_s = 10;
    end

    params = parametres_projet();
    h = params.h_filtre;
    delay = params.ordre_filtre / 2;

    x_raw = x_raw(:)';
    N_win = round(win_s * Fe);
    N_hop = round(hop_s * Fe);
    Ntot  = length(x_raw);

    if Ntot < N_win
        error('Signal trop court pour une fenêtre de %d s.', win_s);
    end

    starts = 1 : N_hop : (Ntot - N_win + 1);
    bpm_t     = nan(1, length(starts));
    t_centres = nan(1, length(starts));

    for k = 1 : length(starts)
        idx = starts(k) : starts(k) + N_win - 1;
        xw  = x_raw(idx);
        xw  = (xw - mean(xw)) / std(xw);
        xf  = filter(h, 1, xw);
        xa  = [xf(delay+1:end), zeros(1, delay)];

        [~, pks] = findpeaks(xa, ...
            'MinPeakDistance',   params.distance_min_samples, ...
            'MinPeakProminence', params.prominence_rel * max(xa));

        if length(pks) >= 2
            RR = diff(pks) / Fe;
            bpm_t(k) = 60 / mean(RR);
        end
        t_centres(k) = (starts(k) + N_win/2 - 1) / Fe;
    end

    % Affichage si pas de sortie demandée
    if nargout == 0
        figure('Name', 'BPM glissant');
        plot(t_centres, bpm_t, 'bo-', 'LineWidth', 1.5, 'MarkerSize', 6);
        xlabel('Temps (s)');
        ylabel('BPM');
        title(sprintf('Fréquence cardiaque instantanée (fenêtre %d s, pas %d s)', ...
              win_s, hop_s));
        grid on;
        ylim([30 180]);
    end

end
