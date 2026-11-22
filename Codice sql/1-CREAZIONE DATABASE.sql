SET NAMES latin1; 
SET FOREIGN_KEY_CHECKS = 0;

/*CREAZIONE DATABASE*/
BEGIN;
DROP DATABASE IF EXISTS FilmSphere;
CREATE DATABASE IF NOT EXISTS FilmSphere;
COMMIT;

USE FilmSphere;

/* Film */
DROP TABLE IF EXISTS Film;
CREATE TABLE Film 
(
	ID_Film INT NOT NULL, 
    Titolo VARCHAR(75) NOT NULL, 
    Descrizione VARCHAR(500), 
    Valutazione FLOAT, 
    Durata INT NOT NULL, 
    Genere VARCHAR(25) NOT NULL, 
    Anno_Produzione INT NOT NULL,
    
    PRIMARY KEY(ID_Film)
);

/*AttorePrincipale*/
DROP TABLE IF EXISTS AttorePrincipale;
CREATE TABLE AttorePrincipale
(
	CodFiscale CHAR(50) NOT NULL,
    Nome VARCHAR(50) NOT NULL,
    Cognome VARCHAR(50) NOT NULL,
    
    PRIMARY KEY(CodFiscale)
);

/*Cast*/
DROP TABLE IF EXISTS Cast_;
CREATE TABLE Cast_
(
	ID_Film INT NOT NULL,
    CodFiscale CHAR(50) NOT NULL,
    
    PRIMARY KEY(ID_Film, CodFiscale),
    FOREIGN KEY(ID_Film) REFERENCES Film(ID_Film), 
    FOREIGN KEY(CodFiscale) REFERENCES AttorePrincipale(CodFiscale)
);

/*Regista*/
DROP TABLE IF EXISTS Regista;
CREATE TABLE Regista
(
	CodFiscale CHAR(50) NOT NULL,
    Nome VARCHAR(50) NOT NULL,
    Cognome VARCHAR(50) NOT NULL,
    Premi_vinti INT DEFAULT 0,
    
    PRIMARY KEY(CodFiscale)
);

/*Regia*/
DROP TABLE IF EXISTS Regia;
CREATE TABLE Regia
(
	ID_Film INT NOT NULL,
    CodFiscale CHAR(50) NOT NULL,
    
    PRIMARY KEY(ID_Film, CodFiscale),
    FOREIGN KEY(ID_Film) REFERENCES Film(ID_Film), 
    FOREIGN KEY(CodFiscale) REFERENCES Regista(CodFiscale)
);


/*Premio*/
DROP TABLE IF EXISTS Premio;
CREATE TABLE Premio
(
	Nome_premio VARCHAR(50) NOT NULL, 
    Anno_vittoria INT NOT NULL, 
    ID_Film INT NOT NULL, 
    Importanza INT NOT NULL,
    
    PRIMARY KEY(Nome_premio, Anno_vittoria),
    FOREIGN KEY(ID_Film) REFERENCES Film(ID_Film)
);

/*Formato*/
DROP TABLE IF EXISTS Formato;
CREATE TABLE Formato
(
	Codice_formato VARCHAR(20) NOT NULL,
    Qualita VARCHAR(10),				# 4k, FullHD, HD, SD
    Lunghezza_video INT,				# Lunghezza consigliata per il formato in minuti
    Rapporto_aspetto FLOAT,				# 16/9=1.7778; 4/3=1.3334; Larghezza/altezza
    Tipo_formato VARCHAR(15) NOT NULL,	# Audio, Video, AudioVideo
    Risoluzione INT,					# Numero di pixel 
    BitRate FLOAT NOT NULL,				# Numero di MegaBite al secondo
    Dimensione_file FLOAT NOT NULL,		# MegaBite al minuto
    
    PRIMARY KEY(Codice_formato)
);

/*Rilascio*/
DROP TABLE IF EXISTS Rilascio;
CREATE TABLE Rilascio
(
	ID_Film INT NOT NULL,
    Codice_formato VARCHAR(20) NOT NULL,
    Data_uscita DATE NOT NULL,
    
    PRIMARY KEY(ID_Film, Codice_formato),
    FOREIGN KEY(ID_Film) REFERENCES Film(ID_Film), 
    FOREIGN KEY(Codice_formato) REFERENCES Formato(Codice_formato)
);

/*Disponibilita*/
DROP TABLE IF EXISTS Disponibilita;
CREATE TABLE Disponibilita
(
	Codice_formato VARCHAR(20) NOT NULL,
    Paese VARCHAR(50) NOT NULL,
    
    PRIMARY KEY(Codice_formato, Paese),
    FOREIGN KEY(Codice_formato) REFERENCES Formato(Codice_formato),
    FOREIGN KEY(Paese) REFERENCES AreaGeografica(Paese)
);

/*AreaGeografica*/
DROP TABLE IF EXISTS AreaGeografica;
CREATE TABLE AreaGeografica
(
	Paese VARCHAR(50) NOT NULL, 
    IP_area INT NOT NULL,
    Latitudine DOUBLE NOT NULL,
    Longitudine DOUBLE NOT NULL,
        
    PRIMARY KEY(Paese)
);

/*Produzione*/
DROP TABLE IF EXISTS Produzione;
CREATE TABLE Produzione
(
	ID_film INT NOT NULL,
    Paese VARCHAR(50) NOT NULL,
    
    PRIMARY KEY(ID_film, Paese),
    FOREIGN KEY(ID_film) REFERENCES Film(ID_film),
    FOREIGN KEY(Paese) REFERENCES AreaGeografica(Paese)
);

/*Cache*/
DROP TABLE IF EXISTS Cache;
CREATE TABLE Cache
(
	ID_server INT NOT NULL,
    CodFiscale CHAR(50) NOT NULL,
    
    PRIMARY KEY(ID_server, CodFiscale),
    FOREIGN KEY(ID_server) REFERENCES ServerCDN(ID_server),
    FOREIGN KEY(CodFiscale) REFERENCES Utente(CodFiscale)
);

/*Salvataggio*/
DROP TABLE IF EXISTS Salvataggio;
CREATE TABLE Salvataggio
(
	ID_film INT NOT NULL,
    CodFiscale CHAR(50) NOT NULL,
    ID_server INT NOT NULL, 
    
    PRIMARY KEY(ID_film, ID_server, CodFiscale),
    FOREIGN KEY(ID_film) REFERENCES Film(ID_film),
    FOREIGN KEY(ID_server) REFERENCES ServerCDN(ID_server),
    FOREIGN KEY(CodFiscale) REFERENCES Utente(CodFiscale)
);

/*ServerCDN*/
DROP TABLE IF EXISTS ServerCDN;
CREATE TABLE ServerCDN
(
	ID_server INT NOT NULL, 
    Paese VARCHAR(50) NOT NULL, 
    Larghezza_banda INT NOT NULL, -- espressa in bit/s
    Stato VARCHAR(10) NOT NULL, 
    Capacita_massima INT NOT NULL,  
    
    PRIMARY KEY(ID_server),
    FOREIGN KEY(Paese) REFERENCES AreaGeografica(Paese)
);

/*RatingPersonale*/
DROP TABLE IF EXISTS RatingPersonale;
CREATE TABLE RatingPersonale
(
	ID_film INT NOT NULL,
    CodFiscale CHAR(50) NOT NULL,
    Voto TINYINT NOT NULL, 
    Peso_voto TINYINT NOT NULL,
    
    PRIMARY KEY(ID_film, CodFiscale),
    FOREIGN KEY(ID_film) REFERENCES Film(ID_film),
    FOREIGN KEY(CodFiscale) REFERENCES Utente(CodFiscale)
);

/*Cronologia*/
DROP TABLE IF EXISTS Cronologia;
CREATE TABLE Cronologia
(
	Data_visualizzazione DATE NOT NULL, 
    ID_Film INT NOT NULL, 
    CodFiscale CHAR(50) NOT NULL, 
    
    PRIMARY KEY(Data_visualizzazione, ID_Film, CodFiscale), 
    FOREIGN KEY(ID_film) REFERENCES Film(ID_film),
    FOREIGN KEY(CodFiscale) REFERENCES Utente(CodFiscale)
);

/*Lingua*/
DROP TABLE IF EXISTS Lingua;
CREATE TABLE Lingua
(
	Nome_lingua CHAR(50) NOT NULL, 
    
    PRIMARY KEY(Nome_lingua)
);

/*Audio*/
DROP TABLE IF EXISTS Audio;
CREATE TABLE Audio
(
	Nome_lingua CHAR(50) NOT NULL, 
    ID_film INT NOT NULL, 
    
    PRIMARY KEY(Nome_lingua, ID_film), 
    FOREIGN KEY(Nome_lingua) REFERENCES Lingua(Nome_lingua),
    FOREIGN KEY(ID_film) REFERENCES Film(ID_film)
);

/*Sottotitoli*/
DROP TABLE IF EXISTS Sottotitoli;
CREATE TABLE Sottotitoli
(
	Nome_lingua CHAR(50) NOT NULL, 
    ID_film INT NOT NULL, 
    
    PRIMARY KEY(Nome_lingua, ID_film), 
    FOREIGN KEY(Nome_lingua) REFERENCES Lingua(Nome_lingua),
    FOREIGN KEY(ID_film) REFERENCES Film(ID_film)
);

/*Utente*/
DROP TABLE IF EXISTS Utente;
CREATE TABLE Utente
(
	CodFiscale CHAR(50) NOT NULL, 
    Paese VARCHAR(50) NOT NULL, 
    Nome VARCHAR(50) NOT NULL,
    Cognome VARCHAR(50) NOT NULL, 
    Data_nascita DATE NOT NULL, 
    Critico BOOL, 
    Email VARCHAR(100) NOT NULL, 
    Password VARCHAR(50) NOT NULL,
    Ore_rimanenti DOUBLE,
	
    PRIMARY KEY(CodFiscale),
    FOREIGN KEY(Paese) REFERENCES AreaGeografica(Paese)
);

/*Fattura*/
DROP TABLE IF EXISTS Fattura;
CREATE TABLE Fattura
(
	Codice INT NOT NULL, 
    CodFiscale CHAR(50) NOT NULL, 
    Data_pagamento DATE DEFAULT NULL, 
    Scadenza_fattura DATE NOT NULL, 
    Numero_carta BIGINT NOT NULL, 
	CVV_carta INT NOT NULL, 
    Scadenza_carta DATE NOT NULL, 

    
    PRIMARY KEY(Codice),
    FOREIGN KEY(CodFiscale) REFERENCES Utente(CodFiscale)
);

/*Connessione */
DROP TABLE IF EXISTS Connessione;
CREATE TABLE Connessione
(
	Inizio_connessione DATETIME NOT NULL,
    Indirizzo_IP BIGINT NOT NULL, 
    CodFiscale CHAR(50) NOT NULL, 
    Paese VARCHAR(50) NOT NULL, 
    Dispositivo VARCHAR(25) NOT NULL,
    Fine_connessione DATETIME,
    ID_server INT NOT NULL,
    
    PRIMARY KEY(Inizio_connessione, Indirizzo_IP), 
    FOREIGN KEY(CodFiscale) REFERENCES Utente(CodFiscale),
    FOREIGN KEY(Paese) REFERENCES AreaGeografica(Paese),
    FOREIGN KEY(ID_server) REFERENCES ServerCDN(ID_server)
);

/*Iscrizione*/
DROP TABLE IF EXISTS Iscrizione;
CREATE TABLE Iscrizione
(
	CodFiscale CHAR(50) NOT NULL, 
    Nome VARCHAR(50) NOT NULL, 
    
    PRIMARY KEY(CodFiscale, Nome), 
    FOREIGN KEY(CodFiscale) REFERENCES Utente(CodFiscale),
    FOREIGN KEY(Nome) REFERENCES Abbonamento(Nome)
);

/*Abbonamento*/
DROP TABLE IF EXISTS Abbonamento;
CREATE TABLE Abbonamento
(
    Nome VARCHAR(50) NOT NULL, 
    Tariffa INT NOT NULL, 
    Eta_minima INT, 
    Qualita_contenuti VARCHAR(10), 
    Massimo_ore_mensili INT, 
    Funzionalita_aggiuntive VARCHAR(300),

    PRIMARY KEY(Nome)
);

/*Restrizione*/
DROP TABLE IF EXISTS Restrizione;
CREATE TABLE Restrizione
(
    Paese VARCHAR(50) NOT NULL, 
    Nome VARCHAR(50) NOT NULL, 
   
    PRIMARY KEY(Paese, Nome), 
    FOREIGN KEY(Paese) REFERENCES AreaGeografica(Paese),
    FOREIGN KEY(Nome) REFERENCES Abbonamento(Nome)
);
