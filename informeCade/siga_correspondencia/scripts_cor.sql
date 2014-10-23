--
--
--
ALTER TABLE fil_dependencia ADD cade_param VARCHAR2(1);
--
--
--
ALTER TABLE fil_dependencia 
ADD CONSTRAINT dep_cade_param_chk
CHECK (cade_param IN ('S','N') )
;
