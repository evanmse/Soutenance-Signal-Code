/**
 * ============================================================
 *  bluetooth_uart.c
 *  Implémentation Bluetooth (HC-05/HC-06) via UART pour STM32F4
 *  Projet 1 – Mesure de la fréquence cardiaque
 *  Groupe G2D – APP Signal 2025/2026
 * ============================================================
 *
 *  Utilise HAL UART (USART2) à 9600 bauds, 8N1.
 *  Le module HC-05 est configuré en mode esclave par défaut.
 *
 *  Protocole de trame :
 *    $FC,<état>,<bpm>,<rr_ms>,<snr_db>,<phase>*<checksum_XOR>\r\n
 *
 *  Exemple : $FC,OK,72,833,25,3*4A\r\n
 */

#include "bluetooth_uart.h"
#include "stm32f4xx_hal.h"
#include <stdio.h>
#include <string.h>

/* ── Handle UART (déclaré extern si initialisé dans main.c) ─ */
static UART_HandleTypeDef huart_bt;

/* ── Buffer d'émission ──────────────────────────────────── */
#define BT_TX_BUF_SIZE 128
static char bt_tx_buf[BT_TX_BUF_SIZE];

/* ── Timeout UART (ms) ──────────────────────────────────── */
#define BT_TIMEOUT_MS  100

/* ================================================================
 *  Fonctions internes
 * ================================================================ */

/**
 * @brief  Calcule le checksum XOR d'une chaîne (entre $ et *).
 */
static uint8_t calcul_checksum(const char *payload, uint16_t len)
{
    uint8_t chk = 0;
    for (uint16_t i = 0; i < len; i++) {
        chk ^= (uint8_t)payload[i];
    }
    return chk;
}

/**
 * @brief  Envoie une chaîne via UART (bloquant).
 */
static void uart_send(const char *data, uint16_t len)
{
    HAL_UART_Transmit(&huart_bt, (uint8_t *)data, len, BT_TIMEOUT_MS);
}

/* ================================================================
 *  Fonctions publiques
 * ================================================================ */

void BT_Init(void)
{
    /* Configuration USART2 : PA2 (TX), PA3 (RX) */
    __HAL_RCC_USART2_CLK_ENABLE();
    __HAL_RCC_GPIOA_CLK_ENABLE();

    GPIO_InitTypeDef gpio = {0};
    gpio.Pin       = GPIO_PIN_2 | GPIO_PIN_3;
    gpio.Mode      = GPIO_MODE_AF_PP;
    gpio.Pull      = GPIO_PULLUP;
    gpio.Speed     = GPIO_SPEED_FREQ_HIGH;
    gpio.Alternate = GPIO_AF7_USART2;
    HAL_GPIO_Init(GPIOA, &gpio);

    huart_bt.Instance          = USART2;
    huart_bt.Init.BaudRate     = 9600;
    huart_bt.Init.WordLength   = UART_WORDLENGTH_8B;
    huart_bt.Init.StopBits     = UART_STOPBITS_1;
    huart_bt.Init.Parity       = UART_PARITY_NONE;
    huart_bt.Init.Mode         = UART_MODE_TX_RX;
    huart_bt.Init.HwFlowCtl    = UART_HWCONTROL_NONE;
    huart_bt.Init.OverSampling = UART_OVERSAMPLING_16;

    HAL_UART_Init(&huart_bt);

    /* Message de démarrage */
    BT_EnvoyerMessage("G2D CardioMonitor v1.0 - Pret");
}

void BT_EnvoyerResultat(const ResultatFC_t *res)
{
    const char *etat = res->signal_detecte ? "OK" : "NO";

    /* Construction du payload (sans $ ni *checksum) */
    char payload[80];
    int plen = snprintf(payload, sizeof(payload), "FC,%s,%u,%u,%d,%u",
                        etat,
                        (unsigned)res->bpm,
                        (unsigned)res->rr_moy_ms,
                        (int)res->snr_db,
                        (unsigned)res->phase);

    /* Checksum XOR sur le payload */
    uint8_t chk = calcul_checksum(payload, (uint16_t)plen);

    /* Trame complète : $<payload>*<checksum>\r\n */
    int total = snprintf(bt_tx_buf, BT_TX_BUF_SIZE,
                         "$%s*%02X\r\n", payload, chk);

    uart_send(bt_tx_buf, (uint16_t)total);
}

void BT_EnvoyerMessage(const char *msg)
{
    int len = snprintf(bt_tx_buf, BT_TX_BUF_SIZE, "$MSG,%s\r\n", msg);
    uart_send(bt_tx_buf, (uint16_t)len);
}

void BT_EnvoyerPhase(uint8_t phase)
{
    static const char *noms_phase[] = {
        "ATTENTE",
        "ACQUISITION",
        "TRAITEMENT",
        "RESULTAT"
    };

    const char *nom = (phase <= PHASE_RESULTAT) ? noms_phase[phase] : "INCONNU";
    int len = snprintf(bt_tx_buf, BT_TX_BUF_SIZE,
                       "$PHASE,%u,%s\r\n", (unsigned)phase, nom);
    uart_send(bt_tx_buf, (uint16_t)len);
}
