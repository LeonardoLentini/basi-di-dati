# FilmSphere Database

## 📋 Descrizione del Progetto
Questo progetto consiste nella progettazione e implementazione di un **database relazionale** per **FilmSphere**, un servizio fittizio di memorizzazione e streaming di film online, sviluppato come progetto per il corso di **Basi di Dati** (Ingegneria Informatica, A.A. 2022-2023).

Il database gestisce il catalogo dei film (cast, regia, premi, lingue audio e sottotitoli), i formati audio/video in cui sono rilasciati, gli utenti con i relativi abbonamenti, fatture e cronologia di visione, e la rete di server CDN che distribuisce i contenuti a livello globale.

Il progetto copre l'intero ciclo di progettazione:
* **Progettazione Concettuale:** Schema E-R suddiviso in quattro aree (Contenuti, Formati, Cliente, Streaming), prima e dopo la ristrutturazione.
* **Progettazione Logica:** Tavola dei volumi, analisi delle ridondanze, traduzione nel modello relazionale e normalizzazione (BCNF).
* **Logica Attiva:** Trigger per vincoli di integrità e attributi derivati (es. età minima, stato e bilanciamento dei server CDN, ore residue dell'abbonamento) ed Event schedulati per la manutenzione periodica (pulizia della cronologia, caching, reset delle ore mensili).
* **Operazioni sui Dati:** Stored procedure e funzioni per le operazioni richieste, tra cui registrazione utenti, fatture in scadenza, film più visti della settimana e raccomandazione di contenuti in base al genere preferito.
* **Data Analytics:**
    * **Classifiche di tendenza:** Top 10 dei film più visti nelle ultime due settimane per continente e per tipo di abbonamento, con il miglior formato disponibile.
    * **Valutazione dei film:** Voto calcolato e mantenuto aggiornato tramite trigger, combinando la media ponderata dei ranking (con peso maggiore per i critici), i premi vinti dal film e quelli vinti dal regista.

## 🛠️ Stack Tecnologico
* **Database:** MySQL 8.0+ (richiesto per CTE e window functions).
* **Modellazione E-R:** draw.io.
* **Client consigliato:** MySQL Workbench.

---

## 🚀 Guida all'Installazione

### 1. Preparazione dell'Ambiente
1.  Scaricare e installare [MySQL Community Server](https://dev.mysql.com/downloads/mysql/) (versione 8.0 o superiore).
2.  Scaricare e installare [MySQL Workbench](https://dev.mysql.com/downloads/workbench/) (oppure utilizzare la CLI di MySQL).
3.  Connettersi all'istanza locale con un utente che abbia i permessi per creare database, trigger ed eventi (es. `root`).

### 2. Esecuzione degli Script
Gli script si trovano nella cartella `Codice sql/` e vanno eseguiti **nell'ordine indicato dal numero nel nome del file**:

| # | File | Contenuto |
|---|------|-----------|
| 1 | `1-CREAZIONE DATABASE.sql` | Creazione del database `FilmSphere` e di tutte le tabelle |
| 2 | `2-TRIGGER E EVENT.sql` | Trigger per vincoli e attributi derivati, Event schedulati |
| 3 | `3-IMPLEMENTAZIONE OPERAZIONI.sql` | Stored procedure e funzioni delle operazioni sui dati |
| 4 | `4-DATA ANALYTIC 1.sql` | Procedure per le classifiche per area e per abbonamento |
| 5 | `5-DATA ANALYTIC 2.sql` | Funzione e trigger per il calcolo della valutazione dei film |
| 6 | `6-POPOLAMENTO.sql` | Popolamento del database con dati di esempio |
| 7 | `7-CHIAMATA OPERAZIONI.sql` | Esempi di chiamata di tutte le operazioni |

In MySQL Workbench: **File → Open SQL Script**, selezionare il file e cliccare sull'icona del fulmine ⚡ per eseguirlo.

Da CLI (dalla cartella `Codice sql/`):
```bash
mysql -u root -p < "1-CREAZIONE DATABASE.sql"
mysql -u root -p FilmSphere < "2-TRIGGER E EVENT.sql"
# ... e così via fino al file 7
```

### 3. Abilitazione degli Event
Gli Event (`PulisciCronologia`, `Caching`, `AggiornamentoOreMensili`) vengono eseguiti solo se lo scheduler di MySQL è attivo. Per abilitarlo:
```sql
SET GLOBAL event_scheduler = ON;
```

### 4. Prova delle Operazioni
Il file `7-CHIAMATA OPERAZIONI.sql` contiene un esempio di chiamata per ogni operazione e analytic, ad esempio:
```sql
CALL FilmPiuVistiSettimana();
CALL RaccomandazioneContenuti("BIALUC001");
CALL RankFilmPerArea(01);   -- 01 = Europa
```

> ℹ️ **Nota:** Tutti i dati presenti nello script di popolamento (utenti, email, password, numeri di carta) sono **fittizi** e generati esclusivamente a scopo di test.

---

## ⚠️ Troubleshooting

### Risultati vuoti nelle query temporali
Alcune operazioni (es. film più visti della settimana, classifiche delle ultime due settimane, fatture in scadenza) filtrano i dati rispetto alla **data corrente**. Poiché i dati di popolamento hanno date fisse, eseguendo le query in un periodo successivo è possibile ottenere risultati vuoti: è sufficiente aggiornare le date nello script `6-POPOLAMENTO.sql`.

---

## 📂 Struttura della Repository
```text
/
├── Codice sql/                 # Script SQL numerati in ordine di esecuzione
├── Documentazione.pdf          # Relazione completa del progetto
├── E-R non ristrutturato.pdf   # Schema E-R concettuale
└── E-R ristrutturato.pdf       # Schema E-R dopo la ristrutturazione
```

---

## 👥 Autori
* Dario Falaschi
* Leonardo Lentini
