%% ============================================================
%  BLUETOOTH_STM32.M
%  Simulation de l'envoi Bluetooth des résultats vers smartphone
%  + Génération du code C embarqué pour STM32F4 (UART → HC-05)
%  Groupe G2D – APP Signal 2025/2026
% ============================================================
%  Ce script :
%   1. Simule la trame envoyée en Bluetooth (protocole texte)
%   2. Génère le code C prêt à compiler pour STM32
%   3. Affiche un exemple d'interface smartphone
% ============================================================

function bluetooth_stm32(BPM, actif, RR_moy_ms, snr_db)
% BLUETOOTH_STM32  Simule et génère l'envoi Bluetooth des résultats.
%
% SYNTAXE :
%   bluetooth_stm32(BPM, actif, RR_moy_ms, snr_db)
%
% ENTREES :
%   BPM       : fréquence cardiaque mesurée (BPM)
%   actif     : booléen, true si signal cardiaque détecté
%   RR_moy_ms : intervalle RR moyen (ms)
%   snr_db    : SNR estimé (dB)

    if nargin < 4, snr_db = 0; end
    if nargin < 3, RR_moy_ms = 0; end
    if nargin < 2, actif = true; end

    fprintf('\n');
    fprintf('  ╔═══════════════════════════════════════════════════╗\n');
    fprintf('  ║       ENVOI BLUETOOTH (UART → HC-05/BLE)         ║\n');
    fprintf('  ╚═══════════════════════════════════════════════════╝\n\n');

    % ── 1. Construction de la trame ───────────────────────
    % Format texte simple (compatible terminal série smartphone)
    % Protocole : $FC,<status>,<bpm>,<rr_ms>,<snr>*<checksum>\r\n
    
    if actif
        status_str = 'OK';
    else
        status_str = 'NO';
    end
    
    payload = sprintf('$FC,%s,%d,%d,%d', status_str, round(BPM), ...
                      round(RR_moy_ms), round(snr_db));
    
    % Checksum XOR (standard NMEA)
    chk = 0;
    for i = 2:length(payload)   % skip $
        chk = bitxor(chk, uint8(payload(i)));
    end
    
    trame = sprintf('%s*%02X\r\n', payload, chk);
    
    fprintf('  1. TRAME BLUETOOTH\n');
    fprintf('  ┌──────────────────────────────────────────────────┐\n');
    fprintf('  │  Protocole : texte NMEA-like (UART 9600 bauds)  │\n');
    fprintf('  │  Format    : $FC,<état>,<bpm>,<rr>,<snr>*<chk>  │\n');
    fprintf('  │                                                  │\n');
    fprintf('  │  Trame envoyée :                                 │\n');
    fprintf('  │  → %s', trame);
    fprintf('  │                                                  │\n');
    fprintf('  │  Champ    Valeur       Signification             │\n');
    fprintf('  │  ───────  ───────────  ────────────────────────  │\n');
    fprintf('  │  $FC      en-tête      identifiant du message    │\n');
    fprintf('  │  %s       état         %s             │\n', status_str, ...
            ternaire(actif, 'signal détecté    ', 'pas de signal     '));
    fprintf('  │  %d      BPM          fréquence cardiaque       │\n', round(BPM));
    fprintf('  │  %d     RR (ms)      intervalle moyen           │\n', round(RR_moy_ms));
    fprintf('  │  %d      SNR (dB)     qualité du signal         │\n', round(snr_db));
    fprintf('  │  *%02X     checksum     vérification XOR          │\n', chk);
    fprintf('  └──────────────────────────────────────────────────┘\n\n');

    % ── 2. Simulation interface smartphone ────────────────
    fprintf('  2. AFFICHAGE SMARTPHONE (simulé)\n');
    fprintf('  ┌────────────────────────────────────┐\n');
    fprintf('  │      ♥ Cardio Monitor G2D          │\n');
    fprintf('  │                                    │\n');
    if actif
        fprintf('  │   État : ● SIGNAL DETECTE          │\n');
        fprintf('  │                                    │\n');
        fprintf('  │        ╔═══════════╗               │\n');
        fprintf('  │        ║  %3d BPM  ║               │\n', round(BPM));
        fprintf('  │        ╚═══════════╝               │\n');
        fprintf('  │                                    │\n');
        fprintf('  │   RR moyen : %d ms                 │\n', round(RR_moy_ms));
        fprintf('  │   SNR      : %d dB                 │\n', round(snr_db));
    else
        fprintf('  │   État : ○ PAS DE SIGNAL           │\n');
        fprintf('  │                                    │\n');
        fprintf('  │   Placez votre doigt sur le        │\n');
        fprintf('  │   capteur optique...               │\n');
    end
    fprintf('  │                                    │\n');
    fprintf('  └────────────────────────────────────┘\n\n');

    % ── 3. Affichage OLED (simulé, 128x64) ───────────────
    fprintf('  3. AFFICHAGE OLED 128x64 (simulé)\n');
    fprintf('  ┌────────────────────────┐\n');
    if actif
        fprintf('  │ FC: %3d BPM    ♥ ON   │\n', round(BPM));
        fprintf('  │ RR: %3d ms            │\n', round(RR_moy_ms));
        fprintf('  │ SNR: %2d dB    [====] │\n', round(snr_db));
    else
        fprintf('  │ FC: --- BPM    ♥ OFF  │\n');
        fprintf('  │ Pas de signal         │\n');
        fprintf('  │ LED: éteinte          │\n');
    end
    fprintf('  └────────────────────────┘\n\n');

end

function s = ternaire(cond, si_vrai, si_faux)
    if cond, s = si_vrai; else, s = si_faux; end
end
