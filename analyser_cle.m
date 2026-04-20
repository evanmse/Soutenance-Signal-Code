%% ============================================================
%  ANALYSER_CLE.M
%  Analyse spectrale : fréquence dominante et SNR corrigé.
%  Groupe G2D – APP Signal 2025/2026
% ============================================================
function [freq_dom, snr_estime, bpm_estime] = analyser_cle(x, Fe)
% ANALYSER_CLE  Identifie le pic dominant et estime le SNR spectral.
%
% SYNTAXE :
%   [freq_dom, snr, bpm] = analyser_cle(x, Fe)
%
% ENTREES :
%   x  : signal (de préférence filtré dans la bande utile)
%   Fe : fréquence d'échantillonnage (Hz)
%
% SORTIES :
%   freq_dom    : fréquence dominante (Hz)
%   snr_estime  : SNR spectral estimé (dB)
%   bpm_estime  : fréquence dominante exprimée en BPM
%
% METHODE DE SNR (CORRIGEE) :
%   - On calcule le spectre de puissance |X|^2
%   - On identifie le pic principal et une zone de largeur ±Δ autour
%   - La puissance du pic = somme sur cette zone
%   - La puissance du bruit = somme sur le reste du spectre utile
%   - SNR = 10 log10( P_pic / P_bruit )

    N = length(x);

    % FFT normalisée
    X = fft(x) / N;

    % Spectre unilatéral
    Nhalf = floor(N/2) + 1;
    X_pos = abs(X(1:Nhalf));
    f_pos = (0:Nhalf-1) * (Fe / N);

    % Spectre de puissance
    P = X_pos.^2;

    % Recherche du pic dominant dans la bande cardiaque [0.5 - 3] Hz
    mask_band = (f_pos >= 0.5) & (f_pos <= 3.0);
    [~, rel_idx] = max(P(mask_band));
    idx_band = find(mask_band);
    idx_pic = idx_band(rel_idx);
    freq_dom = f_pos(idx_pic);

    % Zone autour du pic : ±3 bins (marge d'élargissement spectral)
    delta = 3;
    i1 = max(1, idx_pic - delta);
    i2 = min(Nhalf, idx_pic + delta);
    mask_pic = false(size(P));
    mask_pic(i1:i2) = true;

    % Puissance du pic et du bruit
    P_pic   = sum(P(mask_pic));
    P_bruit = sum(P(~mask_pic));

    if P_bruit <= 0
        P_bruit = eps;
    end

    snr_estime = 10 * log10(P_pic / P_bruit);
    bpm_estime = freq_dom * 60;

    if nargout == 0
        fprintf('Fréquence dominante : %.3f Hz (%.1f BPM)\n', freq_dom, bpm_estime);
        fprintf('SNR spectral estimé : %.2f dB\n', snr_estime);
    end

end
