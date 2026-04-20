%% ============================================================
%  DETECTER_ACTIVITE.M
%  Détection de la présence d'un signal cardiaque par estimation
%  de la puissance sur fenêtre glissante.
%  Groupe G2D – APP Signal 2025/2026
% ============================================================
function [detecte, puissance_estim] = detecter_activite(x_filt, Fe, fenetre_s, seuil_P)
% DETECTER_ACTIVITE  Décide si un signal cardiaque est présent.
%
% SYNTAXE :
%   [detecte, P] = detecter_activite(x_filt, Fe, fenetre_s, seuil_P)
%
% ENTREES :
%   x_filt    : signal APRES filtrage passe-bande [0.5-3] Hz
%   Fe        : fréquence d'échantillonnage (Hz)
%   fenetre_s : durée de la fenêtre glissante (s), typiquement 2
%   seuil_P   : seuil de puissance (sans unité, signal normalisé)
%
% SORTIES :
%   detecte         : booléen (true si activité détectée)
%   puissance_estim : puissance moyenne estimée
%
% JUSTIFICATION DU SEUIL :
%   Après normalisation (x / std(x)), un signal PPG réel a une
%   puissance ≈ 1. Après filtrage passe-bande [0.5-3] Hz d'un bruit
%   blanc seul de même variance, la puissance résiduelle est de l'ordre
%   de (3-0.5)/(Fe/2) ≈ 0.05. Le seuil est fixé à 0.15, soit 3× la
%   puissance du bruit seul, pour éviter les faux positifs.

    % Normalisation (robuste à l'échelle du capteur)
    x_norm = x_filt / (std(x_filt) + eps);

    % Demi-fenêtre en échantillons
    K = round(fenetre_s * Fe / 2);
    N = length(x_norm);

    if N < 2*K + 1
        warning('Signal trop court pour estimation fiable.');
        detecte = false;
        puissance_estim = 0;
        return;
    end

    % Puissance glissante
    puiss = zeros(N, 1);
    for n = K+1 : N-K
        fenetre = x_norm(n-K:n+K);
        puiss(n) = mean(fenetre.^2);
    end

    % Puissance moyenne sur la zone valide
    puissance_estim = mean(puiss(K+1:N-K));

    % Décision
    detecte = (puissance_estim > seuil_P);

end
