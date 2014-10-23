--
-- Funcion con la cual me encargo de subir las trds
--
CREATE OR REPLACE FUNCTION SIGA_ARCHIVO.FX_CARGUE_TRD RETURN VARCHAR2 IS
    --
    -- Variable la cual va contener el log de errores
    --
    v_log_errores       VARCHAR2(1000) := '';
    --
    -- Cursor el cual busca por medio del codigo de la dependencia el dep_id
    --
    CURSOR c_IdDependencia(pc_dep_codigo  VARCHAR2) IS
    SELECT dep_id, count(*) contador
      FROM sfil_dependencia
     WHERE dep_codigo = pc_dep_codigo
     GROUP BY dep_id
    ;    
    --
    -- Cursor el cual busca por medio del codigo de la serie el  ser_id
    --
    CURSOR c_IdSerie(pc_dep_id NUMBER, pc_ser_codigo VARCHAR2) IS
    SELECT ser_id, count(*) contador
      FROM spar_serie
     WHERE ser_codigo = UPPER(pc_ser_codigo)
       AND dep_id = pc_dep_id
     GROUP BY ser_id
     ;
    --
    -- Cursor el cual busca por medio del codigo de la subserie el subser_id
    --
    CURSOR c_IdSubSerie(pc_ser_id NUMBER, pc_subser_codigo VARCHAR2) IS
    SELECT subser_id, count(*)
      FROM spar_subserie
    WHERE ser_id = pc_ser_id
      AND subser_codigo = pc_subser_codigo
    GROUP BY subser_id
    ;
    --
    -- Cursor el cual obtiene los datos de la tabla temporal
    --    
    CURSOR c_tablaTemporal IS
    SELECT RET_ID,DEP_CODIGO,SER_ID,SER_CODIGO,SUBSER_ID,SUBSER_CODIGO,CLADO_ID,RET_ANNOGESTION,RET_ANNOCENTRAL,RET_DISPOSICION,RET_PROCEDIMIENTO
      FROM temp_retencion
      ORDER BY RET_ID ASC
      ;
    --
    CURSOR c_existClado(pc_clado_id NUMBER) IS
    SELECT count(*) contador
      FROM spar_clasedocumento
     WHERE clado_id = pc_clado_id
     ;   
    --
    --Cursor el cual obtiene las dispociones validas insertadas por el usuario
    --
    CURSOR c_dispoValidas(pc_disp  VARCHAR2) IS
    SELECT DISP_ID
      FROM spar_disposicion
     WHERE pc_disp like '%.D_'||disp_id||'.%'
    ;
    --
    --
    --
    CURSOR c_validaRet(pc_ser_id NUMBER, pc_subser_id NUMBER) IS
    SELECT count(*)
      FROM spar_retencion
     WHERE ser_id = pc_ser_id
       AND subser_id = pc_subser_id
;
    
    v_contLineas        NUMBER := 1;
    v_dep_id            NUMBER;
    v_numDep            NUMBER;
    v_ser_id            NUMBER;
    v_numSer            NUMBER;
    v_subser_id         NUMBER;
    v_numsubser         NUMBER;
    v_numClado          NUMBER;
    --
    v_dispocisiones     VARCHAR2(600):= '';
    --
    --Variable en la cual se encuentra si existe o no una retencion igual
    --
    v_valExRet          NUMBER;
    --
BEGIN
    --
    FOR temp IN c_tablaTemporal 
    LOOP
        --
        OPEN c_IdDependencia(temp.DEP_CODIGO);
        FETCH c_IdDependencia INTO v_dep_id, v_numDep;
        CLOSE c_IdDependencia;
        --
        --v_log_errores := v_log_errores || ' , dep_id: ' || v_dep_id || ' , numDep: '|| v_numDep;
        --
        --return 'Esta es la disposicion: ' || temp.RET_DISPOSICION;
        --
        IF v_dep_id IS NULL OR v_numDep <> 1 THEN
            --
            DELETE FROM temp_retencion;
            --
            ROLLBACK;
            --
            RETURN 'Error linea ' || v_contLineas || ' : Dependencia inexistente o duplicidad en codigo de la dependencia';
            --
        END IF;
        --
        OPEN c_IdSerie(v_dep_id,temp.SER_CODIGO);
        FETCH c_IdSerie INTO v_ser_id,v_numSer;
        CLOSE c_IdSerie;
        --
        IF v_ser_id IS NULL OR v_numSer <> 1 THEN
            --
            DELETE FROM temp_retencion;
            --
            ROLLBACK;
            --
            RETURN 'Error linea ' || v_contLineas || ' : La serie no pertenece a la dependencia ' || temp.DEP_CODIGO || ' o no existe ';
            --
        END IF;
        --
        OPEN c_IdSubSerie(v_ser_id,temp.SUBSER_CODIGO);
        FETCH c_IdSubSerie INTO v_subser_id,v_numsubser;
        CLOSE c_IdSubSerie;
        --
        IF v_subser_id IS NULL OR v_numsubser <> 1 THEN
            --
            DELETE FROM temp_retencion;
            --
            ROLLBACK;
            --
            RETURN 'Error linea ' || v_contLineas || ' : La subserie no pertenece a la serie ' || temp.SER_CODIGO || ' o no existe ';
            --
        END IF;
        --
        OPEN c_existClado(temp.CLADO_ID);
        FETCH c_existClado INTO v_numClado;
        CLOSE c_existClado;
        --
        --return 'v_numClado: ' || v_numClado ||' temp.CLADO_ID: ' || temp.CLADO_ID;
        IF v_numClado <> 1 THEN
            --
            DELETE FROM temp_retencion;
            --
            ROLLBACK;
            --
            RETURN 'Error linea ' || v_contLineas || ' : La clase de documento no existe';
            --
        END IF;
        
        FOR disp IN c_dispoValidas(temp.RET_DISPOSICION) 
        LOOP
            v_dispocisiones := v_dispocisiones || '.D_' || disp.DISP_ID  || '.';
        END LOOP;
        
        IF v_dispocisiones <> temp.RET_DISPOSICION THEN
            --
            ROLLBACK;
            --
            RETURN 'Error linea ' || v_contLineas || ' : Alguna o todas las dispocisiones no son validas variable dis:' || v_dispocisiones || ' y lo de la tabla: ' ||temp.RET_DISPOSICION;
            --
        END IF;
        --
        OPEN c_validaRet(v_ser_id, v_subser_id);
        FETCH c_validaRet INTO v_valExRet;
        CLOSE c_validaRet;
        
        IF v_valExRet = 0 THEN
            --RETURN 'INSERTA linea' || v_contLineas;
            INSERT INTO spar_retencion (
                                        RET_ID,
                                        SER_ID,
                                        SUBSER_ID,
                                        CLADO_ID,
                                        RET_ANNOGESTION,
                                        RET_ANNOCENTRAL,
                                        RET_DISPOSICION,
                                        RET_PROCEDIMIENTO)
            values ((select nvl(max(RET_ID), 0)+1 from spar_retencion), 
                     v_ser_id,
                     v_subser_id,
                     temp.clado_id,
                     temp.RET_ANNOGESTION,
                     temp.RET_ANNOCENTRAL,
                     temp.RET_DISPOSICION,
                     temp.RET_PROCEDIMIENTO                     
                   );
                   
        ELSIF v_valExRet = 1 THEN
            
            UPDATE  spar_retencion
               SET  CLADO_ID = temp.clado_id,
             RET_ANNOGESTION = temp.RET_ANNOGESTION,
             RET_ANNOCENTRAL = temp.RET_ANNOCENTRAL,
             RET_DISPOSICION = temp.RET_DISPOSICION,
           RET_PROCEDIMIENTO = temp.RET_PROCEDIMIENTO
             WHERE SER_ID = v_ser_id
               AND SUBSER_ID = v_subser_id
                ;
            --
        ELSE 
            --
            ROLLBACK;
            --
            RETURN 'INCONSISTENCIA DE DATOS DE TRD linea' || v_contLineas;
            --
        END IF;
        
        v_dep_id    := null;
        v_numDep    := null;
        v_ser_id    := null;
        v_numSer    := null;
        v_subser_id := null;
        v_numsubser := null;
        v_numClado  := null;
        v_dispocisiones := '';
        --
        v_contLineas := v_contLineas + 1;
        --
    END LOOP;
    --
    DELETE FROM temp_retencion;
    --
    COMMIT;
    --
    --
    RETURN upper('Cargue realizado exitosamente') ;
    --
   EXCEPTION
     WHEN OTHERS THEN       
       ROLLBACK;
       RETURN 'Error' || sqlerrm;
END;
/
--
-- Tabla temporal para cargue de trds
--
CREATE GLOBAL TEMPORARY TABLE TEMP_RETENCION
(
  RET_ID             NUMBER,
  DEP_CODIGO         VARCHAR2(400 BYTE),
  SER_ID             NUMBER,
  SER_CODIGO         VARCHAR2(400 BYTE),
  SUBSER_ID          NUMBER,
  SUBSER_CODIGO      VARCHAR2(400 BYTE),
  CLADO_ID           NUMBER,
  RET_ANNOGESTION    VARCHAR2(4 BYTE),
  RET_ANNOCENTRAL    VARCHAR2(4 BYTE),
  RET_DISPOSICION    VARCHAR2(4000 BYTE),
  RET_PROCEDIMIENTO  VARCHAR2(4000 BYTE)
)
ON COMMIT PRESERVE ROWS
NOCACHE;


