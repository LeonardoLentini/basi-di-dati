-- 	CHIAMATA OPERAZIONI e QUERY

-- 7.1	Visualizzare il numero di aree geografiche diverse da cui un utente ha effettuato almeno un accesso nel mese corrente
select NumAreeDiverse("BIALUC001");

-- 7.2 	Per ogni area geografica indicare nella data odierna qual è stato il tipo 
-- 		di dispositivo su cui sono avvenute il maggior numero di connessioni 
CALL DispositivoPiuUsato();

-- 7.3 	Indicare gli utenti che hanno fatture in scadenza nei prossimi 10 giorni
CALL FattureInScadenza();

-- 7.4 	Dato un regista, mostrare tutti i film diretti da quel regista che hanno 
-- 		vinto un premio, negli ultimi 5 anni, includendo l’anno della vittoria
CALL FilmDelRegista("BERING019");

-- 7.5 	Visualizzazione dei 10 film più visti della settimana
CALL FilmPiuVistiSettimana();

-- 7.6	Dato un film e un utente dire se la durata del film è superiore alle ore mensili rimanenti nell’abbonamento di quell’utente 
CALL FilmVisualizzabile(001, "BIALUC001");

-- 7.7 	Registrazione di un utente
CALL RegistrazioneNuovoUtente("ROSGIU202", "Italia", "Giulia", "Rossi", "1998-04-17 00:00:00", 0, "ROSGIU202@filmsphere.com", "GR#202");
    
-- 7.8	Dato un utente seleziona il genere più presente all’interno della sua cronologia e suggerisce 
-- 		tutti i film presenti nel database di quel genere ad esclusione di quelli già visti
CALL RaccomandazioneContenuti("BIALUC001");

-- 7.9	Indicare il/i regista/i che ha/hanno vinto più premi
CALL RegistaPiuVincente();
