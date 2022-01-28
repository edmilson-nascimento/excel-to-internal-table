*&---------------------------------------------------------------------*
REPORT yteste.

*Inicialization of data
TYPES: BEGIN OF t_record,
         bp     TYPE bu_partner,
         role   TYPE bu_partnerrole,
         branch TYPE bcode,
         desc   TYPE fith_desc,
         def    TYPE fith_default_bcode,
         status TYPE char5,
         erros  TYPE salv_csqt_log_text,
       END OF t_record.

DATA: itab          TYPE TABLE OF alsmex_tabline,
      it_record     TYPE TABLE OF t_record,
      gd_currentrow TYPE i.

DATA(lo_teste_class) =  NEW cl_finloc_cvi_persist_data( ).
DATA(lo_teste_class2) = NEW cl_finloc_customer_update( ).
DATA(lo_teste_class3) = NEW cl_finloc_vendor_update( ).

DATA: lt_pbupl_d_t      TYPE TABLE OF fitha_pbupl_d_t,
      lt_pbupl_d        TYPE TABLE OF fitha_pbupl_d,
      lt_pbupl_d_t_data TYPE TABLE OF fitha_pbupl_d_t,
      lt_pbupl_d_data   TYPE TABLE OF fitha_pbupl_d,
      lt_pbupl_d_t_aux  TYPE TABLE OF fitha_pbupl_d_t,
      lt_pbupl_d_aux    TYPE TABLE OF fitha_pbupl_d.

DATA: lt_pbupl_k_t      TYPE TABLE OF fitha_pbupl_k_t,
      lt_pbupl_k        TYPE TABLE OF fitha_pbupl_k,
      lt_pbupl_k_t_data TYPE TABLE OF fitha_pbupl_k_t,
      lt_pbupl_k_data   TYPE TABLE OF fitha_pbupl_k,
      lt_pbupl_k_t_aux  TYPE TABLE OF fitha_pbupl_k_t,
      lt_pbupl_k_aux    TYPE TABLE OF fitha_pbupl_k.

DATA: layout_settings TYPE REF TO cl_salv_layout,
      layout_key      TYPE salv_s_layout_key,
      lt_alv          TYPE TABLE OF t_record,
      go_alv          TYPE REF TO cl_salv_table,
      columns         TYPE REF TO cl_salv_columns_table,
      column          TYPE REF TO cl_salv_column.

*Selection Screen Declaration
PARAMETERS p_infile TYPE rlgrap-filename LOWER CASE OBLIGATORY.
************************************************************************
*Get file
AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_infile.
  DATA: lt_table TYPE TABLE OF file_table,
        c_rc     TYPE i.
  CALL METHOD cl_gui_frontend_services=>file_open_dialog
    CHANGING
      file_table = lt_table
      rc         = c_rc.
  IF sy-subrc = 0.
    p_infile = VALUE #( lt_table[ 1 ]-filename OPTIONAL ).
  ENDIF.

START-OF-SELECTION.

*Convert Excel to internal table
  CALL FUNCTION 'ALSM_EXCEL_TO_INTERNAL_TABLE'
    EXPORTING
      filename                = p_infile
      i_begin_col             = '1'
      i_begin_row             = '2'
      i_end_col               = '14'
      i_end_row               = '31'
    TABLES
      intern                  = itab
    EXCEPTIONS
      inconsistent_parameters = 1
      upload_ole              = 2
      OTHERS                  = 3.
  IF sy-subrc <> 0.
    MESSAGE e208(00) WITH 'Error: Could not read file'.
  ENDIF.

  SORT itab BY row col.

*Formatting table to match Excel
  LOOP AT itab ASSIGNING FIELD-SYMBOL(<itab>).
    CASE <itab>-col.
      WHEN '0001'.
        APPEND INITIAL LINE TO it_record ASSIGNING FIELD-SYMBOL(<wa_record>).
        <wa_record>-bp     = <itab>-value.

      WHEN '0002'.
        <wa_record>-role   = <itab>-value.

      WHEN '0003'.
        <wa_record>-branch = <itab>-value.

      WHEN '0004'.
        <wa_record>-desc   = <itab>-value.

      WHEN '0005'.
        <wa_record>-def    = to_upper( <itab>-value ).

    ENDCASE.
  ENDLOOP.


**********************************************************************
  CLEAR it_record .

  DATA:
    lv_row TYPE alsmex_tabline-row .

  LOOP AT itab INTO DATA(ls_data) .

    IF ( lv_row IS INITIAL ) .

      " Atribuindo valor inicial
      lv_row = ls_data-row .
      INSERT INITIAL LINE INTO it_record
      INDEX ( lines( it_record ) + 1 )
      ASSIGNING FIELD-SYMBOL(<fs_record>) .

    ELSEIF ( lv_row NE ls_data-row ) .

      " Atribuindo valor inicial
      lv_row = ls_data-row .
      INSERT INITIAL LINE INTO it_record
      INDEX ( lines( it_record ) + 1 )
      ASSIGNING <fs_record> .

    ENDIF .

    " Verificando se a linha foi inserindo e se o numero de contrato é o mesmo
    IF ( <fs_record> IS ASSIGNED ) AND
       ( ls_data-value IS NOT INITIAL ) .

      ASSIGN COMPONENT ls_data-col OF STRUCTURE <fs_record> TO FIELD-SYMBOL(<fs_field>) .
      IF ( <fs_field> IS ASSIGNED ) .

        <fs_field> = ls_data-value .
        UNASSIGN <fs_field> .

      ENDIF .
    ENDIF .

  ENDLOOP .
**********************************************************************


*Select lines where default is filled for each match and count
  SELECT bp, role, COUNT( def ) AS count
    FROM @it_record AS a
   WHERE def EQ @abap_true
   GROUP BY bp, role
    INTO TABLE @DATA(lt_test_count).

*Select all data stored in BP without the changed we want to make
*Customers:
  SELECT *
    FROM fitha_pbupl_d_t
  INTO TABLE @lt_pbupl_d_t
  FOR ALL ENTRIES IN @it_record
   WHERE kunnr = @it_record-bp.

  SELECT *
    FROM fitha_pbupl_d
  INTO TABLE @lt_pbupl_d
  FOR ALL ENTRIES IN @it_record
   WHERE kunnr = @it_record-bp.
*Vendors:
  SELECT *
    FROM fitha_pbupl_k_t
  INTO TABLE @lt_pbupl_k_t
  FOR ALL ENTRIES IN @it_record
   WHERE lifnr = @it_record-bp.

  SELECT *
    FROM fitha_pbupl_k
  INTO TABLE @lt_pbupl_k
  FOR ALL ENTRIES IN @it_record
   WHERE lifnr = @it_record-bp.

*ERROR Validations
  LOOP AT it_record ASSIGNING <wa_record>.

    " Error if BP and/or branch is not filled
    IF <wa_record>-bp IS INITIAL OR <wa_record>-branch IS INITIAL.
      CONCATENATE <wa_record>-erros TEXT-m03 ';' INTO <wa_record>-erros SEPARATED BY space .
    ENDIF.

    IF <wa_record>-role = 'D'.

      " Error if BP does not have the customer role
      SELECT SINGLE @abap_true
        FROM but100
        INTO @DATA(lv_exists)
       WHERE partner EQ @<wa_record>-bp
         AND rltyp EQ 'FLCU00'.
      IF sy-subrc <> 0.
        CONCATENATE <wa_record>-erros TEXT-m01 <wa_record>-bp ';' INTO <wa_record>-erros SEPARATED BY space .
      ENDIF.

    ELSEIF <wa_record>-role = 'K'.
      " Error if BP does not have the vendor role
      SELECT SINGLE @abap_true
        FROM but100
        INTO @lv_exists
       WHERE partner EQ @<wa_record>-bp
         AND rltyp EQ 'FLVN00'.
      IF sy-subrc <> 0.
        CONCATENATE <wa_record>-erros TEXT-m01 <wa_record>-bp ';' INTO <wa_record>-erros SEPARATED BY space .
      ENDIF.

    ELSE.
      " Error if the role filled is not customer or vendor
      CONCATENATE <wa_record>-erros TEXT-m02 <wa_record>-bp ';' INTO <wa_record>-erros SEPARATED BY space .
    ENDIF.

    "Validate number of default flags and return erro if there's mora than 1 default for each combination BP/role
    DATA(ls_test_count) = VALUE #( lt_test_count[
      bp   = <wa_record>-bp
      role = <wa_record>-role ] OPTIONAL ).
    IF ls_test_count-count > 1.
      CONCATENATE <wa_record>-erros TEXT-m04 <wa_record>-bp ';' INTO <wa_record>-erros SEPARATED BY space .
    ENDIF.

  ENDLOOP.

  "Check if any errors occured
  LOOP AT it_record ASSIGNING <wa_record>
    WHERE erros IS NOT INITIAL.
    EXIT.
  ENDLOOP.
  "If exist don't errors:
  IF sy-subrc IS NOT INITIAL.
    " Build final tables to update data
    LOOP AT it_record ASSIGNING <wa_record>.

      "For Customer:
      IF <wa_record>-role = 'D'.
        lt_pbupl_d_t_data = lt_pbupl_d_t.
        DATA(ls_fitha_pbupl_d_t) = VALUE #( lt_pbupl_d_t[
          kunnr     = <wa_record>-bp
          j_1tpbupl = <wa_record>-branch ] OPTIONAL ).
        IF sy-subrc IS INITIAL.
          ls_fitha_pbupl_d_t-description = <wa_record>-desc.
          APPEND ls_fitha_pbupl_d_t TO lt_pbupl_d_t_data.
        ELSE.
          APPEND VALUE #(
            spras       = sy-langu
            kunnr       = <wa_record>-bp
            j_1tpbupl   = <wa_record>-branch
            description = <wa_record>-desc
            ) TO lt_pbupl_d_t_data.
        ENDIF.

        lt_pbupl_d_data = lt_pbupl_d.
        DATA(ls_fitha_pbupl_d) = VALUE #( lt_pbupl_d[
          kunnr     = <wa_record>-bp
          j_1tpbupl = <wa_record>-branch ] OPTIONAL ).
        IF sy-subrc IS INITIAL.
          ls_fitha_pbupl_d-default_branch = <wa_record>-def.
          APPEND ls_fitha_pbupl_d TO lt_pbupl_d_data.
        ELSE.
          APPEND VALUE #(
            kunnr          = <wa_record>-bp
            j_1tpbupl      = <wa_record>-branch
            default_branch = <wa_record>-def
            ) TO lt_pbupl_d_data.
        ENDIF.

        " For Vendor
      ELSEIF <wa_record>-role = 'K'.
        lt_pbupl_k_t_data = lt_pbupl_k_t.
        DATA(ls_fitha_pbupl_k_t) = VALUE #( lt_pbupl_k_t[
               lifnr     = <wa_record>-bp
               j_1tpbupl = <wa_record>-branch ] OPTIONAL ).
        IF sy-subrc IS INITIAL.
          ls_fitha_pbupl_k_t-description = <wa_record>-desc.
          APPEND ls_fitha_pbupl_k_t TO lt_pbupl_k_t_data.
        ELSE.
          APPEND VALUE #(
            spras       = sy-langu
            lifnr       = <wa_record>-bp
            j_1tpbupl   = <wa_record>-branch
            description = <wa_record>-desc
            ) TO lt_pbupl_k_t_data.
        ENDIF.

        lt_pbupl_k_data = lt_pbupl_k.
        DATA(ls_fitha_pbupl_k) = VALUE #( lt_pbupl_k[
          lifnr     = <wa_record>-bp
          j_1tpbupl = <wa_record>-branch ] OPTIONAL ).
        IF sy-subrc IS INITIAL.
          ls_fitha_pbupl_k-default_branch = <wa_record>-def.
          APPEND ls_fitha_pbupl_k TO lt_pbupl_k_data.
        ELSE.
          APPEND VALUE #(
            lifnr          = <wa_record>-bp
            j_1tpbupl      = <wa_record>-branch
            default_branch = <wa_record>-def
            ) TO lt_pbupl_k_data.
        ENDIF.
      ENDIF.
    ENDLOOP.

    "Set and update data selected to BP for customers:
    lo_teste_class->set_fitha_pbupl_d_t_delete( lt_pbupl_d_t ).
    lo_teste_class->set_fitha_pbupl_d_t( lt_pbupl_d_t_data ).
    lo_teste_class->set_fitha_pbupl_d_delete( lt_pbupl_d ).
    lo_teste_class->set_fitha_pbupl_d( lt_pbupl_d_data ).
    lo_teste_class2->cs_update_fitha_pbupl_d_t( ).
    lo_teste_class2->cs_update_fitha_pbupl_d( ).

    "Set and update data selected to BP for vendors:
    lo_teste_class->set_fitha_pbupl_k_t_delete( lt_pbupl_k_t ).
    lo_teste_class->set_fitha_pbupl_k_t( lt_pbupl_k_t_data ).
    lo_teste_class->set_fitha_pbupl_k_delete( lt_pbupl_k ).
    lo_teste_class->set_fitha_pbupl_k( lt_pbupl_k_data ).
    lo_teste_class3->cs_update_fitha_pbupl_k_t( ).
    lo_teste_class3->cs_update_fitha_pbupl_k( ).

    "Commit
    CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
      EXPORTING
        wait = abap_true.

    "Success MESSAGE
    IF sy-subrc = 0.
      MESSAGE i208(00) WITH 'Operation Completed Successfully.'.
    ENDIF.

    " If exist errors:
  ELSE.
    LOOP AT it_record ASSIGNING <wa_record>.
      IF <wa_record>-erros IS NOT INITIAL.
        "Add all the errors to table
        APPEND <wa_record> TO lt_alv.
      ENDIF.
    ENDLOOP.
    " Create and show ALV
    cl_salv_table=>factory(
    IMPORTING
      r_salv_table = go_alv
    CHANGING
      t_table      = lt_alv ).

    columns = go_alv->get_columns( ).
    layout_settings = go_alv->get_layout( ).
    layout_key-report = sy-repid.
    layout_settings->set_key( layout_key ).
    layout_settings->set_save_restriction( if_salv_c_layout=>restrict_none ).

    columns->set_optimize( ).
    go_alv->display( ).

  ENDIF.
