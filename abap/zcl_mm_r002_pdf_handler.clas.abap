  CLASS zcl_mm_r002_pdf_handler DEFINITION
    PUBLIC
    FINAL
    CREATE PUBLIC.

    PUBLIC SECTION.
      INTERFACES if_rap_query_provider.

    PRIVATE SECTION.
      CLASS-METHODS consume_request_options
        IMPORTING
          io_request TYPE REF TO if_rap_query_request.

      CLASS-METHODS parse_filter_value
        IMPORTING
          it_filter_cond TYPE if_rap_query_filter=>tt_name_range_pairs
          iv_name        TYPE string
        RETURNING
          VALUE(rv_value) TYPE string.
  ENDCLASS.


  CLASS zcl_mm_r002_pdf_handler IMPLEMENTATION.

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

    METHOD parse_filter_value.
      DATA(lv_name) = to_upper( iv_name ).
      LOOP AT it_filter_cond INTO DATA(ls_cond).
        CHECK to_upper( ls_cond-name ) = lv_name.
        READ TABLE ls_cond-range INTO DATA(ls_range) INDEX 1.
        IF sy-subrc = 0.
          rv_value = ls_range-low.
        ENDIF.
        RETURN.
      ENDLOOP.
    ENDMETHOD.

    METHOD if_rap_query_provider~select.
      DATA lt_result TYPE STANDARD TABLE OF zce_mm_r002_pdf WITH EMPTY KEY.
      DATA ls_row    TYPE zce_mm_r002_pdf.
      DATA lv_ebelns TYPE string.
      DATA lv_formid TYPE tdsfname.
      DATA lt_ebeln  TYPE zcl_mm_r002_service=>tt_ebeln.
      DATA lv_pdf    TYPE xstring.
      DATA lv_fname  TYPE string.
      DATA lv_error  TYPE string.
      DATA lv_total  TYPE int8.

      consume_request_options( io_request ).

      TRY.
          DATA(lo_filter) = io_request->get_filter( ).
          IF lo_filter IS BOUND.
            DATA(lt_cond) = lo_filter->get_as_ranges( ).
            lv_ebelns = parse_filter_value( it_filter_cond = lt_cond iv_name = 'EBELNS' ).
            lv_formid = CONV #( parse_filter_value( it_filter_cond = lt_cond iv_name = 'FORMID' ) ).
          ENDIF.
        CATCH cx_root.
          CLEAR lt_result.
          io_response->set_data( lt_result ).
          IF io_request->is_total_numb_of_rec_requested( ).
            io_response->set_total_number_of_records( 0 ).
          ENDIF.
          RETURN.
      ENDTRY.

      IF lv_formid IS INITIAL.
        lv_formid = zcl_mm_r002_service=>gc_form_default.
      ENDIF.

      ls_row-ebelns   = lv_ebelns.
      ls_row-formid   = lv_formid.
      ls_row-mimetype = 'application/pdf'.

      IF lv_ebelns IS NOT INITIAL AND io_request->is_data_requested( ) = abap_true.
        lt_ebeln = zcl_mm_r002_service=>parse_ebeln_list( lv_ebelns ).
        TRY.
            zcl_mm_r002_service=>get_pdf(
              EXPORTING
                it_ebeln  = lt_ebeln
                iv_formid = lv_formid
              IMPORTING
                ev_pdf    = lv_pdf
                ev_fname  = lv_fname
                ev_error  = lv_error ).
            ls_row-pdf      = lv_pdf.
            ls_row-filename = lv_fname.
            ls_row-message  = lv_error.
          CATCH cx_root INTO DATA(lx).
            ls_row-message = lx->get_text( ).
        ENDTRY.
        APPEND ls_row TO lt_result.
      ENDIF.

      lv_total = lines( lt_result ).

      IF io_request->is_data_requested( ) = abap_true.
        io_response->set_data( lt_result ).
      ENDIF.
      IF io_request->is_total_numb_of_rec_requested( ).
        io_response->set_total_number_of_records( lv_total ).
      ENDIF.
    ENDMETHOD.

  ENDCLASS.
