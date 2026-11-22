DROP PROCEDURE IF EXISTS RankFilmPerArea;
DELIMITER $$
CREATE PROCEDURE RankFilmPerArea(IN _ID_Input INT)
BEGIN
	-- mettere le prime 10 posizioni dei film visti nel sever X in ordine di numero di visualizzazioni
	With FilmAreaX as(
		-- utenti che hanno visto film dall'area X e quando è avvenuta la connessione
			Select C1.CodFiscale as CodX, Inizio_connessione as InizioX, Fine_connessione as FineX
			From Connessione C1
			Where C1.ID_server = _ID_Input -- ID del server e quindi del continente
		), TabellaIntermedia as(
			Select F.ID_Film, F.Titolo, RANK() Over(order by Count(*) DESC) as Posizione
			From Film F Natural join Cronologia C inner join FilmAreaX X on X.CodX=C.CodFiscale
			Where C.Data_visualizzazione Between DATE(X.InizioX) AND DATE(X.FineX) AND
				  C.Data_visualizzazione > current_date() - interval 14 DAY
			Group by F.ID_Film
			Limit 10
		)
		Select T.ID_Film, T.Titolo, T.Posizione, R.Codice_formato
		From TabellaIntermedia T natural join Rilascio R natural join Formato F
		Where F.Risoluzione = ( Select Max(F1.Risoluzione)
								From Formato F1
									 natural join
									 Rilascio R1
								Where R1.ID_Film= T.ID_Film
								);
END $$
DELIMITER ;

/*
call RankFilmPerArea(01);
call RankFilmPerArea(02);
call RankFilmPerArea(03);
call RankFilmPerArea(04);
call RankFilmPerArea(05);
call RankFilmPerArea(06);
*/


DROP PROCEDURE IF EXISTS RankFilmPerAbbonamento;
DELIMITER $$
CREATE PROCEDURE RankFilmPerAbbonamento(IN _NomeAbbonamentoX VARCHAR(50))
BEGIN

	With FilmAbbonamnetoX as(
		Select I.CodFiscale as CodX
		From Iscrizione I
		Where I.Nome = _NomeAbbonamentoX
    ), TabellaIntermedia as(
		Select F.ID_Film, F.Titolo, RANK() Over(order by Count(*) DESC) as Posizione
		From Film F Natural join Cronologia C inner join FilmAbbonamnetoX X on X.CodX=C.CodFiscale
		Where C.Data_visualizzazione > current_date() - interval 14 DAY
		Group by F.ID_Film
		Limit 10
    )
    Select T.ID_Film, T.Titolo, T.Posizione, R.Codice_formato
    From TabellaIntermedia T natural join Rilascio R natural join Formato F
	Where F.Risoluzione = ( Select Max(F1.Risoluzione)
							From Formato F1 natural join Rilascio R1
                            Where R1.ID_Film= T.ID_Film
                            );
    
END $$
DELIMITER ;

/*
call RankFilmPerAbbonamento("Basic");
call RankFilmPerAbbonamento("Premium");
call RankFilmPerAbbonamento("Pro");
call RankFilmPerAbbonamento("Deluxe");
call RankFilmPerAbbonamento("Ultimate");
*/
