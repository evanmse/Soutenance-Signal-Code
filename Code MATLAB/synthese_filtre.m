%% ============================================================
%  SYNTHESE_FILTRE.M
%  Synthèse du filtre RIF passe-bande par méthode fenêtrée
%  (fenêtre de Hamming, SANS Signal Processing Toolbox).
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
%   Filtre passe-bande = différence de deux passe-bas (sinc fenêtré).
%   Fenêtre de Hamming calculée manuellement (0.54 - 0.46*cos).
%   L'ordre est estimé par la formule de Kaiser.

    Fe  = params.Fe;
    fp1 = params.fp1;   fp2 = params.fp2;
    fs1 = params.fs1;   fs2 = params.fs2;
    Astop = params.Astop;

    % ── Estimation de l'ordre par la formule de Kaiser ────
    delta_f1 = (fp1 - fs1) / Fe;
    delta_f2 = (fs2 - fp2) / Fe;
    delta_f  = min(delta_f1, delta_f2);

    if Astop > 21
        ordre = ceil((Astop - 7.95) / (14.36 * delta_f));
    else
        ordre = ceil(0.9222 / delta_f);
    end

    % Arrondir à l'entier pair (filtre de type I, phase linéaire)
    if mod(ordre, 2) ~= 0
        ordre = ordre + 1;
    end

    M = ordre;
    L = M + 1;

    % ── Fréquences de coupure normalisées (0 à 0.5) ──────
    fc1 = (fs1 + fp1) / 2 / Fe;
    fc2 = (fp2 + fs2) / 2 / Fe;

    % ── Fenêtre de Hamming (manuelle) ─────────────────────
    n = 0:M;
    w = 0.54 - 0.46 * cos(2*pi*n / M);

    % ── Réponse impulsionnelle idéale (sinc fenêtré) ──────
    n_centered = n - M/2;
    h_lp1 = zeros(1, L);
    h_lp2 = zeros(1, L);

    for k = 1:L
        if n_centered(k) == 0
            h_lp1(k) = 2 * fc1;
            h_lp2(k) = 2 * fc2;
        else
            h_lp1(k) = sin(2*pi*fc1*n_centered(k)) / (pi*n_centered(k));
            h_lp2(k) = sin(2*pi*fc2*n_centered(k)) / (pi*n_centered(k));
        end
    end

    % Passe-bande = différence des deux passe-bas
    h_bp = h_lp2 - h_lp1;

    % Application de la fenêtre
    h = h_bp .* w;

    % Normalisation (gain unitaire au centre de la bande passante)
    f_centre = (fp1 + fp2) / 2;
    omega_c = 2 * pi * f_centre / Fe;
    gain = abs(sum(h .* exp(-1j * omega_c * (0:M))));
    h = h / gain;

end
