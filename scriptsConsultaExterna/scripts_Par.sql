--
-- tabla de usuarios consulta externa
--
CREATE TABLE SIGA_PARAMETROS.PAR_USUARIOEXT
(
    USUA_EXT_ID             NUMBER(20,2)                           		,
    USUA_EXT_DOCUMENTO      VARCHAR(50)      	NOT NULL           		,
    USUA_EXT_TIPO_DOC       VARCHAR(50)      	NOT NULL           		,
    USUA_EXT_NOMBRES        VARCHAR(100)     	NOT NULL           		,
    USUA_EXT_APELLIDOS      VARCHAR(100)     	NOT NULL           		,
    USUA_EXT_CORREO         VARCHAR(100)     	NOT NULL           		,
    USUA_EXT_DIRECCION      VARCHAR(100)                           		,
    USUA_EXT_NOM_ENTIDAD    VARCHAR(100)                           		,
    USUA_EXT_CONTRA         VARCHAR(100)    	NOT NULL           		,
    USUA_EXT_ENT_ID         NUMBER(20,2)    	NOT NULL           		,
    USUA_EXT_ESTADO         VARCHAR(1)      	DEFAULT 'P'  NOT NULL   ,
    USUA_EXT_FEC_REGISTRO   DATE                DEFAULT sysdate         ,
    USUA_EXT_ULTIMO_ING     TIMESTAMP                           
)
;
--
-- Primary key de la tabla
--
ALTER TABLE PAR_USUARIOEXT
ADD CONSTRAINT PK_PAR_USUARIOEXT PRIMARY KEY (USUA_EXT_ID)
;
--
-- Check de estados I inactivo por default 
--
ALTER TABLE PAR_USUARIOEXT ADD CONSTRAINT CHK_USUA_EXT_ESTADO
CHECK (USUA_EXT_ESTADO IN ('I', 'A', 'R','P'))
;


--
-- Llave para evitar que los documentos de los usuarios se repitan
--
ALTER TABLE SIGA_PARAMETROS.PAR_USUARIOEXT 
ADD CONSTRAINT DOCUMENTO_UNQ unique("USUA_EXT_DOCUMENTO") 
;
--BIEN 
--
-- Trigger para crear la secuencia y para controlar la concordancia con la tabla par_entidad
--
CREATE OR REPLACE TRIGGER SIGA_PARAMETROS.TRAU_BFINS_PAR_USUARIOEXT
BEFORE INSERT ON PAR_USUARIOEXT
FOR EACH ROW
DECLARE
    --
    v_usua_id      NUMBER(20,2);
    v_usua_id_aux  NUMBER(20,2);
    --
    CURSOR c_nuevo_id IS
        SELECT (nvl(max(USUA_EXT_ID), 1) +1) id
          FROM PAR_USUARIOEXT
        ;
    --
BEGIN
    --
    v_usua_id_aux := :NEW.USUA_EXT_ID;
    --
    IF v_usua_id_aux IS NULL THEN
        --
        OPEN c_nuevo_id;
        FETCH c_nuevo_id INTO v_usua_id;
        CLOSE c_nuevo_id;
        --
        :NEW.USUA_EXT_ID := v_usua_id;
        --
    END IF;   
    --   
    EXCEPTION
        WHEN OTHERS THEN
            NULL;
END TRAU_BFINS_PAR_USUARIOEXT;
/

--
-- tabla de auditoria de movimientos de usuario
--
CREATE TABLE SIGA_PARAMETROS.PAR_AUDUSUARIOEXT
(
    AUD_USUA_AUD_ID             	NUMBER(20,2)                ,
    AUD_USUA_ACCION    				VARCHAR(50)      NOT NULL   ,
    AUD_USUA_DESCRIPCION    		VARCHAR(100)                ,
    AUD_USUA_DOCUMENTO    			VARCHAR(100)     NOT NULL   ,
    AUD_USUA_FECHA    		DATE    DEFAULT sysdate    			,
    CONSTRAINT PK_PAR_AUDUSUARIOEXT
    PRIMARY KEY (AUD_USUA_AUD_ID)
)
;
--
-- Trigger para la secuencia de la columna de identificacion
--

CREATE OR REPLACE TRIGGER SIGA_PARAMETROS.TRAU_BFINS_PAR_AUDUSUARIOEXT
BEFORE INSERT ON PAR_AUDUSUARIOEXT
FOR EACH ROW
DECLARE
    --
    v_usua_id      NUMBER(20,2);
    v_usua_id_aux  NUMBER(20,2);
    --
    CURSOR c_nuevo_id IS
        SELECT (nvl(max(AUD_USUA_AUD_ID), 0) +1) id
          FROM PAR_AUDUSUARIOEXT
        ;
    --
BEGIN
    --
    v_usua_id_aux := :NEW.AUD_USUA_AUD_ID;
    --
    IF v_usua_id_aux IS NULL THEN
        --
        OPEN c_nuevo_id;
        FETCH c_nuevo_id INTO v_usua_id;
        CLOSE c_nuevo_id;
        --
        :NEW.AUD_USUA_AUD_ID := v_usua_id;
        --
    END IF;       
	--
    EXCEPTION
        WHEN OTHERS THEN
            NULL;
END TRAU_BFINS_CEX_AUD_USUA;
/


CREATE OR REPLACE 
FUNCTION FX_CONSULTA_REGISTRO( p_documento      VARCHAR2,
								p_tipoDoc		VARCHAR2
                              )RETURN VARCHAR2 IS
	--
    v_existe_usuario         varchar2(2);    
	v_estado_usuario         varchar2(20);
	v_tipodoc_Usua			 varchar2(20);
	--
    CURSOR  c_usuarioRegistrado  IS
    SELECT decode(count(*), 0, 'No', 'Si' ) rta
    FROM PAR_USUARIOEXT
    WHERE trim(upper(USUA_EXT_DOCUMENTO)) = trim(upper(p_documento))
    ;    
	--
    CURSOR c_usuaEstado IS
    SELECT decode(USUA_EXT_ESTADO, 'I', 'Inactivo' ,'A' ,'Activo', 'R', 'Rechazado')
      FROM PAR_USUARIOEXT
     WHERE trim(upper(USUA_EXT_DOCUMENTO)) = trim(upper(p_documento))
       ;
	--
	CURSOR c_valida_tipoDoc IS 
	SELECT USUA_EXT_TIPO_DOC
	FROM PAR_USUARIOEXT
    WHERE trim(upper(USUA_EXT_DOCUMENTO)) = trim(upper(p_documento))
    ;    
	--
BEGIN
   --
   OPEN c_usuarioRegistrado;
   FETCH c_usuarioRegistrado INTO v_existe_usuario;
   CLOSE c_usuarioRegistrado;
   --
	IF UPPER(v_existe_usuario) = 'SI' THEN
		--
		OPEN c_valida_tipoDoc;
        FETCH c_valida_tipoDoc INTO v_tipodoc_Usua;
        CLOSE c_valida_tipoDoc;		
		--
		IF v_tipodoc_Usua = p_tipoDoc THEN
			--
			OPEN c_usuaEstado;
			FETCH c_usuaEstado INTO v_estado_usuario;
			CLOSE c_usuaEstado;		
			--
			IF v_estado_usuario = 'Inactivo' THEN
				--
				RETURN 'NO - Inactivo';
				--
			ELSIF v_estado_usuario = 'Activo' THEN
				--
				RETURN 'NO - Activo';
				--
			ELSIF v_estado_usuario = 'Rechazado' THEN
				--
				RETURN 'SI - Rechazado';
				--
			END IF;	
			--
		ELSE
			RETURN 'NO - TIPO_DOC_INCONSISTENTE';
		END IF;
		--
	ELSE
	--
		RETURN 'Si - Inexistente';
	--	
	END IF;
	--  
   EXCEPTION
     WHEN OTHERS THEN       
       RETURN 'Error' || sqlerrm;
END; 
/

create or replace 
FUNCTION FX_AUTENTICA_CONS_EXT(
                                               p_documento      VARCHAR2,
                                               p_clave           VARCHAR
                                               )RETURN VARCHAR2 IS
    --
    v_aux      varchar2(10);
    --
    CURSOR c_existe IS
    SELECT decode(count(*), 1, 'Si', 'No')
    FROM PAR_USUARIOEXT
    WHERE trim(USUA_EXT_DOCUMENTO) = trim(p_documento)
    AND trim(USUA_EXT_CONTRA) = trim(p_clave)
    ;
    --
    CURSOR c_autentica IS
    SELECT nvl(USUA_EXT_ESTADO,'I')
    FROM PAR_USUARIOEXT
    WHERE trim(USUA_EXT_DOCUMENTO) = trim(p_documento)
    AND trim(USUA_EXT_CONTRA) = trim(p_clave)
    ;
    --
    v_rta   varchar(2) := '';

BEGIN
    --
    OPEN c_existe;
    FETCH c_existe INTO v_aux;
    CLOSE c_existe;
    --
    IF UPPER(v_aux) = 'SI' THEN 
        --
        OPEN c_autentica;
        FETCH c_autentica INTO v_rta;
        CLOSE c_autentica; 
        --
        IF v_rta = 'A' THEN
            --
            RETURN 'Si';
            --
        ELSE 
            --
            RETURN 'NO - ' || v_rta;
            --
        END IF;
        --
    ELSE
    --
        RETURN v_aux || '- Error de Usuario o contraseña';
    --
    END IF;
    --    
    RETURN v_rta;
    --
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 'Error ' || sqlerrm;
END;
/
--
-- FUNCION PARA ENCONTRAR LAS RESPUESTAS DE UN RADICADO
--
CREATE OR REPLACE FUNCTION F_RETORNASALIDASRTAS (
                                                         p_rad_num VARCHAR2
                                                ) RETURN VARCHAR2
                                                AS
    --
    CURSOR c_referenciados IS
    select refe.rad_numero radicado,  rad.tira_id tipoRad
    from sfil_referenciados refe, sfil_radicacion rad
    where refe.rad_referenciado = p_rad_num
	and rad.rad_numero = refe.rad_numero
    ;
    --from sfil_referenciados refe,  sfil_radicacion rad
    --where rad.rad_numero = refe.RAD_REFERENCIADO
    --and rad.tira_id =  2
    --and refe.rad_numero = p_rad_num
    --;
    --
    v_listRefe         VARCHAR2(4000) := '';    
    v_Coma VARCHAR2(1) := '';
    --
BEGIN
     BEGIN
           FOR reg_con IN c_referenciados LOOP
                v_listRefe :=  v_listRefe || v_Coma || reg_con.radicado || '%' || reg_con.tipoRad;
              v_Coma := ',';
          END LOOP;
     EXCEPTION
     WHEN OTHERS THEN
          NULL;
     END;

     RETURN v_listRefe;
END;
/
 
 
GRANT ALL ON SIGA_PARAMETROS.PAR_USUARIOEXT TO SIGA_CORRESPONDENCIA;
GRANT ALL ON SIGA_PARAMETROS.PAR_AUDUSUARIOEXT TO SIGA_CORRESPONDENCIA;

CREATE OR REPLACE FUNCTION F_SEC_AUDITORIA RETURN VARCHAR2
                                                AS
    --
     v_usua_id      NUMBER(20,2);
     v_usua_id_aux  NUMBER(20,2);
    --
    CURSOR c_nuevo_id IS
        SELECT (nvl(max(AUD_USUA_AUD_ID), 0) +1) id
          FROM PAR_AUDUSUARIOEXT
        ;
    --
BEGIN
    --
    OPEN c_nuevo_id;
    FETCH c_nuevo_id INTO v_usua_id;
    CLOSE c_nuevo_id;
    --
    RETURN v_usua_id;
    --
END;
/

GRANT EXECUTE ON F_SEC_AUDITORIA TO SIGA_CORRESPONDENCIA;