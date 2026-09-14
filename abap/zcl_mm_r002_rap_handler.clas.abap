CLASS zcl_mm_r002_rap_handler DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_rap_query_provider.

  PRIVATE SECTION.
    CLASS-METHODS consume_request_options
      IMPORTING
        io_request TYPE REF TO if_rap_query_request.

    CLASS-METHODS fill_range
      IMPORTING
        it_filter TYPE if_rap_query_filter=>tt_name_range_pairs
        iv_name   TYPE string
      CHANGING
        ct_range  TYPE STANDARD TABLE.

    CLASS-METHODS apply_paging
      IMPORTING
        io_request TYPE REF TO if_rap_query_request
      CHANGING
        ct_data    TYPE STANDARD TABLE.

    CLASS-METHODS alpha_in_range
      CHANGING
        ct_range TYPE STANDARD TABLE.
ENDCLASS.


CLASS zcl_mm_r002_rap_handler IMPLEMENTATION.

  METHOD consume_request_options.
    DATA(lv_top)    = io_request->get_paging( )->get_page_size( ).
    DATA(lv_skip)   = io_request->get_paging( )->get_offset( ).
    DATA(lt_sort)   = io_request->get_sort_elements( ).
    DATA(lt_fields) = io_request->get_requested_elements( ).
    IF lt_sort IS NOT INITIAL OR lt_fields IS NOT INITIAL OR lv_top > 0 OR lv_skip > 0.
    ENDIF.
    TRY.
        DATA(lo_search) = io_request->get_search_expression( ).
      CATCH cx_root.
    ENDTRY.
  ENDMETHOD.

  METHOD fill_range.
    DATA lv_low  TYPE string.
    DATA lv_high TYPE string.
    DATA lr_line TYPE REF TO data.

    FIELD-SYMBOLS <ls_line> TYPE any.
    FIELD-SYMBOLS <lv_sign> TYPE any.
    FIELD-SYMBOLS <lv_opt>  TYPE any.
    FIELD-SYMBOLS <lv_low>  TYPE any.
    FIELD-SYMBOLS <lv_high> TYPE any.

    DATA(lv_name) = to_upper( iv_name ).
    LOOP AT it_filter INTO DATA(ls_cond).
      CHECK to_upper( ls_cond-name ) = lv_name.
      LOOP AT ls_cond-range INTO DATA(ls_r).
        lv_low  = ls_r-low.
        lv_high = ls_r-high.
        IF lv_name = 'BEDAT'.
          REPLACE ALL OCCURRENCES OF '-' IN lv_low  WITH ''.
          REPLACE ALL OCCURRENCES OF '-' IN lv_high WITH ''.
          REPLACE ALL OCCURRENCES OF 'T' IN lv_low  WITH ''.
          REPLACE ALL OCCURRENCES OF 'T' IN lv_high WITH ''.
          REPLACE ALL OCCURRENCES OF ':' IN lv_low  WITH ''.
          REPLACE ALL OCCURRENCES OF ':' IN lv_high WITH ''.
          IF strlen( lv_low ) > 8.
            lv_low = lv_low(8).
          ENDIF.
          IF strlen( lv_high ) > 8.
            lv_high = lv_high(8).
          ENDIF.
        ENDIF.

        CREATE DATA lr_line LIKE LINE OF ct_range.
        ASSIGN lr_line->* TO <ls_line>.
        ASSIGN COMPONENT 'SIGN' OF STRUCTURE <ls_line> TO <lv_sign>.
        ASSIGN COMPONENT 'OPTION' OF STRUCTURE <ls_line> TO <lv_opt>.
        ASSIGN COMPONENT 'LOW' OF STRUCTURE <ls_line> TO <lv_low>.
        ASSIGN COMPONENT 'HIGH' OF STRUCTURE <ls_line> TO <lv_high>.
        IF <lv_sign> IS ASSIGNED.
          IF ls_r-sign IS INITIAL.
            <lv_sign> = 'I'.
          ELSE.
            <lv_sign> = ls_r-sign.
          ENDIF.
        ENDIF.
        IF <lv_opt> IS ASSIGNED.
          IF ls_r-option IS INITIAL.
            <lv_opt> = 'EQ'.
          ELSE.
            <lv_opt> = ls_r-option.
          ENDIF.
        ENDIF.
        IF <lv_low> IS ASSIGNED.
          <lv_low> = lv_low.
        ENDIF.
        IF <lv_high> IS ASSIGNED.
          <lv_high> = lv_high.
        ENDIF.
        APPEND <ls_line> TO ct_range.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

  METHOD alpha_in_range.
    FIELD-SYMBOLS <ls> TYPE any.
    FIELD-SYMBOLS <low> TYPE any.
    FIELD-SYMBOLS <high> TYPE any.
    LOOP AT ct_range ASSIGNING <ls>.
      ASSIGN COMPONENT 'LOW' OF STRUCTURE <ls> TO <low>.
      IF sy-subrc = 0 AND <low> IS NOT INITIAL.
        CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
          EXPORTING
            input  = <low>
          IMPORTING
            output = <low>.
      ENDIF.
      ASSIGN COMPONENT 'HIGH' OF STRUCTURE <ls> TO <high>.
      IF sy-subrc = 0 AND <high> IS NOT INITIAL.
        CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
          EXPORTING
            input  = <high>
          IMPORTING
            output = <high>.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD apply_paging.
    DATA(lv_skip) = io_request->get_paging( )->get_offset( ).
    DATA(lv_top)  = io_request->get_paging( )->get_page_size( ).

    IF lv_skip > 0 AND lv_skip < lines( ct_data ).
      DELETE ct_data FROM 1 TO lv_skip.
    ELSEIF lv_skip >= lines( ct_data ).
      CLEAR ct_data.
      RETURN.
    ENDIF.

    IF lv_top > 0 AND lv_top < lines( ct_data ).
      DELETE ct_data FROM lv_top + 1.
    ENDIF.
  ENDMETHOD.

  METHOD if_rap_query_provider~select.
    DATA lt_result TYPE STANDARD TABLE OF zce_mm_r002 WITH EMPTY KEY.
    DATA lt_list   TYPE zcl_mm_r002_service=>tt_list.
    DATA ls_sel    TYPE zcl_mm_r002_service=>ty_sel.
    DATA lv_total  TYPE int8.
    DATA ls_row    TYPE zce_mm_r002.
    DATA ls_list   TYPE zcl_mm_r002_service=>ty_list.

    consume_request_options( io_request ).

    TRY.
        DATA(lo_filter) = io_request->get_filter( ).
        IF lo_filter IS BOUND.
          DATA(lt_cond) = lo_filter->get_as_ranges( ).
          fill_range( EXPORTING it_filter = lt_cond iv_name = 'EBELN' CHANGING ct_range = ls_sel-ebeln ).
          fill_range( EXPORTING it_filter = lt_cond iv_name = 'BEDAT' CHANGING ct_range = ls_sel-bedat ).
          fill_range( EXPORTING it_filter = lt_cond iv_name = 'EKGRP' CHANGING ct_range = ls_sel-ekgrp ).
          fill_range( EXPORTING it_filter = lt_cond iv_name = 'LIFNR' CHANGING ct_range = ls_sel-lifnr ).
          fill_range( EXPORTING it_filter = lt_cond iv_name = 'EKORG' CHANGING ct_range = ls_sel-ekorg ).
          fill_range( EXPORTING it_filter = lt_cond iv_name = 'WERKS' CHANGING ct_range = ls_sel-werks ).

          LOOP AT lt_cond INTO DATA(ls_cond).
            CHECK to_upper( ls_cond-name ) = 'NOSHOW'.
            READ TABLE ls_cond-range INTO DATA(ls_r) INDEX 1.
            IF sy-subrc = 0
               AND ( ls_r-low = 'X'
                  OR ls_r-low = 'true'
                  OR ls_r-low = 'TRUE'
                  OR ls_r-low = '1' ).
              ls_sel-noshow = abap_true.
            ENDIF.
          ENDLOOP.
        ENDIF.
      CATCH cx_rap_query_filter_no_range.
      CATCH cx_root.
        CLEAR lt_result.
        io_response->set_data( lt_result ).
        IF io_request->is_total_numb_of_rec_requested( ).
          io_response->set_total_number_of_records( 0 ).
        ENDIF.
        RETURN.
    ENDTRY.

    alpha_in_range( CHANGING ct_range = ls_sel-ebeln ).
    alpha_in_range( CHANGING ct_range = ls_sel-lifnr ).

    TRY.
        zcl_mm_r002_service=>get_po_data(
          EXPORTING is_sel  = ls_sel
          IMPORTING et_list = lt_list ).
      CATCH cx_root.
        CLEAR lt_list.
    ENDTRY.

    LOOP AT lt_list INTO ls_list.
      CLEAR ls_row.
      MOVE-CORRESPONDING ls_list TO ls_row.
      ls_row-log    = ls_list-log.
      ls_row-noshow = ls_sel-noshow.
      ls_row-previewtxt = '预览PDF'.
      ls_row-pdfurl = |/sap/opu/odata4/sap/zui_mm_r002_o4/srvd/sap/zui_mm_r002/0001/| &&
                      |PoPdf(ebelns='{ ls_row-ebeln }',formid='{ zcl_mm_r002_service=>gc_form_default }')/pdf|.
      APPEND ls_row TO lt_result.
    ENDLOOP.

    lv_total = lines( lt_result ).

    IF io_request->is_data_requested( ) = abap_true.
      apply_paging( EXPORTING io_request = io_request CHANGING ct_data = lt_result ).
      io_response->set_data( lt_result ).
    ENDIF.

    IF io_request->is_total_numb_of_rec_requested( ).
      io_response->set_total_number_of_records( lv_total ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.
