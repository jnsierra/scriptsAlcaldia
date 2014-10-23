--
-- Tabla en la cual se encuentran los cades parametrizados
--
CREATE TABLE PAR_REDCADES
(
  REDCADE_ID            NUMBER(20,2)            NOT NULL,
  REDCADE_CODIGO        VARCHAR2(50 BYTE)       NOT NULL,
  REDCADE_NOMBRE        VARCHAR2(100 BYTE)      NOT NULL,
  REDCADE_DESCRIPCION   VARCHAR2(100 BYTE)      NOT NULL,
  REDCADE_ESTADO        VARCHAR2(1 BYTE)        NOT NULL,
  REDCADE_DIRECCION     VARCHAR2(50 BYTE)       NOT NULL,
  REDCADE_RESPONSABLE   VARCHAR2(100 BYTE),
  REDCADE_CORRREO_RESP  VARCHAR2(100 BYTE)
);


ALTER TABLE PAR_REDCADES ADD (
  CONSTRAINT REDCADE_ESTADO_CHK
 CHECK (REDCADE_ESTADO IN ('A','I') ),
  CONSTRAINT PK_PAR_REDCADES
 PRIMARY KEY
 (REDCADE_ID));

GRANT ALL ON PAR_REDCADES TO SIGA_ARCHIVO;

GRANT ALL ON PAR_REDCADES TO SIGA_CORRESPONDENCIA;


CREATE OR REPLACE TRIGGER SIGA_PARAMETROS.TRAU_BFINS_PAR_REDCADES
BEFORE INSERT ON PAR_REDCADES
FOR EACH ROW
DECLARE
    --
    v_cade_id      NUMBER(20,2);
    v_id_aux  NUMBER(20,2);
    --
    CURSOR c_nuevo_id IS
        SELECT max(nvl(REDCADE_ID, 0))+1 id
          FROM PAR_REDCADES
        ;
    --
BEGIN
    --
    v_id_aux := :NEW.REDCADE_ID;
    --
    IF v_id_aux IS NULL THEN
        --
        OPEN c_nuevo_id;
        FETCH c_nuevo_id INTO v_cade_id;
        CLOSE c_nuevo_id;
        --
        :NEW.REDCADE_ID := v_cade_id;
        --
    END IF;   
    --   
    EXCEPTION
        WHEN OTHERS THEN
            NULL;
END TRAU_BFINS_PAR_REDCADES;
/
--
--
--
ALTER TABLE par_serie ADD cade_param VARCHAR2(1);
--
--
--
ALTER TABLE par_serie 
ADD CONSTRAINT serie_cade_param_chk
CHECK (cade_param IN ('S','N') )
;
--
--
--
ALTER TABLE par_subserie ADD cade_param VARCHAR2(1);
--
--
--
ALTER TABLE par_subserie 
ADD CONSTRAINT SUBSERIECADE_PARAM_CHK
CHECK (cade_param IN ('S','N') )
;



