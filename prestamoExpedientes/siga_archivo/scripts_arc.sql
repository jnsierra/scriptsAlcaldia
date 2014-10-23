--
-- Estado en el cual se encuentran los expedientes
--
ALTER TABLE SIA_PRESTAMO
ADD prest_estado VARCHAR(2) DEFAULT 'S' NOT NULL;