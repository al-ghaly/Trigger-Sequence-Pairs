/*
FIRST WE HAVE TO SETUP THE ENVIRONMENT 
We will only work on a specific tables that has a numeric, non-composite
primary key column.
*/
--Create a temporary table holding the data for the tables we are going 
--to work on
CREATE TABLE TABLES_TO_ADJUST
(
   TABLE_NAME        VARCHAR2 (50),
   COLUMN_NAME       VARCHAR2 (50),
   CONSTRAINT_NAME   VARCHAR2 (50)
);

--Getting the data of the tables we are going to work on
INSERT INTO TABLES_TO_ADJUST
   SELECT CT.table_name, CL.column_name, CT.constraint_name
     FROM user_constraints CT, user_cons_columns CL, user_tab_columns UC
    WHERE     CT.constraint_name = CL.constraint_name
          AND UC.TABLE_NAME = CT.TABLE_NAME
          AND UC.COLUMN_NAME = CL.column_name
          AND constraint_type = 'P'
          AND CT.table_name NOT LIKE '%$%'
          AND UC.data_type = 'NUMBER' ;

--We can't use composite key here so we will just delete any tables with 
--a composite primary key
DELETE FROM TABLES_TO_ADJUST
      WHERE table_name IN (  SELECT table_name
                               FROM TABLES_TO_ADJUST
                           GROUP BY table_name
                             HAVING COUNT (table_name) > 1);
--      NOW WE ARE READY LETS BEGIN THE FUN PART --

CREATE OR REPLACE PROCEDURE ADJUST
IS
   --The maximum ID for each table
   MAX_ID                 NUMBER (6);

   --All the tables to adjust
   CURSOR tables_cursor
   IS
      SELECT * FROM tables_to_adjust;

   --A dynamic SQL Statement to extract dynamic data (MAX ID FOR EACH TABLE)
   SQL_MAX_ID_STMT        VARCHAR2 (200);
   --Dynamic sql statment for creating the sequence
   SQL_SEQ_STMT           VARCHAR2 (200);
   --Dynamic sql statment for creating the Trigger
   SQL_TRG_STMT           VARCHAR2 (200);
   --flag to see if the sequence exists
   SEQ_COUNTER            NUMBER (1);
   --Dynamic sql statment to count the triggers
   SQL_SEQ_COUNTER_STMT   VARCHAR (200);
BEGIN
   --Loop over each table and adjust it
   FOR TABLE_REC IN TABLES_CURSOR
   LOOP
      --Get the maximum ID for that table
      SQL_MAX_ID_STMT :=
            'SELECT MAX('
         || TABLE_REC.COLUMN_NAME
         || ') FROM '
         || TABLE_REC.TABLE_NAME;
           
      EXECUTE IMMEDIATE SQL_MAX_ID_STMT INTO MAX_ID;
      MAX_ID := NVL(MAX_ID, 1);  
       
      --MAKE SURE THE SEQUENCE IS NOT ALREADY THERE
      SQL_SEQ_COUNTER_STMT :=
            'SELECT COUNT(*) FROM USER_SEQUENCES'
         || ' WHERE SEQUENCE_NAME = '''
         || TABLE_REC.TABLE_NAME
         || '_SEQ''';
        
      EXECUTE IMMEDIATE SQL_SEQ_COUNTER_STMT INTO SEQ_COUNTER;
      IF SEQ_COUNTER = 1
      THEN
            EXECUTE IMMEDIATE 'DROP SEQUENCE ' || TABLE_REC.TABLE_NAME
         || '_SEQ';
      END IF;
         --Create the Sequence
         SQL_SEQ_STMT :=
               'CREATE SEQUENCE '
            || TABLE_REC.TABLE_NAME
            || '_SEQ START WITH '
            || (MAX_ID + 1)
            || ' INCREMENT BY 1';
      EXECUTE IMMEDIATE SQL_SEQ_STMT;

         --Create the Trigger
         SQL_TRG_STMT :=
               'CREATE OR REPLACE TRIGGER '
            || TABLE_REC.TABLE_NAME
            || '_TRG  BEFORE INSERT ON '
            || TABLE_REC.TABLE_NAME
            || ' FOR EACH ROW BEGIN :NEW.'
            || TABLE_REC.COLUMN_NAME
            || ':= '
            || TABLE_REC.TABLE_NAME
            || '_SEQ.NEXTVAL; END  '
            || TABLE_REC.TABLE_NAME
            || '_TRG;';
     EXECUTE IMMEDIATE SQL_TRG_STMT;
   END LOOP;
END;
--MAKING SURE EVERYTHING IS A OKAY
SHOW ERROR;
