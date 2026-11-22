-- 11.2
DROP FUNCTION IF EXISTS CalcoloValutazione; 
DELIMITER $$
CREATE FUNCTION CalcoloValutazione ( _ID_Input Int)
RETURNS FLOAT DETERMINISTIC
BEGIN 
	DECLARE MediaValutazioni Float DEFAULT 0;
    DECLARE SommaVoti INT DEFAULT 0;
    DECLARE NumVoti INT DEFAULT 0;
	DECLARE BonusPremi FLOAT DEFAULT 0;
    DECLARE BonusRegistri FLOAT DEFAULT 0;
	
    Set SommaVoti = ( -- effettuo al sommma dei voti di quel film, valutandoli 3 volte del normale, se il voto è stato dato da un critico
					Select SUM(R.Voto * R.Peso_voto) -- Peso_voto è modificato già da un altro trigger per valere 1 oppure 3
                    From RatingPersonale R
                    Where R.ID_Film = _ID_Input
					);	
    Set NumVoti = ( -- conto quanti voti ha ricevuto quel film e se ho un peso_voto = 3, conto quel voto 3 volte
					Select SUM(R.Peso_voto)
                    From RatingPersonale R
                    Where R.ID_Film = _ID_Input
					);                    
	Set BonusPremi = 0.1 * ( -- conto il bonus che il film riceverà sulla base di quali premi ha vinto
					Select SUM(P.Importanza)
                    From Premio P
                    Where P.ID_Film = _ID_Input
					);  -- ogni premio vinto aggiunge un voto di 0.1 * la sua importanza
	
    IF BonusPremi IS NULL THEN
		SET BonusPremi = 0;
	END IF;
    
    IF(	
		(	
			Select SUM(R1.Premi_vinti)
			From Regista R1 natural join Regia R2
			Where R2.ID_Film = _ID_Input 
		) > 2 )THEN
		Set BonusRegistri = 0.1 ;
	END IF;
        
	Set MediaValutazioni = (SommaVoti/NumVoti) + BonusPremi + BonusRegistri; -- calcolo la valutazione con la seguente equazione
    
    IF MediaValutazioni > 10 THEN -- la valutazione media non può essere più di 10/10
		Set MediaValutazioni = 10;
	END IF;
    
    RETURN MediaValutazioni;  
END $$
DELIMITER ;

DROP TRIGGER IF EXISTS ValutazioneFilm1;
DELIMITER $$
CREATE TRIGGER ValutazioneFilm1
After INSERT ON RatingPersonale FOR EACH ROW 
BEGIN
	Declare NuovaValutazione Float;
    
    Set NuovaValutazione = CalcoloValutazione (New.ID_Film); -- quando viene inserito un nuovo rating si ricalcola la valutazione di quel film
    
	Update Film F
	Set F.Valutazione = NuovaValutazione
	Where F.ID_Film = New.ID_Film;
    
END $$
DELIMITER ;

DROP TRIGGER IF EXISTS ValutazioneFilm2;
DELIMITER $$
CREATE TRIGGER ValutazioneFilm2
After INSERT ON Premio FOR EACH ROW
BEGIN
	Declare NuovaValutazione Float;
    
    Set NuovaValutazione = CalcoloValutazione (New.ID_Film); -- quando viene inserito un nuovo premio si ricalcola la valutazione di quel film
                            
	Update Film F
	Set F.Valutazione = NuovaValutazione
	Where F.ID_Film = New.ID_Film;
    
END $$
DELIMITER ;
