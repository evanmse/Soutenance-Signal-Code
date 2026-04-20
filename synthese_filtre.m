%% ============================================================
%  SYNTHESE_FILTRE.M
%  Synthèse du filtre RIF passe-bande par la méthode de Parks-McClellan
%  (algorithme de Remez, équiondulation).
%  Groupe G2D – APP Signal 2025/2026
% ============================================================
function [h, ordre] = synthese_filtre(params)
% SYNTHESE_FILTRE  Construit le filtre RIF correspondant au gabarit.
%
% SYNTAXE :
%   [h, ordre] = synthese_filtre(params)
%
% ENTREE :
%   params : structure retournée par parametres_projet()
%
% SORTIES :
%   h     : vecteur des coefficients du filtre RIF
%   ordre : ordre effectif du filtre (longueur de h moins 1)
%
% METHODE :
%   Utilisation de firpmord() pour estimer l'ordre minimum puis de firpm()
%   (Parks-McClellan) pour la synthèse. En repli, fir1() avec une fenêtre
%   de Hamming si firpm n'est pas disponible.

    Fe  = params.Fe;
    fs1 = params.fs1;   fp1 = params.fp1;
    fp2 = params.fp2;   fs2 = params.fs2;

    % Conversion des amplitudes dB → linéaire
    dev_pass = (10^(params.Apass/20) - 1) / (10^(params.Apass/20) + 1);
    dev_stop = 10^(-params.Astop/20);

    try
        % --- Estimation de l'ordre minimum ---
        [n_est, fo, ao, w] = firpmord([fs1 fp1 fp2 fs2], [0 1 0], ...
            [dev_stop dev_pass dev_stop], Fe);

        % On arrondit à l'entier pair supérieur (filtre de type I)
        n_est = 2 * ceil(n_est / 2);

        % Synthèse par Parks-McClellan
        h = firpm(n_est, fo, ao, w);
        ordre = length(h) - 1;

    catch
        % Repli si Signal Processing Toolbox non complète
        ordre_fallback = 100;
        h = fir1(ordre_fallback, [fp1 fp2] / (Fe/2), 'bandpass', hamming(ordre_fallback+1));
        ordre = ordre_fallback;
        warning('firpm indisponible, repli fir1 avec ordre %d', ordre);
    end

    % Vérification du gabarit a posteriori (optionnel, affiché si pas de sortie)
    if nargout == 0
        [H, f] = freqz(h, 1, 4096, Fe);
        Hdb = 20*log10(abs(H) + 1e-12);
        fprintf('Filtre RIF : ordre %d\n', ordre);
        fprintf('  Atténuation max en bande atténuée basse : %.1f dB\n', ...
                max(Hdb(f <= fs1)));
        fprintf('  Atténuation max en bande atténuée haute : %.1f dB\n', ...
                max(Hdb(f >= fs2)));
        fprintf('  Ondulation max en bande passante        : %.3f dB\n', ...
                max(Hdb(f >= fp1 & f <= fp2)) - min(Hdb(f >= fp1 & f <= fp2)));
    end

end
