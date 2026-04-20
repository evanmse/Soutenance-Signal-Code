/**
 * ============================================================
 *  bluetooth_uart.h
 *  Interface Bluetooth (HC-05/HC-06) via UART pour STM32F4
 *  Projet 1 – Mesure de la fréquence cardiaque
 *  Groupe G2D – APP Signal 2025/2026
 * ============================================================
 *
 *  Connexion matérielle :
 *    HC-05 TX  →  STM32 USART2_RX (PA3)
 *    HC-05 RX  →  STM32 USART2_TX (PA2)
 *    HC-05 VCC →  3.3V ou 5V
 *    HC-05 GND →  GND
 *
 *  Configuration UART : 9600 bauds, 8N1
 */

#ifndef BLUETOOTH_UART_H
#define BLUETOOTH_UART_H

#include <stdint.h>
#include <stdbool.h>

/* ── Structure des résultats à envoyer ──────────────────── */
typedef struct {
    bool     signal_detecte;   /* true si activité cardiaque présente */
    uint16_t bpm;              /* fréquence cardiaque (BPM)           */
    uint16_t rr_moy_ms;       /* intervalle RR moyen (ms)            */
    int16_t  snr_db;           /* SNR estimé (dB)                     */
    uint8_t  phase;            /* phase du système (0-3)              */
} ResultatFC_t;

/* Phases du système */
#define PHASE_ATTENTE     0    /* En attente de signal */
#define PHASE_ACQUISITION 1    /* Acquisition en cours (10 s) */
#define PHASE_TRAITEMENT  2    /* Filtrage + calcul BPM */
#define PHASE_RESULTAT    3    /* Résultat disponible */

/* ── Fonctions publiques ────────────────────────────────── */

/**
 * @brief  Initialise l'UART2 pour la communication Bluetooth.
 *         Doit être appelé une fois au démarrage (après HAL_Init).
 */
void BT_Init(void);

/**
 * @brief  Envoie les résultats de mesure vers le smartphone.
 * @param  res  Pointeur vers la structure de résultats.
 *
 * Trame envoyée : $FC,<état>,<bpm>,<rr>,<snr>,<phase>*<checksum>\r\n
 */
void BT_EnvoyerResultat(const ResultatFC_t *res);

/**
 * @brief  Envoie un message texte libre (pour debug ou rapport).
 * @param  msg  Chaîne de caractères terminée par '\0'.
 */
void BT_EnvoyerMessage(const char *msg);

/**
 * @brief  Envoie la phase courante du système.
 * @param  phase  Numéro de phase (PHASE_ATTENTE..PHASE_RESULTAT).
 */
void BT_EnvoyerPhase(uint8_t phase);

#endif /* BLUETOOTH_UART_H */
