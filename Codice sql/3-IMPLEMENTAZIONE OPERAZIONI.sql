-- OPERAZIONI

-- 7.1	Visualizzare il numero di aree geografiche diverse da cui un utente ha effettuato almeno un accesso nel mese corrente
DROP FUNCTION IF EXISTS NumAreeDiverse; 
DELIMITER $$
CREATE FUNCTION NumAreeDiverse ( _Cod_Input CHAR(50))
RETURNS INT DETERMINISTIC
BEGIN 
	DECLARE NumAree INT DEFAULT 0;
    
	Select count(Distinct C.Paese) INTO NumAree
	From Connessione C
	Where C.CodFiscale = _Cod_Input AND MONTH(C.Inizio_connessione) = MONTH(current_date());
    
    RETURN NumAree;
END $$
DELIMITER ;

-- 7.2 	Per ogni area geografica indicare nella data odierna qual è stato il tipo 
-- 		di dispositivo su cui sono avvenute il maggior numero di connessioni 
DROP PROCEDURE IF EXISTS DispositivoPiuUsato;
DELIMITER $$
CREATE PROCEDURE DispositivoPiuUsato()
BEGIN
	With TabellaConnessioni as( -- creo una tabella che contiene nella data odierna per ogni area e ogni dispositivo il numero di connessioni
		SELECT C1.Paese, C1.Dispositivo, COUNT(*) AS NumConnessioni 
		FROM Connessione C1
		WHERE DATE(C1.Inizio_connessione) = current_date()		
		GROUP BY C1.Paese, C1.Dispositivo
	)
	SELECT Distinct(X.Paese), X.Dispositivo		-- indico per ogni paese il dispositivo 
	FROM TabellaConnessioni X
	Where X.NumConnessioni = (	Select Max(X1.NumConnessioni) -- dove il dispositivo è il dispositivo con il maggior numero di connessioni per i dispositivi di quel paese
								From TabellaConnessioni X1
								Where X.Paese= X1.Paese
								);
END $$
DELIMITER ;

-- 7.3 	Indicare gli utenti che hanno fatture in scadenza nei prossimi 10 giorni
DROP PROCEDURE IF EXISTS FattureInScadenza; 
DELIMITER $$
CREATE PROCEDURE FattureInScadenza()
BEGIN
	Select U.Nome, U.Cognome
	From
		Utente U
		inner join
		Fattura F on F.CodFiscale=U.CodFiscale
	Where F.Data_pagamento IS NULL AND F.Scadenza_fattura > current_date() - INTERVAL 10 DAY;
END $$
DELIMITER ;

-- 7.4 	Dato un regista, mostrare tutti i film diretti da quel regista che hanno 
-- 		vinto un premio, negli ultimi 5 anni, includendo l’anno della vittoria
DROP PROCEDURE IF EXISTS FilmDelRegista; 
DELIMITER $$
CREATE PROCEDURE FilmDelRegista (IN _Cod_Input CHAR(50))
BEGIN 

	Select 	F.Titolo, P.Anno_vittoria
	From 	Regista R
			natural join 
			Regia D
            natural join 
            Film F
            natural join
            Premio P
	Where R.CodFiscale = _Cod_Input AND 
		  P.Nome_premio IS NOT NULL AND P.Anno_vittoria IS NOT NULL
           AND P.Anno_vittoria >= (YEAR(current_date()) - 5)
    ;
    
END $$
DELIMITER ;


-- 7.5 	Visualizzazione dei 10 film più visti della settimana
DROP PROCEDURE IF EXISTS FilmPiuVistiSettimana;
DELIMITER $$
CREATE PROCEDURE FilmPiuVistiSettimana()
BEGIN
	With NumeroVisualizzazioni AS(	
		Select ID_Film, Titolo, count(*) as VisualizzazioniPerFilm -- conto il numero di visualizzazioni dei film visti questa settimana
		From Cronologia
			 natural join
			 Film
		Where Data_visualizzazione BETWEEN ( Current_date() - Interval 7 DAY) AND  current_date()
		Group by ID_Film
	), 
    ClassificaVisualizzazioni as(
	Select Titolo, Dense_rank() over (Partition by ID_Film Order By VisualizzazioniPerFilm DESC) as Posizione -- dei film visti quella settimana faccio una classifica basata sulle visualizzazioni
	From NumeroVisualizzazioni
	)
	select *  -- seleziono i titoli e la posizione in classifica dei 10 film piu visti                                                                                                                                                               
	From ClassificaVisualizzazioni
	Where Posizione <= 10;
END $$
DELIMITER ;

-- 7.6	Dato un film e un utente dire se la durata del film è superiore alle ore mensili rimanenti nell’abbonamento di quell’utente 
DROP PROCEDURE IF EXISTS FilmVisualizzabile;
DELIMITER $$
CREATE PROCEDURE FilmVisualizzabile (IN _ID_Film INT, IN _CodFiscale CHAR(50))
BEGIN
	DECLARE durata DOUBLE DEFAULT 0;
    DECLARE rimanenti INT DEFAULT 0;
    
    DECLARE messaggio VARCHAR(500);
    
    IF _ID_Film NOT IN (
						select distinct F.ID_Film
                        FROM Film F 
					  ) THEN
		SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Film non presente';
	END IF; 
	IF _CodFiscale NOT IN (
							SELECT distinct U.CodFiscale
							FROM Utente U 
						  ) THEN
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = 'Nessun utente trovato';
	END IF;
	
	SET durata =  (
					SELECT F1.Durata
					FROM Film F1
					WHERE _ID_Film = F1.ID_Film
				   );
	SET rimanenti = (
						SELECT U1.Ore_rimanenti
						FROM Utente U1
						WHERE _CodFiscale = U1.CodFiscale
					);
	SET durata = durata / 60;
	IF durata > rimanenti THEN 
		SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = "Ore insufficienti, film non visualizzabile";
	END IF;

END $$
DELIMITER ;


-- 7.7 	Registrazione di un utente

DROP PROCEDURE IF EXISTS RegistrazioneNuovoUtente;
DELIMITER $$
CREATE PROCEDURE RegistrazioneNuovoUtente (IN NewCodFiscale CHAR(50), IN NewPaese VARCHAR(50), IN NewNome VARCHAR(50), IN NewCognome VARCHAR(50), IN NewData_nascita DATE, IN NewCritico BOOL, IN NewEmail VARCHAR(100), IN NewPassword VARCHAR(50)) -- ore rimanenti viene dato uguale a 0
BEGIN

	DECLARE messaggio VARCHAR(500);

	-- si controlla che non siano già presente il codfiscale o email nella tabella
    IF NewCodFiscale IN (
						select U.CodFiscale
                        FROM Utente U 
					  ) THEN
		SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Utente già presente';
	END IF; 
    
    IF NewEmail IN (
						select U.Email
                        FROM Utente U 
					  ) THEN
		SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Utente già presente';
	END IF; 
    
    -- si controlla che il paese sia presente nella tabella areageografica
    IF NewPaese NOT IN (
						select A.Paese
                        FROM AreaGeografica A 
					  ) THEN
		SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Film non presente';
	END IF; 
    
    -- si inserisce i dati del nuovo utente
	INSERT INTO Utente(CodFiscale, Paese, Nome, Cognome, Data_nascita, Critico, Email, Password, Ore_rimanenti) VALUES
	( NewCodFiscale, NewPaese, NewNome, NewCognome, NewData_nascita, NewCritico, NewEmail, NewPassword, 0);
	
    set messaggio = "Nuovo utente inserito.";
	select messaggio;
END $$
DELIMITER ;

    
-- 7.8	Dato un utente seleziona il genere più presente all’interno della sua cronologia e suggerisce 
-- 		tutti i film presenti nel database di quel genere ad esclusione di quelli già visti

DROP PROCEDURE IF EXISTS RaccomandazioneContenuti ;
DELIMITER $$
CREATE PROCEDURE RaccomandazioneContenuti (IN _CodFiscale CHAR(50))
BEGIN

	DECLARE GenerePreferito VARCHAR(25) DEFAULT '';
    
    -- analizziamo il genere di film più visto dall' utente
    SET GenerePreferito = (
		WITH VisualizzazioniPerGenere AS
		(
			Select F.Genere, Count(*) as NumeroVisualizzazioni
			From 	Cronologia C
					Natural join
					Film F
			Where C.CodFiscale = _CodFiscale
			Group By F.Genere
		)
        SELECT Genere 
        FROM VisualizzazioniPerGenere
        WHERE NumeroVisualizzazioni = (
										SELECT MAX(NumeroVisualizzazioni)
										FROM VisualizzazioniPerGenere
									  )
		LIMIT 1
		);
			    
    -- selezioniamo tutti i film presenti di quel genere, a esclusione dei film già visti dall'utente
    
    Select Distinct(F.ID_Film)
	From 	Film F
			Left outer join
			Cronologia C ON F.ID_Film= C.ID_Film
	Where C.CodFiscale <> _CodFiscale AND F.Genere = GenerePreferito
    ;
	
END $$
DELIMITER ;


-- 7.9	Indicare il/i regista/i che ha/hanno vinto più premi
DROP PROCEDURE IF EXISTS RegistaPiuVincente;
DELIMITER $$
CREATE PROCEDURE RegistaPiuVincente()
BEGIN
	Select R.Nome, R.Cognome
	From Regista R
	Where R.Premi_vinti=	(	Select MAX(R1.Premi_vinti)
								From Regista R1
								);
END $$
DELIMITER ;


