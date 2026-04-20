/**
 * ============================================================
 *  main_exemple.c
 *  Exemple d'intégration : boucle principale STM32
 *  Projet 1 – Mesure de la fréquence cardiaque
 *  Groupe G2D – APP Signal 2025/2026
 * ============================================================
 *
 *  Cet exemple montre comment utiliser bluetooth_uart.h
 *  dans la boucle principale du microcontrôleur.
 *
 *  Architecture :
 *    Timer → ISR acquisition ADC (Fe = 100 Hz)
 *    Main loop → traitement quand buffer plein (10 s)
 *    UART2 → envoi résultats vers HC-05 → smartphone
 *    GPIO → LED activité + afficheur OLED
 */

#include "stm32f4xx_hal.h"
#include "bluetooth_uart.h"
#include <stdbool.h>

/* ── Paramètres du système (identiques à MATLAB) ────────── */
#define FE              100     /* Hz */
#define DUREE_ANALYSE   10      /* secondes */
#define N_ECHANTILLONS  (FE * DUREE_ANALYSE)  /* 1000 */
#define ORDRE_FILTRE    74      /* à adapter selon synthese_filtre.m */

/* ── Buffers ────────────────────────────────────────────── */
static int16_t  buffer_adc[N_ECHANTILLONS];
static float    buffer_filtre[N_ECHANTILLONS];
static volatile uint16_t idx_acq = 0;
static volatile bool     buffer_pret = false;

/* ── Coefficients du filtre (exportés depuis MATLAB) ────── */
/* Remplacer par les valeurs de h = params.h_filtre            */
/* Commande MATLAB : fprintf('%.10ff,\n', h)                   */
extern const float h_filtre[ORDRE_FILTRE + 1];

/* ── LED activité ───────────────────────────────────────── */
#define LED_ACTIVITE_PIN   GPIO_PIN_13
#define LED_ACTIVITE_PORT  GPIOC

static void LED_Set(bool on)
{
    HAL_GPIO_WritePin(LED_ACTIVITE_PORT, LED_ACTIVITE_PIN,
                      on ? GPIO_PIN_SET : GPIO_PIN_RESET);
}

/* ================================================================
 *  ISR : acquisition ADC (appelée par Timer à 100 Hz)
 * ================================================================ */
void HAL_ADC_ConvCpltCallback(ADC_HandleTypeDef *hadc)
{
    if (!buffer_pret && idx_acq < N_ECHANTILLONS) {
        buffer_adc[idx_acq] = (int16_t)(HAL_ADC_GetValue(hadc) - 2048);
        idx_acq++;

        if (idx_acq >= N_ECHANTILLONS) {
            buffer_pret = true;
        }
    }
}

/* ================================================================
 *  Traitement : filtrage RIF
 * ================================================================ */
static void filtrage_rif(const int16_t *x, float *y, uint16_t n)
{
    for (uint16_t i = 0; i < n; i++) {
        float acc = 0.0f;
        for (uint16_t k = 0; k <= ORDRE_FILTRE; k++) {
            int idx = (int)i - (int)k;
            if (idx >= 0) {
                acc += h_filtre[k] * (float)x[idx];
            }
        }
        y[i] = acc;
    }
}

/* ================================================================
 *  Traitement : détection d'activité (puissance)
 * ================================================================ */
static bool detecter_activite(const float *y, uint16_t n, float seuil)
{
    float puissance = 0.0f;
    for (uint16_t i = 0; i < n; i++) {
        puissance += y[i] * y[i];
    }
    puissance /= (float)n;
    return (puissance > seuil);
}

/* ================================================================
 *  Traitement : détection de pics et calcul BPM
 * ================================================================ */
static uint16_t calculer_bpm(const float *y, uint16_t n,
                              uint16_t dist_min, float prom_rel,
                              uint16_t *rr_moy_ms)
{
    /* Trouver le max pour le seuil de prominence */
    float ymax = 0.0f;
    for (uint16_t i = 0; i < n; i++) {
        if (y[i] > ymax) ymax = y[i];
    }
    float seuil_prom = prom_rel * ymax;

    /* Détection des pics locaux */
    uint16_t pics[64];
    uint16_t n_pics = 0;

    for (uint16_t i = dist_min; i < n - 1 && n_pics < 64; i++) {
        if (y[i] > y[i-1] && y[i] > y[i+1] && y[i] > seuil_prom) {
            /* Vérifier distance min avec le pic précédent */
            if (n_pics == 0 || (i - pics[n_pics - 1]) >= dist_min) {
                pics[n_pics++] = i;
            }
        }
    }

    if (n_pics < 2) {
        *rr_moy_ms = 0;
        return 0;
    }

    /* Calcul du RR moyen */
    uint32_t rr_sum = 0;
    for (uint16_t i = 1; i < n_pics; i++) {
        rr_sum += (pics[i] - pics[i-1]);
    }
    float rr_moy_samples = (float)rr_sum / (float)(n_pics - 1);
    float rr_moy_sec = rr_moy_samples / (float)FE;

    *rr_moy_ms = (uint16_t)(rr_moy_sec * 1000.0f);
    return (uint16_t)(60.0f / rr_moy_sec);
}

/* ================================================================
 *  Boucle principale
 * ================================================================ */
int main(void)
{
    HAL_Init();
    /* SystemClock_Config(); -- à implémenter selon votre carte */

    /* Initialisation Bluetooth */
    BT_Init();
    BT_EnvoyerPhase(PHASE_ATTENTE);
    LED_Set(false);

    ResultatFC_t resultat = {0};

    while (1) {

        /* ── Phase 1 : Attente et acquisition ─────────── */
        if (!buffer_pret) {
            if (idx_acq == 0) {
                resultat.phase = PHASE_ATTENTE;
                BT_EnvoyerPhase(PHASE_ATTENTE);
            } else {
                resultat.phase = PHASE_ACQUISITION;
                /* Envoi progression toutes les 2 secondes */
                if (idx_acq % (2 * FE) == 0) {
                    BT_EnvoyerPhase(PHASE_ACQUISITION);
                }
            }
            continue;
        }

        /* ── Phase 2 : Traitement ─────────────────────── */
        resultat.phase = PHASE_TRAITEMENT;
        BT_EnvoyerPhase(PHASE_TRAITEMENT);

        /* Filtrage RIF passe-bande */
        filtrage_rif(buffer_adc, buffer_filtre, N_ECHANTILLONS);

        /* Détection d'activité */
        resultat.signal_detecte = detecter_activite(
            buffer_filtre, N_ECHANTILLONS, 0.15f);

        LED_Set(resultat.signal_detecte);

        if (resultat.signal_detecte) {
            /* Calcul du BPM */
            resultat.bpm = calculer_bpm(
                buffer_filtre, N_ECHANTILLONS,
                28,     /* distance_min = 280 ms × 100 Hz = 28 */
                0.40f,  /* prominence relative */
                &resultat.rr_moy_ms);
        } else {
            resultat.bpm = 0;
            resultat.rr_moy_ms = 0;
        }

        /* ── Phase 3 : Envoi des résultats ────────────── */
        resultat.phase = PHASE_RESULTAT;
        BT_EnvoyerResultat(&resultat);

        /* TODO : afficher sur OLED
         * OLED_AfficherBPM(resultat.bpm);
         * OLED_AfficherEtat(resultat.signal_detecte);
         */

        /* Réinitialisation pour le prochain bloc */
        buffer_pret = false;
        idx_acq = 0;

        HAL_Delay(100);
    }
}
