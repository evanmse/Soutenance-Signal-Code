function [pks, locs] = findpeaks_custom(x, varargin)
% FINDPEAKS_CUSTOM  Détection de pics sans Signal Processing Toolbox.
%
% SYNTAXE :
%   [pks, locs] = findpeaks_custom(x)
%   [pks, locs] = findpeaks_custom(x, 'MinPeakDistance', d, 'MinPeakProminence', p)
%
% ENTREES :
%   x                : vecteur de signal
%   'MinPeakDistance' : distance minimale entre pics (en échantillons)
%   'MinPeakProminence' : prominence minimale des pics
%
% SORTIES :
%   pks  : valeurs des pics détectés
%   locs : indices des pics détectés

    % Paramètres par défaut
    min_dist = 1;
    min_prom = 0;

    % Lecture des paires nom/valeur
    k = 1;
    while k <= length(varargin)
        if ischar(varargin{k})
            switch lower(varargin{k})
                case 'minpeakdistance'
                    min_dist = varargin{k+1};
                    k = k + 2;
                case 'minpeakprominence'
                    min_prom = varargin{k+1};
                    k = k + 2;
                otherwise
                    k = k + 1;
            end
        else
            k = k + 1;
        end
    end

    x = x(:)';
    N = length(x);

    % ── 1. Trouver tous les maxima locaux ─────────────────
    is_peak = false(1, N);
    for i = 2:N-1
        if x(i) > x(i-1) && x(i) > x(i+1)
            is_peak(i) = true;
        end
    end

    all_locs = find(is_peak);
    all_pks  = x(all_locs);

    if isempty(all_locs)
        pks = []; locs = [];
        return;
    end

    % ── 2. Filtrage par prominence ────────────────────────
    if min_prom > 0
        keep = false(size(all_locs));
        for i = 1:length(all_locs)
            idx = all_locs(i);
            val = x(idx);

            % Chercher le minimum à gauche jusqu'au prochain pic plus haut
            left_min = val;
            for j = idx-1:-1:1
                if x(j) > val
                    break;
                end
                left_min = min(left_min, x(j));
            end

            % Chercher le minimum à droite jusqu'au prochain pic plus haut
            right_min = val;
            for j = idx+1:N
                if x(j) > val
                    break;
                end
                right_min = min(right_min, x(j));
            end

            prominence = val - max(left_min, right_min);
            keep(i) = (prominence >= min_prom);
        end
        all_locs = all_locs(keep);
        all_pks  = x(all_locs);
    end

    if isempty(all_locs)
        pks = []; locs = [];
        return;
    end

    % ── 3. Filtrage par distance minimale (garder les plus hauts) ─
    if min_dist > 1
        % Trier par amplitude décroissante
        [~, order] = sort(all_pks, 'descend');
        sorted_locs = all_locs(order);

        selected = false(size(sorted_locs));
        for i = 1:length(sorted_locs)
            loc = sorted_locs(i);
            % Vérifier qu'aucun pic déjà sélectionné n'est trop proche
            too_close = false;
            for j = 1:i-1
                if selected(j) && abs(loc - sorted_locs(j)) < min_dist
                    too_close = true;
                    break;
                end
            end
            if ~too_close
                selected(i) = true;
            end
        end

        final_locs = sort(sorted_locs(selected));
    else
        final_locs = all_locs;
    end

    locs = final_locs;
    pks  = x(locs);

end
