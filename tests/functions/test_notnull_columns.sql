-- Create function to test NOT NULL constraints for multiple columns
CREATE OR REPLACE FUNCTION pg_temp.test_notnull_columns(
    p_schema_name name,
    p_table_name name,
    p_columns name[]
)
RETURNS TABLE(test_result text)
LANGUAGE PLPGSQL AS
$function$
DECLARE
    col_name name;
BEGIN
    FOREACH col_name IN ARRAY p_columns
    LOOP
        test_result := col_not_null(p_schema_name, p_table_name, col_name
            , format('Column %I.%I.%I should be NOT NULL', p_schema_name, p_table_name, col_name));
        RETURN NEXT;
    END LOOP;
END;
$function$;