-- TRIGGER

-- 9.1 
-- Anno produzione film deve essere uguale al minimo anno (data uscita) di quel film in un qualsiasi formato
DROP TRIGGER IF EXISTS ControlloDataFilm;
DELIMITER $$
CREATE TRIGGER ControlloDataFilm
After INSERT ON Formato FOR EACH ROW
BEGIN
	DECLARE AnnoFormato INT;
    DECLARE AnnoFilm INT;
    DECLARE ID_X INT; 
    SET AnnoFormato = (
					Select YEAR(Data_uscita)
					FROM Rilascio
					WHERE Codice_formato = NEW.Codice_formato
				);
	Set AnnoFilm  = (
					Select Anno_Produzione
					FROM Film F
						 natural join
                         Rilascio R
					WHERE F.ID_Film = R.ID_Film AND R.Codice_formato = NEW.Codice_formato
				);
	Set ID_X = (
				Select ID_Film
                From Rilascio R
				WHERE R.Codice_formato = NEW.Codice_formato
				);
	IF AnnoFormato < AnnoFilm THEN
		Update Film F
        Set Anno_Produzione = AnnoFormato
        Where F.ID_Film = ID_X;
	END IF;
END $$
DELIMITER ;

-- 9.2
-- Aggiornare lo stato dei server in funzione del numero di connessioni
DROP TRIGGER IF EXISTS StatoServerCDN;
DELIMITER $$
CREATE TRIGGER StatoServerCDN
After INSERT ON Connessione FOR EACH ROW
BEGIN
	Declare NumeroConnessioni INT;
    
    Set NumeroConnessioni = (
							Select Count(*)
                            From Connessione C
                            Where ID_server= New.ID_server AND Fine_connessione IS NULL
							);
    
	IF NumeroConnessioni < 25 THEN
		Update ServerCDN
		Set Stato = "Buono"
		Where ID_server= New.ID_server;
    ELSE IF NumeroConnessioni < 50 THEN
			Update ServerCDN
			Set Stato = "Regolare"
			Where ID_server= New.ID_server;
        ELSE
			Update ServerCDN
			Set Stato = "Pessimo"
			Where ID_server= New.ID_server;
		END IF;
	END IF;
    
END $$
DELIMITER ;


-- 9.3 
-- Vincoli per il popolamento della tabella Connessione
DROP TRIGGER IF EXISTS PopolamentoConnessione;
DELIMITER $$
CREATE TRIGGER PopolamentoConnessione 
BEFORE INSERT ON Connessione FOR EACH ROW
BEGIN
	DECLARE AbbonamentoUtente VARCHAR(20);
    
    -- Controllo che il paese da cui viene effettuata la connessione sia valido in base alla restrizione dell'abbonamento dell'utente
    -- Ricavo l'abbonamento dell'utente
		SET AbbonamentoUtente = 
		(
			SELECT Nome
			FROM Iscrizione
			WHERE CodFiscale = NEW.CodFiscale
		);
		
		IF NEW.Paese NOT IN(	
							SELECT R.Paese
							FROM Restrizione R 
							WHERE R.Nome = AbbonamentoUtente 
						) THEN
			SIGNAL SQLSTATE '45000'
			SET Message_text = "La connessione non è eseguibile a causa delle restrizioni dell'abbonamento";
		END IF;
        
        
        -- la connessione viene allacciata al server più vicino indifferentemente dal server di ingresso 
		SET NEW.ID_Server = (
		WITH Coordinate_server AS
		(
			SELECT A.Paese, S.ID_server, A.Latitudine, A.Longitudine
			FROM AreaGeografica A NATURAL JOIN ServerCDN S
			WHERE A.Paese IN (
							SELECT Paese 
							FROM ServerCDN
							)
		),
		Distanza_server AS
		(
			SELECT A.Paese, C.ID_server, C.Paese AS Paese_Server, ((A.Latitudine - C.Latitudine)*(A.Latitudine - C.Latitudine) + (A.Longitudine - C.Longitudine)*(A.Longitudine - C.Longitudine)) AS Modulo
			FROM AreaGeografica A CROSS JOIN Coordinate_server C 
		),
		Classifica_distanze AS
		(
			Select Paese, ID_server, Paese_Server, RANK() OVER (PARTITION BY Paese ORDER BY Modulo) AS Vicinanza
			FROM Distanza_server
		)
			SELECT ID_server 
			FROM Classifica_distanze
			WHERE Paese = NEW.Paese AND Vicinanza = 1
		);

    -- controlli da fare:
    -- dispositivo deve essere uno tra Smartphone Tablet  Computer  SmartTV  
    IF NEW.Dispositivo <> "Tablet" THEN
		IF NEW.Dispositivo <> "Computer" THEN
			IF NEW.Dispositivo <> "Smartphone" THEN
				IF NEW.Dispositivo <> "SmartTV" THEN
					SIGNAL SQLSTATE "45000"
                    SET MESSAGE_TEXT = " Il dispositivo usato per la connessione non è riconosciuto, connessione non eseguibile";
				END IF;
			END IF;
		END IF;
	END IF;
    
    -- l'utente deve essere presente tra gli utenti
    IF NEW.CodFiscale NOT IN (
								SELECT CodFiscale 
                                FROM Utente
							 ) 	THEN 
										SIGNAL SQLSTATE "45000"
                                        SET MESSAGE_TEXT = "Utente non presente in piattaforma, connessione non eseguibile";
	END IF;
    
    -- se fine_connessione <> da NULL allora fine_connessione deve essere maggiore di inizio_connessione
    IF NEW.Fine_connessione <> NULL THEN
		IF NEW.Fine_connessione < NEW.Inizio_connessione THEN
			SIGNAL SQLSTATE "45000"
            SET MESSAGE_TEXT = "La fine della connessione non può essere antecedente all'inizio della stessa";
		END IF;
	END IF;
    
    -- Ogni dispositivo ha il suo indirizzo IP quindi se si effettua una connessione con un dispositivo già utilizzato questo deve avere
    -- il proprio indirizzo IP indifferentemente dall'IP inserito in ingresso
	IF NEW.Dispositivo IN 	(
								SELECT Dispositivo
								FROM Connessione
                                WHERE CodFiscale = NEW.CodFiscale
                            ) THEN
		SET NEW.Indirizzo_IP = (
									Select Indirizzo_IP
                                    FROM Connessione
                                    WHERE Dispositivo = NEW.Dispositivo
                                    AND CodFiscale = NEW.CodFiscale
                                    LIMIT 1
							   );
	ELSE 
		IF NEW.Indirizzo_IP / 1000000000 < (	
												SELECT IP_Area
												FROM AreaGeografica
                                                WHERE Paese = NEW.Paese
                                                LIMIT 1
											) OR  	NEW.Indirizzo_IP / 1000000000 >= (	
																						SELECT (IP_Area + 1) AS IP_Area_successiva
																						FROM AreaGeografica
																						WHERE Paese = NEW.Paese
																						LIMIT 1
																					)	THEN 
		SIGNAL SQLSTATE "45000"
        SET MESSAGE_TEXT = " L'indirizzo IP non corrisponde all'area geografica della connessione, connessione non eseguibile";
		END IF;
	END IF;
    
    -- Il paese deve essere presente tra le aree geografiche del database
    IF NEW.Paese NOT IN	(	
							SELECT Paese
                            FROM AreaGeografica
						) THEN 
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = "Paese non riconosciuto, connessione non eseguibile";
	END IF;
END $$
DELIMITER ;										

-- 9.4 
-- L’attributo Massimo_ore_mensili deve essere soddisfatto e il film deve essere visualizzabile
DROP TRIGGER IF EXISTS ControlloVisualizzazione;
DELIMITER $$
CREATE TRIGGER ControlloVisualizzazione
BEFORE INSERT ON Cronologia FOR EACH ROW
BEGIN
	 call FilmVisualizzabile(New.ID_Film, New.CodFiscale);
END $$
DELIMITER ;

-- 9.5
-- L’attributo Eta_minima deve essere soddisfatto
DROP TRIGGER IF EXISTS ControlloEtaMinima;
DELIMITER $$
CREATE TRIGGER ControlloEtaMinima
BEFORE INSERT ON Iscrizione FOR EACH ROW
BEGIN
	DECLARE EtaUtente INT DEFAULT 0;
    Declare EtaAbbonamento Int Default 18;
    
    Set EtaUtente =(
		Select (YEAR(current_date()) - YEAR(Data_nascita) ) AS eta
		From Utente
		Where CodFiscale=New.CodFiscale
    );
    
    Set EtaAbbonamento =(
		Select Eta_minima
        From Abbonamento
        Where Nome=New.Nome
    );
    
	IF (EtaAbbonamento > EtaUtente) THEN
		signal sqlstate '45000'
		SET message_text= "L'utente non ha l'età sufficiente per iscriversi a tale abbonamento";
	END IF;
END $$
DELIMITER ;

-- 9.6
-- Data una richiesta di visualizzazione di un film nel formato disponibile per l'abbonamento dell'utente, 
-- controllare che quel film sia disponibile nel luogo dove avviene la connessione 
DROP TRIGGER IF EXISTS ControlloFormato;
DELIMITER $$
CREATE TRIGGER ControlloFormato
BEFORE INSERT ON Cronologia
FOR EACH ROW
BEGIN
	DECLARE LuogoConnessione VARCHAR(50);
	DECLARE QualitaUtente VARCHAR(10);
	DECLARE PunteggioQualitaUtente INT;
    DECLARE PunteggioQualitaFilm INT;
    DECLARE FormatoFilm VARCHAR (20);
    -- ricerco il paese da cui l'utente ha effettuato la connessione
    SET LuogoConnessione = (
							SELECT Paese
                            FROM Connessione
                            WHERE CodFiscale = NEW.CodFiscale 
								AND DATE(Inizio_Connessione) = NEW.Data_visualizzazione
							LIMIT 1
							);
	-- ricerco la qualità massima disponibile per l'abbonamento dell'utente e la converto in numero
	-- le qualità possono essere : SD(1), HD(2), FULLHD(3), 4K(4)
		SET QualitaUtente = (
								SELECT A.Qualita_contenuti
								FROM Abbonamento A NATURAL JOIN Iscrizione I
								WHERE I.CodFiscale = NEW.CodFiscale
							);
		
		IF QualitaUtente = "SD" THEN
			SET PunteggioQualitaUtente = 1;
		ELSE 
			IF QualitaUtente = "HD" THEN
				SET PunteggioQualitaUtente = 2;
			ELSE 
				IF QualitaUtente = "FULLHD" THEN
					SET PunteggioQualitaUtente = 3;
				ELSE 
					SET PunteggioQualitaUtente = 4;
				END IF;
			END IF;
		END IF;
		
		
	-- tra tutte le possibili qualità del film (non audio) assegno un punteggio a quella minore
		IF "SD" IN (												
						SELECT F.Qualita							
						FROM Formato F NATURAL JOIN Rilascio R
						WHERE R.ID_Film = NEW.ID_Film 			
							AND F.Tipo_formato <> "Audio"			
					) THEN 										
			SET PunteggioQualitaFilm = 1;		
			SET FormatoFilm = (
								SELECT F.Codice_formato
								FROM Formato F NATURAL JOIN Rilascio R
								WHERE R.ID_Film = NEW.ID_Film 			
									AND F.Tipo_formato <> "Audio"
									AND F.Qualita = "SD"
                                    AND F.Codice_formato IN (
																SELECT Codice_formato
																FROM Disponibilita
                                                                WHERE Paese = LuogoConnessione
															)
								LIMIT 1
							  );
		ELSE 	
			IF "HD" IN (											
							SELECT F.Qualita						
							FROM Formato F NATURAL JOIN Rilascio R
							WHERE R.ID_Film = NEW.ID_Film 			
								AND F.Tipo_formato <> "Audio"		
						) THEN 										
				SET PunteggioQualitaFilm = 2;	
				SET FormatoFilm = (
									SELECT F.Codice_formato
									FROM Formato F NATURAL JOIN Rilascio R
									WHERE R.ID_Film = NEW.ID_Film 			
										AND F.Tipo_formato <> "Audio"
										AND F.Qualita = "HD"
										AND F.Codice_formato IN (
																	SELECT Codice_formato
																	FROM Disponibilita
																	WHERE Paese = LuogoConnessione
																)
									LIMIT 1
								  );            
			ELSE 
				IF "FULLHD" IN (											
								SELECT F.Qualita						
								FROM Formato F NATURAL JOIN Rilascio R
								WHERE R.ID_Film = NEW.ID_Film 			
									AND F.Tipo_formato <> "Audio"		
							) THEN 										
					SET PunteggioQualitaFilm = 3;
					SET FormatoFilm = (
										SELECT F.Codice_formato
										FROM Formato F NATURAL JOIN Rilascio R
										WHERE R.ID_Film = NEW.ID_Film 			
											AND F.Tipo_formato <> "Audio"
											AND F.Qualita = "FULLHD"
											AND F.Codice_formato IN (
																		SELECT Codice_formato
																		FROM Disponibilita
																		WHERE Paese = LuogoConnessione
																	)
										LIMIT 1
									  );   
				ELSE 
					IF "4K" IN (											
									SELECT F.Qualita						
									FROM Formato F NATURAL JOIN Rilascio R
									WHERE R.ID_Film = NEW.ID_Film 			
										AND F.Tipo_formato <> "Audio"		
								) THEN 										
						SET PunteggioQualitaFilm = 4;	
						SET FormatoFilm = (
											SELECT F.Codice_formato
											FROM Formato F NATURAL JOIN Rilascio R
											WHERE R.ID_Film = NEW.ID_Film 			
												AND F.Tipo_formato <> "Audio"
												AND F.Qualita = "4K"
												AND F.Codice_formato IN (
																			SELECT Codice_formato
																			FROM Disponibilita
																			WHERE Paese = LuogoConnessione
																		)
											LIMIT 1
										  );   
					ELSE
						SIGNAL SQLSTATE "45000" 
						SET MESSAGE_TEXT = "ERRORE";
					END IF;
				END IF;
			END IF;
		END IF;
		
		IF PunteggioQualitaFilm > PunteggioQualitaUtente THEN
			SIGNAL SQLSTATE "45000"
			SET MESSAGE_TEXT = "La qualità contenuti dell'abbonamento dell'utente non consente di visualizzare il film";
		END IF;
		
		IF FormatoFilm IS NULL THEN
			SIGNAL SQLSTATE "45000"
			SET MESSAGE_TEXT = "Il formato del film non è disponibile nel luogo della connessione";
		END IF;

END $$
DELIMITER ;


-- 9.7
-- Controllare che formato video sia di tipo: video, audio o audiovideo
DROP TRIGGER IF EXISTS FormatoInserito;
DELIMITER $$
CREATE TRIGGER FormatoInserito
BEFORE INSERT ON Formato FOR EACH ROW
BEGIN
	IF (New.Tipo_formato <> "Video") THEN
		IF (New.Tipo_formato <> "Audio") THEN
			IF (New.Tipo_formato <> "AudioVideo")  THEN
				signal sqlstate '45000'
				SET message_text= "Il tipo di formato inserito è errato";
			END IF;
		END IF;
	END IF;
END $$
DELIMITER ;


-- 9.8
-- Creazione di un nuovo utente implica creazione di una cache per lui
DROP TRIGGER IF EXISTS CacheUtente;
DELIMITER $$
CREATE TRIGGER CacheUtente
AFTER INSERT ON Utente FOR EACH ROW
BEGIN
	DECLARE ServerVicino INT DEFAULT 01;
	-- cerco la nazionalità dell'utente e ricavo il server più vicino 
	-- nazionalità = new.paese
    IF NEW.CodFiscale NOT IN(	
								SELECT CodFiscale 
                                FROM Cache
							)
							THEN
    SET ServerVicino = (
		WITH Coordinate_server AS
		(
			SELECT A.Paese, S.ID_server, A.Latitudine, A.Longitudine
			FROM AreaGeografica A NATURAL JOIN ServerCDN S
			WHERE A.Paese IN (
							SELECT Paese 
							FROM ServerCDN
							)
		),
		Distanza_server AS
		(
			SELECT A.Paese, C.ID_server, C.Paese AS Paese_Server, ((A.Latitudine - C.Latitudine)*(A.Latitudine - C.Latitudine) + (A.Longitudine - C.Longitudine)*(A.Longitudine - C.Longitudine)) AS Modulo
			FROM AreaGeografica A CROSS JOIN Coordinate_server C 
		),
		Classifica_distanze AS
		(
			Select Paese, ID_server, Paese_Server, RANK() OVER (PARTITION BY Paese ORDER BY Modulo) AS Vicinanza
			FROM Distanza_server
		)
			SELECT ID_server 
			FROM Classifica_distanze
			WHERE Paese = NEW.Paese AND Vicinanza = 1
		);
    
    -- crea una cache con chiave il nome utente e il server
    INSERT INTO Cache(CodFiscale, ID_server) VALUES(New.CodFiscale, ServerVicino);
    END IF;
    
END $$
DELIMITER ;


-- 9.9 
-- Scelta server CDN
-- Quando un utente richiede di visualizzare un film, una funzionalità, sceglie il server del CDN più vicino all’utente,
-- per ridurre i tempi di buffering e migliorare l’esperienza di visione. Inoltre, questa funzionalità considera le informazioni sul traffico di rete e sulle prestazioni 
-- dei vari server del CDN, al fine di garantire che l’utente riceva il contenuto dal server più opportuno in quel momento, non solo in ottica di prossimità, 
-- ma anche in termini di bilanciamento del carico. 
-- Durante la visione di un film da parte di un utente, il server CDN può cambiare.
-- Questo può avvenire per diversi motivi, come ad esempio il sovraccarico del server, o il sopraggiungere di problemi di connessione. 
-- Il sistema di CDN è progettato per scegliere automaticamente il server (alternativo) più opportuno, 
-- cioè vicino all’utente e in grado di garantire una visualizzazione fluida e senza interruzioni dato il suo livello di carico.
DROP TRIGGER IF EXISTS BilanciamentoServer;
DELIMITER $$ 
CREATE TRIGGER BilanciamentoServer
AFTER INSERT ON Connessione FOR EACH ROW
BEGIN
	-- se il numero di connessioni arriva a 50 lo stato del server va a pessimo quindi devo bilanciare
    DECLARE NumeroConnessioni INT;
    DECLARE ConnessioniLontane INT;
    DECLARE Salva_Indirizzo_IP BIGINT DEFAULT 0;
    DECLARE Salva_Inizio_Connessione DATETIME;
    DECLARE Salva_paese VARCHAR(50);
    DECLARE ID_server_vicino INT;
    
    Set NumeroConnessioni = (
							Select Count(*)
                            From Connessione C
                            Where ID_server= New.ID_server AND Fine_connessione IS NULL
							);
	IF NumeroConnessioni = 50 THEN
		-- bilancio il carico 
        -- Trova la connessione più lontana su un dato server, in caso ce ne fossero più di 1 salvo la più vecchia
		-- 1) trovo tutte le connessioni non terminate connesse al server in stato pessimo e mantengo chiave e coordinate del paese
		SET ConnessioniLontane = ( 
				with Connessioni_server as
				(
					SELECT C.Inizio_connessione, C.Indirizzo_IP, A.Paese, A.Longitudine, A.Latitudine
					FROM Connessione C inner join AreaGeografica A on C.Paese = A.Paese
					WHERE C.ID_server = New.ID_server AND C.Fine_connessione IS NULL
				),
		-- 2) coordinate del server che mi interessa
				Coordinate_server as
				(
					SELECT A.Paese, A.Longitudine, A.Latitudine
					FROM AreaGeografica A inner join ServerCDN S on A.Paese = S.Paese
					WHERE S.ID_Server = New.ID_server
				), 
		-- 3) calcolo la distanza tra le connessioni del punto 1 e il server
				Distanze_server as
				(
					Select A.Paese, A.Inizio_connessione, A.Indirizzo_IP, ((A.Latitudine - C.Latitudine)*(A.Latitudine - C.Latitudine) + (A.Longitudine - C.Longitudine)*(A.Longitudine - C.Longitudine)) AS Modulo
					FROM Coordinate_server C cross join Connessioni_server A 
				),
				Classifica_distanze as
				(
					Select Paese, Inizio_connessione, Indirizzo_IP, RANK() OVER (ORDER BY Modulo DESC) AS Lontananza
					FROM Distanze_server 
				), 
				Connessioni_piu_lontane as
				(
					SELECT COUNT(*) AS Numero		-- se >1 allora cambio la connessione più vecchia
					FROM Classifica_distanze
					WHERE Lontananza = 1
				)
					SELECT Numero
					from Connessioni_piu_lontane
				);
                
		IF ConnessioniLontane > 1 THEN		-- salvo la chiave e il paese della connessione più vecchia attiva sul server
											-- perché andrò a spostare quella su un altro server
					SELECT (
							SELECT Inizio_connessione, Indirizzo_IP, Paese
							FROM Connessione
							WHERE ID_server = NEW.ID_server AND Fine_connessione IS NULL
								AND Inizio_connessione = ( 	SELECT MIN(Inizio_connessione)
                                                         	FROM Connessione
                                                            WHERE Fine_connessione IS NULL
														  )
								AND Fine_connessione IS NULL
							LIMIT 1
						  ) 
						INTO Salva_Inizio_Connessione, Salva_Indirizzo_IP, Salva_paese;
		ELSE			-- salvo la chiave della connessione più lontana attiva sul server 
					SELECT  
							(
							with Connessioni_server as
							(
								SELECT C.Inizio_connessione, C.Indirizzo_IP, A.Paese, A.Longitudine, A.Latitudine
								FROM Connessione C inner join AreaGeografica A on C.Paese = A.Paese
								WHERE C.ID_server = New.ID_server AND C.Fine_connessione IS NULL
							),
							Coordinate_server as
							(
								SELECT A.Paese, A.Longitudine, A.Latitudine
								FROM AreaGeografica A inner join ServerCDN S on A.Paese = S.Paese
								WHERE S.ID_Server = New.ID_server
							), 
							Distanze_server as
							(
								Select A.Paese, A.Inizio_connessione, A.Indirizzo_IP, ((A.Latitudine - C.Latitudine)*(A.Latitudine - C.Latitudine) + (A.Longitudine - C.Longitudine)*(A.Longitudine - C.Longitudine)) AS Modulo
								FROM Coordinate_server C cross join Connessioni_server A 
							),
							Classifica_distanze as
							(
								Select Paese, Inizio_connessione, Indirizzo_IP, RANK() OVER (ORDER BY Modulo DESC) AS Lontananza
								FROM Distanze_server 
							) 
								SELECT Inizio_connessione, Indirizzo_IP, Paese
								FROM Classifica_distanze
								WHERE Lontananza = 1
							) 
						INTO Salva_Inizio_Connessione, Salva_Indirizzo_IP, Salva_paese;
        END IF;    
					-- sposto la connnessione di cui ho la chiave sul server più vicino ad essa (escluso il New.ID_server)
					-- trovo il server più vicino alla connessione salvata (escludendo il NEW.ID_server)
		SELECT 
				(
			WITH Coordinate_server AS
					(
						SELECT A.Paese, S.ID_server, A.Latitudine, A.Longitudine
						FROM AreaGeografica A NATURAL JOIN ServerCDN S
						WHERE A.Paese IN (
										SELECT Paese 
										FROM ServerCDN
										WHERE ID_server <> NEW.ID_server
										)
					),
					Distanza_server AS
					(
						SELECT A.Paese, C.ID_server, C.Paese AS Paese_Server, ((A.Latitudine - C.Latitudine)*(A.Latitudine - C.Latitudine) + (A.Longitudine - C.Longitudine)*(A.Longitudine - C.Longitudine)) AS Modulo
						FROM AreaGeografica A CROSS JOIN Coordinate_server C 
						WHERE A.Paese = Salva_paese
					),
					Classifica_distanze AS
					(
						Select Paese, ID_server, Paese_Server, RANK() OVER (PARTITION BY Paese ORDER BY Modulo) AS Vicinanza
						FROM Distanza_server
					)
						SELECT ID_server 
						FROM Classifica_distanze
						WHERE Vicinanza = 1
						LIMIT 1
					) 
				INTO ID_server_vicino;		
				-- aggiorno connessione cambiando il server della connessione salvata
                UPDATE Connessione
                SET ID_server = ID_server_vicino
                WHERE Inizio_connessione = Salva_Inizio_connessione 
					AND Indirizzo_IP = Salva_Indirizzo_IP;
    END IF;
END $$ 
DELIMITER ;

-- 9.10
-- Aggiornare attributo Ore_rimanenti
DROP TRIGGER IF EXISTS AggiornaOreRimanenti;
DELIMITER $$
CREATE TRIGGER AggiornaOreRimanenti
AFTER INSERT ON Cronologia FOR EACH ROW
BEGIN
	-- il controllo sul numero di ore rimanenti dell'utente è effettuato dal trigger 9.4
	-- calcolo la durata del film in ore
	DECLARE DurataFilm INT;
    SET DurataFilm = (
						SELECT Durata
                        FROM Film
                        WHERE ID_Film = NEW.ID_Film 
					 )/60;
	UPDATE Utente U
    SET U.Ore_rimanenti = U.Ore_rimanenti - DurataFilm
    Where New.CodFiscale=U.CodFiscale;
END $$
DELIMITER ;

-- 9.11
-- Aggiornare attributo Premi_vinti
DROP TRIGGER IF EXISTS AggiornaPremiVinti;
DELIMITER $$
CREATE TRIGGER AggiornaPremiVinti 
AFTER INSERT ON Premio FOR EACH ROW
BEGIN
	UPDATE Regista
    SET Premi_vinti=Premi_vinti + 1
    WHERE CodFiscale IN (
							Select R.CodFiscale
                            FROM Regia R 
                            WHERE R.ID_Film = NEW.ID_Film
						);
                            
END $$
DELIMITER ;

-- 9.12
-- Un film può vincere un premio solo nell’anno in cui è uscito 
DROP TRIGGER IF EXISTS VittoriaPremio;
DELIMITER $$
CREATE TRIGGER VittoriaPremio 
BEFORE INSERT ON Premio FOR EACH ROW
BEGIN
	DECLARE ANNO INT;
    SET Anno = (
					Select Anno_produzione 
					FROM Film
					WHERE ID_Film = NEW.ID_Film
				);
	IF Anno < NEW.Anno_vittoria THEN
		SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = "Premio non assegnabile, il film non è uscito nell'anno della vittoria";
	ELSE IF Anno > NEW.Anno_vittoria THEN
			SIGNAL SQLSTATE '45000'
			SET MESSAGE_TEXT = "Premio non assegnabile, il film è uscito dopo";
		END IF;
	END IF;
END $$
DELIMITER ;

-- 9.13
-- Nell'inserimento di un RatingPersonale aggiorna Peso_voto se il Rating è stato fatto da un Critico
DROP TRIGGER IF EXISTS ImportanzaVoto;
DELIMITER $$
CREATE TRIGGER ImportanzaVoto
BEFORE INSERT ON RatingPersonale FOR EACH ROW
BEGIN
    DECLARE importanza BOOL DEFAULT FALSE;
	SET importanza = (	SELECT Critico
						FROM Utente
						WHERE CodFiscale = NEW.CodFiscale
					 );
    IF importanza = 0 THEN
		SET NEW.Peso_voto = 1;
	ELSE
		SET NEW.Peso_voto = 3;
	END IF;
END $$
DELIMITER ;

-- EVENT

-- 9.14
-- Eliminare la cronologia di visualizzazione più vecchia di 6 mesi per ogni utente
DROP EVENT IF EXISTS PulisciCronologia;
DELIMITER $$
CREATE EVENT PulisciCronologia
ON SCHEDULE EVERY 1 DAY
STARTS "2022-01-01 23:55:00" 
DO
BEGIN
	DELETE From Cronologia
	Where Data_visualizzazione < Current_date() - interval 6 MONTH;
END $$
DELIMITER ;

--  9.15
-- Caching
DROP EVENT IF EXISTS Caching;
DELIMITER $$
CREATE EVENT Caching
ON SCHEDULE EVERY 7 DAY
STARTS "2022-01-01 23:55:00" 
DO
BEGIN
	-- CREO UN CURSORE E SCORRO LA TABELLA CACHE, PRENDENDO UNA AD UNO IL CODICE FISCALE
    
    DECLARE finito INTEGER DEFAULT 0;
    DECLARE CodiceX CHAR(50);
    DECLARE GenerePreferito VARCHAR(25) DEFAULT '';
    DECLARE ServerX INT DEFAULT 0;
    
    DECLARE Cursore CURSOR FOR
	Select CodFiscale
    From Cache;
    
    DECLARE CONTINUE HANDLER FOR NOT FOUND
	SET finito = 1;
    
    OPEN Cursore;
    
    preleva:LOOP
		FETCH Cursore Into CodiceX;
        IF Finito = 1 THEN 
			LEAVE preleva;
		END IF;
        
        -- analizziamo il genere di film più visto dall'utente
    
		Set GenerePreferito = (
			WITH VisualizzazioniPerGenere as
            (
				(
				Select F.Genere, Count(*) as NumeroVisualizzazioni
				From 	Cronologia C
						Natural join
						Film F
				Where C.CodFiscale = CodiceX
				Group By F.Genere
				)
			)
			Select Genere
			From VisualizzazioniPerGenere
			Where NumeroVisualizzazioni = (	
											Select  MAX(NumeroVisualizzazioni)
											FROM VisualizzazioniPerGenere		
										  )
			);
		
        -- troviamo a quale server appartiene la cache
        
		Set ServerX = (
						Select ID_server
                        From Cache
                        Where CodFiscale=CodiceX
						);
                        
		-- inseriamo dentro al salvataggio 3 nuovi film
        
		Insert INTO Salvateggio (ID_Film, ID_server, CodFiscale)
		Select Distinct(F.ID_Film), ServerX, CodiceX
		From 	Film F
				Left outer join
				Cronologia C ON F.ID_Film= C.ID_Film
		Where C.CodFiscale <> CodiceX AND F.Genere = GenerePreferito
		LIMIT 3;
        
	END LOOP preleva;
    Close Cursore;
END $$
DELIMITER ;


-- 9.16
-- Aggiornamento mensile delle ore di streaming rimanenti all'utente
DROP EVENT IF EXISTS AggiornamentoOreMensili;
DELIMITER $$
CREATE EVENT AggiornamentoOreMensili 
ON SCHEDULE EVERY 1 MONTH
STARTS "2022-01-01 23:55:00" 
DO
BEGIN
	UPDATE Utente
		SET Ore_rimanenti = 20
		WHERE 20 = (
						SELECT Massimo_ore_mensili
                        FROM Abbonamento A
                        WHERE CodFiscale = A.CodFiscale
					);
	UPDATE Utente
		SET Ore_rimanenti = 40
        WHERE 40 = (
						SELECT Massimo_ore_mensili
                        FROM Abbonamento A
                        WHERE CodFiscale = A.CodFiscale
					);
	UPDATE Utente
		SET Ore_rimanenti = 90
        WHERE 90 = (
						SELECT Massimo_ore_mensili
                        FROM Abbonamento A
                        WHERE CodFiscale = A.CodFiscale
					);
	UPDATE Utente
		SET Ore_rimanenti = 745
        WHERE 745 = (
						SELECT Massimo_ore_mensili
                        FROM Abbonamento A
                        WHERE CodFiscale = A.CodFiscale
					);

END $$
DELIMITER ;

