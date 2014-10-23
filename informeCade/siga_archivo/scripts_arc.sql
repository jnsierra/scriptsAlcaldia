--
-- Recupera los correos de los responsables de los cades parametrizados
--
CREATE OR REPLACE FUNCTION SIGA_ARCHIVO.FX_RESP_INFCADE
    RETURN VARCHAR2 IS
    --
    -- Cursor el cual recupera los correos de los encargados de los cades
    --
    CURSOR c_correoResp IS
    SELECT REDCADE_CORRREO_RESP
      FROM SPAR_REDCADES
     WHERE REDCADE_ESTADO = 'A'
    ;
    --
    -- Variable en la cual se almacenaran todos los correos de los encargados de los cades
    --
    v_correos       VARCHAR2(2000) := '';
    v_iterator      NUMBER(5,2)  := 0;
    --
    BEGIN
    
    FOR correo IN c_correoResp 
    LOOP
        IF v_iterator = 0 THEN
            --
            v_correos := correo.REDCADE_CORRREO_RESP;
            --
        ELSE
            --
            v_correos := v_correos || ';' || correo.REDCADE_CORRREO_RESP;
            --
        END IF;
        
        
        v_iterator := v_iterator+1;
    END LOOP;
    
    RETURN v_correos;
END;
/
--
-- Determina si puede hacer cargue de informe
--
CREATE OR REPLACE FUNCTION SIGA_ARCHIVO.FX_VER_CARGUE_INFCADE
    RETURN VARCHAR2 IS
    --
    --
    CURSOR c_fechasPar IS
    SELECT to_date(nvl(cade_fechainicial,'1'), 'dd') ini, to_date(nvl(cade_fechafinal, '1'), 'dd') fin 
      FROM sia_parametros
     WHERE par_id = 1
     ;
    --
    v_fechaIni      DATE;
    v_fechaFin      DATE;
    v_hoy           DATE;
    --
    BEGIN
    
    OPEN c_fechasPar;
    FETCH c_fechasPar INTO v_fechaIni,v_fechaFin;
    CLOSE c_fechasPar;
    
    v_hoy  := sysdate;
    --Datos para realizar pruebas
    --v_hoy  := to_date('01/10/2014', 'dd/mm/yyyy');
    --v_fechaIni := add_months(v_fechaIni,1);
    --v_fechaFin := add_months(v_fechaFin,1);
    
    IF v_hoy >= v_fechaIni AND v_hoy <= v_fechaFin THEN
        --
        RETURN 'PERMITIDO';
        --
    END IF;
    
    RETURN 'NOPERMITIDO';
    
    EXCEPTION 
        WHEN OTHERS THEN
            RETURN 'Error '|| sqlerrm;
END;
/
--
-- Verifica si debe enviar correos a los encargados de los cades
--
CREATE OR REPLACE FUNCTION SIGA_ARCHIVO.FX_VER_ENV_CORREOS_INFCADE
    RETURN VARCHAR2 IS    
    --
    CURSOR c_validaTipoLogica IS
    SELECT CASE 
            WHEN tabla.rango > 0 THEN
                   'NORMAL'
            WHEN tabla.rango <= 0 THEN
                   'ESPECIAL'
           END RESULTADO
      FROM (SELECT cade_fechainicial - cade_diasCorreo rango FROM sia_parametros WHERE par_id = 1) tabla
    ;
    --
    CURSOR c_fechasPar IS
    SELECT to_date(nvl(cade_fechainicial,'1'), 'dd') ini, to_number(nvl(cade_diasCorreo, '1')) dias
      FROM sia_parametros
     WHERE par_id = 1
     ; 
    --
    v_tipoLogica        VARCHAR2(20);
    v_fechaIni          DATE;
    v_fechaEnvio        DATE;
    v_numDiasCorreo     NUMBER(20,2);
    v_hoy               DATE;
    v_evalua            NUMBER(20,2);
    
BEGIN
    
    OPEN c_validaTipoLogica;
    FETCH c_validaTipoLogica INTO v_tipoLogica;
    CLOSE c_validaTipoLogica;
    
    OPEN c_fechasPar;
    FETCH c_fechasPar INTO v_fechaIni, v_numDiasCorreo;
    CLOSE c_fechasPar;
    
    IF v_tipoLogica = 'ESPECIAL' THEN
        --
        v_fechaIni := add_months(v_fechaIni,1);
        --
    END IF;
    
    --
    -- Variable con la cual se desde que fecha debo empezar a enviar los correos
    --
    v_fechaEnvio := v_fechaIni - v_numDiasCorreo;
    --
    v_hoy := sysdate;
    --v_hoy := to_date('2/10/2014','dd/mm/yyyy');
    --
    --return 'v_fechaEnvio' || v_fechaEnvio || '  v_fechaIni ' || v_fechaIni || ' v_hoy '  ||v_hoy;
    IF v_hoy >= v_fechaEnvio AND  v_hoy <= v_fechaIni THEN
        --
        RETURN 'ENVIA';
        --
    END IF;
    
    RETURN 'ENVIA';
    
END;
/
--
-- Funcion con la cual cargo los informes
--
CREATE OR REPLACE FUNCTION SIGA_ARCHIVO.FX_INSERTA_EXPEDIENTE(
                                p_arc_Nombre                  VARCHAR2,
                                p_arc_fecini                  VARCHAR2,
                                p_arc_fecfin                  VARCHAR2,
                                p_arc_Codigo                  VARCHAR2,
                                p_arc_Folios                  VARCHAR2,
                                p_arc_Comentarios             VARCHAR2,
                                p_arc_Cara                    VARCHAR2,
                                p_arc_Archivador              VARCHAR2,
                                p_arc_Cajon                   VARCHAR2,
                                p_arc_Codigoexp               VARCHAR2,
                                p_arc_Consecutivo             VARCHAR2,
                                p_deps_Id                     NUMBER,
                                p_sop_Id                      VARCHAR2,
                                p_arc_Signaturatopografica    VARCHAR2,
                                p_cade_puntoAten              VARCHAR2,
                                p_cade_Responsable            VARCHAR2,
                                p_cade_Mes                    VARCHAR2,
                                p_cade_Anno                   VARCHAR2                                
                              )RETURN VARCHAR2 IS
        --
        -- OBTENGO LOS PARAMETROS DE DEPENDECIA SERIE Y SUB SERIE PARAMETRIZADAS
        --
        CURSOR C_PARAM_DEPSERSSER IS
        SELECT dep.dep_id, ser.ser_id, sub.subser_id
         FROM sfil_dependencia dep, spar_serie ser, spar_subserie sub 
        WHERE dep.dep_id = ser.dep_id
          AND ser.ser_id = sub.ser_id
          AND dep.cade_param = 'S'
          AND ser.cade_param = 'S'
          AND sub.cade_param = 'S'
          AND rownum = 1
          ;
        --
        --Cusor el cual obtiene el siguiente secuencial de la tabla sia_archivo
        --
        CURSOR C_ARC_ID IS
        SELECT MAX(arc_id) + 1
          FROM sia_archivo
        ;
        --
        -- Valores predeterminados de la informacion del FUID
        --
        v_frec_Id     VARCHAR2(1) := 'M';    -- Frecuencia de consulta
        v_idet_Id     VARCHAR2(1) := 'N';    -- Indice de deterioro
        v_seg_Id      VARCHAR2(1) := 'G';    -- Seguridad
        v_uco_Id      VARCHAR2(1) := '2';    -- Conservación
        --
        v_ser_id      NUMBER := 0;
        v_subser_id   NUMBER := 0;
        v_dep_id      NUMBER := 0;
        --
        v_arc_id      NUMBER := 0;
        v_arc_estado  VARCHAR2(1) := 'A';
        v_arc_fecha   DATE        := SYSDATE;
        --
BEGIN
        --
        OPEN C_PARAM_DEPSERSSER;
        FETCH C_PARAM_DEPSERSSER INTO v_dep_id, v_ser_id, v_subser_id;
        CLOSE C_PARAM_DEPSERSSER;
        --
        OPEN C_ARC_ID;
        FETCH C_ARC_ID INTO v_arc_id;
        CLOSE C_ARC_ID;
        --
        INSERT INTO SIA_ARCHIVO
        (
            ARC_ID,
            SER_ID,
            SUBSER_ID,
            ARC_ANNO,
            ARC_ARCHIVADOR,
            ARC_CAJON,
            ARC_CONSECUTIVO,
            ARC_ESTADO,
            ARC_NOMBRE,
            ARC_CODIGO,
            ARC_FOLIOS,
            ARC_COMENTARIOS,
            ARC_FECHA,
            IDET_ID,
            DEPS_ID,
            ARC_CARA,
            FREC_ID,
            SEG_ID,
            UCO_ID,
            ARC_FECHAPRIMERDOC,
            ARC_FECHASEGUNDODOC,
            SOP_ID,
            ARC_SIGNATURATOPOGRAFICA,
            CADE_PUNTOATEN,
            CADE_RESPONSABLE,
            CADE_MES,
            CADE_ANNO,
            ARC_CODIGOEXP,
            FUNC_CEDULA
        )
        VALUES (
            v_arc_id,
            v_ser_id,
            v_subser_id,
            p_cade_Anno,
            p_arc_Archivador,
            p_arc_Cajon,
            p_arc_Consecutivo,
            v_arc_estado,
            p_arc_Nombre,
            p_arc_Codigo,
            p_arc_Folios,
            p_arc_Comentarios,
            v_arc_fecha,
            v_idet_Id,
            p_deps_Id,
            p_arc_Cara,
            v_frec_Id,
            v_seg_Id,
            v_uco_Id,
            to_date(p_arc_fecini,'dd/mm/yyyy'),
            to_date(p_arc_fecfin,'dd/mm/yyyy'),
            p_sop_Id,
            p_arc_Signaturatopografica,
            p_cade_puntoAten,
            p_cade_Responsable,
            p_cade_Mes,
            p_cade_Anno,
            p_arc_Codigoexp,
            p_cade_Responsable
        );
        commit;

        RETURN 'OK-'||v_arc_id ;
    
   EXCEPTION
     WHEN OTHERS THEN       
       RETURN 'Error' || sqlerrm;
END;
/
--
--
--
CREATE GLOBAL TEMPORARY TABLE TEMP_CONSINFORMECADE
(
  FILA                  NUMBER,
  REDCADE_NOMBRE        VARCHAR2(400 BYTE),
  NOMBREIMAGEN          VARCHAR2(400 BYTE),
  CADE_ANNO             VARCHAR2(400 BYTE),
  PERIODO               VARCHAR2(400 BYTE),
  ARC_ID                VARCHAR2(400 BYTE),
  ARC_CODIGO            VARCHAR2(400 BYTE),
  ARC_NOMBRE            VARCHAR2(400 BYTE),
  ARC_ESTADO            VARCHAR2(400 BYTE)
)
ON COMMIT PRESERVE ROWS
NOCACHE;

create index sia_archivo_cade 
on sia_archivo (cade_puntoaten)
;



