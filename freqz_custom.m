function [H, f] = freqz_custom(h, dummy, Nfft, Fe)
% FREQZ_CUSTOM  Réponse en fréquence d'un filtre RIF, sans Toolbox.
%
% SYNTAXE :
%   [H, f] = freqz_custom(h, 1, Nfft, Fe)
%
% ENTREES :
%   h    : coefficients du filtre RIF
%   dummy: ignoré (compatibilité avec freqz(h,1,...))
%   Nfft : nombre de points fréquentiels
%   Fe   : fréquence d'échantillonnage (Hz)
%
% SORTIES :
%   H : réponse en fréquence complexe (Nfft/2+1 points, 0 à Fe/2)
%   f : vecteur de fréquences correspondant (Hz)

    if nargin < 3, Nfft = 4096; end
    if nargin < 4, Fe = 2*pi; end

    Nhalf = floor(Nfft/2) + 1;
    f = (0:Nhalf-1)' * (Fe / Nfft);

    M = length(h);
    n = 0:M-1;

    H = zeros(Nhalf, 1);
    for k = 1:Nhalf
        omega = 2 * pi * f(k) / Fe;
        H(k) = sum(h .* exp(-1j * omega * n));
    end

end
