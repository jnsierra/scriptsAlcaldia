--
-- Estado en el cual se encuentran los expedientes
--
ALTER TABLE SIA_PRESTAMO
ADD prest_estado VARCHAR(2) DEFAULT 'S' NOT NULL;
--
-- Funcion el cual retorna un vector con los encargados de archivo 
--
CREATE OR REPLACE FUNCTION SIGA_ARCHIVO.FX_BUSCA_ENCARGADOS(
                                                            p_arc_id                  VARCHAR2
                                                            )RETURN VARCHAR2 IS
        --
        -- Cursor en el cual identifico a que dependencia pertenece el expediente
        --
        CURSOR c_depId IS
        SELECT to_char(d.dep_id)
          FROM sia_archivo r, spar_serie s, sfil_dependencia d
         WHERE r.arc_id = p_arc_id
           AND r.ser_id = s.ser_id
           AND s.dep_id = d.dep_id
        ;
        --
        -- Cursor con el cual obtengo los correos de los encargados de la dependencia 
        --
        CURSOR c_correos(pc_depId varchar2) IS
        SELECT u.email
          FROM sia_perfilusuario pu, susuario_tabla u
         WHERE pu.perusu_listadependencias like '%.'|| pc_depId ||'.%'
           AND pu.usu_id = u.cedula
           AND email is not null
           AND upper(PU.PERUSU_ENCARGADOARCHIVO) = 'S'
           ;
        --
        v_dep_id            VARCHAR2(100)  := '';
        --
        v_correos           VARCHAR2(1000) := '';
        v_contador          INT := 0; 
        --
BEGIN
    
    OPEN c_depId;
    FETCH c_depId INTO v_dep_id;
    CLOSE c_depId;
    
    IF v_dep_id IS NOT NULL THEN
        --
        FOR correos IN c_correos(v_dep_id) 
        LOOP
            --
            IF v_contador = 0 THEN
                --
                v_correos := correos.email;
                v_contador := 1;
                --
            ELSE
                --
                v_correos := v_correos|| ',' || TRIM(correos.email);
                --                
            END IF;
            --            
        END LOOP;
        --
    ELSE
        --
        RETURN 'Error expediente no existe';
        --
    END IF;
    --
    RETURN v_correos;    
    --
   EXCEPTION
     WHEN OTHERS THEN       
       RETURN 'Error' || sqlerrm;
END;
/
