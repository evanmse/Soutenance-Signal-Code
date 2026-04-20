%% ============================================================
%  GENERER_PPG_REEL.M
%  Génère des fichiers ppg_*.mat simulant des enregistrements
%  acquis sur la carte électronique (CAN 12 bits, Fe = 250 Hz).
%  Groupe G2D – APP Signal 2025/2026
% ============================================================
%  Ce script produit PLUSIEURS scénarios de signaux PPG :
%   1. Repos normal (~72 BPM)
%   2. Effort modéré (~110 BPM)
%   3. Bradycardie (~45 BPM)
%   4. Tachycardie (~160 BPM)
%   5. FC variable (repos → effort → récupération)
%   6. Pas de signal (bruit seul – doigt absent)
%
%  Chaque fichier est compatible avec charger_ppg_reel.m
%  (variable 'ppg', Fe = 250 Hz).
% ============================================================

clear; close all; clc;

fprintf('==========================================================\n');
fprintf('  GENERATION DE SIGNAUX PPG - 6 SCENARIOS                 \n');
fprintf('==========================================================\n\n');

rng(2026);

Fe_acq = 250;   % Hz – fréquence du CAN de la carte

% ── Définition des scénarios ──────────────────────────────
scenarios = struct();

scenarios(1).nom       = 'Repos normal';
scenarios(1).fichier   = 'ppg_reel.mat';
scenarios(1).duree_s   = 45;
scenarios(1).fc_bpm    = 72;
scenarios(1).hrv_ms    = 25;
scenarios(1).snr_db    = 25;
scenarios(1).artefacts = true;
scenarios(1).variable  = false;   % FC constante

scenarios(2).nom       = 'Effort modere';
scenarios(2).fichier   = 'ppg_effort.mat';
scenarios(2).duree_s   = 30;
scenarios(2).fc_bpm    = 110;
scenarios(2).hrv_ms    = 15;
scenarios(2).snr_db    = 20;
scenarios(2).artefacts = true;
scenarios(2).variable  = false;

scenarios(3).nom       = 'Bradycardie';
scenarios(3).fichier   = 'ppg_bradycardie.mat';
scenarios(3).duree_s   = 30;
scenarios(3).fc_bpm    = 45;
scenarios(3).hrv_ms    = 35;
scenarios(3).snr_db    = 25;
scenarios(3).artefacts = false;
scenarios(3).variable  = false;

scenarios(4).nom       = 'Tachycardie';
scenarios(4).fichier   = 'ppg_tachycardie.mat';
scenarios(4).duree_s   = 30;
scenarios(4).fc_bpm    = 160;
scenarios(4).hrv_ms    = 10;
scenarios(4).snr_db    = 18;
scenarios(4).artefacts = true;
scenarios(4).variable  = false;

scenarios(5).nom       = 'FC variable (repos-effort-recup)';
scenarios(5).fichier   = 'ppg_variable.mat';
scenarios(5).duree_s   = 60;
scenarios(5).fc_bpm    = [65 130 80];   % 3 phases
scenarios(5).hrv_ms    = 20;
scenarios(5).snr_db    = 22;
scenarios(5).artefacts = true;
scenarios(5).variable  = true;

scenarios(6).nom       = 'Pas de signal (bruit seul)';
scenarios(6).fichier   = 'ppg_bruit.mat';
scenarios(6).duree_s   = 15;
scenarios(6).fc_bpm    = 0;
scenarios(6).hrv_ms    = 0;
scenarios(6).snr_db    = 0;
scenarios(6).artefacts = false;
scenarios(6).variable  = false;

% ── Génération de chaque scénario ─────────────────────────
for s = 1:length(scenarios)
    sc = scenarios(s);
    fprintf('  [%d/%d] %s\n', s, length(scenarios), sc.nom);
    fprintf('        Fichier : %s\n', sc.fichier);

    duree_s = sc.duree_s;
    N_total = Fe_acq * duree_s;
    t = (0:N_total-1) / Fe_acq;

    % --- Cas spécial : bruit seul (pas de signal cardiaque) ---
    if sc.fc_bpm == 0
        ppg_clean = zeros(1, N_total);
        drift = 0.05 * sin(2*pi*0.1*t);
        bruit = 0.3 * randn(1, N_total);
        ppg_analog = 2048 + 200 * (drift + bruit);
        ppg = uint16(max(0, min(4095, round(ppg_analog))));
        save(sc.fichier, 'ppg');
        fprintf('        → Bruit seul, %d échantillons\n\n', N_total);
        continue;
    end

    % --- Génération des battements ---
    if sc.variable
        % FC variable : 3 phases égales
        fc_phases = sc.fc_bpm;
        n_phases = length(fc_phases);
        phase_dur = duree_s / n_phases;
    end

    RR_moy = 60 / sc.fc_bpm(1);
    HRV_std = sc.hrv_ms / 1000;
    rr_list = [];
    tc = 0.5;

    while tc < duree_s - 1
        % FC variable : changer la FC selon la phase
        if sc.variable
            phase_idx = min(n_phases, floor(tc / phase_dur) + 1);
            RR_moy = 60 / fc_phases(phase_idx);
        end

        rr_resp = 0.03 * sin(2*pi*0.25*tc);
        rr_rand = HRV_std * randn;
        rr = RR_moy + rr_resp + rr_rand;
        rr = max(rr, 0.33);
        rr = min(rr, 2.0);
        rr_list = [rr_list, rr];
        tc = tc + rr;
    end

    n_beats = length(rr_list);
    t_beats = cumsum([0.5, rr_list(1:end-1)]);

    % --- Forme d'onde PPG ---
    ppg_clean = zeros(1, N_total);
    for k = 1:n_beats
        tb = t_beats(k);
        amp_sys = 0.9 + 0.1*randn;
        sigma_sys = 0.06 + 0.005*randn;
        ppg_clean = ppg_clean + amp_sys * exp(-((t - tb).^2) / (2*sigma_sys^2));

        amp_dic = 0.30 + 0.05*randn;
        delay_dic = 0.22 + 0.02*randn;
        sigma_dic = 0.08 + 0.005*randn;
        ppg_clean = ppg_clean + amp_dic * exp(-((t - tb - delay_dic).^2) / (2*sigma_dic^2));

        amp_dia = 0.15 + 0.03*randn;
        delay_dia = 0.40 + 0.03*randn;
        ppg_clean = ppg_clean + amp_dia * exp(-((t - tb - delay_dia).^2) / (2*0.12^2));
    end

    % --- Dérive basale ---
    drift = 0.15 * sin(2*pi*0.20*t + pi/4) ...
          + 0.08 * sin(2*pi*0.02*t) ...
          + 0.05 * t / duree_s;

    % --- Bruit ---
    P_sig = mean(ppg_clean.^2);
    P_bruit = P_sig / 10^(sc.snr_db/10);
    bruit = sqrt(P_bruit) * randn(1, N_total) + 0.02*sin(2*pi*50*t + rand*2*pi);

    % --- Artefacts ---
    artefact = zeros(1, N_total);
    if sc.artefacts && duree_s > 10
        t_art1 = round(duree_s * 0.2 * Fe_acq);
        len_art = round(0.3 * Fe_acq);
        if t_art1 + len_art - 1 <= N_total
            artefact(t_art1:t_art1+len_art-1) = 0.8 * randn(1, len_art);
        end
        t_art2 = round(duree_s * 0.6 * Fe_acq);
        if t_art2 + len_art - 1 <= N_total
            artefact(t_art2:t_art2+len_art-1) = 0.6 * randn(1, len_art);
        end
    end

    % --- Signal final CAN 12 bits ---
    ppg_analog = 2048 + 200 * (ppg_clean + drift + bruit + artefact);
    ppg = uint16(max(0, min(4095, round(ppg_analog))));

    % --- Sauvegarde ---
    save(sc.fichier, 'ppg');

    fc_eff = 60 / mean(rr_list);
    fprintf('        → FC ≈ %.0f BPM, %d battements, SNR = %d dB, %d éch.\n\n', ...
            fc_eff, n_beats, sc.snr_db, N_total);
end

% ── Tableau récapitulatif ─────────────────────────────────
fprintf('  ┌────┬──────────────────────────────┬────────────────────────┬──────────┐\n');
fprintf('  │ N° │ Scénario                     │ Fichier                │ FC (BPM) │\n');
fprintf('  ├────┼──────────────────────────────┼────────────────────────┼──────────┤\n');
for s = 1:length(scenarios)
    sc = scenarios(s);
    if sc.fc_bpm == 0
        fc_str = '---';
    elseif sc.variable
        fc_str = sprintf('%d→%d→%d', sc.fc_bpm(1), sc.fc_bpm(2), sc.fc_bpm(3));
    else
        fc_str = sprintf('%d', sc.fc_bpm);
    end
    fprintf('  │ %2d │ %-28s │ %-22s │ %-8s │\n', s, sc.nom, sc.fichier, fc_str);
end
fprintf('  └────┴──────────────────────────────┴────────────────────────┴──────────┘\n\n');

fprintf('  Pour analyser un scénario :\n');
fprintf('  >> charger_ppg_reel        (charge ppg_reel.mat par défaut)\n');
fprintf('  >> Modifier FICHIER dans charger_ppg_reel.m pour les autres\n\n');
fprintf('==========================================================\n');
